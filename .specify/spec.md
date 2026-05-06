# AAST Classroom Emotion System — Specification

## Vision
An AI-powered Learning Management System and Classroom Emotion Analytics Platform for AAST.

## Objectives
- Detect and track student emotions in real-time during lectures
- Provide analytics dashboards for Admin and Lecturer roles
- Deliver a mobile app for student engagement and focus monitoring
- Enable AI-driven interventions (smart notes, fresh-brainer questions)
- Support exam proctoring via camera-based detection

## Architecture Constraints (LOCKED)
See `.specify/memory/constitution.md` for the 16 non-negotiable principles.

## Key Components
1. **Backend**: FastAPI + SQLite + Python vision pipeline
2. **Web Portal**: R/Shiny (Admin + Lecturer only)
3. **Mobile App**: React Native + Expo (Students only)
4. **AI Services**: Gemini 1.5 Flash, OpenAI Whisper, YOLOv8, HSEmotion

## Success Criteria
- All 8 admin analytics panels functional
- All 5 lecturer submodules complete
- Student mobile app with focus mode and smart notes
- Real-time emotion detection from classroom camera
- Nightly CSV exports for analytics
- Confusion-triggered AI interventions working
