import React from "react";
import { StyleSheet, Text, View } from "react-native";

interface FocusOverlayProps {
  strikes: number;
  focusActive: boolean;
  lectureId: string | null;
}

const MAX_STRIKES = 3;

/**
 * FocusOverlay — T055
 *
 * Displays the current strike counter and focus-lock status.
 * Turns amber at 1–2 strikes, red at 3+ strikes.
 * Rendered inside the Focus Mode screen above the content.
 */
export default function FocusOverlay({
  strikes,
  focusActive,
  lectureId,
}: FocusOverlayProps) {
  const strikeDots = Array.from({ length: MAX_STRIKES }, (_, i) => i < strikes);
  const isWarning = strikes >= MAX_STRIKES;

  return (
    <View style={[styles.container, isWarning && styles.containerWarning]}>
      {/* Focus status badge */}
      <View style={styles.row}>
        <View style={[styles.badge, focusActive ? styles.badgeActive : styles.badgeInactive]}>
          <Text style={styles.badgeText}>
            {focusActive ? "FOCUS ACTIVE" : "FOCUS INACTIVE"}
          </Text>
        </View>
        {lectureId && (
          <Text style={styles.lectureId}>Lecture: {lectureId}</Text>
        )}
      </View>

      {/* Strike counter */}
      <View style={styles.strikeRow}>
        <Text style={styles.strikeLabel}>Strikes</Text>
        <View style={styles.dotsRow}>
          {strikeDots.map((filled, i) => (
            <View
              key={i}
              style={[styles.dot, filled && (isWarning ? styles.dotRed : styles.dotAmber)]}
            />
          ))}
        </View>
        <Text style={[styles.strikeCount, isWarning && styles.strikeCountRed]}>
          {strikes}/{MAX_STRIKES}
        </Text>
      </View>

      {/* Warning message at max strikes */}
      {isWarning && (
        <View style={styles.warningBanner}>
          <Text style={styles.warningText}>
            ⚠ Maximum strikes reached — lecturer has been notified
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: "#002147",   // AAST navy
    borderRadius: 12,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: "#C9A84C",        // AAST gold
  },
  containerWarning: {
    backgroundColor: "#7f1d1d",
    borderColor: "#ef4444",
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 10,
  },
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 20,
  },
  badgeActive: {
    backgroundColor: "#C9A84C",  // gold
  },
  badgeInactive: {
    backgroundColor: "#4b5563",
  },
  badgeText: {
    color: "#fff",
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1,
  },
  lectureId: {
    color: "#d1d5db",
    fontSize: 12,
  },
  strikeRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
  },
  strikeLabel: {
    color: "#9ca3af",
    fontSize: 13,
    marginRight: 6,
  },
  dotsRow: {
    flexDirection: "row",
    gap: 6,
    flex: 1,
  },
  dot: {
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: "#374151",
    borderWidth: 1,
    borderColor: "#6b7280",
  },
  dotAmber: {
    backgroundColor: "#f59e0b",
    borderColor: "#d97706",
  },
  dotRed: {
    backgroundColor: "#ef4444",
    borderColor: "#dc2626",
  },
  strikeCount: {
    color: "#e5e7eb",
    fontSize: 16,
    fontWeight: "700",
  },
  strikeCountRed: {
    color: "#ef4444",
  },
  warningBanner: {
    marginTop: 10,
    backgroundColor: "rgba(239, 68, 68, 0.2)",
    borderRadius: 6,
    padding: 8,
  },
  warningText: {
    color: "#fca5a5",
    fontSize: 12,
    textAlign: "center",
  },
});
