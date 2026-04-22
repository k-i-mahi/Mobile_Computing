# CampusConnect Feature Verification Checklist

Last updated: 2026-04-11
Scope: iOS app + Firestore-backed core flows based on your original startup-grade prompt.

## 1) Current Implementation Status (Code + Runtime Audit)

### Operational or significantly implemented
- Authentication with campus-domain validation, email verification flow, login/logout/reset.
- Role-aware routing and banned-account UX state.
- Dashboard feed with search/filter/sort and social event cards.
- Event details with upvote, comments/replies, share link, and reminders.
- My Events with Notice Board and Upcoming sections.
- Notice Board Firestore-backed UI.
- Calendar screen with event markers and selected-day event list.
- Notifications screen with reminder toggles.
- Profile and Settings (including theme switching).
- Admin screens: approvals, reports queue, comment moderation, upvote viewer, restrictions.
- Firestore moderation entities and admin actions are present in code and rules.

### Fixed in this correction pass
- Dedicated bottom tab now shows Notifications (not Notices).
- Duplicate Alerts tab removed.
- Firestore rules updated to prevent cascading permission denials caused by brittle email-claim checks.
- Firestore rules corrected for reminders subcollection path.
- RSVP removed from the app surface and Firestore rules.
- Event report action now actually writes report documents (instead of no-op UI action).
- Explore loading trap reduced by removing a stuck-loading trigger path.

### Still partial or external dependency
- Gmail integration is UI-level status management, not full OAuth + metadata sync pipeline yet.
- KUET notice sync quality depends on backend sync jobs/data freshness.
- App Check behavior on real device depends on Firebase console/API configuration.

## 2) Preflight (must pass before feature testing)

1. Build app successfully.
- Command:
  - xcodebuild -project CampusConnect.xcodeproj -scheme CampusConnect -destination 'platform=iOS Simulator,name=iPhone 17' clean build
- Expected: BUILD SUCCEEDED.

2. Confirm Firestore rules are latest.
- Command:
  - cd firebase
  - firebase deploy --only firestore:rules --project campusconnect-da9af
- Expected: rules compiled and deployed.

3. Firebase project sanity.
- Verify GoogleService-Info.plist bundle ID matches running app target.
- Verify Firebase Auth Email/Password is enabled.

4. Test account sanity.
- Use one USER account and one ADMIN account.
- USER email must be a campus domain email.

## 3) Feature-by-Feature Test Checklist

Use PASS/FAIL for each step.

### A. Authentication and Access Control
1. Sign up with non-campus email.
- Expected: blocked with clear error.

2. Sign up with campus email.
- Expected: account created, verification email requested.

3. Login before verification (real-device/non-debug behavior).
- Expected: blocked, verification reminder shown.

4. Login with wrong password.
- Expected: readable auth error.

5. Forgot password flow.
- Expected: reset email request succeeds or meaningful failure shown.

6. Login with banned user.
- Expected: banned UX path, no normal app access.

7. Logout and session restore.
- Expected: logout returns to auth; valid session re-enters dashboard.

### B. Dashboard / Home Feed
1. Open dashboard after login.
- Expected: feed appears, no infinite spinner.

2. Search by title/venue/organizer keyword.
- Expected: filtered results update live.

3. Category filter changes.
- Expected: list narrows correctly.

4. Sort options:
- newest
- trending
- most upvoted
- most discussed
- nearest upcoming
- Expected: list reorders appropriately.

5. Event card data quality.
- Expected each card shows title/date/venue/category/engagement values.

### C. Event Details + Social Interactions
1. Open event detail from feed.
- Expected: full detail screen renders.

2. Toggle upvote.
- Expected: succeeds once per user; toggle removes upvote.

3. Add comment.
- Expected: appears in thread.

4. Add reply.
- Expected: nested reply appears under target comment.

5. Report event.
- Expected: report saved to reports collection with OPEN status.

6. Report comment.
- Expected: report saved to reports collection with OPEN status.

7. Share event.
- Expected: app deep link generated; unauthorized users are denied gracefully.

8. Notification toggle on event.
- Expected: reminder document created/updated and local reminder scheduled/cancelled.

### D. My Events
1. Open My Events tab.
- Expected: section selector available (Notice Board, Create Event, Upcoming Events).

2. Upcoming section for USER.
- Expected: only that user events; statuses visible.

3. Swipe actions on own event.
- Expected: edit and delete actions function according to policy.

