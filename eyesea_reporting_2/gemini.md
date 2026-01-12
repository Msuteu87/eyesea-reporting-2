# Guidelines for Eyesea Reporting 2: Flutter + Supabase + Dart Project

This document provides comprehensive guidelines and best practices for developing the "Eyesea Reporting 2" application using Flutter (Dart), Supabase as the backend, and incorporating robust offline capabilities. Adhering to these principles will ensure a maintainable, scalable, and secure application.

---

## Current Implementation Status

| Feature | Status |
|---------|--------|
| Clean Architecture | ✅ Implemented |
| Supabase Auth | ✅ Implemented |
| Use Cases Layer | ✅ Implemented |
| Split Data Sources | ✅ Implemented |
| Data Models | ✅ Implemented |
| Theme System (Light/Dark) | ✅ Implemented |
| SSO Placeholder | ✅ Placeholder Added |
| Reports CRUD | 🟡 Data source only |
| Offline Mode | ⬜ Not started |

### Environment Setup

1. Copy `lib/core/secrets.dart.example` to `lib/core/secrets.dart`
2. Add your Supabase credentials:
   ```dart
   class Secrets {
     static const String supabaseUrl = 'YOUR_URL';
     static const String supabaseAnonKey = 'YOUR_KEY';
   }
   ```
3. Run `flutter pub get`
4. Run `flutter run -d web-server --web-port 5001`

---

## 1. Project Setup and Dependencies

### 1.1 Flutter Initialization

Initialize your Flutter project with a focus on clean architecture and state management. The project name will be "eyesea_reporting_2".

```bash
flutter create eyesea_reporting_2
cd eyesea_reporting_2
```

### 1.2 Supabase Integration

Integrate the Supabase client library for Dart. Ensure environment variables are used for API keys and URLs.

```bash
flutter pub add supabase_flutter
```

Configure Supabase in your `main.dart` or a dedicated initialization file:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const MyApp());
}

// Access Supabase client anywhere
final supabase = Supabase.instance.client;
```

### 1.3 Dart and Flutter Configuration

Ensure your `pubspec.yaml` manages dependencies effectively and your `analysis_options.yaml` enforces strict linting rules for code quality.

### 1.4 Routing with GoRouter

Implement routing using `go_router` for declarative navigation and deep linking. This provides a robust and scalable routing solution for Flutter applications.

```bash
flutter pub add go_router
```

## 2. Folder Structure Best Practices

A well-organized folder structure is paramount for maintainability and scalability in Flutter projects. A feature-first or clean architecture approach is recommended.

```
eyesea_reporting_2/
├── lib/
│   ├── core/                  # Core functionalities, constants, utilities
│   │   ├── constants/         # App-wide constants
│   │   ├── errors/            # Custom error handling
│   │   ├── network/           # Network-related utilities (e.g., Dio interceptors)
│   │   └── utils/             # General utility functions
│   ├── data/                  # Data layer (repositories, data sources, models)
│   │   ├── datasources/       # Remote and local data sources
│   │   ├── models/            # Data models (from Supabase, local DB)
│   │   └── repositories/      # Abstractions for data operations
│   ├── domain/                # Business logic layer (entities, use cases, repositories interfaces)
│   │   ├── entities/          # Core business objects
│   │   ├── repositories/      # Abstract repository definitions
│   │   └── usecases/          # Business logic operations
│   ├── presentation/          # UI layer (screens, widgets, view models/blocs)
│   │   ├── auth/              # Authentication-related screens and widgets
│   │   ├── home/              # Home screen and related widgets
│   │   ├── shared/            # Reusable UI widgets
│   │   └── routes/            # GoRouter configuration
│   ├── main.dart              # Application entry point
│   └── app.dart               # Root widget, theme, and router setup
├── assets/                    # Static assets like images, fonts
├── test/                      # Unit and widget tests
├── pubspec.yaml
├── analysis_options.yaml
└── ...
```

### Explanation of Directories:

*   `core/`: Contains fundamental, app-wide components that are independent of specific features.
*   `data/`: Handles data retrieval, caching, and persistence. It abstracts the data sources from the business logic.
*   `domain/`: Encapsulates the core business rules and entities. It should be independent of any frameworks.
*   `presentation/`: Manages the user interface and presentation logic, including screens, widgets, and state management (e.g., Provider, BLoC, Riverpod).
*   `assets/`: Stores static resources.
*   `test/`: Contains all automated tests.

## 3. Code Maintainability and Quality

### 3.1 Dart for Type Safety

Leverage Dart's strong type system and null safety features. Define clear models and interfaces. Use Supabase's type generation tools (if available for Dart) or manual mapping to ensure data consistency.

### 3.2 Consistent Code Style

Adhere to the [Dart Style Guide](https://dart.dev/guides/language/effective-dart) [1]. Use `dart format` and integrate linting rules (via `analysis_options.yaml`) into your CI/CD pipeline to enforce consistency.

### 3.3 Modularization and Reusability

Break down complex features into smaller, focused modules (widgets, services, providers). Apply the Single Responsibility Principle (SRP) to functions and classes.

### 3.4 Clear Naming Conventions

Follow Dart's naming conventions (e.g., `camelCase` for variables and functions, `PascalCase` for classes). Use descriptive names for better readability.

### 3.5 Comments and Documentation

Write clear, concise comments for complex logic and public APIs. Utilize Dart's documentation comments (`///`) for generating API documentation.

