import cv2
import numpy as np
import threading
import time
import os
import sys

# Ensure we can import from the current directory
sys.path.append("python-api")

from services.vision_pipeline import run_pipeline
from database import SessionLocal
from models import Incident

def test_proctoring_logic():
    print("Starting PROCTORING test (Context: exam)...")
    print("This will test: Phone Detection, Head Rotation, and Multiple Persons.")
    print("\n--- INSTRUCTIONS ---")
    print("1. Look straight for a few seconds.")
    print("2. Turn your head extremely left/right or up/down.")
    print("3. Show your phone to the camera.")
    print("4. (Optional) Have someone else appear in the frame.")
    print("---------------------\n")
    
    stop_event = threading.Event()
    
    # Using webcam source 0, context 'exam', exam_id 'EXAM_TEST'
    t = threading.Thread(target=run_pipeline, args=("LECT_TEST", "0", stop_event, "exam", "EXAM_TEST"))
    t.daemon = True
    t.start()
    
    # Run for 30 seconds to allow for multiple checks
    print("Pipeline is running in the background. Monitoring incidents...")
    for i in range(30, 0, -1):
        # Periodically check database for new incidents to show live-ish feedback
        db = SessionLocal()
        count = db.query(Incident).filter(Incident.exam_id == "EXAM_TEST").count()
        sys.stdout.write(f"\rTesting... {i}s remaining | Incidents found: {count}")
        sys.stdout.flush()
        db.close()
        time.sleep(1)
    print("\nStopping pipeline...")
    
    stop_event.set()
    t.join(timeout=5)
    
    # 3. Verify results
    db = SessionLocal()
    incidents = db.query(Incident).filter(Incident.exam_id == "EXAM_TEST").all()
    print(f"\nProctoring Results for EXAM_TEST:")
    print(f"Total incidents logged: {len(incidents)}")
    
    for inc in incidents:
        print(f"- [{inc.timestamp}] {inc.flag_type} (Severity {inc.severity})")
    
    # Check if evidence was saved
    evidence_dir = os.path.join("data", "evidence")
    if os.path.exists(evidence_dir):
        evidence_files = [f for f in os.listdir(evidence_dir) if f.startswith("EXAM_TEST")]
        print(f"New evidence files for this test: {len(evidence_files)}")
        for f in evidence_files[:5]:
            print(f"  - {f}")
        if len(evidence_files) > 5:
            print(f"  ... and {len(evidence_files)-5} more.")
    else:
        print("Evidence directory not found.")
    
    db.close()

if __name__ == "__main__":
    test_proctoring_logic()
