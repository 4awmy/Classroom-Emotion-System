import os
import sys
import pandas as pd
import io
import requests
import face_recognition
import numpy as np
import re
from sqlalchemy.orm import Session

# Add parent directory to sys.path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal, engine
from models import Student, Base

def extract_drive_id(url: str) -> str | None:
    if not url or str(url) == "nan":
        return None
    patterns = [
        r'/file/d/([a-zA-Z0-9_-]+)',
        r'id=([a-zA-Z0-9_-]+)',
        r'([a-zA-Z0-9_-]{25,})'
    ]
    for pattern in patterns:
        match = re.search(pattern, str(url))
        if match:
            return match.group(1)
    return None

def get_face_encoding(image_bytes: bytes) -> bytes | None:
    try:
        img = face_recognition.load_image_file(io.BytesIO(image_bytes))
        encodings = face_recognition.face_encodings(img)
        if encodings:
            return encodings[0].astype(np.float64).tobytes()
    except Exception as e:
        print(f"  [ERROR] Face encoding failed: {e}")
    return None

def encode_dataset():
    csv_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "StudentPicsDataset.csv")
    if not os.path.exists(csv_path):
        print(f"Dataset not found at {csv_path}")
        return

    print(f"Loading dataset from {csv_path}...")
    df = pd.read_csv(csv_path)
    
    # Standardize columns
    df.columns = [str(c).strip().lower().replace(" ", "_") for c in df.columns]
    
    # Deduplicate by student_id to prevent UNIQUE constraint failures
    if "student_id" in df.columns:
        original_count = len(df)
        df = df.drop_duplicates(subset=["student_id"], keep="first")
        new_count = len(df)
        if original_count > new_count:
            print(f"Removed {original_count - new_count} duplicate student entries.")

    db = SessionLocal()

    created = 0
    updated = 0
    failed = 0

    print(f"Processing {len(df)} rows...")
    
    for idx, row in df.iterrows():
        sid = str(row.get("student_id", "")).strip().split(".")[0]
        name = str(row.get("student_name", row.get("name", ""))).strip()
        url = str(row.get("photo_link", "")).strip()

        if not re.match(r'^\d{9}$', sid):
            print(f"[{idx+1}/{len(df)}] Skipping invalid ID: {sid}")
            continue

        print(f"[{idx+1}/{len(df)}] Processing {sid} ({name})...", end=" ", flush=True)

        student = db.query(Student).filter(Student.student_id == sid).first()
        if not student:
            student = Student(student_id=sid, name=name)
            db.add(student)
            created += 1
        else:
            student.name = name
            updated += 1

        # Encoding
        file_id = extract_drive_id(url)
        if file_id:
            try:
                resp = requests.get(f"https://drive.google.com/uc?export=download&id={file_id}", timeout=20)
                if resp.status_code == 200:
                    encoding = get_face_encoding(resp.content)
                    if encoding:
                        student.face_encoding = encoding
                        print("SUCCESS (Encoded)")
                    else:
                        print("FAILED (No face detected)")
                        failed += 1
                else:
                    print(f"FAILED (HTTP {resp.status_code})")
                    failed += 1
            except Exception as e:
                print(f"FAILED ({e})")
                failed += 1
        else:
            print("SKIPPED (No Drive ID)")

        # Commit every 10 rows to be safe
        if (idx + 1) % 10 == 0:
            db.commit()

    db.commit()
    db.close()
    print("\nEncoding Complete!")
    print(f"New Students: {created}")
    print(f"Updated Students: {updated}")
    print(f"Failed/Skipped Encodings: {failed}")

if __name__ == "__main__":
    # Ensure tables exist
    Base.metadata.create_all(bind=engine)
    encode_dataset()
