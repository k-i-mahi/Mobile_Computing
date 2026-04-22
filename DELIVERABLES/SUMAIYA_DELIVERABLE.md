# Sumaiya - Feature Delivery Package

## Scope
- Events
- Calendar

## Branch
- feature/sumaiya-events-calendar

## Ownership Files (Target)
- CampusConnect/ViewModels/FirestoreEventManager.swift
- CampusConnect/ViewModels/EventJSONViewModel.swift
- CampusConnect/ViewModels/SeatScoreViewModel.swift
- CampusConnect/Services/RSVPManager.swift
- CampusConnect/Views/Events/EventListView.swift
- CampusConnect/Views/Events/EventDetailView.swift
- CampusConnect/Views/Events/EventFilterView.swift
- CampusConnect/Views/Events/CreateEventView.swift
- CampusConnect/Views/Events/EditEventView.swift
- CampusConnect/Views/Events/MyEventsView.swift
- CampusConnect/Views/Calendar/CalendarView.swift

## Commit Standard
- [Sumaiya][Events]
- [Sumaiya][Calendar]
- [Sumaiya][RSVP]

## Validation Checklist
1. Event list renders expected data.
2. Event detail page shows complete event information.
3. Filter behavior updates results correctly.
4. RSVP updates reflect instantly and persist.
5. Calendar shows correct date grouping and event mapping.

## PR Template
Title:
[Events+Calendar] Final integration for Sumaiya module

Description:
- Completed event and calendar journey from list to RSVP.
- Added filters and date-flow checks.
- Verified event CRUD views and user event listings.

Checklist:
- Scope limited to assigned module.
- Build passes.
- No debug code.
- Screenshots attached.
- Test steps documented.
