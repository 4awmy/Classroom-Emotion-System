import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  TouchableOpacity,
  Share,
  RefreshControl,
} from "react-native";
import { useStore } from "@/store/useStore";
import { notesAPI } from "@/services/api";
import NotesViewer from "@/components/NotesViewer";

/**
 * Smart Notes Screen — Phase 3 (T056)
 * Fetches AI-generated notes from GET /notes/{student_id}/{lecture_id}
 * Uses NotesViewer component with markdown rendering + ✱ highlights
 */
export default function NotesScreen() {
  const { studentId, activeLectureId } = useStore();
  const [notes, setNotes] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (studentId && activeLectureId) {
      loadNotes();
    }
  }, [studentId, activeLectureId]);

  const loadNotes = async (isRefresh = false) => {
    if (!studentId || !activeLectureId) {
      setError("No active lecture session.");
      return;
    }

    try {
      isRefresh ? setRefreshing(true) : setLoading(true);
      setError(null);

      const response = await notesAPI.get(studentId, activeLectureId);
      const markdown = response?.markdown ?? response;
      setNotes(typeof markdown === "string" ? markdown : JSON.stringify(markdown));
    } catch (err) {
      console.error("[Notes] Error loading notes:", err);
      setError("Could not load notes. The lecture may still be in progress.");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleShare = async () => {
    if (!notes) return;
    try {
      await Share.share({
        message: notes,
        title: `Lecture Notes — ${activeLectureId}`,
      });
    } catch (err) {
      console.error("[Notes] Share error:", err);
    }
  };

  // ── Loading State ──────────────────────────────────────────────────────────
  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#002147" />
        <Text style={styles.loadingText}>Generating your personalised notes...</Text>
        <Text style={styles.loadingSubtext}>This may take a few seconds</Text>
      </View>
    );
  }

  // ── Error State ────────────────────────────────────────────────────────────
  if (error) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorTitle}>Notes Unavailable</Text>
        <Text style={styles.errorText}>{error}</Text>
        <TouchableOpacity style={styles.retryButton} onPress={() => loadNotes()}>
          <Text style={styles.retryButtonText}>Try Again</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  if (!notes) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorTitle}>No Notes Yet</Text>
        <Text style={styles.errorText}>
          Notes are generated after the lecture ends. Check back shortly.
        </Text>
        {studentId && activeLectureId && (
          <TouchableOpacity style={styles.retryButton} onPress={() => loadNotes()}>
            <Text style={styles.retryButtonText}>Refresh</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  }

  // ── Notes View ─────────────────────────────────────────────────────────────
  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>Smart Notes</Text>
          {activeLectureId && (
            <Text style={styles.subtitle}>Lecture: {activeLectureId}</Text>
          )}
        </View>
        <TouchableOpacity style={styles.shareButton} onPress={handleShare}>
          <Text style={styles.shareButtonText}>Share</Text>
        </TouchableOpacity>
      </View>

      {/* Scrollable Notes */}
      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentPadding}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={() => loadNotes(true)}
            colors={["#002147"]}
          />
        }
      >
        <NotesViewer markdown={notes} />
      </ScrollView>
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
    padding: 24,
    backgroundColor: "#f5f5f5",
  },
  loadingText: {
    marginTop: 16,
    fontSize: 15,
    color: "#002147",
    fontWeight: "500",
    textAlign: "center",
  },
  loadingSubtext: {
    marginTop: 6,
    fontSize: 12,
    color: "#888",
    textAlign: "center",
  },
  errorTitle: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#002147",
    marginBottom: 8,
    textAlign: "center",
  },
  errorText: {
    fontSize: 14,
    color: "#666",
    textAlign: "center",
    lineHeight: 20,
  },
  retryButton: {
    marginTop: 20,
    backgroundColor: "#002147",
    paddingHorizontal: 24,
    paddingVertical: 10,
    borderRadius: 8,
  },
  retryButtonText: {
    color: "#fff",
    fontWeight: "600",
    fontSize: 14,
  },
  header: {
    backgroundColor: "#002147",
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 12,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  title: {
    fontSize: 20,
    fontWeight: "bold",
    color: "#fff",
  },
  subtitle: {
    fontSize: 11,
    color: "#C9A84C",
    marginTop: 2,
  },
  shareButton: {
    backgroundColor: "#C9A84C",
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 6,
  },
  shareButtonText: {
    fontSize: 13,
    fontWeight: "600",
    color: "#002147",
  },
  content: {
    flex: 1,
  },
  contentPadding: {
    padding: 16,
    paddingBottom: 32,
  },
});
