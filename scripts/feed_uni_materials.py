import os
import psycopg2
import uuid
from datetime import datetime

# Database Configuration (From environment variables)
DB_CONFIG = {
    "host": os.getenv("DB_HOST", ""),
    "port": int(os.getenv("DB_PORT", 25060)),
    "user": os.getenv("DB_USER", ""),
    "password": os.getenv("DB_PASSWORD", ""),
    "dbname": os.getenv("DB_NAME", ""),
    "sslmode": "require"
}

def feed_materials(folder_path, class_id="CLASS_10230", lecturer_id="omar"):
    print(f"[*] Scanning folder: {folder_path}")
    
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        print("[v] Connected to DigitalOcean Database.")

        # 1. Ensure a default lecture exists for this test
        lecture_id = f"LEC_{datetime.now().strftime('%m%d_%H%M')}"
        cur.execute(
            "INSERT INTO lectures (lecture_id, class_id, lecturer_id, title, start_time, status) "
            "VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT DO NOTHING",
            (lecture_id, class_id, lecturer_id, "Uni Material Import", datetime.now(), "completed")
        )

        # 2. Scan for PDF/PPT/TXT files
        count = 0
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                if file.lower().endswith(('.pdf', '.pptx', '.ppt', '.txt', '.docx')):
                    file_path = os.path.join(root, file).replace("\\", "/")
                    material_id = str(uuid.uuid4())[:8].upper()
                    
                    print(f"    [+] Adding: {file}")
                    cur.execute(
                        "INSERT INTO materials (material_id, lecture_id, lecturer_id, title, drive_link) "
                        "VALUES (%s, %s, %s, %s, %s)",
                        (material_id, lecture_id, lecturer_id, file, file_path)
                    )
                    count += 1
        
        conn.commit()
        cur.close()
        conn.close()
        print(f"\n[SUCCESS] Added {count} materials to lecture {lecture_id}.")
        print("[!] You can now test the AI using this lecture_id.")

    except Exception as e:
        print(f"[x] Error: {e}")

if __name__ == "__main__":
    # You can change this path when you run it from your terminal
    uni_path = r"C:\Users\omarh\OneDrive\Desktop\Uni"
    feed_materials(uni_path)
