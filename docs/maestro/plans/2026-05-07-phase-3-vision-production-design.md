---
design_depth: deep
task_complexity: complex
---

# Design Document: Phase 3 Vision Pipeline Production Readiness

## 1. Problem Statement
The Phase 3 vision pipeline is functionally mapped but lacks critical production-ready features. The core issue is that the current implementation is incomplete across four vectors:
1) **Dataset Encoding**: The SQLite database only contains a subset of face encodings, meaning real-world attendance matching will fail for the 127 student roster.
2) **Proctoring**: Head rotation detection relies on placeholder logic, preventing accurate automated exam monitoring.
3) **Interventions**: The Gemini AI service is mocked out, blocking the delivery of actionable, dynamic student insights.
4) **Robustness**: The camera stream thread drops silently on network hiccups or camera disconnects, which is unacceptable for live campus lectures.

We must close these gaps to align the codebase fully with the 'New Architecture' (Approach B) and formally complete the Phase 3 milestone.

## 2. Requirements

**Functional Requirements:**
- **REQ-1**: The system must successfully execute `encode_real_dataset.py` to process and store all 127 student face encodings into the SQLite `students` table.
- **REQ-2**: The `proctor_service.py` must integrate MediaPipe FaceMesh to calculate and evaluate 3D head rotation angles for exam monitoring.
- **REQ-3**: The `gemini_service.py` must perform real asynchronous LLM API calls to generate intervention plans and broadcast the results to connected clients via WebSockets.
- **REQ-4**: The vision pipeline execution thread in `session.py`/`vision_pipeline.py` must implement an aggressive auto-reconnect loop to handle intermittent camera stream drops.

**Non-Functional Requirements:**
- **REQ-5**: Memory Conservation: MediaPipe must be lazily instantiated only when proctoring mode is explicitly activated.
- **REQ-6**: API Responsiveness: Gemini API calls must utilize FastAPI's `BackgroundTasks` to ensure the main event loop remains unblocked.

**Constraints:**
- **CON-1**: Architectural Integrity: The implementation must extend the existing monolithic FastAPI architecture without introducing external message brokers (like Celery/Redis).

## 3. Approach

**Selected Approach: Monolithic Integration**
We will implement the final Phase 3 features directly within the existing FastAPI monolith — *[keeps deployment simple and leverages existing thread models]* (Traces To: CON-1). MediaPipe will be integrated into `proctor_service.py` but strictly instantiated on-demand — *[avoids memory bloat during standard lectures where head rotation is unneeded]* (Traces To: REQ-2, REQ-5). Gemini integration will utilize `fastapi.BackgroundTasks` — *[ensures the API remains instantly responsive without requiring external queues like Celery]* (Traces To: REQ-3, REQ-6). Dataset encoding will be executed natively as a standalone script step to fully populate the SQLite database — *[ensures the two-stage pipeline can actually match all students in the wild]* (Traces To: REQ-1). Finally, the camera stream loop will wrap cv2 reads in an aggressive backoff-retry loop (Traces To: REQ-4).

**Alternatives Considered:**
- **Offloaded Pipeline** *(considered: moving vision to Celery/Redis — rejected because it violates CON-1 and adds unnecessary infrastructure overhead)*.
- **YOLOv8 Landmarks** *(considered: extracting head pose from YOLO-face — rejected because it lacks the 3D precision of MediaPipe required for strict exam proctoring)*.

**Decision Matrix:**
| Criterion | Weight | Monolithic (Selected) | Offloaded Pipeline |
|---|---|---|---|
| Feature Completeness | 40% | 5: Implements all features | 5: Implements all features |
| API Performance | 30% | 3: Potential GIL contention | 5: Zero API impact |
| Implementation Speed | 30% | 5: Matches current repo | 2: Major architectural shift |
| **Weighted Total** | | **4.4** | **4.1** |

## 4. Architecture

**Component & Data Flow:**

