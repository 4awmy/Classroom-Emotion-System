"""
Vision router — cloud-side frame processing.
Face detection:  OpenCV Haar cascade (pre-built wheels, no C compilation).
Face matching:   HOG descriptor cosine similarity stored as BLOB per student.
Enrollment check: Only students enrolled in the lecture's class are marked present.
Emotion:         HSEmotion ONNX (AffectNet, pure-Python wheel).
"""

from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from database import get_db
from models import Student, AttendanceLog, EmotionLog, Lecture, Enrollment
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

_VISION_OK = _CV2_OK

router = APIRouter()

_fer = None
_face_cascade = None

CONFIDENCE_MAP = {
    "Focused": 1.00, "Engaged": 0.85, "Confused": 0.55,
    "Anxious": 0.35, "Frustrated": 0.25, "Disengaged": 0.00,
}

_HOG_SIZE = (64, 64)
ENCODING_DTYPE = np.float32
SIMILARITY_THRESHOLD = 0.75


def _get_cascade():
    global _face_cascade
    if _face_cascade is None and _CV2_OK:
        _face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
    return _face_cascade


def _get_fer():
    global _fer
    if _fer is None and _HSEMOTION_OK:
        _fer = HSEmotionRecognizer(model_name="enet_b0_8_best_afew")
    return _fer


def _hog_descriptor(face_bgr: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(cv2.resize(face_bgr, _HOG_SIZE), cv2.COLOR_BGR2GRAY)
    hog = cv2.HOGDescriptor(
        _winSize=(64, 64), _blockSize=(16, 16), _blockStride=(8, 8),
        _cellSize=(8, 8), _nbins=9
    )
    desc = hog.compute(gray).flatten().astype(ENCODING_DTYPE)
    norm = np.linalg.norm(desc)
    return desc / norm if norm > 0 else desc


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
    - Detects all faces using Haar cascade.
    - Matches each face against enrolled HOG encodings.
    - Checks if matched student is enrolled in the lecture's class.
    - Writes AttendanceLog + EmotionLog only for enrolled+matched students.
    - Returns bounding boxes for all detected faces (for overlay drawing in UI).
    """
    if not _VISION_OK:
        raise HTTPException(status_code=503, detail="OpenCV not available on this backend.")

    img_bytes = await image.read()
    np_arr = np.frombuffer(img_bytes, np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="Could not decode image. Send a valid JPEG.")

    frame_h, frame_w = frame.shape[:2]

    # Resolve the class linked to this lecture (for enrollment check)
    lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    class_id = lecture.class_id if lecture else None

    if class_id:
        enrolled_ids = set(
            e.student_id
            for e in db.query(Enrollment).filter(Enrollment.class_id == class_id).all()
        )
    else:
        enrolled_ids = None  # No class linked — skip enrollment check

    # Load all HOG encodings from DB
    students = db.query(Student).filter(Student.face_encoding.isnot(None)).all()
    known = []
    for s in students:
        enc = np.frombuffer(s.face_encoding, dtype=ENCODING_DTYPE)
        if enc.shape[0] > 100:  # HOG vectors ~1764-dim; skip legacy 128/512-dim blobs
            known.append((s, enc))

    # Detect all faces in the frame
    cascade = _get_cascade()
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=3, minSize=(20, 20))

    fer = _get_fer()
    detected = []

    for (x, y, w, h) in (faces if len(faces) > 0 else []):
        face_roi = frame[y:y + h, x:x + w]
        if face_roi.size == 0:
            continue

        bbox = {"x": int(x), "y": int(y), "w": int(w), "h": int(h)}

        # No encodings enrolled yet
        if not known:
            detected.append({
                "student_id": None, "name": "Unknown",
                "emotion": None, "confidence": None,
                "similarity": None, "enrolled": None,
                "bbox": bbox,
                "message": "No HOG encodings enrolled — upload roster first",
            })
            continue

        # Match face against enrolled encodings
        query_vec = _hog_descriptor(face_roi)
        sims = [_cosine_sim(query_vec, vec) for _, vec in known]
        best_idx = int(np.argmax(sims))
        best_sim = sims[best_idx]

        if best_sim < SIMILARITY_THRESHOLD:
            # Face detected but not recognised
            detected.append({
                "student_id": None, "name": "Unknown",
                "emotion": None, "confidence": None,
                "similarity": round(best_sim, 3), "enrolled": None,
                "bbox": bbox,
                "message": "Face not found in database",
            })
            continue

        student = known[best_idx][0]

        # Recognised but not enrolled in this class
        if enrolled_ids is not None and student.student_id not in enrolled_ids:
            detected.append({
                "student_id": student.student_id, "name": student.name,
                "emotion": None, "confidence": None,
                "similarity": round(best_sim, 3), "enrolled": False,
                "bbox": bbox,
                "message": f"{student.name} is not enrolled in this class",
            })
            continue

        # Enrolled & recognised — record attendance (idempotent)
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

        # Detect emotion
        emotion = "Focused"
        confidence = CONFIDENCE_MAP["Focused"]
        if fer is not None and face_roi.size > 0:
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
        "faces_found": int(len(faces)) if len(faces) > 0 else 0,
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
        },
        "models_loaded": {
            "face_cascade": _face_cascade is not None,
            "emotion_recognizer": _fer is not None,
        },
        "method": "HOG descriptors + Haar cascade (OpenCV built-in)",
    }
