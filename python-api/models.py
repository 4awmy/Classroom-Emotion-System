from sqlalchemy import String, Integer, Float, Boolean, Time, DateTime, ForeignKey, BigInteger, LargeBinary, Uuid
from sqlalchemy.orm import relationship, Mapped, mapped_column
from sqlalchemy.sql import func
from database import Base
import datetime
from typing import List, Optional
import uuid

class Admin(Base):
    __tablename__ = "admins"
    admin_id: Mapped[str] = mapped_column(String, primary_key=True)
    auth_user_id: Mapped[uuid.UUID] = mapped_column(Uuid, unique=True, nullable=False) # Linked to Supabase
    name: Mapped[str] = mapped_column(String, nullable=False)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    needs_password_reset: Mapped[bool] = mapped_column(Boolean, default=True) # NEW: For first-time reset
    phone: Mapped[Optional[str]] = mapped_column(String)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class Lecturer(Base):
    __tablename__ = "lecturers"
    lecturer_id: Mapped[str] = mapped_column(String, primary_key=True)
    auth_user_id: Mapped[uuid.UUID] = mapped_column(Uuid, unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    needs_password_reset: Mapped[bool] = mapped_column(Boolean, default=True) # NEW
    department: Mapped[Optional[str]] = mapped_column(String)
    title: Mapped[Optional[str]] = mapped_column(String)
    phone: Mapped[Optional[str]] = mapped_column(String)
    photo_url: Mapped[Optional[str]] = mapped_column(String)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    classes: Mapped[List["Class"]] = relationship(back_populates="lecturer")
    lectures: Mapped[List["Lecture"]] = relationship(back_populates="lecturer")
    materials: Mapped[List["Material"]] = relationship(back_populates="lecturer")
    notifications: Mapped[List["Notification"]] = relationship(back_populates="lecturer")

class Student(Base):
    __tablename__ = "students"
    student_id: Mapped[str] = mapped_column(String, primary_key=True)
    auth_user_id: Mapped[uuid.UUID] = mapped_column(Uuid, unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    email: Mapped[Optional[str]] = mapped_column(String)
    needs_password_reset: Mapped[bool] = mapped_column(Boolean, default=True) # NEW
    department: Mapped[Optional[str]] = mapped_column(String)
    year: Mapped[Optional[int]] = mapped_column(Integer)
    face_encoding: Mapped[Optional[bytes]] = mapped_column(LargeBinary) # Stored as BYTEA in Postgres
    photo_url: Mapped[Optional[str]] = mapped_column(String)
    enrolled_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    enrollments: Mapped[List["Enrollment"]] = relationship(back_populates="student")
    emotion_logs: Mapped[List["EmotionLog"]] = relationship(back_populates="student")
    attendance_logs: Mapped[List["AttendanceLog"]] = relationship(back_populates="student")
    incidents: Mapped[List["Incident"]] = relationship(back_populates="student")
    notifications: Mapped[List["Notification"]] = relationship(back_populates="student")
    focus_strikes: Mapped[List["FocusStrike"]] = relationship(back_populates="student")

class Course(Base):
    __tablename__ = "courses"
    course_id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    department: Mapped[Optional[str]] = mapped_column(String)
    credit_hours: Mapped[Optional[int]] = mapped_column(Integer)
    semester: Mapped[Optional[str]] = mapped_column(String)
    year: Mapped[Optional[int]] = mapped_column(Integer)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    classes: Mapped[List["Class"]] = relationship(back_populates="course")

class Class(Base):
    __tablename__ = "classes"
    class_id: Mapped[str] = mapped_column(String, primary_key=True)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.course_id", ondelete="CASCADE"))
    lecturer_id: Mapped[Optional[str]] = mapped_column(ForeignKey("lecturers.lecturer_id", ondelete="SET NULL"))
    section_name: Mapped[Optional[str]] = mapped_column(String)
    room: Mapped[Optional[str]] = mapped_column(String)
    semester: Mapped[Optional[str]] = mapped_column(String)
    year: Mapped[Optional[int]] = mapped_column(Integer)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    course: Mapped["Course"] = relationship(back_populates="classes")
    lecturer: Mapped[Optional["Lecturer"]] = relationship(back_populates="classes")
    schedules: Mapped[List["ClassSchedule"]] = relationship(back_populates="class_")
    enrollments: Mapped[List["Enrollment"]] = relationship(back_populates="class_")
    lectures: Mapped[List["Lecture"]] = relationship(back_populates="class_")
    exams: Mapped[List["Exam"]] = relationship(back_populates="class_")

class ClassSchedule(Base):
    __tablename__ = "class_schedule"
    schedule_id: Mapped[str] = mapped_column(String, primary_key=True)
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.class_id", ondelete="CASCADE"))
    day_of_week: Mapped[str] = mapped_column(String, nullable=False)
    start_time: Mapped[datetime.time] = mapped_column(Time, nullable=False)
    end_time: Mapped[datetime.time] = mapped_column(Time, nullable=False)

    class_: Mapped["Class"] = relationship(back_populates="schedules")

class Enrollment(Base):
    __tablename__ = "enrollments"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.class_id", ondelete="CASCADE"))
    student_id: Mapped[str] = mapped_column(ForeignKey("students.student_id", ondelete="CASCADE"))
    enrolled_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    class_: Mapped["Class"] = relationship(back_populates="enrollments")
    student: Mapped["Student"] = relationship(back_populates="enrollments")

class Lecture(Base):
    __tablename__ = "lectures"
    lecture_id: Mapped[str] = mapped_column(String, primary_key=True)
    class_id: Mapped[Optional[str]] = mapped_column(ForeignKey("classes.class_id"), nullable=True)
    lecturer_id: Mapped[str] = mapped_column(ForeignKey("lecturers.lecturer_id"))
    title: Mapped[Optional[str]] = mapped_column(String)
    session_type: Mapped[Optional[str]] = mapped_column(String, server_default="lecture")
    start_time: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True))
    end_time: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True))
    scheduled_start: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True))
    scheduled_end: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True)) # Added for early exit calculation
    actual_start_time: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True))
    actual_end_time: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True))
    total_frames_captured: Mapped[int] = mapped_column(Integer, server_default="0")
    expected_frames_count: Mapped[int] = mapped_column(Integer, server_default="0")
    slide_url: Mapped[Optional[str]] = mapped_column(String)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    class_: Mapped["Class"] = relationship(back_populates="lectures")
    lecturer: Mapped["Lecturer"] = relationship(back_populates="lectures")
    exams: Mapped[List["Exam"]] = relationship(back_populates="lecture")
    materials: Mapped[List["Material"]] = relationship(back_populates="lecture")
    emotion_logs: Mapped[List["EmotionLog"]] = relationship(back_populates="lecture")
    attendance_logs: Mapped[List["AttendanceLog"]] = relationship(back_populates="lecture")
    notifications: Mapped[List["Notification"]] = relationship(back_populates="lecture")
    focus_strikes: Mapped[List["FocusStrike"]] = relationship(back_populates="lecture")

