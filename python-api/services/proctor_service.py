import os
import time
import cv2
import math
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from models import Incident
import numpy as np

class ProctorService:
    def __init__(self, db: Session):
        self.db = db
        self.evidence_dir = os.path.join("data", "evidence")
        os.makedirs(self.evidence_dir, exist_ok=True)
        self.last_seen = {}  # {student_id: datetime}

    def log_incident(self, student_id: str, exam_id: str, flag_type: str, severity: int, frame_roi: np.ndarray = None):
        """Logs an incident to the database and saves evidence if provided."""
        evidence_path = None
        if frame_roi is not None and frame_roi.size > 0:
            timestamp = int(time.time())
            filename = f"{exam_id}_{student_id}_{timestamp}.jpg"
            save_path = os.path.join(self.evidence_dir, filename)
            cv2.imwrite(save_path, frame_roi, [cv2.IMWRITE_JPEG_QUALITY, 80])
            # Store relative path as per ARCHITECTURE.md
            evidence_path = f"data/evidence/{filename}"

        incident = Incident(
            student_id=student_id,
            exam_id=exam_id,
            timestamp=datetime.utcnow(),
            flag_type=flag_type,
            severity=severity,
            evidence_path=evidence_path
        )
        self.db.add(incident)
        self.db.commit()
        print(f"[PROCTOR] Incident: {flag_type} for {student_id} (Severity {severity})")

    def check_phone_on_desk(self, student_id: str, exam_id: str, person_roi: np.ndarray, yolo_results):
        """Detects if a cell phone is present in the person's area."""
        # YOLO class 67 is 'cell phone'
        for box in yolo_results[0].boxes:
            if int(box.cls[0]) == 67:
                self.log_incident(student_id, exam_id, "phone_on_desk", 3, person_roi)
                return True
        return False

    def check_multiple_persons(self, student_id: str, exam_id: str, person_roi: np.ndarray, yolo_results):
        """Detects if more than one person is in the person's area."""
        # YOLO class 0 is 'person'
        person_count = 0
        for box in yolo_results[0].boxes:
            if int(box.cls[0]) == 0:
                person_count += 1
        
        if person_count > 1:
            self.log_incident(student_id, exam_id, "multiple_persons", 3, person_roi)
            return True
        return False

    def check_identity_mismatch(self, student_id: str, exam_id: str, person_roi: np.ndarray, distance: float):
        """Logs an incident if the face recognition distance is too high."""
        if distance > 0.5:
            self.log_incident(student_id, exam_id, "identity_mismatch", 3, person_roi)
            return True
        return False

    def check_absent(self, exam_id: str, detected_ids: set):
        """Detects if a previously seen student is now absent (> 5s)."""
        current_time = datetime.utcnow()
        
        # Check for students who were seen but are not in the current frame
        for student_id, last_time in list(self.last_seen.items()):
            if student_id not in detected_ids:
                if (current_time - last_time).total_seconds() > 5:
                    self.log_incident(student_id, exam_id, "absent", 3)
                    # Remove from last_seen to avoid repeated logging until they reappear
                    del self.last_seen[student_id]
        
        # Update last_seen for detected students
        for student_id in detected_ids:
            self.last_seen[student_id] = current_time

    def check_head_rotation(self, student_id: str, exam_id: str, face_roi: np.ndarray):
        """Detects head rotation using MediaPipe FaceMesh and solvePnP."""
        if face_roi is None or face_roi.size == 0:
            return 0, 0, 0, False

        # Lazy load mediapipe
        import mediapipe as mp
        
        if not hasattr(self, '_face_mesh'):
            self._face_mesh = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=False,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5
            )

        h, w, _ = face_roi.shape
        rgb_roi = cv2.cvtColor(face_roi, cv2.COLOR_BGR2RGB)
        results = self._face_mesh.process(rgb_roi)

        if not results.multi_face_landmarks:
            return 0, 0, 0, False

        face_landmarks = results.multi_face_landmarks[0]
        img_points = []
        
        # Landmarks for pose estimation:
        # 1: Nose tip, 199: Chin, 33: L eye L corner, 263: R eye R corner, 61: L mouth, 291: R mouth
        for idx in [1, 199, 33, 263, 61, 291]:
            lm = face_landmarks.landmark[idx]
            img_points.append([lm.x * w, lm.y * h])
            
        img_points = np.array(img_points, dtype="double")

        # 3D model points (generic face model)
        model_points = np.array([
            (0.0, 0.0, 0.0),             # Nose tip
            (0.0, -330.0, -65.0),        # Chin
            (-225.0, 170.0, -135.0),     # Left eye left corner
            (225.0, 170.0, -135.0),      # Right eye right corner
            (-150.0, -150.0, -125.0),    # Left Mouth corner
            (150.0, -150.0, -125.0)      # Right mouth corner
        ])

        # Camera matrix approximation
        focal_length = w
        center = (w / 2, h / 2)
        camera_matrix = np.array(
            [[focal_length, 0, center[0]],
             [0, focal_length, center[1]],
             [0, 0, 1]], dtype="double"
        )

        dist_coeffs = np.zeros((4, 1))
        success, rotation_vector, translation_vector = cv2.solvePnP(
            model_points, img_points, camera_matrix, dist_coeffs, flags=cv2.SOLVEPNP_ITERATIVE
        )

        # Convert to Euler angles
        rmat, _ = cv2.Rodrigues(rotation_vector)
        
        # Decompose rotation matrix
        sy = math.sqrt(rmat[0,0] * rmat[0,0] +  rmat[1,0] * rmat[1,0])
        singular = sy < 1e-6
        if not singular:
            x = math.atan2(rmat[2,1] , rmat[2,2])
            y = math.atan2(-rmat[2,0], sy)
            z = math.atan2(rmat[1,0], rmat[0,0])
        else:
            x = math.atan2(-rmat[1,2], rmat[1,1])
            y = math.atan2(-rmat[2,0], sy)
            z = 0
        
        pitch = math.degrees(x)
        yaw = math.degrees(y)
        roll = math.degrees(z)

        suspicious = False
        # Thresholds: Yaw > 30 (looking left/right), Pitch > 20 (looking up/down)
        if abs(yaw) > 30 or abs(pitch) > 20:
            suspicious = True
            self.log_incident(student_id, exam_id, "head_rotation", 2, face_roi)

        return pitch, yaw, roll, suspicious

    def check_auto_submit(self, exam_id: str, student_id: str):
        """Checks if a student should be auto-submitted due to multiple high-severity incidents."""
        ten_mins_ago = datetime.utcnow() - timedelta(minutes=10)
        count = self.db.query(Incident).filter(
            Incident.exam_id == exam_id,
            Incident.student_id == student_id,
            Incident.severity == 3,
            Incident.timestamp >= ten_mins_ago
        ).count()
        
        return count >= 3