1. **Vision Pipeline (Live Heartbeat):**
   `FastAPI Route` -> spawns thread in `session.py` -> runs `vision_pipeline.py`.
   The pipeline executes: YOLOv8-person -> YOLOv8-face -> HSEmotion -> `face_recognition` (against SQLite BLOBs).
   *Stream Robustness*: The `cv2.VideoCapture` read step is wrapped in a retry block — *[prevents silent thread death on Wi-Fi drops]* (Traces To: REQ-4).

2. **Proctoring Module (Exam Mode):**
   If the session is an exam, `vision_pipeline.py` calls `proctor_service.py`.
   `proctor_service.py` initializes MediaPipe FaceMesh -> calculates head rotation vector.
   *[This logic is strictly isolated to the exam flow to protect standard lecture performance]* (Traces To: REQ-2, REQ-5).

3. **Intervention Module (AI):**
   `FastAPI Route` calls `gemini_service.py`.
   Service offloads to `BackgroundTasks` -> calls LLM API -> receives plan -> pushes to `websocket.py`.
   *[This provides a standard async push pattern without blocking the client]* (Traces To: REQ-3, REQ-6).

4. **Dataset Pipeline (Pre-flight):**
   `encode_real_dataset.py` iterates over the 127 images -> uses `face_recognition` -> writes directly to `classroom_emotions.db`.
   *[Ensures the live vision thread has the complete roster available for matching]* (Traces To: REQ-1).

## 5. Agent Team

Based on our domain analysis, the following subagents will execute this plan:

- **coder**: Will handle the heavy lifting of extending `proctor_service.py` (MediaPipe), `gemini_service.py` (BackgroundTasks), and executing the `encode_real_dataset.py` script. — *[Selected because the task is primarily focused on Python backend implementation]* (Traces To: REQ-1, REQ-2, REQ-3, REQ-4).
- **tester**: Will write integration tests to verify the async Gemini endpoints and ensure MediaPipe correctly calculates head rotation on mock images. — *[Ensures the new complex integrations are stable before Phase 4]* (Traces To: REQ-2, REQ-3).
- **code_reviewer**: Will perform a final security and performance audit of the pipeline during the completion phase. — *[Critical quality gate to ensure GIL contention hasn't spiked]* (Traces To: CON-1).

## 6. Risk Assessment

- **Performance Degradation (High)**: Running YOLOv8-person, YOLOv8-face, and MediaPipe FaceMesh concurrently during an exam could overload the CPU/GPU and drop the frame rate.
  *Mitigation*: Ensure MediaPipe is strictly lazy-loaded and only processes the small, already-detected face crop (from YOLO-face), rather than the full image frame. — *[Directly addresses the overhead risk inherent to the chosen Monolithic approach]* (Traces To: CON-1, REQ-5).

- **Network I/O Blocking (Medium)**: External Gemini API calls may experience high latency, potentially hanging the server.
  *Mitigation*: FastAPIs `BackgroundTasks` will guarantee the main thread and active vision loops are never blocked waiting for the LLM. — *[Proactive handling of third-party API latency]* (Traces To: REQ-6).

- **Encoding Failures (Low)**: Some images in the 127-student dataset might be unreadable or contain no faces.
  *Mitigation*: The `encode_real_dataset.py` script will gracefully catch and log failed encodings, allowing the script to complete for valid photos rather than crashing the pipeline. — *[Ensures the bulk of the roster is encoded even with dirty data]* (Traces To: REQ-1).

## 7. Success Criteria

The Phase 3 Vision Pipeline will be considered "Production Ready" when:
1. **Dataset Verified**: The `classroom_emotions.db` `students` table contains 127 valid face encoding BLOBs. — *[Validates REQ-1]*.
2. **Proctoring Verified**: Triggering an exam session successfully calculates and logs 3D head rotation vectors via MediaPipe without crashing the vision thread. — *[Validates REQ-2, REQ-5]*.
3. **Interventions Verified**: Calling the Gemini intervention endpoint immediately returns an HTTP 202 Accepted, and the actual LLM payload is subsequently received over the connected WebSocket. — *[Validates REQ-3, REQ-6]*.
4. **Robustness Verified**: Artificially interrupting the camera stream (e.g., simulating a network drop) triggers an observable, automatic backoff-and-reconnect loop in the server logs rather than thread death. — *[Validates REQ-4]*.