# Eyesea Reporting 2

## Overview
Eyesea Reporting 2 is a Flutter-based maritime reporting application with Supabase backend integration and offline capabilities using SQLite.

## Current State
- Project initialized with clean architecture folder structure
- Supabase integration configured (requires credentials)
- GoRouter for navigation
- Provider for state management (ready to implement)
- Basic authentication screens scaffolded

## Project Architecture

### Folder Structure
```
eyesea_reporting_2/
├── lib/
│   ├── core/                  # Core functionalities
│   │   ├── constants/         # App-wide constants
│   │   ├── errors/            # Custom exceptions and failures
│   │   ├── network/           # Network utilities
│   │   └── utils/             # General utilities (logger)
│   ├── data/                  # Data layer
│   │   ├── datasources/       # Supabase and local data sources
│   │   ├── models/            # Data models
│   │   └── repositories/      # Repository implementations
│   ├── domain/                # Business logic layer
│   │   ├── entities/          # Business objects
│   │   ├── repositories/      # Repository interfaces
│   │   └── usecases/          # Use cases
│   ├── presentation/          # UI layer
│   │   ├── auth/              # Authentication screens
│   │   ├── home/              # Home screen
│   │   ├── shared/            # Reusable widgets
│   │   └── routes/            # GoRouter configuration
│   ├── main.dart              # Entry point with Supabase init
│   └── app.dart               # Root widget with theme/router
├── assets/                    # Static assets
└── test/                      # Tests
```

### Key Technologies
- **Flutter**: Cross-platform UI framework
- **Supabase**: Backend-as-a-Service (Auth, Database, Storage)
- **GoRouter**: Declarative routing
- **SQLite (sqflite)**: Local database for offline support
- **Provider**: State management

## Environment Variables
Required for Supabase integration:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous key

## Running the App
```bash
cd eyesea_reporting_2
flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0
```

With Supabase credentials:
```bash
flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0 \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key
```

## Recent Changes
- **2026-01-10**: Project initialized with clean architecture structure
  - Flutter project created
  - Added dependencies: supabase_flutter, go_router, sqflite, path_provider, provider
  - Set up core, data, domain, presentation layers
  - Created basic home and login screens
  - Configured strict linting rules

## User Preferences
- Clean architecture pattern
- Feature-first folder organization
- Strict linting enabled
- Material 3 design system
