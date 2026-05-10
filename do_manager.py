#!/usr/bin/env python3
"""
DigitalOcean Manager — AAST Classroom Emotion System
Usage:
    python do_manager.py deploy       # Create app on DO (first time)
    python do_manager.py status       # Show app + service health
    python do_manager.py logs backend # Stream logs for a component
    python do_manager.py logs frontend
    python do_manager.py redeploy     # Trigger new deployment
    python do_manager.py seed-db      # Import prod_seed.sql into DO managed DB
    python do_manager.py urls         # Print all live URLs
    python do_manager.py destroy      # Delete the app (careful!)
"""

import sys, os, json, time, subprocess, textwrap
import urllib.request, urllib.error

# ── Config ──────────────────────────────────────────────────────────────────
TOKEN    = os.getenv("DO_TOKEN", "")
if not TOKEN:
    print("[ERROR] Set DO_TOKEN env var: set DO_TOKEN=dop_v1_...")
    sys.exit(1)
APP_NAME = "classroom-emotion-system"
STATE_FILE = ".do_state.json"   # caches app_id so you don't have to look it up
BASE = "https://api.digitalocean.com/v2"

# ── App spec ─────────────────────────────────────────────────────────────────
APP_SPEC = {
    "name": APP_NAME,
    "region": "nyc",
    "services": [
        {
            "name": "backend",
            "github": {
                "repo": "4awmy/Classroom-Emotion-System",
                "branch": "deploy-ready",
                "deploy_on_push": True
            },
            "dockerfile_path": "python-api/Dockerfile",
            "source_dir": "python-api",
            "http_port": 8000,
            "instance_count": 1,
            "instance_size_slug": "basic-xxs",
            "routes": [{"path": "/"}],
            "health_check": {
                "http_path": "/health",
                "initial_delay_seconds": 30,
                "period_seconds": 30,
                "failure_threshold": 3
            },
            "envs": [
                {"key": "DATABASE_URL",   "scope": "RUN_TIME", "value": "${db.DATABASE_URL}"},
                {"key": "GEMINI_API_KEY", "scope": "RUN_TIME", "type": "SECRET", "value": ""},
                {"key": "JWT_SECRET",     "scope": "RUN_TIME", "type": "SECRET", "value": "aast-lms-jwt-secret-2026"},
                {"key": "ENVIRONMENT",    "scope": "RUN_TIME", "value": "production"},
                {"key": "SPACES_REGION",  "scope": "RUN_TIME", "value": "nyc3"},
                {"key": "SPACES_ENDPOINT","scope": "RUN_TIME", "value": "https://nyc3.digitaloceanspaces.com"},
            ]
        },
        {
            "name": "frontend",
            "github": {
                "repo": "4awmy/Classroom-Emotion-System",
                "branch": "deploy-ready",
                "deploy_on_push": True
            },
            "source_dir": "shiny-app",
            "dockerfile_path": "shiny-app/Dockerfile",
            "http_port": 3838,
            "instance_count": 1,
            "instance_size_slug": "basic-xxs",
            "routes": [{"path": "/portal", "preserve_path_prefix": True}],
            "envs": [
                {"key": "API_URL", "scope": "RUN_TIME", "value": "${backend.PUBLIC_URL}"},
            ]
        }
    ],
    "databases": [
        {
            "name": "db",
            "engine": "PG",
            "version": "15",
            "size": "db-s-dev-database",
            "num_nodes": 1
        }
    ]
}

# ── HTTP helpers ─────────────────────────────────────────────────────────────
def _req(method, path, body=None):
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read()) if r.length != 0 else {}
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        print(f"[ERROR] {method} {path} -> {e.code}: {err}")
        sys.exit(1)

def _get(path):    return _req("GET", path)
def _post(path, body): return _req("POST", path, body)
def _put(path, body):  return _req("PUT", path, body)
def _delete(path): return _req("DELETE", path)

