import React, { useEffect, useRef, useState, useMemo } from "react";
import {
  View,
  Text,
  StyleSheet,
  AppState,
  AppStateStatus,
  Alert,
  ScrollView,
  SafeAreaView,
  TouchableOpacity,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { wsAPI, examAPI } from "@/services/api";
import { useStore } from "@/store/useStore";
import { Colors, DarkColors, Radius, Shadow, Spacing } from "@/constants/theme";

export default function ExamScreen() {
  const { studentId, activeLectureId, isDark } = useStore();
  const C = isDark ? DarkColors : Colors;
  const styles = useMemo(() => makeStyles(C), [isDark]);
  const router = useRouter();

  const [examId, setExamId] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [incidents, setIncidents] = useState<string[]>([]);
  const [elapsedSeconds, setElapsed] = useState(0);
  const [severity3Count, setSeverity3Count] = useState(0);

  const appStateRef = useRef<AppStateStatus>(AppState.currentState);
  const severity3Ref = useRef(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Format elapsed time as HH:MM:SS
  const formatTime = (s: number) => {
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const sec = s % 60;
    return [h, m, sec].map((v) => String(v).padStart(2, "0")).join(":");
  };

  // Start exam on mount
  useEffect(() => {
    const id = activeLectureId ?? `EXAM_${Date.now()}`;
    setExamId(id);

    examAPI.start(id, studentId ?? "unknown").catch(() => {});

    timerRef.current = setInterval(() => setElapsed((e) => e + 1), 1000);

    const sub = AppState.addEventListener("change", handleAppState);

    // Listen for auto-submit from backend via WebSocket
    const unsubWS = wsAPI.onMessage((msg) => {
      if (msg.type === "exam:autosubmit" && msg.exam_id === id) {
        handleAutoSubmit();
      }
    });

    return () => {
      sub.remove();
      unsubWS();
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, []);

  const handleAppState = (next: AppStateStatus) => {
    const prev = appStateRef.current;
    appStateRef.current = next;

    if (prev === "active" && next !== "active" && !submitted) {
      // Log app_background incident (severity 1)
      wsAPI.emitStrike(studentId ?? "", examId ?? "", "app_background", "exam");
      addIncident("App went to background", 1);
    }
  };

  const addIncident = (description: string, severity: number) => {
    setIncidents((prev) => [
      `[${new Date().toLocaleTimeString()}] ${description} (Sev ${severity})`,
      ...prev,
    ]);
    if (severity === 3) {
      const newCount = severity3Ref.current + 1;
      severity3Ref.current = newCount;
      setSeverity3Count(newCount);
      // Auto-submit if 3 severity-3 incidents
      if (newCount >= 3) handleAutoSubmit();
    }
  };

  const handleAutoSubmit = () => {
    if (submitted) return;
    setSubmitted(true);
    if (timerRef.current) clearInterval(timerRef.current);
    examAPI.submit(examId ?? "", studentId ?? "").catch(() => {});
    Alert.alert(
      "Exam Auto-Submitted",
      "Your exam was automatically submitted due to repeated violations.",
      [{ text: "OK", onPress: () => router.replace("/(student)/home") }]
    );
  };

  const handleManualSubmit = () => {
    Alert.alert("Submit Exam", "Are you sure you want to submit?", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Submit",
        style: "destructive",
        onPress: () => {
          setSubmitted(true);
          if (timerRef.current) clearInterval(timerRef.current);
          examAPI.submit(examId ?? "", studentId ?? "").catch(() => {});
          router.replace("/(student)/home");
        },
      },
    ]);
  };

  if (submitted) {
    return (
      <SafeAreaView style={[styles.container, { justifyContent: "center", alignItems: "center" }]}>
        <Ionicons name="checkmark-circle" size={80} color={C.success} />
        <Text style={styles.submittedTitle}>Exam Submitted</Text>
        <Text style={styles.submittedSub}>Your responses have been recorded.</Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>Exam Mode</Text>
          <Text style={styles.headerSub}>ID: {studentId ?? "—"}</Text>
        </View>
        <View style={styles.timerBox}>
          <Ionicons name="time-outline" size={16} color={C.gold} />
          <Text style={styles.timerText}>{formatTime(elapsedSeconds)}</Text>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Status Card */}
        <View style={styles.card}>
          <View style={styles.cardRow}>
            <Ionicons name="shield-checkmark" size={22} color={C.success} />
            <Text style={styles.cardTitle}>Exam In Progress</Text>
          </View>
          <Text style={styles.cardSub}>
            You are being monitored. Keep your eyes on your screen and your device flat on the desk.
          </Text>
        </View>

        {/* Violation counter */}
        <View style={[styles.card, severity3Count >= 2 && styles.cardDanger]}>
          <View style={styles.cardRow}>
            <Ionicons
              name="warning"
              size={22}
              color={severity3Count >= 2 ? C.error : C.warning}
            />
            <Text style={[styles.cardTitle, severity3Count >= 2 && { color: C.error }]}>
              Severity Violations: {severity3Count} / 3
            </Text>
          </View>
          {severity3Count >= 2 && (
            <Text style={{ color: C.error, fontSize: 13, marginTop: 4 }}>
              ⚠ Next violation will auto-submit your exam.
            </Text>
          )}
        </View>

        {/* Rules */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Exam Rules</Text>
          {[
            "Keep this app in the foreground at all times",
            "Do not place any phone or device on the desk",
            "Keep your head facing forward",
            "Only one person should be visible to the camera",
            "Identity mismatch will be flagged immediately",
          ].map((rule, i) => (
            <View key={i} style={styles.ruleRow}>
              <Ionicons name="alert-circle-outline" size={16} color={C.gold} />
              <Text style={styles.ruleText}>{rule}</Text>
            </View>
          ))}
        </View>

        {/* Incident Log */}
        {incidents.length > 0 && (
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Incident Log</Text>
            {incidents.slice(0, 10).map((inc, i) => (
              <Text key={i} style={styles.incidentText}>
                {inc}
              </Text>
            ))}
          </View>
        )}
      </ScrollView>

      {/* Submit Button */}
      <View style={styles.footer}>
        <TouchableOpacity style={styles.submitBtn} onPress={handleManualSubmit}>
          <Ionicons name="send" size={18} color="#fff" />
          <Text style={styles.submitText}>Submit Exam</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const makeStyles = (C: typeof Colors) =>
  StyleSheet.create({
    container: { flex: 1, backgroundColor: C.navy },
    header: {
      flexDirection: "row",
      justifyContent: "space-between",
      alignItems: "center",
      paddingHorizontal: Spacing.lg,
      paddingVertical: Spacing.md,
      borderBottomWidth: 1,
      borderBottomColor: "#1E3A5F",
    },
    headerTitle: { color: "#fff", fontSize: 20, fontWeight: "700" },
    headerSub: { color: C.gold, fontSize: 13, marginTop: 2 },
    timerBox: { flexDirection: "row", alignItems: "center", gap: 6 },
    timerText: { color: C.gold, fontSize: 18, fontWeight: "700", fontVariant: ["tabular-nums"] },
    scroll: { padding: Spacing.lg, gap: Spacing.md },
    card: {
      backgroundColor: C.white,
      borderRadius: Radius.lg,
      padding: Spacing.lg,
      ...Shadow.card,
    },
    cardDanger: { borderWidth: 1, borderColor: C.error },
    cardRow: { flexDirection: "row", alignItems: "center", gap: 8, marginBottom: 8 },
    cardTitle: { fontSize: 16, fontWeight: "600", color: C.textPrimary, flex: 1 },
    cardSub: { fontSize: 13, color: C.textSecondary, lineHeight: 20 },
    sectionTitle: { fontSize: 14, fontWeight: "700", color: C.navy, marginBottom: 10 },
    ruleRow: { flexDirection: "row", alignItems: "flex-start", gap: 8, marginBottom: 6 },
    ruleText: { fontSize: 13, color: C.textSecondary, flex: 1, lineHeight: 18 },
    incidentText: { fontSize: 12, color: C.error, marginBottom: 4, fontFamily: "monospace" },
    footer: { padding: Spacing.lg, borderTopWidth: 1, borderTopColor: "#1E3A5F" },
    submitBtn: {
      backgroundColor: C.error,
      borderRadius: Radius.md,
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "center",
      gap: 8,
      paddingVertical: 14,
    },
    submitText: { color: "#fff", fontSize: 16, fontWeight: "700" },
    submittedTitle: { fontSize: 24, fontWeight: "700", color: "#fff", marginTop: 16 },
    submittedSub: { fontSize: 14, color: C.textSecondary, marginTop: 8 },
  });
