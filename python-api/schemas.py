from pydantic import BaseModel, EmailStr, ConfigDict
from typing import List, Optional
from datetime import datetime, time
import uuid

# Admin
class AdminBase(BaseModel):
    admin_id: str
    name: str
    email: EmailStr
    phone: Optional[str] = None

class AdminCreate(AdminBase):
    auth_user_id: Optional[str] = None
    password: Optional[str] = None # Added for local auth

class AdminUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: Optional[str] = None

class AdminResponse(AdminBase):
    auth_user_id: Optional[str] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Lecturer
class LecturerBase(BaseModel):
    lecturer_id: str
    name: str
    email: EmailStr
    department: Optional[str] = None
    title: Optional[str] = None
    phone: Optional[str] = None
    photo_url: Optional[str] = None

class LecturerCreate(LecturerBase):
    auth_user_id: Optional[str] = None
    password: Optional[str] = None # Added for local auth

class LecturerUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    department: Optional[str] = None
    title: Optional[str] = None
    phone: Optional[str] = None
    photo_url: Optional[str] = None
    password: Optional[str] = None

class LecturerResponse(LecturerBase):
    auth_user_id: Optional[str] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Student
class StudentBase(BaseModel):
    student_id: str
    name: str
    email: Optional[EmailStr] = None
    department: Optional[str] = None
    year: Optional[int] = None
    photo_url: Optional[str] = None

class StudentCreate(StudentBase):
    auth_user_id: Optional[str] = None
    password: Optional[str] = None # Added for local auth
    face_encoding: Optional[bytes] = None

class StudentUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    department: Optional[str] = None
    year: Optional[int] = None
    photo_url: Optional[str] = None
    face_encoding: Optional[bytes] = None
    password: Optional[str] = None

class StudentResponse(StudentBase):
    auth_user_id: Optional[str] = None
    enrolled_at: datetime
    model_config = ConfigDict(from_attributes=True)

class StudentListResponse(StudentBase):
    has_encoding: bool = False
    model_config = ConfigDict(from_attributes=True)

class StudentUploadResponse(BaseModel):
    student_id: str
    name: str
    encoding_saved: bool

# Course
class CourseBase(BaseModel):
    course_id: str
    title: str
    department: Optional[str] = None
    credit_hours: Optional[int] = None
    semester: Optional[str] = None
    year: Optional[int] = None

class CourseCreate(CourseBase):
    pass

class CourseUpdate(BaseModel):
    title: Optional[str] = None
    department: Optional[str] = None
    credit_hours: Optional[int] = None
    semester: Optional[str] = None
    year: Optional[int] = None

class CourseResponse(CourseBase):
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Class
class ClassBase(BaseModel):
    class_id: str
    course_id: str
    lecturer_id: Optional[str] = None
    section_name: Optional[str] = None
    room: Optional[str] = None
    semester: Optional[str] = None
    year: Optional[int] = None

class ClassCreate(ClassBase):
    pass

class ClassUpdate(BaseModel):
    lecturer_id: Optional[str] = None
    section_name: Optional[str] = None
    room: Optional[str] = None
    semester: Optional[str] = None
    year: Optional[int] = None

class ClassResponse(ClassBase):
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# ClassSchedule
class ClassScheduleBase(BaseModel):
    schedule_id: str
    class_id: str
    day_of_week: str
    start_time: time
    end_time: time

class ClassScheduleCreate(ClassScheduleBase):
    pass

class ClassScheduleUpdate(BaseModel):
    day_of_week: Optional[str] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None

class ClassScheduleResponse(ClassScheduleBase):
    model_config = ConfigDict(from_attributes=True)

# Enrollment
class EnrollmentBase(BaseModel):
    class_id: str
    student_id: str

class EnrollmentCreate(EnrollmentBase):
    pass

class EnrollmentUpdate(BaseModel):
    class_id: Optional[str] = None
    student_id: Optional[str] = None

class EnrollmentResponse(EnrollmentBase):
    id: int
    enrolled_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Lecture
class LectureBase(BaseModel):
    lecture_id: str
    class_id: str
    lecturer_id: str
    title: Optional[str] = None
    session_type: Optional[str] = "lecture"
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    scheduled_start: Optional[datetime] = None
    slide_url: Optional[str] = None

class LectureCreate(LectureBase):
    pass

class LectureResponse(LectureBase):
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Exam
class ExamBase(BaseModel):
    exam_id: str
    class_id: str
    lecture_id: Optional[str] = None
    title: str
    scheduled_start: Optional[datetime] = None
    end_time: Optional[datetime] = None
    auto_submit: Optional[bool] = True

class ExamCreate(ExamBase):
    pass

class ExamResponse(ExamBase):
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Material
class MaterialBase(BaseModel):
    material_id: str
    lecture_id: str
    lecturer_id: str
    title: str
    drive_link: Optional[str] = None

class MaterialCreate(MaterialBase):
    pass

class MaterialResponse(MaterialBase):
    uploaded_at: datetime
    model_config = ConfigDict(from_attributes=True)

# EmotionLog
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
    model_config = ConfigDict(from_attributes=True)

# AttendanceLog
class AttendanceLogBase(BaseModel):
    student_id: str
    lecture_id: str
    status: str
    method: str

class AttendanceLogCreate(AttendanceLogBase):
    timestamp: Optional[datetime] = None

class AttendanceLogResponse(AttendanceLogBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)

# Incident
class IncidentBase(BaseModel):
    student_id: Optional[str] = None
    exam_id: str
    flag_type: str
    severity: int
    evidence_path: Optional[str] = None

class IncidentCreate(IncidentBase):
    timestamp: Optional[datetime] = None

class IncidentResponse(IncidentBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)

# Notification
class NotificationBase(BaseModel):
    student_id: Optional[str] = None
    lecturer_id: str
    lecture_id: Optional[str] = None
    reason: str

class NotificationCreate(NotificationBase):
    pass

class NotificationResponse(NotificationBase):
    id: int
    created_at: datetime
    read: Optional[bool] = False
    model_config = ConfigDict(from_attributes=True)

# FocusStrike
class FocusStrikeBase(BaseModel):
    student_id: str
    lecture_id: str
    strike_type: str

class FocusStrikeCreate(FocusStrikeBase):
    timestamp: Optional[datetime] = None

class FocusStrikeResponse(FocusStrikeBase):
    id: int
    timestamp: datetime
    model_config = ConfigDict(from_attributes=True)
