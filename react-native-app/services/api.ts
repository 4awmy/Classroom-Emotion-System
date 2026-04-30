import axios, { AxiosInstance } from "axios";
import { io, Socket } from "socket.io-client";

const API_URL = process.env.EXPO_PUBLIC_API_URL || "http://localhost:8000";
const WS_URL = process.env.EXPO_PUBLIC_WS_URL || "ws://localhost:8000";

export const apiClient: AxiosInstance = axios.create({
  baseURL: API_URL,
  timeout: 10000,
});

// Add JWT token to request headers if available
let authToken: string | null = null;

export const setAuthToken = (token: string) => {
  authToken = token;
  apiClient.defaults.headers.common["Authorization"] = `Bearer ${token}`;
};

apiClient.interceptors.request.use((config) => {
  if (authToken) {
    config.headers.Authorization = `Bearer ${authToken}`;
  }
  return config;
});

// WebSocket client
let socket: Socket | null = null;

export const connectWebSocket = (): Socket => {
  if (socket?.connected) return socket;

  console.log("[API] Connecting to WebSocket:", WS_URL);
  socket = io(WS_URL, {
    transports: ["websocket"],
    reconnection: true,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000,
    reconnectionAttempts: 5,
  });

  socket.on("connect", () => {
    console.log("[WebSocket] Connected:", socket?.id);
  });

  socket.on("disconnect", () => {
    console.log("[WebSocket] Disconnected");
  });

  socket.on("connect_error", (error) => {
    console.error("[WebSocket] Connection error:", error);
  });

  return socket;
};

export const getWebSocket = (): Socket | null => socket;

/**
 * API Service Methods (P1-S3 stubs)
 * These will be implemented in Phase 2
 */

export const authAPI = {
  login: async (studentId: string, password: string) => {
    const response = await apiClient.post("/auth/login", {
      student_id: studentId,
      password,
    });
    return response.data;
  },
};

export const sessionAPI = {
  getUpcoming: async () => {
    const response = await apiClient.get("/session/upcoming");
    return response.data;
  },
  start: async (lectureId: string) => {
    const response = await apiClient.post("/session/start", {
      lecture_id: lectureId,
    });
    return response.data;
  },
  end: async (lectureId: string) => {
    const response = await apiClient.post("/session/end", {
      lecture_id: lectureId,
    });
    return response.data;
  },
};

export const notesAPI = {
  get: async (studentId: string, lectureId: string) => {
    const response = await apiClient.get(`/notes/${studentId}/${lectureId}`);
    return response.data;
  },
  getPlan: async (studentId: string) => {
    const response = await apiClient.get(`/notes/${studentId}/plan`);
    return response.data;
  },
};

// WebSocket events wrapper
export const wsAPI = {
  emitStrike: (studentId: string, lectureId: string, type: string) => {
    const ws = getWebSocket();
    if (ws?.connected) {
      ws.emit("strike", {
        student_id: studentId,
        lecture_id: lectureId,
        type,
      });
      console.log("[WebSocket] Strike emitted:", {
        studentId,
        lectureId,
        type,
      });
    }
  },
};
