# Implementation Plan: Supabase Auth & Schedule View

## Goal
- Transition React Native app to Supabase Auth.
- Implement Schedule View to fetch and display student schedules from PostgreSQL.

## Phase 1: Supabase Auth Migration
1. **Dependencies:** Install `@supabase/supabase-js` in `react-native-app`.
2. **Setup:** Create `react-native-app/services/supabase.ts` to initialize the Supabase client.
3. **Login Refactor:** Update `react-native-app/app/(auth)/login.tsx` to use `supabase.auth.signInWithPassword`.
4. **Auth State:** Update `react-native-app/store/useStore.ts` to handle Supabase auth state changes using `onAuthStateChange`.
5. **Session Management:** Ensure navigation protects routes based on `session`.

## Phase 2: Schedule View Implementation
1. **Service:** Create/Update `react-native-app/services/api.ts` with a function to fetch schedule:
   - Query `public.enrollments` to get `class_id`s for the authenticated student.
   - Join with `public.class_schedule` and `public.classes` and `public.courses`.
2. **Component:** Create `react-native-app/components/ScheduleView.tsx`.
3. **Integration:** Update `react-native-app/app/(student)/home.tsx` to include `ScheduleView`.

## Validation
- Verify login success with actual user credentials.
- Verify schedule displays correctly for a student.
- Ensure no regressions in navigation.
