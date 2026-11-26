// Mock & Hybrid TicketRepository issuing signed QR tickets with Hive + Firestore sync.

import 'dart:async';
import 'dart:convert';

import '../../core/firebase/firestore_transit_service.dart';
import '../../core/maps/google_web_views.dart';
import '../models/ticket.dart';
import '../models/ticket_type.dart';
import '../repositories/ticket_repository.dart';
import '../seed/seed_tickets.dart';
import 'local_storage_helper.dart';

//**********************************************
// Signed QR & Hybrid Ticket Repository        *
//**********************************************

// Offline-capable [TicketRepository] persisting tickets in Hive and syncing
// authenticated rider tickets to Cloud Firestore `users/{uid}/tickets`.
class MockTicketRepository implements TicketRepository {
  // Creates a [MockTicketRepository] backed by Hive box [boxName].
  MockTicketRepository({
    String boxName = 'm_mobilnost_tickets',
    DateTime Function()? clock,
    FirestoreTransitService? firestoreService,
  })  : _store = LocalKeyValueStore(boxName),
        _clock = clock ?? DateTime.now,
        // ignore: prefer_initializing_formals
        _firestoreService = firestoreService {
    _controller = StreamController<(String, List<Ticket>)>.broadcast();
  }

  final LocalKeyValueStore _store;
  final DateTime Function() _clock;
  final FirestoreTransitService? _firestoreService;
  late final StreamController<(String, List<Ticket>)> _controller;
  final Set<String> _seedingUsers = <String>{};
  int _sequence = 0;

  bool get _shouldSyncRemote =>
      _firestoreService != null && !isFlutterTestEnvironment;

  static String _computeSignatureHex(String input) {
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    final seeded = '$input|marprom-m2-ticket-v2';
    for (var i = 0; i < seeded.length; i++) {
      final code = seeded.codeUnitAt(i);
      h1 = ((h1 ^ code) * 0x01000193) & 0x7fffffff;
      h2 = ((h2 + (code << 3)) * 0x45d9f3b) & 0x7fffffff;
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
  }

  // Encodes a tamper-evident signed JSON QR payload containing ticketId, uid,
  // ticket type, expiry timestamp, and verification signature hash.
  static String buildSignedQrPayload({
    required String ticketId,
    required String userId,
    required String ticketCode,
    required DateTime validUntil,
  }) {
    final expIso = validUntil.toUtc().toIso8601String();
    final sig = _computeSignatureHex('$ticketId|$userId|$ticketCode|$expIso');
    return jsonEncode(<String, dynamic>{
      'ticketId': ticketId,
      'uid': userId,
      'type': ticketCode,
      'validUntil': expIso,
      'sig': sig,
    });
  }

  // Verifies whether [rawPayload] carries a valid Marprom signed JSON ticket hash.
  static bool verifySignedQrPayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map<String, dynamic>) return false;
      final ticketId = decoded['ticketId']?.toString() ?? '';
      final uid = decoded['uid']?.toString() ?? '';
      final type = decoded['type']?.toString() ?? '';
      final expIso = decoded['validUntil']?.toString() ?? '';
      final sig = decoded['sig']?.toString() ?? '';
      if (ticketId.isEmpty || uid.isEmpty || type.isEmpty || expIso.isEmpty) {
        return false;
      }
      return _computeSignatureHex('$ticketId|$uid|$type|$expIso') == sig;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<TicketType>> getTicketTypes() async =>
      List<TicketType>.unmodifiable(seedTicketTypes);

  @override
  Future<TicketType?> getTicketTypeById(String typeId) async =>
      seedTicketTypesById[typeId];

  @override
  Future<List<Ticket>> getUserTickets(String userId) async {
    final entries = await _store.readAllEntries();
    final byId = <String, Ticket>{};
    for (final value in entries.values) {
      if (value is Map) {
        final ticket = Ticket.fromJson(value);
        if (ticket.userId == userId) {
          byId[ticket.id] = ticket;
        }
      }
    }

    if (_shouldSyncRemote && userId.isNotEmpty) {
      final remoteTickets = await _firestoreService!.getUserTickets(userId);
      for (final remote in remoteTickets) {
        final local = byId[remote.id];
        if (local == null ||
            (remote.validatedAt != null && local.validatedAt == null)) {
          byId[remote.id] = remote;
          await _store.write('ticket_${remote.id}', remote.toJson());
        }
      }
    }

    final tickets = byId.values.toList(growable: false);
    tickets.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return tickets;
  }

  // Issues one pre-activated 75-minute Demo Vozovnica when [userId] has zero
  // active tickets (skipped automatically inside Flutter tests).
  Future<Ticket?> ensureDemoTicketSeeded(String userId) async {
    if (userId.trim().isEmpty || _seedingUsers.contains(userId)) return null;
    _seedingUsers.add(userId);
    try {
      final existing = await getUserTickets(userId);
      final now = _clock();
      final activeIdx = existing.indexWhere(
        (t) => t.statusAt(now) == TicketStatus.active,
      );
      if (activeIdx != -1) return existing[activeIdx];

      final demoType = seedTicketTypesById['single'] ?? seedTicketTypes.first;
      return await purchaseTicket(
        type: demoType,
        userId: userId,
        validFrom: now,
      );
    } finally {
      _seedingUsers.remove(userId);
    }
  }

