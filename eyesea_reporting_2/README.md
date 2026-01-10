# Eyesea Reporting 2

A Flutter-based maritime reporting application with Supabase backend integration and offline capabilities.

## Features

- Cross-platform support (Web, iOS, Android)
- Supabase backend integration for authentication and data storage
- Offline-first architecture with SQLite local database
- Clean architecture design pattern
- Material 3 design system with light/dark theme support

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **Supabase** - Backend-as-a-Service (Auth, Database, Storage)
- **GoRouter** - Declarative navigation and deep linking
- **Provider** - State management
- **SQLite (sqflite)** - Local database for offline support

## Project Structure

```
lib/
├── core/                  # Core functionalities
│   ├── constants/         # App-wide constants
│   ├── errors/            # Custom exceptions and failures
│   ├── network/           # Network utilities
│   └── utils/             # General utilities (logger)
├── data/                  # Data layer
│   ├── datasources/       # Supabase and local data sources
│   ├── models/            # Data models
│   └── repositories/      # Repository implementations
├── domain/                # Business logic layer
│   ├── entities/          # Business objects
│   ├── repositories/      # Repository interfaces
│   └── usecases/          # Use cases
├── presentation/          # UI layer
│   ├── auth/              # Authentication screens
│   ├── home/              # Home screen
│   ├── shared/            # Reusable widgets
│   └── routes/            # GoRouter configuration
├── main.dart              # Entry point with Supabase init
└── app.dart               # Root widget with theme/router
```

## Getting Started

### Prerequisites

- Flutter SDK (3.x or higher)
- Dart SDK
- Supabase account (for backend features)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run -d web-server --web-port 5000 --web-hostname 0.0.0.0
   ```

### Environment Variables

To enable Supabase integration, provide the following environment variables:

```bash
flutter run --dart-define=SUPABASE_URL=your_supabase_url \
            --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Your Supabase anonymous key |

## Building for Production

### Web
```bash
flutter build web --release
```

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Architecture

This project follows **Clean Architecture** principles:

- **Presentation Layer**: UI components, screens, and state management
- **Domain Layer**: Business logic, entities, and use cases
- **Data Layer**: Repositories, data sources, and models

## Contributing

1. Follow the Dart style guide
2. Ensure all tests pass
3. Use meaningful commit messages
4. Create feature branches for new development

## License

This project is proprietary software. All rights reserved.
