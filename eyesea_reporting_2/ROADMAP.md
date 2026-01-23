# Development Roadmap

This document tracks technical improvements and future enhancements for the Eyesea Reporting codebase.

---

## Recently Completed (January 2026)

The following improvements have been implemented:

### Scalability & Memory Management
- ✅ Memory cap for social feed (200 items max) - `social_feed_provider.dart`
- ✅ Memory cap for user reports (100 items max) - `profile_provider.dart`
- ✅ Memory cap for past events (50 items max) - `events_provider.dart`
- ✅ Reduced cache expiry from 24h to 1h - `report_cache_service.dart`

### Lifecycle & Stability
- ✅ Location permission check on app resume - `home_screen.dart`
- ✅ MapboxMap cleanup in dispose - `home_screen.dart`
- ✅ Stale data indicator support (`lastSyncTime`, `timeSinceLastSync`) - `auth_provider.dart`

### Configuration & Maintainability
- ✅ Centralized pollution config (`PollutionConfig`) - `lib/core/config/pollution_config.dart`
- ✅ Centralized YOLO config (`YoloConfig`) - `lib/core/config/yolo_config.dart`
- ✅ Documented sync strategy - `report_queue_service.dart`
- ✅ Documented compression strategy - `image_compression_service.dart`
- ✅ Documented AI privacy features - `ai_analysis_service.dart`

### Code Cleanup
- ✅ Removed all `// TODO:` comments from codebase
- ✅ Converted TODO items to proper documentation

### Push Notifications
- ✅ Firebase Cloud Messaging integration (iOS & Android) - `push_notification_service.dart`
- ✅ Device token management with Supabase - `device_tokens` table with RLS
- ✅ Edge Function for push delivery - `supabase/functions/send-push-notification`
- ✅ iOS background modes and APNs configuration - `Info.plist`, `AppDelegate.swift`
- ✅ Codemagic CI/CD Firebase config injection - `codemagic.yaml`

---

## Phase 1: Performance Optimization (Next Priority)

### Pagination Improvements

| Task | File | Notes |
|------|------|-------|
| Cursor-based pagination for feeds | `social_feed_provider.dart` | Requires repository changes |
| Cursor-based pagination for reports | `profile_provider.dart` | O(1) vs O(n) for large offsets |
| Server-side limit for leaderboards | `leaderboard_provider.dart` | Limit to top 100 on server |

### Caching Enhancements

| Task | File | Notes |
|------|------|-------|
| Event-driven cache invalidation | `report_cache_service.dart` | Subscribe to Supabase realtime |
| Granular filter cache invalidation | `reports_map_provider.dart` | Only clear affected filters |
| Geographic cache partitioning | `report_cache_service.dart` | For global views at scale |

---

## Phase 2: Security Hardening

| Task | File | Notes |
|------|------|-------|
| Server-side XP calculation | Edge Function | Re-calculate from `ai_analysis` table |
| Server-side fraud scoring | Edge Function | Validate client-submitted counts |

---

## Phase 3: Code Architecture (Long-term)

### Large Files to Consider Splitting

Files over 500 lines that could benefit from componentization:

| File | Lines | Suggested Split |
|------|-------|-----------------|
| `profile_screen.dart` | ~890 | Settings, Reports, Legal tabs |
| `onboarding_screen.dart` | ~693 | Step components |
| `report_details_screen.dart` | ~641 | Form sections |
| `reports_map_provider.dart` | ~594 | Data, Filter, Marker providers |
| `create_event_screen.dart` | ~577 | Form, Location, DateTime pickers |

### Dependency Injection

| Task | Notes |
|------|-------|
| Evaluate GetIt for DI | Lazy singletons, easier mocking |
| Stream subscription management | Shared subscription manager for multiple providers |

---

## Phase 4: Features (Backlog)

| Feature | Notes |
|---------|-------|
| SSO Authentication | Google, Apple, LinkedIn via Supabase OAuth |
| Event deep linking | `/events/:eventId` route |
| Adaptive image compression | Adjust quality based on network type |
| Lazy YOLO model loading | Unload when backgrounded to free memory |

---

## Summary

| Status | Count |
|--------|-------|
| Completed | 18 |
| Next Priority | 6 |
| Backlog | 15 |

---

## How to Use This Document

1. **Check completed section** for recent improvements
2. **Pick from next priority** based on current needs
3. **Add new items** to appropriate phase
4. **Review quarterly** to reassess priorities

---

*Last updated: January 2026*
