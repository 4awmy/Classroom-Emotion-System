from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import List, Optional
from datetime import datetime

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    student_id: Optional[str] = None
    role: Optional[str] = None

class UserLogin(BaseModel):
    student_id: str = Field(..., json_schema_extra={"example": "231006367"})
    password: str = Field(..., json_schema_extra={"example": "password123"})

class StudentBase(BaseModel):
    student_id: str
    name: str
    email: Optional[EmailStr] = None

class StudentCreate(StudentBase):
    face_encoding: Optional[bytes] = None

class StudentResponse(StudentBase):
    enrolled_at: datetime
    model_config = ConfigDict(from_attributes=True)

class StudentListResponse(StudentBase):
    has_encoding: bool
    model_config = ConfigDict(from_attributes=True)

class StudentUploadResponse(BaseModel):
    student_id: str
    name: str
    encoding_saved: bool

class LectureBase(BaseModel):
    lecture_id: str
    lecturer_id: str
    title: str
    subject: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    slide_url: Optional[str] = None

class LectureResponse(LectureBase):
    model_config = ConfigDict(from_attributes=True)

class EmotionLogBase(BaseModel):
    student_id: str
    lecture_id: str
    raw_emotion: Optional[str] = None       # HSEmotion raw label: happy | neutral | sad | anger | fear | disgust | surprise
    raw_confidence: Optional[float] = None  # Model softmax score — actual detection certainty (0.0–1.0)
    emotion: str                            # Mapped educational state: Focused | Engaged | Confused | Anxious | Frustrated | Disengaged
    confidence: float                       # Fixed engagement weight per state (CLAUDE.md §8.2)
    engagement_score: float                 # == confidence

class EmotionLogCreate(EmotionLogBase):
    timestamp: Optional[datetime] = None

class EmotionLogResponse(EmotionLogBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)

class AttendanceLogBase(BaseModel):
    student_id: str
    lecture_id: str
    status: str
    method: str

class AttendanceLogResponse(AttendanceLogBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)

# student_id and exam_id are nullable in the DB (incident can precede identity match)
class IncidentBase(BaseModel):
    student_id: Optional[str] = None
    exam_id: Optional[str] = None
    flag_type: str
    severity: int
    evidence_path: Optional[str] = None

class IncidentResponse(IncidentBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)

class TranscriptBase(BaseModel):
    lecture_id: str
    chunk_text: str
    language: Optional[str] = None  # ar | en | mixed

class TranscriptResponse(TranscriptBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)

class NotificationBase(BaseModel):
    student_id: str
    lecturer_id: str
    lecture_id: Optional[str] = None
    reason: str

class NotificationResponse(NotificationBase):
    id: int
    created_at: datetime
    read: int  # 0 = unread | 1 = read
    model_config = ConfigDict(from_attributes=True)

class FocusStrikeBase(BaseModel):
    student_id: str
    lecture_id: str
    strike_type: str  # app_background

class FocusStrikeResponse(FocusStrikeBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)
