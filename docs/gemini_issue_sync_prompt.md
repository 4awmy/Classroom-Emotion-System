# Gemini CLI Task: Sync GitHub Issues with Speckit Tasks

## Context
The project's plan was just fully revalidated. The old GitHub issues (#86-#170, ~80 issues) are based on an outdated WBS that uses the `[P1-S1-01]` format organized by Phase + Student Role (S1=Vision, S2=Shiny, S3=Backend, S4=React Native).

The new authoritative task list is `specs/aast-lms-validation/tasks.md` with 74 tasks (T001-T074) organized by Phase + User Story (US1-US5). This is now the single source of truth.

## Your Task

### Step 1: Close ALL old issues (#86 through #170)
Run a loop to close every old issue with a comment explaining the migration:

```powershell
$issues = @(86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,166,167,168,170)
foreach ($i in $issues) {
    gh issue close $i --repo 4awmy/Classroom-Emotion-System --comment "Superseded by Speckit-validated task list. See specs/aast-lms-validation/tasks.md for updated T001-T074 tasks."
}
```

### Step 2: Create new labels for the 8 phases
```powershell
gh label create "Phase 1: Setup" --color "e6e6e6" --description "Env config, dependencies, directories" --repo 4awmy/Classroom-Emotion-System
gh label create "Phase 2: Foundation" --color "c2e0c6" --description "SQLite, ORM, mocks, JWT — BLOCKS everything" --repo 4awmy/Classroom-Emotion-System
gh label create "Phase 3: US1 Vision" --color "fbca04" --description "YOLO, face_recognition, HSEmotion, Whisper, export" --repo 4awmy/Classroom-Emotion-System
gh label create "Phase 4: US2 Shiny" --color "7057ff" --description "Admin panels, Lecturer dashboard, R analytics" --repo 4awmy/Classroom-Emotion-System
gh label create "Phase 5: US3 Mobile" --color "d93f0b" --description "React Native: login, focus, captions, notes" --repo 4awmy/Classroom-Emotion-System
gh label create "Phase 6: US4 AI" --color "0e8a16" --description "Gemini smart notes, fresh-brainer, intervention" --repo 4awmy/Classroom-Emotion-System
gh label create "Phase 7: US5 Exam" --color "b60205" --description "Proctoring: phone, head, auto-submit" --repo 4awmy/Classroom-Emotion-System
gh label create "Phase 8: Polish" --color "006b75" --description "CI/CD, integration test, README" --repo 4awmy/Classroom-Emotion-System
gh label create "MVP" --color "ff9f1c" --description "Required for demo presentation" --repo 4awmy/Classroom-Emotion-System
gh label create "blocking" --color "b60205" --description "Blocks other tasks from starting" --repo 4awmy/Classroom-Emotion-System
```

### Step 3: Create all 74 new issues from tasks.md
Read `specs/aast-lms-validation/tasks.md` and create one GitHub issue per task (T001-T074).

For each task:
- **Title**: `[T0XX] Short description` (e.g. `[T001] Verify Python 3.11 installed`)
- **Body**: The full task description from tasks.md including file paths, commands, and "Done when" criteria
- **Labels**: Assign the phase label from Step 2. Also add `MVP` label to Phases 1-5 tasks. Add `blocking` label to T009-T024.
- **Milestone**: Create milestones for `Phase 1: Setup`, `Phase 2: Foundation`, `Phase 3: Vision Pipeline`, `Phase 4: Shiny Portal`, `Phase 5: Mobile App`, `Phase 6: AI`, `Phase 7: Exam`, `Phase 8: Polish`

Example issue creation:
```powershell
gh issue create --repo 4awmy/Classroom-Emotion-System --title "[T001] Verify Python 3.11 installed" --body "Verify Python 3.11 installed: ``python --version`` must show 3.11.x (required by face_recognition/dlib)" --label "Phase 1: Setup" --label "MVP" --milestone "Phase 1: Setup"
```

### Step 4: Create dependency references
After all issues are created, add a comment to each Phase 3+ issue listing its blocking dependency:
- All Phase 3-8 issues: "Blocked by Phase 2 completion (T009-T024)"
- All Phase 6 issues: "Blocked by Phase 3 completion (T026-T033)"
- All Phase 7 issues: "Blocked by Phase 3 completion (T026-T033)"
- All Phase 8 issues: "Blocked by all desired user stories"

## Rules
- Use `--repo 4awmy/Classroom-Emotion-System` on every `gh` command
- Create milestones before assigning them to issues
- If a label already exists, `gh label create` will error — that's fine, skip it
- Do NOT create issues for tasks that are purely verification/checkpoint steps (those are Phase boundaries, not tasks)
- All 74 T-tasks from tasks.md MUST have a corresponding GitHub issue
