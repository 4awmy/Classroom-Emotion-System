import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# Load environment variables
load_dotenv()

# Hybrid Setup: Local PostgreSQL for Data
# DATABASE_URL should point to localhost (Docker)
DATABASE_URL = os.getenv("LOCAL_DATABASE_URL", "postgresql://postgres:password123@localhost:5432/classroom_emotions")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class Base(DeclarativeBase):
    pass

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
