const axios = require('axios');
const cheerio = require('cheerio');
const https = require('https');
const { admin, initFirestore } = require('./lib/firebase.cjs');
const { recordUsage, writeSummary } = require('./lib/usage.cjs');

const MAX_NOTICES_PER_RUN = Number.parseInt(process.env.NOTICE_MAX_ITEMS_PER_RUN || '120', 10);
const KUET_BASE_URL = 'https://www.kuet.ac.bd/';
const ALLOW_INSECURE_TLS = process.env.NOTICE_ALLOW_INSECURE_TLS === '1';
const AXIOS_OPTIONS = {
  timeout: 12000,
  httpsAgent: ALLOW_INSECURE_TLS ? new https.Agent({ rejectUnauthorized: false }) : undefined,
};

const SOURCES = [
  {
    key: 'kuet_home',
    url: KUET_BASE_URL,
    sourceName: 'KUET Official Website',
    fallbackSourceType: 'KUET_NOTICE',
  },
  {
    key: 'kuet_latest_info',
    url: 'https://www.kuet.ac.bd/latest-info',
    sourceName: 'KUET Latest Info',
    fallbackSourceType: 'KUET_LATEST_INFO',
  },
  {
    key: 'kuet_notices',
    url: 'https://www.kuet.ac.bd/notices',
    sourceName: 'KUET Notices',
    fallbackSourceType: 'KUET_NOTICE',
  },
];

function toDocId(url) {
  return Buffer.from(url).toString('base64').replace(/=/g, '');
}

