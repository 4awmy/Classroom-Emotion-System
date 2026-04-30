import requests
import os
import sys

file_path = r'C:\Users\omarh\projects\Classroom-Emotion-System\StudentPicsDataset.xlsx'
url = 'http://localhost:8000/roster/upload'

print(f"Starting upload of {file_path} to {url}...")
try:
    with open(file_path, 'rb') as f:
        files = {'roster_xlsx': f}
        # Using a long timeout for the requests call
        response = requests.post(url, files=files, timeout=1200) 
        print(f"Status Code: {response.status_code}")
        try:
            print(f"Response Body: {response.json()}")
        except:
            print(f"Raw Response: {response.text}")
except Exception as e:
    print(f"Upload failed with error: {e}")
    sys.exit(1)
