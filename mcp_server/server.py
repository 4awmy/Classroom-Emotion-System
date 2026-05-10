#!/usr/bin/env python3
"""
AAST LMS — Development MCP Server
Gives AI agents (Claude, Gemini CLI, Codex) full development capabilities:
  - Read project files, architecture, tasks
  - Search the codebase
  - Run the backend / tests
  - Query the database
  - Check deployment status
  - Git operations

Usage:
    python mcp_server/server.py
"""

import os, json, asyncio, subprocess, re
from pathlib import Path
from dotenv import load_dotenv
import httpx
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

load_dotenv(Path(__file__).parent / ".env")
load_dotenv(Path(__file__).parent.parent / "python-api" / ".env")

ROOT        = Path(__file__).parent.parent.resolve()
API_URL     = os.getenv("API_URL", "https://classroomx-lkbxf.ondigitalocean.app")
DB_URL      = os.getenv("DATABASE_URL") or os.getenv("LOCAL_DATABASE_URL",
              "postgresql://postgres:password123@localhost:5432/classroom_emotions")
LOCAL_API   = "http://localhost:8000"

server = Server("aast-lms-dev")

# ── Helpers ───────────────────────────────────────────────────────────────────
def _run(cmd: str, cwd: str = None, timeout: int = 30) -> dict:
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          cwd=cwd or str(ROOT), timeout=timeout)
        return {"stdout": r.stdout[-3000:], "stderr": r.stderr[-1000:],
                "returncode": r.returncode}
    except subprocess.TimeoutExpired:
        return {"error": f"Command timed out after {timeout}s", "returncode": -1}
    except Exception as e:
        return {"error": str(e), "returncode": -1}

def _api(path: str, method: str = "GET", body: dict = None, local: bool = False) -> dict:
    base = LOCAL_API if local else API_URL
    try:
        with httpx.Client(base_url=base, timeout=15) as c:
            fn = getattr(c, method.lower())
            r  = fn(path, json=body) if body else fn(path)
            return r.json()
    except Exception as e:
        return {"error": str(e)}

def _db(sql: str, params=None) -> list:
    try:
        import psycopg2, psycopg2.extras
        conn = psycopg2.connect(DB_URL)
        cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute(sql, params or ())
        rows = [dict(r) for r in cur.fetchall()]
        conn.close()
        return rows
    except Exception as e:
        return [{"error": str(e)}]

def _read_file(rel_path: str, max_lines: int = 200) -> str:
    p = ROOT / rel_path
    if not p.exists():
        return f"File not found: {rel_path}"
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    out   = "\n".join(lines[:max_lines])
    if len(lines) > max_lines:
        out += f"\n... ({len(lines) - max_lines} more lines)"
    return out

def out(data):
    return [TextContent(type="text", text=json.dumps(data, indent=2, default=str))]

