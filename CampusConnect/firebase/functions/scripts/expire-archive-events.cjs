const { admin, initFirestore } = require('./lib/firebase.cjs');
const { recordUsage, writeSummary } = require('./lib/usage.cjs');

const MAX_EVENTS = Number.parseInt(process.env.EXPIRE_MAX_EVENTS || '500', 10);
const SCAN_MULTIPLIER = Number.parseInt(process.env.EXPIRE_SCAN_MULTIPLIER || '5', 10);

async function main() {
  const db = initFirestore();
  const startedAt = new Date().toISOString();

  let reads = 0;
  let writes = 0;
  let deletes = 0;

  const today = new Date().toISOString().slice(0, 10);

  const scanLimit = Math.max(MAX_EVENTS * SCAN_MULTIPLIER, MAX_EVENTS);

  const eventsSnap = await db
    .collection('events')
    .where('status', '==', 'APPROVED')
    .limit(scanLimit)
    .get();

  reads += eventsSnap.size;

  const targetDocs = eventsSnap.docs
    .filter((doc) => {
      const eventDate = doc.get('date');
      return typeof eventDate === 'string' && eventDate < today;
    })
    .slice(0, MAX_EVENTS);

  if (targetDocs.length > 0) {
    const batch = db.batch();

    targetDocs.forEach((doc) => {
      batch.update(doc.ref, {
        status: 'EXPIRED',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    writes += targetDocs.length;
  }

  const usageStatus = await recordUsage(db, {
    jobName: 'expire_archive_events',
    reads,
    writes,
    deletes,
  });

  const summary = {
    jobName: 'expire_archive_events',
    startedAt,
    finishedAt: new Date().toISOString(),
    maxEventsPerRun: MAX_EVENTS,
    scannedEvents: eventsSnap.size,
    expiredEvents: targetDocs.length,
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
