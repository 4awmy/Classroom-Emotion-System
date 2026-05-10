import csv
import re
import uuid
from anyascii import anyascii
import os

def transliterate_name(name):
    if not name:
        return ""
    # anyascii does a phonetic transliteration
    trans = anyascii(name).strip()
    # Remove phonetic marks (backticks and single quotes) to make it cleaner for English names
    trans = trans.replace("`", "").replace("'", "")
    # Replace multiple spaces with one
    trans = re.sub(r'\s+', ' ', trans)
    return trans.title()

def generate_student_email(name, student_id):
    eng_name = transliterate_name(name)
    # Remove non-alpha from the start to get a proper initial
    clean_eng = re.sub(r'^[^a-zA-Z]+', '', eng_name)
    first_initial = clean_eng[0].lower() if clean_eng else 's'
    # Ensure ID is clean
    clean_id = str(student_id).replace('.0', '').strip()
    return f"{first_initial}{clean_id}@aast.com"

def process_students_csv(file_path):
    updates = []
    if not os.path.exists(file_path):
        print(f"{file_path} not found")
        return updates
    
    with open(file_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            sid = row.get('Student ID', '').strip()
            name = row.get('Student Name', '').strip()
            if not sid or not name:
                continue
            
            eng_name = transliterate_name(name)
            email = generate_student_email(name, sid)
            safe_name = eng_name.replace("'", "''")
            u = str(uuid.uuid4())
            
            # Update by student_id (handling potential .0 suffix in DB)
            updates.append(f"UPDATE students SET name = '{safe_name}', email = '{email}', auth_user_id = '{u}' WHERE student_id = '{sid}' OR student_id = '{sid}.0';")
    return updates

def process_lms_sql(file_path):
    updates = []
    if not os.path.exists(file_path):
        print(f"{file_path} not found")
        return updates
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern for admins and lecturers
    matches = re.findall(r"INSERT INTO (admins|lecturers) \(.*?\) VALUES \('([^']+)',\s*'([^']+)',\s*'([^']+)'\)", content)
    for table, user_id, name, email in matches:
        eng_name = transliterate_name(name)
        safe_name = eng_name.replace("'", "''")
        u = str(uuid.uuid4())
        key_name = f"{table[:-1]}_id"
        
        # We update name and auth_user_id
        updates.append(f"UPDATE {table} SET name = '{safe_name}', auth_user_id = '{u}' WHERE {key_name} = '{user_id}';")
    return updates

if __name__ == "__main__":
    print("Generating migration script...")
    
    all_updates = [
        "-- Migration to rename users to English, generate UUIDs, and set student emails",
        "BEGIN;"
    ]
    
    # 1. Students
    print("Processing Students CSV...")
    all_updates.extend(process_students_csv('StudentPicsDataset (1).csv'))
    
    # 2. LMS Users (Admins and Lecturers)
    print("Processing LMS SQL...")
    all_updates.extend(process_lms_sql('lms_import_utf8.sql'))
    
    all_updates.append("COMMIT;")
    
    output_file = 'migration_english_users_v3.sql'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(all_updates))
    
    print(f"DONE! Generated {output_file} with {len(all_updates)-2} update statements.")
