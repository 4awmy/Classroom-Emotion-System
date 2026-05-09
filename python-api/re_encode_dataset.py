import os
import cv2
import face_recognition
import numpy as np
from sqlalchemy.orm import Session
from database import SessionLocal
import models
import requests
import io

def get_google_drive_direct_link(url):
    """Converts a Google Drive sharing link to a direct download link."""
    if "id=" in url:
        file_id = url.split("id=")[1].split("&")[0]
        return f"https://drive.google.com/uc?export=download&id={file_id}"
    return url

def re_encode_all_students():
    """
    Downloads photos from Google Drive, generates biometric signatures, 
    and saves them to the local PostgreSQL database.
    """
    db = SessionLocal()
    print("[*] Starting biometric re-encoding with Direct Link support...")
    
    students = db.query(models.Student).filter(models.Student.photo_url != None).all()
    print(f"[*] Processing {len(students)} students.")
    
    success_count = 0
    fail_count = 0
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    for student in students:
        img = None
        direct_url = get_google_drive_direct_link(student.photo_url)
        
        try:
            # Download image bytes
            resp = requests.get(direct_url, headers=headers, timeout=10)
            if resp.status_code == 200:
                nparr = np.frombuffer(resp.content, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            else:
                print(f"[!] HTTP {resp.status_code} for {student.student_id}")
        except Exception as e:
            print(f"[!] Network error for {student.student_id}: {e}")
                
        if img is not None:
            # AI Encoding
            rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            face_locations = face_recognition.face_locations(rgb_img)
            
            if face_locations:
                encodings = face_recognition.face_encodings(rgb_img, face_locations)
                if encodings:
                    student.face_encoding = encodings[0].tobytes()
                    db.commit()
                    print(f"[v] SUCCESS: Biometrics generated for {student.student_id}")
                    success_count += 1
                    continue
        
        print(f"[x] FAILED: Could not detect face for student {student.student_id}")
        fail_count += 1

    print(f"\n[SUMMARY] Biometric Encoding Complete.")
    print(f"Success: {success_count}")
    print(f"Failed:  {fail_count}")
    db.close()

if __name__ == "__main__":
    re_encode_all_students()
