import cv2
import numpy as np
import threading
import time
import os
from services.vision_pipeline import run_pipeline
from database import SessionLocal, engine
from models import Student, EmotionLog, AttendanceLog, Base

# Mock VideoCapture to return a static image
class MockVideoCapture:
    def __init__(self, source):
        # Try to find a test image
        self.image_path = "python-api/data/snapshots/TEST_PHASE3/999999999.jpg"
        if not os.path.exists(self.image_path):
            # Create a dummy image if not found
            self.frame = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(self.frame, "Mock Frame", (100, 100), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        else:
            self.frame = cv2.imread(self.image_path)
        self.is_open = True

    def isOpened(self):
        return self.is_open

    def read(self):
        # Always return the same frame
        return True, self.frame.copy()

    def release(self):
        self.is_open = False

def test_pipeline_with_mock():
    print("Starting pipeline test with MOCK VideoCapture...")
    
    # Monkeypatch cv2.VideoCapture
    original_vc = cv2.VideoCapture
    cv2.VideoCapture = MockVideoCapture
    
    stop_event = threading.Event()
    
    # We use a real lecture ID but the camera URL is ignored by our mock
    lecture_id = "TEST_MOCK_L"
    t = threading.Thread(target=run_pipeline, args=(lecture_id, "0", stop_event))
    t.daemon = True
    t.start()
    
    print("Pipeline running for 15 seconds...")
    time.sleep(15) 
    stop_event.set()
    t.join(timeout=5)
    
    # Restore original VideoCapture
    cv2.VideoCapture = original_vc
    
    # 3. Verify results
    db = SessionLocal()
    emotions = db.query(EmotionLog).filter(EmotionLog.lecture_id == lecture_id).all()
    attendance = db.query(AttendanceLog).filter(AttendanceLog.lecture_id == lecture_id).all()
    
    print(f"\nResults for {lecture_id}:")
    print(f"Emotions captured: {len(emotions)}")
    print(f"Attendance marked: {len(attendance)}")
    
    if emotions:
        last_log = emotions[-1]
        print(f"Last Emotion: {last_log.emotion} (Raw: {last_log.raw_emotion}, Score: {last_log.raw_confidence})")
    
    db.close()

if __name__ == "__main__":
    test_pipeline_with_mock()
