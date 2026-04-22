# App Check Real-Device Setup

Last updated: 2026-04-11
Project: campusconnect-da9af

## Why this matters
App Check protects your Firebase backend from unauthorized clients. If App Check API/provider is not configured in Firebase Console, real-device requests may fail or use placeholder tokens.

## What is already implemented in app code
- DEBUG builds: App Check is disabled in client startup to avoid blocking local development.
- RELEASE builds on device: App uses App Attest when available, with DeviceCheck fallback.

Code reference:
- CampusConnect/App/CampusConnectApp.swift

## Required Firebase Console steps (one-time)

1. Enable App Check API
- Open: https://console.developers.google.com/apis/api/firebaseappcheck.googleapis.com/overview?project=470491786545
- Click Enable.

2. Register iOS app in App Check
- Firebase Console -> Build -> App Check -> Apps
- Select your iOS app (bundle ID must match build target)
- Register provider:
  - Preferred: App Attest
  - Fallback: DeviceCheck

3. Start in monitor mode first
- For Firestore and Auth, keep App Check in monitor mode while validating clients.
- Confirm legitimate traffic is accepted.

4. Move to enforcement mode
- After validation, switch Firestore/Auth to enforcement.
- Keep release build tests on physical device.

## If You Do Not Have an iPhone (Simulator-only path)

You can continue full feature development on simulator without enabling App Check enforcement yet.

1. Keep App Check API enabled in Google Cloud.
2. In Firebase App Check product pages (Firestore/Auth), keep mode in Monitor (not Enforced).
3. Do not block your development waiting for Team ID or device registration.
4. Continue running DEBUG simulator builds (App Check is intentionally disabled in app code for DEBUG).
5. When you later get a physical iPhone, complete provider registration and then switch enforcement on.

Recommended now:
- Focus on feature correctness and Firestore rule correctness.
- Treat App Check as a release hardening step, not a simulator prerequisite.

## Real-device validation checklist

1. Install and run a RELEASE build on physical iPhone.
2. Sign in with campus account.
3. Open dashboard, event details, comments, notifications, profile.
4. Verify no repeated App Check token errors in device logs.
5. Verify Firestore reads/writes succeed under enforcement.

## Common failure and fix

Failure:
- 403 on exchangeDebugToken / SERVICE_DISABLED for firebaseappcheck.googleapis.com

Fix:
- Enable App Check API link above
- Ensure provider registration exists for the same iOS app ID/bundle
- Wait a few minutes for propagation

## Notes
- Simulator behavior does not represent real App Check enforcement behavior.
- Keep DEBUG builds developer-friendly; validate enforcement on RELEASE + physical device.
