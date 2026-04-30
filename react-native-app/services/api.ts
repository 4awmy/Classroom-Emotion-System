import axios, { AxiosInstance } from "axios";

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

// Native WebSocket client (compatible with FastAPI standard WS endpoints)
let wsConnection: WebSocket | null = null;
type FocusStrikeMessage = {
  type: "focus_strike";
  student_id: string;
  lecture_id: string;
  strike_type: string;
  timestamp: string;
};

const pendingStrikeMessages: FocusStrikeMessage[] = [];

const sendJson = (message: FocusStrikeMessage) => {
  wsConnection?.send(JSON.stringify(message));
};

export const connectWebSocket = (): WebSocket => {
  if (
    wsConnection &&
    (wsConnection.readyState === WebSocket.OPEN ||
      wsConnection.readyState === WebSocket.CONNECTING)
  ) {
    return wsConnection;
  }

  const wsEndpoint = WS_URL.endsWith("/session/ws")
    ? WS_URL
    : `${WS_URL.replace(/\/$/, "")}/session/ws`;
  console.log("[API] Connecting to WebSocket:", wsEndpoint);
  wsConnection = new WebSocket(wsEndpoint);

  wsConnection.onopen = () => {
    console.log("[WebSocket] Connected");
    while (
      pendingStrikeMessages.length > 0 &&
      wsConnection?.readyState === WebSocket.OPEN
    ) {
      const message = pendingStrikeMessages.shift();
      if (message) {
        sendJson(message);
      }
    }
  };

  wsConnection.onclose = () => {
    console.log("[WebSocket] Disconnected");
  };

  wsConnection.onerror = (error) => {
    console.error("[WebSocket] Connection error:", error);
  };

  wsConnection.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data as string);
      console.log("[WebSocket] Message received:", data);
    } catch {
      console.log("[WebSocket] Raw message:", event.data);
    }
  };

  return wsConnection;
};

export const getWebSocket = (): WebSocket | null => wsConnection;

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
  emitStrike: (
    studentId: string,
    lectureId: string,
    strikeType: string,
  ): boolean => {
    const ws = getWebSocket();
    const message: FocusStrikeMessage = {
      type: "focus_strike",
      student_id: studentId,
      lecture_id: lectureId,
      strike_type: strikeType,
      timestamp: new Date().toISOString(),
    };

    if (ws?.readyState === WebSocket.OPEN) {
      sendJson(message);
      console.log("[WebSocket] Strike emitted:", message);
      return true;
    }

    pendingStrikeMessages.push(message);
    connectWebSocket();
    console.log("[WebSocket] Strike queued:", message);
    return false;
  },
};
