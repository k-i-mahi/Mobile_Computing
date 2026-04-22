const { initFirestore, admin } = require('./lib/firebase.cjs');
const { recordUsage, writeSummary } = require('./lib/usage.cjs');

const MAX_EVENTS = Number.parseInt(process.env.CLEANUP_MAX_EVENTS || '300', 10);
const RETENTION_DAYS = Number.parseInt(process.env.ARCHIVE_RETENTION_DAYS || '90', 10);
const SCAN_MULTIPLIER = Number.parseInt(process.env.CLEANUP_SCAN_MULTIPLIER || '5', 10);

async function main() {
  const db = initFirestore();
  const startedAt = new Date().toISOString();

  let reads = 0;
  let writes = 0;
  let deletes = 0;

  const cutoffDate = new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000);
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

  const scanLimit = Math.max(MAX_EVENTS * SCAN_MULTIPLIER, MAX_EVENTS);

  const eventsSnap = await db
    .collection('events')
    .where('status', '==', 'ARCHIVED')
    .limit(scanLimit)
    .get();

  reads += eventsSnap.size;

  const targetDocs = eventsSnap.docs
    .filter((doc) => {
      const archivedAt = doc.get('archivedAt');
      return archivedAt instanceof admin.firestore.Timestamp && archivedAt.isBefore(cutoffTimestamp);
    })
    .slice(0, MAX_EVENTS);

  if (targetDocs.length > 0) {
    const batch = db.batch();

    targetDocs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    deletes += targetDocs.length;
  }

  const usageStatus = await recordUsage(db, {
    jobName: 'cleanup_archived_events',
    reads,
    writes,
    deletes,
  });

  const summary = {
    jobName: 'cleanup_archived_events',
    startedAt,
    finishedAt: new Date().toISOString(),
    maxEventsPerRun: MAX_EVENTS,
    retentionDays: RETENTION_DAYS,
    scannedEvents: eventsSnap.size,
    deletedEvents: targetDocs.length,
    usageThisRun: { reads, writes, deletes },
    usageTotalsToday: usageStatus.totals,
    freeTierLimits: usageStatus.limits,
    nearLimit: usageStatus.nearLimit,
    alerts: usageStatus.alerts,
  };

  writeSummary(summary);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
