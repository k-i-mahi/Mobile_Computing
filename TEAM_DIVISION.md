# CampusConnect - Final Team Division (Submission Version)

> Project: CampusConnect (SwiftUI iOS App with Firebase)
> Team Members: Sumaiya, Mahi, Avijeet
> Architecture: MVVM · SwiftUI · Firebase Auth · Firestore
> Date: April 2026

---

## Final Ownership Overview

This is the final professional ownership split for development, upload, and PR review.

| Module | Owner | Scope |
|------|-------|-------|
| Events + Calendar | Sumaiya | Event listing, event details, filtering, RSVP, calendar rendering and date flow |
| Explore + Dashboard + Auth + Profile | Mahi | Explore experience, dashboard navigation, sign-in, sign-up, profile management |
| Admin Panel + Notifications | Avijeet | Admin controls, approval/management actions, push/in-app notification flow |

---

## Detailed Division

### Sumaiya - Events and Calendar Section

Primary responsibility:
- Event and calendar user journey from list to detail to RSVP
- Event filtering, category logic, and calendar date interactions

Typical file ownership:
- `CampusConnect/ViewModels/FirestoreEventManager.swift`
- `CampusConnect/ViewModels/EventJSONViewModel.swift`
- `CampusConnect/ViewModels/SeatScoreViewModel.swift`
- `CampusConnect/Services/RSVPManager.swift`
- `CampusConnect/Views/Events/EventListView.swift`
- `CampusConnect/Views/Events/EventDetailView.swift`
- `CampusConnect/Views/Events/EventFilterView.swift`
- `CampusConnect/Views/Events/CreateEventView.swift`
- `CampusConnect/Views/Events/EditEventView.swift`
- `CampusConnect/Views/Events/MyEventsView.swift`
- `CampusConnect/Views/Calendar/CalendarView.swift`

### Mahi - Explore, Dashboard, Sign-in, Sign-up, Profile

Primary responsibility:
- Authentication and profile lifecycle
- Explore and dashboard navigation experience

Typical file ownership:
- `CampusConnect/ViewModels/AuthViewModel.swift`
- `CampusConnect/ViewModels/ProfileViewModel.swift`
- `CampusConnect/Views/Auth/AuthRouterView.swift`
- `CampusConnect/Views/Auth/LoginView.swift`
- `CampusConnect/Views/Profile/ProfileView.swift`
- `CampusConnect/Views/Home/DashboardView.swift`
- `CampusConnect/Views/Events/EventListView.swift` (Explore-side coordination)

### Avijeet - Admin Panel and Notification Section

Primary responsibility:
- Admin-facing controls and moderation flows
- Notification setup, triggering, and user-facing delivery handling

Implementation notes:
- If admin and notification files are not yet created, Avijeet will create and own them in a dedicated feature branch.
- Naming convention recommendation:
	- `CampusConnect/Views/Admin/AdminPanelView.swift`
	- `CampusConnect/ViewModels/AdminViewModel.swift`
	- `CampusConnect/Services/NotificationService.swift`
	- `CampusConnect/ViewModels/NotificationViewModel.swift`

---

## Branching Strategy (Professional)

Use one clean branch per owner area:

```text
main
 |- feature/sumaiya-events-calendar
 |- feature/mahi-explore-dashboard-auth-profile
 |- feature/avijeet-admin-notifications
```

Branch rules:
1. Always branch from latest `main`.
2. Keep PR scope limited to the assigned module.
3. Use small, meaningful commits.
4. Rebase or merge `main` before opening PR if needed.

---

## Commit Message Standard

Use this professional format:

```text
[Owner][Module] Short action-oriented message
```

Examples:
- `[Sumaiya][Events] Add RSVP toggle state fix`
- `[Mahi][Auth] Improve sign-up validation and error handling`
- `[Avijeet][Notifications] Add local notification scheduling service`

---

## Pull Request Standard

PR title format:

```text
[Module] Summary of completed feature
```

PR checklist (required):
1. Scope matches branch ownership.
2. App builds successfully.
3. No debug code or commented dead code.
4. Screenshots added for UI changes.
5. Test/validation steps written clearly.
6. Linked to team task or issue.

Reviewer flow:
1. Owner opens PR to `main`.
2. At least one teammate reviews.
3. Address review comments.
4. Squash-merge with a clean final message.

---

## Upload Plan From One PC

Since all work is being uploaded from one PC, follow this sequence:

1. Pull latest `main`.
2. Create first branch and complete module work.
3. Commit with proper message format.
4. Push branch and open PR.
5. Repeat for next two branches.
6. Merge PRs one-by-one after review to avoid conflicts.

Recommended command flow per feature:

```bash
git checkout main
git pull origin main
git checkout -b feature/<owner-module-name>
git add .
git commit -m "[Owner][Module] <message>"
git push -u origin feature/<owner-module-name>
```

---

## Final Note

This division is now aligned exactly to:
- Sumaiya: Events + Calendar
- Mahi: Explore + Dashboard + Sign-in + Sign-up + Profile
- Avijeet: Admin Panel + Notifications

Use this document as the final submission reference for repository uploads, commits, and PR professionalism.
