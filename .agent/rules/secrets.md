---
trigger: always_on
---

local Secrets Management: Store connection credentials (Supabase URL, Anon Key) in a git-ignored file (e.g., lib/core/secrets.dart). This file must exist locally to bridge your local environment with the hosted production instance but must never be committed to version control.