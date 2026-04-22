# CampusConnect Production Blueprint

## 1. Product Architecture
- Client: SwiftUI + MVVM + service-oriented data layer.
- Identity: Firebase Auth only, with campus-domain, verification, and banned checks.
- Data: Firestore with top-level collections for high-cardinality entities and subcollections for upvotes/comments/replies.
- Backend automation: Cloud Functions for counters, moderation escalation, notice sync, expiry/archive cleanup, and notification side effects.
- Media: Cloudinary only (URL/publicId/metadata in Firestore).

## 2. Modules
- Authentication and Access Control
- Home Feed and Sorting
- Event Details + social interactions
- My Events (Notice Board, Create Event, Upcoming)
- Notice Board (KUET primary, Gmail optional)
- Calendar and Reminders
- Notifications center
- Profile and Settings
- Reporting and Moderation
- Admin dashboard + approval queue + history + actions
- Background jobs

## 3. User Flow
1. Splash -> Onboarding -> Login/Sign up.
2. Sign up requires @stud.kuet.ac.bd and email verification.
3. User creates event -> status PENDING_APPROVAL.
4. Admin approves/rejects.
5. Rejected event includes required reason.
6. User edits and resubmits.
7. Approved event appears in feed and can be upvoted/commented/reported.

## 4. Admin Flow
1. Open approval queue.
2. Review pending events and reports.
3. Approve/reject with required moderation notes.
4. Issue warnings/restrictions via moderation case.
5. Auto-ban only after warning threshold (>3 confirmed warnings).

## 5. Firestore Schema
Top-level collections:
- users
- user_profiles
- user_roles
- events
- archived_events
- event_upvotes
- comments
- replies
- reports
- moderation_cases
- warnings
- restrictions
- user_event_reminders
- admin_actions
- notice_board_items
- notice_sources
- gmail_connection_settings
- synced_gmail_notice_items
- organizations_or_clubs

Recommended subcollections:
- events/{eventId}/upvotes/{uid}
- events/{eventId}/comments/{commentId}
- events/{eventId}/comments/{commentId}/replies/{replyId}
- users/{uid}/user_event_reminders/{reminderId}

## 6. Key Fields
- users: role, accountStatus, warningCount, bannedAt, gmailConnected.
- events: status, rejectionReason, rejectionHistory[], upvoteCount, commentCount, replyCount, uniqueCommenterCount, trendingScore, removedByAdmin, archivedAt.
- reports: targetType, targetId, reason, description, status.
- moderation_cases: linked reports, decision trail, action state.
- admin_actions: actorUid, action, targetId, timestamp.

## 7. Indexing Strategy
- events(status ASC, date ASC)
- events(creatorUid ASC, createdAt DESC)
- events(status ASC, upvoteCount DESC)
- events(status ASC, commentCount DESC)
- reports(status ASC, createdAt DESC)
- moderation_cases(status ASC, createdAt DESC)
- notice_board_items(sourceType ASC, publishedAt DESC)

## 8. Counter Sync
- upvoteCount: increment/decrement on upvote write trigger.
- commentCount/replyCount: maintained by comment/reply triggers.
- uniqueCommenterCount: recomputed by trigger when comments change.
- discussionScore/trendingScore: periodic scheduled recompute.

## 9. Approval and Moderation History
- Event rejection history stored as array objects with reason, actor UID, timestamp.
- Global audit log in admin_actions for all admin decisions.
- Moderation case links to reports and actions.

## 10. KUET Notice Normalization and Cache
- Function scrapes KUET official pages on schedule.
- Normalized item includes title, sourceType, sourceName, originalUrl, publishedAt, syncedAt.
- Client reads Firestore cache only; never direct scrape per app load.

## 11. Gmail Metadata Integration
- Optional per-user OAuth.
- Store connection state in gmail_connection_settings/{uid}.
- Store metadata-only items in synced_gmail_notice_items/{uid}/{itemId}.
- If disconnected/revoked, app still uses KUET notice board without degradation.

## 12. Security Strategy
- Require authenticated + verified + campus-domain users.
- Block banned users from reads/writes except own appeal metadata if needed.
- Ownership checks for profile/event/comment operations.
- Admin-only writes for moderation, warnings, restrictions, and approval status transitions.

## 13. Notification Plan
- Local reminders for event times and user reminder preferences.
- FCM triggers on approval/rejection/moderation updates.
- Permission denied handled gracefully with silent fallback state.

## 14. Expiry/Archival
- Daily job marks old approved events as EXPIRED.
- Owner/admin action archives events.
- Weekly cleanup hard-deletes stale archived events after retention.

## 15. Required Error Messages
- Invalid campus email, unverified email, weak password, wrong password, account disabled, banned user, permission denied, no internet.
- Upload failed / Cloudinary upload failed.
- Duplicate upvote, expired interaction blocked, unauthorized edits/deletes.
- Rejection reason missing.
- Report submission failure.
- Notification permission denied.
- KUET source unavailable.
- Gmail denied/revoked/sync unavailable.

## 16. Performance Notes
- Paginate comments and replies.
- Keep upvotes as subcollection, never huge arrays.
- Use lightweight event cards and lazy lists.
- Precompute trending/discussion counters in backend.
- Cache notice board snapshots for minimal reads.

## 17. Sample Documents
users/{uid}
```json
{
  "email": "john.doe@stud.kuet.ac.bd",
  "role": "USER",
  "accountStatus": "ACTIVE",
  "warningCount": 0,
  "gmailConnected": false
}
```

events/{eventId}
```json
{
  "title": "KUET Tech Fest 2026",
  "status": "PENDING_APPROVAL",
  "upvoteCount": 0,
  "commentCount": 0,
  "uniqueCommenterCount": 0,
  "creatorUid": "uid_123",
  "organizationName": "KUET CSE Society",
  "registrationLink": "https://forms.gle/example",
  "imageURL": "https://res.cloudinary.com/...",
  "imagePublicId": "campus/events/techfest-2026"
}
```

reports/{reportId}
```json
{
  "targetType": "EVENT",
  "targetId": "event_1",
  "reason": "False Information",
  "description": "Date in post conflicts with official notice",
  "reporterUid": "uid_reporter",
  "status": "OPEN"
}
```
