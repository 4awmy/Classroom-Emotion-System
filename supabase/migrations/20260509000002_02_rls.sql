-- Enable RLS on every table
ALTER TABLE admins           ENABLE ROW LEVEL SECURITY;
ALTER TABLE lecturers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE students         ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_schedule   ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE lectures         ENABLE ROW LEVEL SECURITY;
ALTER TABLE exams            ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials        ENABLE ROW LEVEL SECURITY;
ALTER TABLE emotion_log      ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_log   ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents        ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE focus_strikes    ENABLE ROW LEVEL SECURITY;

-- ─── ADMIN: full access to everything ───
CREATE POLICY "admin_all" ON admins
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_lecturers" ON lecturers
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_students" ON students
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_courses" ON courses
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_classes" ON classes
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_schedule" ON class_schedule
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_enrollments" ON enrollments
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_view_all_analytics" ON emotion_log
    FOR SELECT USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_view_all_attendance" ON attendance_log
    FOR SELECT USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_view_all_incidents" ON incidents
    FOR SELECT USING ((auth.jwt() ->> 'role') = 'admin');

-- ─── LECTURER: read own profile, read own classes only ───
CREATE POLICY "lecturer_read_own_profile" ON lecturers
    FOR SELECT USING (
        auth_user_id = auth.uid()
    );

CREATE POLICY "lecturer_update_own_profile" ON lecturers
    FOR UPDATE USING (
        auth_user_id = auth.uid()
    );

CREATE POLICY "lecturer_view_own_classes" ON classes
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

CREATE POLICY "lecturer_view_own_schedule" ON class_schedule
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND class_id IN (
            SELECT class_id FROM classes
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_view_enrollments" ON enrollments
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND class_id IN (
            SELECT class_id FROM classes
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_manage_lectures" ON lectures
    FOR ALL USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

CREATE POLICY "lecturer_manage_exams" ON exams
    FOR ALL USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND class_id IN (
            SELECT class_id FROM classes
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_manage_materials" ON materials
    FOR ALL USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

CREATE POLICY "lecturer_view_own_emotions" ON emotion_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecture_id IN (
            SELECT lecture_id FROM lectures
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_view_own_attendance" ON attendance_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecture_id IN (
            SELECT lecture_id FROM lectures
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_view_own_incidents" ON incidents
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND exam_id IN (
            SELECT exam_id FROM exams
            WHERE class_id IN (
                SELECT class_id FROM classes
                WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
            )
        )
    );

CREATE POLICY "lecturer_view_own_notifications" ON notifications
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

-- ─── STUDENT: own data only ───
CREATE POLICY "student_read_own_profile" ON students
    FOR SELECT USING (auth_user_id = auth.uid());

CREATE POLICY "student_view_own_emotions" ON emotion_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_own_attendance" ON attendance_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_own_enrollments" ON enrollments
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_schedule" ON class_schedule
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND class_id IN (
            SELECT class_id FROM enrollments
            WHERE student_id = (auth.jwt() ->> 'student_id')
        )
    );

CREATE POLICY "student_insert_focus_strikes" ON focus_strikes
    FOR INSERT WITH CHECK (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_own_notifications" ON notifications
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );
