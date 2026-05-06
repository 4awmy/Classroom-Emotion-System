import sys
import os
import random
import datetime

# Add the parent directory to sys.path to import from python-api
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal, engine
import models

def seed_data():
    # Ensure tables are created
    models.Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    try:
        # 1. Create Students
        students = []
        student_names = [
            "Ahmed Ali", "Sara Hassan", "Mohamed Ibrahim", "Layla Mahmoud", 
            "Omar Khalid", "Mariam Youssef", "Ziad Amr", "Nour El-Din",
            "Hana Ahmed", "Kareem Mostafa"
        ]
        
        for i, name in enumerate(student_names):
            student_id = f"2010{i:05d}"
            student = db.query(models.Student).filter(models.Student.student_id == student_id).first()
            if not student:
                student = models.Student(
                    student_id=student_id,
                    name=name,
                    email=f"{name.lower().replace(' ', '.')}@student.aast.edu",
                    face_encoding=None # Placeholder
                )
                db.add(student)
                db.flush() # Get the object in session
                students.append(student)
            else:
                students.append(student)
        
        db.commit()
        print(f"Seeded {len(students)} students.")

        # 2. Create Lectures
        lectures = []
        lecture_data = [
            {"id": "L001", "title": "Introduction to AI", "subject": "Computer Science", "lecturer": "Dr. Samer"},
            {"id": "L002", "title": "Data Structures", "subject": "Computer Science", "lecturer": "Dr. Mona"},
            {"id": "L003", "title": "Digital Logic Design", "subject": "Computer Engineering", "lecturer": "Dr. Ahmed"}
        ]
        
        for data in lecture_data:
            lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == data["id"]).first()
            if not lecture:
                lecture = models.Lecture(
                    lecture_id=data["id"],
                    lecturer_id=f"PROF_{data['lecturer'].split()[-1].upper()}",
                    title=data["title"],
                    subject=data["subject"],
                    start_time=datetime.datetime.utcnow() - datetime.timedelta(hours=2),
                    end_time=datetime.datetime.utcnow() + datetime.timedelta(hours=1),
                    slide_url="https://example.com/slides"
                )
                db.add(lecture)
                db.flush()
                lectures.append(lecture)
            else:
                lectures.append(lecture)
        
        db.commit()
        print(f"Seeded {len(lectures)} lectures.")

        # 3. Create Materials
        for lecture in lectures:
            material = db.query(models.Material).filter(models.Material.lecture_id == lecture.lecture_id).first()
            if not material:
                material = models.Material(
                    material_id=f"M_{lecture.lecture_id}",
                    lecture_id=lecture.lecture_id,
                    lecturer_id=lecture.lecturer_id,
                    title=f"Handout for {lecture.title}",
                    drive_link="https://drive.google.com/example"
                )
                db.add(material)
        
        db.commit()
        print("Seeded materials.")

        # 4. Create Attendance
        for lecture in lectures:
            for student in students:
                attendance = db.query(models.AttendanceLog).filter(
                    models.AttendanceLog.student_id == student.student_id,
                    models.AttendanceLog.lecture_id == lecture.lecture_id
                ).first()
                if not attendance:
                    attendance = models.AttendanceLog(
                        student_id=student.student_id,
                        lecture_id=lecture.lecture_id,
                        status="Present",
                        method="AI",
                        timestamp=lecture.start_time + datetime.timedelta(minutes=random.randint(0, 15))
                    )
                    db.add(attendance)
        
        db.commit()
        print("Seeded attendance logs.")

        # 5. Create Emotion Logs — use locked fixed confidence values (CLAUDE.md §8.2)
        EMOTION_CONFIDENCE = {
            "Focused": 1.00, "Engaged": 0.85, "Confused": 0.55,
            "Anxious": 0.35, "Frustrated": 0.25, "Disengaged": 0.00,
        }
        # Realistic HSEmotion raw label mapping for each educational state
        RAW_LABEL_FOR_STATE = {
            "Focused": "neutral",
            "Engaged": "happy",
            "Confused": "anger",    # anger with low intensity → Confused
            "Anxious": "fear",
            "Frustrated": "disgust",
            "Disengaged": "sad",
        }
        emotions = list(EMOTION_CONFIDENCE.keys())
        count = 0
        for lecture in lectures:
            for student in students:
                # Generate 35-45 logs per student per lecture to reach 1000+ total
                num_logs = random.randint(35, 45)
                for _ in range(num_logs):
                    emotion = random.choice(emotions)
                    confidence = EMOTION_CONFIDENCE[emotion]
                    log = models.EmotionLog(
                        student_id=student.student_id,
                        lecture_id=lecture.lecture_id,
                        timestamp=lecture.start_time + datetime.timedelta(minutes=random.randint(0, 120)),
                        raw_emotion=RAW_LABEL_FOR_STATE[emotion],
                        raw_confidence=round(random.uniform(0.50, 0.95), 3),  # simulated model certainty
                        emotion=emotion,
                        confidence=confidence,
                        engagement_score=confidence  # engagement_score == confidence (locked)
                    )
                    db.add(log)
                    count += 1
        
        db.commit()
        print(f"Seeded {count} emotion logs.")

    except Exception as e:
        print(f"Error seeding data: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_data()
