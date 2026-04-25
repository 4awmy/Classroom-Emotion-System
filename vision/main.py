import requests
import os
import time
import signal
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

API_URL = os.getenv("API_URL", "http://backend:8000")
VIDEO_SOURCE = os.getenv("VIDEO_SOURCE", "0")

# Convert VIDEO_SOURCE to int if it's a digit (for webcam index)
if VIDEO_SOURCE.isdigit():
    VIDEO_SOURCE = int(VIDEO_SOURCE)

class VisionNode:
    def __init__(self):
        self.running = True
        self.last_health_check = 0
        self.backend_healthy = False
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self.handle_exit)
        signal.signal(signal.SIGTERM, self.handle_exit)

    def handle_exit(self, signum, frame):
        print("\nShutdown signal received. Closing...")
        self.running = False

    def check_backend(self):
        """Periodic health check of the backend."""
        current_time = time.time()
        if current_time - self.last_health_check > 5:
            try:
                response = requests.get(f"{API_URL}/health", timeout=2)
                if response.status_code == 200:
                    if not self.backend_healthy:
                        print(f"Connected to Backend successfully at {API_URL}")
                    self.backend_healthy = True
                else:
                    self.backend_healthy = False
            except requests.exceptions.RequestException:
                if self.backend_healthy:
                    print("Lost connection to Backend.")
                self.backend_healthy = False
            self.last_health_check = current_time

    def run(self):
        print(f"Vision Node Started. Video Source: {VIDEO_SOURCE}")
        
        cap = cv2.VideoCapture(VIDEO_SOURCE)
        
        if not cap.isOpened():
            print(f"Error: Could not open video source {VIDEO_SOURCE}")
            return

        frame_count = 0
        
        try:
            while self.running and cap.isOpened():
                ret, frame = cap.read()
                
                if not ret:
                    print("Warning: Failed to capture frame or end of video.")
                    break

                frame_count += 1
                
                # Periodic logs and health checks
                self.check_backend()
                
                if frame_count % 30 == 0:
                    print(f"Status: Captured {frame_count} frames. Backend Online: {self.backend_healthy}")
                    
        except KeyboardInterrupt:
            self.running = False
        finally:
            cap.release()
            print("Vision Node resources released.")

if __name__ == "__main__":
    node = VisionNode()
    node.run()