### E. Notice Board
1. Open Notice Board from My Events section.
- Expected: list or empty-state loads without permission errors.

2. Open source link on a notice item.
- Expected: external official link opens.

3. Backend outage simulation.
- Expected: graceful fallback/empty state with friendly message.

### F. Create / Edit Event
1. Open Create Event.
- Expected: form fields, validation, and warning copy are visible.

2. Submit invalid form.
- Expected: inline validation errors.

3. Submit valid USER event.
- Expected: status enters pending approval (not instantly public).

4. Edit rejected event and resubmit.
- Expected: status transitions back to review flow.

### G. Upcoming Events
1. Check only upcoming non-expired own events appear.
- Expected: matches status and date constraints.

2. Confirm status labels.
- Expected: pending/approved/rejected/expired/archived display correctly.

### H. Calendar
1. Open Calendar tab.
- Expected: month grid renders with markers.

2. Tap different dates.
- Expected: per-day event list updates.

3. Validate reminder defaults.
- Expected: default reminder logic available and adjustable.

### I. Notifications
1. Open Notifications tab.
- Expected: reminders list or empty state shown.

2. Toggle reminder in list.
- Expected: persists and updates next reminder status.

3. Deny notification permission.
- Expected: clear denied-permission message and graceful behavior.

### J. Profile and Settings
1. Open Profile.
- Expected: profile data loads.

2. Edit and save profile fields.
- Expected: Firestore doc updates successfully.

3. Theme change (light/dark/system).
- Expected: visual mode applies without broken contrast.

4. Open Gmail integration screen.
- Expected: screen loads and state controls function at UI level.

### K. Reporting and Moderation
1. Submit event and comment reports as USER.
- Expected: reports appear in reports queue for ADMIN.

2. ADMIN opens Reports Queue.
- Expected: OPEN reports listed in descending time.

3. ADMIN moderation actions.
- Expected: warning/restriction/ban actions update user/account docs and logs.

### L. Admin Dashboard
1. Login as ADMIN and open admin panel.
- Expected: panel visible only to admin role.

2. Approval queue flow.
- Expected: approve/reject updates event status and logs actions.

3. Rejection reason enforcement.
- Expected: reject requires non-empty reason.

4. Upvote viewer.
- Expected: per-event upvoter list visible to admin.

### M. Optional Gmail Integration
1. Access integration screen from settings.
- Expected: optional path; app fully usable without connection.

2. If Gmail not connected.
- Expected: Notice Board still works from KUET source pipeline.

### N. Background Jobs / Sync / Cleanup
1. Verify scheduled backend jobs executed recently.
- Expected: notice_board_items refresh and archival jobs show activity.

2. Verify expired events lifecycle.
- Expected: expired -> archived behavior follows job cadence/policy.

## 4) Firestore Query Spot Checks (Operational Proof)

Check these paths during testing:
- users/{uid}
- events (approved feed + own creatorUid query)
- events/{eventId}/upvotes/{uid}
- events/{eventId}/comments/{commentId}
- events/{eventId}/comments/{commentId}/replies/{replyId}
- reports
- notice_board_items
- user_event_reminders/{uid}/items/{eventId}

Expected: no persistent Missing or insufficient permissions for valid signed-in campus user.

## 5) Known High-Risk Areas to Re-check First

1. Auth token/profile bootstrap after first signup.
2. Dashboard loading state fallback behavior.
3. Event approval visibility rule boundaries.
4. Admin-only routes and actions.
5. Notice board data freshness from backend sync.
6. App Check behavior on real device (if enforcement is enabled in Firebase console).

## 6) Sign-off Template (Use after full run)

- Auth and access: PASS/FAIL
- Dashboard feed/search/filter/sort: PASS/FAIL
- Event social (upvote/comment/reply/report/share): PASS/FAIL
- My Events + Upcoming + Notice Board: PASS/FAIL
- Create/Edit + approval lifecycle: PASS/FAIL
- Calendar + reminders + notifications: PASS/FAIL
- Profile/settings/theme: PASS/FAIL
- Admin moderation suite: PASS/FAIL
- Gmail optional path: PASS/FAIL/PARTIAL
- Background sync/cleanup jobs: PASS/FAIL/PARTIAL

If any section fails, capture:
- user role used
- exact screen path
- first failing action
- first 20 log lines after failure
- impacted Firestore path/query
