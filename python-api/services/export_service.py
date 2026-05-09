import os
import pandas as pd
from apscheduler.schedulers.background import BackgroundScheduler
from database import SessionLocal
import models
from services import gemini_service

EXPORT_DIR = "data/exports"
PLANS_DIR = "data/plans"

def export_all():
    db = SessionLocal()
    try:
        os.makedirs(EXPORT_DIR, exist_ok=True)
        queries = {
            "emotions":      "SELECT e.student_id, s.name, e.lecture_id, e.timestamp, e.emotion, e.confidence, e.engagement_score FROM emotion_log e JOIN students s ON e.student_id = s.student_id",
            "attendance":    "SELECT a.student_id, s.name, a.lecture_id, a.timestamp, a.status, a.method, a.snapshot_path FROM attendance_log a JOIN students s ON a.student_id = s.student_id",
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

def generate_nightly_plans():
    """Generates AI intervention plans for each student based on their emotion history."""
    db = SessionLocal()
    try:
        os.makedirs(PLANS_DIR, exist_ok=True)
        students = db.query(models.Student).all()
        for student in students:
            # Get last 50 emotion logs for this student
            emotions = db.query(models.EmotionLog).filter(
                models.EmotionLog.student_id == student.student_id
            ).order_by(models.EmotionLog.timestamp.desc()).limit(50).all()
            
            if not emotions:
                continue
                
            history = [{"emotion": e.emotion, "timestamp": e.timestamp.isoformat()} for e in emotions]
            plan = gemini_service.generate_intervention_plan(history)
            
            with open(os.path.join(PLANS_DIR, f"{student.student_id}.md"), "w", encoding="utf-8") as f:
                f.write(plan)
            print(f"[PLANS] Generated plan for {student.student_id}")
    except Exception as e:
        print(f"[PLANS] Error generating plans: {e}")
    finally:
        db.close()

scheduler = BackgroundScheduler()
# Export every 10 seconds for Live Dashboard
scheduler.add_job(export_all, "interval", seconds=10)
scheduler.add_job(generate_nightly_plans, "cron", hour=2, minute=30)
scheduler.start()
