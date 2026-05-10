# AI Dev Tools Handout — AAST Classroom Emotion System
**For the full team — how to use AI agents to develop the project**

---

## TL;DR — Quick Start per Person

| You are | Use this | For what |
|---|---|---|
| S1 (Vision) | **Claude Code** | Fix vision_pipeline.py, debug face recognition |
| S2 (Shiny/R) | **Gemini CLI** | R/Shiny code, ggplot, httr2 calls |
| S3 (Backend) | **Claude Code** | FastAPI routes, DB, deployment |
| S4 (Mobile) | **Codex CLI** | React Native, TypeScript, Expo |

---

## Live URLs

| | URL |
|---|---|
| Backend API | `https://classroomx-lkbxf.ondigitalocean.app` |
| API Docs | `https://classroomx-lkbxf.ondigitalocean.app/docs` |
| Health | `https://classroomx-lkbxf.ondigitalocean.app/health` |
| GitHub Branch | `deploy-ready` (auto-deploys on every push) |

---

## 1. Claude Code

The most capable agent for this project — reads CLAUDE.md, knows the full architecture.

**Install & run:**
```bash
npm install -g @anthropic-ai/claude-code
cd Classroom-Emotion-System
claude
```

**Best for:**
- Multi-file changes ("add this feature across backend + Shiny")
- Debugging deployment errors from DO logs
- Database migrations and schema changes
- Anything that needs context from the whole codebase

**Example prompts:**
```
The vision pipeline keeps logging "No frames found" — fix it
Add a /lecturer/engagement endpoint that returns per-student scores
The Shiny live dashboard isn't refreshing — find why
Run the backend locally and test the /health endpoint
```

**MCP server gives Claude live DB + dev tools — already configured.**
Just start `claude` and ask questions involving real data.

---

## 2. Gemini CLI

Best for R/Shiny work and quick code questions. Free with Google account.

**Install:**
```bash
npm install -g @google/gemini-cli
gemini           # first run — sign in with Google
```

**Or with API key:**
```bash
export GEMINI_API_KEY=your_key_here   # from aistudio.google.com
```

**Basic usage:**
```bash
# Ask about a file
gemini "explain shiny-app/modules/engagement_score.R"

# Fix something
gemini -f shiny-app/server/lecturer_server.R "the live dashboard panel isn't updating, fix it"

# R-specific help
gemini "write an httr2 call to GET /emotion/live?lecture_id=L1 and plot the result with ggplot2"
```

**With MCP (gives Gemini access to live DB and project tools):**

1. Install deps: `pip install -r mcp_server/requirements.txt`
2. Create `mcp_server/.env`:
   ```
   API_URL=https://classroomx-lkbxf.ondigitalocean.app
   LOCAL_DATABASE_URL=postgresql://postgres:password123@localhost:5432/classroom_emotions
   ```
3. Run with MCP:
   ```bash
   gemini --mcp mcp_server/gemini_config.json "show me all students with engagement below 0.4"
   ```

Create `mcp_server/gemini_config.json`:
```json
{
  "mcpServers": {
    "aast-lms": {
      "command": "python",
      "args": ["mcp_server/server.py"],
      "env": {
        "API_URL": "https://classroomx-lkbxf.ondigitalocean.app",
        "LOCAL_DATABASE_URL": "postgresql://postgres:password123@localhost:5432/classroom_emotions"
      }
    }
  }
}
```

**What Gemini can do via MCP:**
- Read any project file → understand before writing
- Search the codebase → find where something is defined
- Query the DB → check if data exists before writing code
- Check if the backend is up
- See git status and recent commits

---

## 3. OpenAI Codex CLI

Best for React Native / TypeScript (S4) and writing new functions from scratch.

**Install:**
```bash
npm install -g @openai/codex
export OPENAI_API_KEY=your_key
```

**Basic usage:**
```bash
cd Classroom-Emotion-System
codex   # interactive mode

# Or direct:
codex "add pull-to-refresh to the home screen in react-native-app"
codex "fix the TypeScript error in react-native-app/store/useStore.ts"
codex "write a test for the focus strike WebSocket event"
```