# ── State persistence ─────────────────────────────────────────────────────────
def save_state(data):
    with open(STATE_FILE, "w") as f:
        json.dump(data, f, indent=2)

def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {}

def get_app_id():
    state = load_state()
    if "app_id" in state:
        return state["app_id"]
    # Try to find by name
    apps = _get("/apps").get("apps", [])
    for a in apps:
        if a.get("spec", {}).get("name") == APP_NAME:
            save_state({"app_id": a["id"]})
            return a["id"]
    print("[ERROR] App not found. Run: python do_manager.py deploy")
    sys.exit(1)

# ── Commands ─────────────────────────────────────────────────────────────────
def cmd_deploy():
    print(f"[DEPLOY] Creating app '{APP_NAME}' on DigitalOcean...")
    # Check if already exists
    apps = _get("/apps").get("apps", [])
    for a in apps:
        if a.get("spec", {}).get("name") == APP_NAME:
            print(f"[DEPLOY] App already exists: {a['id']}")
            print("[DEPLOY] Use 'redeploy' to trigger a new build.")
            save_state({"app_id": a["id"]})
            return

    result = _post("/apps", {"spec": APP_SPEC})
    app = result.get("app", {})
    app_id = app.get("id")
    print(f"[DEPLOY] App created! ID: {app_id}")
    save_state({"app_id": app_id})

    print("\n[DEPLOY] Waiting for initial build (this takes 5-10 min)...")
    _wait_for_active(app_id)

def cmd_status():
    app_id = get_app_id()
    app = _get(f"/apps/{app_id}").get("app", {})

    phase   = app.get("last_deployment_active_at", "unknown")
    live_url= app.get("live_url", "not yet")
    print(f"\n{'='*55}")
    print(f"  App: {APP_NAME}")
    print(f"  ID:  {app_id}")
    print(f"  URL: {live_url}")
    print(f"{'='*55}")

    deployment = app.get("in_progress_deployment") or app.get("active_deployment") or {}
    dep_phase = deployment.get("phase", "unknown")
    print(f"  Deployment phase: {dep_phase}")

    for svc in app.get("spec", {}).get("services", []):
        name = svc["name"]
        print(f"  Service: {name}")

    # DB info
    for db in app.get("spec", {}).get("databases", []):
        print(f"  Database: {db['name']} ({db['engine']} {db.get('version','')})")

    print()
    # Health check via HTTP
    if live_url and live_url != "not yet":
        try:
            req = urllib.request.Request(f"{live_url}/health",
                headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=10) as r:
                body = json.loads(r.read())
                print(f"  /health → {body}")
        except Exception as e:
            print(f"  /health → UNREACHABLE ({e})")

def cmd_logs(component="backend"):
    app_id = get_app_id()
    print(f"[LOGS] Fetching logs for component: {component}")
    result = _get(f"/apps/{app_id}/logs?component_name={component}&type=RUN&follow=false")
    url = result.get("live_url") or result.get("url") or ""
    if url:
        print(f"[LOGS] Streaming from: {url}")
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as r:
            while True:
                line = r.readline()
                if not line:
                    break
                print(line.decode("utf-8", errors="replace"), end="")
    else:
        # Fallback: print what we got
        print(json.dumps(result, indent=2))

def cmd_redeploy():
    app_id = get_app_id()
    print(f"[REDEPLOY] Triggering new deployment for {app_id}...")
    result = _post(f"/apps/{app_id}/deployments", {})
    dep = result.get("deployment", {})
    print(f"[REDEPLOY] Deployment ID: {dep.get('id')}")
    print(f"[REDEPLOY] Phase: {dep.get('phase')}")
    _wait_for_active(app_id)

