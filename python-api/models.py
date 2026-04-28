from sqlalchemy import Column, Integer, String, DateTime, Float, ForeignKey, BLOB
from sqlalchemy.orm import relationship
from database import Base
import datetime

class Student(Base):
    __tablename__ = "students"
    student_id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    email = Column(String)
    face_encoding = Column(BLOB)  # 128-dim float64 numpy array as bytes
    enrolled_at = Column(DateTime, default=datetime.datetime.utcnow)

class Lecture(Base):
    __tablename__ = "lectures"
    lecture_id = Column(String, primary_key=True)
    lecturer_id = Column(String, nullable=False)
    title = Column(String)
    subject = Column(String)
    start_time = Column(DateTime, default=datetime.datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    slide_url = Column(String)

class EmotionLog(Base):
    __tablename__ = "emotion_log"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    emotion = Column(String, nullable=False)  # Focused | Engaged | Confused | Anxious | Frustrated | Disengaged
    confidence = Column(Float, nullable=False)
    engagement_score = Column(Float, nullable=False)

class AttendanceLog(Base):
    __tablename__ = "attendance_log"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    status = Column(String, nullable=False)  # Present | Absent
    method = Column(String, nullable=False)  # AI | Manual | QR

class Material(Base):
    __tablename__ = "materials"
    material_id = Column(String, primary_key=True)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    lecturer_id = Column(String, nullable=False)
    title = Column(String, nullable=False)
    drive_link = Column(String)
    uploaded_at = Column(DateTime, default=datetime.datetime.utcnow)

class Incident(Base):
    __tablename__ = "incidents"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"))
    exam_id = Column(String)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    flag_type = Column(String, nullable=False)
    severity = Column(Integer, nullable=False)  # 1 low | 2 medium | 3 high
    evidence_path = Column(String)

class Transcript(Base):
    __tablename__ = "transcripts"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    chunk_text = Column(String, nullable=False)
    language = Column(String)

class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecturer_id = Column(String, nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"))
    reason = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    read = Column(Integer, default=0)  # 0 = unread | 1 = read

class FocusStrike(Base):
    __tablename__ = "focus_strikes"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    strike_type = Column(String, nullable=False)  # app_background
