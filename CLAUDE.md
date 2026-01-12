# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Eyesea Reporting is a mobile-first maritime pollution reporting app built with Flutter and hosted Supabase. Users capture pollution sightings, the app runs on-device AI analysis (YOLO), and reports are synced to the cloud with offline-first capabilities.

## Build & Development Commands

```bash
# Navigate to Flutter project
cd eyesea_reporting_2

# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run

# Run on web
flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0

# Run with Supabase credentials (if not using secrets.dart)
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key

# Code generation (for json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Build for production
flutter build ios --release
flutter build apk --release
flutter build web --release

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code
flutter analyze
```

## Architecture

### Clean Architecture Layers

```
lib/
├── core/           # Cross-cutting concerns
│   ├── services/   # Singletons: AIAnalysisService, ConnectivityService, ReportQueueService
│   ├── theme/      # AppTheme, AppColors (Space Grotesk font, Lucide icons)
│   └── secrets.dart # Git-ignored, contains SUPABASE_URL and SUPABASE_ANON_KEY
├── data/           # Implementation layer
│   ├── datasources/  # Supabase API calls (AuthDataSource, ReportDataSource, etc.)
│   └── repositories/ # Repository implementations
├── domain/         # Business logic
│   ├── entities/   # Core domain objects (ReportEntity, PendingReport, AIAnalysisResult)
│   └── repositories/ # Abstract repository interfaces
└── presentation/   # UI layer
    ├── providers/  # ChangeNotifier classes (AuthProvider, ReportsMapProvider)
    ├── routes/     # GoRouter configuration (AppRouter)
    └── [feature]/  # Feature screens and widgets
```

### Key Architectural Patterns

- **MVVM with Provider**: State management uses `ChangeNotifier` and `Provider`. No Riverpod/Bloc.
- **Manual Dependency Injection**: All dependencies are wired in `main.dart` and passed via `MultiProvider`.
- **Offline-First**: Reports queue locally in Hive, sync when connectivity restored via `ReportQueueService`.
- **On-Device AI**: YOLO model runs locally for privacy. iOS uses CoreML (`.mlpackage`), Android uses TFLite.
- **Client-Side Security**: Never rely solely on client-side validation. All critical validation and business logic must happen in Supabase (RLS, database functions, or Edge Functions).

### Data Flow for Reports

1. User captures image → `CameraCaptureScreen`
2. AI analysis runs → `AIAnalysisService` (YOLO detection)
3. Report form → `ReportDetailsScreen`
4. Save to queue → `ReportQueueService` (Hive)
5. Sync to Supabase → `ReportDataSource` when online
6. Display on map → `ReportsMapProvider` → `HomeScreen` (Mapbox)

### Navigation

GoRouter with `StatefulShellRoute.indexedStack` for bottom nav:
- `/` - HomeScreen (Map with markers)
- `/events` - EventsScreen
- `/report` - ReportScreen
- `/analysis` - AnalysisScreen
- `/profile` - ProfileScreen

Auth-guarded routes redirect through `/splash` → `/login` → `/onboarding` → `/`.

## Database & Supabase

### Critical Rules

- **No Docker/Local Supabase**: Always use hosted Supabase (`https://[project-ref].supabase.co`). Do not suggest `docker compose` or `supabase start`.
- **RLS Required**: Every table must have Row Level Security policies. Never leave tables open.
- **Migrations**: Located in `eyesea_reporting_2/supabase/migrations/`. Use `supabase db pull` and `supabase migration new`.
- **Destructive Operations**: Ask for confirmation before suggesting `DELETE` or `TRUNCATE`.

### Key Tables

- `reports` - Pollution reports with PostGIS geography column for location
- `report_images` - Links to storage, references reports
- `ai_analysis` - YOLO detection results per report
- `profiles` - User profiles linked to Supabase Auth

### Location Handling

Locations use PostGIS geography. The `get_reports_with_location` RPC returns `POINT(lng lat)` format. Client parses this in `ReportEntity.fromJson()`.

## Secrets & Environment

Create `lib/core/secrets.dart` (git-ignored):

```dart
class Secrets {
  static const supabaseUrl = 'https://your-project.supabase.co';
  static const supabaseAnonKey = 'your-anon-key';
}
```

Mapbox token is in `android/app/src/main/AndroidManifest.xml` and iOS `Info.plist`.

## AI/ML Integration

- **Package**: `ultralytics_yolo: ^0.1.46`
- **iOS Model**: `ios/yolo11n.mlpackage/` (CoreML)
- **Android Model**: `android/app/src/main/assets/*.tflite`
- **Confidence Threshold**: 0.25
- **Privacy-First**: All AI processing happens on-device. No images sent to external APIs.

### Detection Categories

- **People Detection**: Blocks submission if people detected (privacy protection)
- **Pollution Items**: Bottles, cups, bags, debris, fishing gear, containers
- **Scene Context**: Beach, outdoor, water for better categorization
- **Multi-Category**: Can detect multiple pollution types per image

Maps YOLO classes to `PollutionType` enum: plastic, oil, debris, sewage, fishingGear, container, other.

## Styling Conventions

- **Font**: Space Grotesk via `google_fonts`
- **Icons**: Lucide Icons (`lucide_icons` package)
- **Colors**: 60-30-10 rule (60% Neutral, 30% Secondary, 10% Accent) using `ColorScheme.fromSeed`
- **Theme**: Centralized `ThemeData` with Light/Dark/System support
- **Logging**: Use `dart:developer` `log()`, never `print()`

## Report Status Flow

`ReportStatus` enum: `pending` → `verified` → `resolved` (recovered) | `rejected`

Markers: Blue for active (pending/verified), Green for resolved.

## Dart Code Standards

- **Null Safety**: Write soundly null-safe code. Avoid `!` unless guaranteed safe.
- **Immutability**: Prefer immutable data structures. `StatelessWidget` must be immutable.
- **Async**: Use `Future/await` for operations, `Stream` for events. Handle async errors with `try-catch`.
- **Serialization**: `json_serializable` with `fieldRename: FieldRename.snake`
- **Performance**: Use `const` constructors, `ListView.builder` for long lists, `compute()` for expensive tasks.