def cmd_urls():
    app_id = get_app_id()
    app = _get(f"/apps/{app_id}").get("app", {})
    live = app.get("live_url", "not deployed yet")
    print(f"\n  Backend (API):  {live}")
    print(f"  API Docs:       {live}/docs")
    print(f"  Health:         {live}/health")
    # Frontend is on a different subdomain
    for svc in app.get("spec", {}).get("services", []):
        if svc["name"] == "frontend":
            print(f"  Shiny Portal:   check DO dashboard for frontend URL")

def cmd_seed_db():
    """Import prod_seed.sql into the DO managed database."""
    seed_file = "prod_seed.sql"
    if not os.path.exists(seed_file):
        print(f"[ERROR] {seed_file} not found. Run from project root.")
        sys.exit(1)

    app_id = get_app_id()
    app = _get(f"/apps/{app_id}").get("app", {})

    # Find the DB cluster ID from the app
    db_info = app.get("active_deployment", {}).get("spec", {}) or app.get("spec", {})
    print("[SEED] Looking for managed DB connection...")

    # Get all databases in the account
    dbs = _get("/databases").get("databases", [])
    target_db = None
    for db in dbs:
        if APP_NAME in db.get("name", "") or "db" in db.get("name", ""):
            target_db = db
            break

    if not target_db:
        print("[SEED] Available databases:")
        for db in dbs:
            print(f"       {db['id']} — {db['name']}")
        print("[SEED] Could not auto-detect DB. Copy a connection string above and run:")
        print(f"       psql \"<connection_string>\" < {seed_file}")
        return

    conn = target_db.get("connection", {})
    uri = conn.get("uri", "")
    print(f"[SEED] Found DB: {target_db['name']} ({target_db['id']})")
    print(f"[SEED] Importing {seed_file} ({os.path.getsize(seed_file)//1024} KB)...")

    # psql import
    env = os.environ.copy()
    env["PGPASSWORD"] = conn.get("password", "")
    proc = subprocess.run(
        ["psql", uri, "-f", seed_file],
        env=env, capture_output=True, text=True
    )
    if proc.returncode == 0:
        print("[SEED] Import successful!")
    else:
        print("[SEED] psql output:")
        print(proc.stdout[-2000:])
        print(proc.stderr[-2000:])

def cmd_destroy():
    app_id = get_app_id()
    confirm = input(f"Delete app {APP_NAME} ({app_id})? This is irreversible. Type YES: ")
    if confirm.strip() != "YES":
        print("Cancelled.")
        return
    _delete(f"/apps/{app_id}")
    os.remove(STATE_FILE)
    print("[DESTROY] App deleted.")

# ── Helpers ──────────────────────────────────────────────────────────────────
def _wait_for_active(app_id, timeout=900):
    print("[WAIT] Polling deployment status", end="", flush=True)
    deadline = time.time() + timeout
    while time.time() < deadline:
        app = _get(f"/apps/{app_id}").get("app", {})
        dep = app.get("in_progress_deployment") or app.get("active_deployment") or {}
        phase = dep.get("phase", "UNKNOWN")
        if phase in ("ACTIVE", "DEPLOYED"):
            print(f"\n[WAIT] Deployed! Live URL: {app.get('live_url','?')}")
            return
        if phase in ("ERROR", "FAILED", "CANCELED"):
            print(f"\n[WAIT] Deployment failed: {phase}")
            print("Run: python do_manager.py logs backend")
            return
        print(".", end="", flush=True)
        time.sleep(20)
    print("\n[WAIT] Timed out waiting for deployment.")

# ── Entry point ───────────────────────────────────────────────────────────────
COMMANDS = {
    "deploy":   cmd_deploy,
    "status":   cmd_status,
    "redeploy": cmd_redeploy,
    "urls":     cmd_urls,
    "seed-db":  cmd_seed_db,
    "destroy":  cmd_destroy,
    "logs":     lambda: cmd_logs(sys.argv[2] if len(sys.argv) > 2 else "backend"),
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(textwrap.dedent(__doc__))
        sys.exit(0)
    COMMANDS[sys.argv[1]]()
