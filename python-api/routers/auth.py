import os
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import JWTError, jwt
from database import get_db
from schemas import UserLogin, Token, TokenData
import models

router = APIRouter(tags=["Authentication"])

JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 60 * 8  # 8 hours

_bearer_scheme = HTTPBearer(auto_error=True)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    db: Session = Depends(get_db),
) -> models.Student:
    """
    Dependency that verifies a Bearer JWT and returns the authenticated Student row.
    Raises HTTP 401 if the token is missing, malformed, expired, or the student
    no longer exists in the database.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM]
        )
        student_id: str = payload.get("student_id")
        if student_id is None:
            raise credentials_exception
        token_data = TokenData(student_id=student_id, role=payload.get("role"))
    except JWTError:
        raise credentials_exception

    student = db.query(models.Student).filter(
        models.Student.student_id == token_data.student_id
    ).first()
    if student is None:
        raise credentials_exception
    return student


@router.post("/login", response_model=Token)
def login(request: UserLogin, db: Session = Depends(get_db)):
    """
    Validate student_id and password.
    Mock validation: password must be 'password123'.
    Phase 2 will hash and compare against the students table.
    """
    # Always perform the DB lookup first so that both "bad ID" and "bad password"
    # paths take the same code path — this prevents timing-based enumeration of
    # valid student IDs.
    student = db.query(models.Student).filter(
        models.Student.student_id == request.student_id
    ).first()

    # Phase 1 mock: reject any unknown student_id or wrong password with an
    # identical error message to avoid leaking which condition failed.
    # Phase 2 will replace the plaintext comparison with bcrypt.verify().
    if student is None or request.password != "password123":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Phase 1 mock role determination:
    #   - IDs starting with "LECT" are treated as lecturers.
    #   - All other IDs (including 9-digit AAST student numbers) are students.
    # Phase 2 will add a dedicated lecturers/staff table and look up role there.
    role = "lecturer" if request.student_id.upper().startswith("LECT") else "student"

    payload = {
        "student_id": request.student_id,
        "role": role,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRE_MINUTES),
    }

    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

    return Token(access_token=token, token_type="bearer")
