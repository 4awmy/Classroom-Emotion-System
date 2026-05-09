# Classroom Emotion System - Project Handover Document
**Version:** 4.0 (Audit & Compliance Edition)  
**Date:** May 2026  
**Architect:** Senior Backend AI Lead

---

## 1. Project Overview
The Classroom Emotion System is a multi-platform AI analytics suite designed for high-fidelity educational monitoring. It uses computer vision (YOLOv8, Face Recognition) to track student attendance and emotional engagement in real-time, providing administrators with statistically-backed auditing tools and lecturers with a live command center.

### **Core Stack:**
*   **Backend:** FastAPI (Python 3.13) + SQLAlchemy.
*   **Analytics Engine:** R 4.4 (Shiny, ggplot2, plotly).
*   **Mobile:** React Native (Expo) for Student Access.
*   **Database:** Local PostgreSQL (Docker) + Supabase Auth (Hybrid).
*   **AI:** YOLOv8 (Person/Face), HSEmotion (Emotion), face_recognition (128-d biometrics).

---

## 2. Directory Structure & Key Files
*   `/python-api/`: Core intelligence and API server.
    *   `main.py`: Entry point (handles lifespan and background threads).
    *   `database.py`: PostgreSQL connection management.
    *   `models.py`: Database schema (v3 Hybrid).
    *   `services/vision_pipeline.py`: The AI heartbeat (camera feed processing).
    *   `services/proctor_service.py`: Cheating detection logic.
*   `/shiny-app/`: The Management Dashboards.
    *   `app.R`: Main UI router and login logic.
    *   `global.R`: Database and API client setup.
    *   `ui/` & `server/`: Modular logic for 14 Admin panels and 8 Lecturer tools.
    *   `modules/clustering.R`: K-means logic for Student/Lecturer grouping.
*   `/react-native-app/`: Mobile application for students.
*   `/data/`: Local storage for evidence photos and materials.

---

## 3. Installation & Setup

### **Prerequisites**
1.  **Python 3.13+**: Install via python.org.
2.  **R & RStudio**: Install R 4.4 and the latest RStudio.
3.  **Docker Desktop**: Required for the local PostgreSQL database.
4.  **Node.js & Expo CLI**: Required for the mobile app.

### **Step 1: Database (PostgreSQL)**
1.  Open terminal in project root.
2.  Run: `docker-compose up -d`
    *   *Default Port:* 5432
    *   *Credentials:* `postgres / password123`

### **Step 2: Backend (Python)**
1.  `cd python-api`
2.  Install dependencies: `pip install -r requirements.txt`
3.  Run migrations/seed: `python scripts/seed_academic_glue.py`
4.  Start server: `python main.py`
    *   *URL:* `http://localhost:8000`

### **Step 3: Portal (R/Shiny)**
1.  Open RStudio.
2.  Install libraries: `install.packages(c("shiny", "shinydashboard", "plotly", "DT", "dplyr", "RPostgres"))`
3.  Run: `shiny::runApp("shiny-app")`
    *   *URL:* `http://localhost:3838`

---

## 4. How to Update & Modify

### **Adding a New Column to DB**
Do not edit the DB directly. Update `python-api/models.py` first, then run a manual `ALTER TABLE` script like `python-api/scripts/final_db_fix.py`.

### **Updating AI Models**
*   **Face Encodings:** To add new students, run `python python-api/re_encode_dataset.py`. This downloads photos from Google Drive and generates the 128-d vectors.
*   **YOLO:** Replace `yolov8n.pt` in the root with your custom-trained weights.

---

## 5. Defense Logic: Statistical Methodologies

When defending this project, emphasize these **"Chapters 5-8"** implementations:

1.  **Sampling (Chapter 5):** The system uses **Systematic Sampling**. We capture 1 frame every 5 seconds ($k=5$). This ensures the data represents the "Population" (the 2-hour lecture) without overwhelming the CPU.
2.  **Confidence Intervals (Chapter 6):** In the Admin Audit tab, we calculate the **Standard Error ($s/\sqrt{n}$)**. If the camera was offline, the margin of error increases, and the "Quality Score" is automatically adjusted downward to ensure fairness.
3.  **Hypothesis Testing (Chapter 7):** We use a **Two-Sample T-Test** ($p < 0.05$) to compare the mean engagement of the first 10 mins vs. last 10 mins. If the difference is statistically significant, we reject the null hypothesis and flag a "Premature Conclusion."
4.  **Clustering (Machine Learning):** We use **K-Means** in R to group students into behavioral clusters. This identifies hidden patterns in student-subject relationships.

---

## 6. Troubleshooting
*   **Port 8000 Busy:** Run `taskkill /F /IM python.exe /T` to clear orphaned background threads.
*   **Camera Locked:** Ensure no other app (Zoom, Teams) is using the webcam.
*   **API Error 500:** Check `python-api/backend_err.log`. Usually caused by a missing database column.

---
**Handover Complete.**
*For further technical support, contact the Dev Team via GitHub.*
