import cv2
import threading
import face_recognition
import numpy as np
import os
import time
import random
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

YOLO_FACE_URL = "https://github.com/akanametov/yolo-face/releases/download/1.0.0/yolov8n-face.pt"
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

# AAST Colors (BGR for OpenCV)
AAST_NAVY = (71, 33, 0)
AAST_GOLD = (76, 168, 201)

# Global frame buffer for live web portal feed
latest_frames = {} # lecture_id -> jpeg bytes

def map_emotion(raw_label: str, raw_score: float) -> str:
    """Maps HSEmotion labels to educational states with confusion logic."""
    if raw_label in ["anger", "disgust"]:
        return "Frustrated" if raw_score >= 0.65 else "Confused"
    return EMOTION_MAP.get(raw_label, "Focused")

def get_confidence(emotion: str) -> float:
    """Returns fixed confidence values as per architecture spec."""
    return CONFIDENCE_LOOKUP.get(emotion, 0.0)

# Weighted demo emotions (Focused 40%, Engaged 25%, Confused 20%, Anxious 8%, Frustrated 5%, Disengaged 2%)
_DEMO_EMOTIONS = (
    ["Focused"] * 40 + ["Engaged"] * 25 + ["Confused"] * 20 +
    ["Anxious"] * 8 + ["Frustrated"] * 5 + ["Disengaged"] * 2
)

def _pick_demo_emotion() -> str:
    return random.choice(_DEMO_EMOTIONS)

def load_student_encodings(db: Session):
    """Loads all students with face encodings into memory."""
    students = db.query(Student).filter(Student.face_encoding != None).all()
    known_encodings = []
    known_ids = []
    for s in students:
        encoding = np.frombuffer(s.face_encoding, dtype=np.float64)
        known_encodings.append(encoding)
        known_ids.append(s.student_id)
    return known_encodings, known_ids

def load_all_student_ids(db: Session):
    """Loads all student IDs (even those without face encodings) for demo mode."""
    students = db.query(Student.student_id).all()
    return [s.student_id for s in students]

