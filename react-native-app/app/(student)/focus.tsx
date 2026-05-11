import React, { useEffect, useMemo, useRef, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  AppState,
  AppStateStatus,
  ScrollView,
  SafeAreaView,
  Modal,
  TouchableOpacity,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { wsAPI } from "@/services/api";
import { useStore } from "@/store/useStore";
import FocusOverlay from "@/components/FocusOverlay";
import { Colors, DarkColors, Radius, Shadow, Spacing } from "@/constants/theme";

export default function FocusScreen() {
  const { studentId, activeLectureId, focusActive, strikes, setStrikes, isDark } =
    useStore();
  const C = isDark ? DarkColors : Colors;
  const styles = useMemo(() => makeStyles(C), [isDark]);

  const appStateRef = useRef<AppStateStatus>(AppState.currentState);
  const strikesRef = useRef(strikes);
  const [appState, setAppState] = useState<AppStateStatus>(AppState.currentState);
  const [logs, setLogs] = useState<Array<{ time: string; state: string }>>([]);
  const [showOverlay, setShowOverlay] = useState(false);
  const [freshBrainerQ, setFreshBrainerQ] = useState<string | null>(null);

  useEffect(() => {
    strikesRef.current = strikes;
  }, [strikes]);

  useEffect(() => {
    const subscription = AppState.addEventListener("change", handleAppStateChange);
    return () => subscription.remove();
  }, [focusActive, activeLectureId]);

  // Listen for Fresh Brainer questions broadcast by lecturer
  useEffect(() => {
    const unsubscribe = wsAPI.onMessage((data) => {
      if (data.type === "freshbrainer" && data.question) {
        setFreshBrainerQ(data.question as string);
      }
    });
    return unsubscribe;
  }, []);

  const handleAppStateChange = (nextAppState: AppStateStatus) => {
    const prev = appStateRef.current;
    appStateRef.current = nextAppState;

    const time = new Date().toLocaleTimeString("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    });

    setLogs((prev) =>
      [{ time, state: nextAppState }, ...prev].slice(0, 20)
    );
    setAppState(nextAppState);

    if (prev === "active" && nextAppState !== "active" && focusActive) {
      handleFocusStrike(nextAppState);
    }
  };

  const handleFocusStrike = (state: AppStateStatus) => {
    const next = strikesRef.current + 1;
    strikesRef.current = next;
    setStrikes(next);
    setShowOverlay(true);

    if (studentId && activeLectureId) {
      wsAPI.emitStrike(studentId, activeLectureId, "app_background");
    }
  };

  const isActive = focusActive && !!activeLectureId;

  return (
    <SafeAreaView style={styles.root}>
      {/* ── Header ──────────────────────────────────── */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Focus Mode</Text>
        <View style={[styles.statusBadge, isActive ? styles.statusActive : styles.statusInactive]}>
          <View style={[styles.statusDot, { backgroundColor: isActive ? "#4ADE80" : "#F87171" }]} />
          <Text style={styles.statusText}>{isActive ? "Active" : "Inactive"}</Text>
        </View>
      </View>

      <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollContent}>

        {/* ── Stats Row ────────────────────────────────── */}
        <View style={styles.statsRow}>
          <View style={styles.statCard}>
            <Ionicons name="person-outline" size={18} color={C.navy} />
            <Text style={styles.statLabel}>Student</Text>
            <Text style={styles.statValue}>{studentId ?? "—"}</Text>
          </View>
          <View style={styles.statCard}>
            <Ionicons name="library-outline" size={18} color={C.navy} />
            <Text style={styles.statLabel}>Lecture</Text>
            <Text style={styles.statValue}>{activeLectureId ?? "None"}</Text>
          </View>
          <View
            style={[
              styles.statCard,
              strikes > 0 && { backgroundColor: isDark ? "#3D0000" : "#FEF2F2" },
            ]}
          >
            <Ionicons name="warning-outline" size={18} color={strikes > 0 ? C.error : C.navy} />
            <Text style={styles.statLabel}>Strikes</Text>
            <Text style={[styles.statValue, strikes > 0 && { color: C.error }]}>
              {strikes}
            </Text>
          </View>
        </View>

        {/* ── App State Indicator ──────────────────────── */}
        <View style={styles.appStateCard}>
          <View style={styles.appStateRow}>
            <Ionicons
              name={appState === "active" ? "phone-portrait" : "phone-portrait-outline"}
              size={22}
              color={appState === "active" ? C.success : C.textMuted}
            />
            <View>
              <Text style={styles.appStateLabel}>Current App State</Text>
              <Text
                style={[
                  styles.appStateValue,
                  { color: appState === "active" ? C.success : C.error },
                ]}
              >
                {appState.toUpperCase()}
              </Text>
            </View>
          </View>
        </View>

        {/* ── Info Banner ─────────────────────────────── */}
        {!isActive && (
          <View
            style={[
              styles.infoBanner,
              { backgroundColor: isDark ? "#0F2044" : "#EFF6FF" },
            ]}
          >
            <Ionicons
              name="information-circle-outline"
              size={18}
              color={isDark ? "#60A5FA" : "#3B82F6"}
            />
            <Text style={[styles.infoText, { color: isDark ? "#60A5FA" : "#1D4ED8" }]}>
              Join a lecture from the Home tab to activate focus mode.
            </Text>
          </View>
        )}

        {/* ── Transition Log ───────────────────────────── */}
        <Text style={styles.sectionTitle}>AppState Log</Text>
        <View style={styles.logCard}>
          {logs.length === 0 ? (
            <Text style={styles.emptyLog}>No transitions yet</Text>
          ) : (
            logs.map((log, i) => (
              <View key={i} style={styles.logRow}>
                <Text style={styles.logTime}>{log.time}</Text>
                <View
                  style={[
                    styles.logBadge,
                    {
                      backgroundColor:
                        log.state === "active"
                          ? (isDark ? "#052E16" : "#D1FAE5")
                          : (isDark ? "#3D0000" : "#FEE2E2"),
                    },
                  ]}
                >
                  <Text
                    style={[
                      styles.logState,
                      {
                        color:
                          log.state === "active"
                            ? (isDark ? "#4ADE80" : "#065F46")
                            : (isDark ? "#F87171" : "#991B1B"),
                      },
                    ]}
                  >
                    {log.state}
                  </Text>
                </View>
              </View>
            ))
          )}
        </View>
      </ScrollView>

      {/* ── FocusOverlay (appears on strike) ────────── */}
      {showOverlay && (
        <FocusOverlay
          strikes={strikes}
          onDismiss={() => setShowOverlay(false)}
        />
      )}

      {/* ── Fresh Brainer modal (question from lecturer) ── */}
      <Modal
        visible={!!freshBrainerQ}
        transparent
        animationType="slide"
        onRequestClose={() => setFreshBrainerQ(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalCard, { backgroundColor: C.white }]}>
            <View style={styles.modalHeader}>
              <Ionicons name="bulb" size={22} color={C.gold} />
              <Text style={[styles.modalTitle, { color: C.navy }]}>
                Question from Lecturer
              </Text>
            </View>
            <Text style={[styles.modalQuestion, { color: C.textPrimary }]}>
              {freshBrainerQ}
            </Text>
            <TouchableOpacity
              style={[styles.modalBtn, { backgroundColor: C.navy }]}
              onPress={() => setFreshBrainerQ(null)}
            >
              <Text style={styles.modalBtnText}>Got it</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const makeStyles = (C: typeof Colors) => StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: C.background,
  },
  header: {
    backgroundColor: C.navy,
    paddingHorizontal: Spacing.md,
    paddingTop: 16,
    paddingBottom: 16,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: "bold",
    color: Colors.white,
  },
  statusBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: Radius.xl,
  },
  statusActive: { backgroundColor: "#14532D" },
  statusInactive: { backgroundColor: "#7F1D1D" },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  statusText: { fontSize: 12, fontWeight: "600", color: Colors.white },

  scroll: { flex: 1 },
  scrollContent: { padding: Spacing.md, paddingBottom: 32 },

  /* Stats */
  statsRow: {
    flexDirection: "row",
    gap: 10,
    marginBottom: Spacing.md,
  },
  statCard: {
    flex: 1,
    backgroundColor: C.white,
    borderRadius: Radius.md,
    padding: 12,
    alignItems: "center",
    gap: 4,
    ...Shadow.card,
  },
  statLabel: {
    fontSize: 10,
    color: C.textMuted,
    fontWeight: "600",
    textTransform: "uppercase",
  },
  statValue: {
    fontSize: 14,
    fontWeight: "700",
    color: C.textPrimary,
  },

  /* App State */
  appStateCard: {
    backgroundColor: C.white,
    borderRadius: Radius.md,
    padding: Spacing.md,
    marginBottom: Spacing.md,
    ...Shadow.card,
  },
  appStateRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  appStateLabel: {
    fontSize: 11,
    color: C.textMuted,
    fontWeight: "600",
  },
  appStateValue: {
    fontSize: 16,
    fontWeight: "800",
    letterSpacing: 1,
  },

  /* Info banner */
  infoBanner: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 8,
    borderRadius: Radius.md,
    padding: 12,
    marginBottom: Spacing.md,
  },
  infoText: {
    flex: 1,
    fontSize: 13,
    lineHeight: 18,
  },

  /* Log */
  sectionTitle: {
    fontSize: 15,
    fontWeight: "700",
    color: C.textPrimary,
    marginBottom: 8,
  },
  logCard: {
    backgroundColor: C.white,
    borderRadius: Radius.md,
    padding: Spacing.md,
    ...Shadow.card,
  },
  logRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
  },
  logTime: {
    fontSize: 12,
    color: C.textSecondary,
    fontFamily: "monospace",
  },
  logBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: Radius.sm,
  },
  logState: {
    fontSize: 11,
    fontWeight: "700",
    textTransform: "uppercase",
  },
  emptyLog: {
    fontSize: 13,
    color: C.textMuted,
    textAlign: "center",
    paddingVertical: 16,
    fontStyle: "italic",
  },

  /* Fresh Brainer modal */
  modalOverlay: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.55)",
    justifyContent: "flex-end",
  },
  modalCard: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 24,
    paddingBottom: 40,
    gap: 16,
    ...Shadow.card,
  },
  modalHeader: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
  },
  modalTitle: {
    fontSize: 16,
    fontWeight: "700",
  },
  modalQuestion: {
    fontSize: 15,
    lineHeight: 22,
  },
  modalBtn: {
    borderRadius: Radius.xl,
    paddingVertical: 13,
    alignItems: "center",
    marginTop: 4,
  },
  modalBtnText: {
    color: Colors.white,
    fontWeight: "700",
    fontSize: 15,
  },
});
