# Implementation Plan — AI Intervention, Mobile Integration & Exam Proctoring

## Decisions Confirmed
- **Exam camera**: Server-side classroom cam (existing `vision_pipeline.py` thread) — no phone camera
- **Fresh Brainer UI**: Bottom sheet modal over `focus.tsx` ✅ (stub already exists, needs MCQ upgrade)
- **Exam start authority**: Lecturer starts exam via Shiny → broadcasts `exam:start` WS event → mobile navigates to `exam.tsx`

---

## Sprint 1 — Exam Proctoring Backend (T065–T067)

---

### Backend — Vision Pipeline

#### [MODIFY] [vision_pipeline.py](file:///c:/Users/omarh/projects/Classroom-Emotion-System/python-api/services/vision_pipeline.py)

Wire all 5 ProctorService checks inside the `run_pipeline()` loop when `context == "exam"`.

**Current state:** `proctor` object is created but never called.
**Change:** Inside the `if frame_count % 5 == 0:` block, when `proctor is not None`:
1. Call `proctor.check_phone_on_desk(sid, exam_id, person_roi, yolo_results)` — uses `yolo_person` results already available
2. Call `proctor.check_multiple_persons(sid, exam_id, person_roi, yolo_results)` — same results
3. Call `proctor.check_identity_mismatch(sid, exam_id, face_roi, distance)` — need to track `best_distance` from ArcFace cosine similarity
4. Call `proctor.check_head_rotation(sid, exam_id, face_roi)` — every 30 frames (same cadence as emotion)
5. Call `proctor.check_absent(exam_id, detected_ids)` — once per frame cycle with `detected_this_frame` set

**Add auto-submit trigger (T066):** After each incident is logged, call `proctor.check_auto_submit(exam_id, sid)` and if `True`, use `manager.broadcast_sync()` to emit `exam:autosubmit`.

**Key detail:** `cosine_sim` returns similarity (0–1), so `distance = 1 - similarity`. The `check_identity_mismatch` threshold is `distance > 0.5` → `similarity < 0.5`. Already correct in proctor service.

---

### Backend — Exam Router

#### [MODIFY] [exam.py](file:///c:/Users/omarh/projects/Classroom-Emotion-System/python-api/routers/exam.py)

Add 3 missing endpoints (T067):

**1. `GET /exam/active/{student_id}`** — Returns the active exam for a student's enrolled class (needed by mobile to check if there's a live exam on home screen).

**2. `GET /exam/list/{class_id}`** — Returns all exams for a class (Shiny already has this implicitly but mobile needs it too).

**3. `POST /exam/start-session`** — Called by Shiny when lecturer starts an exam. Creates the exam record and broadcasts `exam:start` WS event with `exam_id`, `class_id`, `title` so mobile can redirect. This replaces the current broken `examAPI.start()`.

**Fix `POST /exam` request body:** Current body is `ExamCreateRequest(class_id, title, scheduled_start)` but `examAPI.start()` in mobile sends `{class_id, student_id}`. Since exam creation is now **lecturer-only**, we keep the current `POST /exam` body as-is for Shiny, and remove the need for mobile to call it.

---

## Sprint 2 — Mobile App Integration Fixes

---

### Mobile — `api.ts`

#### [MODIFY] [api.ts](file:///c:/Users/omarh/projects/Classroom-Emotion-System/react-native-app/services/api.ts)

**1. Fix `examAPI`:** Remove the incorrect `examAPI.start()` (which tried to create an exam from mobile). Replace with:
- `examAPI.getActive(studentId)` → `GET /exam/active/{student_id}`
- `examAPI.submit(examId, studentId, reason?)` → `POST /exam/submit` (keep, body is correct)

**2. Add WS auto-reconnect:** Replace the `onclose` no-op with exponential backoff reconnect:
```
let wsReconnectTimer: ReturnType<typeof setTimeout> | null = null;
wsConnection.onclose = () => {
  // Reconnect in 2s, 4s, 8s up to 30s
};
```

**3. Add `notifyAPI`:** Add `GET /notify/student/{student_id}` to fetch unread notifications for the bell button.

---

### Mobile — `home.tsx`

#### [MODIFY] [home.tsx](file:///c:/Users/omarh/projects/Classroom-Emotion-System/react-native-app/app/(student)/home.tsx)

**1. Handle `exam:start` WS event:** Add handler alongside `session:start`. When `data.type === "exam:start"` arrives:
- Set `activeExamId` in store
- Alert "Exam Started — Please go to Exam screen"
- Navigate to `/(student)/exam`

**2. Wire notification bell:** On press, call `notifyAPI.getStudent(studentId)` and show a simple badge count + list in a Modal.

**3. Add `activeExamId` to store** (see store changes below).

---

### Mobile — `useStore.ts`

#### [MODIFY] [useStore.ts](file:///c:/Users/omarh/projects/Classroom-Emotion-System/react-native-app/store/useStore.ts)

Add `activeExamId: string | null` and `setActiveExamId(id)` to the store so `exam.tsx` can read the current exam without guessing.

---

### Mobile — `exam.tsx`

#### [MODIFY] [exam.tsx](file:///c:/Users/omarh/projects/Classroom-Emotion-System/react-native-app/app/(student)/exam.tsx)

**1. Read `activeExamId` from store** instead of deriving it from `activeLectureId ?? EXAM_${Date.now()}`.

