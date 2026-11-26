import 'package:cloud_firestore/cloud_firestore.dart';

class SocietyDataException implements Exception {
  const SocietyDataException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.residents,
    required this.flats,
    required this.occupiedFlats,
    required this.vacantFlats,
    required this.paidMaintenanceRecords,
    required this.pendingMaintenanceRecords,
    required this.pendingMaintenanceAmount,
    required this.openComplaints,
    required this.resolvedComplaints,
    required this.upcomingEvents,
    required this.pendingAmenityRequests,
  });

  final int residents;
  final int flats;
  final int occupiedFlats;
  final int vacantFlats;
  final int paidMaintenanceRecords;
  final int pendingMaintenanceRecords;
  final num pendingMaintenanceAmount;
  final int openComplaints;
  final int resolvedComplaints;
  final int upcomingEvents;
  final int pendingAmenityRequests;
}

class MonthlyDuesGenerationResult {
  const MonthlyDuesGenerationResult({
    required this.created,
    required this.alreadyGenerated,
    required this.unassignedFlats,
  });

  final int created;
  final int alreadyGenerated;
  final List<String> unassignedFlats;
}

enum _MonthlyDueOutcome { created, alreadyGenerated, unassigned }

/// Returns the shared 30-minute reservation keys for an amenity interval.
List<String> amenitySlotKeys(String amenity, DateTime startAt, DateTime endAt) {
  final day =
      '${startAt.year.toString().padLeft(4, '0')}${startAt.month.toString().padLeft(2, '0')}${startAt.day.toString().padLeft(2, '0')}';
  final safeAmenity =
      amenity.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final slots = <String>[];
  for (var time = startAt;
      time.isBefore(endAt);
      time = time.add(const Duration(minutes: 30))) {
    slots.add(
        '${safeAmenity}_${day}_${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}');
  }
  return slots;
}

class SocietyRepository {
  SocietyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Map<String, dynamic>>> watchRecentActivity(String societyId) =>
      _firestore
          .collection('activity_logs')
          .where('societyId', isEqualTo: societyId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList());

