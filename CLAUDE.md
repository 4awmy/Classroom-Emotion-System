# CLAUDE.md — AI-Powered LMS & Classroom Analytics Platform

## Project overview
An AI-powered LMS and Classroom Emotion Analytics Platform for **AAST**.
The system detects student emotions in real time, stores them as structured CSV data, performs statistical analysis in R, and surfaces insights through Shiny and React frontends.

## Monorepo structure
- `data-schema/`: Locked CSV column contracts.
- `shiny-app/`: R/Shiny web portal (Admin + Lecturer).
- `python-api/`: FastAPI backend + AI Services (DeepFace, Gemini).
- `react-app/`: Student mobile/web app (Expo + Vite).
- `notebooks/`: Google Colab notebooks for training/analytics.

## Data Schema (LOCKED)
- `emotions.csv`: Student_ID, Time, Emotion, Confidence, Lecture_ID
- `attendance.csv`: Student_ID, Lecture_ID, Date, Status, Method
- `materials.csv`: Material_ID, Lecture_ID, Lecturer_ID, Title, Drive_Link, Uploaded_At
- `incidents.csv`: Student_ID, Exam_ID, Timestamp, Flag_type, Severity, Evidence_path

## Tech Stack
- **Backend:** Python 3.10+, FastAPI, DeepFace, OpenCV.
- **Frontend (Admin/Lecturer):** R, Shiny, ggplot2, plotly.
- **Frontend (Student):** React Native (Expo), React (Vite), Tailwind.
- **AI:** Google Gemini (google-generativeai), Whisper.
- **Deployment:** Railway (API), shinyapps.io (Shiny), Vercel (React).

## Development Commands
- **Backend:** `pip install -r python-api/requirements.txt && uvicorn python-api.main:app --reload`
- **Frontend (Shiny):** Run `shiny::runApp("shiny-app")` in R.
- **Frontend (React):** `cd react-app && npm install && npx expo start`
