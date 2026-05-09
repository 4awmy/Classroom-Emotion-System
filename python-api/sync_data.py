import sqlite3
import os
import sys

DB_PATH = "data/classroom_v2.db"
SQL_PATH = "data/master_data.sql"

def export_data():
    """Dumps the current local DB into a SQL file for the team."""
    print(f"[*] Exporting {DB_PATH} to {SQL_PATH}...")
    try:
        conn = sqlite3.connect(DB_PATH)
        with open(SQL_PATH, 'w', encoding='utf-8') as f:
            for line in conn.iterdump():
                f.write('%s\n' % line)
        conn.close()
        print("[v] Export Complete! Push 'master_data.sql' to Git now.")
    except Exception as e:
        print(f"[x] Export Failed: {e}")

def import_data():
    """Overwrites the local DB with the master data from SQL file."""
    if not os.path.exists(SQL_PATH):
        print(f"[x] Error: {SQL_PATH} not found. Pull from Git first.")
        return

    print(f"[*] Importing {SQL_PATH} into {DB_PATH}...")
    try:
        # Delete old DB to start fresh
        if os.path.exists(DB_PATH):
            os.remove(DB_PATH)
        
        conn = sqlite3.connect(DB_PATH)
        with open(SQL_PATH, 'r', encoding='utf-8') as f:
            sql = f.read()
            conn.executescript(sql)
        conn.close()
        print("[v] Import Complete! Your local database is now synced with the team.")
    except Exception as e:
        print(f"[x] Import Failed: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python sync_data.py [import | export]")
    elif sys.argv[1] == "export":
        export_data()
    elif sys.argv[1] == "import":
        import_data()
