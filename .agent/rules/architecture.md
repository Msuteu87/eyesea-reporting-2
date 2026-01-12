---
trigger: always_on
---

### Architecture & Tech Stack
* **Architecture:** MVVM (Model-View-ViewModel) with strict Domain -> Data -> Presentation separation.
* **State Management:** `ValueNotifier`, `ChangeNotifier`, or `StreamBuilder`. Manual dependency injection.
* **Routing:** `go_router` for declarative navigation and deep linking.
* **Backend:** Supabase (Hosted).
* **Serialization:** `json_serializable` (`fieldRename: FieldRename.snake`).
* **Logging:** `dart:developer` `log()` (No `print`).