import { create } from "zustand";

interface StudentStore {
  studentId: string | null;
  activeLectureId: string | null;
  focusActive: boolean;
  strikes: number;

  setStudentId: (id: string) => void;
  setActiveLectureId: (id: string) => void;
  setFocusActive: (active: boolean) => void;
  setStrikes: (count: number | ((prev: number) => number)) => void;
  reset: () => void;
}

/**
 * Zustand store for managing student app state
 * Persists across screen navigation
 */
export const useStore = create<StudentStore>((set) => ({
  studentId: null,
  activeLectureId: null,
  focusActive: false,
  strikes: 0,

  setStudentId: (id) => set({ studentId: id }),
  setActiveLectureId: (id) => set({ activeLectureId: id }),
  setFocusActive: (active) => set({ focusActive: active }),
  setStrikes: (count) =>
    set((state) => ({
      strikes: typeof count === "function" ? count(state.strikes) : count,
    })),

  reset: () =>
    set({
      studentId: null,
      activeLectureId: null,
      focusActive: false,
      strikes: 0,
    }),
}));
