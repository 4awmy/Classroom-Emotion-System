# Agent 1: Complete Phase 1 Backend (S3 remaining)

## MANDATORY RULES — READ BEFORE DOING ANYTHING

### Collaboration Protocol (from GEMINI.md)
1. **Use `gh` CLI** to create branches, commits, and PRs for every implementation.
2. **No Unsolicited Work**: Do NOT start any new task or sub-task beyond what is listed below.
3. **PR & Merge Workflow**:
   a. Create a feature branch: `git checkout -b feature/phase1-s3-remaining`
   b. Commit frequently with descriptive messages.
   c. Push and create a **Draft PR** against `dev`: `gh pr create --base dev --draft --title "[Phase1-S3] Backend completion" --body-file <body>`
   d. After creating the PR, perform a **self-review** comment on the PR.
   e. Tag **@Copilot** in a PR comment requesting review.
   f. Do NOT merge. Wait for user approval.
4. **Stuck/Blocked Protocol**: If you hit a blocker (missing dependency, unclear spec, file conflict), **comment on the PR tagging @4awmy** and explain the blocker. Do NOT silently skip tasks.
5. **Plan Validation**: If you find an error in `ARCHITECTURE.md` or `CLAUDE.md`, STOP immediately and comment on the PR explaining the discrepancy.
6. **Branch Cleanup**: When merging (only after user says "Merge"), use `gh pr merge --delete-branch`.

### Architecture Rules (from constitution.md)
- **Data Isolation**: R/Shiny must never connect to SQLite directly. Only CSV exports.
- **Student IDs**: Use 9-digit format (e.g., `231006367`). NEVER use `S01` format.
- **WebSocket payloads**: Use `"type"` as the event key. NEVER use `"event"`.
- **Tech Stack**: Python 3.11, FastAPI, SQLite.

### Multi-Agent Coordination
- You are Agent 1 (Backend). Agent 2 (Shiny/R) is running in parallel.
- Do NOT touch any files in `shiny-app/`. That's Agent 2's territory.
- Do NOT touch any files in `react-native-app/`. That's Phase 5 work.
- Your scope is `python-api/` and `notebooks/` ONLY.

---

## What's Already Done
- database.py with WAL mode ✅
- models.py with all 9 ORM tables ✅
- main.py with all 8 routers imported ✅
- All mock endpoints (auth, emotion, attendance, session, gemini, exam, roster, upload) ✅
- WebSocket manager ✅
- requirements.txt ✅
- Data directories (exports, plans, evidence) ✅

## Tasks To Complete

### Task 1: Create python-api/.env.example (T002)
```
GEMINI_API_KEY=
OPENAI_API_KEY=
JWT_SECRET=change-me-in-production
DATABASE_URL=sqlite:///./data/classroom_emotions.db
CLASSROOM_CAMERA_URL=rtsp://192.168.1.x/stream
GOOGLE_APPLICATION_CREDENTIALS=./gcloud_key.json
FASTAPI_BASE_URL=http://localhost:8000
```

### Task 2: Fix notebooks/generate_synthetic_data.py (T025)
Read the existing file and fix ALL S01/S02-style student IDs to 9-digit format (231006367 through 231006493 for 127 students). The script should:
- Generate 127 students with 9-digit IDs
- Insert 1000+ emotion_log rows
- Insert attendance_log rows  
- Insert a few transcript rows
Run the script and verify data was seeded.

### Task 3: Create python-api/Procfile
```
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

### Task 4: Verify everything works
```bash
cd python-api
python -c "from database import engine; from main import app; print('Imports OK')"
```

## After All Tasks

1. `git add` all changed files in `python-api/` and `notebooks/`
2. `git commit -m "feat(backend): complete Phase 1 S3 remaining — .env.example, seeder fix, Procfile"`
3. `git push -u origin feature/phase1-s3-remaining`
4. Create draft PR: `gh pr create --base dev --draft --title "[Phase1-S3] Backend completion — .env.example, synthetic seeder, Procfile" --label "Phase 2: Foundation" --label "S3: Backend"`
5. Post self-review comment on the PR
6. Tag @Copilot for review: `gh pr comment <PR_NUMBER> --body "@Copilot Please review this PR."`
7. If anything is blocked, tag @4awmy: `gh pr comment <PR_NUMBER> --body "@4awmy BLOCKER: <describe issue>"`
