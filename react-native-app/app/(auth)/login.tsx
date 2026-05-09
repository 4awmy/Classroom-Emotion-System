import React, { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from "react-native";
import { useRouter } from "expo-router";
import { useStore } from "@/store/useStore";
import { authAPI, connectWebSocket } from "@/services/api";
import { Colors, Radius, Shadow } from "@/constants/theme";

export default function LoginScreen() {
  const router = useRouter();
  const { setStudentId, setAuthToken } = useStore();

  const [studentId, setStudentIdInput] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const canSubmit = studentId.trim().length > 0 && password.trim().length > 0;

  const handleLogin = async () => {
    if (!canSubmit) return;
    setLoading(true);
    try {
      // Demo credentials
      if (studentId.trim() === "demo" && password === "demo") {
        const mockToken = "mock.jwt.token.for.demo";
        setAuthToken(mockToken);
        setStudentId(studentId.trim());
        connectWebSocket();
        router.replace("/(student)/home");
        return;
      }

      // Real API login
      const response = await authAPI.login(studentId.trim(), password);
      if (response?.token) {
        setAuthToken(response.token);
        setStudentId(studentId.trim());
        connectWebSocket();
        router.replace("/(student)/home");
      } else {
        Alert.alert("Login Failed", "Invalid credentials. Please try again.");
      }
    } catch {
      Alert.alert("Login Failed", "Invalid credentials. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ScrollView
        contentContainerStyle={styles.scroll}
        keyboardShouldPersistTaps="handled"
        bounces={false}
      >
        {/* ── Navy Header ─────────────────────────────────── */}
        <View style={styles.header}>
          <View style={styles.logoBadge}>
            <Text style={styles.logoText}>AAST</Text>
          </View>
          <Text style={styles.titleAr}>بوابة الطالب</Text>
          <Text style={styles.titleEn}>Student Portal</Text>
        </View>

        {/* ── Light Body ──────────────────────────────────── */}
        <View style={styles.body}>
          <Text style={styles.signInHint}>Sign in to continue</Text>

          {/* Registration Number */}
          <View style={styles.inputCard}>
            <TextInput
              style={styles.input}
              placeholder="Registration Number"
              placeholderTextColor={Colors.textMuted}
              value={studentId}
              onChangeText={setStudentIdInput}
              keyboardType="default"
              autoCapitalize="none"
              editable={!loading}
            />
          </View>

          {/* Password */}
          <View style={styles.inputCard}>
            <TextInput
              style={styles.input}
              placeholder="Password"
              placeholderTextColor={Colors.textMuted}
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              editable={!loading}
            />
          </View>

          {/* Sign In Button */}
          <TouchableOpacity
            style={[
              styles.button,
              canSubmit ? styles.buttonActive : styles.buttonInactive,
            ]}
            onPress={handleLogin}
            disabled={loading || !canSubmit}
            activeOpacity={0.85}
          >
            {loading ? (
              <ActivityIndicator color={Colors.white} />
            ) : (
              <Text
                style={[
                  styles.buttonText,
                  canSubmit ? styles.buttonTextActive : styles.buttonTextInactive,
                ]}
              >
                Sign In
              </Text>
            )}
          </TouchableOpacity>

          {/* Demo hint */}
          <View style={styles.demoBox}>
            <Text style={styles.demoText}>
              Demo: Registration <Text style={styles.demoBold}>demo</Text> / Password{" "}
              <Text style={styles.demoBold}>demo</Text>
            </Text>
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  scroll: {
    flexGrow: 1,
  },

  /* Navy header — matches real app ~45% height */
  header: {
    backgroundColor: Colors.navy,
    alignItems: "center",
    paddingTop: 64,
    paddingBottom: 40,
    gap: 8,
  },
  logoBadge: {
    width: 90,
    height: 90,
    borderRadius: 45,
    borderWidth: 2.5,
    borderColor: Colors.white,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 8,
  },
  logoText: {
    fontSize: 24,
    fontWeight: "bold",
    color: Colors.white,
    letterSpacing: 3,
  },
  titleAr: {
    fontSize: 18,
    color: Colors.gold,
    fontWeight: "600",
  },
  titleEn: {
    fontSize: 13,
    color: Colors.white,
    opacity: 0.8,
  },

  /* Light body */
  body: {
    flex: 1,
    backgroundColor: Colors.background,
    paddingHorizontal: 24,
    paddingTop: 32,
    paddingBottom: 40,
  },
  signInHint: {
    fontSize: 14,
    color: Colors.textMuted,
    textAlign: "center",
    marginBottom: 28,
  },

  /* Input cards — white rounded, exactly like real app */
  inputCard: {
    backgroundColor: Colors.white,
    borderRadius: Radius.md,
    marginBottom: 16,
    ...Shadow.card,
  },
  input: {
    paddingHorizontal: 18,
    paddingVertical: 16,
    fontSize: 15,
    color: Colors.textPrimary,
  },

  /* Sign In button */
  button: {
    borderRadius: Radius.xl,
    paddingVertical: 15,
    alignItems: "center",
    marginTop: 8,
    marginBottom: 24,
  },
  buttonActive: {
    backgroundColor: Colors.navy,
  },
  buttonInactive: {
    backgroundColor: '#D1D5DB',
  },
  buttonText: {
    fontSize: 15,
    fontWeight: "700",
    letterSpacing: 0.5,
  },
  buttonTextActive: {
    color: Colors.white,
  },
  buttonTextInactive: {
    color: Colors.white,
  },

  /* Demo hint */
  demoBox: {
    backgroundColor: '#EFF6FF',
    borderRadius: Radius.sm,
    padding: 12,
    alignItems: "center",
  },
  demoText: {
    fontSize: 12,
    color: '#3B82F6',
  },
  demoBold: {
    fontWeight: "700",
  },
});
