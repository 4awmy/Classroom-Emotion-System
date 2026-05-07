import cv2
import threading
import face_recognition
import numpy as np
import os
import time
import urllib.request
import asyncio
from datetime import datetime
from sqlalchemy.orm import Session
from models import Student, EmotionLog, AttendanceLog
from database import SessionLocal
from services.proctor_service import ProctorService
from services.websocket import manager, get_main_loop

try:
    from hsemotion_onnx.facial_emotions import HSEmotionRecognizer
except ImportError:
    HSEmotionRecognizer = None

from ultralytics import YOLO

YOLO_FACE_URL = "https://github.com/akanametov/yolo-face/releases/download/v0.0.0/yolov8n-face.pt"
YOLO_FACE_PATH = "yolov8n-face.pt"

def _ensure_yolo_face():
    """Download yolov8n-face.pt at startup if not already present."""
    if not os.path.exists(YOLO_FACE_PATH):
        print(f"[VISION] Downloading {YOLO_FACE_PATH} ...")
        urllib.request.urlretrieve(YOLO_FACE_URL, YOLO_FACE_PATH)
        print(f"[VISION] {YOLO_FACE_PATH} downloaded.")

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

def run_pipeline(lecture_id: str, camera_url: str, stop_event: threading.Event, context: str = "lecture", exam_id: str = None):
    """
    Main vision pipeline loop.
    Runs every 5 seconds.
    camera_url: "0" or integer index for webcam, RTSP URL string for IP/phone camera.
    """
    # Convert "0" / "1" env var strings to integer for cv2.VideoCapture
    camera_source = int(camera_url) if isinstance(camera_url, str) and camera_url.isdigit() else camera_url
    print(f"[VISION] Starting pipeline for lecture {lecture_id} on {camera_source!r} (Context: {context})")

    # Initialize models — Approach B: separate person detector + face detector
    _ensure_yolo_face()
    yolo_person = YOLO('yolov8n.pt')
    yolo_face   = YOLO(YOLO_FACE_PATH)
    if HSEmotionRecognizer:
        try:
            fer_model = HSEmotionRecognizer(model_name='enet_b0_8_best_afew')
        except Exception as e:
            fer_model = None
            print(f"[VISION] Warning: HSEmotion model failed to load: {e}")
    else:
        fer_model = None
        print("[VISION] Warning: HSEmotion not installed.")

    db = SessionLocal()
    proctor = ProctorService(db) if context == "exam" else None
    known_encodings, known_ids = load_student_encodings(db)
    seen_today = set()

    # Snapshot directory
    snapshot_dir = f"data/snapshots/{lecture_id}"
    os.makedirs(snapshot_dir, exist_ok=True)

    retry_count = 0
    max_retries = 10
    backoff_base = 2
    
    while not stop_event.is_set() and retry_count < max_retries:
        print(f"[VISION] Attempting to open camera {camera_source} (Attempt {retry_count + 1}/{max_retries})")
        cap = cv2.VideoCapture(camera_source)
        
        if not cap.isOpened():
            wait_time = min(backoff_base ** retry_count, 60)
            print(f"[VISION] Error: Could not open camera {camera_source}. Retrying in {wait_time}s...")
            retry_count += 1
            if stop_event.wait(timeout=wait_time):
                break
            continue
        
        print(f"[VISION] Camera {camera_source} opened successfully.")
        retry_count = 0 # Reset on success
        
        while not stop_event.is_set():
            start_time = time.time()
            
            try:
                ret, frame = cap.read()
                if not ret:
                    print("[VISION] Camera stream dropped or failed to read frame.")
                    break
            except Exception as e:
                print(f"[VISION] Exception during cap.read(): {e}")
                break
            
            # 1. YOLO Person Detection
            classes = [0]
            if context == "exam":
                classes.append(67) # cell phone
            
            person_results = yolo_person(frame, classes=classes, verbose=False)
            person_boxes = person_results[0].boxes.xyxy.cpu().numpy().astype(int) if person_results[0].boxes else []

            detected_ids = set()
            for box in person_boxes:
                x1, y1, x2, y2 = box[:4]
                person_roi = frame[y1:y2, x1:x2]
                if person_roi.size == 0:
                    continue

                # --- Task A: Identity Match (face_recognition on full person ROI) ---
                rgb_roi = cv2.cvtColor(person_roi, cv2.COLOR_BGR2RGB)
                encs = face_recognition.face_encodings(rgb_roi)
                if not encs:
                    continue

                if len(known_encodings) == 0:
                    continue
                distances = face_recognition.face_distance(known_encodings, encs[0])
                best_idx = np.argmin(distances)
                
                if distances[best_idx] > 0.5:
                    if context == "exam" and exam_id:
                        proctor.check_identity_mismatch(None, exam_id, person_roi, distances[best_idx])
                    continue
                
                student_id = known_ids[best_idx]
                detected_ids.add(student_id)

                # Attendance + Snapshot on first detection this session
                if student_id not in seen_today:
                    seen_today.add(student_id)

                    snapshot_path = None
                    if person_roi.shape[0] >= 100 and person_roi.shape[1] >= 100:
                        path = f"{snapshot_dir}/{student_id}.jpg"
                        cv2.imwrite(path, person_roi, [cv2.IMWRITE_JPEG_QUALITY, 80])
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

                # --- Task B: Emotion with tight face crop (yolo_face → face_roi → HSEmotion) ---
                raw_label, raw_score = None, None
                face_roi = None
                if fer_model:
                    face_results = yolo_face(person_roi, verbose=False)
                    face_boxes = face_results[0].boxes.xyxy.cpu().numpy().astype(int) if face_results[0].boxes else []

                    if len(face_boxes) > 0:
                        fx1, fy1, fx2, fy2 = face_boxes[0][:4]
                        face_roi = person_roi[fy1:fy2, fx1:fx2]
                        if face_roi.size > 0:
                            try:
                                emotion_label, scores = fer_model.predict_emotions(face_roi, logits=False)
                                raw_label = emotion_label.lower()
                                raw_score = float(max(scores))
                            except Exception as e:
                                print(f"[VISION] HSEmotion error for {student_id}: {e}")

                emotion = map_emotion(raw_label, raw_score) if raw_label else "Focused"
                engagement_weight = get_confidence(emotion)

                # Persistence — store both raw model output AND mapped educational state
                log_entry = EmotionLog(
                    student_id=student_id,
                    lecture_id=lecture_id,
                    timestamp=datetime.utcnow(),
                    raw_emotion=raw_label,
                    raw_confidence=raw_score,
                    emotion=emotion,
                    confidence=engagement_weight,
                    engagement_score=engagement_weight
                )
                db.add(log_entry)

                # --- Proctoring Checks ---
                if context == "exam" and exam_id:
                    # Re-run YOLO on person_roi to find phones/multiple persons
                    person_roi_results = yolo_person(person_roi, classes=[0, 67], verbose=False)
                    proctor.check_phone_on_desk(student_id, exam_id, person_roi, person_roi_results)
                    proctor.check_multiple_persons(student_id, exam_id, person_roi, person_roi_results)
                    
                    if face_roi is not None:
                        pitch, yaw, roll, suspicious = proctor.check_head_rotation(student_id, exam_id, face_roi)
                    
                    if proctor.check_auto_submit(exam_id, student_id):
                        try:
                            payload = {
                                "type": "exam:autosubmit",
                                "exam_id": exam_id,
                                "student_id": student_id,
                                "reason": "auto_3_severity3",
                                "timestamp": datetime.utcnow().isoformat() + "Z"
                            }
                            loop = get_main_loop()
                            if loop and loop.is_running():
                                asyncio.run_coroutine_threadsafe(manager.broadcast(payload), loop)
                            else:
                                asyncio.run(manager.broadcast(payload))
                        except Exception as e:
                            print(f"[VISION] Failed to broadcast auto-submit: {e}")
            
            if context == "exam" and exam_id:
                proctor.check_absent(exam_id, detected_ids)

            db.commit()
            
            # Sleep to maintain 5-second interval
            elapsed = time.time() - start_time
            sleep_time = max(0, 5 - elapsed)
            if stop_event.wait(timeout=sleep_time):
                break
        
        cap.release()
        if not stop_event.is_set():
            print("[VISION] Attempting to reconnect camera...")
            time.sleep(2) # Brief pause before re-opening
    
    db.close()
    print(f"[VISION] Pipeline stopped for lecture {lecture_id}")
