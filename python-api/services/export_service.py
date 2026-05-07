import os
import pandas as pd
from apscheduler.schedulers.background import BackgroundScheduler
from database import SessionLocal

EXPORT_DIR = "data/exports"

def export_all():
    db = SessionLocal()
    try:
        os.makedirs(EXPORT_DIR, exist_ok=True)
        queries = {
            "emotions":      "SELECT student_id, lecture_id, timestamp, emotion, confidence, engagement_score FROM emotion_log",
            "attendance":    "SELECT student_id, lecture_id, timestamp, status, method, snapshot_path FROM attendance_log",
            "materials":     "SELECT material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at FROM materials",
            "incidents":     "SELECT student_id, exam_id, timestamp, flag_type, severity, evidence_path FROM incidents",
            "notifications": "SELECT student_id, lecturer_id, lecture_id, reason, created_at, read FROM notifications",
        }
        for name, query in queries.items():
            df = pd.read_sql(query, db.bind)
            tmp = f"{EXPORT_DIR}/{name}.tmp.csv"
            df.to_csv(tmp, index=False, encoding="utf-8-sig")
            os.replace(tmp, f"{EXPORT_DIR}/{name}.csv")
    except Exception as e:
        print(f"[EXPORT] Error during export_all: {e}")
    finally:
        db.close()

scheduler = BackgroundScheduler()
scheduler.add_job(export_all, "cron", hour=2, minute=0)
scheduler.start()
