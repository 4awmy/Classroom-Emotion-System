import requests
import os
import time

API_URL = os.getenv("API_URL", "http://backend:8000")

def process_video():
    print(f"Vision Node Started. Connecting to Backend at {API_URL}")
    # Skeleton logic - will be updated with DeepFace in Day 3-4
    while True:
        try:
            # Placeholder for emotion detection
            # Day 1-2 Focus: Network connectivity
            response = requests.get(f"{API_URL}/health")
            if response.status_code == 200:
                print("Connected to Backend successfully.")
            
            # Mock pushing data
            # requests.post(f"{API_URL}/api/emotion", json={"student_id": "S01", "emotion": "Happy", "confidence": 0.85})
            
            time.sleep(5)
        except Exception as e:
            print(f"Waiting for Backend... ({e})")
            time.sleep(5)

if __name__ == "__main__":
    process_video()
