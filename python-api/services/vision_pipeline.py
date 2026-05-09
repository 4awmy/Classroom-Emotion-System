import os
import cv2
import threading
import time
import numpy as np
import base64
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from database import SessionLocal
from models import Student, EmotionLog, AttendanceLog, Lecture
from services.websocket import manager
from services.proctor_service import ProctorService
import torch
import face_recognition

# Try to import HSEmotion
try:
    from hsemotion.face_emotions import HSEmotionRecognizer
except ImportError:
    HSEmotionRecognizer = None

# Ultralytics YOLOv8
from ultralytics import YOLO, settings

# Configure YOLO to be strictly offline
settings.update({'hub': False, 'sync': False})

# Paths
YOLO_FACE_PATH = os.path.join(os.path.dirname(__file__), "..", "yolov8n-face.pt")

def _ensure_yolo_face():
    """Checks if face model exists locally."""
    if not os.path.exists(YOLO_FACE_PATH):
        print(f"[VISION] Warning: Face model not found at {YOLO_FACE_PATH}")

def load_student_encodings(db: Session):
    """Loads all student IDs and their face encodings."""
    students = db.query(Student).all()
    return {s.student_id: np.frombuffer(s.face_encoding, dtype=np.float64) for s in students if s.face_encoding}

def run_pipeline(lecture_id: str, camera_url: str, stop_event: threading.Event, context: str = "lecture", exam_id: str = None):
    """
    Main vision pipeline loop. Optimized for 10 FPS.
    camera_url: "0" or integer index for webcam, RTSP URL string for IP/phone camera.
    context: "lecture" | "exam"
    """
    camera_source = int(camera_url) if isinstance(camera_url, str) and camera_url.isdigit() else camera_url
    print(f"[VISION] Starting pipeline for lecture {lecture_id} on {camera_source!r} (Context: {context})")

    # Initialize models — STRICT OFFLINE
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
    
    # Audit v4: Initialize counters
    frame_count = 0
    start_time = datetime.utcnow()
    
    cap = cv2.VideoCapture(camera_source)
    if not cap.isOpened():
        print(f"[VISION] Error: Could not open camera {camera_url}")
        return

    # Load known faces
    known_encodings = load_student_encodings(db)
    known_ids = list(known_encodings.keys())
    known_vectors = list(known_encodings.values())
    
    detected_this_session = set()
    
    try:
        while not stop_event.is_set():
            ret, frame = cap.read()
            if not ret:
                print("[VISION] Failed to grab frame. Reconnecting...")
                time.sleep(2)
                cap = cv2.VideoCapture(camera_source)
                continue

            frame_count += 1
            
            # --- Audit v4: First detection triggers actual_start_time ---
            if frame_count == 1:
                lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
                if lecture and not lecture.actual_start_time:
                    lecture.actual_start_time = datetime.utcnow()
                    db.commit()

            # Perform person detection
            person_results = yolo_person(frame, verbose=False, stream=False)
            
            # For each detected person
            detected_ids = set()
            for box in person_results[0].boxes:
                if int(box.cls[0]) != 0: continue # Only 'person'
                
                # Get ROI
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                person_roi = frame[y1:y2, x1:x2]
                if person_roi.size == 0: continue
                
                # Detect face in ROI
                face_results = yolo_face(person_roi, verbose=False, stream=False)
                for fbox in face_results[0].boxes:
                    fx1, fy1, fx2, fy2 = map(int, fbox.xyxy[0])
                    face_roi = person_roi[fy1:fy2, fx1:fx2]
                    if face_roi.size == 0: continue
                    
                    # Face Recognition
                    rgb_face = cv2.cvtColor(face_roi, cv2.COLOR_BGR2RGB)
                    current_encodings = face_recognition.face_encodings(rgb_face)
                    
                    if current_encodings:
                        matches = face_recognition.compare_faces(known_vectors, current_encodings[0], tolerance=0.5)
                        if True in matches:
                            first_match_index = matches.index(True)
                            sid = known_ids[first_match_index]
                            detected_ids.add(sid)
                            
                            # Log attendance if first time
                            if sid not in detected_this_session:
                                db.add(AttendanceLog(student_id=sid, lecture_id=lecture_id, status="PRESENT", method="FACE"))
                                db.commit()
                                detected_this_session.add(sid)
                            
                            # --- PROCTORING LOGIC ---
                            if context == "exam" and proctor:
                                # 1. Head Rotation
                                proctor.check_head_rotation(sid, exam_id, face_roi)
                                
                                # 2. Phone Check
                                proctor.check_phone_on_desk(sid, exam_id, person_roi, person_results)
                                
                                # 3. Multiple Persons
                                proctor.check_multiple_persons(sid, exam_id, person_roi, person_results)
                                
                                # 4. Auto-Submit Check
                                if proctor.check_auto_submit(exam_id, sid):
                                    print(f"[PROCTOR] TRIGGERING AUTO-SUBMIT FOR {sid}")
                                    manager.broadcast_sync({
                                        "type": "exam:autosubmit",
                                        "exam_id": exam_id,
                                        "student_id": sid,
                                        "reason": "3+ high-severity incidents"
                                    })

                            # Emotion Detection
                            if fer_model and frame_count % 30 == 0:
                                res = fer_model.predict_emotions(rgb_face, logits=False)
                                emotion = max(res, key=lambda x: res[x])
                                score = res[emotion]
                                db.add(EmotionLog(student_id=sid, lecture_id=lecture_id, emotion=emotion, confidence=float(score), engagement_score=float(score)))
                                db.commit()

            # Check Absence during exams
            if context == "exam" and proctor:
                proctor.check_absent(exam_id, detected_ids)

            # For Demo: Emit a heartbeat to WebSockets
            if frame_count % 30 == 0:
                manager.broadcast_sync({
                    "type": "vision:heartbeat",
                    "lecture_id": lecture_id,
                    "frame": frame_count,
                    "timestamp": datetime.utcnow().isoformat()
                })

            # Control FPS (Approx 10 FPS)
            time.sleep(0.1)

    except Exception as e:
        print(f"[VISION] Pipeline Crash: {e}")
    finally:
        # --- Audit v4: Final wrap up ---
        end_time = datetime.utcnow()
        lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
        if lecture:
            lecture.actual_end_time = end_time
            lecture.total_frames_captured = frame_count
            duration_sec = (end_time - start_time).total_seconds()
            lecture.expected_frames_count = int(duration_sec * 10)
            db.commit()
            
        cap.release()
        db.close()
        print(f"[VISION] Pipeline for {lecture_id} stopped. Frames: {frame_count}")

if __name__ == "__main__":
    # Test stub
    e = threading.Event()
    run_pipeline("TEST_L", "0", e)
