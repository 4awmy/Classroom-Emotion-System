# React Native Mobile App — AAST LMS

Student-facing mobile application for the AAST Learning Management System. Built with **React Native (Expo Router)** and **TypeScript**.

## ✅ Implemented Features (Phase 1)

### P1-S4-01: Expo Scaffold

- Expo Router navigation with auth group separation
- Zustand state management
- TypeScript configuration

### P1-S4-02: Auth Screen

- Student ID + Password login form
- Mock JWT authentication (demo/demo)
- Stores token in headers for future requests

### P1-S4-03: Home Screen

- Shows upcoming lectures (mock data)
- "Join Lecture" button navigation
- Engagement summary placeholder

### ✅ **P1-S4-05: AppState Logging** ← **THIS ISSUE**

- **Monitors AppState changes** (active/background/inactive)
- **Logs all transitions** with timestamps to console
- **Records strikes** when app goes to background during focus mode
- **Real-time display** of AppState logs in UI
- **Strike counter** increments on background transitions
- Ready for Phase 2 WebSocket integration

### P1-S4-04: Focus Mode Stub

- Foundation for strike tracking
- AppState monitoring ready
- Strike counter UI

## 🚀 Quick Start

### Prerequisites

```bash
# Node.js 18+
node --version

# Expo CLI
npm install -g expo-cli eas-cli
expo --version
```

### Installation & Run

```bash
# Install dependencies
npm install

# Set environment variables
cp .env.example .env

# Start Expo development server
npm start

# Then choose:
# 'a' → Android emulator
# 'i' → iOS simulator (Mac only)
# Scan QR code → Expo Go app (physical device)
```

**Demo Credentials:**

- Student ID: `demo`
- Password: `demo`

## 📂 Project Structure

```
react-native-app/
├── app/
│   ├── _layout.tsx              # Root navigation setup
│   ├── (auth)/
│   │   └── login.tsx            # P1-S4-02: Auth screen
│   └── (student)/
│       ├── home.tsx             # P1-S4-03: Upcoming lectures
│       ├── focus.tsx            # ✅ P1-S4-05: AppState logging
│       └── notes.tsx            # Smart notes viewer
├── components/
│   ├── CaptionBar.tsx           # P1-S4 stub: Live captions
│   ├── FocusOverlay.tsx         # Strike counter UI
│   └── NotesViewer.tsx          # Markdown display
├── store/
│   └── useStore.ts             # Zustand global store
├── services/
│   └── api.ts                  # HTTP + WebSocket client
├── package.json
├── app.json                    # Expo config
├── .env.example
└── README.md
```

## 🔍 AppState Logging Details (P1-S4-05)

**What it does:**

1. ✅ Listens to `AppState` events from React Native
2. ✅ Logs every state change with ISO timestamp
3. ✅ Records background transitions as "strikes"
4. ✅ Displays logs in real-time on focus screen
5. ✅ Increments strike counter

**Console Output Example:**

```
[FocusMode] Setting up AppState listener
[FocusMode] AppState change: 2025-04-30 10:45:23 → background
[FocusMode] ⚠️  STRIKE RECORDED: {
  student_id: "S01",
  lecture_id: "L1",
  type: "app_background",
  timestamp: "10:45:23"
}
[FocusMode] AppState change: 2025-04-30 10:45:30 → active
```

**UI Display:**

- Real-time log viewer showing last 20 transitions
- Status cards showing: Student ID, Lecture ID, Strikes, Current State
- Color-coded strike counter (red when > 0)

## 📝 Testing

### Manual Test Checklist

#### Test AppState Logging (P1-S4-05)

```
1. ✅ Login with demo/demo
2. ✅ Tap "Join" on a lecture
3. ✅ Watch focus.tsx load
4. ✅ Press home button on device
   → Console should show: "[FocusMode] AppState change: ... → background"
   → Console should show: "[FocusMode] ⚠️  STRIKE RECORDED"
   → Strike counter should increment
   → Focus screen logs should update in real-time
5. ✅ Return to app (foreground)
   → Console should show: "[FocusMode] AppState change: ... → active"
```

### Expected Logs

When testing on a physical device or emulator:

```javascript
// Background transition
[FocusMode] AppState change: 2025-04-30 10:45:23 → background
[FocusMode] ⚠️  STRIKE RECORDED: {
  student_id: "demo",
  lecture_id: "L1",
  type: "app_background",
  timestamp: "10:45:23"
}

// Foreground transition
[FocusMode] AppState change: 2025-04-30 10:45:30 → active
```

## 🔗 API Integration (Phase 2)

Currently using mock data. Phase 2 will connect to:

- `POST /auth/login` — Real authentication
- `GET /session/upcoming` — Real lecture list
- `WS /session/ws` — WebSocket captions + events
- `POST /socket.emit('strike', ...)` — Real strike emission

## 🏗️ Building APK (Phase 4)

```bash
# Build Android APK (free tier)
eas build --platform android --profile preview

# Download APK from expo.dev dashboard
# Install on physical device
```

## 📞 Support

For issues:

1. Check console logs (Expo Dev Tools → Console)
2. Run `expo start --clear` to clear cache
3. Check `.env` is set correctly
4. Verify FastAPI backend is running on specified URL

## 📄 License

AAST LMS © 2025
