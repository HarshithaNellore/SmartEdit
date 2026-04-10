from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, Project, ProjectCollaborator, ProjectComment, ProjectVersion, ActivityLog, PendingInvite
from ..schemas import (
    CollaboratorAdd, CollaboratorResponse,
    CommentCreate, CommentResponse,
    VersionCreate, VersionResponse,
    ActivityResponse,
)
from ..auth import get_current_user

router = APIRouter(prefix="/api/projects/{project_id}", tags=["Collaboration"])


def _get_project_for_user(project_id: str, user: User, db: Session) -> Project:
    """Return the project if the user is the owner or a collaborator."""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    # Allow owner
    if project.user_id == user.id:
        return project
    # Allow collaborators
    collab = db.query(ProjectCollaborator).filter(
        ProjectCollaborator.project_id == project_id,
        ProjectCollaborator.user_id == user.id,
    ).first()
    if collab:
        return project
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a member of this project")


def _log_activity(db: Session, project_id: str, user_id: str | None, text: str):
    entry = ActivityLog(project_id=project_id, user_id=user_id, text=text)
    db.add(entry)
    db.commit()


# ─── Collaborators ───────────────────────────────────────────

@router.get("/collaborators", response_model=List[CollaboratorResponse])
def list_collaborators(
    project_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    collabs = (
        db.query(ProjectCollaborator)
        .filter(ProjectCollaborator.project_id == project.id)
        .order_by(ProjectCollaborator.invited_at.asc())
        .all()
    )
    results = []
    for c in collabs:
        user = db.query(User).filter(User.id == c.user_id).first()
        results.append(CollaboratorResponse(
            id=c.id,
            user_id=c.user_id,
            name=user.name if user else "Unknown",
            email=user.email if user else "",
            role=c.role,
            is_online=c.is_online,
            avatar_color=user.avatar_color if user else "#6C63FF",
            invited_at=c.invited_at,
        ))
    return results


@router.post("/collaborators", response_model=CollaboratorResponse, status_code=status.HTTP_201_CREATED)
def add_collaborator(
    project_id: str,
    data: CollaboratorAdd,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)

    # Find the user to invite by email
    target_user = db.query(User).filter(User.email == data.email).first()

    if not target_user:
        # User not registered — create a pending invite instead of 404
        existing_pending = db.query(PendingInvite).filter(
            PendingInvite.project_id == project.id,
            PendingInvite.email == data.email,
        ).first()
        if existing_pending:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="An invitation is already pending for this email")

        pending = PendingInvite(
            project_id=project.id,
            email=data.email,
            role=data.role,
            invited_by=current_user.id,
        )
        db.add(pending)
        db.commit()
        db.refresh(pending)

        _log_activity(db, project.id, current_user.id, f"Invited {data.email} (pending registration) as {data.role}")

        # Trigger email notification (non-blocking — if it fails, invite still exists)
        try:
            from .email_routes import _send_email, _build_invite_html
            subject = f"{current_user.name} invited you to collaborate on \"{project.name}\" — SmartCut"
            html = _build_invite_html(current_user.name, project.name, data.role)
            _send_email(data.email, subject, html)
        except Exception:
            pass  # Email is best-effort

        # Return a synthetic CollaboratorResponse for the pending invite
        return CollaboratorResponse(
            id=pending.id,
            user_id="pending",
            name=data.email.split("@")[0],
            email=data.email,
            role=data.role,
            is_online=False,
            avatar_color="#9E9E9E",
            invited_at=pending.created_at,
        )

    # Prevent duplicate
    existing = db.query(ProjectCollaborator).filter(
        ProjectCollaborator.project_id == project.id,
        ProjectCollaborator.user_id == target_user.id,
    ).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User is already a collaborator")

    collab = ProjectCollaborator(
        project_id=project.id,
        user_id=target_user.id,
        role=data.role,
    )
    db.add(collab)
    project.is_shared = True
    db.commit()
    db.refresh(collab)

    _log_activity(db, project.id, current_user.id, f"{target_user.name} was invited as {data.role}")

    # Send notification email to the existing user too
    try:
        from .email_routes import _send_email, _build_invite_html
        subject = f"{current_user.name} invited you to collaborate on \"{project.name}\" — SmartCut"
        html = _build_invite_html(current_user.name, project.name, data.role)
        _send_email(target_user.email, subject, html)
    except Exception:
        pass

    return CollaboratorResponse(
        id=collab.id,
        user_id=target_user.id,
        name=target_user.name,
        email=target_user.email,
        role=collab.role,
        is_online=collab.is_online,
        avatar_color=target_user.avatar_color,
        invited_at=collab.invited_at,
    )


