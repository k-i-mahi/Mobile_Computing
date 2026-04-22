# CampusConnect Step-by-Step Setup Guide

This guide is the exact sequence you should follow to run your upgraded CampusConnect app end-to-end.

## Phase 1: Open and Verify Project
1. Open Xcode and load the workspace from CampusConnect.xcodeproj.
2. Confirm GoogleService-Info.plist exists at project root and is included in the app target.
3. Build once to ensure local signing and target settings are valid.

## Phase 2: Firebase Project Setup
1. In Firebase Console, create/select your Firebase project.
2. Add your iOS app bundle ID and download GoogleService-Info.plist.
3. Replace existing plist in the project if needed.
4. Enable Authentication providers:
- Email/Password
- Email link verification enabled
5. In Firestore, create database in production mode.
6. Deploy Firestore rules from file:
- CampusConnect/firebase/firestore.rules

## Phase 3: Firestore Data Bootstrapping
1. Create an ADMIN user document in users collection manually:
- role = ADMIN
- accountStatus = ACTIVE
- warningCount = 0
2. Ensure normal users default to:
- role = USER
- accountStatus = ACTIVE
3. Optional: run seed flow from admin panel once to populate initial events.

## Phase 4: Backend Automation Setup (Free Strategy)
1. From firebase/functions, run npm install.
2. Set your Firebase project with firebase use <project-id>.
3. Deploy Firestore rules only:
- firebase deploy --only firestore:rules
4. Push repository changes so GitHub Actions workflows run your automation jobs.
5. Verify GitHub Actions scheduled workflows are active:
- Reconcile Events (Free Tier)
- Expire Archive Events (Daily)
- Cleanup Archived Events (Weekly)
- Sync KUET Notices (Every 4 Hours)
6. Optional paid path: if you later upgrade to Blaze, you can deploy Cloud Functions with:
- firebase deploy --only functions

## Phase 5: Cloudinary Setup (Required for event banners)
1. Create free Cloudinary account.
2. Create unsigned upload preset for mobile uploads.
3. In Constants.swift set:
- cloudinaryCloudName
- cloudinaryUploadPreset
4. Build and run app.
5. In Create Event screen, select a cover photo and submit.

## Phase 6: APNs and Notification Setup
1. In Apple Developer portal, enable Push Notifications for app ID.
2. Create APNs key and upload in Firebase Cloud Messaging settings.
3. In Xcode target capabilities, enable Push Notifications.
4. Keep Background Modes as needed for remote notifications.
5. Run app and allow notification permission.

## Phase 7: Gmail Optional Integration Setup
This is optional and should not block app usage.
1. In Google Cloud Console, configure OAuth consent screen.
2. Create OAuth client for iOS app.
3. Add token exchange handling in backend function (placeholder already in functions).
4. Keep KUET notice board as primary source even if Gmail is not connected.

## Phase 8: Manual QA Checklist
1. Sign up using non-campus email -> must fail.
2. Sign up using campus email -> verification required.
3. Try login without verification -> blocked with clear message.
4. Create event as USER -> status should be pending approval.
5. Approve/reject as ADMIN from approval queue.
6. Reject with reason -> user sees feedback and can resubmit.
7. Upvote/un-upvote event and verify counters update.
8. Add comments/replies and report a comment.
9. Open admin reports queue and moderation screens.
10. Apply warning/restriction/ban and verify account behavior.
11. Test deep link campusconnect://event/<eventId> while:
- signed out
- unverified
- verified campus user
12. Confirm calendar shows month grid with day markers and upvoted markers.
13. Configure reminder offset from event details and verify notification scheduling.

## Phase 9: Production Readiness Checklist
1. Move API-like constants to secure runtime config for release builds.
2. Add Firestore indexes requested by query errors from console.
3. Enable App Check in Firebase.
4. Verify security rules in simulator and on-device flows.
5. Add monitoring for GitHub Actions failures and notice sync failures.

## Phase 10: What You Should Do Next in Order
1. Configure Cloudinary keys in Constants.swift.
2. Deploy Firebase rules (free path) and verify GitHub Actions workflows.
3. Create first ADMIN user document.
4. Run app and execute QA checklist above.
5. Share any failing step with logs, and then patch iteration can continue quickly.
