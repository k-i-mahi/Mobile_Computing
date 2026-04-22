import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import axios from 'axios';
import * as cheerio from 'cheerio';
import * as crypto from 'crypto';
import * as https from 'https';

admin.initializeApp();
const db = admin.firestore();

function normalizeEmail(value: unknown): string {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function isCampusEmail(email: string): boolean {
  return email.endsWith('@stud.kuet.ac.bd');
}

function isStrongPassword(password: string): boolean {
  return password.length >= 6 && /[A-Z]/.test(password) && /[a-z]/.test(password) && /[0-9]/.test(password);
}

function toBase64Url(input: string | Buffer): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function notificationDocId(dedupeKey: string): string {
  return toBase64Url(dedupeKey).slice(0, 120);
}

async function writeUserEventNotification(
  uid: string,
  data: {
    eventId: string;
    eventTitle: string;
    kind: string;
    message: string;
    targetCommentId?: string;
    targetReplyId?: string;
    dedupeKey: string;
  }
): Promise<void> {
  if (!uid || !data.eventId || !data.dedupeKey) {
    return;
  }

  const ref = db.collection('user_notifications')
    .doc(uid)
    .collection('items')
    .doc(notificationDocId(data.dedupeKey));

  const existing = await ref.get();
  if (existing.exists) {
    return;
  }

  await ref.set({
    eventId: data.eventId,
    eventTitle: data.eventTitle,
    kind: data.kind,
    message: data.message,
    targetCommentId: data.targetCommentId ?? null,
    targetReplyId: data.targetReplyId ?? null,
    dedupeKey: data.dedupeKey,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function eventTitleFrom(data: admin.firestore.DocumentData | undefined, fallback = 'Event'): string {
  const title = typeof data?.title === 'string' ? data.title.trim() : '';
  return title || fallback;
}

function parseEventDateTimestamp(value: unknown): admin.firestore.Timestamp | null {
  if (typeof value !== 'string' || !value.trim()) {
    return null;
  }
  const raw = value.trim();
  const parsed = /^\d{4}-\d{2}-\d{2}$/.test(raw)
    ? new Date(`${raw}T00:00:00.000Z`)
    : new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return admin.firestore.Timestamp.fromDate(parsed);
}

function nextReminderTimestamp(
  eventDate: admin.firestore.Timestamp | null,
  offsetHours: number,
  systemPermissionGranted: boolean | undefined
): admin.firestore.Timestamp | admin.firestore.FieldValue {
  if (!eventDate || systemPermissionGranted === false) {
    return admin.firestore.FieldValue.delete();
  }
  const triggerDate = new Date(eventDate.toMillis() - offsetHours * 60 * 60 * 1000);
  return triggerDate > new Date()
    ? admin.firestore.Timestamp.fromDate(triggerDate)
    : admin.firestore.FieldValue.delete();
}

export const checkAccountExistsForReset = functions.https.onCall(async (data) => {
  const email = normalizeEmail(data?.email);

  if (!isCampusEmail(email)) {
    throw new functions.https.HttpsError('invalid-argument', 'Enter your campus email to continue.');
  }

  try {
    await admin.auth().getUserByEmail(email);
    return { exists: true };
  } catch (err) {
    const code = (err as { code?: string }).code;
    if (code === 'auth/user-not-found') {
      return { exists: false };
    }

    throw new functions.https.HttpsError('internal', 'Failed to verify account right now.');
  }
});

export const resetPasswordDirect = functions.https.onCall(async (data) => {
  const email = normalizeEmail(data?.email);
  const newPassword = typeof data?.newPassword === 'string' ? data.newPassword : '';

  if (!isCampusEmail(email)) {
    throw new functions.https.HttpsError('invalid-argument', 'Enter your campus email to continue.');
  }

  if (!isStrongPassword(newPassword)) {
    throw new functions.https.HttpsError('invalid-argument', 'Use a stronger password with upper, lower, and number.');
  }

  let userRecord: admin.auth.UserRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (err) {
    const code = (err as { code?: string }).code;
    if (code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('failed-precondition', 'Account not registered yet. Please sign up!');
    }
    throw new functions.https.HttpsError('internal', 'Could not update password right now.');
  }

  await admin.auth().updateUser(userRecord.uid, { password: newPassword });

  await db.collection('users').doc(userRecord.uid).set(
    {
      passwordUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true };
});

export const onEventApprovalTransition = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== 'APPROVED' && after.status === 'APPROVED') {
      await db.collection('admin_actions').add({
        action: 'EVENT_APPROVED',
        eventId: context.params.eventId,
        actorUid: after.lastModeratedBy ?? 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (before.status !== 'REJECTED' && after.status === 'REJECTED') {
      if (!after.rejectionReason) {
        throw new Error('Rejected events must have a rejection reason.');
      }

      await db.collection('admin_actions').add({
        action: 'EVENT_REJECTED',
        eventId: context.params.eventId,
        reason: after.rejectionReason,
        actorUid: after.lastModeratedBy ?? 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

export const onUpvoteWrite = functions.firestore
  .document('events/{eventId}/upvotes/{uid}')
  .onWrite(async (change, context) => {
    const eventRef = db.collection('events').doc(context.params.eventId);
    const increment = !change.before.exists && change.after.exists ? 1 : change.before.exists && !change.after.exists ? -1 : 0;

    if (increment !== 0) {
      await eventRef.update({
        upvoteCount: admin.firestore.FieldValue.increment(increment),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (!change.before.exists && change.after.exists) {
      const eventSnap = await eventRef.get();
      const event = eventSnap.data();
      const creatorUid = typeof event?.creatorUid === 'string' ? event.creatorUid : '';
      const actorUid = typeof change.after.data()?.uid === 'string' ? change.after.data()?.uid : context.params.uid;

      if (creatorUid && actorUid && creatorUid !== actorUid) {
        await writeUserEventNotification(creatorUid, {
          eventId: context.params.eventId,
          eventTitle: eventTitleFrom(event),
          kind: 'UPVOTE_ON_YOUR_EVENT',
          message: 'Someone upvoted your event.',
          dedupeKey: `UPVOTE_ON_OWN|${context.params.eventId}|${actorUid}`,
        });
      }
    }
  });

export const onCommentWrite = functions.firestore
  .document('events/{eventId}/comments/{commentId}')
  .onWrite(async (change, context) => {
    const eventRef = db.collection('events').doc(context.params.eventId);
    const after = change.after.exists ? change.after.data() : null;
    const before = change.before.exists ? change.before.data() : null;

    if (!before && after) {
      await eventRef.update({
        commentCount: admin.firestore.FieldValue.increment(1),
      });

      const uid = after.authorUid as string;
      const commentsByUser = await db
        .collection(`events/${context.params.eventId}/comments`)
        .where('authorUid', '==', uid)
        .count()
        .get();

      if ((commentsByUser.data().count ?? 0) > 50) {
        await db.collection('moderation_cases').add({
          type: 'SUSPICIOUS_COMMENT_VOLUME',
          eventId: context.params.eventId,
          userUid: uid,
          status: 'OPEN',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const eventSnap = await eventRef.get();
      const event = eventSnap.data();
      const creatorUid = typeof event?.creatorUid === 'string' ? event.creatorUid : '';
      if (creatorUid && creatorUid !== uid) {
        const authorName = typeof after.authorName === 'string' && after.authorName.trim()
          ? after.authorName.trim()
          : 'Someone';
        await writeUserEventNotification(creatorUid, {
          eventId: context.params.eventId,
          eventTitle: eventTitleFrom(event),
          kind: 'NEW_COMMENT_ON_YOUR_EVENT',
          message: `${authorName} commented on your event.`,
          targetCommentId: context.params.commentId,
          dedupeKey: `COMMENT_ON_OWN|${context.params.eventId}|${context.params.commentId}`,
        });
      }
    }

    if (before && !after) {
      await eventRef.update({
        commentCount: admin.firestore.FieldValue.increment(-1),
      });
    }
  });

export const onReplyCreate = functions.firestore
  .document('events/{eventId}/comments/{commentId}/replies/{replyId}')
  .onCreate(async (snap, context) => {
    const reply = snap.data();
    const replyAuthorUid = typeof reply.authorUid === 'string' ? reply.authorUid : '';

    const commentRef = db.collection('events')
      .doc(context.params.eventId)
      .collection('comments')
      .doc(context.params.commentId);
    const [commentSnap, eventSnap] = await Promise.all([
      commentRef.get(),
      db.collection('events').doc(context.params.eventId).get(),
    ]);

    const comment = commentSnap.data();
    const parentAuthorUid = typeof comment?.authorUid === 'string' ? comment.authorUid : '';
    if (!parentAuthorUid || parentAuthorUid === replyAuthorUid) {
      return;
    }

    const replyAuthorName = typeof reply.authorName === 'string' && reply.authorName.trim()
      ? reply.authorName.trim()
      : 'Someone';

    await writeUserEventNotification(parentAuthorUid, {
      eventId: context.params.eventId,
      eventTitle: eventTitleFrom(eventSnap.data()),
      kind: 'REPLY_TO_YOUR_COMMENT',
      message: `${replyAuthorName} replied to your comment.`,
      targetCommentId: context.params.commentId,
      targetReplyId: context.params.replyId,
      dedupeKey: `REPLY_TO_YOU|${context.params.eventId}|${context.params.commentId}|${context.params.replyId}`,
    });
  });

export const onEventDetailsChanged = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const venueChanged = before.venue !== after.venue;
    const dateChanged = before.date !== after.date;
    const titleChanged = before.title !== after.title;
    const statusChanged = before.status !== after.status;

    if (!venueChanged && !dateChanged && !titleChanged && !statusChanged) {
      return;
    }

    const changed: string[] = [];
    if (venueChanged) {
      changed.push('venue');
    }
    if (dateChanged) {
      changed.push('date/time');
    }
    if (statusChanged) {
      changed.push('status');
    }
    if (titleChanged) {
      changed.push('title');
    }

    const eventId = context.params.eventId;
    const eventDate = parseEventDateTimestamp(after.date);
    const reminders = await db.collectionGroup('items')
      .where('eventId', '==', eventId)
      .where('isEnabled', '==', true)
      .get();

    await Promise.all(reminders.docs.map(async (reminderDoc) => {
      const uid = reminderDoc.ref.parent.parent?.id;
      if (!uid) {
        return;
      }

      const reminder = reminderDoc.data();
      const reminderOffsetHours = typeof reminder.reminderOffsetHours === 'number'
        ? reminder.reminderOffsetHours
        : 24;
      const systemPermissionGranted = typeof reminder.systemPermissionGranted === 'boolean'
        ? reminder.systemPermissionGranted
        : undefined;

      await reminderDoc.ref.set(
        {
          eventTitle: eventTitleFrom(after),
          eventDate: eventDate ?? admin.firestore.FieldValue.delete(),
          nextReminderAt: nextReminderTimestamp(eventDate, reminderOffsetHours, systemPermissionGranted),
          lastSeenVenue: typeof after.venue === 'string' ? after.venue : '',
          lastSeenDate: typeof after.date === 'string' ? after.date : '',
          lastSeenStatus: typeof after.status === 'string' ? after.status : '',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      if (venueChanged || dateChanged) {
        await writeUserEventNotification(uid, {
          eventId,
          eventTitle: eventTitleFrom(after),
          kind: 'EVENT_DETAILS_CHANGED',
          message: `Event ${changed.filter((item) => item === 'venue' || item === 'date/time').join(' and ')} changed. Please review updated details.`,
          dedupeKey: `DETAILS|${eventId}|${after.venue ?? ''}|${after.date ?? ''}`,
        });
      }

      if (statusChanged) {
        await writeUserEventNotification(uid, {
          eventId,
          eventTitle: eventTitleFrom(after),
          kind: 'STATUS_CHANGE',
          message: `Event status updated to ${String(after.status ?? '').replace(/_/g, ' ')}.`,
          dedupeKey: `STATUS|${eventId}|${after.status ?? ''}`,
        });
      }
    }));
  });

export const warningEscalation = functions.firestore
  .document('warnings/{warningId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const userUid = data.userUid as string;
    const userRef = db.collection('users').doc(userUid);

    await db.runTransaction(async (tx) => {
      const userDoc = await tx.get(userRef);
      const warningCount = (userDoc.data()?.warningCount ?? 0) + 1;
      tx.update(userRef, { warningCount });

      if (warningCount >= 4) {
        tx.update(userRef, {
          accountStatus: 'BANNED',
          bannedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  });

export const expireAndArchiveEvents = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const [approvedSnapshot, legacyApprovedSnapshot] = await Promise.all([
      db
      .collection('events')
      .where('status', '==', 'APPROVED')
      .get(),
      db
        .collection('events')
        .where('isApproved', '==', true)
        .get(),
    ]);

    const now = Date.now();
    const byId = new Map<string, admin.firestore.QueryDocumentSnapshot>();
    approvedSnapshot.docs.forEach((doc) => byId.set(doc.id, doc));
    legacyApprovedSnapshot.docs.forEach((doc) => byId.set(doc.id, doc));

    let batch = db.batch();
    let pendingWrites = 0;

    const commitBatchIfNeeded = async (force = false): Promise<void> => {
      if (pendingWrites === 0) {
        return;
      }
      if (!force && pendingWrites < 450) {
        return;
      }
      await batch.commit();
      batch = db.batch();
      pendingWrites = 0;
    };

    for (const doc of byId.values()) {
      const data = doc.data();
      const rawStatus = typeof data.status === 'string' ? data.status : '';

      if (rawStatus === 'EXPIRED' || rawStatus === 'ARCHIVED' || rawStatus === 'REMOVED_BY_ADMIN') {
        continue;
      }

      const eventDate = parseEventDateTimestamp(data.date);
      if (!eventDate) {
        continue;
      }

      const expiresAtMillis = eventDate.toMillis() + 24 * 60 * 60 * 1000;
      if (expiresAtMillis > now) {
        continue;
      }

      batch.update(doc.ref, {
        status: 'EXPIRED',
        isApproved: false,
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      pendingWrites += 1;

      await commitBatchIfNeeded();
    }

    await commitBatchIfNeeded(true);
  });

export const cleanupArchivedEvents = functions.pubsub
  .schedule('every sunday 03:00')
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 1000 * 60 * 60 * 24 * 90)
    );

    const snapshot = await db
      .collection('events')
      .where('status', '==', 'ARCHIVED')
      .where('archivedAt', '<', cutoff)
      .get();

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  });

type KuetNoticeSource = {
  key: string;
  url: string;
  sourceName: string;
  fallbackSourceType: string;
};

type NormalizedKuetNotice = {
  id: string;
  title: string;
  sourceKey: string;
  sourceName: string;
  sourceType: string;
  sourceUrl: string;
  originalUrl: string;
  publishedAt: admin.firestore.Timestamp;
};

const kuetNoticeSources: KuetNoticeSource[] = [
  {
    key: 'kuet_home',
    url: 'https://www.kuet.ac.bd/',
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

const allowKuetInsecureTLS = process.env.NOTICE_ALLOW_INSECURE_TLS === '1';
const kuetAxiosOptions = {
  timeout: 12000,
  httpsAgent: allowKuetInsecureTLS ? new https.Agent({ rejectUnauthorized: false }) : undefined,
};

const kuetMonthIndexes: Record<string, number> = {
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

function compactNoticeText(value: unknown): string {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function normalizeKuetUrl(href: string, sourceUrl: string): string | null {
  try {
    return new URL(href, sourceUrl).toString();
  } catch {
    return null;
  }
}

function resolveKuetNoticeYear(monthIndex: number): number {
  const now = new Date();
  let year = now.getUTCFullYear();
  const candidate = new Date(Date.UTC(year, monthIndex, 1, 12));
  const futureCutoff = new Date(now.getTime() + 1000 * 60 * 60 * 24 * 45);
  if (candidate > futureCutoff) {
    year -= 1;
  }
  return year;
}

function kuetNoticeTimestamp(dayValue: string, monthValue: string, yearValue?: string): admin.firestore.Timestamp | null {
  const monthIndex = kuetMonthIndexes[String(monthValue || '').toLowerCase()];
  const day = Number.parseInt(String(dayValue || ''), 10);
  const year = yearValue ? Number.parseInt(String(yearValue), 10) : resolveKuetNoticeYear(monthIndex);

  if (monthIndex === undefined || Number.isNaN(day) || Number.isNaN(year)) {
    return null;
  }

  return admin.firestore.Timestamp.fromDate(new Date(Date.UTC(year, monthIndex, day, 12)));
}

function parseKuetNoticeTitle(rawTitle: string): { title: string; publishedAt: admin.firestore.Timestamp | null } {
  const title = compactNoticeText(rawTitle);

  let match = title.match(/^(\d{1,2})[-\s]([A-Za-z]{3,9})[-,\s]+(\d{4})\s+(.+)$/);
  if (match) {
    return {
      title: compactNoticeText(match[4]),
      publishedAt: kuetNoticeTimestamp(match[1], match[2], match[3]),
    };
  }

  match = title.match(/^([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})\s+(.+)$/);
  if (match) {
    return {
      title: compactNoticeText(match[4]),
      publishedAt: kuetNoticeTimestamp(match[2], match[1], match[3]),
    };
  }

  match = title.match(/^([A-Za-z]{3,9})\s+(\d{1,2})\s+(.+)$/);
  if (match) {
    return {
      title: compactNoticeText(match[3]),
      publishedAt: kuetNoticeTimestamp(match[2], match[1]),
    };
  }

  return { title, publishedAt: null };
}

function kuetNoticeSourceType(source: KuetNoticeSource, rawTitle: string, originalUrl: string): string {
  const haystack = `${source.url} ${rawTitle} ${originalUrl}`.toLowerCase();
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

function isKuetNoticeCandidate(parsed: { title: string; publishedAt: admin.firestore.Timestamp | null }, originalUrl: string | null): boolean {
  if (!parsed.publishedAt || parsed.title.length < 8 || !originalUrl) {
    return false;
  }
  const lowerTitle = parsed.title.toLowerCase();
  if (lowerTitle === 'all notices' || lowerTitle === 'all news' || lowerTitle === 'explore here') {
    return false;
  }
  const host = new URL(originalUrl).host.toLowerCase();
  return host.includes('kuet.ac.bd') ||
    host.includes('drive.google.com') ||
    host.includes('admission.kuet.ac.bd');
}

export const syncKuetNoticeBoard = functions.pubsub
  .schedule('every 4 hours')
  .onRun(async () => {
    const seenUrls = new Set<string>();
    const maxItems = 120;

    for (const source of kuetNoticeSources) {
      try {
        const response = await axios.get(source.url, kuetAxiosOptions);
        const $ = cheerio.load(response.data);
        const normalizedItems: NormalizedKuetNotice[] = [];

        $('a').each((_, el) => {
          if (seenUrls.size >= maxItems) {
            return;
          }

          const rawTitle = compactNoticeText($(el).text());
          const href = compactNoticeText($(el).attr('href'));
          const originalUrl = normalizeKuetUrl(href, source.url);
          const parsed = parseKuetNoticeTitle(rawTitle);

          if (!isKuetNoticeCandidate(parsed, originalUrl) || !originalUrl || !parsed.publishedAt) {
            return;
          }

          if (seenUrls.has(originalUrl)) {
            return;
          }

          seenUrls.add(originalUrl);
          normalizedItems.push({
            id: Buffer.from(originalUrl).toString('base64').replace(/=/g, ''),
            title: parsed.title,
            sourceKey: source.key,
            sourceName: source.sourceName,
            sourceType: kuetNoticeSourceType(source, rawTitle, originalUrl),
            sourceUrl: source.url,
            originalUrl,
            publishedAt: parsed.publishedAt,
          });
        });

        const batch = db.batch();
        normalizedItems.forEach((item) => {
          batch.set(
            db.collection('notice_board_items').doc(item.id),
            {
              title: item.title,
              sourceType: item.sourceType,
              sourceName: item.sourceName,
              sourceUrl: item.sourceUrl,
              originalUrl: item.originalUrl,
              publishedAt: item.publishedAt,
              syncedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        });
        batch.set(
          db.collection('notice_sources').doc(source.key),
          {
            sourceName: source.sourceName,
            sourceType: source.fallbackSourceType,
            sourceUrl: source.url,
            status: 'AVAILABLE',
            itemCount: normalizedItems.length,
            lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        await batch.commit();
      } catch (err) {
        await db.collection('notice_sources').doc(source.key).set(
          {
            sourceName: source.sourceName,
            sourceType: source.fallbackSourceType,
            sourceUrl: source.url,
            status: 'UNAVAILABLE',
            lastError: (err as Error).message,
            lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        await db.collection('admin_actions').add({
          action: 'NOTICE_SYNC_FAILED',
          source: source.url,
          sourceName: source.sourceName,
          sourceType: source.fallbackSourceType,
          message: (err as Error).message,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  });

type GmailSyncNotice = {
  id?: string;
  title?: string;
  sourceName?: string;
  sender?: string;
  originalUrl?: string;
  messageUrl?: string;
  publishedAt?: string | number;
};

type GmailHeader = {
  name?: string;
  value?: string;
};

type GmailMessage = {
  id?: string;
  threadId?: string;
  internalDate?: string;
  payload?: {
    headers?: GmailHeader[];
  };
};

function toStableDocId(input: string): string {
  return toBase64Url(input).slice(0, 120);
}

function toPublishedTimestamp(value: string | number | undefined): admin.firestore.Timestamp {
  if (value !== undefined) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return admin.firestore.Timestamp.fromDate(parsed);
    }
  }
  return admin.firestore.Timestamp.now();
}

function getHeader(headers: GmailHeader[] | undefined, name: string): string {
  const match = headers?.find((header) => header.name?.toLowerCase() === name.toLowerCase());
  return (match?.value ?? '').trim();
}

function gmailMessageUrl(messageId: string): string {
  return messageId
    ? `https://mail.google.com/mail/u/0/#inbox/${encodeURIComponent(messageId)}`
    : 'https://mail.google.com/';
}

function gmailPrivateKey(): string {
  return (
    process.env.GMAIL_DWD_PRIVATE_KEY ??
    process.env.GMAIL_DOMAIN_WIDE_DELEGATION_PRIVATE_KEY ??
    ''
  ).replace(/\\n/g, '\n');
}

function gmailClientEmail(): string {
  return (
    process.env.GMAIL_DWD_CLIENT_EMAIL ??
    process.env.GMAIL_DOMAIN_WIDE_DELEGATION_CLIENT_EMAIL ??
    ''
  ).trim();
}

function hasDomainWideDelegationConfig(): boolean {
  return Boolean(gmailClientEmail() && gmailPrivateKey());
}

function createGmailJwtAssertion(subjectEmail: string): string {
  const iat = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };
  const claims = {
    iss: gmailClientEmail(),
    scope: 'https://www.googleapis.com/auth/gmail.readonly',
    aud: 'https://oauth2.googleapis.com/token',
    sub: subjectEmail,
    iat,
    exp: iat + 3600,
  };

  const unsigned = `${toBase64Url(JSON.stringify(header))}.${toBase64Url(JSON.stringify(claims))}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const signature = signer.sign(gmailPrivateKey());
  return `${unsigned}.${toBase64Url(signature)}`;
}

async function getGmailAccessToken(subjectEmail: string): Promise<string> {
  const params = new URLSearchParams();
  params.set('grant_type', 'urn:ietf:params:oauth:grant-type:jwt-bearer');
  params.set('assertion', createGmailJwtAssertion(subjectEmail));

  const response = await axios.post(
    'https://oauth2.googleapis.com/token',
    params.toString(),
    {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 15000,
    }
  );

  const accessToken = (response.data as { access_token?: string }).access_token;
  if (!accessToken) {
    throw new Error('Gmail token exchange did not return an access token.');
  }
  return accessToken;
}

async function fetchGmailMessages(subjectEmail: string): Promise<GmailSyncNotice[]> {
  if (!hasDomainWideDelegationConfig()) {
    throw new Error('Missing Gmail domain-wide delegation service account configuration.');
  }

  const accessToken = await getGmailAccessToken(subjectEmail);
  const listParams = new URLSearchParams();
  listParams.set('maxResults', '40');
  listParams.append('labelIds', 'INBOX');
  listParams.set('includeSpamTrash', 'false');
  listParams.set('q', 'newer_than:30d');

  const listResponse = await axios.get(
    `https://gmail.googleapis.com/gmail/v1/users/me/messages?${listParams.toString()}`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
      timeout: 15000,
    }
  );

  const messageRefs = ((listResponse.data as { messages?: { id?: string }[] }).messages ?? [])
    .filter((message) => Boolean(message.id))
    .slice(0, 40);

  const notices: GmailSyncNotice[] = [];
  for (const messageRef of messageRefs) {
    const metadataParams = new URLSearchParams();
    metadataParams.set('format', 'metadata');
    metadataParams.append('metadataHeaders', 'Subject');
    metadataParams.append('metadataHeaders', 'From');
    metadataParams.append('metadataHeaders', 'Date');

    const messageResponse = await axios.get(
      `https://gmail.googleapis.com/gmail/v1/users/me/messages/${messageRef.id}?${metadataParams.toString()}`,
      {
        headers: { Authorization: `Bearer ${accessToken}` },
        timeout: 15000,
      }
    );

    const message = messageResponse.data as GmailMessage;
    const headers = message.payload?.headers ?? [];
    const subject = getHeader(headers, 'Subject') || '(no subject)';
    const sender = getHeader(headers, 'From') || 'Unknown sender';
    const dateHeader = getHeader(headers, 'Date');
    const internalDate = message.internalDate ? Number(message.internalDate) : NaN;
    const publishedAt = Number.isFinite(internalDate)
      ? internalDate
      : dateHeader;

    notices.push({
      id: message.id ?? messageRef.id,
      title: subject,
      sender,
      sourceName: sender,
      originalUrl: gmailMessageUrl(message.id ?? messageRef.id ?? ''),
      publishedAt,
    });
  }

  return notices;
}

async function fetchGmailMessagesViaWebhook(uid: string, email: string): Promise<GmailSyncNotice[]> {
  const webhookUrl = process.env.GMAIL_METADATA_SYNC_WEBHOOK_URL;
  if (!webhookUrl) {
    throw new Error('Gmail sync is not configured.');
  }

  const response = await axios.post(
    webhookUrl,
    { uid, email },
    { timeout: 15000 }
  );

  const payload = response.data as { items?: GmailSyncNotice[] };
  return Array.isArray(payload?.items) ? payload.items.slice(0, 80) : [];
}

async function persistGmailNotices(uid: string, email: string, notices: GmailSyncNotice[]): Promise<number> {
  const batch = db.batch();
  const settingsRef = db.collection('gmail_connection_settings').doc(uid);

  batch.set(
    settingsRef,
    {
      email,
      lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSyncStatus: 'SUCCESS',
      lastSyncError: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  for (const notice of notices) {
    const title = (notice.title ?? '').trim() || 'Campus Gmail Notice';
    const originalUrl = (notice.originalUrl ?? notice.messageUrl ?? '').trim() || 'https://mail.google.com/';
    const sender = (notice.sender ?? notice.sourceName ?? 'Campus Gmail').trim();
    const rawId = (notice.id ?? `${uid}:${title}:${sender}:${originalUrl}`).trim();
    const itemRef = db.collection('synced_gmail_notice_items')
      .doc(uid)
      .collection('items')
      .doc(toStableDocId(rawId));

    batch.set(
      itemRef,
      {
        title,
        email,
        sourceType: 'GMAIL_METADATA',
        sourceName: sender,
        sender,
        originalUrl,
        publishedAt: toPublishedTimestamp(notice.publishedAt),
        syncedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  await batch.commit();
  return notices.length;
}

async function resolveUserEmail(uid: string, fallbackEmail?: string): Promise<string> {
  const fallback = normalizeEmail(fallbackEmail);
  const userDoc = await db.collection('users').doc(uid).get();
  return normalizeEmail(userDoc.data()?.email) || fallback;
}

async function syncGmailMetadataForUser(uid: string, email: string): Promise<{ storedCount: number }> {
  const normalizedEmail = normalizeEmail(email);
  if (!isCampusEmail(normalizedEmail)) {
    throw new Error('Only @stud.kuet.ac.bd accounts can sync KUET mail.');
  }

  const notices = hasDomainWideDelegationConfig()
    ? await fetchGmailMessages(normalizedEmail)
    : await fetchGmailMessagesViaWebhook(uid, normalizedEmail);

  const storedCount = await persistGmailNotices(uid, normalizedEmail, notices);
  return { storedCount };
}

export const syncMyGmailMetadata = functions.https.onCall(async (_data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in to sync KUET mail.');
  }

  const settingsRef = db.collection('gmail_connection_settings').doc(uid);
  const settingsSnap = await settingsRef.get();
  if (settingsSnap.data()?.connected !== true) {
    throw new functions.https.HttpsError('failed-precondition', 'Turn on KUET mail integration first.');
  }

  const email = await resolveUserEmail(uid, context.auth?.token.email as string | undefined);
  if (!isCampusEmail(email)) {
    throw new functions.https.HttpsError('permission-denied', 'Only @stud.kuet.ac.bd accounts can sync KUET mail.');
  }

  try {
    await settingsRef.set(
      {
        email,
        lastManualSyncAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return await syncGmailMetadataForUser(uid, email);
  } catch (err) {
    const message = (err as Error).message;
    await settingsRef.set(
      {
        lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSyncStatus: 'FAILED',
        lastSyncError: message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    throw new functions.https.HttpsError('unavailable', message);
  }
});

export const syncConnectedGmailMetadata = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const connectedUsers = await db.collection('gmail_connection_settings')
      .where('connected', '==', true)
      .limit(200)
      .get();

    for (const userDoc of connectedUsers.docs) {
      const uid = userDoc.id;
      const settingsRef = db.collection('gmail_connection_settings').doc(uid);

      try {
        const email = await resolveUserEmail(uid, userDoc.data().email as string | undefined);
        await syncGmailMetadataForUser(uid, email);
      } catch (err) {
        const message = (err as Error).message;
        await settingsRef.set(
          {
            lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSyncStatus: 'FAILED',
            lastSyncError: message,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        await db.collection('admin_actions').add({
          action: 'GMAIL_SYNC_FAILED',
          targetUid: uid,
          message,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return null;
  });
