import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  TouchableOpacity,
  Share,
} from "react-native";
import { useStore } from "@/store/useStore";
import { notesAPI } from "@/services/api";

/**
 * Smart Notes Screen (P1-S4 stub)
 * Displays generated study notes with highlights
 * Phase 2: Fetch from /notes/{student_id}/{lecture_id}
 */
export default function NotesScreen() {
  const { studentId, activeLectureId } = useStore();
  const [notes, setNotes] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (studentId && activeLectureId) {
      loadNotes();
    }
  }, [studentId, activeLectureId]);

  const loadNotes = async () => {
    try {
      setLoading(true);
      console.log("[Notes] Loading notes for:", studentId, activeLectureId);

      // Phase 1: Mock notes
      const mockNotes = `# Study Notes

## Key Concepts
- **Algorithms**: Step-by-step procedures for solving problems
- **Time Complexity**: Measure of how fast an algorithm runs

✱ **Important**: This section was covered when you were briefly distracted.
Pay close attention to Big O notation - it's crucial for the exam.

## Examples
1. Linear Search: O(n)
2. Binary Search: O(log n)
3. Bubble Sort: O(n²)

## Practice Problems
- Implement a binary search function
- Analyze time complexity of nested loops
- Design an efficient sorting algorithm
`;
      setNotes(mockNotes);

      // Phase 2: Uncomment for real API
      // if (activeLectureId) {
      //   const response = await notesAPI.get(studentId, activeLectureId);
      //   setNotes(response);
      // }
    } catch (error) {
      console.error("[Notes] Error loading notes:", error);
      setNotes("Failed to load notes. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleShare = async () => {
    try {
      await Share.share({
        message: notes,
        title: "My Study Notes",
      });
    } catch (error) {
      console.error("[Notes] Share error:", error);
    }
  };

  if (loading) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#002147" />
        <Text style={styles.loadingText}>Loading notes...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Smart Notes</Text>
        <TouchableOpacity style={styles.shareButton} onPress={handleShare}>
          <Text style={styles.shareButtonText}>📤 Share</Text>
        </TouchableOpacity>
      </View>

      {/* Notes Content */}
      <ScrollView style={styles.content}>
        <Text style={styles.notesText}>{notes}</Text>
      </ScrollView>

      {/* Legend */}
      <View style={styles.legend}>
        <Text style={styles.legendTitle}>✱ = Key content when distracted</Text>
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
  shareButton: {
    backgroundColor: "#c9a84c",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
  },
  shareButtonText: {
    fontSize: 12,
    fontWeight: "600",
    color: "#002147",
  },
  content: {
    flex: 1,
    padding: 16,
  },
  notesText: {
    fontSize: 14,
    lineHeight: 22,
    color: "#333",
    fontFamily: "system",
  },
  legend: {
    backgroundColor: "#fff9e6",
    padding: 12,
    borderTopWidth: 1,
    borderTopColor: "#ffe0b2",
  },
  legendTitle: {
    fontSize: 12,
    color: "#f57f17",
    fontStyle: "italic",
  },
});
