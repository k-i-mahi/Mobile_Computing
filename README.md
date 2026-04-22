# CampusConnect

A SwiftUI iOS app that connects students to campus events — browse, RSVP, create, and manage events in one place, backed by Firebase.

---

## Features

### Authentication
- Campus-only sign-in and sign-up (restricted to institutional email domain)
- Password reset via email link
- Animated splash screen and first-launch onboarding
- Automatic routing between Login and Dashboard based on auth state
- Banned account detection with clear user feedback

### Explore & Events
- Real-time event feed sourced from Firestore with live updates
- Full-text search across title, venue, organizer, and description
- Category filter sheet and multi-option sort (date, name, seats)
- Detailed event view with RSVP button and live seat counter
- Create and edit events through a guided form (admin events auto-approved, others go to review queue)
- Swipe-to-edit and swipe-to-delete in My Events tab

### Calendar
- Monthly calendar grid with dot markers on days that have events
- Tap any date to list events for that day
- Navigate between months with animated transitions

### Notifications
- In-app notification feed with unread badge count
- Real-time Firestore listener — notifications appear without refresh
- Mark individual notifications read on tap, or mark all read at once
- Swipe-to-delete individual notifications
- Local UNUserNotification scheduling for event reminders (configurable minutes before event)

### Admin Panel (admin role only)
- User management: issue warnings, restrict comments, restrict event creation, promote to admin, ban, or restore
- Event moderation: approve or reject pending events with a required rejection reason
- Broadcast notifications: send a custom title + body to all users at once
- Accessible directly from the Profile tab when the signed-in user holds the admin role

### Profile
- Display name, department, bio, and phone — all inline editable
- Profile photo picker with upload to Firebase Storage
- Theme selector (system / light / dark)
- Sign-out with confirmation alert

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI (iOS 17+) |
| Architecture | MVVM |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Storage | Firebase Storage (profile photos) |
| Local Notifications | UserNotifications framework |
| Dependency Management | Swift Package Manager |

---

## Project Structure

```
CampusConnect/
├── Services/
│   ├── NotificationService.swift   — local scheduling + Firestore push
│   └── RSVPManager.swift           — transactional RSVP toggle and count
│
├── ViewModels/
│   ├── AuthViewModel.swift         — Firebase Auth state, role, restriction status
│   ├── ProfileViewModel.swift      — Firestore profile load/save
│   ├── FirestoreEventManager.swift — real-time event CRUD with snapshot listeners
│   ├── EventJSONViewModel.swift    — in-memory store with search, filter, sort
│   ├── SeatScoreViewModel.swift    — live seat availability scoring
│   ├── AdminViewModel.swift        — moderation actions and broadcast
│   └── NotificationsViewModel.swift— notification feed with read/unread state
│
└── Views/
    ├── Auth/
    │   ├── AuthRouterView.swift    — splash → onboarding → login/dashboard router
    │   └── LoginView.swift         — sign-in and sign-up form
    ├── Home/
    │   └── DashboardView.swift     — main TabView container
    ├── Events/
    │   ├── EventListView.swift     — searchable, filterable event feed
    │   ├── EventDetailView.swift   — detail with RSVP and seat counter
    │   ├── EventFilterView.swift   — category filter sheet
    │   ├── CreateEventView.swift   — new event form
    │   ├── EditEventView.swift     — edit existing event
    │   └── MyEventsView.swift      — creator's event list
    ├── Calendar/
    │   └── CalendarView.swift      — monthly calendar with event markers
    ├── Notifications/
    │   └── NotificationsView.swift — notification feed UI
    ├── Admin/
    │   └── AdminPanelView.swift    — user and event moderation panel
    └── Profile/
        └── ProfileView.swift       — profile display and editing
```

---

## Team

| Module | Owner | Branch |
|--------|-------|--------|
| Auth · Explore · Dashboard · Profile | Mahi | `feature/mahi-explore-dashboard-auth-profile` |
| Events · Calendar · RSVP | Sumaiya | `feature/sumaiya-events-calendar` |
| Admin Panel · Notifications | Avijeet | `feature/avijeet-admin-notifications` |

---

## Getting Started

### Requirements
- Xcode 15 or later
- iOS 17 deployment target
- A Firebase project with Authentication and Firestore enabled

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/k-i-mahi/Mobile_Computing.git
   cd Mobile_Computing
   ```

2. Add your `GoogleService-Info.plist` from the Firebase console into the `CampusConnect/` directory.

3. Open `CampusConnect.xcodeproj` in Xcode. Swift Package Manager will resolve Firebase dependencies automatically.

4. Set the campus email domain in `Constants.swift` to match your institution.

5. Build and run on a simulator or device (iOS 17+).

### Firestore Collections

| Collection | Purpose |
|------------|---------|
| `users` | User profiles, roles, restriction status |
| `users/{uid}/notifications` | Per-user in-app notifications |
| `users/{uid}/rsvps` | Per-user RSVP records |
| `events` | All campus events |
| `account_registry` | Email-to-UID lookup for login validation |

---

## Branching Strategy

```
main
 ├── feature/mahi-explore-dashboard-auth-profile
 ├── feature/sumaiya-events-calendar
 └── feature/avijeet-admin-notifications
```

Commit message format: `[Owner][Module] Short action-oriented message`

---

## Deliverables

Each team member's scope, owned files, and PR checklist are documented in:

- [`DELIVERABLES/MAHI_DELIVERABLE.md`](DELIVERABLES/MAHI_DELIVERABLE.md)
- [`DELIVERABLES/SUMAIYA_DELIVERABLE.md`](DELIVERABLES/SUMAIYA_DELIVERABLE.md)
- [`DELIVERABLES/ABHIJEET_DELIVERABLE.md`](DELIVERABLES/ABHIJEET_DELIVERABLE.md)
- [`TEAM_DIVISION.md`](TEAM_DIVISION.md)
