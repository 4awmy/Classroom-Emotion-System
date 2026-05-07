import cv2
import numpy as np
import face_recognition
from ultralytics import YOLO
import os

def diagnose():
    img_path = 'data/snapshots/TEST_PHASE3/999999999.jpg'
    if not os.path.exists(img_path):
        print(f"Error: {img_path} not found")
        return

    img = cv2.imread(img_path)
    model = YOLO('python-api/yolov8n.pt')
    
    # YOLO Detection
    res = model(img, classes=[0], verbose=False)
    boxes = res[0].boxes.xyxy.cpu().numpy().astype(int)
    print(f"YOLO found {len(boxes)} persons.")

    for i, box in enumerate(boxes):
        x1, y1, x2, y2 = box
        roi = img[y1:y2, x1:x2]
        print(f"ROI {i} shape: {roi.shape}")
        
        rgb_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)
        encs = face_recognition.face_encodings(rgb_roi)
        print(f"ROI {i} face encodings: {len(encs)}")
        
        if len(encs) == 0:
            # Try a slightly larger ROI or the whole frame
            print(f"ROI {i} failed. Trying full frame...")
            full_encs = face_recognition.face_encodings(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
            print(f"Full frame face encodings: {len(full_encs)}")

if __name__ == "__main__":
    diagnose()
