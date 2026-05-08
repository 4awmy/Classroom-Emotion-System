from services.vision_pipeline import YOLO
import cv2
import time
import sys

sys.path.append("python-api")

def test():
    yolo = YOLO('yolov8n.pt')
    cap = cv2.VideoCapture(0)
    print("Camera warming up...")
    time.sleep(2)
    print("Clearing buffer...")
    for _ in range(10):
        cap.read()
    
    ret, frame = cap.read()
    if ret:
        print("Running detection...")
        results = yolo(frame, verbose=False)
        classes = [results[0].names[int(c)] for c in results[0].boxes.cls.cpu().numpy()]
        print(f"Detected classes: {classes}")
        cv2.imwrite("test_capture.jpg", frame)
        print("Saved capture to test_capture.jpg")
    else:
        print("Failed to capture frame")
    
    cap.release()

if __name__ == "__main__":
    test()
