import os
import sys
import json
import yaml
import urllib.request

# Config
TOKEN = os.getenv("DO_TOKEN")
APP_NAME = "classroomx"
SPEC_FILE = "app.yaml"

if not TOKEN:
    print("[ERROR] Set DO_TOKEN env var.")
    sys.exit(1)

def get_app_id():
    url = "https://api.digitalocean.com/v2/apps"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {TOKEN}"})
    with urllib.request.urlopen(req) as res:
        apps = json.loads(res.read())["apps"]
        for app in apps:
            if app["spec"]["name"] == APP_NAME:
                return app["id"]
    return None

def update_app_spec(app_id):
    print(f"[SYNC] Loading spec from {SPEC_FILE}...")
    with open(SPEC_FILE, "r") as f:
        spec = yaml.safe_load(f)
    
    url = f"https://api.digitalocean.com/v2/apps/{app_id}"
    data = json.dumps({"spec": spec}).encode()
    
    req = urllib.request.Request(url, data=data, method="PUT", headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json"
    })
    
    print(f"[SYNC] Updating app {app_id} on DigitalOcean...")
    try:
        with urllib.request.urlopen(req) as res:
            result = json.loads(res.read())
            print("[SUCCESS] App spec updated. DigitalOcean is now redeploying with the Shiny Portal!")
            print(f"  Deployment ID: {result['app']['active_deployment']['id']}")
    except urllib.error.HTTPError as e:
        print(f"[ERROR] Failed to update spec: {e.read().decode()}")

if __name__ == "__main__":
    aid = get_app_id()
    if aid:
        update_app_spec(aid)
    else:
        print(f"[ERROR] App '{APP_NAME}' not found.")
