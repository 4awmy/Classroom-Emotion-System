import cv2
import requests
import os
import time
import signal
import numpy as np
from dotenv import load_dotenv
import threading

# We might need these for the heavy lifting
# If running standalone, ensure these are installed: 
# pip install opencv-python requests numpy ultralytics face_recognition hse-emotion
try:
    from ultralytics import YOLO
    import face_recognition
    from hsemotion.face_emotions import HSEmotionRecognizer as HSEmotionRecognize
except ImportError:
    print("[ERROR] Missing dependencies. Run: pip install ultralytics face_recognition hsemotion-onnx opencv-python requests")

# Load environment variables
load_dotenv()

API_URL = os.getenv("API_URL", "http://localhost:8000")
VIDEO_SOURCE = os.getenv("VIDEO_SOURCE", "0")
LECTURE_ID = os.getenv("LECTURE_ID", "TEST_L") # In production, set this via CLI or env

# Convert VIDEO_SOURCE to int if it's a digit (for webcam index)
if isinstance(VIDEO_SOURCE, str) and VIDEO_SOURCE.isdigit():
    VIDEO_SOURCE = int(VIDEO_SOURCE)

# Path to models (assumes running from project root)
YOLO_PERSON_PATH = "yolov8n.pt"
YOLO_FACE_PATH = "yolov8n-face.pt"

class VisionNode:
    def __init__(self):
        self.running = True
        self.backend_healthy = False
        self.known_encodings = {} # {student_id: encoding}
        self.seen_today = set()
        
        # Load Models
        print("[INIT] Loading AI Models...")
        self.yolo_model = YOLO(YOLO_PERSON_PATH)
        self.face_model = YOLO(YOLO_FACE_PATH)
        self.fer_model = HSEmotionRecognize(model_name='enet_b0_8_best_vga', device='cpu')
        print("[INIT] Models loaded.")

    def sync_roster(self):
        """Fetch known face encodings from the cloud backend."""
        print(f"[SYNC] Fetching roster from {API_URL}...")
        try:
            # We use an internal/roster endpoint if available, or list students
            # For now, let's assume we can get student data
            response = requests.get(f"{API_URL}/roster/students", timeout=5)
            if response.status_code == 200:
                students = response.json()
                for s in students:
                    sid = s['student_id']
                    # We might need another call to get the actual BLOB encoding if not in list
                    # But for v1, let's just log the sync
                    print(f"  - Synced {s['name']} ({sid})")
                self.backend_healthy = True
            else:
                print(f"[SYNC] Failed to fetch roster: {response.status_code}")
        except Exception as e:
            print(f"[SYNC] Error connecting to backend: {e}")

    def map_emotion(self, label, score):
        """Maps HSEmotion labels to our internal state."""
        mapping = {
            "neutral": "Focused",
            "happiness": "Engaged",
            "surprise": "Engaged",
            "fear": "Anxious",
            "anger": "Frustrated",
            "disgust": "Frustrated",
            "sadness": "Disengaged"
        }
        # If anger/disgust but low score, maybe just confused
        if label in ["anger", "disgust"] and score < 0.65:
            return "Confused"
        return mapping.get(label, "Focused")

    def get_confidence(self, emotion):
        """Fixed confidence scores per architecture spec."""
        scores = {
            "Focused": 1.0,
            "Engaged": 0.85,
            "Confused": 0.55,
            "Anxious": 0.35,
            "Frustrated": 0.25,
            "Disengaged": 0.0
        }
        return scores.get(emotion, 0.5)

    def process_frame(self, frame):
        """Detect persons, identify them, and detect emotions."""
        # 1. Detect Persons
        results = self.yolo_model(frame, classes=[0], verbose=False)
        boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)
        
        for box in boxes:
            x1, y1, x2, y2 = box
            person_roi = frame[y1:y2, x1:x2]
            if person_roi.size == 0: continue
            
            # 2. Identify Student (Face Recognition)
            # In a real classroom, we'd compare encodings. 
            # For this prototype, we'll mock detection of a test student if a face is seen.
            rgb_roi = cv2.cvtColor(person_roi, cv2.COLOR_BGR2RGB)
            encs = face_recognition.face_encodings(rgb_roi)
            
            if encs:
                # Mock: Always detect '231006131' for demo if any face found
                student_id = "231006131" 
                
                # 3. Detect Emotion
                # Get tight face crop
                face_results = self.face_model(person_roi, verbose=False)
                if len(face_results[0].boxes) > 0:
                    fx1, fy1, fx2, fy2 = face_results[0].boxes.xyxy[0].cpu().numpy().astype(int)
                    face_roi = person_roi[fy1:fy2, fx1:fx2]
                else:
                    face_roi = person_roi # Fallback
                
                res = self.fer_model.predict_emotions(face_roi, logits=False)
                label = max(res, key=lambda x: res[x])
                score = float(res[label])
                
                emotion = self.map_emotion(label, score)
                confidence = self.get_confidence(emotion)
                
                # 4. Push to Cloud
                self.push_data(student_id, emotion, confidence)

    def push_data(self, student_id, emotion, confidence):
        """Send logs to the DigitalOcean backend."""
        # Attendance (if first time)
        if student_id not in self.seen_today:
            try:
                requests.post(f"{API_URL}/attendance/log", json={
                    "student_id": student_id,
                    "lecture_id": LECTURE_ID,
                    "status": "Present",
                    "method": "AI"
                }, timeout=2)
                self.seen_today.add(student_id)
                print(f"[CLOUD] Attendance marked for {student_id}")
            except: pass
            
        # Emotion
        try:
            requests.post(f"{API_URL}/emotion/log", json={
                "student_id": student_id,
                "lecture_id": LECTURE_ID,
                "emotion": emotion,
                "confidence": confidence,
                "engagement_score": confidence
            }, timeout=2)
            print(f"[CLOUD] Emotion pushed: {student_id} -> {emotion}")
        except Exception as e:
            print(f"[CLOUD] Failed to push emotion: {e}")

    def run(self):
        print(f"[START] Vision Node Active. Source: {VIDEO_SOURCE}")
        self.sync_roster()
        
        cap = cv2.VideoCapture(VIDEO_SOURCE)
        frame_count = 0
        
        try:
            while self.running:
                ret, frame = cap.read()
                if not ret:
                    print("[WARN] Camera disconnected. Retrying...")
                    time.sleep(5)
                    cap = cv2.VideoCapture(VIDEO_SOURCE)
                    continue

                frame_count += 1
                
                # Process every 90 frames (~3 seconds at 30fps)
                if frame_count % 90 == 0:
                    threading.Thread(target=self.process_frame, args=(frame.copy(),)).start()
                
                # Heartbeat to console
                if frame_count % 300 == 0:
                    print(f"[STATUS] Active. Frames: {frame_count}")

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
                    
        except KeyboardInterrupt:
            self.running = False
        finally:
            cap.release()
            print("[STOP] Vision Node shut down.")

if __name__ == "__main__":
    node = VisionNode()
    node.run()
