import cv2
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
if isinstance(VIDEO_SOURCE, str) and VIDEO_SOURCE.isdigit():
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
                # Use a reasonable timeout to prevent blocking the capture loop
                response = requests.get(f"{API_URL}/health", timeout=2)
                if response.status_code == 200:
                    if not self.backend_healthy:
                        print(f"Connected to Backend successfully at {API_URL}")
                    self.backend_healthy = True
                else:
                    self.backend_healthy = False
            except Exception as e:
                # Broad exception to keep the node running even if network is unstable
                if self.backend_healthy:
                    print(f"Lost connection to Backend: {e}")
                self.backend_healthy = False
            self.last_health_check = current_time

    def run(self):
        print(f"Vision Node Started. Video Source: {VIDEO_SOURCE}")
        
        cap = cv2.VideoCapture(VIDEO_SOURCE)
        
        if not cap.isOpened():
            print(f"Error: Could not open video source {VIDEO_SOURCE}")
            # If we are in a headless environment with no webcam, this might fail.
            # For testing, we'll just log and continue the loop mock-style if it's '0'
            if VIDEO_SOURCE == 0 or str(VIDEO_SOURCE) == "0":
                print("No webcam found. Running in mock-capture mode for testing.")
            else:
                return

        frame_count = 0
        
        try:
            while self.running:
                if cap.isOpened():
                    ret, frame = cap.read()
                    if not ret:
                        print("Warning: Failed to capture frame or end of video.")
                        # If it's a file, we might want to loop or stop. For now, stop.
                        break
                else:
                    # Mock capture for environments without cameras
                    time.sleep(0.1)

                frame_count += 1
                
                # Periodic logs and health checks
                self.check_backend()
                
                if frame_count % 30 == 0:
                    print(f"Status: Captured {frame_count} frames. Backend Online: {self.backend_healthy}")

                # Small delay to regulate CPU usage
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
                    
        except KeyboardInterrupt:
            self.running = False
        finally:
            if cap.isOpened():
                cap.release()
            cv2.destroyAllWindows()
            print("Vision Node resources released.")

if __name__ == "__main__":
    node = VisionNode()
    node.run()
