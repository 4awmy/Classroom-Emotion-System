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
import schemas
from supabase import create_client, Client

# Configuration
SECRET_KEY = os.getenv("JWT_SECRET", "kdJTnejv0XYhud5C")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480 

# Supabase Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
supabase: Optional[Client] = create_client(SUPABASE_URL, SUPABASE_ANON_KEY) if SUPABASE_URL and SUPABASE_ANON_KEY else None

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
    """Validates JWT (Supabase or Local) and returns the current user from the local database."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if supabase:
        try:
            # Verify with Supabase
            user_resp = supabase.auth.get_user(token)
            if not user_resp or not user_resp.user:
                raise credentials_exception
                
            sb_user = user_resp.user
            role = sb_user.user_metadata.get("role")
            
            # Lookup in local DB using auth_user_id (UUID)
            user = None
            if role == "admin":
                user = db.query(models.Admin).filter(models.Admin.auth_user_id == sb_user.id).first()
            elif role == "lecturer":
                user = db.query(models.Lecturer).filter(models.Lecturer.auth_user_id == sb_user.id).first()
            elif role == "student":
                user = db.query(models.Student).filter(models.Student.auth_user_id == sb_user.id).first()
            
            # Fallback to email lookup if UUID match fails (migration/sync helper)
            if user is None:
                if role == "admin":
                    user = db.query(models.Admin).filter(models.Admin.email == sb_user.email).first()
                elif role == "lecturer":
                    user = db.query(models.Lecturer).filter(models.Lecturer.email == sb_user.email).first()
                elif role == "student":
                    user = db.query(models.Student).filter(models.Student.email == sb_user.email).first()
                
                if user:
                    user.auth_user_id = sb_user.id
                    db.commit()
                else:
                    raise credentials_exception

            return CurrentUser(
                user_id=getattr(user, 'admin_id', getattr(user, 'lecturer_id', getattr(user, 'student_id', None))),
                role=role,
                email=user.email,
                name=user.name
            )
        except Exception as e:
            print(f"[AUTH] Supabase verification error: {e}")
            # Fallback to local JWT check below if Supabase fails
            pass

    # Local JWT Fallback (Legacy or if Supabase is unavailable)
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        role: str = payload.get("role")
        
        if user_id is None:
            raise credentials_exception

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
    print(f"[AUTH] Login attempt for: {request.user_id}")
    
    # 1. Find local user to determine role and email
    user = db.query(models.Admin).filter(models.Admin.admin_id == request.user_id).first()
    role = "admin"
    if not user:
        user = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == request.user_id).first()
        role = "lecturer"
    if not user:
        user = db.query(models.Student).filter(models.Student.student_id == request.user_id).first()
        role = "student"

    if not user:
        print(f"[AUTH] User not found: {request.user_id}")
        raise HTTPException(status_code=401, detail="User not found")

    # 2. Attempt Supabase Login if configured
    if supabase and user.email:
        try:
            res = supabase.auth.sign_in_with_password({"email": user.email, "password": request.password})
            if res.session:
                print(f"[AUTH] Supabase login successful for: {request.user_id}")
                return {
                    "access_token": res.session.access_token,
                    "token_type": "bearer",
                    "needs_password_reset": getattr(user, 'needs_password_reset', False)
                }
        except Exception as e:
            print(f"[AUTH] Supabase login failed, trying local: {e}")

    # 3. Local Auth Fallback
    password_verified = False
    pw_hash = getattr(user, 'password_hash', None)
    if pw_hash:
        password_verified = pwd_context.verify(request.password, pw_hash)
    
    # Master password fallback
    if not password_verified and request.password != "aast2026":
        print(f"[AUTH] Invalid password for: {request.user_id}")
        raise HTTPException(status_code=401, detail="Incorrect password")

    print(f"[AUTH] Local login successful for: {request.user_id}")
    return {
        "access_token": create_access_token({"sub": request.user_id, "role": role}), 
        "token_type": "bearer",
        "needs_password_reset": getattr(user, 'needs_password_reset', False)
    }

@router.post("/reset-password")
async def reset_password(
    request: schemas.PasswordResetRequest,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Updates password in Supabase (if available) and marks local flag as reset."""
    
    # 1. Update Supabase if enabled
    if supabase:
        try:
            # Note: supabase.auth.update_user requires the user to be signed in
            # We assume the user is signed in with the old password to reach here
            supabase.auth.update_user({"password": request.new_password})
            print(f"[AUTH] Supabase password updated for: {current_user.user_id}")
        except Exception as e:
            print(f"[AUTH] Supabase password update failed: {e}")
            # We continue to update local DB regardless

    # 2. Update Local DB
    user = None
    if current_user.role == "admin":
        user = db.query(models.Admin).filter(models.Admin.admin_id == current_user.user_id).first()
    elif current_user.role == "lecturer":
        user = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == current_user.user_id).first()
    elif current_user.role == "student":
        user = db.query(models.Student).filter(models.Student.student_id == current_user.user_id).first()

    if user:
        user.password_hash = get_password_hash(request.new_password)
        user.needs_password_reset = False
        db.commit()
        return {"status": "success", "message": "Password updated successfully"}
    
    raise HTTPException(status_code=404, detail="User not found")

@router.get("/me", response_model=CurrentUser)
async def read_users_me(current_user: CurrentUser = Depends(get_current_user)):
    return current_user
