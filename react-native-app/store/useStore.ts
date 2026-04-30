import { create } from "zustand";

interface StudentStore {
  studentId: string | null;
  activeLectureId: string | null;
  focusActive: boolean;
  strikes: number;
  caption: string | null;

  setStudentId: (id: string) => void;
  setActiveLectureId: (id: string) => void;
  setFocusActive: (active: boolean) => void;
  setStrikes: (count: number | ((prev: number) => number)) => void;
  setCaption: (text: string | null) => void;
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
  caption: null,

  setStudentId: (id) => set({ studentId: id }),
  setActiveLectureId: (id) => set({ activeLectureId: id }),
  setFocusActive: (active) => set({ focusActive: active }),
  setStrikes: (count) =>
    set((state) => ({
      strikes: typeof count === "function" ? count(state.strikes) : count,
    })),
  setCaption: (text) => set({ caption: text }),

  reset: () =>
    set({
      studentId: null,
      activeLectureId: null,
      focusActive: false,
      strikes: 0,
      caption: null,
    }),
}));
