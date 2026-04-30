# WebSocket Contracts — AAST LMS

**Date**: 2026-04-30 | Source: ARCHITECTURE.md Section 4 + CLAUDE.md (updated)

**Endpoint**: `ws://{host}/session/ws`

All messages use JSON with `"type"` as the event discriminator. The `"event"` key is FORBIDDEN.

---

## Server → Client Messages

### session:start
Sent when lecturer clicks "Start Lecture".
```json
{
  "type": "session:start",
  "lectureId": "L1",
  "slideUrl": "https://drive.google.com/...",
  "startTime": "2026-04-30T09:00:00"
}
```

### session:end
Sent when lecturer clicks "End Lecture".
```json
{
  "type": "session:end",
  "lectureId": "L1",
  "endTime": "2026-04-30T10:00:00"
}
```

### caption
Sent every ~5 seconds when Whisper produces a transcript chunk.
```json
{
  "type": "caption",
  "text": "وسنتحدث اليوم عن الـ recursion",
  "lecture_id": "L1",
  "timestamp": "2026-04-30T09:05:32",
  "language": "mixed"
}
```

### freshbrainer
Sent when lecturer confirms the AI-generated confusion question.
```json
{
  "type": "freshbrainer",
  "question": "What is the difference between stack and heap memory?",
  "lecture_id": "L1"
}
```

### exam:autosubmit
Sent when the exam auto-submit threshold is triggered (3× sev-3 in 10 min).
```json
{
  "type": "exam:autosubmit",
  "exam_id": "E1",
  "student_id": "231006367",
  "reason": "3 severity-3 incidents in 10 minutes"
}
```

---

## Client → Server Messages

### focus_strike
Sent when React Native detects `AppState` changing to background during focus mode.
```json
{
  "type": "focus_strike",
  "student_id": "231006367",
  "lecture_id": "L1",
  "strike_type": "app_background"
}
```

**Exam variant** (routes to `incidents` table instead of `focus_strikes`):
```json
{
  "type": "focus_strike",
  "student_id": "231006367",
  "lecture_id": "L1",
  "strike_type": "app_background",
  "context": "exam"
}
```

---

## Routing Logic (server-side, session.py)

| Message type | Source | Handler | DB write |
|---|---|---|---|
| `focus_strike` (no context) | React Native | `session.py` WS handler | `focus_strikes` |
| `focus_strike` (context=exam) | React Native | `session.py` WS handler | `incidents` (sev=1) |

---

## Offline Strike Caching (client-side)

When WS is disconnected, React Native queues strikes in `AsyncStorage`. On reconnect:
1. Drain queue in FIFO order
2. Send each cached strike as a `focus_strike` message
3. Clear queue only after server acknowledges (no explicit ACK needed — fire-and-forget)
