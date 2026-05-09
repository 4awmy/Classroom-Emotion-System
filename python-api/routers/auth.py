import os
from datetime import datetime, timedelta
from typing import Optional, Union
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
ACCESS_TOKEN_EXPIRE_MINUTES = 480 # 8 hours

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

router = APIRouter()

# Models
class LoginRequest(BaseModel):
    user_id: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class CurrentUser(BaseModel):
    user_id: str
    role: str
    email: Optional[str] = None
    name: Optional[str] = None

# Utilities
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# Dependency
async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
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
        
        # Verify user still exists
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

# Endpoints
@router.post("/login", response_model=Token)
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    # 1. Check Admins
    user = db.query(models.Admin).filter(models.Admin.admin_id == request.user_id).first()
    role = "admin"
    
    # 2. Check Lecturers
    if not user:
        user = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == request.user_id).first()
        role = "lecturer"
        
    # 3. Check Students
    if not user:
        user = db.query(models.Student).filter(models.Student.student_id == request.user_id).first()
        role = "student"

    if not user or not user.password_hash or not verify_password(request.password, user.password_hash):
        # Fallback for dev: if password is 'admin' and user is 'admin', let them in even without hash
        if request.user_id == "admin" and request.password == "admin" and role == "admin":
            pass # Authorized
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect user ID or password",
                headers={"WWW-Authenticate": "Bearer"},
            )

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": request.user_id, "role": role},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=CurrentUser)
async def read_users_me(current_user: CurrentUser = Depends(get_current_user)):
    return current_user
