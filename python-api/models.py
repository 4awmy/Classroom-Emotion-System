from sqlalchemy import Column, Integer, String, DateTime, Float, ForeignKey, BLOB
from sqlalchemy.orm import relationship
from database import Base
import datetime

class Student(Base):
    __tablename__ = "students"
    student_id = Column(String, primary_key=True)  # 9-digit AAST number
    name = Column(String, nullable=False)
    email = Column(String)
    face_encoding = Column(BLOB)  # 128-dim float64 numpy array as bytes
    enrolled_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    emotions = relationship("EmotionLog", back_populates="student")
    attendance = relationship("AttendanceLog", back_populates="student")
    incidents = relationship("Incident", back_populates="student")
    notifications = relationship("Notification", back_populates="student")
    focus_strikes = relationship("FocusStrike", back_populates="student")

class Schedule(Base):
    __tablename__ = "schedules"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    lecturer_id = Column(String, nullable=False)
    subject = Column(String, nullable=False)
    title = Column(String, nullable=False)
    day_of_week = Column(Integer, nullable=False)  # 0-6 (Monday-Sunday)
    scheduled_start = Column(String, nullable=False)  # HH:MM
    scheduled_end = Column(String, nullable=False)    # HH:MM
    classroom = Column(String)
    is_recurring = Column(Integer, default=1)  # 1 = yes, 0 = no

    # Relationships
    lectures = relationship("Lecture", back_populates="schedule")

class Lecture(Base):
    __tablename__ = "lectures"
    lecture_id = Column(String, primary_key=True)
    lecturer_id = Column(String, nullable=False)
    schedule_id = Column(Integer, ForeignKey("schedules.id"), nullable=True)
    title = Column(String)
    subject = Column(String)
    start_time = Column(DateTime, default=datetime.datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    scheduled_start_time = Column(DateTime, nullable=True)
    slide_url = Column(String)

    # Relationships
    schedule = relationship("Schedule", back_populates="lectures")
    emotions = relationship("EmotionLog", back_populates="lecture")
    attendance = relationship("AttendanceLog", back_populates="lecture")
    materials = relationship("Material", back_populates="lecture")
    notifications = relationship("Notification", back_populates="lecture")
    focus_strikes = relationship("FocusStrike", back_populates="lecture")

class EmotionLog(Base):
    __tablename__ = "emotion_log"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    raw_emotion = Column(String, nullable=True)   # HSEmotion raw label: happy | neutral | sad | angry | fear | disgust | surprise
    raw_confidence = Column(Float, nullable=True)  # Model softmax score (0.0–1.0) — how sure the model is
    emotion = Column(String, nullable=False)       # Mapped educational state: Focused | Engaged | Confused | Anxious | Frustrated | Disengaged
    confidence = Column(Float, nullable=False)     # Fixed engagement weight per state (CLAUDE.md §8.2) — NOT model confidence
    engagement_score = Column(Float, nullable=False)  # == confidence (engagement weight)

    # Relationships
    student = relationship("Student", back_populates="emotions")
    lecture = relationship("Lecture", back_populates="emotions")

class AttendanceLog(Base):
    __tablename__ = "attendance_log"
    id            = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id    = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id    = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp     = Column(DateTime, default=datetime.datetime.utcnow)
    check_in_time = Column(DateTime, default=datetime.datetime.utcnow)
    total_duration = Column(Integer, default=0)  # Total seconds present
    status        = Column(String, nullable=False)   # Present | Absent
    method        = Column(String, nullable=False)   # AI | Manual | QR
    snapshot_path = Column(String, nullable=True)    # Path to face ROI crop: data/snapshots/{lecture_id}/{student_id}.jpg

    # Relationships
    student = relationship("Student", back_populates="attendance")
    lecture = relationship("Lecture", back_populates="attendance")

class Material(Base):
    __tablename__ = "materials"
    material_id = Column(String, primary_key=True)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    lecturer_id = Column(String, nullable=False)
    title = Column(String, nullable=False)
    drive_link = Column(String)
    uploaded_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relationships
    lecture = relationship("Lecture", back_populates="materials")

class Incident(Base):
    __tablename__ = "incidents"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"))
    exam_id = Column(String)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    flag_type = Column(String, nullable=False)
    severity = Column(Integer, nullable=False)  # 1 low | 2 medium | 3 high
    evidence_path = Column(String)

    # Relationships
    student = relationship("Student", back_populates="incidents")

class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecturer_id = Column(String, nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"))
    reason = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    read = Column(Integer, default=0)  # 0 = unread | 1 = read

    # Relationships
    student = relationship("Student", back_populates="notifications")
    lecture = relationship("Lecture", back_populates="notifications")

class FocusStrike(Base):
    __tablename__ = "focus_strikes"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    strike_type = Column(String, nullable=False)  # app_background

    # Relationships
    student = relationship("Student", back_populates="focus_strikes")
    lecture = relationship("Lecture", back_populates="focus_strikes")
