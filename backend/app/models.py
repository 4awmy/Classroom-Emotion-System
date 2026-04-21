from sqlalchemy import Column, Integer, String, DateTime, Float, ForeignKey
from .database import Base
import datetime

class LectureSession(Base):
    __tablename__ = "lecture_sessions"
    id = Column(Integer, primary_key=True, index=True)
    lecture_name = Column(String)
    start_time = Column(DateTime, default=datetime.datetime.utcnow)
    end_time = Column(DateTime, nullable=True)

class EmotionLog(Base):
    __tablename__ = "emotions_log"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(String)
    time = Column(DateTime, default=datetime.datetime.utcnow)
    emotion = Column(String)
    confidence = Column(Float)
    lecture_id = Column(Integer, ForeignKey("lecture_sessions.id"))
