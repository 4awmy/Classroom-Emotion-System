import os
import io
import pandas as pd
import boto3
from apscheduler.schedulers.background import BackgroundScheduler
from database import SessionLocal, DATA_DIR

# Path for local CSV exports (R/Shiny reads from here)
EXPORT_DIR = os.path.join(DATA_DIR, "exports")

def export_all():
    """
    Nightly export of all SQLite tables to CSV for R/Shiny analytics.
    Implements atomic writes (write to temp then rename) and UTF-8-SIG encoding.
    """
    db = SessionLocal()
    try:
        # Queries match ARCHITECTURE.md §6.3 "Locked" schemas
        queries = {
            "emotions":      "SELECT student_id, lecture_id, timestamp, emotion, confidence, engagement_score FROM emotion_log",
            "attendance":    "SELECT student_id, lecture_id, timestamp, status, method FROM attendance_log",
            "materials":     "SELECT material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at FROM materials",
            "incidents":     "SELECT student_id, exam_id, timestamp, flag_type, severity, evidence_path FROM incidents",
            "notifications": "SELECT student_id, lecturer_id, lecture_id, reason, created_at, read FROM notifications",
        }
        
        # Ensure export directory exists
        os.makedirs(EXPORT_DIR, exist_ok=True)

        # Initialize S3 client for Digital Ocean Spaces (optional production backup)
        s3_enabled = all([
            os.getenv('SPACES_KEY'),
            os.getenv('SPACES_SECRET'),
            os.getenv('SPACES_ENDPOINT'),
            os.getenv('SPACES_BUCKET')
        ])
        
        client = None
        bucket = None
        if s3_enabled:
            try:
                session = boto3.session.Session()
                client = session.client(
                    's3',
                    region_name=os.getenv('SPACES_REGION'),
                    endpoint_url=os.getenv('SPACES_ENDPOINT'),
                    aws_access_key_id=os.getenv('SPACES_KEY'),
                    aws_secret_access_key=os.getenv('SPACES_SECRET')
                )
                bucket = os.getenv('SPACES_BUCKET')
            except Exception as s3_err:
                print(f"S3 Client initialization failed: {s3_err}")
                client = None

        for name, query in queries.items():
            # Use db.bind to execute the query
            df = pd.read_sql(query, db.bind)
            
            # 1. Local Export (Atomic write: write to temp then rename)
            # This ensures R/Shiny never reads a partially written file.
            final_path = os.path.join(EXPORT_DIR, f"{name}.csv")
            tmp_path = f"{final_path}.tmp"
            
            # Use utf-8-sig to ensure Arabic names in roster are handled correctly by Excel/Shiny
            df.to_csv(tmp_path, index=False, encoding="utf-8-sig")
            
            # Atomic rename (os.replace is atomic on POSIX)
            if os.path.exists(tmp_path):
                os.replace(tmp_path, final_path)
            
            # 2. S3 Export (if enabled)
            if client and bucket:
                # Write to in-memory buffer
                csv_buffer = io.StringIO()
                df.to_csv(csv_buffer, index=False, encoding="utf-8-sig")
                
                # Upload to Spaces
                client.put_object(
                    Bucket=bucket,
                    Key=f"exports/{name}.csv",
                    Body=csv_buffer.getvalue(),
                    ACL='private'
                )
        print(f"Successfully exported {len(queries)} tables to {EXPORT_DIR}")
    except Exception as e:
        print(f"Error during export_all: {e}")
    finally:
        db.close()

# Configure scheduler to run nightly at 02:00
scheduler = BackgroundScheduler()
scheduler.add_job(export_all, "cron", hour=2, minute=0)
scheduler.start()
