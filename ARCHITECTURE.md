# ARCHITECTURE.md — Logical Architecture & Data Flow Specification
> **Audience:** Engineering team only. This document defines the precise wiring between every subsystem.
> **Status:** Production-Ready (FastAPI + PostgreSQL + Digital Ocean)

---

## 0. System Overview: Consolidated Cloud Architecture

The Classroom Emotion System is a consolidated cloud platform designed for real-time engagement monitoring and automated proctoring.

### 0.1 Centralized Cloud (DigitalOcean)
- **Backend (FastAPI):** Orchestrates business logic, authentication, WebSocket signaling, and AI interventions.
- **Database (Managed PostgreSQL):** Hosted on Digital Ocean. The single source of truth for academic records, user credentials, attendance, and emotion logs.
- **Identity:** Managed directly via the FastAPI auth router using `password_hash` and `auth_user_id` (UUID) in the PostgreSQL user tables.
- **Storage (DO Spaces):** S3-compatible storage for student photos, attendance snapshots, and exam evidence.

### 0.2 Local Vision Nodes (Classroom)
- **Hardware:** Classroom PC/Laptop or Edge Device.
- **Software:** `vision/main.py` or FastAPI Vision Thread.
- **AI Stack:** YOLOv8 (Person/Face detection), face-recognition (Identity), HSEmotion (Emotion classification).
- **Privacy:** Processes video locally; only anonymized metadata and occasional proof-of-presence snapshots are sent to the cloud.

---

## 1. System Topology & Data Flow

### 1.1 High-Level Component Map
```mermaid
graph TD
    subgraph Classroom
        CAM[IP/USB Camera] --> VIS[Vision Node: vision/main.py]
    end

    subgraph DigitalOcean [Cloud Layer]
        API[FastAPI Backend]
        DB[(Managed PostgreSQL)]
        OBJ[DO Spaces: S3 Storage]
        GEM[Gemini 2.5 Flash AI]
    end

    subgraph Clients [Frontend Layer]
        STAFF[R/Shiny Staff Portal]
        APP[React Native Student App]
    end

    VIS -- Anonymized Metadata --> API
    VIS -- Snapshot Upload --> OBJ
    API -- Query/Save --> DB
    API -- Context --> GEM
    GEM -- Intervention --> API
    API -- WebSockets --> STAFF
    API -- WebSockets --> APP
    STAFF -- Analytics Query --> DB
```

---

## 2. Identity & Data Standards

### 2.1 User Identity Flow
```mermaid
sequenceDiagram
    participant User as Student/Lecturer
    participant API as FastAPI Backend
    participant DB as PostgreSQL
    participant JWT as Auth Service

    User->>API: Login (Email/Password)
    API->>DB: Fetch user by Email
    DB-->>API: Returns password_hash & auth_user_id
    API->>API: Verify password (BCrypt)
    API->>JWT: Generate Token (sub: auth_user_id)
    JWT-->>User: Returns JWT Token
```

### 2.2 Entity Relationship Diagram (ERD)
```mermaid
erDiagram
    ADMINS ||--o{ LOGS : manages
    LECTURERS ||--o{ CLASSES : teaches
    CLASSES ||--o{ LECTURES : contains
    CLASSES ||--o{ ENROLLMENTS : registers
    STUDENTS ||--o{ ENROLLMENTS : joins
    LECTURES ||--o{ EMOTION_LOG : records
    LECTURES ||--o{ ATTENDANCE_LOG : tracks
    STUDENTS ||--o{ EMOTION_LOG : displays
    STUDENTS ||--o{ ATTENDANCE_LOG : marked_in
    LECTURES ||--o{ MATERIALS : links
    MATERIALS ||--o{ COMPREHENSION_CHECKS : triggers
```

---

## 3. Data Contracts — PostgreSQL Schema

### `students`
| Column | Type | Description |
| :--- | :--- | :--- |
| `student_id` | TEXT (PK) | Primary academic ID (e.g. 231006367) |
| `auth_user_id` | UUID (Unique) | Internal Unique identifier |
| `password_hash`| TEXT | Securely hashed password |
| `name` | TEXT | English Full Name |
| `email` | TEXT | `[initial][id]@aast.com` |
| `face_encoding`| BYTEA | 128-dim face vector |
| `photo_url` | TEXT | Link to DO Spaces/Google Drive |

---

## 4. AI Pipeline Specifications

### 4.1 Vision Inference Flow
```mermaid
flowchart LR
    F[Frame Capture] --> DET[YOLOv8: Person/Face Detection]
    DET --> CROP[Face Cropping]
    CROP --> ID[Face Recognition: Identity]
    CROP --> EMO[HSEmotion: Emotion Classification]
    ID --> SYNC[Aggregator]
    EMO --> SYNC
    SYNC --> SEND[Post to Backend]
```

### 4.2 AI Interventions (Gemini)
- **Signal:** Student "Confused" score > 0.8 for 3 consecutive cycles.
- **Context:** Extracts text from current `lecture_materials` (PDF/PPT).
- **Prompt:** "Explain [Concept] for a student who looks confused."
- **Action:** Sends a **Fresh Brainer** question via WebSocket to the Student App.

---

## 5. Deployment

### 5.1 Cloud Topology
- **Primary Region:** `fra` (Frankfurt, Germany)
- **Infrastructure:**
    - App Platform: `basic-s` (2GB RAM)
    - Managed Database: PostgreSQL 15 (Development Node)
    - Object Storage: DigitalOcean Spaces (S3)

---

*End of Specification — Last Updated May 2026*
