# AAST Classroom Emotion & Proctoring System (v4.0)

Welcome to the production version of the AAST Learning Management System, now consolidated into a high-performance **FastAPI + PostgreSQL** architecture.

---

## 🚀 Quick Start (For Developers)

1.  **Pull the latest code** from the `deploy-ready` branch.
2.  **Database Connection:**
    *   The system now uses a single **Managed PostgreSQL** database on Digital Ocean.
    *   Configure `DATABASE_URL` in your local `.env` or `.Renviron` file.
3.  **Run Backend (FastAPI):**
    ```bash
    cd python-api
    python main.py
    ```
4.  **Run Portal (Shiny):**
    *   Open `shiny-app/app.R` in RStudio.
    *   Click **"Run App"** or run `shiny::runApp("shiny-app")` in the console.

---

## 🏗️ Core Architecture: The "State Machine"
The system has been refactored from a simple data logger into a strict **State Machine** for every lecture:
*   **not_started:** The initial scheduled state.
*   **live:** Active monitoring phase. AI vision and WebSockets are fully engaged.
*   **ended:** Session frozen for analysis. Generates final engagement reports and attendance summaries.

---

## 🛡️ User Guides

### 1. Administrator Guide (Centralized Roster)
The Admin portal is the master control center for all system data.
*   **User Management:** Add, Edit, or Delete Admins, Lecturers, and Students in one place.
*   **Photo Management:** Upload student photos for AI face encoding directly from the UI.
*   **Academic Structure:** Manage Courses, Classes, and assigned Faculty.

### 2. Lecturer Guide (The Command Center)
A high-speed dashboard designed for the classroom.
*   **Live Dashboard:** 2-column layout with real-time video and a **Dynamic Attendance Grid**.
*   **Live Snapshots:** The UI automatically replaces student profile pictures with **camera snapshots** the moment they are recognized by the AI.
*   **Hard Reset:** A surgical reset button to wipe session data and restart a lecture from scratch if needed.

---

## 🛠️ Technology Stack
*   **Backend:** FastAPI (Python 3.13) + SQLAlchemy 2.0.
*   **Database:** Managed PostgreSQL 15+ (Digital Ocean).
*   **Auth:** Integrated BCrypt hashing (Supabase has been retired).
*   **Vision:** YOLOv8 (Detection) + HSEmotion (Emotion Recognition).
*   **Frontend:** R/Shiny (Staff Portal) & React Native (Student App).

---

## 🔬 Custom Technical Logic: The "Nuclear Option" Parser

To ensure 100% database reliability in Dockerized environments, we implemented a custom R function in `global.R` to handle PostgreSQL connection strings. 

### `parse_postgres_url(url_str)`
This function is necessary because the standard R database drivers sometimes struggle to parse complex `postgresql://` strings on Linux/Digital Ocean servers.

**How it works:**
It uses Regex and string splitting to manually deconstruct the connection string into its raw components:
1.  **Auth:** Extracts `user` and `password`.
2.  **Host:** Extracts the remote `host` and `port`.
3.  **DB:** Extracts the specific `database name`.
4.  **Security:** Forces `sslmode = "require"`.

**The Result:** By passing these raw parameters explicitly to `dbConnect()`, we bypass the brittle automatic parsers, ensuring the UI **never** fails to connect to the production database.

---

## 🛑 Troubleshooting
*   **Empty UI:** Expand the **System Debug Info** box at the bottom of the page. Check the `Env Status` and `Last DB Error`.
*   **Connection Denied:** Ensure your local IP is added to the **Trusted Sources** in the Digital Ocean Database settings.
*   **Snapshot Not Loading:** Verify the `API_URL` environment variable is pointing to your public gateway.

*© 2026 Arab Academy for Science, Technology & Maritime Transport*
