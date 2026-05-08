import { create } from "zustand";
import AsyncStorage from "@react-native-async-storage/async-storage";

interface StudentStore {
  studentId: string | null;
  activeLectureId: string | null;
  focusActive: boolean;
  strikes: number;
  isDark: boolean;

  setStudentId: (id: string) => void;
  setActiveLectureId: (id: string) => void;
  setFocusActive: (active: boolean) => void;
  setStrikes: (count: number | ((prev: number) => number)) => void;
  setIsDark: (dark: boolean) => void;
  toggleDark: () => void;
  reset: () => void;
}

/**
 * Zustand store for managing student app state
 * Persists across screen navigation
 */
export const useStore = create<StudentStore>((set, get) => ({
  studentId: null,
  activeLectureId: null,
  focusActive: false,
  strikes: 0,
  isDark: false,

  setStudentId: (id) => set({ studentId: id }),
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
    AsyncStorage.setItem("dark_mode", next ? "1" : "0");
  },

  reset: () =>
    set({
      studentId: null,
      activeLectureId: null,
      focusActive: false,
      strikes: 0,
    }),
}));
