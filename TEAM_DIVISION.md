# CampusConnect — Team Work Division

> **Project:** CampusConnect (SwiftUI iOS App with Firebase)  
> **Team Members:** **M**, **S**, **A**  
> **Architecture:** MVVM · SwiftUI · Firebase (Auth + Firestore) · NewsAPI  

---

## Overview

The project is divided into three logical modules so each team member owns **end-to-end responsibility** — from data model through view-model to UI — for their area. Shared infrastructure (app entry point, design system, utilities) is co-owned.

| Area | Owner | Summary |
|------|-------|---------|
| **Authentication & User Profile** | **M** | Sign-up / sign-in flow, user profile management, settings & theme |
| **Events System** | **S** | Event CRUD (Firestore), event listing (JSON), RSVP, calendar, filters |
| **News & Shared UI Components** | **A** | News feed (API), reusable components, design system, utilities |

---

## Detailed Breakdown

### 👤 M — Authentication & User Profile

**Scope:** Everything related to user identity, profile data, and app preferences.

| File | Path | Description |
|------|------|-------------|
| `AuthViewModel.swift` | `ViewModels/` | Firebase Auth sign-up, sign-in, sign-out logic |
| `ProfileViewModel.swift` | `ViewModels/` | Load, save, and update Firestore user profile |
| `ThemeManager.swift` | `ViewModels/` | App theme persistence (system / light / dark) |
| `UserProfile.swift` | `Models/` | User profile data model (Codable, Equatable) |
| `ValidationService.swift` | `Services/` | Input validation for auth & profile forms |
| `AuthRouterView.swift` | `Views/Auth/` | Splash → login / dashboard routing |
| `LoginView.swift` | `Views/Auth/` | Login & registration UI |
| `ProfileView.swift` | `Views/Profile/` | Profile display & inline editing |
| `SettingsView.swift` | `Views/Settings/` | Theme selector, about section |
| `CampusConnectApp.swift` | `App/` | App entry point, Firebase init *(co-owned)* |
| `firestore.rules` | Root | Security rules for Firestore *(co-owned)* |

**Key Responsibilities:**
- Firebase Authentication (email / password)
- Firestore `/users/{uid}` document read/write
- Form validation (sign-up, sign-in, profile)
- Theme switching and persistence via `@AppStorage`
- Splash screen animation and auth-state routing

---

### 📅 S — Events System

**Scope:** All event functionality — Firestore-backed CRUD, local JSON listing, RSVP, filtering, and calendar.

| File | Path | Description |
|------|------|-------------|
| `FirestoreEventManager.swift` | `ViewModels/` | Real-time Firestore listener, create/update/delete events |
| `EventJSONViewModel.swift` | `ViewModels/` | Load & filter local JSON events |
| `SeatScoreViewModel.swift` | `ViewModels/` | Seat availability scoring logic |
| `FirestoreEvent.swift` | `Models/` | Firestore event data model |
| `Event.swift` | `Models/` | Local JSON event data model |
| `Organizer.swift` | `Models/` | Organizer data model |
| `RSVPManager.swift` | `Services/` | RSVP check / toggle / count via Firestore subcollections |
| `EventListView.swift` | `Views/Events/` | Explore tab — searchable, filterable event list |
| `EventDetailView.swift` | `Views/Events/` | Full event detail with RSVP + organizer profile |
| `EventFilterView.swift` | `Views/Events/` | Category filter sheet |
| `CreateEventView.swift` | `Views/Events/` | New event form (Firestore) |
| `EditEventView.swift` | `Views/Events/` | Edit existing event form |
| `MyEventsView.swift` | `Views/Events/` | User's own Firestore events tab |
| `CalendarView.swift` | `Views/Calendar/` | Monthly calendar with event markers |
| `OrganizerProfileView.swift` | `Views/Organizer/` | Organizer detail card |
| `DashboardView.swift` | `Views/Home/` | Main tab bar container *(co-owned)* |
| `events.json` | `Resources/` | Sample event dataset (10 events) |

