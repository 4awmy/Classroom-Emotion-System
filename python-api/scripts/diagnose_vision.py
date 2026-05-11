import cv2
import numpy as np
from ultralytics import YOLO
import os
from services.face_embeddings import arcface_embedding

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
        
        emb = arcface_embedding(roi)
        print(f"ROI {i} ArcFace embedding: {emb is not None}")
        
        if emb is None:
            print(f"ROI {i} failed. Trying full frame...")
            full_emb = arcface_embedding(img)
            print(f"Full frame ArcFace embedding: {full_emb is not None}")

if __name__ == "__main__":
    diagnose()
