#!/usr/bin/env python3
"""
AAST Classroom Emotion System — MCP Server
Exposes project data and controls to Claude, Gemini CLI, and Codex.

Usage:
    python mcp_server/server.py

Config (env vars or .env):
    API_URL       = https://classroomx-lkbxf.ondigitalocean.app  (live)
                  or http://localhost:8000 (local)
    DATABASE_URL  = postgresql://postgres:password123@localhost:5432/classroom_emotions
"""

import os, json, asyncio
from dotenv import load_dotenv
import httpx
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

load_dotenv()

API_URL      = os.getenv("API_URL", "https://classroomx-lkbxf.ondigitalocean.app")
DATABASE_URL = os.getenv("DATABASE_URL") or os.getenv("LOCAL_DATABASE_URL",
               "postgresql://postgres:password123@localhost:5432/classroom_emotions")

server = Server("aast-lms")

# ── DB helper (optional — only works if psycopg2 installed) ──────────────────
def _db_query(sql: str, params=None) -> list[dict]:
    try:
        import psycopg2, psycopg2.extras
        conn = psycopg2.connect(DATABASE_URL)
        cur  = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute(sql, params or ())
        rows = [dict(r) for r in cur.fetchall()]
        conn.close()
        return rows
    except Exception as e:
        return [{"error": str(e)}]

def _api(method: str, path: str, body: dict | None = None) -> dict:
    try:
        with httpx.Client(base_url=API_URL, timeout=15) as client:
            fn = getattr(client, method.lower())
            r  = fn(path, json=body) if body else fn(path)
            return r.json()
    except Exception as e:
        return {"error": str(e)}

# ── Tool definitions ──────────────────────────────────────────────────────────
@server.list_tools()
async def list_tools():
    return [
        Tool(name="health_check",
             description="Check if the live backend API is running.",
             inputSchema={"type": "object", "properties": {}}),

        Tool(name="get_table_stats",
             description="Row counts for every table in the database.",
             inputSchema={"type": "object", "properties": {}}),

        Tool(name="get_students",
             description="List students. Optional filter by name/department.",
             inputSchema={"type": "object", "properties": {
                 "search":     {"type": "string",  "description": "Name fragment to filter"},
                 "department": {"type": "string",  "description": "Filter by department"},
                 "limit":      {"type": "integer", "description": "Max rows (default 20)"},
             }}),

        Tool(name="get_recent_emotions",
             description="Get the most recent emotion log entries.",
             inputSchema={"type": "object", "properties": {
                 "lecture_id": {"type": "string",  "description": "Filter by lecture ID"},
                 "student_id": {"type": "string",  "description": "Filter by student ID"},
                 "limit":      {"type": "integer", "description": "Max rows (default 30)"},
             }}),

        Tool(name="get_attendance",
             description="Get attendance records for a lecture or student.",
             inputSchema={"type": "object", "properties": {
                 "lecture_id": {"type": "string"},
                 "student_id": {"type": "string"},
                 "limit":      {"type": "integer"},
             }}),

        Tool(name="get_engagement_summary",
             description="Average engagement score per student for a lecture.",
             inputSchema={"type": "object", "properties": {
                 "lecture_id": {"type": "string", "description": "Lecture ID (required)"},
             }, "required": ["lecture_id"]}),

        Tool(name="get_lectures",
             description="List lectures. Shows title, start/end time, and class.",
             inputSchema={"type": "object", "properties": {
                 "limit": {"type": "integer", "description": "Max rows (default 10)"},
             }}),

        Tool(name="run_sql",
             description="Run a read-only SQL SELECT query directly against the database. Use for custom analysis.",
             inputSchema={"type": "object", "properties": {
                 "query": {"type": "string", "description": "SQL SELECT statement"},
             }, "required": ["query"]}),

        Tool(name="call_api",
             description="Call any FastAPI endpoint on the live backend.",
             inputSchema={"type": "object", "properties": {
                 "method": {"type": "string",  "description": "GET or POST"},
                 "path":   {"type": "string",  "description": "e.g. /session/upcoming"},
                 "body":   {"type": "object",  "description": "Request body for POST"},
             }, "required": ["method", "path"]}),

        Tool(name="get_incidents",
             description="Get exam proctoring incidents (phone, head rotation, etc).",
             inputSchema={"type": "object", "properties": {
                 "student_id": {"type": "string"},
                 "exam_id":    {"type": "string"},
                 "limit":      {"type": "integer"},
             }}),

        Tool(name="get_confused_students",
             description="Find students with confusion/frustration rate above a threshold in a lecture.",
             inputSchema={"type": "object", "properties": {
                 "lecture_id": {"type": "string",  "description": "Lecture ID"},
                 "threshold":  {"type": "number",  "description": "Min confusion rate 0-1 (default 0.3)"},
             }, "required": ["lecture_id"]}),
    ]