**Key Responsibilities:**
- Firestore `/events` collection CRUD with real-time listeners
- RSVP subcollection management (`/events/{id}/rsvps`)
- Local JSON event loading and category-based filtering
- Calendar date navigation and event-day highlighting
- Seat counter animation and scoring
- Search functionality (title, venue, tags)

---

### 📰 A — News & Shared UI Components

**Scope:** News feed (external API), all reusable UI components, design tokens, and project utilities.

| File | Path | Description |
|------|------|-------------|
| `NewsViewModel.swift` | `ViewModels/` | Fetch, cache, and expose news articles |
| `NewsArticle.swift` | `Models/` | News article data model (Codable, Hashable) |
| `NewsAPIService.swift` | `Services/` | Actor-based REST client with 5-min cache |
| `NewsListView.swift` | `Views/News/` | News feed UI with pull-to-refresh + detail sheet |
| `EventCardView.swift` | `Views/Components/` | Reusable event card (used in Explore & Calendar) |
| `CategoryBadgeView.swift` | `Views/Components/` | Category badge (pill, chip, label, compact styles) |
| `SeatCounterView.swift` | `Views/Components/` | Animated seat availability indicator |
| `SharedComponents.swift` | `Views/Components/` | LoadingView, ErrorView, EmptyStateView, SearchBar, etc. |
| `Constants.swift` | `Utilities/` | Design tokens, colors, category colors, gradients |
| `DateFormatterHelper.swift` | `Utilities/` | Date parsing & formatting utilities |
| `Bundle+Decode.swift` | `Utilities/` | Generic JSON decoding from bundle |
| `ViewExtensions.swift` | `Utilities/` | CardModifier, ShimmerModifier, HapticManager, staggeredAppear |
| `README.md` | Root | Project documentation *(co-owned)* |
| `DEPENDENCIES.md` | Root | Dependency list *(co-owned)* |

**Key Responsibilities:**
- NewsAPI integration (REST, async/await, actor isolation)
- Response caching with 5-minute TTL
- All reusable SwiftUI components used across the app
- Design system: color tokens, gradients, category theming
- Date formatting and parsing utilities
- Custom view modifiers (card, shimmer, staggered animation)
- Haptic feedback manager

---

## Co-Owned Files

These files are shared responsibility — any team member may need to touch them:

| File | Reason |
|------|--------|
| `CampusConnectApp.swift` | App entry, Firebase init, environment injection |
| `DashboardView.swift` | Tab bar — references all feature views |
| `firestore.rules` | Security rules affect all Firestore operations |
| `README.md` | Project-level documentation |
| `DEPENDENCIES.md` | Shared dependency tracking |
| `.gitignore` | Git configuration |

---

## Git Workflow Suggestion

```
main
 ├── feature/m-auth-profile      ← M's branch
 ├── feature/s-events-system      ← S's branch
 └── feature/a-news-components    ← A's branch
```

1. Each member creates their feature branch from `main`
2. Work on assigned files only; coordinate on co-owned files
3. Open Pull Requests for review before merging to `main`
4. Use clear commit messages: `[M] Add login validation`, `[S] Fix RSVP toggle`, `[A] Update card modifier`

---

## File Count Summary

| Member | Models | ViewModels | Services | Views | Utilities | Other | **Total** |
|--------|--------|------------|----------|-------|-----------|-------|-----------|
| **M** | 1 | 3 | 1 | 4 | — | 2 | **11** |
| **S** | 3 | 3 | 1 | 8 | — | 1 | **16** |
| **A** | 1 | 1 | 1 | 5 | 4 | 2 | **14** |

> **Note:** S has more files because the events system is the core feature with CRUD, filters, calendar, and RSVP. The workload is balanced by A handling all shared components and utilities used across the entire app, and M handling the critical auth flow and security rules.

---

*Generated for CampusConnect team — SwiftUI · Firebase · MVVM*
