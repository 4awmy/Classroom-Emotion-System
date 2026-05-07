import time
import os
from fastapi.testclient import TestClient
from main import app
from database import SessionLocal
from models import EmotionLog, AttendanceLog

# Ensure camera URL points to a real image for the pipeline
os.environ["CLASSROOM_CAMERA_URL"] = "data/snapshots/TEST_PHASE3/999999999.jpg"

client = TestClient(app)

def run_integration_test():
    lecture_id = "REAL_INTEGRATION_TEST"
    
    print(f"Starting session for {lecture_id}...")
    response = client.post("/session/start", json={
        "lecture_id": lecture_id,
        "lecturer_id": "L001",
        "title": "Integration Test",
        "subject": "Vision",
        "slide_url": "http://example.com/test.pdf"
    })
    
    print("API Response:", response.json())
    
    if response.status_code == 200:
        print("Waiting 25 seconds for vision and whisper pipelines to process...")
        time.sleep(25)
        
        print("Ending session...")
        client.post("/session/end", json={"lecture_id": lecture_id})
        
        # Verify Database
        db = SessionLocal()
        emotions = db.query(EmotionLog).filter(EmotionLog.lecture_id == lecture_id).all()
        attendance = db.query(AttendanceLog).filter(AttendanceLog.lecture_id == lecture_id).all()
        
        print(f"\nResults in Database:")
        print(f"Emotions captured: {len(emotions)}")
        print(f"Attendance marked: {len(attendance)}")
        
        if emotions:
            for log in emotions:
                print(f" - Student {log.student_id}: {log.emotion} (Score: {log.engagement_score})")
        
        db.close()
    else:
        print("Failed to start session.")

if __name__ == "__main__":
    run_integration_test()