class Exam(Base):
    __tablename__ = "exams"
    exam_id: Mapped[str] = mapped_column(String, primary_key=True)
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.class_id"))
    lecture_id: Mapped[Optional[str]] = mapped_column(ForeignKey("lectures.lecture_id"))
    title: Mapped[str] = mapped_column(String, nullable=False)
    scheduled_start: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True))
    end_time: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime(timezone=True))
    auto_submit: Mapped[Optional[bool]] = mapped_column(Boolean, server_default="true")
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    class_: Mapped["Class"] = relationship(back_populates="exams")
    lecture: Mapped[Optional["Lecture"]] = relationship(back_populates="exams")

class Material(Base):
    __tablename__ = "materials"
    material_id: Mapped[str] = mapped_column(String, primary_key=True)
    lecture_id: Mapped[str] = mapped_column(ForeignKey("lectures.lecture_id"))
    lecturer_id: Mapped[str] = mapped_column(ForeignKey("lecturers.lecturer_id"))
    title: Mapped[str] = mapped_column(String, nullable=False)
    drive_link: Mapped[Optional[str]] = mapped_column(String)
    uploaded_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    lecture: Mapped["Lecture"] = relationship(back_populates="materials")
    lecturer: Mapped["Lecturer"] = relationship(back_populates="materials")

class EmotionLog(Base):
    __tablename__ = "emotion_log"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    student_id: Mapped[str] = mapped_column(ForeignKey("students.student_id"))
    lecture_id: Mapped[str] = mapped_column(ForeignKey("lectures.lecture_id"))
    timestamp: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    emotion: Mapped[str] = mapped_column(String, nullable=False)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    engagement_score: Mapped[float] = mapped_column(Float, nullable=False)

    student: Mapped["Student"] = relationship(back_populates="emotion_logs")
    lecture: Mapped["Lecture"] = relationship(back_populates="emotion_logs")

class AttendanceLog(Base):
    __tablename__ = "attendance_log"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    student_id: Mapped[str] = mapped_column(ForeignKey("students.student_id"))
    lecture_id: Mapped[str] = mapped_column(ForeignKey("lectures.lecture_id"))
    timestamp: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    status: Mapped[str] = mapped_column(String, nullable=False)
    method: Mapped[str] = mapped_column(String, nullable=False)

    student: Mapped["Student"] = relationship(back_populates="attendance_logs")
    lecture: Mapped["Lecture"] = relationship(back_populates="attendance_logs")

class Incident(Base):
    __tablename__ = "incidents"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    student_id: Mapped[Optional[str]] = mapped_column(ForeignKey("students.student_id"))
    exam_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    timestamp: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    flag_type: Mapped[str] = mapped_column(String, nullable=False)
    severity: Mapped[int] = mapped_column(Integer, nullable=False)
    evidence_path: Mapped[Optional[str]] = mapped_column(String)

    student: Mapped[Optional["Student"]] = relationship(back_populates="incidents")

class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    student_id: Mapped[Optional[str]] = mapped_column(ForeignKey("students.student_id"))
    lecturer_id: Mapped[str] = mapped_column(ForeignKey("lecturers.lecturer_id"))
    lecture_id_fk: Mapped[Optional[str]] = mapped_column(ForeignKey("lectures.lecture_id"))
    reason: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    read: Mapped[Optional[bool]] = mapped_column(Boolean, server_default="false")

    student: Mapped[Optional["Student"]] = relationship(back_populates="notifications")
    lecturer: Mapped["Lecturer"] = relationship(back_populates="notifications")
    lecture: Mapped[Optional["Lecture"]] = relationship(back_populates="notifications")

class FocusStrike(Base):
    __tablename__ = "focus_strikes"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    student_id: Mapped[str] = mapped_column(ForeignKey("students.student_id"))
    lecture_id: Mapped[str] = mapped_column(ForeignKey("lectures.lecture_id"))
    timestamp: Mapped[datetime.datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    strike_type: Mapped[str] = mapped_column(String, nullable=False)

    student: Mapped["Student"] = relationship(back_populates="focus_strikes")
    lecture: Mapped["Lecture"] = relationship(back_populates="focus_strikes")
