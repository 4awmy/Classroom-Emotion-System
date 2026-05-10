# AI Tools Handout — AAST Classroom Emotion System
**For the full team: S1 (Vision), S2 (Shiny), S3 (Backend), S4 (Mobile)**

---

## Live URLs (bookmark these)

| Service | URL |
|---|---|
| **Backend API** | https://classroomx-lkbxf.ondigitalocean.app |
| **API Docs (Swagger)** | https://classroomx-lkbxf.ondigitalocean.app/docs |
| **Health Check** | https://classroomx-lkbxf.ondigitalocean.app/health |
| **GitHub Branch** | `deploy-ready` (auto-deploys on push) |

---

## 1. Claude Code (AI pair programmer in terminal)

**Install:**
```bash
npm install -g @anthropic-ai/claude-code
```

**Start in project root:**
```bash
cd Classroom-Emotion-System
claude
```

**What it can do:**
- Read, edit, and write code across the whole project
- Run terminal commands, git, tests
- Fix bugs you paste into the chat
- Explain any file in the codebase

**Best prompts:**
```
Fix the attendance snapshot not saving for lecture L1
Show me all students with engagement below 0.3
Why is the Shiny dashboard not showing live data?
Add a /lecturer/stats endpoint to the FastAPI backend
```

---

## 2. Gemini CLI

**Install:**
```bash
npm install -g @google/gemini-cli
```

**Authenticate:**
```bash
gemini auth login
# Opens browser → sign in with Google account that has Gemini API access
```

**Basic usage:**
```bash
# Ask a question
gemini "explain the vision pipeline in python-api/services/vision_pipeline.py"

# With file context
gemini -f python-api/routers/session.py "what does the start_lecture endpoint do"

# Fix a bug
gemini -f python-api/database.py "why would this fail in production"
```

**With MCP server (gives Gemini access to live DB — see Section 4):**
```bash
gemini --mcp mcp_server/gemini_mcp_config.json "how many students are enrolled"
```

**Your Gemini API Key:**
- Get from: https://aistudio.google.com → Get API Key
- Set it: `export GEMINI_API_KEY=your_key_here`
- Model to use: `gemini-2.5-flash` (free tier)

---

## 3. OpenAI Codex CLI

**Install:**
```bash
npm install -g @openai/codex
```

**Authenticate:**
```bash
export OPENAI_API_KEY=your_openai_key
# Or create ~/.codex/config.json:
# { "apiKey": "your_openai_key" }
```

**Basic usage:**
```bash
# Start interactive session in project
cd Classroom-Emotion-System
codex

# Direct command
codex "add input validation to the roster upload endpoint"
codex "write a test for the emotion mapping function"
codex "explain what shiny-app/modules/engagement_score.R does"
```

**Useful flags:**
```bash
codex --model gpt-4o "refactor vision_pipeline.py to be cleaner"
codex --approval-mode auto "fix the failing health check"  # runs without confirmation
```

**What Codex is best at:**
- Writing new functions from scratch
- Refactoring specific files
- Writing unit tests
- Explaining algorithms

---

## 4. MCP Server — Give AI tools access to live data

The MCP server exposes your live database and API to Claude, Gemini CLI, and Codex.

### Setup (one time, all team members)

```bash
cd Classroom-Emotion-System
pip install -r mcp_server/requirements.txt

# Create mcp_server/.env
echo "API_URL=https://classroomx-lkbxf.ondigitalocean.app" > mcp_server/.env
echo "LOCAL_DATABASE_URL=postgresql://postgres:password123@localhost:5432/classroom_emotions" >> mcp_server/.env
```

### Connect to Claude Code

Add to your `~/.claude/claude_desktop_config.json` (create if missing):

```json
{
  "mcpServers": {
    "aast-lms": {
      "command": "python",
      "args": ["C:/Users/omarh/projects/Classroom-Emotion-System/mcp_server/server.py"],
      "env": {
        "API_URL": "https://classroomx-lkbxf.ondigitalocean.app",
        "LOCAL_DATABASE_URL": "postgresql://postgres:password123@localhost:5432/classroom_emotions"
      }
    }
  }
}
```

Then in Claude Code you can say:
```
Get the engagement summary for lecture L1
Show me students with confusion rate above 40%
How many students attended yesterday's lecture?
Run: SELECT * FROM emotion_log ORDER BY timestamp DESC LIMIT 5
```

### Connect to Gemini CLI

Create `mcp_server/gemini_mcp_config.json`:
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

Then:
```bash
gemini --mcp mcp_server/gemini_mcp_config.json "which students were confused in the last lecture"
```

### Connect to Codex

```bash
codex --mcp-config mcp_server/codex_mcp_config.json "analyze engagement trends"
```

Create `mcp_server/codex_mcp_config.json`:
```json
{
  "mcpServers": {
    "aast-lms": {
      "command": "python",
      "args": ["mcp_server/server.py"]
    }
  }
}
```

### Available MCP Tools

| Tool | What it does |
|---|---|
| `health_check` | Is the backend alive? |
| `get_table_stats` | Row counts for all tables |
| `get_students` | List/search students |
| `get_recent_emotions` | Latest emotion log entries |
| `get_attendance` | Attendance records |
| `get_engagement_summary` | Per-student engagement for a lecture |
| `get_confused_students` | Students above confusion threshold |
| `get_lectures` | List recent lectures |
| `get_incidents` | Exam proctoring flags |
| `run_sql` | Run any SELECT query |
| `call_api` | Call any live API endpoint |

---

## 5. Who Uses What

| Team Member | Primary Tool | Use Case |
|---|---|---|
| **S1 (Vision)** | Claude Code | Debug vision_pipeline.py, face recognition issues |
| **S2 (Shiny/R)** | Gemini CLI | R code help, Shiny layout questions |
| **S3 (Backend)** | Claude Code + MCP | API debugging, DB queries, deployment |
| **S4 (Mobile)** | Codex | React Native TypeScript, Expo issues |

---

## 6. Daily Workflow

### When you push a fix:
```bash
git add .
git commit -m "fix: your change"
git push origin deploy-ready
# DO auto-deploys in ~3 minutes
```

### Check if your deploy worked:
```bash
curl https://classroomx-lkbxf.ondigitalocean.app/health
# Should return: {"status":"ok"}
```

### View live logs:
```bash
# Install doctl first (see below)
doctl apps logs 05c01b58-661a-4a35-af36-e2cccf78495c --type run
```

### Install doctl (DO CLI):
```bash
winget install DigitalOcean.Doctl   # Windows
# or: brew install doctl            # Mac
doctl auth init                     # paste DO token when prompted
```

---

## 7. Emergency Contacts

| Issue | Who to ping |
|---|---|
| Backend down / API errors | S3 |
| Vision pipeline not detecting | S1 |
| Shiny portal broken | S2 |
| Mobile app crashes | S4 |
| Database questions | S3 (has Docker locally) |

---

## 8. Key Files Reference

| File | What it is |
|---|---|
| `python-api/main.py` | FastAPI entry point |
| `python-api/database.py` | DB connection |
| `python-api/services/vision_pipeline.py` | Camera → emotion detection |
| `shiny-app/app.R` | Shiny entry point |
| `shiny-app/modules/engagement_score.R` | Core engagement math |
| `react-native-app/app/(student)/focus.tsx` | Student focus mode |
| `vision/main.py` | Standalone vision client (run locally on demo day) |
| `mcp_server/server.py` | MCP server for AI tools |
| `do_manager.py` | DigitalOcean management script |
| `prod_seed.sql` | Full DB dump (119 students) |
