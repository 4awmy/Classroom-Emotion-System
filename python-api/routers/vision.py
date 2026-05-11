"""
Vision router — cloud-side frame processing.
Face detection + identity: InsightFace buffalo_sc (RetinaFace + ArcFace, ONNX, CPU).
Enrollment check: only students enrolled in the lecture's class are logged.
Emotion: HSEmotion ONNX (AffectNet).
"""

from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from database import get_db
from models import Student, AttendanceLog, EmotionLog, Lecture, Enrollment
from services.face_embeddings import (
    ENCODING_DIM,
    ENCODING_DTYPE,
    detect_and_embed,
    cosine_sim,
    cv2_available,
    deepface_available,
)
import numpy as np

try:
    import cv2
    _CV2_OK = True
except ImportError:
    _CV2_OK = False

try:
    from hsemotion_onnx.facial_emotions import HSEmotionRecognizer
    _HSEMOTION_OK = True
except ImportError:
    _HSEMOTION_OK = False

_VISION_OK = _CV2_OK and cv2_available()

router = APIRouter()

_fer = None

CONFIDENCE_MAP = {
    "Focused": 1.00, "Engaged": 0.85, "Confused": 0.55,
    "Anxious": 0.35, "Frustrated": 0.25, "Disengaged": 0.00,
}

SIMILARITY_THRESHOLD = 0.50  # InsightFace ArcFace cosine; same-person typically >0.60


def _get_fer():
    global _fer
    if _fer is None and _HSEMOTION_OK:
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
    InsightFace detects + embeds all faces in one pass (RetinaFace + ArcFace).
    Matches against enrolled student embeddings (cosine similarity).
    Writes AttendanceLog + EmotionLog for matched+enrolled students.
    """
    if not _VISION_OK:
        raise HTTPException(status_code=503, detail="OpenCV not available on this backend.")
    if not deepface_available():
        raise HTTPException(status_code=503, detail="InsightFace not available on this backend.")

    img_bytes = await image.read()
    np_arr    = np.frombuffer(img_bytes, np.uint8)
    frame     = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="Could not decode image. Send a valid JPEG.")

    frame_h, frame_w = frame.shape[:2]

    # Resolve class for enrollment check
    lecture  = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    class_id = lecture.class_id if lecture else None
    enrolled_ids = None
    if class_id:
        enrolled_ids = {
            e.student_id
            for e in db.query(Enrollment).filter(Enrollment.class_id == class_id).all()
        }

    # Load all InsightFace ArcFace (512-dim) encodings from DB
    students = db.query(Student).filter(Student.face_encoding.isnot(None)).all()
    known = []
    for s in students:
        enc = np.frombuffer(s.face_encoding, dtype=ENCODING_DTYPE)
        if enc.shape[0] == ENCODING_DIM:
            known.append((s, enc))

    # Detect all faces + embeddings in one InsightFace pass
    face_detections = detect_and_embed(frame)

    if not face_detections and not known:
        return {
            "detected": [], "faces_found": 0, "matched": 0,
            "frame_width": frame_w, "frame_height": frame_h,
        }

    fer = _get_fer()
    detected = []

    for det in face_detections:
        bbox       = det["bbox"]
        query_vec  = det["embedding"]

        if not known:
            detected.append({
                "student_id": None, "name": "Unknown",
                "emotion": None, "confidence": None,
                "similarity": None, "enrolled": None,
                "bbox": bbox,
                "message": "No InsightFace encodings in DB — re-run scripts/load_roster.py",
            })
            continue

        sims     = [cosine_sim(query_vec, vec) for _, vec in known]
        best_idx = int(np.argmax(sims))
        best_sim = sims[best_idx]

        if best_sim < SIMILARITY_THRESHOLD:
            detected.append({
                "student_id": None, "name": "Unknown",
                "emotion": None, "confidence": None,
                "similarity": round(best_sim, 3), "enrolled": None,
                "bbox": bbox,
                "message": f"Best match {best_sim:.2f} below threshold {SIMILARITY_THRESHOLD}",
            })
            continue

        student = known[best_idx][0]

        if enrolled_ids is not None and student.student_id not in enrolled_ids:
            detected.append({
                "student_id": student.student_id, "name": student.name,
                "emotion": None, "confidence": None,
                "similarity": round(best_sim, 3), "enrolled": False,
                "bbox": bbox,
                "message": f"{student.name} not enrolled in this class",
            })
            continue

        # Attendance — idempotent
        already = db.query(AttendanceLog).filter(
            AttendanceLog.student_id == student.student_id,
            AttendanceLog.lecture_id == lecture_id,
            AttendanceLog.status == "Present",
        ).first()
        if not already:
            db.add(AttendanceLog(
                student_id=student.student_id,
                lecture_id=lecture_id,
                status="Present",
                method="AI",
            ))

        # Emotion — crop face ROI from frame for HSEmotion
        emotion    = "Focused"
        confidence = CONFIDENCE_MAP["Focused"]
        if fer is not None:
            x, y, w, h = bbox["x"], bbox["y"], bbox["w"], bbox["h"]
            face_roi = frame[y:y + h, x:x + w]
            if face_roi.size > 0:
                try:
                    label, scores = fer.predict_emotions(face_roi, logits=False)
                    emotion    = _map_emotion(label, float(max(scores)))
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
            "similarity": round(best_sim, 3),
            "enrolled": True,
            "bbox": bbox,
            "message": None,
        })

    try:
        db.commit()
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail=f"DB constraint: ensure lecture '{lecture_id}' exists (POST /session/start first). Detail: {e.orig}",
        )

    return {
        "detected": detected,
        "faces_found": len(face_detections),
        "matched": sum(1 for d in detected if d.get("enrolled") is True),
        "frame_width": frame_w,
        "frame_height": frame_h,
    }


@router.get("/status")
def vision_status():
    return {
        "vision_available": _VISION_OK,
        "packages": {
            "opencv": _CV2_OK,
            "hsemotion_onnx": _HSEMOTION_OK,
            "insightface": deepface_available(),
        },
        "method": "InsightFace buffalo_sc (RetinaFace + ArcFace ONNX, CPU)",
        "encoding_dim": ENCODING_DIM,
        "similarity_threshold": SIMILARITY_THRESHOLD,
    }
