# AAST Classroom Emotion & Proctoring System (v2)

Welcome to the updated AAST Learning Management System, now powered by **Supabase PostgreSQL** and **AI-Vision Analytics**.

---

## 🚀 Quick Start (For Developers)

1.  **Pull the latest code** from the `dev` branch.
2.  **Database Connection:**
    *   Create `python-api/.env` with the Supabase credentials provided by the lead dev.
    *   Create `shiny-app/.Renviron` (RStudio will load this automatically).
3.  **Run Backend (FastAPI):**
    ```bash
    cd python-api
    python main.py
    ```
4.  **Run Portal (Shiny):**
    *   Open `shiny-app/app.R` in RStudio.
    *   Click **"Run App"** or run `shiny::runApp("shiny-app")` in the console.

---

## 🔄 Team Data Sync (Shared Recipe)
Since we are using **Local SQLite**, each developer has their own database. To keep the data consistent:

*   **To Share your data (Data Team):**
    ```bash
    cd python-api
    python sync_data.py export
    # Then git commit 'python-api/data/master_data.sql'
    ```
*   **To Get the team's latest data:**
    ```bash
    git pull
    cd python-api
    python sync_data.py import
    ```

---

## 🛡️ User Guides

### 1. Administrator Guide
The Admin portal is the central command for the semester.
*   **Analytics:** View system-wide attendance, engagement heatmaps, and performance clusters.
*   **Management:** 
    *   **Students:** Add new students and upload photos for AI face encoding.
    *   **Lecturers:** Create and manage lecturer profiles.
    *   **Academic Structure:** Configure Courses, Sections (Classes), and weekly Timetables.
*   **Security:** Review proctoring incident logs from all exams in real-time.

### 2. Lecturer Guide
Focus on your class while the AI handles the data.
*   **My Schedule:** View your personalized weekly timetable.
*   **Live Session:** 
    *   Select your class and click **"Start Lecture"**.
    *   The AI will automatically track student emotions and attendance.
    *   **Gemini AI** will alert you if the class looks confused and suggest clarifying questions.
*   **Reports:** Drill down into individual student engagement trends and generated AI study plans.
*   **Exams:** Create and monitor digital exams with automated high-severity incident reporting.

### 3. Student Guide (Mobile App)
Your companion for staying focused and on track.
*   **Login:** Sign in using your registered AAST email and the password assigned by your admin.
*   **My Schedule:** See your upcoming lectures and exam locations.
*   **Focus Mode:** 
    *   Join your live lecture via the app.
    *   Earn "Focus Points" by staying in the app; switching to social media or backgrounding the app will trigger a Focus Strike.

---

## 🛠️ Technology Stack
*   **Backend:** FastAPI (Python 3.13) + SQLAlchemy 2.0.
*   **Database:** Supabase PostgreSQL with Row Level Security (RLS).
*   **Vision:** YOLOv8 (Face Detection) + HSEmotion (Emotion Recognition).
*   **Frontend:** R/Shiny (Analytics) & React Native/Expo (Mobile).
*   **AI:** Google Gemini Pro for real-time pedagogical feedback.

---

## 🛑 Troubleshooting
*   **Blank Screen in Shiny:** Ensure you have **Restarted RStudio** after pulling the latest code to load the new `.Renviron` file.
*   **Login Failed:** You must be manually linked in the Supabase Authentication dashboard by an admin.
*   **Database Refused:** Check if your network blocks Port 6543 (Transaction Pooler). If so, request a Port 443 configuration from the dev lead.

*© 2026 Arab Academy for Science, Technology & Maritime Transport*
