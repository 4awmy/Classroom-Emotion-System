import requests
import time
import json

BASE_URL = "http://localhost:8000/api"
SECRET = "kdJTnejv0XYhud5C"

def test_full_ai_cycle():
    print("--- STARTING GEMINI INTEGRATION TEST ---")
    
    # 0. Setup: Ensure database is seeded
    print("[1/6] Seeding database...")
    requests.post(f"{BASE_URL}/internal/seed?x_seed_secret={SECRET}")

    lecture_id = "L_TEST_AI"
    student_id = "231006131" # Omar from prod_seed

    # 1. Start Lecture
    print("[2/6] Starting lecture...")
    requests.post(f"{BASE_URL}/session/start", json={"lecture_id": lecture_id, "lecturer_id": "omar"})

    # 2. Test Refresher
    print("[3/6] Testing AI Refresher...")
    resp = requests.get(f"{BASE_URL}/gemini/refresher?lecture_id={lecture_id}")
    if resp.status_code == 200:
        print(f"  [OK] Refresher generated: {resp.json().get('summary')[:50]}...")
    else:
        print(f"  [FAIL] Refresher failed: {resp.status_code}")

    # 3. Simulate Confusion (Threshold check)
    print("[4/6] Simulating confusion...")
    for i in range(5):
        requests.post(f"{BASE_URL}/emotion/log", json={
            "student_id": student_id,
            "lecture_id": lecture_id,
            "emotion": "Confused",
            "confidence": 0.9,
            "engagement_score": 0.1
        })
    print("  [OK] Confusion logs sent.")

    # 4. Generate Comprehension Check
    print("[5/6] Generating AI Quiz...")
    resp = requests.post(f"{BASE_URL}/gemini/check/generate?lecture_id={lecture_id}")
    if resp.status_code == 200:
        check_data = resp.json()
        check_id = check_data['id']
        topic = check_data['topic']
        print(f"  [OK] Quiz generated (Topic: {topic}): {check_data['question']}")
        
        # Submit WRONG answer
        print("  - Submitting WRONG answer...")
        requests.post(f"{BASE_URL}/gemini/check/submit", params={
            "check_id": check_id,
            "student_id": student_id,
            "chosen_option": (check_data.get('correct_option', 0) + 1) % 3
        })
    else:
        print(f"  [FAIL] Quiz generation failed: {resp.status_code}")

    # 5. Verify Personalized Notes
    print("[6/6] Verifying Personalized Notes...")
    resp = requests.get(f"{BASE_URL}/notes/{student_id}/{lecture_id}")
    if resp.status_code == 200:
        notes = resp.json().get('markdown', '')
        if "*" in notes:
            print("  [OK] Smart notes generated with re-explanation markers (*)")
        else:
            print("  [WARN] Smart notes generated but missing markers. Check Gemini prompt.")
        print(f"  - Snippet: {notes[:100]}...")
    else:
        print(f"  [FAIL] Notes failed: {resp.status_code}")

    print("--- TEST CYCLE COMPLETE ---")

if __name__ == "__main__":
    try:
        test_full_ai_cycle()
    except Exception as e:
        print(f"FATAL TEST ERROR: {e}")
