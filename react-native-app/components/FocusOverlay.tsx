import React, { useMemo } from "react";
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { Colors, DarkColors, Radius, Shadow } from "@/constants/theme";
import { useStore } from "@/store/useStore";

interface FocusOverlayProps {
  strikes: number;
  onDismiss: () => void;
}

export default function FocusOverlay({ strikes, onDismiss }: FocusOverlayProps) {
  const { isDark } = useStore();
  const C = isDark ? DarkColors : Colors;
  const styles = useMemo(() => makeStyles(C), [isDark]);

  const isWarning = strikes >= 3;

  return (
    <Modal transparent animationType="fade" visible onRequestClose={onDismiss}>
      <View style={styles.backdrop}>
        <View style={styles.card}>
          {/* Icon */}
          <View style={[styles.iconCircle, isWarning ? styles.iconRed : styles.iconAmber]}>
            <Ionicons
              name={isWarning ? "warning" : "eye-off"}
              size={32}
              color={Colors.white}
            />
          </View>

          {/* Title */}
          <Text style={styles.title}>
            {isWarning ? "Focus Warning!" : "Strike Recorded"}
          </Text>
          <Text style={styles.subtitle}>
            You left the app during a lecture session.
          </Text>

          {/* Strike Counter */}
          <View
            style={[
              styles.strikeBadge,
              {
                backgroundColor: isWarning
                  ? (isDark ? "#3D0000" : "#FEE2E2")
                  : (isDark ? "#451A03" : "#FEF3C7"),
              },
            ]}
          >
            <Text style={styles.strikeCount}>{strikes}</Text>
            <Text style={styles.strikeLabel}>
              {strikes === 1 ? "Strike" : "Strikes"}
            </Text>
          </View>

          {isWarning && (
            <Text style={styles.warningText}>
              Your lecturer has been notified of repeated focus violations.
            </Text>
          )}

          {/* Dismiss */}
          <TouchableOpacity
            style={styles.dismissBtn}
            onPress={onDismiss}
            activeOpacity={0.85}
          >
            <Text style={styles.dismissText}>Return to App</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const makeStyles = (C: typeof Colors) => StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: "#00000066",
    alignItems: "center",
    justifyContent: "center",
    padding: 32,
  },
  card: {
    backgroundColor: C.white,
    borderRadius: Radius.xl,
    padding: 28,
    alignItems: "center",
    width: "100%",
    gap: 12,
    ...Shadow.card,
  },
  iconCircle: {
    width: 68,
    height: 68,
    borderRadius: 34,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 4,
  },
  iconRed: { backgroundColor: C.error },
  iconAmber: { backgroundColor: C.warning },
  title: {
    fontSize: 20,
    fontWeight: "800",
    color: C.textPrimary,
    textAlign: "center",
  },
  subtitle: {
    fontSize: 13,
    color: C.textSecondary,
    textAlign: "center",
    lineHeight: 20,
  },
  strikeBadge: {
    flexDirection: "row",
    alignItems: "baseline",
    gap: 6,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: Radius.xl,
    marginVertical: 4,
  },
  strikeCount: {
    fontSize: 36,
    fontWeight: "900",
    color: C.textPrimary,
  },
  strikeLabel: {
    fontSize: 14,
    fontWeight: "600",
    color: C.textSecondary,
  },
  warningText: {
    fontSize: 12,
    color: C.error,
    textAlign: "center",
    lineHeight: 18,
    paddingHorizontal: 8,
  },
  dismissBtn: {
    backgroundColor: C.navy,
    borderRadius: Radius.xl,
    paddingHorizontal: 32,
    paddingVertical: 12,
    marginTop: 8,
    width: "100%",
    alignItems: "center",
  },
  dismissText: {
    fontSize: 15,
    fontWeight: "700",
    color: Colors.white,
  },
});
