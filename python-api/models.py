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

class Lecture(Base):
    __tablename__ = "lectures"
    lecture_id = Column(String, primary_key=True)
    lecturer_id = Column(String, nullable=False)
    title = Column(String)
    subject = Column(String)
    start_time = Column(DateTime, default=datetime.datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    slide_url = Column(String)

    # Relationships
    emotions = relationship("EmotionLog", back_populates="lecture")
    attendance = relationship("AttendanceLog", back_populates="lecture")
    materials = relationship("Material", back_populates="lecture")
    transcripts = relationship("Transcript", back_populates="lecture")
    notifications = relationship("Notification", back_populates="lecture")
    focus_strikes = relationship("FocusStrike", back_populates="lecture")

class EmotionLog(Base):
    __tablename__ = "emotion_log"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    emotion = Column(String, nullable=False)  # Focused | Engaged | Confused | Anxious | Frustrated | Disengaged
    confidence = Column(Float, nullable=False)
    engagement_score = Column(Float, nullable=False)

    # Relationships
    student = relationship("Student", back_populates="emotions")
    lecture = relationship("Lecture", back_populates="emotions")

class AttendanceLog(Base):
    __tablename__ = "attendance_log"
    id            = Column(Integer, primary_key=True, index=True, autoincrement=True)
    student_id    = Column(String, ForeignKey("students.student_id"), nullable=False)
    lecture_id    = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp     = Column(DateTime, default=datetime.datetime.utcnow)
    status        = Column(String, nullable=False)  # Present | Absent
    method        = Column(String, nullable=False)  # AI | Manual | QR

    # Relationships
    student = relationship("Student", back_populates="attendance")
    lecture = relationship("Lecture", back_populates="attendance")
    evidence = relationship("AttendanceEvidence", back_populates="attendance", uselist=False)

class AttendanceEvidence(Base):
    __tablename__ = "attendance_evidence"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    attendance_id = Column(Integer, ForeignKey("attendance_log.id"), nullable=False)
    snapshot_path = Column(String, nullable=False)  # Path to face ROI crop

    # Relationships
    attendance = relationship("AttendanceLog", back_populates="evidence")

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

class Transcript(Base):
    __tablename__ = "transcripts"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    lecture_id = Column(String, ForeignKey("lectures.lecture_id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    chunk_text = Column(String, nullable=False)
    language = Column(String)  # ar | en | mixed

    # Relationships
    lecture = relationship("Lecture", back_populates="transcripts")

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
