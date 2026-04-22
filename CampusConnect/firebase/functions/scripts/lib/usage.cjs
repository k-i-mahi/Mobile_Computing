const fs = require('fs');
const path = require('path');
const { admin } = require('./firebase.cjs');

const DEFAULT_FREE_LIMITS = {
  reads: 50000,
  writes: 20000,
  deletes: 20000,
};

function toInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function toFloat(value, fallback) {
  const parsed = Number.parseFloat(String(value ?? ''));
  return Number.isNaN(parsed) ? fallback : parsed;
}

function getTodayKey() {
  return new Date().toISOString().slice(0, 10);
}

function getLimits() {
  return {
    reads: toInt(process.env.FREE_READ_LIMIT, DEFAULT_FREE_LIMITS.reads),
    writes: toInt(process.env.FREE_WRITE_LIMIT, DEFAULT_FREE_LIMITS.writes),
    deletes: toInt(process.env.FREE_DELETE_LIMIT, DEFAULT_FREE_LIMITS.deletes),
  };
}

function getThreshold() {
  return toFloat(process.env.ALERT_THRESHOLD_PCT, 0.75);
}

function asPct(current, limit) {
  if (!limit) {
    return 0;
  }

  return (current / limit) * 100;
}

async function recordUsage(db, usageInput) {
  const usage = {
    reads: toInt(usageInput.reads, 0),
    writes: toInt(usageInput.writes, 0),
    deletes: toInt(usageInput.deletes, 0),
  };

  const jobName = usageInput.jobName || 'unknown_job';
  const dateKey = getTodayKey();
  const usageRef = db.collection('automation_usage').doc(dateKey);

  let totals = {
    reads: usage.reads,
    writes: usage.writes,
    deletes: usage.deletes,
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(usageRef);
    const previous = snap.exists ? snap.data() : {};
    const previousJobs = previous.jobs || {};
    const previousJob = previousJobs[jobName] || { runs: 0, reads: 0, writes: 0, deletes: 0 };

    totals = {
      reads: toInt(previous.reads, 0) + usage.reads,
      writes: toInt(previous.writes, 0) + usage.writes,
      deletes: toInt(previous.deletes, 0) + usage.deletes,
    };

    tx.set(
      usageRef,
      {
        reads: totals.reads,
        writes: totals.writes,
        deletes: totals.deletes,
        jobs: {
          ...previousJobs,
          [jobName]: {
            runs: toInt(previousJob.runs, 0) + 1,
            reads: toInt(previousJob.reads, 0) + usage.reads,
            writes: toInt(previousJob.writes, 0) + usage.writes,
            deletes: toInt(previousJob.deletes, 0) + usage.deletes,
            lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        createdAt: previous.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  const limits = getLimits();
  const threshold = getThreshold();

  const alerts = [];
  ['reads', 'writes', 'deletes'].forEach((metric) => {
    const limit = limits[metric];
    const current = totals[metric];
    const ratio = limit ? current / limit : 0;

    if (ratio >= threshold) {
      alerts.push(
        `${metric} usage is at ${asPct(current, limit).toFixed(1)}% (${current}/${limit}) for ${dateKey}.`
      );
    }
  });

  return {
    dateKey,
    totals,
    limits,
    threshold,
    nearLimit: alerts.length > 0,
    alerts,
  };
}

function writeSummary(summary) {
  const outputPath = process.env.AUTOMATION_SUMMARY_PATH;

  if (outputPath) {
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(outputPath, JSON.stringify(summary, null, 2));
  }

  console.log(JSON.stringify(summary, null, 2));
}

module.exports = {
  recordUsage,
  writeSummary,
};
