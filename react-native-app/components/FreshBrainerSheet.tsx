import React, { useEffect, useRef, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  Animated,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { checkAPI } from "@/services/api";
import { Colors, Radius, Spacing } from "@/constants/theme";

interface FreshBrainerSheetProps {
  visible: boolean;
  question: string | null;
  checkId?: number;
  options?: string[];
  studentId: string;
  onDismiss: () => void;
}

const TIMER_SECONDS = 30;

export default function FreshBrainerSheet({
  visible,
  question,
  checkId,
  options,
  studentId,
  onDismiss,
}: FreshBrainerSheetProps) {
  const [selectedOption, setSelectedOption] = useState<number | null>(null);
  const [result, setResult] = useState<boolean | null>(null);
  const [timeLeft, setTimeLeft] = useState(TIMER_SECONDS);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const progressAnim = useRef(new Animated.Value(1)).current;

  const isMCQ = !!(checkId && options && options.length > 0);

  useEffect(() => {
    if (visible) {
      setSelectedOption(null);
      setResult(null);
      setTimeLeft(TIMER_SECONDS);
      progressAnim.setValue(1);

      Animated.timing(progressAnim, {
        toValue: 0,
        duration: TIMER_SECONDS * 1000,
        useNativeDriver: false,
      }).start();

      timerRef.current = setInterval(() => {
        setTimeLeft((t) => {
          if (t <= 1) {
            clearInterval(timerRef.current!);
            onDismiss();
            return 0;
          }
          return t - 1;
        });
      }, 1000);
    } else {
      if (timerRef.current) clearInterval(timerRef.current);
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [visible]);

  const handleOptionSelect = async (optionIndex: number) => {
    if (selectedOption !== null) return;
    setSelectedOption(optionIndex);
    if (timerRef.current) clearInterval(timerRef.current);

    if (checkId) {
      try {
        const resp = await checkAPI.submitAnswer(checkId, studentId, optionIndex);
        setResult(resp.is_correct as boolean);
      } catch {
        setResult(false);
      }
    }
  };

  const optionStyle = (idx: number) => {
    if (selectedOption === null) return { bg: "#F8FAFC", border: "#E2E8F0", text: Colors.navy };
    if (idx === selectedOption) {
      if (result === true)  return { bg: "#D1FAE5", border: "#10B981", text: "#065F46" };
      if (result === false) return { bg: "#FEE2E2", border: "#EF4444", text: "#991B1B" };
      return { bg: "#DBEAFE", border: "#3B82F6", text: "#1E3A5F" };
    }
    return { bg: "#F8FAFC", border: "#E2E8F0", text: "#94A3B8" };
  };

  const dismissLabel =
    result === true ? "Correct! ✅  Got it" :
    result === false ? "Wrong ❌  Got it" :
    "Got it";

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onDismiss}
    >
      <View style={styles.overlay}>
        <View style={styles.sheet}>
          {/* Gold drag handle */}
          <View style={styles.handle} />

          {/* Animated timer bar */}
          <Animated.View
            style={[
              styles.timerBar,
              {
                width: progressAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: ["0%", "100%"],
                }),
              },
            ]}
          />

          {/* Header */}
          <View style={styles.header}>
            <Ionicons name="bulb" size={22} color={Colors.gold} />
            <Text style={styles.headerTitle}>Question from Lecturer</Text>
            <Text style={styles.timerText}>{timeLeft}s</Text>
          </View>

          {/* Question text */}
          <Text style={styles.question}>{question}</Text>

          {/* MCQ options (only when checkId present) */}
          {isMCQ && options && (
            <View style={styles.optionsWrap}>
              {options.map((opt, idx) => {
                const col = optionStyle(idx);
                return (
                  <TouchableOpacity
                    key={idx}
                    style={[styles.optionBtn, { backgroundColor: col.bg, borderColor: col.border }]}
                    onPress={() => handleOptionSelect(idx)}
                    disabled={selectedOption !== null}
                    activeOpacity={0.75}
                  >
                    <Text style={[styles.optionLabel, { color: col.text }]}>
                      {String.fromCharCode(65 + idx)}.{" "}
                    </Text>
                    <Text style={[styles.optionText, { color: col.text }]}>{opt}</Text>
                    {selectedOption === idx && result === true && (
                      <Ionicons name="checkmark-circle" size={18} color="#10B981" />
                    )}
                    {selectedOption === idx && result === false && (
                      <Ionicons name="close-circle" size={18} color="#EF4444" />
                    )}
                  </TouchableOpacity>
                );
              })}
            </View>
          )}

          {/* Dismiss / Got it */}
          <TouchableOpacity
            style={[styles.dismissBtn, result !== null && styles.dismissBtnDone]}
            onPress={onDismiss}
          >
            <Text style={styles.dismissText}>{dismissLabel}</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.55)",
    justifyContent: "flex-end",
  },
  sheet: {
    backgroundColor: Colors.white,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingBottom: 40,
    overflow: "hidden",
  },
  handle: {
    width: 40,
    height: 4,
    backgroundColor: Colors.gold,
    borderRadius: 2,
    alignSelf: "center",
    marginTop: 12,
    marginBottom: 8,
  },
  timerBar: {
    height: 3,
    backgroundColor: Colors.gold,
    marginBottom: 16,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.md,
  },
  headerTitle: {
    flex: 1,
    fontSize: 16,
    fontWeight: "700",
    color: Colors.navy,
  },
  timerText: {
    fontSize: 14,
    fontWeight: "600",
    color: Colors.gold,
  },
  question: {
    fontSize: 15,
    lineHeight: 22,
    color: "#1E293B",
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.md,
  },
  optionsWrap: {
    paddingHorizontal: Spacing.lg,
    gap: 8,
    marginBottom: Spacing.md,
  },
  optionBtn: {
    flexDirection: "row",
    alignItems: "center",
    borderWidth: 1.5,
    borderRadius: Radius.md,
    padding: 12,
    gap: 4,
  },
  optionLabel: {
    fontSize: 14,
    fontWeight: "700",
    minWidth: 24,
  },
  optionText: {
    flex: 1,
    fontSize: 14,
    lineHeight: 18,
  },
  dismissBtn: {
    marginHorizontal: Spacing.lg,
    backgroundColor: Colors.navy,
    borderRadius: Radius.xl,
    paddingVertical: 13,
    alignItems: "center",
    marginTop: 4,
  },
  dismissBtnDone: {
    backgroundColor: "#10B981",
  },
  dismissText: {
    color: Colors.white,
    fontWeight: "700",
    fontSize: 15,
  },
});
