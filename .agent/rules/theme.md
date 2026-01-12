---
trigger: always_on
---

### Global Theme & App Styles
* **Centralized Theme:** Define a centralized `ThemeData` object. Support `ThemeMode.light`, `ThemeMode.dark`, and `ThemeMode.system`.
* **Color System:** Use `ColorScheme.fromSeed` for harmonious palettes. Implement the **60-30-10 rule** (60% Neutral, 30% Secondary, 10% Accent).
    * *Custom Colors:* Use `ThemeExtension` for semantic colors (e.g., `success`, `danger`) not covered by Material 3.
* **Typography:** Use `google_fonts`. Define a strict `TextTheme` scale (Display, Title, Body). Prioritize legibility and font weight hierarchy.
* **Component Styling:** Define global styles in `ThemeData` (e.g., `elevatedButtonTheme`, `inputDecorationTheme`) to ensure consistency and reduce local styling.