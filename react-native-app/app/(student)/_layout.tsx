import { Stack } from "expo-router";

/**
 * Layout for the (student) route group.
 * Uses a Stack navigator so home → focus → notes push/pop correctly.
 * Individual screens control their own header title via `<Stack.Screen
 * options={{ title: '...' }}>` or the route options prop.
 */
export default function StudentLayout() {
  return (
    <Stack
      screenOptions={{
        headerStyle: { backgroundColor: "#002147" },
        headerTintColor: "#fff",
        headerTitleStyle: { fontWeight: "bold" },
      }}
    >
      <Stack.Screen name="home" options={{ title: "AAST LMS" }} />
      <Stack.Screen name="focus" options={{ title: "Focus Mode" }} />
      <Stack.Screen name="notes" options={{ title: "Smart Notes" }} />
    </Stack>
  );
}
