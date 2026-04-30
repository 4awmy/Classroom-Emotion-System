import React, { useEffect, useRef, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  AppState,
  AppStateStatus,
  ScrollView,
  Alert,
} from "react-native";
import { useStore } from "@/store/useStore";

/**
 * Focus Mode Screen (P1-S4-05)
 *
 * Logs AppState changes (background/foreground transitions)
 * Tracks focus strikes when app goes to background
 */
export default function FocusScreen() {
  const { studentId, activeLectureId, focusActive, strikes, setStrikes } =
    useStore();

  // useRef avoids the stale-closure problem: the subscription registered in
  // useEffect always reads the *current* app state via the ref, regardless of
  // how many re-renders have occurred since the subscription was created.
  const appStateRef = useRef<AppStateStatus>(AppState.currentState);
  const [appState, setAppState] = useState<AppStateStatus>(
    AppState.currentState,
  );
  const [logs, setLogs] = useState<Array<{ time: string; state: string }>>([]);

  /**
   * Monitor AppState changes
   * Logs: "2025-04-30 10:45:23 → background" when app goes to background
   * Logs: "2025-04-30 10:45:30 → active" when app returns to foreground
   */
  useEffect(() => {
    console.log("[FocusMode] Setting up AppState listener");

    const subscription = AppState.addEventListener(
      "change",
      handleAppStateChange,
    );

    return () => {
      console.log("[FocusMode] Removing AppState listener");
      subscription.remove();
    };
  }, [focusActive, activeLectureId]);

  const handleAppStateChange = (nextAppState: AppStateStatus) => {
    // Read previous state from the ref — always current, never stale.
    const previousAppState = appStateRef.current;
    appStateRef.current = nextAppState;

    const timestamp = new Date().toLocaleTimeString("en-US", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    });

    // Log the transition
    const transitionLog = `${timestamp} → ${nextAppState}`;
    console.log("[FocusMode] AppState change:", transitionLog);

    // Update logs display (keep last 20)
    setLogs((prevLogs) =>
      [{ time: timestamp, state: nextAppState }, ...prevLogs].slice(0, 20),
    );

    setAppState(nextAppState);

    /**
     * When app goes to background during active focus mode:
     * - Increment strike counter
     * - Emit WebSocket strike event (Phase 2)
     * - Alert lecturer in real-time
     */
    if (
      previousAppState === "active" &&
      nextAppState !== "active" &&
      focusActive
    ) {
      handleFocusStrike(nextAppState);
    }
  };

  const handleFocusStrike = (state: AppStateStatus) => {
    const timestamp = new Date().toLocaleTimeString("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    });

    console.log("[FocusMode] ⚠️  STRIKE RECORDED:", {
      student_id: studentId,
      lecture_id: activeLectureId,
      type: "app_background",
      state,
      timestamp,
    });

    // Increment strike counter
    setStrikes((prev) => prev + 1);

    // TODO: Phase 2 - Emit WebSocket strike event
    // socket.emit('strike', {
    //   student_id: studentId,
    //   lecture_id: activeLectureId,
    //   type: 'app_background',
    // });

    // Show local alert (can be removed in production)
    Alert.alert(
      "Focus Mode Alert",
      `App went to ${state}. Strike #${strikes + 1} recorded.`,
      [{ text: "OK", onPress: () => {} }],
      { cancelable: false },
    );
  };

  return (
    <ScrollView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Focus Mode</Text>
        <Text style={styles.subtitle}>
          {focusActive ? "🟢 Active" : "🔴 Inactive"}
        </Text>
      </View>

      {/* Status Cards */}
      <View style={styles.statusSection}>
        <View style={styles.statusCard}>
          <Text style={styles.statusLabel}>Student ID</Text>
          <Text style={styles.statusValue}>{studentId || "N/A"}</Text>
        </View>

        <View style={styles.statusCard}>
          <Text style={styles.statusLabel}>Lecture ID</Text>
          <Text style={styles.statusValue}>{activeLectureId || "None"}</Text>
        </View>

        <View
          style={[
            styles.statusCard,
            { backgroundColor: strikes > 0 ? "#ffebee" : "#e8f5e9" },
          ]}
        >
          <Text style={styles.statusLabel}>Strikes</Text>
          <Text
            style={[
              styles.statusValue,
              { color: strikes > 0 ? "#c62828" : "#2e7d32" },
            ]}
          >
            {strikes}
          </Text>
        </View>

        <View style={styles.statusCard}>
          <Text style={styles.statusLabel}>Current State</Text>
          <Text style={styles.statusValue}>{appState}</Text>
        </View>
      </View>

      {/* AppState Logs */}
      <View style={styles.logsSection}>
        <Text style={styles.logsTitle}>AppState Transition Log</Text>
        <View style={styles.logsList}>
          {logs.length === 0 ? (
            <Text style={styles.noLogs}>No transitions logged yet</Text>
          ) : (
            logs.map((log, index) => (
              <View key={index} style={styles.logEntry}>
                <Text style={styles.logTime}>{log.time}</Text>
                <Text
                  style={[
                    styles.logState,
                    {
                      color: log.state === "active" ? "#2e7d32" : "#c62828",
                    },
                  ]}
                >
                  {log.state}
                </Text>
              </View>
            ))
          )}
        </View>
      </View>

      {/* Info Section */}
      <View style={styles.infoSection}>
        <Text style={styles.infoTitle}>How It Works</Text>
        <Text style={styles.infoText}>
          • Monitors when your app goes to background/foreground{"\n"}• Each
          background transition = 1 strike{"\n"}• Strikes are logged in
          real-time{"\n"}• Lecturer receives live notifications
        </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
    padding: 16,
  },
  header: {
    marginBottom: 24,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#e0e0e0",
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#002147", // AAST navy
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: "#666",
  },
  statusSection: {
    marginBottom: 24,
  },
  statusCard: {
    backgroundColor: "#fff",
    padding: 12,
    marginBottom: 8,
    borderRadius: 8,
    borderLeftWidth: 4,
    borderLeftColor: "#002147",
  },
  statusLabel: {
    fontSize: 12,
    color: "#999",
    fontWeight: "600",
    marginBottom: 4,
  },
  statusValue: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#333",
  },
  logsSection: {
    backgroundColor: "#fff",
    borderRadius: 8,
    padding: 12,
    marginBottom: 24,
  },
  logsTitle: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#002147",
    marginBottom: 12,
  },
  logsList: {
    maxHeight: 300,
  },
  logEntry: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 8,
    paddingHorizontal: 8,
    marginBottom: 4,
    backgroundColor: "#f9f9f9",
    borderRadius: 4,
    borderLeftWidth: 3,
    borderLeftColor: "#002147",
  },
  logTime: {
    fontSize: 12,
    color: "#666",
    fontFamily: "monospace",
  },
  logState: {
    fontSize: 13,
    fontWeight: "600",
    textTransform: "uppercase",
  },
  noLogs: {
    fontSize: 14,
    color: "#999",
    fontStyle: "italic",
    textAlign: "center",
    paddingVertical: 16,
  },
  infoSection: {
    backgroundColor: "#e3f2fd",
    borderRadius: 8,
    padding: 12,
    marginBottom: 24,
  },
  infoTitle: {
    fontSize: 14,
    fontWeight: "bold",
    color: "#1565c0",
    marginBottom: 8,
  },
  infoText: {
    fontSize: 13,
    color: "#0d47a1",
    lineHeight: 20,
  },
});