# ── Tools ─────────────────────────────────────────────────────────────────────
@server.list_tools()
async def list_tools():
    return [
        # ── Project Understanding ──
        Tool(name="get_project_context",
             description="Get the full project architecture, stack, rules, and constraints from CLAUDE.md. "
                         "Always call this first before writing any code.",
             inputSchema={"type": "object", "properties": {
                 "section": {"type": "string",
                             "description": "Optional section to focus on, e.g. 'vision pipeline', 'database', 'deployment'"}
             }}),

        Tool(name="get_tasks",
             description="Get current task list from TASKS.md — shows what's done, in progress, and pending.",
             inputSchema={"type": "object", "properties": {}}),

        Tool(name="get_db_schema",
             description="Get all table schemas from the live database.",
             inputSchema={"type": "object", "properties": {
                 "table": {"type": "string", "description": "Specific table name (optional — omit for all tables)"}
             }}),

        # ── Codebase Search ──
        Tool(name="read_file",
             description="Read any file in the project by relative path.",
             inputSchema={"type": "object", "properties": {
                 "path":      {"type": "string",  "description": "Relative path from project root, e.g. python-api/main.py"},
                 "max_lines": {"type": "integer", "description": "Max lines to return (default 200)"},
             }, "required": ["path"]}),

        Tool(name="search_code",
             description="Search the codebase for a keyword or pattern (uses grep). "
                         "Use to find where something is defined or used.",
             inputSchema={"type": "object", "properties": {
                 "pattern":   {"type": "string", "description": "Search pattern (regex supported)"},
                 "directory": {"type": "string", "description": "Subdirectory to search in (optional)"},
                 "file_type": {"type": "string", "description": "File extension to filter, e.g. py, R, tsx"},
             }, "required": ["pattern"]}),

        Tool(name="list_files",
             description="List files in a directory.",
             inputSchema={"type": "object", "properties": {
                 "directory": {"type": "string", "description": "Relative path (default: project root)"},
                 "pattern":   {"type": "string", "description": "Glob pattern, e.g. *.py"},
             }}),

        # ── Running Things ──
        Tool(name="run_command",
             description="Run a shell command in the project. Use for: git operations, pip install, "
                         "running scripts, checking logs. NOT for starting long-running servers.",
             inputSchema={"type": "object", "properties": {
                 "command":   {"type": "string",  "description": "Shell command to run"},
                 "directory": {"type": "string",  "description": "Subdirectory to run in (optional)"},
                 "timeout":   {"type": "integer", "description": "Timeout in seconds (default 30)"},
             }, "required": ["command"]}),

        Tool(name="run_python",
             description="Run a Python snippet in the context of the python-api directory. "
                         "Useful for testing DB queries, importing models, checking config.",
             inputSchema={"type": "object", "properties": {
                 "code": {"type": "string", "description": "Python code to execute"},
             }, "required": ["code"]}),

        # ── Backend / API ──
        Tool(name="check_backend",
             description="Check if the backend is running (local and/or live on DO) and get health status.",
             inputSchema={"type": "object", "properties": {
                 "target": {"type": "string",
                            "description": "'live' (DO), 'local' (localhost:8000), or 'both' (default)"},
             }}),

        Tool(name="call_api",
             description="Call any endpoint on the live or local backend API.",
             inputSchema={"type": "object", "properties": {
                 "method":  {"type": "string", "description": "GET or POST"},
                 "path":    {"type": "string", "description": "e.g. /health or /session/upcoming"},
                 "body":    {"type": "object", "description": "JSON body for POST"},
                 "target":  {"type": "string", "description": "'live' or 'local' (default: live)"},
             }, "required": ["path"]}),

        Tool(name="get_backend_errors",
             description="Get the last N lines of the backend error log.",
             inputSchema={"type": "object", "properties": {
                 "lines": {"type": "integer", "description": "Number of lines (default 50)"},
             }}),

        # ── Database ──
        Tool(name="query_db",
             description="Run a SQL SELECT query against the local PostgreSQL database.",
             inputSchema={"type": "object", "properties": {
                 "sql":    {"type": "string",  "description": "SELECT query"},
                 "limit":  {"type": "integer", "description": "Max rows (default 20)"},
             }, "required": ["sql"]}),

        Tool(name="db_stats",
             description="Row counts for all tables. Quick way to see if data exists.",
             inputSchema={"type": "object", "properties": {}}),

        # ── Git / Deploy ──
        Tool(name="git_status",
             description="Get git status, recent commits, and current branch.",
             inputSchema={"type": "object", "properties": {}}),

        Tool(name="git_diff",
             description="Show unstaged or staged changes.",
             inputSchema={"type": "object", "properties": {
                 "staged": {"type": "boolean", "description": "Show staged changes (default: unstaged)"},
                 "file":   {"type": "string",  "description": "Specific file path (optional)"},
             }}),

        Tool(name="check_deployment",
             description="Check the DigitalOcean deployment status and get the live URL.",
             inputSchema={"type": "object", "properties": {}}),
    ]

