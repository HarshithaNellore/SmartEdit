import os
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from ..auth import get_current_user
from ..models import User

logger = logging.getLogger("smartcut.email")

router = APIRouter(prefix="/api/email", tags=["Email"])


# ─── Configuration via environment variables ─────────────────
SMTP_HOST = os.environ.get("SMTP_HOST", "")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASS = os.environ.get("SMTP_PASS", "")
SMTP_FROM = os.environ.get("SMTP_FROM", SMTP_USER or "noreply@smartcut.app")

_smtp_configured = bool(SMTP_HOST and SMTP_USER and SMTP_PASS)

if _smtp_configured:
    logger.info(f"SMTP configured: host={SMTP_HOST}:{SMTP_PORT} user={SMTP_USER}")
else:
    logger.warning(
        "SMTP not configured (set SMTP_HOST, SMTP_USER, SMTP_PASS env vars). "
        "Email sending will be simulated."
    )


class InviteEmailRequest(BaseModel):
    email: str
    project_name: str
    inviter_name: str
    role: str = "editor"


def _build_invite_html(inviter_name: str, project_name: str, role: str) -> str:
    return f"""
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto;
                background: linear-gradient(135deg, #0D0D1A 0%, #1A0A2E 100%); color: #FFFFFF;
                border-radius: 16px; overflow: hidden;">
        <div style="padding: 40px 32px; text-align: center;">
            <div style="width: 60px; height: 60px; margin: 0 auto 16px;
                        background: linear-gradient(135deg, #6C63FF, #E040FB); border-radius: 16px;
                        display: flex; align-items: center; justify-content: center;">
                <span style="font-size: 28px;">✨</span>
            </div>
            <h1 style="font-size: 24px; margin: 0 0 8px;">You're Invited!</h1>
            <p style="color: #A0A0B0; font-size: 14px; margin: 0 0 24px;">
                <strong style="color: #E040FB;">{inviter_name}</strong> has invited you to collaborate on
            </p>
            <div style="background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1);
                        border-radius: 12px; padding: 20px; margin-bottom: 24px;">
                <h2 style="font-size: 18px; margin: 0 0 8px; color: #FFFFFF;">{project_name}</h2>
                <span style="background: rgba(108,99,255,0.2); color: #6C63FF; padding: 4px 12px;
                             border-radius: 6px; font-size: 12px; font-weight: 600;">
                    Role: {role.upper()}
                </span>
            </div>
            <a href="https://smartcut.app" style="display: inline-block; background: linear-gradient(135deg, #6C63FF, #E040FB);
                    color: white; padding: 14px 40px; border-radius: 10px; text-decoration: none;
                    font-weight: 600; font-size: 14px;">
                Open SmartCut
            </a>
            <p style="color: #666; font-size: 11px; margin-top: 24px;">
                If you don't have an account, sign up with this email to access the project.
            </p>
        </div>
    </div>
    """


def _send_email(to_email: str, subject: str, html_body: str) -> bool:
    """Send email via SMTP. Returns True on success, False on failure."""
    if not _smtp_configured:
        logger.info(f"[SIMULATED] Email to {to_email}: {subject}")
        return True

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = SMTP_FROM
        msg["To"] = to_email
        msg.attach(MIMEText(html_body, "html"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(SMTP_USER, SMTP_PASS)
            server.sendmail(SMTP_FROM, to_email, msg.as_string())

        logger.info(f"Email sent successfully to {to_email}")
        return True
    except Exception as e:
        logger.error(f"Email send FAILED to {to_email}: {e}")
        return False


@router.post("/invite")
def send_invite_email(
    data: InviteEmailRequest,
    current_user: User = Depends(get_current_user),
):
    """
    Send a collaboration invite email.
    If SMTP is not configured, simulates the send and returns success.
    """
    logger.info(f"Invite email request: from={current_user.email} to={data.email} project={data.project_name}")

    subject = f"{data.inviter_name} invited you to collaborate on \"{data.project_name}\" — SmartCut"
    html = _build_invite_html(data.inviter_name, data.project_name, data.role)

    success = _send_email(data.email, subject, html)

    if success:
        return {
            "status": "sent" if _smtp_configured else "simulated",
            "message": f"Invitation email {'sent' if _smtp_configured else 'simulated (SMTP not configured)'} to {data.email}",
            "smtp_configured": _smtp_configured,
        }
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send email to {data.email}. Check SMTP configuration.",
        )
