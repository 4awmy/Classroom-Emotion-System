import os
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.orm import Session
from jose import jwt
from database import get_db
from schemas import UserLogin, Token
import models

router = APIRouter(tags=["Authentication"])

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 60 * 8  # 8 hours

@router.post("/login", response_model=Token)
def login(request: UserLogin, db: Session = Depends(get_db)):
    """
    Validate student_id and password.
    Mock validation: password must be 'password123'.
    """
    # In Phase 2, we would check the database for the student/lecturer
    # For now, we just validate the mock password
    if request.password != "password123":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Determine role (mock logic: if ID starts with 'LECT', it's a lecturer)
    role = "lecturer" if request.student_id.startswith("LECT") else "student"

    payload = {
        "student_id": request.student_id,
        "role": role,
        "exp": datetime.utcnow() + timedelta(minutes=JWT_EXPIRE_MINUTES),
    }
    
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    
    return Token(access_token=token, token_type="bearer")
