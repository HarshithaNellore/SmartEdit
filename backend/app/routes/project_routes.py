from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, Project
from ..schemas import ProjectCreate, ProjectUpdate, ProjectResponse
from ..auth import get_current_user

router = APIRouter(prefix="/api/projects", tags=["Projects"])


@router.get("/", response_model=List[ProjectResponse])
def list_projects(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    projects = (
        db.query(Project)
        .filter(Project.user_id == current_user.id)
        .order_by(Project.modified_at.desc())
        .all()
    )
    return [
        ProjectResponse(
            id=str(p.id),
            user_id=str(p.user_id),
            name=p.name,
            type=p.type,
            is_shared=p.is_shared,
            total_duration_seconds=p.total_duration_seconds,
            thumbnail_path=p.thumbnail_path,
            created_at=p.created_at,
            modified_at=p.modified_at,
        )
        for p in projects
    ]


@router.post("/", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(
    data: ProjectCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = Project(
        user_id=current_user.id,
        name=data.name,
        type=data.type,
        is_shared=data.is_shared,
        total_duration_seconds=data.total_duration_seconds,
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return ProjectResponse(
        id=str(project.id),
        user_id=str(project.user_id),
        name=project.name,
        type=project.type,
        is_shared=project.is_shared,
        total_duration_seconds=project.total_duration_seconds,
        thumbnail_path=project.thumbnail_path,
        created_at=project.created_at,
        modified_at=project.modified_at,
    )


@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: str,
    data: ProjectUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id,
    ).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    if data.name is not None:
        project.name = data.name
    if data.type is not None:
        project.type = data.type
    if data.is_shared is not None:
        project.is_shared = data.is_shared
    if data.total_duration_seconds is not None:
        project.total_duration_seconds = data.total_duration_seconds

    project.modified_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(project)
    return ProjectResponse(
        id=str(project.id),
        user_id=str(project.user_id),
        name=project.name,
        type=project.type,
        is_shared=project.is_shared,
        total_duration_seconds=project.total_duration_seconds,
        thumbnail_path=project.thumbnail_path,
        created_at=project.created_at,
        modified_at=project.modified_at,
    )


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(
    project_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id,
    ).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    db.delete(project)
    db.commit()