# ── Tool handlers ─────────────────────────────────────────────────────────────
@server.call_tool()
async def call_tool(name: str, arguments: dict):
    def out(data):
        return [TextContent(type="text", text=json.dumps(data, indent=2, default=str))]

    if name == "health_check":
        return out(_api("GET", "/health"))

    elif name == "get_table_stats":
        tables = ["students","lecturers","lectures","emotion_log",
                  "attendance_log","classes","incidents","focus_strikes",
                  "materials","notifications","admins"]
        counts = {}
        for t in tables:
            rows = _db_query(f"SELECT COUNT(*) AS n FROM {t}")
            counts[t] = rows[0].get("n", "err") if rows else "err"
        return out(counts)

    elif name == "get_students":
        limit  = arguments.get("limit", 20)
        search = arguments.get("search", "")
        dept   = arguments.get("department", "")
        sql    = "SELECT student_id, name, email, department, year FROM students WHERE 1=1"
        params = []
        if search:
            sql += " AND name ILIKE %s"; params.append(f"%{search}%")
        if dept:
            sql += " AND department ILIKE %s"; params.append(f"%{dept}%")
        sql += f" LIMIT {int(limit)}"
        return out(_db_query(sql, params))

    elif name == "get_recent_emotions":
        limit      = arguments.get("limit", 30)
        lecture_id = arguments.get("lecture_id")
        student_id = arguments.get("student_id")
        sql = """SELECT e.student_id, s.name, e.lecture_id, e.timestamp,
                        e.emotion, e.confidence, e.engagement_score
                 FROM emotion_log e JOIN students s USING(student_id)
                 WHERE 1=1"""
        params = []
        if lecture_id:
            sql += " AND e.lecture_id = %s"; params.append(lecture_id)
        if student_id:
            sql += " AND e.student_id = %s"; params.append(student_id)
        sql += f" ORDER BY e.timestamp DESC LIMIT {int(limit)}"
        return out(_db_query(sql, params))

    elif name == "get_attendance":
        limit      = arguments.get("limit", 50)
        lecture_id = arguments.get("lecture_id")
        student_id = arguments.get("student_id")
        sql = """SELECT a.student_id, s.name, a.lecture_id,
                        a.timestamp, a.status, a.method
                 FROM attendance_log a JOIN students s USING(student_id)
                 WHERE 1=1"""
        params = []
        if lecture_id:
            sql += " AND a.lecture_id = %s"; params.append(lecture_id)
        if student_id:
            sql += " AND a.student_id = %s"; params.append(student_id)
        sql += f" ORDER BY a.timestamp DESC LIMIT {int(limit)}"
        return out(_db_query(sql, params))

    elif name == "get_engagement_summary":
        lid = arguments["lecture_id"]
        sql = """SELECT e.student_id, s.name,
                        ROUND(AVG(e.engagement_score)::numeric, 3) AS avg_engagement,
                        MODE() WITHIN GROUP (ORDER BY e.emotion) AS dominant_emotion,
                        COUNT(*) AS observations
                 FROM emotion_log e JOIN students s USING(student_id)
                 WHERE e.lecture_id = %s
                 GROUP BY e.student_id, s.name
                 ORDER BY avg_engagement DESC"""
        return out(_db_query(sql, [lid]))

    elif name == "get_lectures":
        limit = arguments.get("limit", 10)
        sql = """SELECT l.lecture_id, l.title, l.lecturer_id,
                        lec.name AS lecturer_name,
                        l.start_time, l.end_time, l.session_type
                 FROM lectures l
                 LEFT JOIN lecturers lec ON l.lecturer_id = lec.lecturer_id
                 ORDER BY l.start_time DESC LIMIT %s"""
        return out(_db_query(sql, [int(limit)]))

    elif name == "run_sql":
        q = arguments.get("query", "").strip()
        if not q.upper().startswith("SELECT"):
            return out({"error": "Only SELECT queries allowed"})
        return out(_db_query(q))

    elif name == "call_api":
        method = arguments.get("method", "GET")
        path   = arguments.get("path", "/health")
        body   = arguments.get("body")
        return out(_api(method, path, body))

    elif name == "get_incidents":
        limit      = arguments.get("limit", 20)
        student_id = arguments.get("student_id")
        exam_id    = arguments.get("exam_id")
        sql = """SELECT i.id, i.student_id, s.name, i.exam_id,
                        i.timestamp, i.flag_type, i.severity
                 FROM incidents i LEFT JOIN students s USING(student_id)
                 WHERE 1=1"""
        params = []
        if student_id:
            sql += " AND i.student_id = %s"; params.append(student_id)
        if exam_id:
            sql += " AND i.exam_id = %s"; params.append(exam_id)
        sql += f" ORDER BY i.timestamp DESC LIMIT {int(limit)}"
        return out(_db_query(sql, params))

    elif name == "get_confused_students":
        lid       = arguments["lecture_id"]
        threshold = arguments.get("threshold", 0.3)
        sql = """SELECT e.student_id, s.name,
                        ROUND(AVG(CASE WHEN e.emotion IN ('Confused','Frustrated') THEN 1.0 ELSE 0.0 END)::numeric, 3) AS confusion_rate,
                        ROUND(AVG(e.engagement_score)::numeric, 3) AS avg_engagement,
                        COUNT(*) AS observations
                 FROM emotion_log e JOIN students s USING(student_id)
                 WHERE e.lecture_id = %s
                 GROUP BY e.student_id, s.name
                 HAVING AVG(CASE WHEN e.emotion IN ('Confused','Frustrated') THEN 1.0 ELSE 0.0 END) >= %s
                 ORDER BY confusion_rate DESC"""
        return out(_db_query(sql, [lid, float(threshold)]))

    return out({"error": f"Unknown tool: {name}"})

# ── Entry point ───────────────────────────────────────────────────────────────
async def main():
    async with stdio_server() as (read, write):
        await server.run(read, write, server.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
