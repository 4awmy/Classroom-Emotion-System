import sqlite3
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os

# Database path
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "python-api", "data", "classroom_emotions.db")

def seed_data():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Clear existing data
    cursor.execute("DELETE FROM emotion_log")
    cursor.execute("DELETE FROM attendance_log")
    cursor.execute("DELETE FROM students")
    cursor.execute("DELETE FROM lectures")

    # 1. Seed Students
    students = [
        ("S01", "Omar Metwalli", "o.metwalli@student.aast.edu"),
        ("S02", "Ahmed Morsi", "a.morsi@student.aast.edu"),
        ("S03", "Mohamed Hassan", "m.hassan@student.aast.edu"),
        ("S04", "Sara Ali", "s.ali@student.aast.edu"),
        ("S05", "Nour Ibrahim", "n.khaled@student.aast.edu")
    ]
    cursor.executemany("INSERT INTO students (student_id, name, email) VALUES (?, ?, ?)", students)

    # 2. Seed Lectures
    lectures = [
        ("L1", "LECT01", "Introduction to AI", "Computer Science", datetime.now() - timedelta(days=1), datetime.now() - timedelta(days=1, hours=-2), "http://drive.google.com/slide1"),
        ("L2", "LECT01", "Neural Networks", "Computer Science", datetime.now(), None, "http://drive.google.com/slide2")
    ]
    cursor.executemany("INSERT INTO lectures (lecture_id, lecturer_id, title, subject, start_time, end_time, slide_url) VALUES (?, ?, ?, ?, ?, ?, ?)", lectures)

    # 3. Seed Emotion Log (1000+ rows)
    emotions = ["Focused", "Engaged", "Confused", "Anxious", "Frustrated", "Disengaged"]
    weights = [0.30, 0.25, 0.20, 0.10, 0.10, 0.05]
    confidence_map = {
        "Focused": 1.00, "Engaged": 0.85, "Confused": 0.55,
        "Anxious": 0.35, "Frustrated": 0.25, "Disengaged": 0.00
    }

    logs = []
    start_time = datetime.now() - timedelta(hours=1)
    
    for i in range(1100):
        student_id = f"S0{np.random.randint(1, 6)}"
        emotion = np.random.choice(emotions, p=weights)
        confidence = confidence_map[emotion]
        timestamp = start_time + timedelta(seconds=i*5)
        
        logs.append((student_id, "L2", timestamp, emotion, confidence, confidence))

    cursor.executemany("INSERT INTO emotion_log (student_id, lecture_id, timestamp, emotion, confidence, engagement_score) VALUES (?, ?, ?, ?, ?, ?)", logs)

    # 4. Seed Attendance
    for s_id, _, _ in students:
        cursor.execute("INSERT INTO attendance_log (student_id, lecture_id, timestamp, status, method) VALUES (?, ?, ?, ?, ?)",
                       (s_id, "L1", datetime.now() - timedelta(days=1), "Present", "AI"))

    conn.commit()
    conn.close()
    print(f"Successfully seeded 1100 rows into {DB_PATH}")

if __name__ == "__main__":
    seed_data()
