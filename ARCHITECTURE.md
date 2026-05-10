# ARCHITECTURE.md — Logical Architecture & Data Flow Specification
> **Audience:** Engineering team only. This document defines the precise wiring between every subsystem.
> **Status:** Production-Ready (PostgreSQL + Supabase + Digital Ocean)

---

## 0. System Overview: Hybrid Cloud-Local Architecture

The Classroom Emotion System is a hybrid cloud platform designed for real-time engagement monitoring and automated proctoring.

### 0.1 Centralized Cloud (DigitalOcean)
- **Backend (FastAPI):** Orchestrates business logic, WebSocket signaling, and AI interventions (Gemini 1.5 Flash).
- **Database (Managed PostgreSQL):** Hosted on Digital Ocean. The source of truth for academic records, attendance, and emotion logs.
- **Identity (Supabase Auth):** Handles user authentication and Row Level Security (RLS). Users are linked via `auth_user_id` (UUID).
- **Storage (DO Spaces):** S3-compatible storage for student photos, attendance snapshots, and exam evidence.

### 0.2 Local Vision Nodes (Classroom)
- **Hardware:** Classroom PC/Laptop or Edge Device.
- **Software:** `vision/main.py` or FastAPI Vision Thread.
- **AI Stack:** YOLOv8 (Person/Face detection), face-recognition (Identity), HSEmotion (Emotion classification).
- **Privacy:** Processes video locally; only anonymized metadata and occasional proof-of-presence snapshots are sent to the cloud.

---

## 1. System Boundary Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CLASSROOM (Local Layer)                            │
│                                                                             │
│   ┌──────────────────┐                                                      │
│   │  IP Camera (1x)  │  RTSP / USB                                          │
│   │  Fixed Position  │──────────────────────────────────────────────────┐  │
│   └──────────────────┘                                                   │  │
└──────────────────────────────────────────────────────────────────────────│──┘
                                                                           │ Data/Signal
                                                                           ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                DIGITAL OCEAN APP PLATFORM (Production)                       │
│                                                                              │
│  ┌──────────────────────────┐          ┌──────────────────────────────────┐  │
│  │   FastAPI API Service    │◀────────▶│   Managed PostgreSQL (DO)        │  │
│  │   (uvicorn / main.py)    │          │   (classroom_emotions DB)        │  │
│  └─────────────┬────────────┘          └──────────────────────────────────┘  │
│                │                                   ▲                         │
│                │                                   │ Linked by UUID          │
│                ▼                                   ▼                         │
│  ┌──────────────────────────┐          ┌──────────────────────────────────┐  │
│  │   DO Spaces (Storage)    │          │   Supabase Auth (Identity)       │  │
│  │   (Snapshots/Evidence)   │          │   (JWT & Role Management)        │  │
│  └──────────────────────────┘          └──────────────────────────────────┘  │
└──────────┬───────────────────────────────┬───────────────────────────────── ┘
           │ HTTP / Direct SQL             │ WebSocket / HTTP
           ▼                               ▼
┌─────────────────────┐        ┌─────────────────────────┐
│  R/Shiny staff Portal│        │  React Native App       │
│  (Lecturers/Admins) │        │  (Students ONLY)        │
│                     │        │                         │
│  Reports: 2x2 Grid  │        │  Role: Student          │
│  Live: 3-Step Sel.  │        │  Signals: Focus Strikes │
└─────────────────────┘        └─────────────────────────┘
```

---

## 2. Identity & Data Standards

### 2.1 User Identity Flow
- **Linking:** Every record in `admins`, `lecturers`, and `students` contains an `auth_user_id` (UUID). This UUID corresponds exactly to the `id` in Supabase's `auth.users`.
- **Naming:** All user names are stored in **English** (transliterated from Arabic where necessary) for system compatibility and clean UI.
- **Emails:**
    - **Students:** Format `[FirstInitial][StudentID]@aast.com` (e.g., `m231006367@aast.com`).
    - **Staff:** Standard AAST/University emails.

### 2.2 Database Persistence
- **Engine:** PostgreSQL 15.
- **Timezone:** All timestamps are stored as `TIMESTAMPTZ` (UTC) to ensure accuracy across geographic regions.
- **Binary Data:** `face_encoding` is stored as `BYTEA` (Postgres binary) for high-performance retrieval.

---

## 3. Data Contracts — PostgreSQL Schema

### `students`
| Column | Type | Description |
| :--- | :--- | :--- |
| `student_id` | TEXT (PK) | Primary academic ID (e.g. 231006367) |
| `auth_user_id` | UUID (Unique) | Linked to Supabase `auth.users` |
| `name` | TEXT | English Full Name |
| `email` | TEXT | `[initial][id]@aast.com` |
| `face_encoding`| BYTEA | 128-dim face vector |
| `photo_url` | TEXT | Link to DO Spaces/Google Drive |

### `lectures`
| Column | Type | Description |
| :--- | :--- | :--- |
| `lecture_id` | TEXT (PK) | Generated ID |
| `class_id` | TEXT (FK) | Link to `classes` |
| `title` | TEXT | Lecture title (Advanced...) |
| `actual_start_time` | TIMESTAMPTZ | When the camera actually started |
| `end_time` | TIMESTAMPTZ | When the session closed |

---

## 4. Frontend Specifications

### 4.1 Lecturer Portal (R/Shiny)
- **Live Dashboard:** Implements a **3-Step Selector** (Course → Class → Session Info) to prevent accidental stream starts.
- **Analytics Tab:** Features a **2x2 Grid Layout**:
    1.  **Emotion Frequency:** Distribution of class mood.
    2.  **Engagement Timeline:** 5-minute rolling average of focus scores.
    3.  **Attendance Summary:** Real-time presence vs. roster.
    4.  **Student Drill-down:** Individual performance metrics.

### 4.2 Student App (React Native)
- **Signal Flow:** Sends `focus_strike` events via WebSockets when the app is backgrounded.
- **Identity:** Authenticates against Supabase; receives real-time "Fresh Brainer" alerts (Gemini AI questions) via WebSocket broadcasts.

---

## 5. Vision Pipeline Data Flow

1.  **Capture:** 1 frame every 5 seconds (configurable for performance).
2.  **Detection:** Stage 1 (Person detection) → Stage 2 (Face crop).
3.  **Recognition:** Compares `face_encoding` against `students` table.
4.  **Inference:** Classifies emotion into: *Focused, Engaged, Confused, Anxious, Frustrated, Disengaged*.
5.  **Logging:**
    - `attendance_log`: Written on **first** identification per session.
    - `emotion_log`: Written every cycle while student is visible.
    - `snapshots`: Face crop saved to DO Spaces for visual presence proof.

---

## 6. Deployment & Seeding

### 6.1 Production Environment
- **Digital Ocean App Platform:** Hosts the FastAPI backend and Shiny frontend.
- **Environment Variables:** `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_KEY`, `SPACES_BUCKET`.

### 6.2 Seeding Standards
- **Script:** `python-api/scripts/prod_import_and_seed.py`.
- **Visual Testing:** Automatically generates 5 historical lectures per course with simulated data to ensure immediate UI functionality upon deployment.

---

*End of Specification — Last Updated May 2026*
