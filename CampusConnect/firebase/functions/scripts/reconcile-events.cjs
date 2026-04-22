const { admin, initFirestore } = require('./lib/firebase.cjs');
const { recordUsage, writeSummary } = require('./lib/usage.cjs');

const MAX_EVENTS = Number.parseInt(process.env.RECONCILE_MAX_EVENTS || '120', 10);

function asNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

async function main() {
  const db = initFirestore();
  const startedAt = new Date().toISOString();

  let reads = 0;
  let writes = 0;
  let deletes = 0;

  const stateRef = db.collection('automation_state').doc('reconcile_events');
  const stateSnap = await stateRef.get();
  reads += 1;

  const cursorId = stateSnap.exists ? stateSnap.get('cursorId') : null;

  let query = db.collection('events').orderBy(admin.firestore.FieldPath.documentId()).limit(MAX_EVENTS);
  if (cursorId) {
    query = query.startAfter(cursorId);
  }

  let eventsSnap = await query.get();
  reads += eventsSnap.size;

  let wrappedCursor = false;

  if (eventsSnap.empty && cursorId) {
    eventsSnap = await db
      .collection('events')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(MAX_EVENTS)
      .get();
    reads += eventsSnap.size;
    wrappedCursor = true;
  }

  let updatedEvents = 0;

  if (!eventsSnap.empty) {
    const batch = db.batch();

    for (const eventDoc of eventsSnap.docs) {
      const eventData = eventDoc.data() || {};

      const [upvoteCountAgg, commentCountAgg] = await Promise.all([
        eventDoc.ref.collection('upvotes').count().get(),
        eventDoc.ref.collection('comments').count().get(),
      ]);
      reads += 2;

      const upvoteCount = asNumber(upvoteCountAgg.data().count);
      const commentCount = asNumber(commentCountAgg.data().count);

      const existingUpvotes = asNumber(eventData.upvoteCount);
      const existingComments = asNumber(eventData.commentCount);

      if (upvoteCount !== existingUpvotes || commentCount !== existingComments) {
        batch.update(eventDoc.ref, {
          upvoteCount,
          commentCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        writes += 1;
        updatedEvents += 1;
      }
    }

    if (updatedEvents > 0) {
      await batch.commit();
    }
  }

  const nextCursorId = eventsSnap.empty ? null : eventsSnap.docs[eventsSnap.docs.length - 1].id;
  const stateUpdate = {
    cursorId: nextCursorId,
    lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (wrappedCursor) {
    stateUpdate.lastWrappedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await stateRef.set(stateUpdate, { merge: true });
  writes += 1;

  const usageStatus = await recordUsage(db, {
    jobName: 'reconcile_events',
    reads,
    writes,
    deletes,
  });

  const summary = {
    jobName: 'reconcile_events',
    startedAt,
    finishedAt: new Date().toISOString(),
    maxEventsPerRun: MAX_EVENTS,
    processedEvents: eventsSnap.size,
    updatedEvents,
    wrappedCursor,
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
