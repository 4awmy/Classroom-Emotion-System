"use client";

import React, { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ActivityIndicator,
} from "react-native";
import { useRouter } from "expo-router";
import { useStore } from "@/store/useStore";
import { authAPI, setAuthToken, connectWebSocket } from "@/services/api";

/**
 * Login Screen (P1-S4-02)
 * Phase 1: Mock JWT authentication
 * Phase 2: Connect to real /auth/login endpoint
 */
export default function LoginScreen() {
  const router = useRouter();
  const { setStudentId } = useStore();

  const [studentId, setStudentIdInput] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleLogin = async () => {
    if (!studentId.trim() || !password.trim()) {
      Alert.alert("Error", "Please enter both Student ID and password");
      return;
    }

    setLoading(true);
    try {
      console.log("[Auth] Logging in student:", studentId);

      // Phase 1: Mock login
      if (studentId === "demo" && password === "demo") {
        const mockToken = "mock.jwt.token.for.demo";
        setAuthToken(mockToken);
        setStudentId(studentId);
        connectWebSocket();

        console.log("[Auth] Mock login successful");
        router.replace("/(student)/home");
        return;
      }

      // Phase 2: Real login (uncomment when backend ready)
      // const response = await authAPI.login(studentId, password);
      // if (response.token) {
      //   setAuthToken(response.token);
      //   setStudentId(studentId);
      //   connectWebSocket();
      //   router.replace('/(student)/home');
      // }
    } catch (error) {
      console.error("[Auth] Login error:", error);
      Alert.alert("Login Failed", "Invalid credentials or server error");
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.logo}>AAST</Text>
        <Text style={styles.title}>Learning Management</Text>
        <Text style={styles.subtitle}>Student Portal</Text>
      </View>

      {/* Form */}
      <View style={styles.form}>
        <Text style={styles.label}>Student ID</Text>
        <TextInput
          style={styles.input}
          placeholder="Enter your student ID"
          value={studentId}
          onChangeText={setStudentIdInput}
          editable={!loading}
          placeholderTextColor="#ccc"
        />

        <Text style={styles.label}>Password</Text>
        <TextInput
          style={styles.input}
          placeholder="Enter your password"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          editable={!loading}
          placeholderTextColor="#ccc"
        />

        <TouchableOpacity
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={handleLogin}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>Login</Text>
          )}
        </TouchableOpacity>
      </View>

      {/* Demo Hint */}
      <View style={styles.demo}>
        <Text style={styles.demoText}>Demo credentials:</Text>
        <Text style={styles.demoValue}>ID: demo | Password: demo</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f5f5f5",
    justifyContent: "center",
    padding: 20,
  },
  header: {
    alignItems: "center",
    marginBottom: 40,
  },
  logo: {
    fontSize: 48,
    fontWeight: "bold",
    color: "#002147", // AAST navy
    marginBottom: 8,
  },
  title: {
    fontSize: 24,
    fontWeight: "600",
    color: "#333",
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: "#999",
  },
  form: {
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 20,
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: "600",
    color: "#333",
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: "#ddd",
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    marginBottom: 16,
    backgroundColor: "#fafafa",
  },
  button: {
    backgroundColor: "#002147",
    borderRadius: 8,
    padding: 14,
    alignItems: "center",
    marginTop: 8,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
  demo: {
    backgroundColor: "#e3f2fd",
    borderRadius: 8,
    padding: 12,
    alignItems: "center",
  },
  demoText: {
    fontSize: 12,
    color: "#1565c0",
    marginBottom: 4,
  },
  demoValue: {
    fontSize: 12,
    fontFamily: "monospace",
    color: "#0d47a1",
    fontWeight: "600",
  },
});
