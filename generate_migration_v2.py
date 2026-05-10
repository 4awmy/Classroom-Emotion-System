import re
import uuid
from anyascii import anyascii
import os

def transliterate_name(name):
    trans = anyascii(name).strip()
    trans = re.sub(r'\s+', ' ', trans)
    return trans.title()

def generate_student_email(name, student_id):
    english_name = transliterate_name(name)
    first_initial = english_name[0].lower() if english_name else 's'
    clean_id = student_id.replace('.0', '')
    return f"{first_initial}{clean_id}@aast.com"

def process_file(file_path, encoding):
    updates = []
    if not os.path.exists(file_path):
        print(f"{file_path} not found")
        return updates
    
    with open(file_path, 'rb') as f:
        raw = f.read()
        try:
            content = raw.decode(encoding)
        except Exception as e:
            print(f"Failed to decode {file_path} with {encoding}: {e}")
            return updates

    # Students
    if 'students' in file_path:
        matches = re.findall(r"\('([\d.]+)',\s*'([^']+)',\s*'([^']*)'\)", content)
        print(f"Found {len(matches)} students in {file_path}")
        if matches:
            print(f"Sample student: {matches[0]}")
        for student_id, name, photo in matches:
            eng_name = transliterate_name(name)
            email = generate_student_email(name, student_id)
            safe_name = eng_name.replace("'", "''")
            u = str(uuid.uuid4())
            updates.append(f"UPDATE students SET name = '{safe_name}', email = '{email}', auth_user_id = '{u}' WHERE student_id = '{student_id}';")
    
    # LMS Users
    if 'lms' in file_path:
        matches = re.findall(r"INSERT INTO (admins|lecturers) \(.*?\) VALUES \('([^']+)',\s*'([^']+)',\s*'([^']+)'\)", content)
        print(f"Found {len(matches)} LMS users in {file_path}")
        if matches:
            print(f"Sample user: {matches[0]}")
        for table, user_id, name, email in matches:
            eng_name = transliterate_name(name)
            safe_name = eng_name.replace("'", "''")
            u = str(uuid.uuid4())
            key_name = f"{table[:-1]}_id"
            updates.append(f"UPDATE {table} SET name = '{safe_name}', auth_user_id = '{u}' WHERE {key_name} = '{user_id}';")
            
    return updates

if __name__ == "__main__":
    all_updates = ["-- User Migration: Rename to English, Generate UUIDs, Set Student Emails", "BEGIN;"]
    
    all_updates.extend(process_file('students.sql', 'utf-16'))
    all_updates.extend(process_file('lms_import_utf8.sql', 'utf-8'))
    
    all_updates.append("COMMIT;")
    
    with open('migration_english_users.sql', 'w', encoding='utf-8') as f:
        f.write('\n'.join(all_updates))
    
    print(f"Generated migration_english_users.sql with {len(all_updates)-3} updates.")
