# Free-Tier Automation Plan

This setup replaces paid Firebase Functions automation with GitHub Actions on the Spark plan.

## Schedules

- Reconciliation incremental: every 30 minutes
- Expire/archive job: daily at 02:20 UTC
- Cleanup job: weekly on Sunday at 03:30 UTC
- Notice sync: every 4 hours

## Required GitHub Secrets

Add these repository secrets in GitHub:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: full JSON for a service account with Firestore access.
- `FIREBASE_PROJECT_ID`: your Firebase project id (example: `campusconnect-da9af`).

## What Gets Created

Workflows:

- `.github/workflows/reconcile-events.yml`
- `.github/workflows/expire-archive-events.yml`
- `.github/workflows/cleanup-archived-events.yml`
- `.github/workflows/sync-notices.yml`

Scripts:

- `firebase/functions/scripts/reconcile-events.cjs`
- `firebase/functions/scripts/expire-archive-events.cjs`
- `firebase/functions/scripts/cleanup-archived-events.cjs`
- `firebase/functions/scripts/sync-notices.cjs`
- `firebase/functions/scripts/lib/firebase.cjs`
- `firebase/functions/scripts/lib/usage.cjs`

## Alerting Near Free Limits

Each job writes estimated operation counters to Firestore:

- Collection: `automation_usage`
- Doc id format: `YYYY-MM-DD`

Threshold behavior:

- `ALERT_THRESHOLD_PCT` default is `0.75` (75% of free-tier limits).
- If reads/writes/deletes reach threshold, workflow opens or updates a GitHub issue labeled `firebase-free-tier-alert`.

Default free-tier limits used by scripts:

- Reads: 50,000/day
- Writes: 20,000/day
- Deletes: 20,000/day

You can override limits per workflow using env vars:

- `FREE_READ_LIMIT`
- `FREE_WRITE_LIMIT`
- `FREE_DELETE_LIMIT`

## Batch Caps (Current)

- Reconcile: `RECONCILE_MAX_EVENTS=120`
- Expire/archive: `EXPIRE_MAX_EVENTS=500`
- Cleanup: `CLEANUP_MAX_EVENTS=300`
- Notice sync: `NOTICE_MAX_ITEMS_PER_RUN=120`

If usage gets close to limits, reduce these caps first.

## Enabling

1. Commit and push these files to GitHub.
2. Add the two required secrets.
3. Open Actions tab and run each workflow once using `workflow_dispatch`.
4. Confirm `automation_usage/YYYY-MM-DD` appears in Firestore.
