from sqlalchemy import create_engine, Column, Integer, String, Float
from sqlalchemy.orm import declarative_base, sessionmaker

# Define the SQLite database file
SQLALCHEMY_DATABASE_URL = "sqlite:///./classroom_emotions.db"

# Create the SQLAlchemy engine
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# Create a SessionLocal class for database sessions
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create a Base class for the models
Base = declarative_base()

# Define the Emotion Database Model based on the PDF requirements
class EmotionRecord(Base):
    __tablename__ = "emotion_records"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(String, index=True)
    time = Column(String)  # Storing as string for simplicity (e.g., "10:05")
    emotion = Column(String, index=True)
    confidence = Column(Float)
    lecture_id = Column(String, index=True)

# Create the tables in the database
Base.metadata.create_all(bind=engine)