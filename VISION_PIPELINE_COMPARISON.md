# VISION_PIPELINE_COMPARISON.md — Architecture Review Document

> **Audience:** S1 (Vision AI), S3 (FastAPI Backend), and any reviewing engineers.
> **Purpose:** Side-by-side evaluation of the current (v1) vision pipeline architecture vs. a proposed two-stage, two-model design. This document does **not** override CLAUDE.md or ARCHITECTURE.md — it is for deliberation only. Any adopted changes must be formally reflected in CLAUDE.md first.
> **Decision required by:** All 4 team members before implementation begins on `vision_pipeline.py`.

---

## Table of Contents

1. [Summary of the Dispute](#1-summary-of-the-dispute)
2. [Approach A — Current Architecture (v1, as written in ARCHITECTURE.md)](#2-approach-a--current-architecture-v1-as-written-in-architecturemd)
3. [Approach B — Proposed Two-Stage Pipeline](#3-approach-b--proposed-two-stage-pipeline)
4. [Head-to-Head Comparison](#4-head-to-head-comparison)
5. [Model Options for the Face Detection Stage](#5-model-options-for-the-face-detection-stage)
6. [Behavioural Signal Extension (Optional — Phase 2)](#6-behavioural-signal-extension-optional--phase-2)
7. [Code Delta — What Changes in `vision_pipeline.py`](#7-code-delta--what-changes-in-vision_pipelinepy)
8. [Open Questions for the Team](#8-open-questions-for-the-team)
9. [Decision Log](#9-decision-log)

---

## 1. Summary of the Dispute

The current ARCHITECTURE.md specifies a **single sequential pipeline** where a YOLOv8 person-detection bounding box is passed directly as the Region of Interest (ROI) into both the face identity matcher (`face_recognition`) and the emotion classifier (`HSEmotion`).

The concern raised is:

> *"A person bounding box (full body) is a poor input for emotion models. The face is a small, low-resolution fraction of the ROI. Should YOLO be used again for tighter face detection before emotion classification?"*

This document captures both approaches so the engineering team can make an informed, traceable decision.

---

## 2. Approach A — Current Architecture (v1, as written in ARCHITECTURE.md)

### 2.1 Pipeline Diagram

```
Camera frame (every 5s)
        │
        ▼
┌───────────────────────────────────────────┐
│  STEP 1 — YOLOv8 Person Detection        │
│  model: yolov8n.pt (COCO class 0)        │
│  input: full 1920×1080 crowd frame       │
│  output: list of [x1, y1, x2, y2] boxes  │
└───────────────────┬───────────────────────┘
                    │  For each box:
                    ▼
┌───────────────────────────────────────────┐
│  STEP 2 — Face Crop + Identity Match      │
│  roi = frame[y1:y2, x1:x2]               │
│       = full PERSON region (head+body)    │
│  face_recognition.face_encodings(roi)     │
│  compare → student_id or "unknown"        │
└───────────────────┬───────────────────────┘
                    │  Student identified:
                    ▼
┌───────────────────────────────────────────┐
│  STEP 3 — HSEmotion Classification        │
│  input: SAME roi as Step 2                │
│         (full person crop, not face crop) │
│  hs_recognizer.predict_emotions(roi)      │
│  output: raw_label + softmax scores       │
└───────────────────┬───────────────────────┘
                    │
                    ▼
              map_emotion() → emotion
              get_confidence() → score
              INSERT emotion_log + attendance_log
```

### 2.2 Source Code (from CLAUDE.md §7.4 — exact specification)

```python
yolo_model    = YOLO("yolov8n.pt")
hs_recognizer = HSEmotionRecognizer(model_name="enet_b0_8_best_afew")

# ... inside run_pipeline() loop:

results = yolo_model(frame, classes=[0], verbose=False)
boxes   = results[0].boxes.xyxy.cpu().numpy().astype(int)

for box in boxes:
    x1, y1, x2, y2 = box[:4]
    roi = frame[y1:y2, x1:x2]          # ← full person ROI
    if roi.size == 0:
        continue
    rgb_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)

    encs = face_recognition.face_encodings(rgb_roi)
    if not encs:
        continue
    student_id = identify_face(encs[0], known)
    if student_id == "unknown":
        continue

    # ↓ Same roi used for emotion — full body crop
    raw_label, scores = hs_recognizer.predict_emotions(roi, logits=False)
    raw_score  = float(max(scores))
    emotion    = map_emotion(raw_label, raw_score)
    confidence = get_confidence(emotion)

    db.add(EmotionLog(...))
```

### 2.3 Strengths

- ✅ Simple — one model load, one inference pass per person box
- ✅ Fewer dependencies — no second YOLO weight file
- ✅ Lower GPU/CPU overhead — one YOLO call per 5-second cycle
- ✅ Already fully specified in CLAUDE.md and ARCHITECTURE.md — no doc changes needed
- ✅ `face_recognition` internally runs its own HOG/CNN face detector anyway — handles partial faces within the person ROI adequately for identity matching

### 2.4 Weaknesses

- ❌ HSEmotion receives a **full person bounding box** as input, not a face crop
  - HSEmotion (`enet_b0_8_best_afew`) is trained on **face images from AffectNet**, not full-body images
  - Passing a 200×400 px torso+head image forces the model to infer on a domain it was not trained for
  - The face occupies roughly 10–20% of the person ROI in a crowd camera shot → significant background noise
- ❌ Emotion accuracy is degraded in classroom density — students seated close together mean the top of one student's head may be cropped into a neighbouring student's bounding box
- ❌ No documented awareness of this mismatch in the current spec

---

## 3. Approach B — Proposed Two-Stage Pipeline

### 3.1 Core Idea

Split the pipeline into **two explicitly separate tasks** with **two separate YOLO models**:

| Task | Purpose | YOLO model | ROI passed to classifier |
|------|---------|------------|--------------------------|
| **Attendance / Identity** | Who is present? | `yolov8n.pt` (COCO person) | Full person crop → `face_recognition` |
| **Emotion / Behaviour** | What state are they in? | `yolov8n-face.pt` (face-tuned) | Tight face crop → `HSEmotion` |

### 3.2 Pipeline Diagram

```
Camera frame (every 5s)
        │
        ▼
┌────────────────────────────────────────────────────┐
│  STAGE 1 — YOLOv8 Person Detection                │
│  model: yolov8n.pt (unchanged from current arch)  │
│  output: person_boxes = [[x1,y1,x2,y2], ...]      │
└─────────────────────────┬──────────────────────────┘
                          │  For each person box:
              ┌───────────┴────────────┐
              │                        │
              ▼                        ▼
  ┌───────────────────────┐  ┌──────────────────────────────┐
  │  TASK A — Attendance  │  │  TASK B — Emotion            │
  │                       │  │                              │
  │  person_roi = frame   │  │  STAGE 2 — YOLO-face         │
  │    [y1:y2, x1:x2]     │  │  model: yolov8n-face.pt      │
  │  face_recognition     │  │  input: person_roi           │
  │    .face_encodings()  │  │  output: face_box [fx1..fy2] │
  │  identify_face()      │  │                              │
  │  → student_id         │  │  face_roi = person_roi       │
  │                       │  │    [fy1:fy2, fx1:fx2]        │
  │  INSERT attendance_log│  │  ← tight face crop only      │
  │  (first detection)    │  │                              │
  └───────────────────────┘  │  HSEmotion                   │
                             │    .predict_emotions(         │
              student_id ───▶│       face_roi)              │
                             │  → raw_label + scores        │
                             │                              │
                             │  map_emotion()               │
                             │  INSERT emotion_log          │
                             └──────────────────────────────┘
```

### 3.3 Proposed Code Delta

```python
# Model initialisation — load both at startup
yolo_person   = YOLO("yolov8n.pt")           # unchanged
yolo_face     = YOLO("yolov8n-face.pt")       # NEW — face-tuned weights
hs_recognizer = HSEmotionRecognizer(model_name="enet_b0_8_best_afew")

# ... inside run_pipeline() loop:

results      = yolo_person(frame, classes=[0], verbose=False)
person_boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)

for box in person_boxes:
    x1, y1, x2, y2 = box[:4]
    person_roi = frame[y1:y2, x1:x2]
    if person_roi.size == 0:
        continue

    # ── TASK A: Identity / Attendance ──────────────────────────
    rgb_roi = cv2.cvtColor(person_roi, cv2.COLOR_BGR2RGB)
    encs = face_recognition.face_encodings(rgb_roi)
    if not encs:
        continue
    student_id = identify_face(encs[0], known)
    if student_id == "unknown":
        continue

    if student_id not in seen_today:
        seen_today.add(student_id)
        db.add(AttendanceLog(student_id=student_id, lecture_id=lecture_id,
                             status="Present", method="AI"))

    # ── TASK B: Emotion — tight face crop ──────────────────────
    face_results = yolo_face(person_roi, verbose=False)
    face_boxes   = face_results[0].boxes.xyxy.cpu().numpy().astype(int) \
                   if face_results[0].boxes else []

    if len(face_boxes) == 0:
        continue  # no face detected within person ROI — skip emotion

    # Take the highest-confidence face detection (index 0)
    fx1, fy1, fx2, fy2 = face_boxes[0][:4]
    face_roi = person_roi[fy1:fy2, fx1:fx2]
    if face_roi.size == 0:
        continue

    try:
        raw_label, scores = hs_recognizer.predict_emotions(face_roi, logits=False)
        raw_score  = float(max(scores))
        emotion    = map_emotion(raw_label, raw_score)
        confidence = get_confidence(emotion)
    except Exception:
        continue

    db.add(EmotionLog(
        student_id=student_id, lecture_id=lecture_id,
        timestamp=datetime.utcnow(), emotion=emotion,
        confidence=confidence, engagement_score=confidence
    ))

db.commit()
time.sleep(FRAME_INTERVAL)
```

### 3.4 Strengths

- ✅ HSEmotion receives input that matches its training domain (AffectNet = face images)
- ✅ Attendance and emotion are decoupled — each task fails independently without blocking the other
- ✅ Tighter face crop → better classification accuracy, especially in dense classroom seating
- ✅ Uses the same `ultralytics` library already in `requirements.txt` — one additional `.pt` download only
- ✅ `yolov8n-face.pt` is ~6 MB — negligible storage cost

### 3.5 Weaknesses

- ❌ Two YOLO inference calls per person per 5-second cycle → higher compute load
  - Mitigated by running `yolo_face` on the small `person_roi` (cropped), not the full frame
- ❌ Adds a second YOLO weight to version-control/deployment — must be downloaded at startup
- ❌ ARCHITECTURE.md and CLAUDE.md must be updated if adopted — coordination cost for all 4 members
- ❌ If `yolo_face` finds no face in a person ROI (e.g., student looking down), emotion data is silently skipped. Under Approach A, HSEmotion would at least attempt inference on whatever is in the person crop
- ❌ Additional failure mode: yolo_face inference throws → needs its own try/except guard

---

## 4. Head-to-Head Comparison

| Criterion | Approach A (Current) | Approach B (Proposed) |
|-----------|---------------------|----------------------|
| **Emotion input domain match** | ❌ Full person crop (body noise) | ✅ Tight face crop (matches training data) |
| **Attendance accuracy** | ✅ Same — `face_recognition` handles the HOG detection internally | ✅ Same — unchanged |
| **Inference cost per cycle** | ✅ 1× YOLO + 1× face_recognition + 1× HSEmotion | ⚠️ 2× YOLO + 1× face_recognition + 1× HSEmotion |
| **Number of models loaded** | 2 (`yolov8n`, `hs_recognizer`) | 3 (`yolov8n`, `yolov8n-face`, `hs_recognizer`) |
| **Dependency footprint** | Same | +6 MB weight file download |
| **Code complexity** | Low — one linear flow | Medium — forked task logic |
| **Spec changes required** | None | CLAUDE.md §7, ARCHITECTURE.md §8.2 |
| **Failure isolation** | Attendance and emotion fail together | Attendance and emotion fail independently |
| **Handles occluded face** | Attempts inference on body crop | Skips — no face detected by YOLO-face |
| **Expected emotion accuracy** | Baseline — degraded by body noise | Improved — model sees only face pixels |
| **Railway.app RAM impact** | Lower | ~50–100 MB more (second YOLO model in memory) |

---

## 5. Model Options for the Face Detection Stage

If Approach B is adopted, the team must choose the face detector. Options ranked by fit:

### Option 1 — `yolov8n-face.pt` ✅ Recommended
- Source: [github.com/akanametov/yolo-face](https://github.com/akanametov/yolo-face)
- Same `ultralytics` API — `YOLO("yolov8n-face.pt")` — zero new library installs
- Size: ~6 MB
- Speed: ~3–5 ms per person crop on CPU, <1 ms on GPU
- Limitations: Not in the official ultralytics model zoo — must be downloaded manually or via URL

```python
# Download at startup if not present:
import urllib.request, os
if not os.path.exists("yolov8n-face.pt"):
    urllib.request.urlretrieve(
        "https://github.com/akanametov/yolo-face/releases/download/v0.0.0/yolov8n-face.pt",
        "yolov8n-face.pt"
    )
```

### Option 2 — `RetinaFace` ⚠️ Accurate, heavier
- Library: `retina-face` (pip)
- Significantly more accurate on small, rotated, or partially occluded faces
- ~60 MB model, ~20–50 ms per inference — too slow for 5s cycle on Railway free tier
- Overkill unless classroom camera is far from students (>10 m)

### Option 3 — `MTCNN` ⚠️ Acceptable, older
- Library: `mtcnn` (pip)
- Multi-scale face detection — good for groups
- ~15 ms per image, ~30 MB — acceptable but slower than yolov8-face
- Returns bounding boxes + 5 facial landmarks (eyes, nose, mouth) — bonus for future gaze tracking

### Option 4 — `face_recognition` internal detector 🔄 Redundant
- `face_recognition.face_locations()` runs HOG or CNN internally before encoding
- This is already called in Task A (Attendance) — the detected face location could be reused for Task B crop
- Avoids a second model entirely but couples Task A and Task B back together
- **Simplest migration path from Approach A**

---

## 6. Behavioural Signal Extension (Optional — Phase 2)

Beyond the emotion classification question, the following richer behavioural signals could be added in a later phase. Listed here for completeness — **none of these are in scope for v1**.

| Signal | What it detects | Tool | In current arch? |
|--------|----------------|------|-----------------|
| Head pose / gaze direction | Looking at board vs. phone | MediaPipe FaceMesh | ✅ Yes — `proctor_service.py` only |
| Temporal emotion trend | Sustained confusion over N cycles | Rolling window on `emotion_log` | ✅ Yes — Gemini trigger at 40% |
| Body posture / slouching | Student leaning back or slumped | YOLOv8-pose | ❌ Not in scope |
| Eye closure / drowsiness | Eye Aspect Ratio (EAR) | dlib `shape_predictor` | ❌ Not in scope |
| Head nodding | Agreement / attention signal | Optical flow on face ROI | ❌ Not in scope |

---

## 7. Code Delta — What Changes in `vision_pipeline.py`

If Approach B is adopted, the changes to `vision_pipeline.py` are contained to:

1. **Model initialisation block** — add `yolo_face = YOLO("yolov8n-face.pt")`
2. **Inside the person loop** — split the single `roi` usage into `person_roi` (attendance) and `face_roi` (emotion)
3. **Attendance write** — move `seen_today` / `AttendanceLog` insert to immediately after identity match (it currently happens later in the loop — same logic, earlier placement)
4. **Emotion inference** — replace `hs_recognizer.predict_emotions(roi, ...)` with `hs_recognizer.predict_emotions(face_roi, ...)`

No changes to:
- `models.py` — same ORM schema
- `database.py` — unchanged
- All routers — unchanged
- `emotion_log` / `attendance_log` schemas — unchanged (LOCKED, Week 1)
- R/Shiny — unchanged
- React Native — unchanged

---

## 8. Open Questions for the Team

These questions need answers before a decision can be made:

1. **Compute budget on Railway.app free tier:**
   > Does the second YOLO inference call (on a small crop, not the full frame) push the 5-second cycle wall time above 5 seconds for a 30-student classroom? S1 should benchmark locally.

2. **`face_recognition` internal face locations — can they be reused?**
   > `face_recognition.face_locations(rgb_roi)` returns bounding boxes of detected faces. These are already computed internally before `face_encodings()` is called. Could Task B simply reuse those coordinates instead of running a second YOLO model?
   > If yes, this eliminates the need for `yolov8n-face.pt` entirely and keeps the code simple (Option 4 above).

3. **Weight hosting on Railway.app:**
   > `yolov8n-face.pt` must be present at container startup. Options: (a) commit to repo, (b) download at startup via `urllib`, (c) mount as Railway volume. Which does S3 prefer?

4. **HSEmotion actual sensitivity to input crop size:**
   > Has S1 empirically tested HSEmotion accuracy on a full person crop vs. a tight face crop on AAST classroom images? The theoretical argument favours Approach B, but the practical gap should be measured before committing to a larger codebase change.

5. **Attendance snapshot (Flow E, ARCHITECTURE.md §12):**
   > The current spec saves the person `roi` as a JPEG snapshot for Lecturer review. Under Approach B, should the snapshot be the person crop or the tight face crop? Face crop is more useful for verification; person crop shows more context.

---

## 9. Decision Log

> Fill this table out during the team review session. One row per decision made.

| Date | Decision | Rationale | Agreed by |
|------|----------|-----------|-----------|
| 2026-05-07 | **Adopt Approach B** — `yolov8n.pt` for person detection + `yolov8n-face.pt` for tight face crop before HSEmotion | HSEmotion was trained on AffectNet face-only images; passing a full-body person ROI is an out-of-domain input that degrades accuracy. yolo_face download handled at startup via `urllib` (auto-download if absent). Attendance snapshot uses person ROI for context; emotion uses tight face ROI. | S1 (Vision AI) |

---

*End of VISION_PIPELINE_COMPARISON.md*
*This document is advisory only. Adopted decisions must be reflected in CLAUDE.md before any code is written.*