function compact(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function normalizeUrl(href, sourceUrl) {
  try {
    return new URL(href, sourceUrl).toString();
  } catch {
    return null;
  }
}

const MONTHS = {
  jan: 0,
  january: 0,
  feb: 1,
  february: 1,
  mar: 2,
  march: 2,
  apr: 3,
  april: 3,
  may: 4,
  jun: 5,
  june: 5,
  jul: 6,
  july: 6,
  aug: 7,
  august: 7,
  sep: 8,
  sept: 8,
  september: 8,
  oct: 9,
  october: 9,
  nov: 10,
  november: 10,
  dec: 11,
  december: 11,
};

function resolvedYearFor(monthIndex) {
  const now = new Date();
  let year = now.getUTCFullYear();
  const candidate = new Date(Date.UTC(year, monthIndex, 1, 12));
  const futureCutoff = new Date(now.getTime() + 1000 * 60 * 60 * 24 * 45);
  if (candidate > futureCutoff) {
    year -= 1;
  }
  return year;
}

function timestampFromParts(dayValue, monthValue, yearValue) {
  const monthIndex = MONTHS[String(monthValue || '').toLowerCase()];
  const day = Number.parseInt(String(dayValue || ''), 10);
  const year = yearValue ? Number.parseInt(String(yearValue), 10) : resolvedYearFor(monthIndex);

  if (monthIndex === undefined || Number.isNaN(day) || Number.isNaN(year)) {
    return null;
  }

  return admin.firestore.Timestamp.fromDate(new Date(Date.UTC(year, monthIndex, day, 12)));
}

function parseTitleAndDate(rawTitle) {
  const title = compact(rawTitle);

  let match = title.match(/^(\d{1,2})[-\s]([A-Za-z]{3,9})[-,\s]+(\d{4})\s+(.+)$/);
  if (match) {
    return {
      title: compact(match[4]),
      publishedAt: timestampFromParts(match[1], match[2], match[3]),
    };
  }

  match = title.match(/^([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})\s+(.+)$/);
  if (match) {
    return {
      title: compact(match[4]),
      publishedAt: timestampFromParts(match[2], match[1], match[3]),
    };
  }

  match = title.match(/^([A-Za-z]{3,9})\s+(\d{1,2})\s+(.+)$/);
  if (match) {
    return {
      title: compact(match[3]),
      publishedAt: timestampFromParts(match[2], match[1], undefined),
    };
  }

  return { title, publishedAt: null };
}

function sourceTypeFor(source, rawTitle, normalizedUrl) {
  const haystack = `${source.url} ${rawTitle} ${normalizedUrl}`.toLowerCase();
  if (source.key === 'kuet_latest_info' || /^\d{1,2}[-\s][A-Za-z]{3,9}[-,\s]+\d{4}/.test(rawTitle)) {
    return 'KUET_LATEST_INFO';
  }
  if (haystack.includes('academic')) {
    return 'KUET_ACADEMIC_NOTICE';
  }
  if (haystack.includes('administrative') || haystack.includes('admin')) {
    return 'KUET_ADMINISTRATIVE_NOTICE';
  }
  return source.fallbackSourceType;
}

function isNoticeCandidate(rawTitle, normalizedUrl, parsed) {
  if (!parsed.publishedAt || parsed.title.length < 8 || !normalizedUrl) {
    return false;
  }

  const lowerTitle = parsed.title.toLowerCase();
  if (lowerTitle === 'all notices' || lowerTitle === 'all news' || lowerTitle === 'explore here') {
    return false;
  }

  const host = new URL(normalizedUrl).host.toLowerCase();
  return host.includes('kuet.ac.bd') ||
    host.includes('drive.google.com') ||
    host.includes('admission.kuet.ac.bd');
}

async function main() {
  const dryRun = process.env.NOTICE_DRY_RUN === '1';
  const db = dryRun ? null : initFirestore();
  const startedAt = new Date().toISOString();

  let reads = 0;
  let writes = 0;
  let deletes = 0;

  const collected = [];
  const seenUrls = new Set();
  const failures = [];

  for (const source of SOURCES) {
    if (collected.length >= MAX_NOTICES_PER_RUN) {
      break;
    }

    try {
      const response = await axios.get(source.url, AXIOS_OPTIONS);
      const $ = cheerio.load(response.data);
      let sourceItemCount = 0;

      $('a').each((_, el) => {
        if (collected.length >= MAX_NOTICES_PER_RUN) {
          return;
        }

        const rawTitle = compact($(el).text());
        const href = compact($(el).attr('href'));
        const normalizedUrl = normalizeUrl(href, source.url);
        const parsed = parseTitleAndDate(rawTitle);

        if (!isNoticeCandidate(rawTitle, normalizedUrl, parsed)) {
          return;
        }

        if (seenUrls.has(normalizedUrl)) {
          return;
        }

        seenUrls.add(normalizedUrl);
        sourceItemCount += 1;
        collected.push({
          sourceKey: source.key,
          sourceName: source.sourceName,
          sourceUrl: source.url,
          sourceType: sourceTypeFor(source, rawTitle, normalizedUrl),
          title: parsed.title,
          normalizedUrl,
          publishedAt: parsed.publishedAt,
          id: toDocId(normalizedUrl),
        });
      });

      if (!dryRun) {
        await db.collection('notice_sources').doc(source.key).set(
          {
            sourceName: source.sourceName,
            sourceType: source.fallbackSourceType,
            sourceUrl: source.url,
            status: 'AVAILABLE',
            itemCount: sourceItemCount,
            lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        writes += 1;
      }
    } catch (error) {
      failures.push({
        source: source.url,
        sourceKey: source.key,
        sourceName: source.sourceName,
        sourceType: source.fallbackSourceType,
        message: error.message,
      });

      if (!dryRun) {
        await db.collection('notice_sources').doc(source.key).set(
          {
            sourceName: source.sourceName,
            sourceType: source.fallbackSourceType,
            sourceUrl: source.url,
            status: 'UNAVAILABLE',
            lastError: error.message,
            lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        writes += 1;
      }
    }
  }

  if (!dryRun && collected.length > 0) {
    const batch = db.batch();

    collected.forEach((item) => {
      const ref = db.collection('notice_board_items').doc(item.id);
      batch.set(
        ref,
        {
          title: item.title,
          sourceType: item.sourceType,
          sourceName: item.sourceName,
          sourceUrl: item.sourceUrl,
          originalUrl: item.normalizedUrl,
          publishedAt: item.publishedAt,
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    await batch.commit();
    writes += collected.length;
  }

  if (!dryRun && failures.length > 0) {
    const batch = db.batch();

    failures.forEach((failure, index) => {
      const ref = db.collection('admin_actions').doc(`NOTICE_SYNC_FAILED_${Date.now()}_${index}`);
      batch.set(ref, {
        action: 'NOTICE_SYNC_FAILED',
        source: failure.source,
        sourceName: failure.sourceName,
        sourceType: failure.sourceType,
        message: failure.message,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    writes += failures.length;
  }

  const usageStatus = dryRun
    ? {
        totals: { reads, writes, deletes },
        limits: {},
        nearLimit: false,
        alerts: [],
      }
    : await recordUsage(db, {
        jobName: 'sync_notice_board',
        reads,
        writes,
        deletes,
      });

  const summary = {
    jobName: 'sync_notice_board',
    dryRun,
    allowInsecureTLS: ALLOW_INSECURE_TLS,
    startedAt,
    finishedAt: new Date().toISOString(),
    maxNoticesPerRun: MAX_NOTICES_PER_RUN,
    syncedNotices: collected.length,
    sampleNotices: collected.slice(0, 5).map((item) => ({
      title: item.title,
      sourceType: item.sourceType,
      sourceName: item.sourceName,
      originalUrl: item.normalizedUrl,
    })),
    failedSources: failures.length,
    failedSourceDetails: failures,
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
