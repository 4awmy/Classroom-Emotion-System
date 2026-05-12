"""
Demo Seed Script — AAST LMS
Populates the database with the exact accounts and data needed for the demo.
Run this ONCE before the demo. Safe to re-run (skips existing records).

Usage:
    python scripts/seed_demo.py [--api https://classroomx-lkbxf.ondigitalocean.app]
"""

import sys
import json
import urllib.request
import urllib.error
import argparse

DEFAULT_API  = "https://classroomx-lkbxf.ondigitalocean.app"
MASTER_PASS  = "aast2026"

# ── HTTP helpers ──────────────────────────────────────────────────────────────

def call(method, path, body=None, token=None, base=DEFAULT_API):
    url  = f"{base}/api{path}"
    data = json.dumps(body).encode() if body else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        msg = e.read().decode()
        # 400 = already exists → treat as OK
        if e.code == 400 and ("already" in msg or "exists" in msg):
            print(f"    (already exists – skipping)")
            return {"_skipped": True}
        print(f"    HTTP {e.code} on {method} {path}: {msg[:200]}")
        return None
    except Exception as ex:
        print(f"    Error on {method} {path}: {ex}")
        return None


def login(user_id, password, base):
    res = call("POST", "/auth/login",
               {"user_id": user_id, "password": password}, base=base)
    if res and res.get("access_token"):
        return res["access_token"]
    return None


def step(label, res):
    if res is not None:
        print(f"  ✓  {label}")
        return True
    print(f"  ✗  {label}  ← FAILED")
    return False


# ── Seed ──────────────────────────────────────────────────────────────────────

def seed(base):
    print(f"\n{'='*60}")
    print(" AAST LMS — Demo Seed Script")
    print(f" Target: {base}")
    print(f"{'='*60}\n")

    # Health check
    health = call("GET", "/health", base=base)
    if not health or health.get("status") != "ok":
        print("✗  API not reachable. Check the URL and try again.\n")
        sys.exit(1)
    print(f"✓  API reachable  (v{health.get('version', '?')})\n")

    # ── Get admin token ──────────────────────────────────────────────────────
    print("Step 1 — Get admin token")
    token = login("admin", MASTER_PASS, base)
    if not token:
        # DB might be empty — trigger the seed endpoint
        print("  admin login failed, triggering /internal/seed ...")
        call("POST", "/internal/seed?x_seed_secret=" + MASTER_PASS, base=base)
        token = login("admin", MASTER_PASS, base)
    if not token:
        print("✗  Cannot obtain admin token. Aborting.")
        sys.exit(1)
    print("  ✓  Token obtained\n")

    # ── Create admin omar ────────────────────────────────────────────────────
    print("Step 2 — Admin user: omar")
    step("omar created/exists", call(
        "POST", "/admin/admins",
        {"admin_id": "omar",
         "name":     "Omar Metwall",
         "email":    "omar@aast.edu",
         "password": MASTER_PASS},
        token=token, base=base
    ))

    # ── Create lecturer mohamedfathy ─────────────────────────────────────────
    print("\nStep 3 — Lecturer: mohamedfathy")
    step("mohamedfathy created/exists", call(
        "POST", "/admin/lecturers",
        {"lecturer_id": "mohamedfathy",
         "name":        "Mohamed Fathy",
         "email":       "m.fathy@aast.edu",
         "department":  "Computer Science",
         "password":    MASTER_PASS},
        token=token, base=base
    ))

    # ── Create student 231006131 ─────────────────────────────────────────────
    print("\nStep 4 — Student: 231006131")
    step("231006131 created/exists", call(
        "POST", "/admin/students",
        {"student_id": "231006131",
         "name":       "Omar Metwall",
         "email":      "231006131@student.aast.edu",
         "password":   MASTER_PASS},
        token=token, base=base
    ))

    # ── Create course STAT401 ────────────────────────────────────────────────
    print("\nStep 5 — Course: STAT401")
    step("STAT401 created/exists", call(
        "POST", "/courses/",
        {"course_id":    "STAT401",
         "title":        "Advanced Statistics",
         "department":   "Computer Science",
         "credit_hours": 3,
         "semester":     "Spring 2026"},
        token=token, base=base
    ))

    # ── Create class section STAT401-A ───────────────────────────────────────
    print("\nStep 6 — Class section: STAT401-A (lecturer = mohamedfathy)")
    step("STAT401-A created/exists", call(
        "POST", "/courses/classes",
        {"class_id":      "STAT401-A",
         "course_id":     "STAT401",
         "lecturer_id":   "mohamedfathy",
         "section_name":  "Section A",
         "semester":      "Spring 2026"},
        token=token, base=base
    ))

    # ── Enroll student ───────────────────────────────────────────────────────
    print("\nStep 7 — Enroll 231006131 in STAT401-A")
    step("Enrollment created/exists", call(
        "POST", "/courses/enrollments",
        {"student_id": "231006131",
         "class_id":   "STAT401-A"},
        token=token, base=base
    ))

    # ── Verify all logins ────────────────────────────────────────────────────
    print("\nStep 8 — Verify all demo logins")
    all_ok = True
    for uid, role in [("omar", "admin"), ("mohamedfathy", "lecturer"), ("231006131", "student")]:
        t = login(uid, MASTER_PASS, base)
        ok = t is not None
        all_ok = all_ok and ok
        print(f"  {'✓' if ok else '✗'}  {uid} ({role}) — {'OK' if ok else 'FAILED'}")

    # ── Summary ──────────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    if all_ok:
        print(" ✅  SEED COMPLETE — system is ready for demo")
    else:
        print(" ⚠   SEED DONE WITH WARNINGS — check failures above")
    print(f"{'='*60}")
    print()
    print(" DEMO CREDENTIALS")
    print(f" {'─'*40}")
    print(f"  Admin    │ omar          │ {MASTER_PASS}")
    print(f"  Lecturer │ mohamedfathy  │ {MASTER_PASS}")
    print(f"  Student  │ 231006131     │ {MASTER_PASS}")
    print(f" {'─'*40}")
    print(f"  Course   : STAT401 — Advanced Statistics")
    print(f"  Class    : STAT401-A (assigned to mohamedfathy)")
    print(f"  Student enrolled: 231006131\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed demo data for AAST LMS")
    parser.add_argument("--api", default=DEFAULT_API, help="Base API URL (no trailing slash)")
    args = parser.parse_args()
    seed(args.api.rstrip("/"))
