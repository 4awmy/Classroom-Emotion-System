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
import { authAPI, connectWebSocket, setAuthToken } from "@/services/api";
import { Colors, Radius, Shadow } from "@/constants/theme";

export default function LoginScreen() {
  const router = useRouter();
  const { setStudentId, setStudentName, setAuthToken: setStoreAuthToken } = useStore();

  const [studentId, setStudentIdInput] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const canSubmit = studentId.trim().length > 0 && password.trim().length > 0;

  const handleLogin = async () => {
    if (!canSubmit) return;
    setLoading(true);
    try {
      // Real API login
      const response = await authAPI.login(studentId.trim(), password);

      if (response?.access_token) {
        setStoreAuthToken(response.access_token);
        setAuthToken(response.access_token);
        setStudentId(studentId.trim());
        // Fetch display name
        try {
          const me = await authAPI.getMe();
          if (me?.name) setStudentName(me.name);
        } catch {
          // Non-fatal — ID shown as fallback
        }
        connectWebSocket();
        router.replace("/(student)/home");
      } else {
        Alert.alert("Login Failed", "Invalid credentials. Please try again.");
      }
    } catch (err: any) {
      const msg = err.response?.data?.detail || "Invalid credentials. Please try again.";
      Alert.alert("Login Failed", msg);
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

          {/* Forgot Password */}
          <TouchableOpacity
            onPress={() =>
              Alert.alert(
                "Forgot Password?",
                "Please contact your system administrator to reset your password.\n\nEmail: lms@aast.edu",
                [{ text: "OK" }]
              )
            }
            activeOpacity={0.7}
          >
            <Text style={styles.forgotText}>Forgot Password?</Text>
          </TouchableOpacity>
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
  forgotText: {
    fontSize: 13,
    color: Colors.textMuted,
    textAlign: "center",
    textDecorationLine: "underline",
    marginTop: 4,
  },
});
