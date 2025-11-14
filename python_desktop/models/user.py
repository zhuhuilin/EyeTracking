"""
User data model - matches Flutter app's User.
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class User:
    """User model for authentication and session tracking."""

    id: Optional[int]
    email: str
    role: str = "user"  # "user" or "admin"
    created_at: Optional[datetime] = None

    def is_admin(self) -> bool:
        """Check if user has admin role."""
        return self.role == "admin"

    def to_dict(self) -> dict:
        """Convert to dictionary for database storage."""
        return {
            "id": self.id,
            "email": self.email,
            "role": self.role,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    @staticmethod
    def from_dict(data: dict) -> "User":
        """Create User from dictionary."""
        return User(
            id=data.get("id"),
            email=data["email"],
            role=data.get("role", "user"),
            created_at=datetime.fromisoformat(data["created_at"]) if data.get("created_at") else None,
        )
