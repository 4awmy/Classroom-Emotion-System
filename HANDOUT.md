# Classroom Emotion System - Project Handover Document
**Version:** 4.0 (Audit & Compliance Edition)  
**Date:** May 2026  
**Repository:** https://github.com/4awmy/Classroom-Emotion-System.git (Branch: `dev`)

---

## 1. Quick Start (From Fresh Clone)

If you are setting this up on a new machine, follow these steps exactly:

### **Step 1: Clone the Repository**
```bash
git clone https://github.com/4awmy/Classroom-Emotion-System.git
cd Classroom-Emotion-System
git checkout dev
```

### **Step 2: Initialize the Database (Docker)**
The project uses a local PostgreSQL database inside Docker.
1. Make sure **Docker Desktop** is running.
2. Run: `docker-compose up -d`
3. Verify: Open Docker Desktop and check that the `classroom_emotions` container is green.

### **Step 3: Setup the Python Backend**
1. `cd python-api`
2. Create a virtual environment: `python -m venv venv`
3. Activate it: `venv\Scripts\activate` (Windows) or `source venv/bin/activate` (Mac/Linux)
4. Install dependencies: `pip install -r requirements.txt`
5. **CRITICAL: Initialize the Schema & Data:**
   Run these two scripts to build the tables and load the real students/courses:
   ```bash
   python scripts/import_real_lms.py     # Imports the 119 real students
   python scripts/seed_academic_glue.py   # Assigns classes, lecturers, and schedules
   python scripts/final_db_fix.py         # Adds the latest audit columns
   ```
6. Start the server: `python main.py`

### **Step 4: Setup the R/Shiny Portal**
1. Open RStudio.
2. Go to File -> Open Project -> Select the `Classroom-Emotion-System` folder.
3. Install required R packages:
   ```R
   install.packages(c("shiny", "shinydashboard", "shinyalert", "shinyjs", "plotly", "DT", "dplyr", "lubridate", "httr2", "RPostgres"))
   ```
4. Open `shiny-app/app.R` and click **"Run App"**.

---

## 2. Database State & Persistence
*   **The Schema:** The database structure is defined in `python-api/models.py`. 
*   **The Data:** Since the data lives in Docker, it is not "inside" the Git files. However, the `scripts/` folder contains everything needed to **completely rebuild** the database from zero in less than 60 seconds.
*   **Student Biometrics:** The 128-d face vectors are stored in the `students` table. To refresh them from the Google Drive dataset, run `python python-api/re_encode_dataset.py`.

---

## 3. Defense Logic (The "Why")

When the examiners ask about your implementation, use these technical justifications:

| Feature | Chapter | Technical Defense |
| :--- | :--- | :--- |
| **Systematic Sampling** | 5 | "We capture frames at a constant interval $k=5s$ to ensure our sample is an unbiased representation of the 2-hour population." |
| **Confidence Intervals** | 6 | "We use the Standard Error formula to calculate 95% Confidence Intervals for engagement. If uptime drops, the margin of error increases, and the quality score is penalized to maintain statistical integrity." |
| **Hypothesis Testing** | 7 | "We perform a two-sample T-test comparing the start and end of the lecture. If $p < 0.05$, we mathematically prove a significant drop in engagement, flagging a premature conclusion." |
| **K-Means Clustering** | 12 | "We use unsupervised learning to group students into behavioral clusters based on their long-term emotional signatures, revealing patterns that simple averages miss." |

---

## 4. Key Developer Commands
*   **Kill Port 8000:** `taskkill /F /IM python.exe /T` (Use this if the server crashes or won't restart).
*   **Reset Admin Password:** Run `python scripts/manual_reset.py` to set a user back to default.
*   **Verify Database:** Run `python scripts/verify_postgres_data.py`.

---
**Handover Status:** 100% COMPLETE
**Branch:** `dev` (All changes pushed and verified)
**Architect Signature:** Gemini CLI Senior Backend Architect
