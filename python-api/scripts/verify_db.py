import sys
import os

# Add the python-api/ parent directory to sys.path to import local modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import engine
import models
from sqlalchemy import inspect

def verify_db():
    print("Creating tables...")
    models.Base.metadata.create_all(bind=engine)
    
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    
    expected_tables = [
        "students", "lectures", "emotion_log", "attendance_log", 
        "materials", "incidents", "transcripts", "notifications", "focus_strikes"
    ]
    
    print(f"Found tables: {tables}")
    
    missing = [t for t in expected_tables if t not in tables]
    if missing:
        print(f"MISSING TABLES: {missing}")
        sys.exit(1)
    else:
        print("All expected tables are present.")

if __name__ == "__main__":
    verify_db()
