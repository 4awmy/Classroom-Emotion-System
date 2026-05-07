import time
import os
from fastapi.testclient import TestClient
from main import app
from database import SessionLocal
from models import EmotionLog, AttendanceLog, Incident

# Ensure camera URL points to a real image for the pipeline
# This image contains a person and a face
os.environ["CLASSROOM_CAMERA_URL"] = "data/snapshots/TEST_PHASE3/999999999.jpg"

client = TestClient(app)

def run_exam_integration_test():
    lecture_id = "EXAM_INTEGRATION_TEST"
    exam_id = "EXAM_001"
    
    print(f"Starting PROCTORED EXAM session for {lecture_id}...")
    # Note: We added context and exam_id to the router
    response = client.post("/session/start", json={
        "lecture_id": lecture_id,
        "lecturer_id": "L001",
        "title": "Proctored Final",
        "subject": "AI",
        "slide_url": "http://example.com/exam.pdf",
        "context": "exam",
        "exam_id": exam_id
    })
    
    print("API Response:", response.json())
    
    if response.status_code == 200:
        print("Waiting 20 seconds for proctoring pipeline to process...")
        # Give it time for multiple frames (1 per 5s)
        time.sleep(20)
        
        print("Ending session...")
        client.post("/session/end", json={"lecture_id": lecture_id})
        
        # Verify Database
        db = SessionLocal()
        emotions = db.query(EmotionLog).filter(EmotionLog.lecture_id == lecture_id).all()
        attendance = db.query(AttendanceLog).filter(AttendanceLog.lecture_id == lecture_id).all()
        incidents = db.query(Incident).filter(Incident.exam_id == exam_id).all()
        
        print(f"\nResults for {lecture_id} (Exam: {exam_id}):")
        print(f"Emotions captured: {len(emotions)}")
        print(f"Attendance marked: {len(attendance)}")
        print(f"Incidents logged:  {len(incidents)}")
        
        if incidents:
            for inc in incidents:
                print(f" - Incident: {inc.flag_type} (Severity: {inc.severity}) at {inc.timestamp}")
        
        db.close()
    else:
        print(f"Failed to start session: {response.text}")

if __name__ == "__main__":
    run_exam_integration_test()
