# Data Schema — LOCKED CONTRACT

All four CSV files are the contract between all four team members. Any change requires team agreement.

### `emotions.csv`
```csv
Student_ID, Time, Emotion, Confidence, Lecture_ID
S01,        10:05, Happy,  0.85,       L1
```
- **Emotion** values: exactly `Happy`, `Neutral`, `Confused`, `Bored` (case-sensitive)
- **Confidence**: float 0.0–1.0 (DeepFace output)
- **Time**: HH:MM format
- **Lecture_ID**: format `L{n}` e.g. L1, L2

### `attendance.csv`
```csv
Student_ID, Lecture_ID, Date,       Status,  Method
S01,        L1,         2024-10-01, Present, AI
```
- **Status**: `Present` or `Absent`
- **Method**: `AI`, `Manual`, or `QR`

### `materials.csv`
```csv
Material_ID, Lecture_ID, Lecturer_ID, Title,         Drive_Link,          Uploaded_At
M01,         L1,         T01,         Intro to OOP,  https://drive.../,   2024-10-01T10:00:00
```

### `incidents.csv`
```csv
Student_ID, Exam_ID, Timestamp,           Flag_type,         Severity, Evidence_path
S01,        E1,      2024-10-01T10:05:00, gaze_away,         2,        /evidence/S01_001.jpg
```
- **Flag_type** values: `absent`, `multiple_persons`, `gaze_away`, `phone_detected`, `identity_mismatch`, `tab_switch`
- **Severity**: integer 1 (low), 2 (medium), 3 (high)
