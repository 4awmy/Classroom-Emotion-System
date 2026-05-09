import threading
from services.vision_pipeline import run_pipeline
import time

stop_event = threading.Event()
lecture_id = "test-123"
camera_url = "0"

print("Starting pipeline...")
pipeline_thread = threading.Thread(target=run_pipeline, args=(lecture_id, camera_url, stop_event))
pipeline_thread.start()

time.sleep(5)
print("Stopping pipeline...")
stop_event.set()
pipeline_thread.join()
print("Pipeline stopped.")