## 4. Avoiding Technical Debt

### 4.1 Incremental Development

Build features incrementally, focusing on delivering small, functional pieces. Avoid over-engineering upfront.

### 4.2 Regular Refactoring

Schedule regular refactoring sessions to improve code quality, remove dead code, and address any accumulated technical debt. This is an ongoing process.

### 4.3 Automated Testing

Implement a robust testing strategy including unit, widget, and integration tests. This helps catch bugs early and provides confidence when making changes.

### 4.4 Code Reviews

Conduct thorough code reviews to ensure adherence to best practices, identify potential issues, and share knowledge within the team.

## 5. Clean and Simple Implementations

### 5.1 State Management

For local widget state, use `StatefulWidget` or `ValueNotifier`. For global state, consider `Provider`, `Riverpod`, or `BLoC/Cubit`. Choose a state management solution that fits your project's complexity and team's familiarity.

### 5.2 Asynchronous Operations

Handle asynchronous operations (e.g., Supabase calls, network requests) using Dart's `async/await` for cleaner, more readable code. Implement proper error handling with `try...catch` blocks.

### 5.3 Supabase Interaction

Centralize Supabase interactions in dedicated data sources or repositories within the `data` layer. This keeps your UI components clean and focused on presentation logic.

```dart
// lib/data/datasources/remote_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteDataSource {
  final SupabaseClient supabase;

  RemoteDataSource(this.supabase);

  Future<List<Map<String, dynamic>>> fetchReports() async {
    final response = await supabase.from('reports').select().execute();
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
    return response.data as List<Map<String, dynamic>>;
  }
}
```

### 5.4 Widget Design

Design widgets to be small, focused, and reusable. Pass data down via constructor parameters and communicate up via callbacks. Avoid deeply nested widgets that are hard to reason about.

### 5.5 GoRouter Usage

Define your routes declaratively using `GoRouter`. Utilize named routes and route parameters for clear navigation. Implement authentication guards to protect routes.

## 6. Security Considerations

### 6.1 Environment Variables

Store sensitive information (e.g., Supabase API keys) securely. For Flutter, use `flutter_dotenv` or Dart's `String.fromEnvironment` with `--dart-define` for build-time configuration.

### 6.2 Row Level Security (RLS)

Enable and configure Supabase Row Level Security (RLS) policies to control data access at the database level. This is critical for securing your data.

### 6.3 Client-Side Insecurity and Backend Reliance

Always assume that any data or logic executed on the client-side (your Flutter app) can be compromised or manipulated. Therefore, all critical data-related processes, especially those involving sensitive information, authorization, or data integrity, **must** be handled on the backend (Supabase). This includes:

*   **Authentication and Authorization:** While client-side checks can improve UX, the ultimate source of truth for user authentication and authorization should always be Supabase's Auth and Row Level Security (RLS).
*   **Data Validation and Business Logic:** Implement all critical data validation and business logic within Supabase database functions (e.g., PostgreSQL functions) or Edge Functions. Never rely solely on client-side validation for data integrity.
*   **Sensitive Operations:** Any operation that modifies critical data, performs financial transactions, or grants permissions should be executed via secure backend calls, not directly from the client without server-side verification.

This principle means that your client-side code should primarily focus on UI presentation and user interaction, while the backend (Supabase) is responsible for data persistence, security, and core business logic.

### 6.4 Input Validation

Always validate user input on both the client-side and server-side (via Supabase functions or database constraints) to prevent injection attacks and ensure data integrity.

## 7. Offline Capabilities with SQLite

Implementing robust offline capabilities is crucial for "Eyesea Reporting 2". SQLite will serve as the local data store, synchronized with Supabase.

### 7.1 Local Data Persistence

Use `sqflite` or `drift` (formerly Moor) for managing your local SQLite database. `drift` offers a more robust and type-safe solution for complex schemas.

```bash
flutter pub add sqflite path_provider
# Or for drift
flutter pub add drift drift_dev sqlite3_flutter_libs build_runner
```

### 7.2 Synchronization Strategies

Choose an appropriate synchronization strategy to keep local and remote data consistent:

