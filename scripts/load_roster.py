"""
Direct roster loader - reads XLSX locally, connects to DO PostgreSQL,
downloads Google Drive photos, generates DeepFace ArcFace face embeddings,
and upserts all students.

Credentials are read from environment variables. Set them before running:
  set DB_HOST=<host>
  set DB_PORT=25060
  set DB_USER=doadmin
  set DB_PASSWORD=<password>
  set DB_NAME=<dbname>
Or copy scripts/.env.example to scripts/.env and fill in the values,
then run: python -m dotenv -f scripts/.env run python scripts/load_roster.py
"""

import os
import re
import sys
import time

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

import cv2
import numpy as np
import pandas as pd
import psycopg2
import requests
from deepface import DeepFace


DB = dict(
    host=os.environ["DB_HOST"],
    port=int(os.environ.get("DB_PORT", 25060)),
    user=os.environ.get("DB_USER", "doadmin"),
    password=os.environ["DB_PASSWORD"],
    dbname=os.environ["DB_NAME"],
    sslmode=os.environ.get("DB_SSLMODE", "require"),
)

XLSX_PATH = os.environ.get("XLSX_PATH", r"C:\Users\hp\Downloads\StudentPicsDataset.xlsx")

ENCODING_DTYPE = np.float32
ENCODING_DIM = 512


def _get_cascade():
    return cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")


_cascade = _get_cascade()


def _arcface_embedding(face_bgr: np.ndarray):
    result = DeepFace.represent(
        img_path=face_bgr,
        model_name="ArcFace",
        detector_backend="skip",
        enforce_detection=False,
    )
    if not result:
        return None
    embedding = np.array(result[0]["embedding"], dtype=ENCODING_DTYPE)
    if embedding.shape[0] != ENCODING_DIM:
        return None
    norm = np.linalg.norm(embedding)
    return embedding / norm if norm > 0 else embedding


def extract_drive_id(url: str):
    patterns = [r"/file/d/([a-zA-Z0-9_-]+)", r"id=([a-zA-Z0-9_-]+)", r"([a-zA-Z0-9_-]{20,})"]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def get_face_encoding(image_bytes: bytes):
    try:
        np_arr = np.frombuffer(image_bytes, np.uint8)
        img_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img_bgr is None:
            return None
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        faces = _cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
        if len(faces) == 0:
            return None
        x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
        face_roi = img_bgr[y:y + h, x:x + w]
        if face_roi.size == 0:
            return None
        embedding = _arcface_embedding(face_roi)
        return embedding.tobytes() if embedding is not None else None
    except Exception as exc:
        print(f"  [ENCODING] {str(exc)[:80]}")
        return None


def make_conn():
    return psycopg2.connect(**DB)


def db_exec(conn, query, params=()):
    """Execute with auto-reconnect."""
    for _ in range(3):
        try:
            cur = conn.cursor()
            cur.execute(query, params)
            return cur, conn
        except (psycopg2.OperationalError, psycopg2.InterfaceError):
            print("  [DB] Reconnecting...")
            try:
                conn.close()
            except Exception:
                pass
            conn = make_conn()
    raise RuntimeError("Could not reconnect to DB after 3 attempts")


def main():
    print(f"Reading XLSX: {XLSX_PATH}")
    df = pd.read_excel(XLSX_PATH)
    df.columns = [c.strip() for c in df.columns]
    aliases = {"Student ID": "student_id", "Student Name": "name", "Photo Link": "photo_link"}
    df.rename(columns=aliases, inplace=True)
    print(f"Loaded {len(df)} students. Columns: {df.columns.tolist()}")

    conn = make_conn()
    print("Connected to DO PostgreSQL.")

    created = updated = encoded = skipped = errors = 0
    total = len(df)

    for i, row in df.iterrows():
        sid = str(row.get("student_id", "")).strip()
        name = str(row.get("name", "")).strip()
        url = str(row.get("photo_link", "")).strip()

        if not sid or sid == "nan":
            continue

        try:
            cur, conn = db_exec(
                conn,
                "INSERT INTO students (student_id, name, needs_password_reset) VALUES (%s, %s, TRUE) "
                "ON CONFLICT (student_id) DO UPDATE SET name = EXCLUDED.name "
                "RETURNING (xmax = 0) AS inserted",
                (sid, name),
            )
            row_result = cur.fetchone()
            if row_result and row_result[0]:
                created += 1
            else:
                updated += 1
            conn.commit()
        except Exception as exc:
            print(f"  [{i + 1}/{total}] UPSERT error for {sid}: {exc}")
            try:
                conn.rollback()
            except Exception:
                pass
            errors += 1
            continue

        try:
            cur, conn = db_exec(
                conn,
                "SELECT octet_length(face_encoding) FROM students WHERE student_id = %s",
                (sid,),
            )
            existing = cur.fetchone()
            if existing and existing[0] == ENCODING_DIM * np.dtype(ENCODING_DTYPE).itemsize:
                print(f"  [{i + 1}/{total}] {name[:30]:30s}  (already ArcFace encoded, skip)")
                continue
        except Exception:
            pass

        file_id = extract_drive_id(url) if url and url != "nan" else None
        if not file_id:
            skipped += 1
            print(f"  [{i + 1}/{total}] {name[:30]:30s}  - no photo link")
            continue

        dl_status = "?"
        try:
            dl_url = f"https://drive.google.com/uc?export=download&id={file_id}"
            resp = requests.get(dl_url, timeout=25)
            if resp.status_code == 200 and len(resp.content) > 1000:
                encoding = get_face_encoding(resp.content)
                if encoding:
                    cur, conn = db_exec(
                        conn,
                        "UPDATE students SET face_encoding = %s WHERE student_id = %s",
                        (psycopg2.Binary(encoding), sid),
                    )
                    conn.commit()
                    encoded += 1
                    dl_status = "encoded"
                else:
                    skipped += 1
                    dl_status = "no face detected"
            else:
                skipped += 1
                dl_status = f"HTTP {resp.status_code}"
        except Exception as exc:
            skipped += 1
            dl_status = str(exc)[:40]

        print(f"  [{i + 1}/{total}] {name[:30]:30s}  {dl_status}")
        time.sleep(0.15)

    try:
        conn.close()
    except Exception:
        pass

    print("\n" + "=" * 50)
    print(f"Done! Created: {created} | Updated: {updated} | Encoded: {encoded} | Skipped: {skipped} | Errors: {errors}")


if __name__ == "__main__":
    main()
