---
trigger: always_on
---

### Architecture & Tech Stack
* **Architecture:** MVVM (Model-View-ViewModel) with strict Domain -> Data -> Presentation separation.
* **State Management:** `ValueNotifier`, `ChangeNotifier`, or `StreamBuilder`. Manual dependency injection.
* **Routing:** `go_router` for declarative navigation and deep linking.
* **Backend:** Supabase (HTTPS).
* **Serialization:** `json_serializable` (`fieldRename: FieldRename.snake`).
* **Logging:** `dart:developer` `log()` (No `print`).

When to Break Things Down

Here's my rule of thumb:

Keep it Together When:
• ✅ View is < 100 lines
• ✅ Only used in one place
• ✅ Closely coupled logic
• ✅ Learning/prototyping

Break it Down When:
• ✅ View > 100 lines
• ✅ You copy-paste code
• ✅ You need to test it separately
• ✅ Multiple people work on it
• ✅ Logic can be reused