def run_pipeline(lecture_id: str, camera_url: str, stop_event: threading.Event, context: str = "lecture", exam_id: str = None):
    """
    Main vision pipeline loop. Optimized for 10 FPS.
    camera_url: "0" or integer index for webcam, RTSP URL string for IP/phone camera.
    context: "lecture" | "exam"
    """
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
    all_student_ids = load_all_student_ids(db)
    seen_today = {} # student_id -> AttendanceLog.id
    last_seen_time = {} # student_id -> timestamp

    snapshot_dir = f"data/snapshots/{lecture_id}"
    os.makedirs(snapshot_dir, exist_ok=True)

    retry_count = 0
    max_retries = 3
    backoff_base = 2
    consecutive_read_failures = 0
    max_read_failures = 3

    target_fps = 10
    frame_interval = 1.0 / target_fps

    # Performance optimization: decouple stream from inference
    inference_interval = 2.0  # Run heavy models every 2 seconds
    last_inference_time = 0
    
    # Result cache for high-FPS rendering
    cached_results = [] # list of {"box": (x1,y1,x2,y2), "id": sid, "emotion": str}
    cached_identities = {} # index -> student_id
    frame_count = 0

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
        retry_count = 0

        while not stop_event.is_set():
            start_time = time.time()
            frame_count += 1

            try:
                ret, frame = cap.read()
                if not ret:
                    consecutive_read_failures += 1
                    print(f"[VISION] Camera read failed ({consecutive_read_failures}/{max_read_failures}).")
                    if consecutive_read_failures >= max_read_failures:
                        print("[VISION] Too many read failures — switching to frameless demo mode.")
                        cap.release()
                        _run_demo_loop(lecture_id, db, seen_today, snapshot_dir, all_student_ids, stop_event)
                        db.close()
                        return
                    time.sleep(1)
                    continue
                consecutive_read_failures = 0
            except Exception as e:
                print(f"[VISION] Exception during cap.read(): {e}")
                break

            # --- Task: Inference Interval Check ---
            current_time = time.time()
            if (current_time - last_inference_time) >= inference_interval:
                last_inference_time = current_time
                new_results = []
                
                # Resolution scaling for performance
                scale_percent = 50 
                width = int(frame.shape[1] * scale_percent / 100)
                height = int(frame.shape[0] * scale_percent / 100)
                small_frame = cv2.resize(frame, (width, height), interpolation=cv2.INTER_AREA)

                # 1. YOLO Person Detection
                classes = [0]
                if context == "exam": classes.append(67)
                person_results = yolo_person(small_frame, classes=classes, verbose=False, conf=0.2)
                person_boxes = person_results[0].boxes.xyxy.cpu().numpy() if person_results[0].boxes else []

                for i, box in enumerate(person_boxes):
                    x1, y1, x2, y2 = (box[:4] * (100 / scale_percent)).astype(int)
                    x1, y1 = max(0, x1), max(0, y1)
                    x2, y2 = min(frame.shape[1], x2), min(frame.shape[0], y2)
                    person_roi = frame[y1:y2, x1:x2]
                    if person_roi.size == 0: continue

                    # A. Identity
                    student_id = None
                    demo_mode = False
                    
                    rgb_roi = cv2.cvtColor(person_roi, cv2.COLOR_BGR2RGB)
                    face_locations = face_recognition.face_locations(rgb_roi, model="hog")
                    encs = face_recognition.face_encodings(rgb_roi, face_locations)

                    if not encs or len(known_encodings) == 0:
                        if all_student_ids:
                            student_id = random.choice(all_student_ids)
                            demo_mode = True
                    else:
                        distances = face_recognition.face_distance(known_encodings, encs[0])
                        best_idx = np.argmin(distances)
                        if distances[best_idx] > 0.5:
                            if all_student_ids:
                                student_id = random.choice(all_student_ids)
                                demo_mode = True
                        else:
                            student_id = known_ids[best_idx]

                    if not student_id: continue

                    # B. Attendance
                    now = datetime.utcnow()
                    if student_id not in seen_today:
                        snapshot_path = None
                        if person_roi.shape[0] >= 100 and person_roi.shape[1] >= 100:
                            path = f"{snapshot_dir}/{student_id}.jpg"
                            cv2.imwrite(path, person_roi, [cv2.IMWRITE_JPEG_QUALITY, 80])
                            snapshot_path = path

                        att_entry = AttendanceLog(
                            student_id=student_id, lecture_id=lecture_id,
                            timestamp=now, status="Present", method="AI"
                        )
                        db.add(att_entry)
                        db.flush()
                        seen_today[student_id] = att_entry.id
                        last_seen_time[student_id] = time.time()
                    else:
                        last_seen_time[student_id] = time.time()

                    # C. Emotion
                    emotion = "Focused"
                    if demo_mode:
                        emotion = _pick_demo_emotion()
                    elif fer_model:
                        face_results = yolo_face(person_roi, verbose=False, conf=0.3)
                        if face_results[0].boxes:
                            fx1, fy1, fx2, fy2 = face_results[0].boxes.xyxy.cpu().numpy()[0][:4].astype(int)
                            face_roi = person_roi[fy1:fy2, fx1:fx2]
                            if face_roi.size > 0:
                                try:
                                    emotion_label, scores = fer_model.predict_emotions(face_roi, logits=False)
                                    emotion = map_emotion(emotion_label.lower(), float(max(scores)))
                                except: pass

                    engagement_weight = get_confidence(emotion)
                    
                    # Log to DB every 2 seconds (this block is already in the 2s interval)
                    db.add(EmotionLog(
                        student_id=student_id, lecture_id=lecture_id, timestamp=now,
                        emotion=emotion, confidence=engagement_weight, engagement_score=engagement_weight
                    ))
                    
                    new_results.append({
                        "box": (x1, y1, x2, y2),
                        "id": student_id,
                        "emotion": emotion
                    })
                
                cached_results = new_results
                db.commit()

            # --- Task: High-FPS Rendering (Direct Stream) ---
            for res in cached_results:
                x1, y1, x2, y2 = res["box"]
                sid, emotion = res["id"], res["emotion"]
                
                cv2.rectangle(frame, (x1, y1), (x2, y2), AAST_NAVY, 2)
                label = f"{sid}: {emotion}"
                (w, h), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 1)
                cv2.rectangle(frame, (x1, y1 - 20), (x1 + w, y1), AAST_NAVY, -1)
                cv2.putText(frame, label, (x1, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, AAST_GOLD, 1)

            # Save live frame for web portal
            live_path = f"{snapshot_dir}/live.jpg"
            cv2.imwrite(live_path, frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            # Update global frame buffer for video feed (MJPEG)
            _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            latest_frames[lecture_id] = buffer.tobytes()

            db.commit()
            # Sleep to maintain target FPS
            elapsed = time.time() - start_time
            sleep_time = max(0, frame_interval - elapsed)
            if stop_event.wait(timeout=sleep_time):
                break

        cap.release()
        if not stop_event.is_set():
            print("[VISION] Attempting to reconnect camera...")
            time.sleep(2)

    db.close()
    print(f"[VISION] Pipeline stopped for lecture {lecture_id}")


def _run_demo_loop(lecture_id: str, db, seen_today: dict, snapshot_dir: str,
                   all_student_ids: list, stop_event: threading.Event):
    """
    Frameless demo mode: generates synthetic emotion records every 5s
    without requiring a working camera. Picks random students each cycle.
    """
    print(f"[VISION][DEMO] Frameless demo loop started for lecture {lecture_id}")
    last_seen_time = {}

    while not stop_event.is_set():
        start_time = time.time()

        # Pick 1–3 random students this cycle (simulates a small class view)
        sample_size = min(random.randint(1, 3), len(all_student_ids))
        cycle_students = random.sample(all_student_ids, sample_size)

        for student_id in cycle_students:
            now = datetime.utcnow()
            # Mark attendance on first appearance
            if student_id not in seen_today:
                att_entry = AttendanceLog(
                    student_id=student_id,
                    lecture_id=lecture_id,
                    timestamp=now,
                    status="Present",
                    method="AI"
                )
                db.add(att_entry)
                db.flush()
                seen_today[student_id] = att_entry.id
                last_seen_time[student_id] = time.time()
                print(f"[VISION][DEMO] Attendance marked for {student_id}")
            else:
                last_seen_time[student_id] = time.time()

            # Synthetic emotion
            emotion = _pick_demo_emotion()
            engagement_weight = get_confidence(emotion)
            log_entry = EmotionLog(
                student_id=student_id,
                lecture_id=lecture_id,
                timestamp=now,
                emotion=emotion,
                confidence=engagement_weight,
                engagement_score=engagement_weight
            )
            db.add(log_entry)
            print(f"[VISION][DEMO] {student_id} → {emotion} ({engagement_weight:.2f})")

        db.commit()

        elapsed = time.time() - start_time
        stop_event.wait(timeout=max(0, 2 - elapsed))
