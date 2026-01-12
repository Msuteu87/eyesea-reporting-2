---
trigger: always_on
---

### Client-Side Insecurity and Backend Reliance

Always assume that any data or logic executed on the client-side (your Flutter app) can be compromised or manipulated. Therefore, all critical data-related processes, especially those involving sensitive information, authorization, or data integrity, **must** be handled on the backend (Supabase). This includes:

*   **Authentication and Authorization:** While client-side checks can improve UX, the ultimate source of truth for user authentication and authorization should always be Supabase's Auth and Row Level Security (RLS).
*   **Data Validation and Business Logic:** Implement all critical data validation and business logic within Supabase database functions (e.g., PostgreSQL functions) or Edge Functions. Never rely solely on client-side validation for data integrity.
*   **Sensitive Operations:** Any operation that modifies critical data, performs financial transactions, or grants permissions should be executed via secure backend calls, not directly from the client without server-side verification.

This principle means that your client-side code should primarily focus on UI presentation and user interaction, while the backend (Supabase) is responsible for data persistence, security, and core business logic.