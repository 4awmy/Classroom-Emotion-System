import logging
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from apscheduler.schedulers.background import BackgroundScheduler
from models import ClassSchedule, Lecture, Class
from database import SessionLocal
import uuid
import threading
from services.vision_pipeline import run_pipeline

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Store stop events for active lectures
active_pipelines = {}

def auto_start_lectures():
    db: Session = SessionLocal()
    try:
        now = datetime.now()
        day_of_week = now.strftime("%A")
        current_time = now.time()

        schedules = db.query(ClassSchedule).filter(
            ClassSchedule.day_of_week == day_of_week,
            ClassSchedule.start_time <= current_time,
            ClassSchedule.end_time > current_time
        ).all()

        for schedule in schedules:
            existing_lecture = db.query(Lecture).filter(
                Lecture.class_id == schedule.class_id,
                Lecture.start_time >= datetime.combine(now.date(), datetime.min.time()),
                Lecture.start_time < datetime.combine(now.date() + timedelta(days=1), datetime.min.time())
            ).first()

            if not existing_lecture:
                class_info = db.query(Class).filter(Class.class_id == schedule.class_id).first()
                new_lecture = Lecture(
                    lecture_id=str(uuid.uuid4()),
                    class_id=schedule.class_id,
                    lecturer_id=class_info.lecturer_id,
                    title=f"Lecture - {class_info.course_id} - {now.date()}",
                    start_time=now,
                    scheduled_start=datetime.combine(now.date(), schedule.start_time)
                )
                db.add(new_lecture)
                db.commit()
                logger.info(f"Started lecture for class {schedule.class_id}")
                
                # Trigger vision pipeline
                stop_event = threading.Event()
                active_pipelines[new_lecture.lecture_id] = stop_event
                threading.Thread(target=run_pipeline, args=(new_lecture.lecture_id, "0", stop_event)).start()
    finally:
        db.close()

def auto_end_lectures():
    db: Session = SessionLocal()
    try:
        now = datetime.now()
        active_lectures = db.query(Lecture).filter(
            Lecture.end_time == None,
            Lecture.start_time != None
        ).all()

        for lecture in active_lectures:
            schedule = db.query(ClassSchedule).filter(
                ClassSchedule.class_id == lecture.class_id,
                ClassSchedule.day_of_week == now.strftime("%A")
            ).first()

            if schedule and now.time() >= schedule.end_time:
                lecture.end_time = now
                db.commit()
                logger.info(f"Ended lecture {lecture.lecture_id}")
                
                # Stop vision pipeline
                if lecture.lecture_id in active_pipelines:
                    active_pipelines[lecture.lecture_id].set()
                    del active_pipelines[lecture.lecture_id]
    finally:
        db.close()

def start_scheduler():
    scheduler = BackgroundScheduler()
    scheduler.add_job(auto_start_lectures, 'interval', minutes=1)
    scheduler.add_job(auto_end_lectures, 'interval', minutes=1)
    scheduler.start()
    return scheduler
