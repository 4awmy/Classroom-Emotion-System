# Project Testing Manual

This manual provides instructions on how to test the various components of the Classroom Emotion System.

## 1. Staff Portal (R/Shiny)
The Staff Portal is the central hub for lecturers and admins to view analytics and manage courses.

### How to Test:
1. Access the portal link (provided in the Credentials section).
2. Log in using the **Lecturer** or **Admin** credentials.
3. Explore the "Live Class" dashboard to see simulated or real-time emotion data.
4. Check the "Attendance" tab for automated records.

## 2. Student Mobile App (React Native)
The student app is used for focus tracking and receiving AI-generated notifications.

### How to Test:
1. Ensure the app is installed (via Expo or direct build).
2. Log in using a **Student** account.
3. Activate "Focus Mode" and observe how the system tracks engagement.

## 3. Backend API (FastAPI)
The engine that powers the emotion detection and AI interventions.

### How to Test:
1. Access the `/docs` (Swagger) endpoint of the API.
2. Use the `POST /vision/trigger` endpoint to simulate a camera frame analysis.
3. Observe the response containing detected emotions and cheating signals.

---

*Note: For security, do not share the testing credentials with unauthorized personnel.*
