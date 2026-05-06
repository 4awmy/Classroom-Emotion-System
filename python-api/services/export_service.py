import os
import io
import pandas as pd
import boto3
from apscheduler.schedulers.background import BackgroundScheduler
from database import SessionLocal

def export_all():
    db = SessionLocal()
    try:
        queries = {
            "emotions":      "SELECT student_id, lecture_id, timestamp, raw_emotion, raw_confidence, emotion, confidence, engagement_score FROM emotion_log",
            "attendance":    "SELECT student_id, lecture_id, timestamp, status, method FROM attendance_log",
            "materials":     "SELECT material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at FROM materials",
            "incidents":     "SELECT student_id, exam_id, timestamp, flag_type, severity, evidence_path FROM incidents",
            "transcripts":   "SELECT lecture_id, timestamp, chunk_text, language FROM transcripts",
            "notifications": "SELECT student_id, lecturer_id, lecture_id, reason, created_at, read FROM notifications",
        }
        
        # Initialize S3 client for Digital Ocean Spaces
        session = boto3.session.Session()
        client = session.client(
            's3',
            region_name=os.getenv('SPACES_REGION'),
            endpoint_url=os.getenv('SPACES_ENDPOINT'),
            aws_access_key_id=os.getenv('SPACES_KEY'),
            aws_secret_access_key=os.getenv('SPACES_SECRET')
        )
        bucket = os.getenv('SPACES_BUCKET')

        for name, query in queries.items():
            # Use db.bind to execute the query
            df = pd.read_sql(query, db.bind)
            
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
    except Exception as e:
        print(f"Error during export_all: {e}")
    finally:
        db.close()

scheduler = BackgroundScheduler()
scheduler.add_job(export_all, "cron", hour=2, minute=0)
scheduler.start()
