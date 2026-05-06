import cv2
import threading
import face_recognition
import numpy as np
import os
import time
from datetime import datetime
from sqlalchemy.orm import Session
from models import Student, EmotionLog, AttendanceLog
from database import SessionLocal

# HSEmotion might need specific initialization
# For MVP, we'll assume a wrapper or direct usage if installed
try:
    from hsemotion.face_emotion_extractor import HSEmotionRecognizer
except ImportError:
    HSEmotionRecognizer = None

# YOLO for person detection
from ultralytics import YOLO

# Constants from CLAUDE.md §8.2
EMOTION_MAP = {
    "neutral": "Focused",
    "happy": "Engaged",
    "surprise": "Engaged",
    "fear": "Anxious",
    "anger": "Frustrated",
    "disgust": "Frustrated",
    "sad": "Disengaged"
}

CONFIDENCE_LOOKUP = {
    "Focused": 1.00,
    "Engaged": 0.85,
    "Confused": 0.55,
    "Anxious": 0.35,
    "Frustrated": 0.25,
    "Disengaged": 0.00
}

def map_emotion(raw_label: str, raw_score: float) -> str:
    """
    Maps HSEmotion labels to system states with confusion logic.
    """
    if raw_label in ["anger", "disgust"]:
        return "Frustrated" if raw_score >= 0.65 else "Confused"
    
    return EMOTION_MAP.get(raw_label, "Focused")

def get_confidence(emotion: str) -> float:
    """
    Returns fixed confidence values as per architecture spec.
    """
    return CONFIDENCE_LOOKUP.get(emotion, 0.0)

def load_student_encodings(db: Session):
    """
    Loads all students with encodings into memory.
    """
    students = db.query(Student).filter(Student.face_encoding != None).all()
    known_encodings = []
    known_ids = []
    for s in students:
        encoding = np.frombuffer(s.face_encoding, dtype=np.float64)
        known_encodings.append(encoding)
        known_ids.append(s.student_id)
    return known_encodings, known_ids

def run_pipeline(lecture_id: str, camera_url: str, stop_event: threading.Event):
    """
    Main vision pipeline loop.
    Runs every 5 seconds.
    camera_url: "0" or integer index for webcam, RTSP URL string for IP/phone camera.
    """
    # Convert "0" / "1" env var strings to integer for cv2.VideoCapture
    camera_source = int(camera_url) if isinstance(camera_url, str) and camera_url.isdigit() else camera_url
    print(f"[VISION] Starting pipeline for lecture {lecture_id} on {camera_source!r}")

    # Initialize models
    yolo_model = YOLO('yolov8n.pt')
    if HSEmotionRecognizer:
        try:
            fer_model = HSEmotionRecognizer(model_name='enet_b0_8_best_afew', device='cpu')
        except Exception as e:
            fer_model = None
            print(f"[VISION] Warning: HSEmotion model failed to load: {e}")
    else:
        fer_model = None
        print("[VISION] Warning: HSEmotion not installed.")

    db = SessionLocal()
    known_encodings, known_ids = load_student_encodings(db)
    seen_today = set()

    # Snapshot directory
    snapshot_dir = f"data/snapshots/{lecture_id}"
    os.makedirs(snapshot_dir, exist_ok=True)

    retry_count = 0
    while not stop_event.is_set() and retry_count < 5:
        cap = cv2.VideoCapture(camera_source)
        if not cap.isOpened():
            print(f"[VISION] Error: Could not open camera {camera_url}. Retrying...")
            retry_count += 1
            time.sleep(10)
            continue
        
        retry_count = 0 # Reset on success
        
        while not stop_event.is_set():
            start_time = time.time()
            
            ret, frame = cap.read()
            if not ret:
                print("[VISION] Camera stream dropped.")
                break
            
            # 1. YOLO Person Detection
            results = yolo_model(frame, classes=[0], verbose=False)
            boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)
            
            for box in boxes:
                x1, y1, x2, y2 = box
                roi = frame[y1:y2, x1:x2]
                if roi.size == 0: continue
                
                # 2. Identity Match
                rgb_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)
                encs = face_recognition.face_encodings(rgb_roi)
                
                if encs:
                    distances = face_recognition.face_distance(known_encodings, encs[0])
                    if len(distances) > 0:
                        best_idx = np.argmin(distances)
                        if distances[best_idx] <= 0.5:
                            student_id = known_ids[best_idx]
                            
                            # 3. Emotion Classification
                            raw_label, raw_score = None, None
                            if fer_model:
                                emotion_label, scores = fer_model.predict_emotions(roi, logits=False)
                                raw_label = emotion_label.lower()
                                raw_score = float(max(scores))
                                emotion = map_emotion(raw_label, raw_score)
                            else:
                                emotion = "Focused"  # Fallback when model unavailable

                            engagement_weight = get_confidence(emotion)

                            # 4. Persistence — store both raw model output AND mapped educational state
                            log_entry = EmotionLog(
                                student_id=student_id,
                                lecture_id=lecture_id,
                                timestamp=datetime.utcnow(),
                                raw_emotion=raw_label,          # e.g. "happy", "neutral", "sad"
                                raw_confidence=raw_score,        # model softmax score (actual certainty)
                                emotion=emotion,                 # mapped state: "Engaged", "Focused", etc.
                                confidence=engagement_weight,    # fixed weight per state (§8.2)
                                engagement_score=engagement_weight
                            )
                            db.add(log_entry)
                            
                            # 5. Attendance + Snapshot (Flow E)
                            if student_id not in seen_today:
                                seen_today.add(student_id)
                                
                                snapshot_path = None
                                if roi.shape[0] >= 100 and roi.shape[1] >= 100:
                                    path = f"{snapshot_dir}/{student_id}.jpg"
                                    cv2.imwrite(path, roi, [cv2.IMWRITE_JPEG_QUALITY, 80])
                                    snapshot_path = path
                                
                                att_entry = AttendanceLog(
                                    student_id=student_id,
                                    lecture_id=lecture_id,
                                    timestamp=datetime.utcnow(),
                                    status="Present",
                                    method="AI",
                                    snapshot_path=snapshot_path
                                )
                                db.add(att_entry)
                                print(f"[VISION] Detected student {student_id} (Attendance Marked)")
            
            db.commit()
            
            # Sleep to maintain 5-second interval
            elapsed = time.time() - start_time
            sleep_time = max(0, 5 - elapsed)
            if stop_event.wait(timeout=sleep_time):
                break
        
        cap.release()
    
    db.close()
    print(f"[VISION] Pipeline stopped for lecture {lecture_id}")
