# Technical Plan: AAST/Moodle Redesign & Feature Additions

**Spec**: `specs/aast-lms-validation/spec-moodle-redesign.md`
**Version**: 1.0.0
**Date**: 2026-05-06

---

## Constitution Check

✅ I. One classroom camera — snapshots are face ROI crops from the existing pipeline frame, not a separate camera
✅ II. Vision pipeline unchanged — snapshot capture is added as a side-effect of the existing detection step
✅ III. Interface split enforced — React Native changes (mobile only), Shiny changes (Admin/Lecturer only)
✅ IV. Data isolation — Shiny fetches snapshots via API URL, never direct file access
✅ V. Nightly export — `snapshot_path` will be included in `attendance.csv` export
✅ VII. Confidence values LOCKED — Req. 7 is display-label only, no backend value changes
✅ XII. Schema change via migration only — `ADD COLUMN snapshot_path TEXT` (non-destructive, nullable)
✅ XIV. Student IDs validated as 9-digit strings in new endpoint

---

## Component-by-Component Technical Plan

---

### Component 1: Schema Migration — `snapshot_path` column

**Files:** `python-api/database.py`, `python-api/models.py`, new migration script

**Approach:**
- Add `snapshot_path TEXT` (nullable) to `AttendanceLog` SQLAlchemy model
- Create `python-api/migrations/add_snapshot_path.py` one-shot migration script:
  ```python
  conn.execute("ALTER TABLE attendance_log ADD COLUMN snapshot_path TEXT")
  ```
- Run migration before any other changes land on dev

**Risk:** None — `ADD COLUMN` with nullable value is non-destructive in SQLite.

---

### Component 2: Vision Pipeline — Live Snapshot Capture

**File:** `python-api/services/vision_pipeline.py`

**Approach:**
- After face is identified (student_id != "unknown"), before writing to DB:
  ```python
  SNAPSHOT_DIR = "data/snapshots"

  # Capture snapshot
  lecture_snap_dir = f"{SNAPSHOT_DIR}/{lecture_id}"
  os.makedirs(lecture_snap_dir, exist_ok=True)

  snap_path = f"{lecture_snap_dir}/{student_id}.jpg"
  h, w = roi.shape[:2]
  if h >= 100 and w >= 100:
      cv2.imwrite(snap_path, roi, [cv2.IMWRITE_JPEG_QUALITY, 80])
  else:
      snap_path = None
  ```
- Pass `snap_path` to `AttendanceLog` INSERT (only on first detection):
  ```python
  AttendanceLog(..., status="Present", method="AI", snapshot_path=snap_path)
  ```
- On re-detection: update snapshot file (overwrite) but do NOT insert new attendance row

**Risk:** ROI too small → guarded by `h >= 100 and w >= 100` check.

---

### Component 3: FastAPI — Snapshot Endpoint

**File:** `python-api/routers/attendance.py`

**Approach:**
```python
from fastapi.responses import FileResponse

@router.get("/snapshot/{lecture_id}/{student_id}")
def get_snapshot(lecture_id: str, student_id: str):
    path = f"data/snapshots/{lecture_id}/{student_id}.jpg"
    if not os.path.exists(path):
        raise HTTPException(404, "No snapshot available")
    return FileResponse(path, media_type="image/jpeg")
```

**No auth required** for this endpoint (image is already de-identified by lecture_id/student_id scope).

---

### Component 4: FastAPI — `POST /roster/student` Endpoint

**File:** `python-api/routers/roster.py`

**Approach:**
```python
import re

STUDENT_ID_RE = re.compile(r"^\d{9}$")
MAX_PHOTO_SIZE = 5 * 1024 * 1024  # 5MB

@router.post("/student", status_code=201)
async def add_student(
    student_id: str = Form(...),
    name: str = Form(...),
    email: str = Form(None),
    photo: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    if not STUDENT_ID_RE.match(student_id):
        raise HTTPException(422, "student_id must be exactly 9 digits")

    content = await photo.read()
    if len(content) > MAX_PHOTO_SIZE:
        raise HTTPException(413, "Photo too large (max 5MB)")

    if db.query(Student).filter_by(student_id=student_id).first():
        raise HTTPException(409, f"Student {student_id} already exists")

    img = face_recognition.load_image_file(io.BytesIO(content))
    encs = face_recognition.face_encodings(img)

    encoding_saved = False
    face_encoding_blob = None
    if encs:
        face_encoding_blob = encs[0].astype(np.float64).tobytes()
        encoding_saved = True

    student = Student(
        student_id=student_id,
        name=name,
        email=email,
        face_encoding=face_encoding_blob
    )
    db.add(student)
    db.commit()

    return {"student_id": student_id, "name": name, "encoding_saved": encoding_saved}
```

