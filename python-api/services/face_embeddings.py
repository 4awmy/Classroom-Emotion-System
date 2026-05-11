from typing import Optional

import numpy as np

try:
    import cv2
    _CV2_OK = True
except ImportError:
    _CV2_OK = False

try:
    from deepface import DeepFace
    _DEEPFACE_OK = True
except ImportError:
    _DEEPFACE_OK = False


ENCODING_DTYPE = np.float32
ENCODING_DIM = 512
ARCFACE_MODEL_NAME = "ArcFace"

_face_cascade = None


def cv2_available() -> bool:
    return _CV2_OK


def deepface_available() -> bool:
    return _DEEPFACE_OK


def embeddings_available() -> bool:
    return _CV2_OK and _DEEPFACE_OK


def get_cascade():
    global _face_cascade
    if _face_cascade is None and _CV2_OK:
        _face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
    return _face_cascade


def normalize_embedding(embedding: np.ndarray) -> np.ndarray:
    embedding = embedding.astype(ENCODING_DTYPE)
    norm = np.linalg.norm(embedding)
    return embedding / norm if norm > 0 else embedding


def cosine_sim(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    return float(np.dot(a, b) / (denom + 1e-8))


def arcface_embedding(face_bgr: np.ndarray) -> Optional[np.ndarray]:
    if not _DEEPFACE_OK or face_bgr.size == 0:
        return None
    try:
        result = DeepFace.represent(
            img_path=face_bgr,
            model_name=ARCFACE_MODEL_NAME,
            detector_backend="skip",
            enforce_detection=False,
        )
        if not result:
            return None
        embedding = np.array(result[0]["embedding"], dtype=ENCODING_DTYPE)
        if embedding.shape[0] != ENCODING_DIM:
            return None
        return normalize_embedding(embedding)
    except Exception as exc:
        print(f"[FACE] ArcFace embedding error: {exc}")
        return None


def largest_face_roi(img_bgr: np.ndarray) -> Optional[np.ndarray]:
    if not _CV2_OK or img_bgr is None:
        return None
    cascade = get_cascade()
    if cascade is None:
        return None
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
    if len(faces) == 0:
        return None
    x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
    face_roi = img_bgr[y:y + h, x:x + w]
    return face_roi if face_roi.size > 0 else None


def image_bytes_to_embedding_bytes(image_bytes: bytes) -> Optional[bytes]:
    if not embeddings_available():
        return None
    np_arr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        return None
    face_roi = largest_face_roi(img_bgr)
    if face_roi is None:
        return None
    embedding = arcface_embedding(face_roi)
    return embedding.tobytes() if embedding is not None else None
