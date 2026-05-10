"""
Vision router — cloud-side frame processing.
Accepts a JPEG uploaded from the Shiny browser webcam, runs face recognition
against enrolled student encodings, detects emotion with HSEmotion, and writes
AttendanceLog + EmotionLog rows for every matched student.
"""

from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from database import get_db
from models import Student, AttendanceLog, EmotionLog
import numpy as np
import io

try:
    import cv2
    import face_recognition
    from hsemotion_onnx.facial_emotions import HSEmotionRecognizer
    _VISION_OK = True
except ImportError:
    _VISION_OK = False

router = APIRouter()

# Lazy-loaded emotion model (downloaded on first call)
_fer = None

CONFIDENCE_MAP = {
    "Focused": 1.00, "Engaged": 0.85, "Confused": 0.55,
    "Anxious": 0.35, "Frustrated": 0.25, "Disengaged": 0.00,
}


def _get_fer():
    global _fer
    if _fer is None and _VISION_OK:
        _fer = HSEmotionRecognizer(model_name="enet_b0_8_best_afew")
    return _fer


def _map_emotion(label: str, score: float) -> str:
    label = label.lower()
    if label in ("anger", "disgust"):
        return "Frustrated" if score >= 0.65 else "Confused"
    return {
        "neutral": "Focused", "happiness": "Engaged",
        "surprise": "Engaged", "fear": "Anxious", "sadness": "Disengaged",
    }.get(label, "Focused")


@router.post("/process-frame")
async def process_frame(
    image: UploadFile = File(...),
    lecture_id: str = Form(...),
    db: Session = Depends(get_db),
):
    """
    Accept a JPEG frame from the browser webcam.
    Returns list of identified students with their detected emotion.
    Attendance and emotion are written to the DB automatically.
    The lecture must already exist (created via POST /session/start).
    """
    if not _VISION_OK:
        raise HTTPException(
            status_code=503,
            detail="Vision libraries (face-recognition, hsemotion-onnx) are not installed on this backend.",
        )

    img_bytes = await image.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="Could not decode image. Send a valid JPEG.")

    # Load all enrolled encodings from DB
    students = db.query(Student).filter(Student.face_encoding.isnot(None)).all()
    if not students:
        return {"detected": [], "faces_found": 0, "message": "No students with face encodings enrolled yet."}

    known_vecs = [np.frombuffer(s.face_encoding, dtype=np.float64) for s in students]

    # Detect faces in the uploaded frame
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    face_locations = face_recognition.face_locations(rgb, model="hog")
    face_encodings = face_recognition.face_encodings(rgb, face_locations)

    fer = _get_fer()
    detected = []

    for (top, right, bottom, left), face_enc in zip(face_locations, face_encodings):
        distances = face_recognition.face_distance(known_vecs, face_enc)
        best_idx = int(np.argmin(distances))
        if distances[best_idx] > 0.5:
            continue  # no match

        student = students[best_idx]

        # --- Attendance (idempotent: skip if already logged for this lecture) ---
        already_present = db.query(AttendanceLog).filter(
            AttendanceLog.student_id == student.student_id,
            AttendanceLog.lecture_id == lecture_id,
            AttendanceLog.status == "Present",
        ).first()
        if not already_present:
            db.add(AttendanceLog(
                student_id=student.student_id,
                lecture_id=lecture_id,
                status="Present",
                method="AI",
            ))

        # --- Emotion ---
        emotion = "Focused"
        confidence = CONFIDENCE_MAP["Focused"]
        if fer is not None:
            face_roi = frame[top:bottom, left:right]
            if face_roi.size > 0:
                try:
                    label, scores = fer.predict_emotions(face_roi, logits=False)
                    emotion = _map_emotion(label, float(max(scores)))
                    confidence = CONFIDENCE_MAP[emotion]
                except Exception:
                    pass

        db.add(EmotionLog(
            student_id=student.student_id,
            lecture_id=lecture_id,
            emotion=emotion,
            confidence=confidence,
            engagement_score=confidence,
        ))

        detected.append({
            "student_id": student.student_id,
            "name": student.name,
            "emotion": emotion,
            "confidence": confidence,
            "distance": round(float(distances[best_idx]), 3),
        })

    try:
        db.commit()
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail=f"DB constraint error — ensure the lecture '{lecture_id}' exists (start the session first). Detail: {e.orig}",
        )

    return {
        "detected": detected,
        "faces_found": len(face_locations),
        "matched": len(detected),
    }


@router.get("/status")
def vision_status():
    """Report whether vision libraries are available on this backend."""
    return {
        "vision_available": _VISION_OK,
        "packages": {
            "opencv": _VISION_OK,
            "face_recognition": _VISION_OK,
            "hsemotion_onnx": _VISION_OK,
        },
        "model_loaded": _fer is not None,
    }
