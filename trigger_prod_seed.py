import urllib.request
import json
import time

URL = "https://classroomx-lkbxf.ondigitalocean.app/api/internal/seed"
SECRET = "aast-lms-secret-2026"

def seed():
    print(f"[SEED] Triggering production database seed at {URL}...")
    req = urllib.request.Request(f"{URL}?x_seed_secret={SECRET}", method="POST")
    
    for i in range(10):
        try:
            with urllib.request.urlopen(req) as res:
                result = json.loads(res.read())
                print("[SUCCESS] Database seeded successfully!")
                print(f"  Tables: {result['tables']}")
                print(f"  Counts: {result['counts']}")
                return
        except Exception as e:
            print(f"[RETRY {i+1}/10] Backend not ready yet or error: {e}")
            time.sleep(30)

if __name__ == "__main__":
    seed()