# ── Handlers ──────────────────────────────────────────────────────────────────
@server.call_tool()
async def call_tool(name: str, arguments: dict):

    # ── Project Understanding ──
    if name == "get_project_context":
        content = _read_file("CLAUDE.md", max_lines=500)
        section = arguments.get("section", "").lower()
        if section:
            # Find the relevant section
            lines = content.splitlines()
            result, capturing, found = [], False, False
            for line in lines:
                if section in line.lower() and line.startswith("#"):
                    capturing = True; found = True
                elif capturing and line.startswith("## ") and section not in line.lower():
                    break
                if capturing:
                    result.append(line)
            content = "\n".join(result) if found else content
        return out({"claude_md": content,
                    "tip": "Read this before writing any code. Key constraints in Section 17."})

    elif name == "get_tasks":
        content = _read_file("TASKS.md", max_lines=300)
        return out({"tasks": content})

    elif name == "get_db_schema":
        table = arguments.get("table")
        if table:
            rows = _db(f"""
                SELECT column_name, data_type, is_nullable, column_default
                FROM information_schema.columns
                WHERE table_name = %s AND table_schema = 'public'
                ORDER BY ordinal_position""", [table])
        else:
            rows = _db("""
                SELECT table_name,
                       (SELECT COUNT(*) FROM information_schema.columns c2
                        WHERE c2.table_name = t.table_name AND c2.table_schema = 'public') AS col_count
                FROM information_schema.tables t
                WHERE table_schema = 'public' ORDER BY table_name""")
        return out(rows)

    # ── Codebase Search ──
    elif name == "read_file":
        p    = arguments["path"]
        ml   = arguments.get("max_lines", 200)
        return out({"path": p, "content": _read_file(p, ml)})

    elif name == "search_code":
        pattern   = arguments["pattern"]
        directory = arguments.get("directory", ".")
        filetype  = arguments.get("file_type", "")
        include   = f"--include='*.{filetype}'" if filetype else ""
        cmd       = f"grep -rn {include} --color=never -m 5 '{pattern}' {directory}"
        r         = _run(cmd)
        return out({"pattern": pattern, "matches": r.get("stdout", ""), "error": r.get("stderr", "")})

    elif name == "list_files":
        directory = arguments.get("directory", ".")
        pattern   = arguments.get("pattern", "*")
        cmd       = f"find {directory} -name '{pattern}' -not -path '*/__pycache__/*' -not -path '*/.git/*' | head -50"
        r         = _run(cmd)
        return out({"files": r.get("stdout", "").strip().splitlines()})

    # ── Running Things ──
    elif name == "run_command":
        cmd = arguments["command"]
        cwd = str(ROOT / arguments["directory"]) if arguments.get("directory") else str(ROOT)
        t   = arguments.get("timeout", 30)
        # Block destructive commands
        blocked = ["rm -rf", "drop table", "delete from", "format", ":(){"]
        if any(b in cmd.lower() for b in blocked):
            return out({"error": f"Blocked dangerous command: {cmd}"})
        return out(_run(cmd, cwd=cwd, timeout=t))

    elif name == "run_python":
        code = arguments["code"]
        # Write to temp file and run in python-api context
        tmp = ROOT / "python-api" / "_mcp_tmp.py"
        tmp.write_text(code)
        r = _run(f"python _mcp_tmp.py", cwd=str(ROOT / "python-api"), timeout=15)
        tmp.unlink(missing_ok=True)
        return out(r)

    # ── Backend / API ──
    elif name == "check_backend":
        target = arguments.get("target", "both")
        result = {}
        if target in ("live", "both"):
            result["live"] = _api("/health")
            result["live_url"] = API_URL
        if target in ("local", "both"):
            result["local"] = _api("/health", local=True)
            result["local_url"] = LOCAL_API
        return out(result)

    elif name == "call_api":
        local  = arguments.get("target", "live") == "local"
        result = _api(arguments["path"], arguments.get("method", "GET"),
                      arguments.get("body"), local=local)
        return out(result)

    elif name == "get_backend_errors":
        lines = arguments.get("lines", 50)
        log   = ROOT / "python-api" / "backend_err.log"
        if log.exists():
            content = log.read_text(encoding="utf-8", errors="replace").splitlines()
            return out({"last_lines": content[-lines:]})
        return out({"error": "backend_err.log not found"})

    # ── Database ──
    elif name == "query_db":
        sql   = arguments["sql"].strip()
        limit = arguments.get("limit", 20)
        if not sql.upper().lstrip().startswith("SELECT"):
            return out({"error": "Only SELECT queries allowed"})
        if "limit" not in sql.lower():
            sql += f" LIMIT {limit}"
        return out(_db(sql))

    elif name == "db_stats":
        tables = _db("""SELECT table_name FROM information_schema.tables
                        WHERE table_schema='public' ORDER BY table_name""")
        counts = {}
        for t in tables:
            name_ = t["table_name"]
            r = _db(f"SELECT COUNT(*) AS n FROM {name_}")
            counts[name_] = r[0].get("n") if r else "err"
        return out(counts)

    # ── Git / Deploy ──
    elif name == "git_status":
        status = _run("git status --short")
        log    = _run("git log --oneline -8")
        branch = _run("git branch --show-current")
        return out({
            "branch":  branch["stdout"].strip(),
            "status":  status["stdout"],
            "recent_commits": log["stdout"],
        })

    elif name == "git_diff":
        staged = arguments.get("staged", False)
        file_  = arguments.get("file", "")
        flag   = "--cached" if staged else ""
        r      = _run(f"git diff {flag} {file_}".strip())
        return out({"diff": r["stdout"][:4000]})

    elif name == "check_deployment":
        DO_TOKEN = os.getenv("DO_TOKEN", "")
        if not DO_TOKEN:
            return out({"note": "Set DO_TOKEN env var to check deployment",
                        "live_url": API_URL,
                        "health": _api("/health")})
        try:
            with httpx.Client(timeout=10) as c:
                r = c.get("https://api.digitalocean.com/v2/apps",
                           headers={"Authorization": f"Bearer {DO_TOKEN}"})
                apps = r.json().get("apps", [])
                for a in apps:
                    if "classroomx" in a.get("spec", {}).get("name", ""):
                        return out({
                            "app_id":  a["id"],
                            "live_url": a.get("live_url"),
                            "phase":   a.get("in_progress_deployment", {}).get("phase") or "ACTIVE",
                            "updated": a.get("updated_at"),
                        })
        except Exception as e:
            return out({"error": str(e)})

    return out({"error": f"Unknown tool: {name}"})

# ── Entry ─────────────────────────────────────────────────────────────────────
async def main():
    async with stdio_server() as (read, write):
        await server.run(read, write, server.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
