from typing import Optional
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


ENCODING_DTYPE = np.float32
ENCODING_DIM   = 512  # InsightFace ArcFace (buffalo_sc) embedding dimension

_insight_app  = None
_face_cascade = None


def cv2_available() -> bool:
    return _CV2_OK


def deepface_available() -> bool:
    """Kept for backward compat with vision.py imports — now means insightface available."""
    return _INSIGHT_OK


def embeddings_available() -> bool:
    return _CV2_OK and _INSIGHT_OK


def _get_insight_app():
    global _insight_app
    if _insight_app is None and _INSIGHT_OK:
        _insight_app = FaceAnalysis(
            name="buffalo_sc",
            providers=["CPUExecutionProvider"],
        )
        _insight_app.prepare(ctx_id=0, det_size=(640, 640))
    return _insight_app


def get_cascade():
    """Haar cascade — still used for emotion ROI cropping in vision.py."""
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


def detect_and_embed(frame_bgr: np.ndarray) -> list:
    """
    Detect all faces in a full frame using InsightFace RetinaFace + ArcFace.
    Returns list of {"bbox": {x,y,w,h}, "embedding": np.ndarray (512-dim)}.
    Produces properly aligned embeddings — more accurate than Haar+crop.
    """
    if not _INSIGHT_OK or frame_bgr is None or frame_bgr.size == 0:
        return []
    try:
        app = _get_insight_app()
        if app is None:
            return []
        faces = app.get(frame_bgr)
        result = []
        for face in faces:
            if face.embedding is None:
                continue
            x1, y1, x2, y2 = [int(c) for c in face.bbox]
            x1, y1 = max(0, x1), max(0, y1)
            result.append({
                "bbox": {"x": x1, "y": y1, "w": max(1, x2 - x1), "h": max(1, y2 - y1)},
                "embedding": normalize_embedding(face.embedding),
            })
        return result
    except Exception as exc:
        print(f"[FACE] detect_and_embed error: {exc}")
        return []


def arcface_embedding(face_bgr: np.ndarray) -> Optional[np.ndarray]:
    """
    Get embedding from a pre-cropped face ROI.
    Runs detection again inside the crop — use detect_and_embed on full frames instead.
    """
    if not _INSIGHT_OK or face_bgr is None or face_bgr.size == 0:
        return None
    try:
        h, w = face_bgr.shape[:2]
        if h < 64 or w < 64:
            face_bgr = cv2.resize(face_bgr, (128, 128))
        faces = detect_and_embed(face_bgr)
        if faces:
            return faces[0]["embedding"]
        # Fallback: no face detected in the crop — embed the crop directly
        app = _get_insight_app()
        if app is None:
            return None
        rec = next((m for m in app.models.values() if hasattr(m, "get_feat")), None)
        if rec is None:
            return None
        face_resized = cv2.resize(face_bgr, (112, 112))
        emb = rec.get_feat(face_resized[np.newaxis, ...])
        return normalize_embedding(emb[0])
    except Exception as exc:
        print(f"[FACE] arcface_embedding error: {exc}")
        return None


def image_bytes_to_embedding_bytes(image_bytes: bytes) -> Optional[bytes]:
    """For roster loading: detect largest face, return its ArcFace embedding as bytes."""
    if not embeddings_available():
        return None
    np_arr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        return None
    faces = detect_and_embed(img_bgr)
    if not faces:
        return None
    largest = max(faces, key=lambda f: f["bbox"]["w"] * f["bbox"]["h"])
    return largest["embedding"].tobytes()