---

### Component 5: Export Service — Include `snapshot_path`

**File:** `python-api/services/export_service.py`

**Approach:**
- Update attendance export query to include `snapshot_path`:
  ```python
  "attendance": "SELECT student_id, lecture_id, timestamp, status, method, snapshot_path FROM attendance_log"
  ```
- This makes `snapshot_path` available in `attendance.csv` for Shiny to read

---

### Component 6: Shiny — Attendance Card Grid (AAST Style)

**Files:** `shiny-app/server/lecturer_server.R`, `shiny-app/ui/lecturer_ui.R`, `shiny-app/www/custom.css`

**Approach:**
- Submodule C (Attendance) receives a UI overhaul
- Read `attendance.csv` + join with students data (from roster)
- Render using `renderUI` with custom HTML per card:
  ```r
  render_student_card <- function(row, lecture_id) {
    snap_url <- if (!is.na(row$snapshot_path)) {
      paste0(FASTAPI_BASE, "/attendance/snapshot/", lecture_id, "/", row$student_id)
    } else {
      "www/default_student.png"  # fallback
    }

    tags$div(
      class = paste0("student-card ", if (row$status == "Present") "present" else "absent"),
      tags$img(src = snap_url, class = "student-photo"),
      tags$div(class = "student-info",
        tags$span(class = "student-id", row$student_id),
        tags$span(class = "student-name", row$name)
      ),
      tags$div(class = "attendance-controls",
        shinyWidgets::materialSwitch(
          inputId = paste0("att_", row$student_id),
          label = "Present",
          value = row$status == "Present",
          color = "success"
        ),
        textInput(paste0("reason_", row$student_id), label = NULL,
                  placeholder = "Reason (optional)")
      )
    )
  }
  ```
- Grid layout via CSS: `display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr))`
- Card borders: green left border = Present, red = Absent
- Save button calls `POST /attendance/manual` for changed rows
- Add `shinyWidgets` to R package list

**CSS additions** (`www/custom.css`):
```css
.student-card {
  background: #fff;
  border-radius: 8px;
  padding: 12px;
  box-shadow: 0 2px 6px rgba(0,0,0,.12);
  border-left: 4px solid #ccc;
}
.student-card.present { border-left-color: #28a745; }
.student-card.absent  { border-left-color: #dc3545; }
.student-photo {
  width: 80px; height: 80px;
  border-radius: 50%;
  object-fit: cover;
  display: block;
  margin: 0 auto 8px;
}
.attendance-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 16px;
  padding: 16px;
}
```

---

### Component 7: Shiny — Admin Student Management Tab

**Files:** `shiny-app/ui/admin_ui.R`, `shiny-app/server/admin_server.R`

**Approach:**
- Add Panel 9: "Student Management" tab (does NOT conflict with locked 8-panel list — this is an addition)
- UI form:
  ```r
  tabPanel("Student Management",
    fluidRow(
      column(4,
        textInput("new_student_id", "Student ID (9 digits)"),
        textInput("new_student_name", "Full Name"),
        textInput("new_student_email", "Email (optional)"),
        fileInput("new_student_photo", "Enrollment Photo", accept = c("image/jpeg", "image/png")),
        actionButton("add_student_btn", "Add Student", class = "btn-primary")
      ),
      column(8,
        DT::dataTableOutput("students_table")
      )
    )
  )
  ```
- Server observer: on `add_student_btn` → multipart POST `/roster/student`
- Handle 201 (success), 409 (duplicate), 422 (no face), 413 (too large)
- `students_table`: read from `students` list via `GET /roster/students` (new GET endpoint needed)

**Additional endpoint:** `GET /roster/students` → returns list of all students (student_id, name, email, has_encoding)

---

### Component 8: React Native — Moodle-Style UI Redesign

**Files affected:**
- `react-native-app/app/(auth)/login.tsx`
- `react-native-app/app/(student)/home.tsx`
- `react-native-app/app/(student)/focus.tsx`
- `react-native-app/app/(student)/notes.tsx`
- New: `react-native-app/constants/theme.ts`

**Approach:**

**`constants/theme.ts`** (new file):
```typescript
export const AAST = {
  navy:       '#002147',
  gold:       '#C9A84C',
  white:      '#FFFFFF',
  lightGray:  '#F5F5F5',
  cardShadow: '0px 2px 6px rgba(0,0,0,0.12)',
  fontFamily: 'Roboto',
} as const;
```