**2. Remove `examAPI.start()` call on mount** — exam is now started by the lecturer, mobile just joins.

**3. Add `exam:start` WS handler** that sets `examId` from the WS payload.

**4. Improve incident display** — add severity color coding (Sev 1 = yellow, Sev 2 = orange, Sev 3 = red).

---

## Sprint 3 — AI Intervention Mobile UI

---

### Mobile — `focus.tsx`

#### [MODIFY] [focus.tsx](file:///c:/Users/omarh/projects/Classroom-Emotion-System/react-native-app/app/(student)/focus.tsx)

**Current state:** Has a `freshBrainerQ` state and a basic Modal that shows a text question with a "Got it" button. WS handler for `type === "freshbrainer"` already exists.

**What's missing:** The WS `freshbrainer` event also carries MCQ data when it's a comprehension check (`POST /gemini/check/generate`). The bottom sheet needs to:

1. **Handle both event subtypes:**
   - `type: "freshbrainer"` → shows open-ended question text only (current behavior — keep)
   - `type: "comprehension_check"` → shows MCQ with 3 option buttons + submits answer via `checkAPI.submitAnswer()`

2. **Upgrade the modal to a proper bottom sheet:**
   - Gold top handle bar (drag indicator)
   - Icon + "Question from Lecturer" header
   - Question text
   - For MCQ: 3 tappable option buttons (A/B/C), correct answer shows ✅ after selection
   - 30-second countdown timer (auto-dismiss on expire)
   - "Got it" / submit CTA

3. **Add WS handler for `comprehension_check` event:**
```ts
if (data.type === "comprehension_check") {
  setActiveCheck({
    id: data.check_id,
    question: data.question,
    options: data.options, // string[]
  });
}
```

4. **Track timer state** — use `useRef` for a 30s interval, clear on dismiss or answer.

---

### Mobile — New Component

#### [NEW] [FreshBrainerSheet.tsx](file:///c:/Users/omarh/projects/Classroom-Emotion-System/react-native-app/components/FreshBrainerSheet.tsx)

Extract the bottom sheet into its own component to keep `focus.tsx` clean. Props:
```ts
interface FreshBrainerSheetProps {
  visible: boolean;
  question: string | null;
  checkId?: number;       // present for MCQ checks
  options?: string[];     // present for MCQ checks
  studentId: string;
  onDismiss: () => void;
}
```

Internally handles:
- 30-second countdown with animated progress bar
- Option selection + `checkAPI.submitAnswer()` call
- Result feedback (✅ correct / ❌ wrong)
- Auto-dismiss on timer expiry

---

### Backend — Gemini Router

#### [MODIFY] [gemini.py](file:///c:/Users/omarh/projects/Classroom-Emotion-System/python-api/routers/gemini.py)

**Upgrade `POST /gemini/check/generate` WS broadcast:**
Currently broadcasts nothing after saving the check. Add a broadcast after `db.commit()`:
```python
await manager.broadcast({
    "type": "comprehension_check",
    "check_id": new_check.id,
    "lecture_id": lecture_id,
    "question": new_check.question,
    "options": mcq["options"],
    "topic": new_check.topic,
})
```
This closes the loop: Shiny triggers MCQ generation → backend saves + broadcasts → mobile shows the sheet.

---

## Files Changed Summary

### Backend (`python-api/`)
| File | Change |
|---|---|
| `services/vision_pipeline.py` | Wire proctor checks + auto-submit broadcast in exam loop |
| `routers/exam.py` | Add `GET /exam/active/{sid}`, `GET /exam/list/{class_id}`, `POST /exam/start-session` |
| `routers/gemini.py` | Broadcast `comprehension_check` WS event after MCQ saved |

### Mobile (`react-native-app/`)
| File | Change |
|---|---|
| `services/api.ts` | Fix `examAPI`, add WS reconnect, add `notifyAPI` |
| `store/useStore.ts` | Add `activeExamId` field |
| `app/(student)/home.tsx` | Handle `exam:start` WS + wire notification bell |
| `app/(student)/exam.tsx` | Use store `activeExamId`, remove `examAPI.start()` on mount |
| `app/(student)/focus.tsx` | Upgrade WS handler + delegate to `FreshBrainerSheet` |
| `components/FreshBrainerSheet.tsx` | **[NEW]** Bottom sheet with MCQ, timer, answer submission |

**Total: 9 files** (3 backend, 6 mobile)

---

## Verification Plan

### Backend Tests
- `curl -X POST /session/start` with `context=exam&exam_id=EXAM001` → vision thread spawns with proctor active
- `curl /exam/incidents/EXAM001` → incidents logged after simulated violations
- `curl -X POST /gemini/check/generate?lecture_id=LEC001` → check saved + WS broadcast received

### Mobile Tests
- Launch app → set `activeExamId` in store → exam screen shows correct ID (not `EXAM_${timestamp}`)
- Trigger `comprehension_check` WS message via `wscat` → `FreshBrainerSheet` appears with options
- Select wrong answer → red ❌ feedback, correct answer → green ✅
- Wait 30s without answering → sheet auto-dismisses
- Kill WS server → wait 2s → WS reconnects automatically

### Integration Test (T072)
- Lecturer starts exam via Shiny `POST /exam/start-session` → mobile receives `exam:start` and redirects
- Vision thread logs `phone_on_desk` incident → `check_auto_submit` triggers → mobile receives `exam:autosubmit` → auto-submits
