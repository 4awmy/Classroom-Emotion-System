# Classroom Emotion System - Project Handover Document
**Version:** 4.0 (Audit & Compliance Edition)  
**Date:** May 2026  
**Repository:** https://github.com/4awmy/Classroom-Emotion-System.git (Branch: `dev`)

---

## 1. Quick Start (Instant Database Setup)

If you are setting this up on a new machine, use this "Instant Restore" method to get the exact same environment used in the demo.

### **Step 1: Clone & Start Docker**
```bash
git clone https://github.com/4awmy/Classroom-Emotion-System.git
cd Classroom-Emotion-System
git checkout dev
docker-compose up -d
```

### **Step 2: Instant Database Restore (RECOMMENDED)**
Run this single command to import all 119 students, classes, and biometric encodings:
```bash
docker exec -i aast_lms_db psql -U postgres classroom_emotions < full_database_backup.sql
```
*Note: Make sure Docker is running and the container `aast_lms_db` is active.*

### **Step 3: Alternative Rebuild (Plan B)**
If the SQL dump fails, you can rebuild the database from scratch using the Python script:
```bash
python rebuild_database.py
```

---

## 2. Technical Setup

### **Backend (Python)**
1. `cd python-api`
2. `python -m venv venv`
3. `venv\Scripts\activate` (Windows)
4. `pip install -r requirements.txt`
5. `python main.py`
   * *API URL:* `http://localhost:8000`

### **Portal (R/Shiny)**
1. Open `shiny-app/app.R` in RStudio.
2. Install dependencies: `install.packages(c("shiny", "shinydashboard", "shinyalert", "plotly", "DT", "dplyr", "RPostgres"))`
3. Click **"Run App"**.
   * *Portal URL:* `http://localhost:3838`

---

## 3. Defense Logic (Theoretical Backing)

| Feature | Chapter | Technical Defense |
| :--- | :--- | :--- |
| **Systematic Sampling** | 5 | "Captured frames every 5s ($k=5$) for an unbiased sample." |
| **Confidence Intervals** | 6 | "Calculated 95% CI to adjust quality scores based on system uptime." |
| **Hypothesis Testing** | 7 | "Used Two-Sample T-Tests to detect significant engagement drops." |
| **K-Means Clustering** | 12 | "Unsupervised learning to identify behavioral student patterns." |

---

## 4. Key Developer Commands
* **Kill Port 8000:** `taskkill /F /IM python.exe /T`
* **Test Camera:** `python python-api/scripts/test_cam.py`
* **Reset Passwords:** `python python-api/scripts/manual_reset.py`

---
**Handover Status:** 100% COMPLETE & SYNCED.
**Branch:** `dev`
**Architect:** Gemini CLI Senior Backend Architect