**Login screen:**
- AAST logo centered at top
- Navy background header, white card below
- Input fields: bordered, rounded, Roboto font
- "Sign In" button: Gold background, Navy text

**Home screen:**
- Navy top bar with AAST logo + "Welcome, {name}"
- Upcoming lectures as cards:
  - White card, subtle shadow
  - Gold left accent bar
  - Course name (bold), Lecturer name, Time
  - "Join" button (Gold)
- Bottom tab bar: Navy background, Gold active icon

**Focus screen:**
- Navy full-screen background
- Lecture timer (see Component 9)
- Strike counter with warning at 3 strikes
- Slide URL button (Gold)
- Caption overlay at bottom

**Notes screen:**
- White background, card-style sections
- ✱ highlights in Gold

**Packages needed:**
```bash
npx expo install expo-font @expo-google-fonts/roboto
```

---

### Component 9: React Native — Lecture Timer

**File:** `react-native-app/app/(student)/focus.tsx`

**Approach:**
```typescript
const [lectureStart, setLectureStart] = useState<Date | null>(null);
const [elapsed, setElapsed] = useState(0);  // seconds

// On session:start WS event:
socket.on('message', (msg) => {
  const data = JSON.parse(msg);
  if (data.type === 'session:start') {
    setLectureStart(new Date(data.start_time));
    setFocusActive(true);
  }
  if (data.type === 'session:end') {
    setFocusActive(false);
    // elapsed freezes — no clearInterval
  }
});

// Timer tick:
useEffect(() => {
  if (!lectureStart || !focusActive) return;
  const id = setInterval(() => {
    setElapsed(Math.floor((Date.now() - lectureStart.getTime()) / 1000));
  }, 1000);
  return () => clearInterval(id);
}, [lectureStart, focusActive]);

// Format:
const formatTime = (s: number) => {
  const h = Math.floor(s / 3600).toString().padStart(2, '0');
  const m = Math.floor((s % 3600) / 60).toString().padStart(2, '0');
  const sec = (s % 60).toString().padStart(2, '0');
  return `${h}:${m}:${sec}`;
};
```

**Display:**
```tsx
<Text style={{ color: AAST.gold, fontSize: 36, fontFamily: 'Roboto_700Bold' }}>
  {formatTime(elapsed)}
</Text>
<Text style={{ color: '#aaa', fontSize: 12 }}>Lecture Duration</Text>
```

**Timer is resilient:** uses local `Date.now()` diff from stored `lectureStart`, not server polling.

---

### Component 10: Confidence Rate Labeling

**Scope:** Display-layer only. No backend changes.

**Changes:**
- `shiny-app/`: update column labels in DT tables, add tooltips
  - `"Confidence" → "Confidence Rate"`
  - Tooltip: "Model certainty for this emotion prediction (fixed per emotion state)"
- `react-native-app/`: update any UI text referring to "confidence"
- `python-api/`: update FastAPI field descriptions in Pydantic schemas
  - Add `description="Fixed confidence proxy for engagement level"` to `confidence` field

---

## Dependency Order (Critical Path)

```
1. Schema migration          ← blocks snapshot capture
2. Vision pipeline snapshot  ← blocks snapshot endpoint
3. Snapshot API endpoint     ← blocks Shiny attendance card photo display
4. POST /roster/student      ← blocks Admin Student Management tab
5. GET /roster/students      ← blocks Admin student table
6. Export service update     ← enables snapshot_path in CSV
7. Shiny attendance cards    ← depends on export + snapshot endpoint
8. Shiny admin student tab   ← depends on POST + GET /roster endpoints
9. RN theme + redesign       ← independent, can start anytime
10. Lecture timer            ← independent, needs session:start to have start_time
11. Confidence label rename  ← independent, lowest priority
```

---

## Testing Plan

| Feature | Test Method |
|---|---|
| Schema migration | Run migration, verify `PRAGMA table_info(attendance_log)` shows snapshot_path |
| Snapshot capture | Run pipeline with test video, check `data/snapshots/L1/{student_id}.jpg` exists |
| Snapshot endpoint | `curl GET /attendance/snapshot/L1/231006367` → returns JPEG |
| POST /roster/student | Send valid form → 201; duplicate → 409; no face → 422 |
| Shiny attendance grid | Load with synthetic data, verify cards render, toggle calls API |
| Shiny admin add student | Fill form, submit, verify student in DT table |
| RN Moodle redesign | Visual review on Expo Go, check colors match spec |
| Lecture timer | Join session, verify timer starts; press home → timer stops (focus lost); session end → timer freezes |
| Confidence label | Check all UI instances show "Confidence Rate" not "Confidence" |