@router.delete("/collaborators/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_collaborator(
    project_id: str,
    user_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    collab = db.query(ProjectCollaborator).filter(
        ProjectCollaborator.project_id == project.id,
        ProjectCollaborator.user_id == user_id,
    ).first()
    if not collab:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collaborator not found")

    removed_user = db.query(User).filter(User.id == user_id).first()
    db.delete(collab)
    db.commit()

    _log_activity(db, project.id, current_user.id,
                  f"{removed_user.name if removed_user else 'A user'} was removed from the team")


# ─── Comments ────────────────────────────────────────────────

@router.get("/comments", response_model=List[CommentResponse])
def list_comments(
    project_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    comments = (
        db.query(ProjectComment)
        .filter(ProjectComment.project_id == project.id)
        .order_by(ProjectComment.created_at.asc())
        .all()
    )
    results = []
    for c in comments:
        user = db.query(User).filter(User.id == c.user_id).first()
        results.append(CommentResponse(
            id=c.id,
            user_id=c.user_id,
            author_name=user.name if user else "Unknown",
            text=c.text,
            attachment=c.attachment,
            created_at=c.created_at,
        ))
    return results


@router.post("/comments", response_model=CommentResponse, status_code=status.HTTP_201_CREATED)
def add_comment(
    project_id: str,
    data: CommentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    comment = ProjectComment(
        project_id=project.id,
        user_id=current_user.id,
        text=data.text,
        attachment=data.attachment,
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)

    _log_activity(db, project.id, current_user.id, f"{current_user.name} added a comment")

    return CommentResponse(
        id=comment.id,
        user_id=current_user.id,
        author_name=current_user.name,
        text=comment.text,
        attachment=comment.attachment,
        created_at=comment.created_at,
    )


@router.delete("/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_comment(
    project_id: str,
    comment_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    comment = db.query(ProjectComment).filter(
        ProjectComment.id == comment_id,
        ProjectComment.project_id == project.id,
    ).first()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Comment not found")
    db.delete(comment)
    db.commit()


@router.delete("/comments", status_code=status.HTTP_204_NO_CONTENT)
def clear_comments(
    project_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    db.query(ProjectComment).filter(ProjectComment.project_id == project.id).delete()
    db.commit()
    _log_activity(db, project.id, current_user.id, "All comments cleared")


# ─── Versions ────────────────────────────────────────────────

@router.get("/versions", response_model=List[VersionResponse])
def list_versions(
    project_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    versions = (
        db.query(ProjectVersion)
        .filter(ProjectVersion.project_id == project.id)
        .order_by(ProjectVersion.created_at.desc())
        .all()
    )
    results = []
    for v in versions:
        user = db.query(User).filter(User.id == v.user_id).first()
        results.append(VersionResponse(
            id=v.id,
            name=v.name,
            author_name=user.name if user else "Unknown",
            notes=v.notes or "",
            created_at=v.created_at,
        ))
    return results


@router.post("/versions", response_model=VersionResponse, status_code=status.HTTP_201_CREATED)
def save_version(
    project_id: str,
    data: VersionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)

    # Auto-increment version name
    count = db.query(ProjectVersion).filter(ProjectVersion.project_id == project.id).count()
    version_name = f"v{count + 1}.0"

    version = ProjectVersion(
        project_id=project.id,
        user_id=current_user.id,
        name=version_name,
        notes=data.notes,
    )
    db.add(version)
    db.commit()
    db.refresh(version)

    _log_activity(db, project.id, current_user.id, f"Version {version_name} saved")

    return VersionResponse(
        id=version.id,
        name=version.name,
        author_name=current_user.name,
        notes=version.notes or "",
        created_at=version.created_at,
    )


@router.post("/versions/{version_id}/restore", status_code=status.HTTP_200_OK)
def restore_version(
    project_id: str,
    version_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    version = db.query(ProjectVersion).filter(
        ProjectVersion.id == version_id,
        ProjectVersion.project_id == project.id,
    ).first()
    if not version:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Version not found")

    _log_activity(db, project.id, current_user.id, f"Restored to {version.name}")
    return {"message": f"Restored to {version.name}"}


# ─── Activity Log ────────────────────────────────────────────

@router.get("/activities", response_model=List[ActivityResponse])
def list_activities(
    project_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = _get_project_for_user(project_id, current_user, db)
    activities = (
        db.query(ActivityLog)
        .filter(ActivityLog.project_id == project.id)
        .order_by(ActivityLog.created_at.desc())
        .limit(50)
        .all()
    )
    return [
        ActivityResponse(id=a.id, text=a.text, created_at=a.created_at)
        for a in activities
    ]
