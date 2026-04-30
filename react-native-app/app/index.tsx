import { Redirect } from "expo-router";

/**
 * Root route — immediately redirect unauthenticated users to the login screen.
 * In Phase 2 this can check the Zustand token and redirect to home if already
 * logged in.
 */
export default function Index() {
  return <Redirect href="/(auth)/login" />;
}
