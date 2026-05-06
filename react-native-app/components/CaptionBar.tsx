import React, { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text, View } from "react-native";
import { getWebSocket, connectWebSocket } from "@/services/api";

interface CaptionMessage {
  type: string;
  text: string;
  lecture_id?: string;
  language?: string;
}

/**
 * CaptionBar — T054
 *
 * Listens on the shared WebSocket for {type: "caption"} events,
 * displays the transcribed text for 4 seconds, then fades out.
 * RTL-aware: Arabic text is right-aligned automatically.
 */
export default function CaptionBar() {
  const [caption, setCaption] = useState<string | null>(null);
  const [isRTL, setIsRTL] = useState(false);
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const clearTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Detect Arabic text (Unicode range 0600–06FF)
  const detectRTL = (text: string): boolean =>
    /[\u0600-\u06FF]/.test(text);

  const showCaption = (text: string) => {
    if (clearTimer.current) clearTimeout(clearTimer.current);

    setCaption(text);
    setIsRTL(detectRTL(text));

    // Fade in
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 200,
      useNativeDriver: true,
    }).start();

    // Auto-clear after 4 seconds
    clearTimer.current = setTimeout(() => {
      Animated.timing(fadeAnim, {
        toValue: 0,
        duration: 400,
        useNativeDriver: true,
      }).start(() => setCaption(null));
    }, 4000);
  };

  useEffect(() => {
    // Ensure WS is connected
    const ws = getWebSocket() ?? connectWebSocket();

    const handleMessage = (event: MessageEvent) => {
      try {
        const data: CaptionMessage = JSON.parse(event.data as string);
        if (data.type === "caption" && data.text?.trim()) {
          showCaption(data.text.trim());
        }
      } catch {
        // ignore non-JSON messages
      }
    };

    ws.addEventListener("message", handleMessage);
    return () => {
      ws.removeEventListener("message", handleMessage);
      if (clearTimer.current) clearTimeout(clearTimer.current);
    };
  }, []);

  if (!caption) return null;

  return (
    <Animated.View style={[styles.container, { opacity: fadeAnim }]}>
      <View style={styles.bar}>
        <Text
          style={[
            styles.captionText,
            isRTL && styles.captionTextRTL,
          ]}
        >
          {caption}
        </Text>
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: "absolute",
    bottom: 24,
    left: 12,
    right: 12,
    zIndex: 999,
  },
  bar: {
    backgroundColor: "rgba(0, 33, 71, 0.88)", // AAST navy, semi-transparent
    borderRadius: 10,
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderLeftWidth: 4,
    borderLeftColor: "#C9A84C", // AAST gold
  },
  captionText: {
    color: "#FFFFFF",
    fontSize: 15,
    lineHeight: 22,
    textAlign: "left",
  },
  captionTextRTL: {
    textAlign: "right",
    writingDirection: "rtl",
  },
});
