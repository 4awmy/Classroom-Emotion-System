import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
} from "react-native";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { useStore } from "@/store/useStore";
import { sessionAPI, wsAPI } from "@/services/api";
import { Colors, DarkColors, Radius, Shadow, Spacing } from "@/constants/theme";

interface Lecture {
  lecture_id: string;
  title: string;
  subject: string;
  start_time: string;
  lecturer_id: string;
}

const ACTIVITIES_LIGHT = [
  { key: "focus", icon: "eye",      label: "Focus Mode",  color: "#EEF2FF", iconColor: "#4F46E5" },
  { key: "notes", icon: "book",     label: "Smart Notes", color: "#F0FDF4", iconColor: "#16A34A" },
  { key: "scan",  icon: "qr-code",  label: "Scan QR",     color: "#FFF7ED", iconColor: "#EA580C" },
];

const ACTIVITIES_DARK = [
  { key: "focus", icon: "eye",      label: "Focus Mode",  color: "#1E2460", iconColor: "#818CF8" },
  { key: "notes", icon: "book",     label: "Smart Notes", color: "#052E16", iconColor: "#4ADE80" },
  { key: "scan",  icon: "qr-code",  label: "Scan QR",     color: "#3D1A00", iconColor: "#FB923C" },
];

export default function HomeScreen() {
  const router = useRouter();
  const { studentId, studentName, activeLectureId, setActiveLectureId, setActiveExamId, setFocusActive, isDark, toggleDark } = useStore();
  const C = isDark ? DarkColors : Colors;
  const styles = useMemo(() => makeStyles(C), [isDark]);
  const ACTIVITIES = isDark ? ACTIVITIES_DARK : ACTIVITIES_LIGHT;

  const [lectures, setLectures] = useState<Lecture[]>([]);
  const [loading, setLoading] = useState(true);
  const activeLectureIdRef = useRef(useStore.getState().activeLectureId);

  // Keep ref in sync so WS handler always has the latest value without re-subscribing
  useEffect(() => {
    activeLectureIdRef.current = activeLectureId;
  }, [activeLectureId]);

  const loadUpcomingLectures = useCallback(async (silent = false) => {
    try {
      if (!silent) setLoading(true);
      const response = await sessionAPI.getUpcoming(studentId ?? undefined);
      setLectures(Array.isArray(response) ? response : []);
    } catch {
      setLectures([]);
    } finally {
      setLoading(false);
    }
  }, [studentId]);

  // Initial load
  useEffect(() => { loadUpcomingLectures(); }, [loadUpcomingLectures]);

  // WebSocket sync: react to session:start and session:end broadcasts from Shiny
  useEffect(() => {
    const unsubscribe = wsAPI.onMessage((data) => {
      if (data.type === "session:start") {
        // Refresh list so the new live lecture appears instantly
        loadUpcomingLectures(true);
        const lid = data.lecture_id as string | undefined;
        Alert.alert(
          "Session Started",
          `A lecture has just gone live${lid ? ` (${lid})` : ""}.\nTap Join to activate focus mode.`,
          [{ text: "OK" }]
        );
      }

      if (data.type === "exam:start") {
        const examId = data.exam_id as string | undefined;
        if (examId) setActiveExamId(examId);
        Alert.alert(
          "Exam Started",
          `An exam has begun${data.title ? `: ${data.title}` : ""}.\nPlease go to the Exam screen.`,
          [
            { text: "Go to Exam", onPress: () => router.push("/(student)/exam") },
            { text: "Later", style: "cancel" },
          ]
        );
      }

      if (data.type === "session:end") {
        const lid = data.lecture_id as string | undefined;
        // Deactivate focus if this was the student's active lecture
        if (lid && lid === activeLectureIdRef.current) {
          setActiveLectureId(null);
          setFocusActive(false);
          Alert.alert("Session Ended", "The lecturer has ended this session.");
        }
        // Refresh list to remove the now-ended lecture
        loadUpcomingLectures(true);
      }
    });
    return unsubscribe;
  }, [loadUpcomingLectures]);

  const handleJoinLecture = (lectureId: string) => {
    setActiveLectureId(lectureId);
    setFocusActive(true);
    router.push("/(student)/focus");
  };

  const handleActivity = (key: string) => {
    if (key === "focus") router.push("/(student)/focus");
    else if (key === "notes") router.push("/(student)/notes");
    else if (key === "scan") router.push("/(student)/scan");
  };

  const handleLogout = async () => {
    useStore.getState().reset();
    router.replace("/(auth)/login");
  };

  const formatTime = (iso: string) =>
    new Date(iso).toLocaleTimeString("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    });

  return (
    <View style={styles.root}>
      {/* ── Top Profile Header ──────────────────────────── */}
      <View style={styles.header}>
        <View style={styles.profileRow}>
          {/* Avatar */}
          <View style={styles.avatar}>
            <Ionicons name="person" size={26} color={C.textSecondary} />
          </View>

          {/* Name + ID */}
          <View style={styles.profileInfo}>
            <Text style={styles.greeting}>
              Hi, <Text style={styles.greetingBold}>{studentName ?? studentId ?? "Student"}</Text>
            </Text>
            {studentId && (
              <View style={styles.idBadge}>
                <Text style={styles.idBadgeText}>{studentId}</Text>
              </View>
            )}
          </View>

          {/* Icons */}
          <View style={styles.headerIcons}>
            <TouchableOpacity style={styles.iconBtn} onPress={toggleDark}>
              <Ionicons name={isDark ? "sunny" : "moon"} size={20} color={Colors.white} />
            </TouchableOpacity>
            <TouchableOpacity style={styles.iconBtn} onPress={handleLogout}>
              <Ionicons name="log-out-outline" size={20} color={Colors.white} />
            </TouchableOpacity>
            <TouchableOpacity style={styles.iconBtn}>
              <Ionicons name="notifications-outline" size={20} color={Colors.white} />
            </TouchableOpacity>
          </View>
        </View>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* ── AAST Banner ─────────────────────────────────── */}
        <View style={styles.banner}>
          <View style={styles.bannerInner}>
            <Text style={styles.bannerTitle}>AAST LMS</Text>
            <Text style={styles.bannerSub}>
              AI-powered Classroom Analytics{"\n"}Arab Academy — Cairo Campus
            </Text>
          </View>
          <View style={styles.bannerBadge}>
            <Text style={styles.bannerBadgeText}>Live</Text>
          </View>
        </View>

        {/* ── Activities Grid ──────────────────────────────── */}
        <Text style={styles.sectionTitle}>Activities</Text>
        <View style={styles.activityGrid}>
          {ACTIVITIES.map((a) => (
            <TouchableOpacity
              key={a.key}
              style={[styles.activityCard, { backgroundColor: a.color }]}
              onPress={() => handleActivity(a.key)}
              activeOpacity={0.75}
            >
              <Ionicons name={a.icon as any} size={30} color={a.iconColor} />
              <Text style={[styles.activityLabel, { color: a.iconColor }]}>
                {a.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* ── Upcoming Lectures ────────────────────────────── */}
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Upcoming Lectures</Text>
          <TouchableOpacity onPress={loadUpcomingLectures}>
            <Text style={styles.viewAll}>Refresh</Text>
          </TouchableOpacity>
        </View>

        {loading ? (
          <ActivityIndicator color={C.navy} style={{ marginVertical: 24 }} />
        ) : lectures.length === 0 ? (
          <View style={styles.emptyCard}>
            <Ionicons name="calendar-outline" size={32} color={C.textMuted} />
            <Text style={styles.emptyText}>No upcoming lectures</Text>
          </View>
        ) : (
          lectures.map((lec) => (
            <View key={lec.lecture_id} style={styles.lectureCard}>
              {/* Timeline dot */}
              <View style={styles.timeline}>
                <View style={styles.timelineDot} />
                <View style={styles.timelineLine} />
              </View>

              <View style={styles.lectureBody}>
                <Text style={styles.lectureCode}>{lec.subject}</Text>
                <Text style={styles.lectureTitle}>{lec.title}</Text>
                <Text style={styles.lectureTime}>{formatTime(lec.start_time)}</Text>
              </View>

              <TouchableOpacity
                style={styles.joinBtn}
                onPress={() => handleJoinLecture(lec.lecture_id)}
                activeOpacity={0.8}
              >
                <Ionicons name="chevron-forward" size={18} color={C.navy} />
              </TouchableOpacity>
            </View>
          ))
        )}
      </ScrollView>
    </View>
  );
}

const makeStyles = (C: typeof Colors) => StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: C.background,
  },

  /* Header */
  header: {
    backgroundColor: C.navy,
    paddingTop: 52,
    paddingBottom: 12,
    paddingHorizontal: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
  },
  profileRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
  },
  avatar: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: C.border,
    alignItems: "center",
    justifyContent: "center",
  },
  profileInfo: {
    flex: 1,
    gap: 4,
  },
  greeting: {
    fontSize: 15,
    color: Colors.white,
  },
  greetingBold: {
    fontWeight: "700",
    color: Colors.white,
  },
  idBadge: {
    backgroundColor: C.gold,
    borderRadius: Radius.xl,
    paddingHorizontal: 10,
    paddingVertical: 2,
    alignSelf: "flex-start",
  },
  idBadgeText: {
    fontSize: 11,
    fontWeight: "700",
    color: Colors.white,
  },
  headerIcons: {
    flexDirection: "row",
    gap: 8,
  },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: 8,
    backgroundColor: C.navy,
    alignItems: "center",
    justifyContent: "center",
  },

  scroll: { flex: 1 },
  scrollContent: { padding: Spacing.md, paddingBottom: 32 },

  /* Banner */
  banner: {
    backgroundColor: Colors.navy,
    borderRadius: Radius.lg,
    padding: Spacing.md,
    marginBottom: Spacing.lg,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    ...Shadow.card,
  },
  bannerInner: { flex: 1 },
  bannerTitle: {
    fontSize: 20,
    fontWeight: "800",
    color: Colors.gold,
    marginBottom: 4,
  },
  bannerSub: {
    fontSize: 12,
    color: Colors.white,
    opacity: 0.8,
    lineHeight: 18,
  },
  bannerBadge: {
    backgroundColor: Colors.gold,
    borderRadius: Radius.xl,
    paddingHorizontal: 12,
    paddingVertical: 4,
  },
  bannerBadgeText: {
    fontSize: 12,
    fontWeight: "700",
    color: Colors.navy,
  },

  /* Section */
  sectionTitle: {
    fontSize: 17,
    fontWeight: "700",
    color: C.textPrimary,
    marginBottom: Spacing.sm,
  },
  sectionHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: Spacing.sm,
    marginTop: Spacing.md,
  },
  viewAll: {
    fontSize: 13,
    color: C.gold,
    fontWeight: "600",
  },

  /* Activities */
  activityGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
    marginBottom: Spacing.md,
  },
  activityCard: {
    width: "47%",
    borderRadius: Radius.md,
    padding: Spacing.md,
    alignItems: "center",
    gap: 8,
    ...Shadow.card,
  },
  activityLabel: {
    fontSize: 13,
    fontWeight: "600",
  },

  /* Lectures */
  lectureCard: {
    backgroundColor: C.white,
    borderRadius: Radius.md,
    padding: Spacing.md,
    marginBottom: 10,
    flexDirection: "row",
    alignItems: "center",
    ...Shadow.card,
  },
  timeline: {
    width: 20,
    alignItems: "center",
    marginRight: 12,
  },
  timelineDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#3B82F6',
  },
  timelineLine: {
    width: 2,
    flex: 1,
    backgroundColor: C.border,
    marginTop: 4,
  },
  lectureBody: { flex: 1 },
  lectureCode: {
    fontSize: 12,
    color: '#3B82F6',
    fontWeight: "600",
    marginBottom: 2,
  },
  lectureTitle: {
    fontSize: 14,
    fontWeight: "700",
    color: C.textPrimary,
    marginBottom: 4,
  },
  lectureTime: {
    fontSize: 12,
    color: C.gold,
    fontWeight: "600",
  },
  joinBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: C.background,
    alignItems: "center",
    justifyContent: "center",
  },

  /* Empty */
  emptyCard: {
    backgroundColor: C.white,
    borderRadius: Radius.md,
    padding: 32,
    alignItems: "center",
    gap: 8,
    ...Shadow.card,
  },
  emptyText: {
    fontSize: 14,
    color: C.textMuted,
  },
});
