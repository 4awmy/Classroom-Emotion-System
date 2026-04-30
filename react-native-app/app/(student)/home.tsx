import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
} from "react-native";
import { useRouter } from "expo-router";
import { useStore } from "@/store/useStore";
import { sessionAPI } from "@/services/api";

interface Lecture {
  lecture_id: string;
  title: string;
  subject: string;
  start_time: string;
  lecturer_id: string;
}

/**
 * Home Screen (P1-S4-03)
 * Shows upcoming lectures and engagement summary
 */
export default function HomeScreen() {
  const router = useRouter();
  const { studentId, setActiveLectureId, setFocusActive } = useStore();

  const [lectures, setLectures] = useState<Lecture[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadUpcomingLectures();
  }, []);

  const loadUpcomingLectures = async () => {
    try {
      setLoading(true);
      console.log("[Home] Loading upcoming lectures for:", studentId);

      // Phase 1: Mock data
      const mockLectures: Lecture[] = [
        {
          lecture_id: "L1",
          title: "Introduction to Algorithms",
          subject: "Computer Science",
          start_time: "2025-04-30T10:00:00Z",
          lecturer_id: "PROF_001",
        },
        {
          lecture_id: "L2",
          title: "Data Structures Advanced",
          subject: "Computer Science",
          start_time: "2025-04-30T12:00:00Z",
          lecturer_id: "PROF_002",
        },
      ];

      setLectures(mockLectures);

      // Phase 2: Uncomment to use real API
      // const response = await sessionAPI.getUpcoming();
      // setLectures(response);
    } catch (error) {
      console.error("[Home] Error loading lectures:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleJoinLecture = (lectureId: string) => {
    console.log("[Home] Joining lecture:", lectureId);
    setActiveLectureId(lectureId);
    setFocusActive(true);
    router.push("/(student)/focus");
  };

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#002147" />
        <Text style={styles.loadingText}>Loading lectures...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.greeting}>Welcome, {studentId}</Text>
        <Text style={styles.subtext}>Upcoming Lectures</Text>
      </View>

      {/* Lectures List */}
      {lectures.length === 0 ? (
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>No upcoming lectures</Text>
        </View>
      ) : (
        <FlatList
          data={lectures}
          keyExtractor={(item) => item.lecture_id}
          renderItem={({ item }) => (
            <View style={styles.lectureCard}>
              <View style={styles.lectureInfo}>
                <Text style={styles.lectureTitle}>{item.title}</Text>
                <Text style={styles.lectureSubject}>{item.subject}</Text>
                <Text style={styles.lectureTime}>
                  {new Date(item.start_time).toLocaleTimeString("en-US", {
                    hour: "2-digit",
                    minute: "2-digit",
                    hour12: true,
                  })}
                </Text>
              </View>
              <TouchableOpacity
                style={styles.joinButton}
                onPress={() => handleJoinLecture(item.lecture_id)}
              >
                <Text style={styles.joinButtonText}>Join</Text>
              </TouchableOpacity>
            </View>
          )}
          scrollEnabled
          contentContainerStyle={styles.listContent}
        />
      )}

      {/* Info Footer */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          💡 Tip: Stay focused during lectures to maintain your engagement score
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
  },
  centered: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
  },
  loadingText: {
    marginTop: 12,
    fontSize: 14,
    color: "#666",
  },
  header: {
    backgroundColor: "#002147",
    paddingHorizontal: 16,
    paddingTop: 24,
    paddingBottom: 16,
  },
  greeting: {
    fontSize: 20,
    fontWeight: "bold",
    color: "#fff",
    marginBottom: 4,
  },
  subtext: {
    fontSize: 14,
    color: "#ccc",
  },
  listContent: {
    padding: 16,
  },
  lectureCard: {
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  lectureInfo: {
    flex: 1,
    marginRight: 12,
  },
  lectureTitle: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#333",
    marginBottom: 4,
  },
  lectureSubject: {
    fontSize: 13,
    color: "#666",
    marginBottom: 6,
  },
  lectureTime: {
    fontSize: 12,
    color: "#002147",
    fontWeight: "600",
  },
  joinButton: {
    backgroundColor: "#002147",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
  },
  joinButtonText: {
    color: "#fff",
    fontWeight: "600",
    fontSize: 14,
  },
  emptyState: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
  },
  emptyText: {
    fontSize: 16,
    color: "#999",
    fontStyle: "italic",
  },
  footer: {
    backgroundColor: "#e3f2fd",
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderTopWidth: 1,
    borderTopColor: "#90caf9",
  },
  footerText: {
    fontSize: 12,
    color: "#1565c0",
    textAlign: "center",
  },
});