*   **Manual Sync:** User-initiated sync for less critical data.
*   **Periodic Sync:** Background sync at regular intervals.
*   **Event-Driven Sync:** Trigger syncs based on specific events (e.g., network availability, data changes).
*   **Conflict Resolution:** Implement clear rules for resolving conflicts during synchronization (e.g., last-write-wins, client-wins, server-wins, or custom logic).

Consider using libraries like **Brick** or **PowerSync** [2] [3] for advanced offline-first capabilities, as they provide robust solutions for syncing and conflict resolution with Supabase.

### 7.3 Best Practices for Offline Data

*   **Data Model Consistency:** Ensure your local data models align with your Supabase schema.
*   **Error Handling:** Gracefully handle network errors and synchronization failures.
*   **User Feedback:** Provide clear visual feedback to the user about sync status.
*   **Security:** Encrypt sensitive data stored locally.


## 9. Model Context Protocol (MCP) Servers

Leveraging MCP servers can significantly enhance your development workflow by enabling AI assistants to interact directly with your project's context, tools, and data. This section outlines key MCP servers relevant to the Flutter + Supabase + Dart stack.

### 9.1 Supabase MCP Server

The official Supabase MCP Server connects your AI assistant directly to your Supabase projects, allowing for intelligent database management and configuration.

#### Key Features:
*   **Database Management:** Design tables, track migrations, run SQL queries, and manage database branches through natural language commands.
*   **Schema Awareness:** Generate TypeScript types directly from your database schema, ensuring type safety across your application. (Note: AI can assist in mapping these to Dart models).
*   **Project Configuration:** Fetch project-specific details like Supabase URL and anonymous keys, and automatically update environment variables.
*   **Debugging:** Retrieve and analyze logs to diagnose and resolve backend issues efficiently.

#### Configuration for Claude Desktop:
```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["supabase-mcp-server"],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "your_supabase_personal_access_token"
      }
    }
  }
}
```

### 9.2 Dart and Flutter MCP Server

The official Dart and Flutter MCP Server transforms your AI assistant into a powerful development partner, providing deep insights and control over your Flutter projects.

#### Key Features:
*   **Code Analysis and Fixes:** Analyze and automatically fix errors in your project's Dart and Flutter code.
*   **Symbol Resolution:** Resolve symbols to elements, fetching documentation and signature information.
*   **App Interaction:** Introspect and interact with your running Flutter application.
*   **Package Management:** Search `pub.dev` for packages and manage dependencies in `pubspec.yaml`.
*   **Testing:** Run tests and analyze results directly through AI commands.
*   **Code Formatting:** Format code consistently using `dart format`.

#### Configuration for Claude Desktop:
```json
{
  "mcpServers": {
    "flutter": {
      "command": "flutter",
      "args": ["mcp-server"],
      "env": {
        "FLUTTER_ROOT": "/path/to/your/flutter/sdk"
      }
    }
  }
}
```

## 10. Performance Optimization

### 10.1 Widget Optimization

Use `const` widgets where possible to prevent unnecessary rebuilds. Optimize `build` methods to be lean and efficient.

### 10.2 Image Optimization

Optimize images for mobile using appropriate formats (e.g., WebP) and compression. Use Flutter's `Image.asset` or `CachedNetworkImage` for efficient loading.

### 10.3 List Virtualization

For long lists, use `ListView.builder` or `CustomScrollView` with `SliverList/SliverGrid` to virtualize rendering and improve performance.

## 11. Deployment

### 11.1 Flutter Build and Release

Use Flutter's built-in tools for building and releasing your application to various platforms (Android, iOS, Web, Desktop). Configure `build.yaml` for different environments.

### 11.2 Supabase Deployment

Supabase projects are hosted and managed by Supabase. Ensure your database schema and RLS policies are correctly configured in your Supabase project.

## References

[1] Dart Style Guide: [https://dart.dev/guides/language/effective-dart](https://dart.dev/guides/language/effective-dart)
[2] Building offline-first mobile apps with Supabase, Flutter and Brick: [https://supabase.com/blog/offline-first-flutter-apps](https://supabase.com/blog/offline-first-flutter-apps)
[3] Flutter Tutorial: Building An Offline-First Chat App With Supabase And PowerSync: [https://www.powersync.com/blog/flutter-tutorial-building-an-offline-first-chat-app-with-supabase-and-powersync](https://www.powersync.com/blog/flutter-tutorial-building-an-offline-first-chat-app-with-supabase-and-powersync)
[4] Supabase MCP Server Blog: [https://supabase.com/blog/mcp-server](https://supabase.com/blog/mcp-server)
[5] Dart and Flutter MCP server Documentation: [https://docs.flutter.dev/ai/mcp-server](https://docs.flutter.dev/ai/mcp-server)
