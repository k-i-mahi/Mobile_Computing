# Abhijeet - Feature Delivery Package

## Scope
- Admin Panel
- Notifications

## Branch
- feature/avijeet-admin-notifications

## Ownership Files (Target)
- CampusConnect/Views/Admin/AdminPanelView.swift
- CampusConnect/ViewModels/AdminViewModel.swift
- CampusConnect/Services/NotificationService.swift
- CampusConnect/ViewModels/NotificationViewModel.swift

## Commit Standard
- [Abhijeet][Admin]
- [Abhijeet][Notifications]

## Validation Checklist
1. Admin panel access rules are enforced correctly.
2. Admin actions work and show feedback states.
3. Notification trigger logic works for required events.
4. In-app/local notification delivery is reliable.
5. Error states are handled with clear user messages.

## PR Template
Title:
[Admin+Notifications] Final integration for Abhijeet module

Description:
- Completed admin panel workflows and notification integration.
- Added verification checks for authorization and delivery.
- Documented critical validation cases for review.

Checklist:
- Scope limited to assigned module.
- Build passes.
- No debug code.
- Screenshots attached.
- Test steps documented.
