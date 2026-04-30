import cv2
import os
import numpy as np

def test_person_detection(image_path: str = None):
    print("--- Testing Vision Pipeline Stub ---")
    
    if image_path and os.path.exists(image_path):
        print(f"Loading image from {image_path}...")
        frame = cv2.imread(image_path)
    else:
        print("No image provided or found. Creating a sample black image for simulation...")
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        cv2.putText(frame, "Sample Classroom", (50, 240), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)

    # Simulate YOLOv8 detection
    print("Simulating YOLOv8 detection...")
    # Mock boxes: [x1, y1, x2, y2]
    mock_boxes = [
        [50, 50, 150, 150],  # Person 1
        [200, 50, 300, 150], # Person 2
        [350, 50, 450, 150]  # Person 3
    ]
    
    print(f"Detected {len(mock_boxes)} persons.")
    
    # Draw boxes on the frame
    for i, box in enumerate(mock_boxes):
        x1, y1, x2, y2 = box
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(frame, f"Person {i+1}", (x1, y1-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

    # Save output
    output_path = "test_detection_output.jpg"
    cv2.imwrite(output_path, frame)
    print(f"Simulation complete. Output saved to {output_path}")

if __name__ == "__main__":
    test_person_detection()
埋