import requests
import json
import sys

BASE_URL = "http://127.0.0.1:8000"

def test_endpoint(method, path, data=None, params=None):
    url = f"{BASE_URL}{path}"
    try:
        if method == "GET":
            response = requests.get(url, params=params)
        elif method == "POST":
            response = requests.post(url, json=data, params=params)
        
        status = response.status_code
        print(f"{method} {path} -> {status}")
        if status != 200:
            print(f"  Error: {response.text}")
        return status == 200
    except Exception as e:
        print(f"{method} {path} -> FAILED: {e}")
        return False

def run_tests():
    print("Starting API tests...")
    results = []
    
    # GET Endpoints
    results.append(test_endpoint("GET", "/health"))
    results.append(test_endpoint("GET", "/emotion/live", params={"lecture_id": "L001"}))
    results.append(test_endpoint("GET", "/emotion/confusion-rate", params={"lecture_id": "L001"}))
    results.append(test_endpoint("GET", "/attendance/qr/L001"))
    results.append(test_endpoint("GET", "/attendance/lecture/L001"))
    results.append(test_endpoint("GET", "/attendance/snapshot/L001/S001"))
    results.append(test_endpoint("GET", "/roster/students"))
    results.append(test_endpoint("GET", "/session/upcoming"))
    results.append(test_endpoint("GET", "/notes/S001/L001"))
    results.append(test_endpoint("GET", "/exam/incidents/E001"))
    
    # POST Endpoints
    results.append(test_endpoint("POST", "/session/start", data={
        "lecture_id": "L002",
        "lecturer_id": "T001",
        "title": "Test Lecture",
        "slide_url": "http://example.com/slides"
    }))
    
    results.append(test_endpoint("POST", "/session/broadcast", data={
        "type": "freshbrainer",
        "question": "What is 2+2?",
        "lecture_id": "L002"
    }))
    
    results.append(test_endpoint("POST", "/attendance/manual", data=[
        {"student_id": "S001", "lecture_id": "L002", "status": "Present"}
    ]))
    
    results.append(test_endpoint("POST", "/exam/start", params={"exam_id": "E002"}))
    
    results.append(test_endpoint("POST", "/gemini/question", data={
        "student_id": "S001",
        "lecture_id": "L001",
        "question": "Can you explain the last slide?"
    }))
    
    results.append(test_endpoint("POST", "/session/end", data={"lecture_id": "L002"}))

    success_count = sum(1 for r in results if r)
    total_count = len(results)
    print(f"\nTests completed: {success_count}/{total_count} passed")
    
    if success_count < total_count:
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
