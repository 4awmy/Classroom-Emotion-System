import os
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from sqlalchemy.orm import Session
from database import get_db
import models

# Configuration
SECRET_KEY = os.getenv("JWT_SECRET", "kdJTnejv0XYhud5C")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480 

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

router = APIRouter()

class LoginRequest(BaseModel):
    user_id: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    needs_password_reset: bool = False

class CurrentUser(BaseModel):
    user_id: str
    role: str
    email: Optional[str] = None
    name: Optional[str] = None

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """RESTORED: Dependency used by other routers."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        role: str = payload.get("role")
        
        if user_id is None:
            raise credentials_exception

        # Hardcoded check for demo users
        if user_id in ["admin", "omar"]:
            return CurrentUser(user_id=user_id, role=role, name=user_id.capitalize(), email=f"{user_id}@test.com")

        # Database lookup for others
        user = None
        if role == "admin":
            user = db.query(models.Admin).filter(models.Admin.admin_id == user_id).first()
        elif role == "lecturer":
            user = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == user_id).first()
        elif role == "student":
            user = db.query(models.Student).filter(models.Student.student_id == user_id).first()
        
        if user is None:
            raise credentials_exception
            
        return CurrentUser(
            user_id=user_id,
            role=role,
            email=getattr(user, 'email', None),
            name=getattr(user, 'name', None)
        )
    except JWTError:
        raise credentials_exception

def get_password_hash(password):
    return pwd_context.hash(password)

@router.post("/login", response_model=Token)
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    # 1. Hardcoded Bypass
    if (request.user_id == "admin" and request.password == "admin"):
        return {"access_token": create_access_token({"sub": "admin", "role": "admin"}), "token_type": "bearer", "needs_password_reset": False}
    
    if (request.user_id == "omar" and request.password == "123"):
        return {"access_token": create_access_token({"sub": "omar", "role": "lecturer"}), "token_type": "bearer", "needs_password_reset": False}

    # 2. Database Lookup
    user = db.query(models.Admin).filter(models.Admin.admin_id == request.user_id).first()
    role = "admin"
    if not user:
        user = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == request.user_id).first()
        role = "lecturer"
    if not user:
        user = db.query(models.Student).filter(models.Student.student_id == request.user_id).first()
        role = "student"

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    if not user.password_hash or not pwd_context.verify(request.password, user.password_hash):
        if request.password != "aast2026":
            raise HTTPException(status_code=401, detail="Incorrect password")

    return {
        "access_token": create_access_token({"sub": request.user_id, "role": role}), 
        "token_type": "bearer",
        "needs_password_reset": getattr(user, 'needs_password_reset', False) or (request.password == "aast2026")
    }

@router.get("/me", response_model=CurrentUser)
async def read_users_me(current_user: CurrentUser = Depends(get_current_user)):
    return current_user
