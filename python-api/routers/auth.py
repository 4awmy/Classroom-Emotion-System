import os
from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from pydantic import BaseModel
from typing import Optional

router = APIRouter(tags=["Authentication"])

SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"

_bearer_scheme = HTTPBearer(auto_error=True)

class CurrentUser(BaseModel):
    sub: str
    role: str
    student_id: Optional[str] = None
    lecturer_id: Optional[str] = None
    admin_id: Optional[str] = None
    email: Optional[str] = None

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme)
) -> CurrentUser:
    """
    Dependency that verifies a Supabase JWT and returns the authenticated user claims.
    Raises HTTP 401 if the token is missing, malformed, or expired.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Supabase uses HS256 and the JWT secret to sign tokens
        payload = jwt.decode(
            credentials.credentials, 
            SUPABASE_JWT_SECRET, 
            algorithms=[JWT_ALGORITHM],
            options={"verify_aud": False}
        )
        
        sub: str = payload.get("sub")
        role: str = payload.get("role")
        
        if sub is None or role is None:
            raise credentials_exception
            
        return CurrentUser(
            sub=sub,
            role=role,
            student_id=payload.get("student_id"),
            lecturer_id=payload.get("lecturer_id"),
            admin_id=payload.get("admin_id"),
            email=payload.get("email")
        )
    except JWTError:
        raise credentials_exception
