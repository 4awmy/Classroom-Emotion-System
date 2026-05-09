import subprocess
import sys
import os

def run_script(script_name):
    print(f"\n[RUNNING] {script_name}...")
    try:
        # Set PYTHONPATH to current dir so database/models can be imported
        env = os.environ.copy()
        env["PYTHONPATH"] = "."
        result = subprocess.run([sys.executable, f"scripts/{script_name}"], env=env, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[SUCCESS] {script_name} completed.")
            print(result.stdout)
        else:
            print(f"[ERROR] {script_name} failed:")
            print(result.stderr)
            return False
    except Exception as e:
        print(f"[EXCEPTION] {e}")
        return False
    return True

def main():
    print("=== AAST LMS DATABASE REBUILDER ===")
    print("This will reset and populate your local PostgreSQL database.\n")
    
    os.chdir("python-api")
    
    scripts = [
        "import_real_lms.py",
        "seed_academic_glue.py",
        "final_db_fix.py"
    ]
    
    for script in scripts:
        if not run_script(script):
            print("\n[!] Rebuild aborted due to errors.")
            return

    print("\n[COMPLETE] Database is now fully populated with 119 students and real courses.")
    print("[NEXT] Run 'python main.py' to start the backend.")

if __name__ == "__main__":
    main()
