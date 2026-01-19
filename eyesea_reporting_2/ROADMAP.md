# Development Roadmap

This document tracks all TODO items and technical debt across the Eyesea Reporting codebase, organized into prioritized phases.

---

## Phase 1: Critical Security & Stability (High Priority)

| Task | File | Category |
|------|------|----------|
| Server-side validation for gamification data | `lib/data/datasources/report_data_source.dart:10` | Security |
| Handle validation for user-adjusted counts vs AI detection | `lib/core/utils/pollution_calculations.dart:18` | Validation |
| Handle location permission changes while backgrounded | `lib/presentation/home/home_screen.dart:9` | Lifecycle |
| Verify MapboxMap cleanup in dispose | `lib/presentation/home/home_screen.dart:14` | Memory |
| ImagePicker instance lifecycle management | `lib/presentation/profile/profile_screen.dart:12` | Memory |

---

## Phase 2: Scalability (Medium-High Priority)

### Pagination & List Management

| Task | File |
|------|------|
| Replace offset pagination with cursor-based pagination | `lib/presentation/providers/profile_provider.dart:14` |
| Replace offset pagination with cursor-based pagination | `lib/presentation/providers/social_feed_provider.dart:19` |
| Fix unbounded list growth in `_userReports` | `lib/presentation/providers/profile_provider.dart:8` |
| Fix unbounded list growth in social feed | `lib/presentation/providers/social_feed_provider.dart:12` |
| Fix unbounded notification list growth | `lib/core/services/notification_service.dart:9` |
| Add pagination for past events | `lib/presentation/providers/events_provider.dart:5` |

### Sync & Concurrency

| Task | File |
|------|------|
| Add concurrency limit for sync operations | `lib/core/services/report_queue_service.dart:25` |
| Implement request batching for sync | `lib/core/services/report_queue_service.dart:15` |
| Fix multiple stream subscriptions from same services | `lib/presentation/providers/reports_map_provider.dart:4` |

---

## Phase 3: Performance Optimization (Medium Priority)

### Caching

| Task | File |
|------|------|
| Replace time-based cache expiry with event-driven invalidation | `lib/core/services/report_cache_service.dart:8` |
| Optimize cache invalidation (clears entire filter cache) | `lib/presentation/providers/reports_map_provider.dart:10` |
| Evaluate 10,000 report cache cap | `lib/core/services/report_cache_service.dart:13` |

### Resource Loading

| Task | File |
|------|------|
| Lazy model loading for YOLO | `lib/core/services/ai_analysis_service.dart:11` |
| Adaptive compression based on network quality | `lib/core/services/image_compression_service.dart:11` |
| Virtual scrolling for large leaderboards | `lib/presentation/providers/leaderboard_provider.dart:11` |

---

## Phase 4: Code Maintainability (Medium Priority)

### Large Files to Refactor

| File | Lines | Action |
|------|-------|--------|
| `lib/presentation/profile/profile_screen.dart` | 890 | Split into components |
| `lib/presentation/onboarding/onboarding_screen.dart` | 693 | Split into components |
| `lib/presentation/report/report_details_screen.dart` | 641 | Split into components |
| `lib/presentation/providers/reports_map_provider.dart` | 594 | Extract responsibilities |
| `lib/presentation/events/create_event_screen.dart` | 577 | Split into components |

### Configuration Extraction

| Task | File |
|------|------|
| Move weight constants to config/database | `lib/core/utils/pollution_calculations.dart:14` |
| Move YOLO class mappings to config file | `lib/core/services/ai_analysis_service.dart:16` |
| Extract role change logic to ProfileEditProvider | `lib/presentation/profile/profile_screen.dart:8` |

---

## Phase 5: Features & UX (Lower Priority)

| Task | File | Category |
|------|------|----------|
| SSO Authentication implementation | `lib/presentation/auth/login_screen.dart:13` | Feature |
| Add notification tap navigation | `lib/core/services/notification_service.dart:13` | Feature |
| Indicate stale data when using cached profile | `lib/presentation/providers/auth_provider.dart:12` | UX |
| Update scene recognition for new YOLO classes | `YOLO_MAPPING_IMPROVEMENTS.md:209` | Feature |

---

## Phase 6: Architecture Improvements (Long-term)

| Task | File |
|------|------|
| Consider GetIt service locator for DI | `lib/main.dart:1` |
| Avoid `ChangeNotifierProvider.value()` anti-pattern | `lib/main.dart:10` |

---

## Phase 7: Documentation (Ongoing)

| Task | File |
|------|------|
| Document people detection blocking behavior | `lib/core/services/ai_analysis_service.dart:6` |
| Add player-facing explanation of XP system | `lib/core/utils/pollution_calculations.dart:3` |
| Document compression strategy and tradeoffs | `lib/core/services/image_compression_service.dart:6` |

---

## Summary

| Phase | Items | Focus |
|-------|-------|-------|
| 1 | 5 | Security & Stability |
| 2 | 9 | Scalability |
| 3 | 6 | Performance |
| 4 | 8 | Maintainability |
| 5 | 4 | Features & UX |
| 6 | 2 | Architecture |
| 7 | 3 | Documentation |
| **Total** | **37** | |

---

## How to Use This Document

1. **Pick a phase** based on current priorities
2. **Check off items** as they are completed by removing the TODO comment from the source file
3. **Update this document** when new TODOs are added or priorities change
4. **Review quarterly** to reassess priorities

---

*Last updated: January 2026*
