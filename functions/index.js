const crypto = require('node:crypto');

const { initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const MAX_MULTICAST = 500;

function shortText(value, maxLength) {
  return typeof value === 'string' ? value.trim().slice(0, maxLength) : '';
}

function eventNotificationId(type, sourceId, userId) {
  return crypto
    .createHash('sha256')
    .update(`${type}:${sourceId}:${userId}:${title}:${message}`)
    .digest('hex');
}

async function deliverToUser(user, { societyId, sourceId, type, title, message }) {
  const userId = user.id;
  if (!userId || user.role !== 'resident' || user.isActive !== true) return;

  const notificationId = eventNotificationId(type, sourceId, userId);
  const notificationRef = db.collection('notifications').doc(notificationId);
  if ((await notificationRef.get()).exists) return;

  const tokenSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('fcm_tokens')
    .get();
  const tokenDocs = tokenSnapshot.docs.filter((doc) => {
    const data = doc.data();
    return typeof data.fid === 'string' && data.fid.length > 0;
  });

  for (let start = 0; start < tokenDocs.length; start += MAX_MULTICAST) {
    const batch = tokenDocs.slice(start, start + MAX_MULTICAST);
    const response = await messaging.sendEachForMulticast({
      fids: batch.map((doc) => doc.data().fid),
      notification: {
        title: shortText(title, 100) || 'SocietyConnect update',
        body: shortText(message, 500),
      },
      data: {
        notificationId,
        type,
        sourceId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'society_updates',
          icon: 'ic_stat_societyconnect',
        },
      },
    });

    const staleTokens = [];
    response.responses.forEach((result, index) => {
      if (
        !result.success &&
        ['messaging/invalid-registration-token', 'messaging/registration-token-not-registered']
          .includes(result.error?.code)
      ) {
        staleTokens.push(batch[index].ref.delete());
      }
    });
    await Promise.all(staleTokens);
    const transientFailure = response.responses.find((result) =>
      !result.success &&
      !['messaging/invalid-registration-token', 'messaging/registration-token-not-registered']
        .includes(result.error?.code),
    );
    if (transientFailure) throw transientFailure.error;
  }

  await notificationRef.create({
    notificationId,
    userId,
    societyId,
    title: shortText(title, 100) || 'SocietyConnect update',
    message: shortText(message, 500),
    type,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function notifySocietyResidents(societyId, notification) {
  if (!societyId) return;
  const residents = await db
    .collection('users')
    .where('societyId', '==', societyId)
    .get();
  for (let start = 0; start < residents.docs.length; start += 25) {
    const batch = residents.docs.slice(start, start + 25);
    const results = await Promise.allSettled(
      batch.map((doc) =>
        deliverToUser({ id: doc.id, ...doc.data() }, {
          societyId,
          ...notification,
        }),
      ),
    );
    for (const result of results) {
      if (result.status === 'rejected') {
        logger.error('Could not deliver society notification', result.reason);
        throw result.reason;
      }
    }
  }
}

async function notifyResident(residentId, societyId, notification) {
  if (!residentId || !societyId) return;
  const residentSnapshot = await db.collection('users').doc(residentId).get();
  if (!residentSnapshot.exists || residentSnapshot.data().societyId !== societyId) return;
  await deliverToUser({ id: residentSnapshot.id, ...residentSnapshot.data() }, {
    societyId,
    ...notification,
  });
}

exports.onNoticePublished = onDocumentCreated({
  document: 'notices/{noticeId}',
  retry: true,
}, async (event) => {
  const notice = event.data?.data();
  if (!notice || notice.isActive === false) return;
  await notifySocietyResidents(notice.societyId, {
    sourceId: event.params.noticeId,
    type: 'notice',
    title: shortText(notice.title, 100) || 'New society notice',
    message: shortText(notice.body, 500),
  });
});

exports.onMaintenanceDueCreated = onDocumentCreated({
  document: 'maintenance/{maintenanceId}',
  retry: true,
}, async (event) => {
  const due = event.data?.data();
  if (!due || due.status !== 'Pending') return;
  const amount = Number(due.amount || 0);
  await notifyResident(due.residentId, due.societyId, {
    sourceId: event.params.maintenanceId,
    type: 'maintenance_due',
    title: 'New maintenance due',
    message: `A maintenance bill of ₹${amount} for ${due.month}/${due.year} is ready.`,
  });
});

exports.onComplaintStatusChanged = onDocumentUpdated({
  document: 'complaints/{complaintId}',
  retry: true,
}, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  await notifyResident(after.residentId, after.societyId, {
    sourceId: event.params.complaintId,
    type: 'complaint_status',
    title: 'Complaint status updated',
    message: `${shortText(after.title, 100) || 'Your complaint'} is now ${shortText(after.status, 40)}.`,
  });
});

exports.onEventPublished = onDocumentCreated({
  document: 'events/{eventId}',
  retry: true,
}, async (event) => {
  const societyEvent = event.data?.data();
  if (!societyEvent || societyEvent.isActive === false) return;
  await notifySocietyResidents(societyEvent.societyId, {
    sourceId: event.params.eventId,
    type: 'event',
    title: 'New society event',
    message: `${shortText(societyEvent.title, 100)}${societyEvent.date ? ` · ${societyEvent.date}` : ''}`,
  });
});

exports.onAmenityDecision = onDocumentUpdated({
  document: 'amenity_requests/{requestId}',
  retry: true,
}, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status) return;
  if (!['Approved', 'Rejected'].includes(after.status)) return;
  await notifyResident(after.residentId, after.societyId, {
    sourceId: event.params.requestId,
    type: 'amenity_decision',
    title: `Booking ${after.status.toLowerCase()}`,
    message: `${shortText(after.amenity, 100) || 'Your amenity request'} was ${after.status.toLowerCase()}.${after.adminResponse ? ` ${shortText(after.adminResponse, 300)}` : ''}`,
  });
});
