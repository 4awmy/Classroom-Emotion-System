import sqlite3
import random
from datetime import datetime, timedelta

# --- Config ---
DB_PATH = "classroom_emotions.db"
START_ID = 231006367
NUM_STUDENTS = 127
EMOTIONS = ["happy", "sad", "angry", "surprised", "neutral", "fearful", "disgusted"]
SESSIONS = ["2026-01-10", "2026-01-12", "2026-01-14", "2026-01-17", "2026-01-19"]

# --- Generate student IDs ---
student_ids = [START_ID + i for i in range(NUM_STUDENTS)]

# --- Connect to DB ---
conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# --- Create tables ---
cursor.execute("""
CREATE TABLE IF NOT EXISTS students (
    student_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS emotion_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    emotion TEXT NOT NULL,
    confidence REAL NOT NULL,
    timestamp TEXT NOT NULL,
    session_date TEXT NOT NULL,
    FOREIGN KEY (student_id) REFERENCES students(student_id)
)
""")

# --- Seed students ---
cursor.execute("DELETE FROM students")
cursor.execute("DELETE FROM emotion_log")

for sid in student_ids:
    cursor.execute("INSERT INTO students (student_id, name) VALUES (?, ?)",
                   (sid, f"Student_{sid}"))

# --- Seed emotion_log (1000+ rows) ---
logs = []
base_time = datetime(2026, 1, 10, 8, 0, 0)

for i in range(1100):  # 1100 rows to safely exceed 1000
    sid = random.choice(student_ids)
    emotion = random.choice(EMOTIONS)
    confidence = round(random.uniform(0.60, 0.99), 4)
    timestamp = (base_time + timedelta(minutes=i * 5)).strftime("%Y-%m-%d %H:%M:%S")
    session = random.choice(SESSIONS)
    logs.append((sid, emotion, confidence, timestamp, session))

cursor.executemany("""
INSERT INTO emotion_log (student_id, emotion, confidence, timestamp, session_date)
VALUES (?, ?, ?, ?, ?)
""", logs)

conn.commit()

# --- Verify ---
student_count = cursor.execute("SELECT COUNT(*) FROM students").fetchone()[0]
log_count = cursor.execute("SELECT COUNT(*) FROM emotion_log").fetchone()[0]

print(f"✅ Students seeded: {student_count}")
print(f"✅ Emotion log rows: {log_count}")

conn.close()