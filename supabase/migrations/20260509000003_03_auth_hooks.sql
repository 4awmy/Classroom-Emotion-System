CREATE OR REPLACE FUNCTION public.custom_jwt_claims(event jsonb)
RETURNS jsonb AS $$
DECLARE
  claims jsonb := event -> 'claims';
  user_role text;
BEGIN
  user_role := (event -> 'claims' ->> 'role');

  IF user_role = 'admin' THEN
    claims := jsonb_set(claims, '{admin_id}',
      to_jsonb((SELECT admin_id FROM admins WHERE auth_user_id = (event ->> 'user_id')::uuid)));

  ELSIF user_role = 'lecturer' THEN
    claims := jsonb_set(claims, '{lecturer_id}',
      to_jsonb((SELECT lecturer_id FROM lecturers WHERE auth_user_id = (event ->> 'user_id')::uuid)));

  ELSIF user_role = 'student' THEN
    claims := jsonb_set(claims, '{student_id}',
      to_jsonb((SELECT student_id FROM students WHERE auth_user_id = (event ->> 'user_id')::uuid)));
  END IF;

  RETURN jsonb_set(event, '{claims}', claims);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
