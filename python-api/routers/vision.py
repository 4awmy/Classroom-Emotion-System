"""
Vision router — cloud-side frame processing.
Uses insightface (ONNX-based, no dlib/C compilation) for face recognition.
Uses HSEmotion for emotion detection.
"""

from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from database import get_db
from models import Student, AttendanceLog, EmotionLog
import numpy as np

try:
    import cv2
    _CV2_OK = True
except ImportError:
    _CV2_OK = False

try:
    from insightface.app import FaceAnalysis
    _INSIGHT_OK = True
except ImportError:
    _INSIGHT_OK = False

try:
    from hsemotion_onnx.facial_emotions import HSEmotionRecognizer
    _HSEMOTION_OK = True
except ImportError:
    _HSEMOTION_OK = False

_VISION_OK = _CV2_OK and _INSIGHT_OK

router = APIRouter()

_face_app = None
_fer = None

CONFIDENCE_MAP = {
    "Focused": 1.00, "Engaged": 0.85, "Confused": 0.55,
    "Anxious": 0.35, "Frustrated": 0.25, "Disengaged": 0.00,
}

# Insightface embeddings are 512-dim float32; stored as such in face_encoding BLOB
ENCODING_DIM = 512
ENCODING_DTYPE = np.float32
SIMILARITY_THRESHOLD = 0.4  # cosine similarity minimum for a match


def _get_face_app():
    global _face_app
    if _face_app is None and _INSIGHT_OK:
        _face_app = FaceAnalysis(providers=["CPUExecutionProvider"])
        _face_app.prepare(ctx_id=0, det_size=(640, 640))
    return _face_app


def _get_fer():
    global _fer
    if _fer is None and _HSEMOTION_OK:
        _fer = HSEmotionRecognizer(model_name="enet_b0_8_best_afew")
    return _fer


def _cosine_sim(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8))


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
    Writes AttendanceLog + EmotionLog rows for each matched face.
    The lecture must exist (created via POST /session/start).
    """
    if not _VISION_OK:
        raise HTTPException(
            status_code=503,
            detail="Vision libraries (insightface, opencv) not available on this backend.",
        )

    img_bytes = await image.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="Could not decode image. Send a valid JPEG.")

    # Load enrolled insightface encodings (512-dim float32)
    students = db.query(Student).filter(Student.face_encoding.isnot(None)).all()
    known = []
    for s in students:
        enc = np.frombuffer(s.face_encoding, dtype=ENCODING_DTYPE)
        if enc.shape[0] == ENCODING_DIM:
            known.append((s, enc))

    if not known:
        return {
            "detected": [], "faces_found": 0,
            "message": "No insightface encodings enrolled yet. Upload roster via /roster/upload.",
        }

    # Detect faces
    face_app = _get_face_app()
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    faces = face_app.get(rgb)

    fer = _get_fer()
    detected = []

    for face in faces:
        embedding = face.embedding.astype(ENCODING_DTYPE)

        sims = [_cosine_sim(embedding, vec) for _, vec in known]
        best_idx = int(np.argmax(sims))
        best_sim = sims[best_idx]

        if best_sim < SIMILARITY_THRESHOLD:
            continue

        student = known[best_idx][0]
        bbox = face.bbox.astype(int)
        x1, y1, x2, y2 = bbox[0], bbox[1], bbox[2], bbox[3]

        # Attendance — idempotent per lecture
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

        # Emotion
        emotion = "Focused"
        confidence = CONFIDENCE_MAP["Focused"]
        if fer is not None:
            face_roi = frame[y1:y2, x1:x2]
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
            "similarity": round(best_sim, 3),
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
        "faces_found": len(faces),
        "matched": len(detected),
    }


@router.get("/status")
def vision_status():
    return {
        "vision_available": _VISION_OK,
        "packages": {
            "opencv": _CV2_OK,
            "insightface": _INSIGHT_OK,
            "hsemotion_onnx": _HSEMOTION_OK,
        },
        "models_loaded": {
            "face_app": _face_app is not None,
            "emotion_recognizer": _fer is not None,
        },
        "encoding_dim": ENCODING_DIM,
        "encoding_dtype": str(ENCODING_DTYPE),
    }
