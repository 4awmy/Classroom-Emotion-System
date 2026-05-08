import { useEffect } from "react";
import { View, Text, StyleSheet, ActivityIndicator } from "react-native";
import { useRouter } from "expo-router";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { setAuthToken, connectWebSocket } from "@/services/api";
import { useStore } from "@/store/useStore";
import { Colors } from "@/constants/theme";

export default function SplashScreen() {
  const router = useRouter();
  const { setStudentId, setIsDark } = useStore();

  useEffect(() => {
    checkStoredSession();
  }, []);

  const checkStoredSession = async () => {
    // Show splash for 1.5s then check stored credentials
    await new Promise((r) => setTimeout(r, 1500));
    try {
      const token = await AsyncStorage.getItem("auth_token");
      const storedId = await AsyncStorage.getItem("student_id");
      const darkMode = await AsyncStorage.getItem("dark_mode");

      if (darkMode === "1") {
        setIsDark(true);
      }

      if (token && storedId) {
        setAuthToken(token);
        setStudentId(storedId);
        connectWebSocket();
        router.replace("/(student)/home");
      } else {
        router.replace("/(auth)/login");
      }
    } catch {
      router.replace("/(auth)/login");
    }
  };

  return (
    <View style={styles.container}>
      {/* Logo Badge */}
      <View style={styles.logoWrap}>
        <View style={styles.logoBadge}>
          <Text style={styles.logoText}>AAST</Text>
        </View>
        <Text style={styles.titleAr}>بوابة الطالب</Text>
        <Text style={styles.titleEn}>Student Portal</Text>
      </View>

      <ActivityIndicator color={Colors.gold} size="small" style={styles.loader} />

      {/* Footer */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>Version: 1.0.0</Text>
        <Text style={styles.footerText}>Information & Documentation Center</Text>
        <Text style={styles.footerText}>
          Arab Academy for Science, Technology and Maritime Transport
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.navy,
    alignItems: "center",
    justifyContent: "center",
  },
  logoWrap: {
    alignItems: "center",
    marginBottom: 48,
  },
  logoBadge: {
    width: 120,
    height: 120,
    borderRadius: 60,
    borderWidth: 3,
    borderColor: Colors.white,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 20,
  },
  logoText: {
    fontSize: 32,
    fontWeight: "bold",
    color: Colors.white,
    letterSpacing: 4,
  },
  titleAr: {
    fontSize: 22,
    color: Colors.gold,
    fontWeight: "600",
    marginBottom: 4,
  },
  titleEn: {
    fontSize: 16,
    color: Colors.white,
    opacity: 0.85,
  },
  loader: {
    marginBottom: 40,
  },
  footer: {
    position: "absolute",
    bottom: 40,
    alignItems: "center",
    gap: 2,
  },
  footerText: {
    fontSize: 11,
    color: Colors.white,
    opacity: 0.55,
    textAlign: "center",
  },
});