**With MCP:**
Create `mcp_server/codex_config.json`:
```json
{
  "mcpServers": {
    "aast-lms": {
      "command": "python",
      "args": ["mcp_server/server.py"],
      "env": {
        "API_URL": "https://classroomx-lkbxf.ondigitalocean.app"
      }
    }
  }
}
```

```bash
codex --mcp-config mcp_server/codex_config.json \
  "check what /session/upcoming returns then update home.tsx to render it properly"
```

**Codex strengths for this project:**
- `react-native-app/` — TypeScript, Expo, Zustand
- Writing unit/integration tests
- Refactoring existing functions
- Fixing type errors

---

## 4. MCP Server — What Dev Tools Each Agent Gets

The MCP server (`mcp_server/server.py`) gives all agents these tools:

### Understanding the project
| Tool | What it does |
|---|---|
| `get_project_context` | Read CLAUDE.md — architecture, constraints, schemas |
| `get_tasks` | Read TASKS.md — what's done, pending, in-progress |
| `get_db_schema` | Live table schemas from the database |

### Exploring code
| Tool | What it does |
|---|---|
| `read_file` | Read any file in the project |
| `search_code` | Grep across codebase for a pattern |
| `list_files` | List files in a directory |

### Running things
| Tool | What it does |
|---|---|
| `run_command` | Run any shell command (git, pip, scripts) |
| `run_python` | Run Python in python-api context |
| `get_backend_errors` | Read backend_err.log |

### Backend & DB
| Tool | What it does |
|---|---|
| `check_backend` | Health check on live + local |
| `call_api` | Call any API endpoint |
| `query_db` | Run a SELECT on local PostgreSQL |
| `db_stats` | Row counts for all tables |

### Git & Deploy
| Tool | What it does |
|---|---|
| `git_status` | Branch, status, recent commits |
| `git_diff` | Staged or unstaged changes |
| `check_deployment` | DO deployment phase + live URL |

---

## 5. Workflow — How to Use AI to Develop a Feature

### Example: S2 adding a new Shiny panel

```bash
# 1. Ask Gemini to understand the project first
gemini --mcp mcp_server/gemini_config.json \
  "read CLAUDE.md and explain how the admin panels work, then show me admin_server.R"

# 2. Ask it to write the feature
gemini --mcp mcp_server/gemini_config.json \
  "add an 8th admin panel showing time-of-day engagement heatmap.
   Use ggplot2 geom_tile. Data comes from emotions.csv via reactivePoll."

# 3. Check it works
gemini "does the heatmap code look correct? check shiny-app/server/admin_server.R"

# 4. Push
git add . && git commit -m "feat: time-of-day heatmap panel" && git push origin deploy-ready
```

### Example: S1 debugging vision pipeline

```bash
# With Claude Code (already has MCP)
claude
> check backend_err.log, then read vision_pipeline.py and tell me why frames aren't saving
> query the DB to see if any emotion_log rows exist
> fix the snapshot saving bug and test it
```

### Example: S4 adding a new screen

```bash
codex --mcp-config mcp_server/codex_config.json \
  "call /session/upcoming to see the response shape,
   then build a proper lecture list component in home.tsx"
```

---

## 6. Daily Git Workflow

```bash
# Always work on deploy-ready
git checkout deploy-ready
git pull origin deploy-ready

# Make changes...

git add -p              # review what you're committing
git commit -m "feat: what you did"
git push origin deploy-ready

# DO auto-deploys in ~3 min
# Verify:
curl https://classroomx-lkbxf.ondigitalocean.app/health
```

---

## 7. Key Files — Know These

```
python-api/main.py                    FastAPI entry point
python-api/database.py                DB connection (reads DATABASE_URL)
python-api/models.py                  SQLAlchemy ORM models
python-api/services/vision_pipeline.py  Camera → YOLO → face → emotion
shiny-app/app.R                       Shiny entry point
shiny-app/global.R                    Libraries + FASTAPI_BASE config
shiny-app/modules/engagement_score.R  Core engagement math (LOCKED)
react-native-app/app/(student)/focus.tsx  AppState focus mode
vision/main.py                        Local vision client (demo day only)
mcp_server/server.py                  This MCP server
prod_seed.sql                         Full DB dump — 119 students
CLAUDE.md                             Single source of truth — READ THIS FIRST
TASKS.md                              All tasks T001–T074
```
