# Mahi - Feature Delivery Package

## Scope
- Explore
- Dashboard
- Sign-in
- Sign-up
- Profile

## Branch
- feature/mahi-explore-dashboard-auth-profile

## Ownership Files (Target)
- CampusConnect/ViewModels/AuthViewModel.swift
- CampusConnect/ViewModels/ProfileViewModel.swift
- CampusConnect/Views/Auth/AuthRouterView.swift
- CampusConnect/Views/Auth/LoginView.swift
- CampusConnect/Views/Profile/ProfileView.swift
- CampusConnect/Views/Home/DashboardView.swift
- CampusConnect/Views/Events/EventListView.swift

## Commit Standard
- [Mahi][Auth]
- [Mahi][Dashboard]
- [Mahi][Profile]

## Validation Checklist
1. Login flow works with valid credentials.
2. Signup flow validates input and shows clear errors.
3. Profile data loads and updates correctly.
4. Dashboard navigation works to all major sections.
5. Explore entrypoint and EventList integration are stable.

## PR Template
Title:
[Auth+Explore+Dashboard+Profile] Final integration for Mahi module

Description:
- Completed Explore, Dashboard, Sign-in, Sign-up, and Profile scope.
- Added validation and navigation checks.
- Verified integration points with shared event list.

Checklist:
- Scope limited to assigned module.
- Build passes.
- No debug code.
- Screenshots attached.
- Test steps documented.