  // Migrates tickets owned by an anonymous demo user [fromUserId] to a signed-in
  // permanent account [toUserId] and syncs them to Firestore.
  Future<void> migrateTickets(String fromUserId, String toUserId) async {
    if (fromUserId.isEmpty || toUserId.isEmpty || fromUserId == toUserId) {
      return;
    }
    final entries = await _store.readAllEntries();
    var moved = false;
    for (final entry in entries.entries) {
      final val = entry.value;
      if (val is Map && val['userId'] == fromUserId) {
        final original = Ticket.fromJson(val);
        final durationMins = original.validUntil
            .difference(original.validFrom)
            .inMinutes
            .clamp(1, 525600);
        final reissued = Ticket.issue(
          id: original.id,
          ticketTypeId: original.ticketTypeId,
          ticketCode: original.ticketCode,
          titles: original.titles,
          priceEur: original.priceEur,
          zone: original.zone,
          durationMinutes: durationMins,
          purchasedAt: original.purchasedAt,
          validFrom: original.validFrom,
          qrPayload: buildSignedQrPayload(
            ticketId: original.id,
            userId: toUserId,
            ticketCode: original.ticketCode,
            validUntil: original.validUntil,
          ),
          driverFallbackCode: original.driverFallbackCode,
          userId: toUserId,
        );
        final updated = original.validatedAt != null
            ? reissued.copyWith(validatedAt: original.validatedAt)
            : reissued;
        await _store.write(entry.key, updated.toJson());
        if (_shouldSyncRemote) {
          unawaited(_firestoreService!.upsertUserTicket(toUserId, updated));
        }
        moved = true;
      }
    }
    if (moved) {
      await _emitForUser(fromUserId);
      await _emitForUser(toUserId);
    }
  }

  @override
  Stream<List<Ticket>> watchUserTickets(String userId) async* {
    yield await getUserTickets(userId);
    await for (final event in _controller.stream) {
      if (event.$1 == userId || event.$1 == '*') {
        yield event.$2.where((t) => t.userId == userId).toList(growable: false);
      }
    }
  }

  @override
  Future<Ticket> purchaseTicket({
    required TicketType type,
    required String userId,
    DateTime? validFrom,
  }) async {
    _sequence++;
    final now = _clock();
    final id = 'tkt_${now.microsecondsSinceEpoch}_$_sequence';
    final start = validFrom ?? now;
    final end = start.add(Duration(minutes: type.durationMinutes));

    final shortCode = ((now.millisecondsSinceEpoch + _sequence * 7919) % 10000)
        .toString()
        .padLeft(4, '0');
    final suffix = (_sequence % 10000).toString().padLeft(4, '0');

    final ticket = Ticket.issue(
      id: id,
      ticketTypeId: type.id,
      ticketCode: type.code,
      titles: type.titles,
      priceEur: type.priceEur,
      zone: type.zone,
      durationMinutes: type.durationMinutes,
      purchasedAt: now,
      validFrom: start,
      qrPayload: buildSignedQrPayload(
        ticketId: id,
        userId: userId,
        ticketCode: type.code,
        validUntil: end,
      ),
      driverFallbackCode: 'MB-$shortCode-$suffix',
      userId: userId,
    );

    await _store.write('ticket_$id', ticket.toJson());
    if (_shouldSyncRemote) {
      unawaited(_firestoreService!.upsertUserTicket(userId, ticket));
    }
    await _emitForUser(userId);
    return ticket;
  }

  @override
  Future<Ticket> validateTicket(String ticketId) async {
    final raw = await _store.read('ticket_$ticketId');
    if (raw is! Map) {
      throw StateError('Ticket $ticketId not found.');
    }
    final updated = Ticket.fromJson(raw).copyWith(validatedAt: _clock());
    await _store.write('ticket_$ticketId', updated.toJson());
    if (_shouldSyncRemote) {
      unawaited(_firestoreService!.upsertUserTicket(updated.userId, updated));
    }
    await _emitForUser(updated.userId);
    return updated;
  }

  @override
  Future<void> clearTicketsForUser(String userId) async {
    final entries = await _store.readAllEntries();
    for (final entry in entries.entries) {
      final val = entry.value;
      if (val is Map && val['userId'] == userId) {
        await _store.delete(entry.key);
      }
    }
    await _emitForUser(userId);
  }

  @override
  Future<void> clearAllTickets() async {
    await _store.clear();
    if (!_controller.isClosed) {
      _controller.add(('*', const []));
    }
  }

  Future<void> _emitForUser(String userId) async {
    if (_controller.isClosed) return;
    final list = await getUserTickets(userId);
    if (!_controller.isClosed) {
      _controller.add((userId, list));
    }
  }

  @override
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
