from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr


# --- Auth Schemas ---

class UserRegister(BaseModel):
    name: str
    email: EmailStr
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    avatar_color: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    token: str
    user: UserResponse


# --- Project Schemas ---

class ProjectCreate(BaseModel):
    name: str
    type: str = "video"
    is_shared: bool = False
    total_duration_seconds: int = 0


class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    is_shared: Optional[bool] = None
    total_duration_seconds: Optional[int] = None


class ProjectResponse(BaseModel):
    id: str
    user_id: str
    name: str
    type: str
    is_shared: bool
    total_duration_seconds: int
    thumbnail_path: Optional[str] = None
    created_at: datetime
    modified_at: datetime

    model_config = {"from_attributes": True}


# --- Collaboration Schemas ---

class CollaboratorAdd(BaseModel):
    email: str
    role: str = "editor"


class CollaboratorResponse(BaseModel):
    id: str
    user_id: str
    name: str
    email: str
    role: str
    is_online: bool
    avatar_color: str
    invited_at: datetime

    model_config = {"from_attributes": True}


class CommentCreate(BaseModel):
    text: str
    attachment: Optional[str] = None


class CommentResponse(BaseModel):
    id: str
    user_id: str
    author_name: str
    text: str
    attachment: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class VersionCreate(BaseModel):
    notes: str = ""


class VersionResponse(BaseModel):
    id: str
    name: str
    author_name: str
    notes: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ActivityResponse(BaseModel):
    id: str
    text: str
    created_at: datetime

    model_config = {"from_attributes": True}


class InviteEmailRequest(BaseModel):
    email: str
    project_name: str
    inviter_name: str
    role: str = "editor"


class PendingInviteResponse(BaseModel):
    id: str
    email: str
    role: str
    created_at: datetime

    model_config = {"from_attributes": True}

