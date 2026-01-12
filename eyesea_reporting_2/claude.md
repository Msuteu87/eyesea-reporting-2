# Project Rules & Guidelines

## 1. Global Guidelines: Production & Strategy
**Context:** High-level constraints, security mandates, and infrastructure rules that apply to the entire project lifecycle.

### Identity & Stack
* **Persona:** Expert Flutter/Dart developer and Supabase architect. Focus on production-ready, secure, and performant code.
* **Primary Stack:** Flutter, Dart, and **Hosted Supabase** (Production via HTTPS).

### Infrastructure Constraints (Critical)
* **No Docker/Local Hosting:** Do not suggest `docker compose`, `supabase start`, or local Docker-based Supabase environments.
* **HTTPS Only:** All Supabase interactions must target the production/hosted URL (`https://[project-ref].supabase.co`).
* **Supabase Extension:** Use the Supabase MCP extension to introspect remote schemas. Do not assume local files represent the truth.

### Database & Security
* **RLS First:** Every table creation or modification **must** include Row Level Security (RLS) policies. Never leave a table "Open".
* **Production Safety:** Explicitly ask for confirmation before suggesting `DELETE` or `TRUNCATE` operations.
* **Schema Management:** Use Supabase CLI only for `db pull` (sync types) and `migration new` (track changes). Avoid commands requiring Docker.
* **Secrets:** Never hardcode keys. Reference `lib/core/secrets.dart` (assumed to exist locally).

### Client-Side Insecurity and Backend Reliance
Always assume that any data or logic executed on the client-side (your Flutter app) can be compromised or manipulated. Therefore, all critical data-related processes, especially those involving sensitive information, authorization, or data integrity, **must** be handled on the backend (Supabase). This includes:
* **Authentication and Authorization:** Supabase Auth and RLS are the ultimate source of truth.
* **Data Validation:** Implement critical validation in Database Functions or Edge Functions.
* **Sensitive Operations:** Modify critical via secure backend calls, not client-side direct access without verification.

---

## 2. Flutter & Dart Standards
**Context:** Language-specific best practices and performance standards.

### Core Principles
* **SOLID:** Apply SOLID principles. Favor composition over inheritance.
* **Immutability:** Prefer immutable data structures. `StatelessWidget` must be immutable.
* **Null Safety:** Write soundly null-safe code. Avoid `!` unless absolutely guaranteed safe.
* **Error Handling:** Never let code fail silently. Use `try-catch` and custom exceptions.

### Dart Style & Syntax
* **Formatting:** Follow "Effective Dart". Use `PascalCase` (Classes), `camelCase` (Members), `snake_case` (Files).
* **Async:** Use `Future/await` for operations, `Stream` for events. Handle async errors robustly.
* **Modern Syntax:** Use arrow syntax for one-liners, exhaustive `switch` expressions, and Records/Pattern Matching.

### Performance
* **Const:** Use `const` constructors wherever possible.
* **Lists:** Use `ListView.builder` or `SliverList` for long lists.
* **Isolates:** Use `compute()` for expensive tasks.

### Synchronization Strategies
* **Strategies:** Manual, Periodic, or Event-Driven sync.
* **Offline:** Ensure local data models align with Supabase schema. Handle network errors gracefully.

---

## 3. Architecture & Tech Stack
* **Architecture:** MVVM (Model-View-ViewModel) with strict Domain -> Data -> Presentation separation.
* **State Management:** `ValueNotifier`, `ChangeNotifier`, or `StreamBuilder`. Manual dependency injection via `Provider`.
* **Routing:** `go_router` for declarative navigation.
* **Backend:** Supabase (Hosted) for data storage, auth, and real-time sync.
* **AI/ML:** On-device computer vision using Ultralytics YOLO (YOLOv11n model) for object detection and pollution classification.
* **Offline-First:** Hive for local storage with queue-based sync for reports.
* **Maps:** Mapbox Maps for location-based features.
* **Serialization:** `json_serializable` (`fieldRename: FieldRename.snake`).
* **Logging:** `dart:developer` `log()` (No `print`).

---

## 4. Code Generation
* **Build Runner:** Use `build_runner` for JSON serialization.
* **Command:** `dart run build_runner build --delete-conflicting-outputs`.

---

## 5. Visual Design & Aesthetics
* **Premium Feel:** Apply subtle noise textures to main backgrounds.
* **Depth & Shadows:** Use multi-layered drop shadows. Colored shadows for "glow".
* **Responsive:** Use `LayoutBuilder` and `MediaQuery`.
* **Iconography:** Incorporate icons liberally.

---

## 6. Secrets Management
* **Local Secrets:** Store credentials in git-ignored `lib/core/secrets.dart`.

---

## 7. Global Theme
* **ThemeData:** Centralized. Support Light, Dark, System.
* **Colors:** `ColorScheme.fromSeed`. 60-30-10 rule.
* **Typography:** `google_fonts` with Space Grotesk. Strict `TextTheme` scale.
* **Icons:** Lucide Icons for consistent, modern iconography.

---

## 8. AI & Computer Vision
* **On-Device Analysis:** Use Ultralytics YOLO (YOLOv11n) for real-time object detection.
* **Privacy-First:** All AI processing happens on-device. No images are sent to external APIs.
* **Detection Categories:**
  - **People Detection:** Block report submission if people are detected (privacy protection).
  - **Pollution Items:** Detect bottles, cups, bags, debris, fishing gear, containers, etc.
  - **Scene Context:** Identify environment (beach, outdoor, water) for better categorization.
* **Multi-Category Support:** AI can detect multiple pollution types in a single image.
* **Model Location:**
  - iOS: `.mlpackage` in `ios/` directory (CoreML format)
  - Android: `.tflite` in `android/app/src/main/assets/` directory
* **Performance:** Use `confidenceThreshold: 0.25` for balanced accuracy and detection rate.

---

## 9. Offline-First Architecture
* **Queue Service:** Reports are queued locally (Hive) and auto-sync when online.
* **Connectivity Service:** Monitor network status with `connectivity_plus`.
* **Image Compression:** Compress images before storage using `flutter_image_compress`.
* **Sync Strategy:** Automatic background sync when connection restored.
* **User Feedback:** Clear indicators for offline mode and pending sync status.
