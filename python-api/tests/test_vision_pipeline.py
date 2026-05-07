import cv2
import numpy as np
import threading
import time
from services.vision_pipeline import run_pipeline
from database import SessionLocal, engine
from models import Student, EmotionLog, AttendanceLog, Base

def test_pipeline_logic():
    # We'll use the existing DB with the seeded face
    print("Starting pipeline test with existing DB...")
    stop_event = threading.Event()
    
    # Using webcam source 0
    t = threading.Thread(target=run_pipeline, args=("TEST_L", "0", stop_event))
    t.daemon = True
    t.start()
    
    # We seeded student 999999999 in earlier steps, let's use that if possible
    # but the test logic below just checks for ANY logs.
    time.sleep(20) # Give it time to run a few loops
    stop_event.set()
    t.join(timeout=5)
    
    # 3. Verify results
    db = SessionLocal()
    emotions = db.query(EmotionLog).all()
    attendance = db.query(AttendanceLog).all()
    print(f"Emotions captured: {len(emotions)}")
    print(f"Attendance marked: {len(attendance)}")
    db.close()

if __name__ == "__main__":
    test_pipeline_logic()
