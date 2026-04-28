import os
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from jose import jwt

router = APIRouter()

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 60 * 8  # 8 hours


class LoginRequest(BaseModel):
    student_id: str
    password: str


class TokenResponse(BaseModel):
    token: str
    student_id: str
    role: str


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest):
    """
    Mock auth endpoint — returns a signed JWT.
    Phase 2 will validate credentials against the students table.
    """
    if not request.student_id or not request.password:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="student_id and password are required",
        )

    payload = {
        "student_id": request.student_id,
        "role": "student",
        "exp": datetime.utcnow() + timedelta(minutes=JWT_EXPIRE_MINUTES),
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return TokenResponse(token=token, student_id=request.student_id, role="student")
