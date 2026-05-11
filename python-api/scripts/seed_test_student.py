import cv2
from sqlalchemy.orm import Session
from database import SessionLocal
from models import Student
import os
from services.face_embeddings import arcface_embedding

def seed_self():
    print("Please look at the camera for 3 seconds...")
    cap = cv2.VideoCapture(0)
    
    # Give the camera time to warm up
    for _ in range(10):
        cap.read()
        
    ret, frame = cap.read()
    cap.release()
    
    if not ret:
        print("Error: Could not capture from webcam.")
        return

    encoding = arcface_embedding(frame)

    if encoding is None:
        print("Error: No face detected in the frame. Please try again.")
        return

    encoding_bytes = encoding.tobytes()

    db = SessionLocal()
    
    # Check if test student exists
    test_id = "999999999"
    student = db.query(Student).filter(Student.student_id == test_id).first()
    
    if not student:
        student = Student(
            student_id=test_id,
            name="Test Student (Me)",
            face_encoding=encoding_bytes
        )
        db.add(student)
        print(f"Created new test student {test_id}")
    else:
        student.face_encoding = encoding_bytes
        print(f"Updated encoding for existing test student {test_id}")
    
    db.commit()
    db.close()
    print("Successfully seeded test student encoding.")

if __name__ == "__main__":
    seed_self()