  Future<AdminDashboardMetrics> loadAdminDashboardMetrics(
      String societyId) async {
    Future<int> count(Query<Map<String, dynamic>> query) async =>
        (await query.count().get()).count ?? 0;

    final residents = count(_firestore
        .collection('users')
        .where('societyId', isEqualTo: societyId)
        .where('role', isEqualTo: 'resident'));
    final flats = count(_firestore
        .collection('flats')
        .where('societyId', isEqualTo: societyId));
    final occupied = count(_firestore
        .collection('flats')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'Occupied'));
    final vacant = count(_firestore
        .collection('flats')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'Vacant'));
    final paid = count(_firestore
        .collection('maintenance')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'Paid'));
    final pendingQuery = _firestore
        .collection('maintenance')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'Pending');
    final pending = pendingQuery.get();
    final openPending = count(_firestore
        .collection('complaints')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'Pending'));
    final openProgress = count(_firestore
        .collection('complaints')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'In Progress'));
    final resolved = count(_firestore
        .collection('complaints')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'Resolved'));
    final events = count(_firestore
        .collection('events')
        .where('societyId', isEqualTo: societyId)
        .where('isActive', isEqualTo: true)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.now()));
    final amenityRequests = count(_firestore
        .collection('amenity_requests')
        .where('societyId', isEqualTo: societyId)
        .where('status', isEqualTo: 'Pending'));

    final results = await Future.wait([
      residents,
      flats,
      occupied,
      vacant,
      paid,
      pending.then((snapshot) => snapshot.docs.length),
      openPending,
      openProgress,
      resolved,
      events,
      amenityRequests,
    ]);
    final pendingRecords = await pending;
    final pendingAmount = pendingRecords.docs.fold<num>(
      0,
      (total, record) => total + ((record.data()['amount'] as num?) ?? 0),
    );
    return AdminDashboardMetrics(
      residents: results[0],
      flats: results[1],
      occupiedFlats: results[2],
      vacantFlats: results[3],
      paidMaintenanceRecords: results[4],
      pendingMaintenanceRecords: results[5],
      pendingMaintenanceAmount: pendingAmount,
      openComplaints: results[6] + results[7],
      resolvedComplaints: results[8],
      upcomingEvents: results[9],
      pendingAmenityRequests: results[10],
    );
  }

  Stream<List<Map<String, dynamic>>> watchFlats(String societyId) => _firestore
      .collection('flats')
      .where('societyId', isEqualTo: societyId)
      .limit(200)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
            ..sort((a, b) => (a['flatNumber'] as String? ?? '')
                .compareTo(b['flatNumber'] as String? ?? '')));

  Stream<List<Map<String, dynamic>>> watchResidents(String societyId) =>
      _firestore
          .collection('users')
          .where('societyId', isEqualTo: societyId)
          .where('role', isEqualTo: 'resident')
          .limit(200)
          .snapshots()
          .map((snapshot) {
        final residents =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        residents.sort((a, b) => (a['fullName'] as String? ?? '')
            .compareTo(b['fullName'] as String? ?? ''));
        return residents;
      });

  Future<List<Map<String, dynamic>>> listVacantFlats(String societyId) async {
    try {
      final snapshot = await _firestore
          .collection('flats')
          .where('societyId', isEqualTo: societyId)
          .where('status', isEqualTo: 'Vacant')
          .limit(200)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  /// Returns only currently vacant flats for resident registration.
  Future<List<Map<String, dynamic>>> listRegistrationFlats(
      String societyId) async {
    final normalizedId = societyId.trim().toUpperCase();
    return listVacantFlats(normalizedId);
  }

  Future<void> setResidentActive({
    required String residentId,
    required String societyId,
    required String adminId,
    required bool isActive,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(residentId), {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('activity_logs').doc(), {
        'societyId': societyId,
        'userId': adminId,
        'action': isActive ? 'resident_activated' : 'resident_deactivated',
        'description':
            '${isActive ? 'Activated' : 'Deactivated'} resident account $residentId.',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> assignResidentFlat({
    required String societyId,
    required String residentId,
    required String flatId,
    required String adminId,
  }) async {
    try {
      final residentRef = _firestore.collection('users').doc(residentId);
      final flatRef = _firestore.collection('flats').doc(flatId);
      await _firestore.runTransaction((transaction) async {
        final resident = await transaction.get(residentRef);
        final flat = await transaction.get(flatRef);
        if (!resident.exists ||
            resident.data()?['role'] != 'resident' ||
            resident.data()?['societyId'] != societyId) {
          throw const SocietyDataException(
              'Resident is not part of this society.');
        }
        if (!flat.exists ||
            flat.data()?['societyId'] != societyId ||
            flat.data()?['status'] != 'Vacant') {
          throw const SocietyDataException(
              'That flat is no longer vacant. Refresh and choose another.');
        }
        final oldFlatId = resident.data()?['flatId'] as String?;
        DocumentSnapshot<Map<String, dynamic>>? oldFlat;
        if (oldFlatId != null && oldFlatId != flatId) {
          oldFlat = await transaction
              .get(_firestore.collection('flats').doc(oldFlatId));
        }
        if (oldFlat != null &&
            oldFlat.exists &&
            oldFlat.data()?['residentId'] == residentId) {
          transaction.update(oldFlat.reference, {
            'residentId': null,
            'status': 'Vacant',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        transaction.update(flatRef, {
          'residentId': residentId,
          'status': 'Occupied',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(residentRef, {
          'flatId': flatId,
          'flatNumber': flat.data()?['flatNumber'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_firestore.collection('activity_logs').doc(), {
          'societyId': societyId,
          'userId': adminId,
          'action': 'flat_assigned',
          'description':
              'Assigned flat ${flat.data()?['flatNumber']} to ${resident.data()?['fullName']}.',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> unassignResidentFlat({
    required String societyId,
    required String residentId,
    required String adminId,
  }) async {
    try {
      final residentRef = _firestore.collection('users').doc(residentId);
      await _firestore.runTransaction((transaction) async {
        final resident = await transaction.get(residentRef);
        if (!resident.exists || resident.data()?['societyId'] != societyId) {
          throw const SocietyDataException(
              'Resident is not part of this society.');
        }
        final flatId = resident.data()?['flatId'] as String?;
        if (flatId == null) return;
        final flatRef = _firestore.collection('flats').doc(flatId);
        final flat = await transaction.get(flatRef);
        if (flat.exists && flat.data()?['residentId'] == residentId) {
          transaction.update(flatRef, {
            'residentId': null,
            'status': 'Vacant',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        transaction.update(residentRef, {
          'flatId': null,
          'flatNumber': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_firestore.collection('activity_logs').doc(), {
          'societyId': societyId,
          'userId': adminId,
          'action': 'flat_unassigned',
          'description':
              'Unassigned flat ${flat.data()?['flatNumber']} from ${resident.data()?['fullName']}.',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> createFlat({
    required String societyId,
    required String flatNumber,
    required String block,
    required String floor,
  }) async {
    final normalized = flatNumber.trim().toUpperCase();
    final safeId = normalized.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
    final ref = _firestore.collection('flats').doc('${societyId}_$safeId');
    try {
      await _firestore.runTransaction((transaction) async {
        if ((await transaction.get(ref)).exists) {
          throw const SocietyDataException(
              'A flat with that number already exists.');
        }
        transaction.set(ref, {
          'flatId': ref.id,
          'societyId': societyId,
          'flatNumber': normalized,
          'block': block.trim(),
          'floor': floor.trim(),
          'residentId': null,
          'status': 'Vacant',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Stream<List<Map<String, dynamic>>> watchNotices(String societyId) =>
      _firestore
          .collection('notices')
          .where('societyId', isEqualTo: societyId)
          .limit(100)
          .snapshots()
          .map((snapshot) {
        final notices =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        notices.removeWhere((notice) => notice['isActive'] == false);
        notices.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
        return notices;
      });

  Future<void> createNotice({
    required String societyId,
    required String title,
    required String body,
    required String category,
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();
      final noticeRef = _firestore.collection('notices').doc();
      batch.set(noticeRef, {
        'societyId': societyId,
        'title': title.trim(),
        'body': body.trim(),
        'category': category,
        'createdBy': userId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('activity_logs').doc(), {
        'societyId': societyId,
        'userId': userId,
        'action': 'notice_published',
        'description': 'Published notice "${title.trim()}".',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> deactivateNotice({
    required String noticeId,
    required String societyId,
    required String adminId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('notices').doc(noticeId), {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('activity_logs').doc(), {
        'societyId': societyId,
        'userId': adminId,
        'action': 'notice_deactivated',
        'description': 'Removed notice $noticeId.',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Stream<List<Map<String, dynamic>>> watchEvents(String societyId) => _firestore
          .collection('events')
          .where('societyId', isEqualTo: societyId)
          .limit(100)
          .snapshots()
          .map((snapshot) {
        final events = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .where((event) => event['isActive'] != false)
            .toList();
        events.sort((a, b) => _eventDate(a).compareTo(_eventDate(b)));
        return events;
      });

  Future<void> saveEvent({
    String? eventId,
    required String societyId,
    required String adminId,
    required String title,
    required String description,
    required String location,
    required String category,
    required DateTime startAt,
  }) async {
    try {
      final batch = _firestore.batch();
      final eventRef = eventId == null
          ? _firestore.collection('events').doc()
          : _firestore.collection('events').doc(eventId);
      final isNew = eventId == null;
      final data = <String, Object?>{
        'societyId': societyId,
        'title': title.trim(),
        'description': description.trim(),
        'location': location.trim(),
        'category': category,
        'date':
            '${startAt.year.toString().padLeft(4, '0')}-${startAt.month.toString().padLeft(2, '0')}-${startAt.day.toString().padLeft(2, '0')}',
        'startTime':
            '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}',
        'startAt': Timestamp.fromDate(startAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      if (isNew) {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = adminId;
        batch.set(eventRef, data);
      } else {
        batch.update(eventRef, data);
      }
      batch.set(_firestore.collection('activity_logs').doc(), {
        'societyId': societyId,
        'userId': adminId,
        'action': isNew ? 'event_created' : 'event_updated',
        'description':
            '${isNew ? 'Created' : 'Updated'} event "${title.trim()}".',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> deactivateEvent({
    required String eventId,
    required String societyId,
    required String adminId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('events').doc(eventId), {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('activity_logs').doc(), {
        'societyId': societyId,
        'userId': adminId,
        'action': 'event_deactivated',
        'description': 'Removed event $eventId.',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Stream<List<Map<String, dynamic>>> watchAmenityRequests({
    required String societyId,
    required bool isAdmin,
    required String userId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('amenity_requests')
        .where('societyId', isEqualTo: societyId);
    if (!isAdmin) query = query.where('residentId', isEqualTo: userId);
    return query.limit(100).snapshots().map((snapshot) {
      final requests =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      requests.sort((a, b) => _requestDate(b).compareTo(_requestDate(a)));
      return requests;
    });
  }

  Future<void> createAmenityRequest({
    required String societyId,
    required String residentId,
    required String residentName,
    required String flatNumber,
    required String amenity,
    required DateTime startAt,
    required DateTime endAt,
    required String purpose,
    required String notes,
  }) async {
    if (startAt.minute % 30 != 0 ||
        endAt.minute % 30 != 0 ||
        startAt.second != 0 ||
        endAt.second != 0 ||
        !startAt.isBefore(endAt)) {
      throw const SocietyDataException(
          'Choose a valid time range using 30-minute intervals.');
    }
    final duration = endAt.difference(startAt).inMinutes;
    if (duration < 30 || duration > 12 * 60) {
      throw const SocietyDataException(
          'Bookings must be between 30 minutes and 12 hours.');
    }
    if (startAt.isBefore(DateTime.now())) {
      throw const SocietyDataException('Choose a future booking time.');
    }

    final requestRef = _firestore.collection('amenity_requests').doc();
    final slots = amenitySlotKeys(amenity, startAt, endAt)
        .map((key) => _firestore
            .collection('societies')
            .doc(societyId)
            .collection('amenity_slots')
            .doc(key))
        .toList();
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshots = await Future.wait(slots.map(transaction.get));
        if (snapshots.any((slot) => slot.exists)) {
          throw const SocietyDataException(
              'That amenity time overlaps another request. Choose a different time.');
        }
        transaction.set(requestRef, {
          'requestId': requestRef.id,
          'societyId': societyId,
          'residentId': residentId,
          'residentName': residentName,
          'flatNumber': flatNumber,
          'amenity': amenity,
          'date':
              '${startAt.year.toString().padLeft(4, '0')}-${startAt.month.toString().padLeft(2, '0')}-${startAt.day.toString().padLeft(2, '0')}',
          'startAt': Timestamp.fromDate(startAt),
          'endAt': Timestamp.fromDate(endAt),
          'purpose': purpose.trim(),
          'notes': notes.trim(),
          'status': 'Pending',
          'adminResponse': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        for (final slot in slots) {
          transaction.set(slot, {
            'societyId': societyId,
            'requestId': requestRef.id,
            'residentId': residentId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> updateAmenityRequest({
    required String requestId,
    required String societyId,
    required String adminId,
    required String status,
    required String response,
  }) async {
    const allowedStatuses = {'Pending', 'Approved', 'Rejected', 'Completed'};
    if (!allowedStatuses.contains(status)) {
      throw const SocietyDataException('Choose a valid request status.');
    }
    final requestRef = _firestore.collection('amenity_requests').doc(requestId);
    try {
      final request = await requestRef.get();
      if (!request.exists || request.data()?['societyId'] != societyId) {
        throw const SocietyDataException('This booking request was not found.');
      }
      final batch = _firestore.batch();
      batch.update(requestRef, {
        'status': status,
        'adminResponse': response.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (status == 'Rejected' || status == 'Completed') {
        final requestData = request.data()!;
        final start = (requestData['startAt'] as Timestamp).toDate();
        final end = (requestData['endAt'] as Timestamp).toDate();
        for (final key
            in amenitySlotKeys(requestData['amenity'] as String, start, end)) {
          batch.delete(_firestore
              .collection('societies')
              .doc(societyId)
              .collection('amenity_slots')
              .doc(key));
        }
      }
      batch.set(_firestore.collection('activity_logs').doc(), {
        'societyId': societyId,
        'userId': adminId,
        'action': 'amenity_request_updated',
        'description': 'Updated booking $requestId to $status.',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Stream<List<Map<String, dynamic>>> watchComplaints({
    required String societyId,
    required bool isAdmin,
    required String userId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('complaints')
        .where('societyId', isEqualTo: societyId);
    if (!isAdmin) query = query.where('residentId', isEqualTo: userId);
    return query.limit(100).snapshots().map((snapshot) {
      final complaints =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      complaints.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
      return complaints;
    });
  }

  Future<void> createComplaint({
    required String societyId,
    required String userId,
    required String flatNumber,
    required String title,
    required String description,
    required String category,
  }) async {
    try {
      await _firestore.collection('complaints').add({
        'societyId': societyId,
        'residentId': userId,
        'flatNumber': flatNumber,
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'status': 'Pending',
        'adminResponse': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> updateComplaint({
    required String complaintId,
    required String societyId,
    required String adminId,
    required String status,
    required String adminResponse,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('complaints').doc(complaintId), {
        'status': status,
        'adminResponse': adminResponse.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('activity_logs').doc(), {
        'societyId': societyId,
        'userId': adminId,
        'action': 'complaint_status_changed',
        'description': 'Updated complaint $complaintId to $status.',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Stream<List<Map<String, dynamic>>> watchMaintenance(
          String societyId, String residentId) =>
      _firestore
          .collection('maintenance')
          .where('societyId', isEqualTo: societyId)
          .where('residentId', isEqualTo: residentId)
          .limit(100)
          .snapshots()
          .map((snapshot) {
        final entries =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        entries.sort((a, b) {
          final aYear = a['year'] as int? ?? 0;
          final bYear = b['year'] as int? ?? 0;
          final aMonth = a['month'] as int? ?? 0;
          final bMonth = b['month'] as int? ?? 0;
          final yearOrder = bYear.compareTo(aYear);
          return yearOrder != 0 ? yearOrder : bMonth.compareTo(aMonth);
        });
        return entries;
      });

  Stream<List<Map<String, dynamic>>> watchSocietyMaintenance(
          String societyId) =>
      _firestore
          .collection('maintenance')
          .where('societyId', isEqualTo: societyId)
          .limit(300)
          .snapshots()
          .map((snapshot) {
        final entries =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        entries.sort((a, b) {
          final yearOrder =
              (b['year'] as int? ?? 0).compareTo(a['year'] as int? ?? 0);
          if (yearOrder != 0) return yearOrder;
          final monthOrder =
              (b['month'] as int? ?? 0).compareTo(a['month'] as int? ?? 0);
          if (monthOrder != 0) return monthOrder;
          return (a['flatNumber'] as String? ?? '')
              .compareTo(b['flatNumber'] as String? ?? '');
        });
        return entries;
      });

  Future<MonthlyDuesGenerationResult> generateMonthlyDues({
    required String societyId,
    required int month,
    required int year,
    required num amount,
    required String adminId,
  }) async {
    try {
      final residentsByFlatId = <String, String>{};
      var residentsQuery = _firestore
          .collection('users')
          .where('societyId', isEqualTo: societyId)
          .where('role', isEqualTo: 'resident')
          .orderBy(FieldPath.documentId)
          .limit(300);
      while (true) {
        final residentsPage = await residentsQuery.get();
        for (final resident in residentsPage.docs) {
          final flatId = resident.data()['flatId'];
          if (flatId is String && flatId.isNotEmpty) {
            residentsByFlatId.putIfAbsent(flatId, () => resident.id);
          }
        }
        if (residentsPage.docs.length < 300) break;
        residentsQuery = residentsQuery.startAfterDocument(
          residentsPage.docs.last,
        );
      }

      var flatsQuery = _firestore
          .collection('flats')
          .where('societyId', isEqualTo: societyId)
          .where('status', isEqualTo: 'Occupied')
          .orderBy(FieldPath.documentId)
          .limit(300);
      var created = 0;
      var alreadyGenerated = 0;
      final unassignedFlats = <String>[];
      while (true) {
        final page = await flatsQuery.get();
        if (page.docs.isEmpty) break;
        for (var start = 0; start < page.docs.length; start += 10) {
          final group = page.docs.skip(start).take(10);
          final results = await Future.wait(group.map((flat) async {
            final maintenanceId = '${societyId}_${flat.id}_${year}_$month';
            final maintenanceRef =
                _firestore.collection('maintenance').doc(maintenanceId);
            return _firestore.runTransaction((transaction) async {
              final existing = await transaction.get(maintenanceRef);
              if (existing.exists) return _MonthlyDueOutcome.alreadyGenerated;
              final currentFlat = await transaction.get(flat.reference);
              if (!currentFlat.exists) return _MonthlyDueOutcome.unassigned;
              final data = currentFlat.data()!;
              if (data['status'] != 'Occupied' ||
                  data['societyId'] != societyId) {
                return _MonthlyDueOutcome.unassigned;
              }
              final flatResidentId =
                  (data['residentId'] as String?)?.trim() ?? '';
              final residentId = flatResidentId.isNotEmpty
                  ? flatResidentId
                  : residentsByFlatId[flat.id];
              if (residentId == null || residentId.isEmpty) {
                return _MonthlyDueOutcome.unassigned;
              }
              final residentRef =
                  _firestore.collection('users').doc(residentId);
              final resident = await transaction.get(residentRef);
              final residentData = resident.data();
              if (!resident.exists ||
                  residentData?['role'] != 'resident' ||
                  residentData?['societyId'] != societyId ||
                  (flatResidentId.isEmpty &&
                      residentData?['flatId'] != flat.id)) {
                return _MonthlyDueOutcome.unassigned;
              }
              if (flatResidentId.isEmpty) {
                transaction.update(flat.reference, {
                  'residentId': residentId,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              transaction.set(maintenanceRef, {
                'maintenanceId': maintenanceId,
                'societyId': societyId,
                'residentId': residentId,
                'flatId': flat.id,
                'flatNumber': data['flatNumber'],
                'month': month,
                'year': year,
                'amount': amount,
                'status': 'Pending',
                'paymentDate': null,
                'paymentMethod': null,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              return _MonthlyDueOutcome.created;
            });
          }));
          for (var index = 0; index < results.length; index++) {
            switch (results[index]) {
              case _MonthlyDueOutcome.created:
                created++;
                break;
              case _MonthlyDueOutcome.alreadyGenerated:
                alreadyGenerated++;
                break;
              case _MonthlyDueOutcome.unassigned:
                final flatNumber = group.elementAt(index).data()['flatNumber'];
                unassignedFlats.add(
                    flatNumber is String && flatNumber.isNotEmpty
                        ? flatNumber
                        : group.elementAt(index).id);
                break;
            }
          }
        }
        flatsQuery = flatsQuery.startAfterDocument(page.docs.last);
      }
      if (created > 0) {
        await _firestore.collection('activity_logs').add({
          'societyId': societyId,
          'userId': adminId,
          'action': 'maintenance_dues_generated',
          'description':
              'Generated $month/$year maintenance dues for $created flats.',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return MonthlyDuesGenerationResult(
        created: created,
        alreadyGenerated: alreadyGenerated,
        unassignedFlats: unassignedFlats,
      );
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  Future<void> recordMaintenancePayment({
    required String maintenanceId,
    required String societyId,
    required String adminId,
    required bool paid,
    required String paymentMethod,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('maintenance').doc(maintenanceId), {
        'status': paid ? 'Paid' : 'Pending',
        'paymentDate': paid ? FieldValue.serverTimestamp() : null,
        'paymentMethod': paid ? paymentMethod : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final activityRef = _firestore.collection('activity_logs').doc();
      batch.set(activityRef, {
        'societyId': societyId,
        'userId': adminId,
        'action': 'maintenance_status_updated',
        'description':
            'Marked maintenance $maintenanceId as ${paid ? 'Paid' : 'Pending'}.',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw SocietyDataException(_firestoreError(error));
    }
  }

  DateTime _dateOf(Map<String, dynamic> data) {
    final value = data['createdAt'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _eventDate(Map<String, dynamic> data) {
    final value = data['startAt'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _requestDate(Map<String, dynamic> data) {
    final value = data['startAt'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _firestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to make this change. Check that the Firestore rules are deployed.';
      case 'unavailable':
        return 'Could not reach society data. Check your connection and retry.';
      default:
        return 'The change could not be saved. Please try again.';
    }
  }
}

final societyRepository = SocietyRepository();
