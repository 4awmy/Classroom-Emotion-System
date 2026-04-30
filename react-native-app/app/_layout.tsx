import { Slot } from "expo-router";

export default function RootLayout() {
  // Render the Slot so nested routes mount immediately.
  // Navigation/redirect logic should run inside pages or
  // nested layouts to avoid navigating before the root is mounted.
  return <Slot />;
}
