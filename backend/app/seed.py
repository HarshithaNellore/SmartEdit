"""Seed default user data for testing."""
from sqlalchemy.orm import Session
from .models import User
from .auth import hash_password


def seed_default_user(db: Session):
    """Create default test user if it doesn't exist."""
    default_email = "test@smartcut.app"
    
    # Check if user already exists
    existing_user = db.query(User).filter(User.email == default_email).first()
    if existing_user:
        return existing_user
    
    # Create default user
    default_user = User(
        name="Test User",
        email=default_email,
        hashed_password=hash_password("password123"),
        avatar_color="#6C63FF",
    )
    
    db.add(default_user)
    db.commit()
    db.refresh(default_user)
    
    print(f"✅ Default user created!")
    print(f"   Email: {default_email}")
    print(f"   Password: password123")
    
    return default_user
