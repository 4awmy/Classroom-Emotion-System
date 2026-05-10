import re
import uuid
from anyascii import anyascii
import os

def transliterate_name(name):
    # anyascii does a decent job for Arabic
    # We strip extra spaces and title case it
    trans = anyascii(name).strip()
    # Replace multiple spaces with one
    trans = re.sub(r'\s+', ' ', trans)
    return trans.title()

def generate_student_email(name, student_id):
    english_name = transliterate_name(name)
    # Get first letter of the first word
    first_initial = english_name[0].lower() if english_name else 's'
    clean_id = student_id.replace('.0', '')
    return f"{first_initial}{clean_id}@aast.com"

def process_students(file_path):
    updates = []
    if not os.path.exists(file_path):
        return updates
    
    with open(file_path, 'r', encoding='utf-16') as f:
        content = f.read()
    
    # Pattern: ('231006367.0', 'محمد علاء لطفى', '...')
    # Using a more robust regex for values block
    matches = re.findall(r"\('([\d.]+)',\s*'([^']+)',\s*'([^']*)'\)", content)
    for student_id, name, photo in matches:
        eng_name = transliterate_name(name)
        email = generate_student_email(name, student_id)
        safe_name = eng_name.replace("'", "''")
        u = str(uuid.uuid4())
        updates.append(f"UPDATE students SET name = '{safe_name}', email = '{email}', auth_user_id = '{u}' WHERE student_id = '{student_id}';")
    return updates

def process_lms_users(file_path):
    updates = []
    if not os.path.exists(file_path):
        return updates
    
    with open(file_path, 'r', encoding='utf-16') as f:
        content = f.read()
    
    # Pattern: INSERT INTO (admins|lecturers) (admin_id, name, email) VALUES ('ID', 'NAME', 'EMAIL')
    matches = re.findall(r"INSERT INTO (admins|lecturers) \(.*?\) VALUES \('([^']+)',\s*'([^']+)',\s*'([^']+)'\)", content)
    for table, user_id, name, email in matches:
        eng_name = transliterate_name(name)
        safe_name = eng_name.replace("'", "''")
        u = str(uuid.uuid4())
        # We update name and set a new UUID for auth_user_id
        # We keep the old email for admins/lecturers as they are already @aast.edu or similar
        key_name = f"{table[:-1]}_id"
        updates.append(f"UPDATE {table} SET name = '{safe_name}', auth_user_id = '{u}' WHERE {key_name} = '{user_id}';")
    return updates

if __name__ == "__main__":
    all_updates = []
    all_updates.append("-- User Migration: Rename to English, Generate UUIDs, Set Student Emails")
    all_updates.append("BEGIN;")
    
    print("Processing students.sql...")
    all_updates.extend(process_students('students.sql'))
    
    print("Processing lms_import.sql...")
    all_updates.extend(process_lms_users('lms_import.sql'))
    
    all_updates.append("COMMIT;")
    
    with open('migration_english_users.sql', 'w', encoding='utf-8') as f:
        f.write('\n'.join(all_updates))
    
    print(f"Generated migration_english_users.sql with {len(all_updates)-3} updates.")
