import sqlite3
import os
from passlib.context import CryptContext

db_path = 'python-api/data/classroom_v2.db'
if not os.path.exists(db_path):
    print(f"Error: {db_path} not found")
    exit(1)

conn = sqlite3.connect(db_path)
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

# Check 'omar'
user = conn.execute("SELECT lecturer_id, password_hash FROM lecturers WHERE lecturer_id='omar'").fetchone()
if user:
    print(f"User: {user[0]}")
    print(f"Stored Hash: {user[1]}")
    
    # Let's force update the password to '123' just to be safe
    new_hash = pwd_context.hash("123")
    conn.execute("UPDATE lecturers SET password_hash=? WHERE lecturer_id='omar'", (new_hash,))
    conn.commit()
    print("SUCCESS: Password for 'omar' has been reset to '123' with valid hashing.")
else:
    print("User 'omar' not found.")

conn.close()
