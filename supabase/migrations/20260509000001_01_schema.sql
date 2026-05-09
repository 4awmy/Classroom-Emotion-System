-- ─────────────────────────────────────────
-- USER TABLES
-- ─────────────────────────────────────────

CREATE TABLE admins (
    admin_id       TEXT PRIMARY KEY,
    auth_user_id   UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    name           TEXT NOT NULL,
    email          TEXT UNIQUE NOT NULL,
    phone          TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lecturers (
    lecturer_id    TEXT PRIMARY KEY,
    auth_user_id   UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    name           TEXT NOT NULL,
    email          TEXT UNIQUE NOT NULL,
    department     TEXT,
    title          TEXT,
    phone          TEXT,
    photo_url      TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE students (
    student_id     TEXT PRIMARY KEY,
    auth_user_id   UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    name           TEXT NOT NULL,
    email          TEXT,
    department     TEXT,
    year           INTEGER,
    face_encoding  BYTEA,
    photo_url      TEXT,
    enrolled_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- ACADEMIC STRUCTURE
-- ─────────────────────────────────────────

CREATE TABLE courses (
    course_id      TEXT PRIMARY KEY,
    title          TEXT NOT NULL,
    department     TEXT,
    credit_hours   INTEGER,
    semester       TEXT,
    year           INTEGER,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE classes (
    class_id       TEXT PRIMARY KEY,
    course_id      TEXT NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    lecturer_id    TEXT REFERENCES lecturers(lecturer_id) ON DELETE SET NULL,
    section_name   TEXT,
    room           TEXT,
    semester       TEXT,
    year           INTEGER,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE class_schedule (
    schedule_id    TEXT PRIMARY KEY,
    class_id       TEXT NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
    day_of_week    TEXT NOT NULL,
    start_time     TIME NOT NULL,
    end_time       TIME NOT NULL
);

CREATE TABLE enrollments (
    id             BIGSERIAL PRIMARY KEY,
    class_id       TEXT NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
    student_id     TEXT NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    enrolled_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(class_id, student_id)
);

CREATE TABLE lectures (
    lecture_id        TEXT PRIMARY KEY,
    class_id          TEXT NOT NULL REFERENCES classes(class_id),
    lecturer_id       TEXT NOT NULL REFERENCES lecturers(lecturer_id),
    title             TEXT,
    session_type      TEXT DEFAULT 'lecture',
    start_time        TIMESTAMPTZ,
    end_time          TIMESTAMPTZ,
    scheduled_start   TIMESTAMPTZ,
    slide_url         TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exams (
    exam_id           TEXT PRIMARY KEY,
    class_id          TEXT NOT NULL REFERENCES classes(class_id),
    lecture_id        TEXT REFERENCES lectures(lecture_id),
    title             TEXT NOT NULL,
    scheduled_start   TIMESTAMPTZ,
    end_time          TIMESTAMPTZ,
    auto_submit       BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE materials (
    material_id    TEXT PRIMARY KEY,
    lecture_id     TEXT NOT NULL REFERENCES lectures(lecture_id),
    lecturer_id    TEXT NOT NULL REFERENCES lecturers(lecturer_id),
    title          TEXT NOT NULL,
    drive_link     TEXT,
    uploaded_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- LIVE ANALYTICS
-- ─────────────────────────────────────────

CREATE TABLE emotion_log (
    id               BIGSERIAL PRIMARY KEY,
    student_id       TEXT NOT NULL REFERENCES students(student_id),
    lecture_id       TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp        TIMESTAMPTZ DEFAULT NOW(),
    emotion          TEXT NOT NULL,
    confidence       REAL NOT NULL,
    engagement_score REAL NOT NULL
);

CREATE TABLE attendance_log (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT NOT NULL REFERENCES students(student_id),
    lecture_id     TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp      TIMESTAMPTZ DEFAULT NOW(),
    status         TEXT NOT NULL,
    method         TEXT NOT NULL
);

CREATE TABLE incidents (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT REFERENCES students(student_id),
    exam_id        TEXT NOT NULL REFERENCES exams(exam_id),
    timestamp      TIMESTAMPTZ DEFAULT NOW(),
    flag_type      TEXT NOT NULL,
    severity       INTEGER NOT NULL,
    evidence_path  TEXT
);

CREATE TABLE notifications (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT REFERENCES students(student_id),
    lecturer_id    TEXT NOT NULL REFERENCES lecturers(lecturer_id),
    lecture_id     TEXT REFERENCES lectures(lecture_id),
    reason         TEXT NOT NULL,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    read           BOOLEAN DEFAULT FALSE
);

CREATE TABLE focus_strikes (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT NOT NULL REFERENCES students(student_id),
    lecture_id     TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp      TIMESTAMPTZ DEFAULT NOW(),
    strike_type    TEXT NOT NULL
);
