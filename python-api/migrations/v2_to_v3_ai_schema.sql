-- Migration: v2 to v3 AI Schema
-- Adds support for AI Comprehension Checks and Student Answers

CREATE TABLE IF NOT EXISTS comprehension_checks (
    id SERIAL PRIMARY KEY,
    lecture_id VARCHAR REFERENCES lectures(lecture_id) ON DELETE CASCADE,
    material_id VARCHAR REFERENCES materials(material_id) ON DELETE SET NULL,
    question TEXT NOT NULL,
    options TEXT NOT NULL, -- JSON encoded list
    correct_option INTEGER NOT NULL, -- 0-based index
    topic VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS student_answers (
    id SERIAL PRIMARY KEY,
    check_id INTEGER REFERENCES comprehension_checks(id) ON DELETE CASCADE,
    student_id VARCHAR REFERENCES students(student_id) ON DELETE CASCADE,
    chosen_option INTEGER NOT NULL,
    is_correct BOOLEAN NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_comp_checks_lecture ON comprehension_checks(lecture_id);
CREATE INDEX IF NOT EXISTS idx_student_answers_check ON student_answers(check_id);
CREATE INDEX IF NOT EXISTS idx_student_answers_student ON student_answers(student_id);
