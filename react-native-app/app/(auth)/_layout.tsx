import { Stack } from "expo-router";

/**
 * Layout for the (auth) route group.
 * Renders auth screens (login) in a header-less stack so they appear
 * full-screen without the default navigation chrome.
 */
export default function AuthLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="login" />
    </Stack>
  );
}
