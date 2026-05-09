import os
import sys
import sqlite3
import subprocess
import time

def check_python():
    print(f"[*] Python Version: {sys.version}")
    try:
        import fastapi
        import sqlalchemy
        import cv2
        import ultralytics
        print("[v] Python libraries: OK")
    except ImportError as e:
        print(f"[x] Missing Python library: {e}")

def check_database():
    db_path = "python-api/data/classroom_v2.db"
    if os.path.exists(db_path):
        print(f"[v] Database file found: {db_path}")
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [t[0] for t in cursor.fetchall()]
            required = ["admins", "lecturers", "students", "lectures", "emotion_log", "attendance_log"]
            missing = [t for t in required if t not in tables]
            if not missing:
                print(f"[v] Database schema: OK ({len(tables)} tables)")
            else:
                print(f"[x] Database missing tables: {missing}")
            conn.close()
        except Exception as e:
            print(f"[x] Database error: {e}")
    else:
        print(f"[x] Database file NOT FOUND: {db_path}")

def check_camera():
    print("[*] Testing Camera 0...")
    import cv2
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        print("[v] Camera access: OK")
        cap.release()
    else:
        print("[!] Camera access: FAILED (This is OK if you don't have a webcam)")

def check_env():
    env_path = "python-api/.env"
    if os.path.exists(env_path):
        print(f"[v] .env file found: {env_path}")
        with open(env_path, 'r') as f:
            content = f.read()
            if "classroom_v2.db" in content:
                print("[v] .env configuration: OK (using local SQLite)")
            else:
                print("[!] .env warning: Not explicitly using classroom_v2.db")
    else:
        print(f"[x] .env file NOT FOUND: {env_path}")

if __name__ == "__main__":
    print("=== AAST LMS SYSTEM DOCTOR ===")
    check_python()
    check_env()
    check_database()
    check_camera()
    print("==============================")
