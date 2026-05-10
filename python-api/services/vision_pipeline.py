import os
import threading
import time
import numpy as np
import base64
from datetime import datetime, timedelta
from typing import List, Optional, Dict
from sqlalchemy.orm import Session
from database import SessionLocal
from models import Student, EmotionLog, AttendanceLog, Lecture
from services.websocket import manager
from services.proctor_service import ProctorService
from services.stream_state import latest_frames
import traceback

# Optional Heavy Imports (For Local Node only)
# On the cloud server, these will be None
try:
    import cv2
except ImportError:
    cv2 = None

try:
    import torch
    import face_recognition
    from ultralytics import YOLO, settings
    if settings:
        settings.update({'hub': False, 'sync': False})
except ImportError:
    torch = None
    face_recognition = None
    YOLO = None

try:
    from hsemotion.face_emotions import HSEmotionRecognizer
except ImportError:
    HSEmotionRecognizer = None

# Paths
YOLO_FACE_PATH = os.path.join(os.path.dirname(__file__), "..", "yolov8n-face.pt")

def _ensure_yolo_face():
    """Checks if face model exists locally."""
    if not os.path.exists(YOLO_FACE_PATH):
        print(f"[VISION] Warning: Face model not found at {YOLO_FACE_PATH}")

def load_student_encodings(db: Session):
    """Loads all student IDs and their face encodings."""
    students = db.query(Student).all()
    encodings = {}
    for s in students:
        if s.face_encoding:
            try:
                vec = np.frombuffer(s.face_encoding, dtype=np.float64)
                if len(vec) == 128:
                    encodings[s.student_id] = vec
            except: pass
    return encodings

def run_pipeline(lecture_id: str, camera_url: str, stop_event: threading.Event, context: str = "lecture", exam_id: str = None):
    """Main vision pipeline loop."""
    if cv2 is None or YOLO is None:
        print("[VISION] Skipping pipeline: AI dependencies (cv2/torch/ultralytics) not installed on this machine.")
        return

    camera_source = int(camera_url) if isinstance(camera_url, str) and camera_url.isdigit() else camera_url
    print(f"[VISION] Starting pipeline for {lecture_id} (Source: {camera_source})")

    cap = None
    db = None
    try:
        # Initialize models
        _ensure_yolo_face()
        yolo_person = YOLO('yolov8n.pt')
        yolo_face   = YOLO(YOLO_FACE_PATH)
        
        fer_model = None
        if HSEmotionRecognizer:
            try:
                fer_model = HSEmotionRecognizer(model_name='enet_b0_8_best_afew')
            except Exception as e:
                print(f"[VISION] HSEmotion load error: {e}")

        db = SessionLocal()
        proctor = ProctorService(db) if context == "exam" else None
        
        frame_count = 0
        start_time = datetime.utcnow()
        
        cap = cv2.VideoCapture(camera_source)
        if not cap or not cap.isOpened():
            print(f"[VISION] ERROR: Could not open camera {camera_url}")
            return

        known_encodings = load_student_encodings(db)
        known_ids = list(known_encodings.keys())
        known_vectors = list(known_encodings.values())
        detected_this_session = set()
        
        print(f"[VISION] Pipeline loop started for {lecture_id}. Known faces: {len(known_ids)}")

        while not stop_event.is_set():
            ret, frame = cap.read()
            if not ret:
                print("[VISION] Failed frame grab. Reconnecting...")
                cap.release()
                time.sleep(2)
                cap = cv2.VideoCapture(camera_source)
                continue

            frame_count += 1
            
            # Update shared frame for streaming
            ret_enc, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 50]) # Lower quality for speed
            if ret_enc:
                latest_frames[lecture_id] = jpeg.tobytes()

            if frame_count == 1:
                lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
                if lecture and not lecture.actual_start_time:
                    lecture.actual_start_time = datetime.utcnow()
                    db.commit()

            # Vision Processing every 5 frames (~3 FPS processing)
            if frame_count % 5 == 0:
                person_results = yolo_person(frame, verbose=False)
                
                for box in person_results[0].boxes:
                    if int(box.cls[0]) != 0: continue
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    person_roi = frame[max(0, y1):y2, max(0, x1):x2]
                    if person_roi.size == 0: continue
                    
                    face_results = yolo_face(person_roi, verbose=False)
                    for fbox in face_results[0].boxes:
                        fx1, fy1, fx2, fy2 = map(int, fbox.xyxy[0])
                        face_roi = person_roi[max(0, fy1):fy2, max(0, fx1):fx2]
                        if face_roi.size == 0: continue
                        
                        sid = "unknown"
                        # recognition logic...
                        rgb_face = cv2.cvtColor(face_roi, cv2.COLOR_BGR2RGB)
                        
                        # DEMO MODE: If face seen, we MUST identify someone
                        if known_vectors:
                            # Only run expensive encodings every 20 frames
                            if frame_count % 20 == 0:
                                current_encodings = face_recognition.face_encodings(rgb_face)
                                if current_encodings:
                                    matches = face_recognition.compare_faces(known_vectors, current_encodings[0], tolerance=0.6)
                                    if True in matches:
                                        sid = known_ids[matches.index(True)]
                                    else:
                                        sid = "unknown"
                            else:
                                # For frames where we don't run re-recognition, we assume 
                                # the face in this bounding box is the same as before?
                                # Actually, without tracking, we should just say unknown or keep last.
                                # But let's stay safe:
                                pass 
                        
                        if sid != "unknown":
                            if sid not in detected_this_session:
                                db.add(AttendanceLog(student_id=sid, lecture_id=lecture_id, status="PRESENT", method="FACE"))
                                db.commit()
                                detected_this_session.add(sid)
                                # Save attendance snapshot
                                snap_dir = os.path.join("data", "snapshots", lecture_id)
                                os.makedirs(snap_dir, exist_ok=True)
                                cv2.imwrite(os.path.join(snap_dir, f"{sid}.jpg"), person_roi)

                            # Emotion Detection (Every 30 frames ~ 3 secs)
                            if fer_model and frame_count % 30 == 0:
                                res = fer_model.predict_emotions(rgb_face, logits=False)
                                emotion = max(res, key=lambda x: res[x])
                                db.add(EmotionLog(student_id=sid, lecture_id=lecture_id, emotion=emotion, confidence=float(res[emotion]), engagement_score=float(res[emotion])))
                                db.commit()
                                print(f"[VISION] Emotion for {sid}: {emotion}")

            if frame_count % 50 == 0:
                manager.broadcast_sync({"type": "vision:heartbeat", "lecture_id": lecture_id, "frame": frame_count})

            time.sleep(0.03)

    except Exception as e:
        print(f"[VISION] FATAL CRASH: {e}")
        traceback.print_exc()
    finally:
        if lecture_id in latest_frames:
            del latest_frames[lecture_id]
        if cap: cap.release()
        if db: db.close()
        print(f"[VISION] Pipeline for {lecture_id} terminated clean.")

if __name__ == "__main__":
    e = threading.Event()
    run_pipeline("DEBUG", "0", e)
