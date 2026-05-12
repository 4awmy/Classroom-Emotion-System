import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { setAuthToken as setAPIAuthToken } from "@/services/api";

interface StudentStore {
  studentId: string | null;
  studentName: string | null;
  authToken: string | null;
  activeLectureId: string | null;
  focusActive: boolean;
  strikes: number;
  isDark: boolean;

  setStudentId: (id: string | null) => void;
  setStudentName: (name: string | null) => void;
  setAuthToken: (token: string | null) => void;
  setActiveLectureId: (id: string | null) => void;
  setFocusActive: (active: boolean) => void;
  setStrikes: (count: number | ((prev: number) => number)) => void;
  setIsDark: (dark: boolean) => void;
  toggleDark: () => void;
  reset: () => void;
}

/**
 * Zustand store for managing student app state
 * Uses persist middleware to handle cold-start edge cases and session restoration.
 */
export const useStore = create<StudentStore>()(
  persist(
    (set, get) => ({
      studentId: null,
      studentName: null,
      authToken: null,
      activeLectureId: null,
      focusActive: false,
      strikes: 0,
      isDark: false,

      setStudentId: (id) => set({ studentId: id }),
      setStudentName: (name) => set({ studentName: name }),
      setAuthToken: (token) => {
        set({ authToken: token });
        if (token) setAPIAuthToken(token);
      },
      setActiveLectureId: (id) => set({ activeLectureId: id }),
      setFocusActive: (active) => set({ focusActive: active }),
      setStrikes: (count) =>
        set((state) => ({
          strikes: typeof count === "function" ? count(state.strikes) : count,
        })),

      setIsDark: (dark) => set({ isDark: dark }),

      toggleDark: () => {
        const next = !get().isDark;
        set({ isDark: next });
      },

      reset: () =>
        set({
          studentId: null,
          studentName: null,
          authToken: null,
          activeLectureId: null,
          focusActive: false,
          strikes: 0,
        }),
    }),
    {
      name: "student-app-storage",
      storage: createJSONStorage(() => AsyncStorage),
      // Persist auth and preferences
      partialize: (state) => ({
        isDark: state.isDark,
        studentId: state.studentId,
        studentName: state.studentName,
        authToken: state.authToken
      }),
      onRehydrateStorage: () => (state) => {
        // Restore API token on app load if found in storage
        if (state?.authToken) {
          setAPIAuthToken(state.authToken);
        }
      },
    }
  )
);
