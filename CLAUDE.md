# Avagenc Chat — iOS

Native iOS client (SwiftUI) for **Avagenc Chat**. UI/UX follows mobile
patterns (toolbar + sheet + push navigation) with Avagenc's signature
visual design (warm cream, Newsreader serif).

## Product facts (do not re-assume)

- **Multi-agent group chat**, not a regular AI chat. Ava (orchestrator) +
  specialists Zee (Tuya), Yori (Spotify), Rafal (Google Workspace). Routing
  via `@mention` (`Agents.route`), not a model picker.
- **One thread per user** (`chat-<uid>`, derived server-side from the token).
  No conversation list. "Reset chat & knowledge" = `DELETE /knowledge`
  (deletes ALL user data in Zep).
- **No streaming.** An agent POST blocks until orchestration finishes; while
  waiting, the thread is polled every 2.2 s (`ConversationStore.runTurn` —
  see `pendingBaseline`, `fetchSeq`, 90 s watch window).
- **Plain text** — no markdown/code blocks. Newsreader serif for message body.
- **Single warm-cream theme** — no dark mode (`preferredColorScheme(.light)`).
- **Real Rupiah wallet** (`GET /wallet`, `/wallet/usage/today` requires the
  `time-zone` header); 402 = out of balance (`errorNote: saldo`). Top-up is a
  **stub** (Midtrans endpoint disabled on the backend) → ends in an info alert.
- **Postera** = Ava's scheduled self-wake-up messages (`GET /postera` —
  PascalCase response, Go structs without json tags).
- Required headers on every request: `Authorization: Bearer <Firebase ID
  token>` + `time-zone` (IANA). Backend errors are always `{"detail": "..."}`.

## Configuration & auth

- `Core/AppConfig.swift`: `apiBase` = Cloud Run backend URL; `webAppURL` —
  web origin for `/legal` links (empty = links render as plain text).
- **Auth = Firebase SDK + GoogleSignIn SDK** (SPM: `firebase-ios-sdk` product
  `FirebaseAuth`, `GoogleSignIn-iOS`). Configured from
  `chat-ios/GoogleService-Info.plist` (bundle `avagenc.chat-ios`).
  `FirebaseApp.configure()` in the AppDelegate (chat_iosApp.swift); URL
  callback scheme = REVERSED_CLIENT_ID in Info.plist; backend token =
  `user.idTokenForcingRefresh(false)` (Core/AuthService.swift). Sessions are
  persisted by the Firebase SDK.
- Integration linking (gworkspace/spotify): status/disconnect work; the full
  connect flow needs the backend to register the mobile redirect URI
  (`avagenc-chat://…`).

## Structure

```
chat-ios/
  Core/        Theme (design tokens — FINAL, do not "fix"),
               Agents (roster+routing), Models (backend contract DTOs),
               APIClient, AuthService, ConversationStore, Stores
  Views/       Login/, Chat/ (ChatScreen, MessageRow, Composer),
               Info/, Profile/, Postera/, Shared/, MainView, ContentView
  Fonts/       Newsreader + Inter Tight (400/500/600) — registered
               programmatically in chat_iosApp + UIAppFonts
  Assets/      avagenc-{ink,accent,cream} (SVG vectors; fill must be on
               <path>, not <svg> — CoreSVG does not inherit), brand-*, google-g
```

## Verification

- The client always talks to the Cloud Run backend (`AppConfig.apiBase`) with
  real Firebase auth — there is no dev/mock mode in the app.
- DEBUG launch args for automation: `-openScreen profile|postera|info|search`,
  `-openTopup`, `-autoSend "<text>"` (requires a signed-in Firebase session
  in the simulator).
- Build: `xcodebuild -project chat-ios.xcodeproj -scheme chat-ios -destination
  'platform=iOS Simulator,name=iPhone 17 Pro' build`.

## Xcode project notes

- `PBXFileSystemSynchronizedRootGroup`: new files under `chat-ios/` join the
  target automatically; `Info.plist` is excluded via an exception set
  (INFOPLIST_FILE + GENERATE_INFOPLIST_FILE merge). Resource subfolders are
  flattened into the bundle root.
- Default actor isolation MainActor + MemberImportVisibility are enabled:
  pure helpers are marked `nonisolated`, `import UIKit` must be explicit.
