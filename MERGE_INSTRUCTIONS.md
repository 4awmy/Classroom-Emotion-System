# MERGE INSTRUCTIONS: Gemini & QR Integration (v3.6.0)

This document provides instructions for merging the `feat-gemini-integration` branch into `deploy-ready` and configuring the production environment on DigitalOcean.

## 1. **Feature Set Summary**
- **Gemini Intelligence:** PDF parsing, AI Refreshers, Confusion Interventions ("Fresh Brainers"), and End-of-Lecture MCQs.
- **Unified Workflow:** Single "Lecture" tab with state management (not_started -> live -> ended).
- **Hard Reset:** Scoped deletion of session data to allow lecture re-runs.
- **QR Attendance:** Mobile-to-Portal scanning with backend verification.
- **Production Hardening:** Decentralized AI processing (backend decoupled from Torch/OpenCV) and Direct SQL database initialization.

## 2. **Git Merge Strategy**
Run these commands from the project root:
```bash
git checkout deploy-ready
git pull origin deploy-ready
git merge feat-gemini-integration
```
*Resolve any conflicts by prioritizing the code in `feat-gemini-integration` for AI/Session logic.*

## 3. **Database Migration**
The new features require two new tables and several modifications to the existing schema.
1.  Locate the migration script: `python-api/migrations/v2_to_v3_ai_schema.sql`.
2.  **Execute the SQL:** Log in to your DigitalOcean PostgreSQL console and run the contents of that file. 
    *   *Note:* The backend also has a "Direct SQL Init" in `main.py` that will attempt to create these tables automatically upon the first successful start.

## 4. **DigitalOcean Environment Config**
Ensure the following environment variables are set in the DigitalOcean App Platform for the **backend** and **frontend** services:

| Key | Service | Value / Note |
|---|---|---|
| `DATABASE_URL` | Both | Use your secret DigitalOcean connection string (with `sslmode=require`). |
| `GEMINI_API_KEY` | Backend | Your API key from Google AI Studio. |
| `JWT_SECRET` | Backend | `kdJTnejv0XYhud5C` (must match your local .env). |
| `API_URL` | Frontend | `https://classroomx-lkbxf.ondigitalocean.app` (The public gateway). |
| `ENVIRONMENT` | Backend | `production` |

## 5. **Deployment & Verification**
1.  **Push to Deploy:** `git push origin deploy-ready`
2.  **Trigger Final Seed:** Once the backend is `ACTIVE`, trigger the admin account creation:
    ```bash
    curl -X POST "https://classroomx-lkbxf.ondigitalocean.app/api/internal/seed?x_seed_secret=kdJTnejv0XYhud5C"
    ```
3.  **Verify Login:** Log in to the portal with `admin` / `aast2026`.
4.  **Test Local Vision:** Launch the local node on your laptop:
    ```bash
    $env:API_URL="https://classroomx-lkbxf.ondigitalocean.app"; python vision/main.py
    ```

---
*Created by Gemini CLI - May 10, 2026*
