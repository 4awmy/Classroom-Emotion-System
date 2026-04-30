from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional
from datetime import datetime

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    student_id: Optional[str] = None
    role: Optional[str] = None

class UserLogin(BaseModel):
    student_id: str = Field(..., example="231006367")
    password: str = Field(..., example="password123")

class StudentBase(BaseModel):
    student_id: str
    name: str
    email: Optional[EmailStr] = None

class StudentCreate(StudentBase):
    face_encoding: Optional[bytes] = None

class StudentResponse(StudentBase):
    enrolled_at: datetime

    class Config:
        from_attributes = True

class LectureBase(BaseModel):
    lecture_id: str
    lecturer_id: str
    title: str
    subject: str
    start_time: datetime
    end_time: Optional[datetime] = None
    slide_url: Optional[str] = None

class LectureResponse(LectureBase):
    class Config:
        from_attributes = True

class EmotionLogBase(BaseModel):
    student_id: str
    lecture_id: str
    emotion: str
    confidence: float
    engagement_score: float

class EmotionLogCreate(EmotionLogBase):
    timestamp: Optional[datetime] = None

class EmotionLogResponse(EmotionLogBase):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True

class AttendanceLogBase(BaseModel):
    student_id: str
    lecture_id: str
    status: str
    method: str

class AttendanceLogResponse(AttendanceLogBase):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True

class IncidentBase(BaseModel):
    student_id: str
    exam_id: str
    flag_type: str
    severity: int
    evidence_path: Optional[str] = None

class IncidentResponse(IncidentBase):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True
