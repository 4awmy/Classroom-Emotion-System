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
from insightface.app import FaceAnalysis


DB = dict(
    host=os.environ["DB_HOST"],
    port=int(os.environ.get("DB_PORT", 25060)),
    user=os.environ.get("DB_USER", "doadmin"),
    password=os.environ["DB_PASSWORD"],
    dbname=os.environ["DB_NAME"],
    sslmode=os.environ.get("DB_SSLMODE", "require"),
)

ROSTER_PATH = os.environ.get("ROSTER_PATH") or os.environ.get("XLSX_PATH", r"C:\Users\hp\Downloads\StudentPicsDataset.xlsx")

ENCODING_DTYPE = np.float32
ENCODING_DIM = 512

_insight_app = None


def _get_insight_app():
    global _insight_app
    if _insight_app is None:
        print("  [FACE] Loading InsightFace buffalo_sc model (first run only)…")
        _insight_app = FaceAnalysis(name="buffalo_sc", providers=["CPUExecutionProvider"])
        _insight_app.prepare(ctx_id=0, det_size=(640, 640))
        print("  [FACE] InsightFace ready.")
    return _insight_app


def extract_drive_id(url: str):
    patterns = [r"/file/d/([a-zA-Z0-9_-]+)", r"id=([a-zA-Z0-9_-]+)", r"([a-zA-Z0-9_-]{20,})"]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def normalize_student_id(value) -> str:
    sid = str(value).strip()
    if sid.endswith(".0"):
        sid = sid[:-2]
    return sid


def get_face_encoding(image_bytes: bytes):
    try:
        np_arr = np.frombuffer(image_bytes, np.uint8)
        img_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img_bgr is None:
            return None
        app   = _get_insight_app()
        faces = app.get(img_bgr)
        if not faces:
            return None
        # Use the largest detected face
        face = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
        emb  = face.embedding.astype(ENCODING_DTYPE)
        norm = np.linalg.norm(emb)
        emb  = emb / norm if norm > 0 else emb
        if emb.shape[0] != ENCODING_DIM:
            return None
        return emb.tobytes()
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
    print(f"Reading roster: {ROSTER_PATH}")
    if ROSTER_PATH.lower().endswith(".csv"):
        df = pd.read_csv(ROSTER_PATH)
    else:
        df = pd.read_excel(ROSTER_PATH)
    df.columns = [c.strip() for c in df.columns]
    aliases = {"Student ID": "student_id", "Student Name": "name", "Photo Link": "photo_link"}
    df.rename(columns=aliases, inplace=True)
    print(f"Loaded {len(df)} students. Columns: {df.columns.tolist()}")

    conn = make_conn()
    print("Connected to DO PostgreSQL.")

    created = updated = encoded = skipped = errors = 0
    total = len(df)

    for i, row in df.iterrows():
        sid = normalize_student_id(row.get("student_id", ""))
        name = str(row.get("name", "")).strip()
        url = str(row.get("photo_link", "")).strip()

        if not sid or sid == "nan":
            continue

        try:
            cur, conn = db_exec(
                conn,
                "INSERT INTO students (student_id, name, photo_url, needs_password_reset) VALUES (%s, %s, %s, TRUE) "
                "ON CONFLICT (student_id) DO UPDATE SET name = EXCLUDED.name, photo_url = EXCLUDED.photo_url "
                "RETURNING (xmax = 0) AS inserted",
                (sid, name, url),
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
