import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:field_notes/core/constants.dart';
import 'package:field_notes/data/local/app_database.dart';
import 'package:field_notes/data/remote/field_notes_api.dart';
import 'package:field_notes/data/repositories/customer_repository.dart';
import 'package:field_notes/data/repositories/note_repository.dart';
import 'package:field_notes/features/customers/customer_bloc.dart';
import 'package:field_notes/features/notes/note_bloc.dart';
import 'package:field_notes/sync/local_change_bus.dart';
import 'package:field_notes/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('search matches title, description, site, and customer and combines filters', () async {
    final now = DateTime.utc(2026, 10, 7, 12);
    await database.saveCustomer(
      CustomerRow(
        id: 'c1',
        userId: 1,
        name: 'Acme Water',
        contactInfo: null,
        createdAt: now,
        updatedAt: now,
        syncState: SyncStates.synced,
      ),
    );
    await database.saveSite(
      SiteRow(
        id: 's1',
        userId: 1,
        customerId: 'c1',
        siteName: 'North Plant',
        address: 'Dock',
        createdAt: now,
        updatedAt: now,
        syncState: SyncStates.synced,
      ),
    );
    await database.saveNote(
      FieldNoteRow(
        id: 'n1',
        userId: 1,
        siteId: 's1',
        title: 'Leak',
        description: 'Valve dripping',
        latitude: null,
        longitude: null,
        notedAt: now,
        status: 'OPEN',
        createdAt: now,
        updatedAt: now,
        syncState: SyncStates.synced,
        localPhotoPath: null,
        photoSyncState: PhotoSync.none,
        remoteHasPhoto: false,
      ),
    );

    final repo = NoteRepository(database, LocalChangeBus(), _UnusedRemote());
    expect(
      (await repo.watch(userId: 1, query: 'acme').first).single.title,
      'Leak',
    );
    expect((await repo.watch(userId: 1, query: 'north').first).length, 1);
    expect((await repo.watch(userId: 1, query: 'valve').first).length, 1);
    expect((await repo.watch(userId: 1, query: 'leak').first).length, 1);
    expect(await repo.watch(userId: 1, query: 'missing').first, isEmpty);
    expect(await repo.watch(userId: 1, status: 'COMPLETED').first, isEmpty);
    expect(
      (await repo
              .watch(userId: 1, status: 'OPEN', siteId: 's1', query: 'plant')
              .first)
          .length,
      1,
    );
  });

  test(
    'push marks applied rows synced and leaves failed rows pending',
    () async {
      final now = DateTime.utc(2026, 10, 1);
      await database.saveCustomer(
        CustomerRow(
          id: 'c1',
          userId: 7,
          name: 'Local',
          contactInfo: null,
          createdAt: now,
          updatedAt: now,
          syncState: SyncStates.pendingUpsert,
        ),
      );
      final remote = _FakeRemote(failIds: {'c1'});
      final service = SyncService(
        remote: remote,
        database: database,
        userId: () async => 7,
      );
      await expectLater(service.sync(), throwsA(isA<SyncException>()));
      final row = await database.anyCustomer(7, 'c1');
      expect(row!.syncState, SyncStates.pendingUpsert);
      expect(row.name, 'Local');
      expect(remote.pushes.single.customers.single['name'], 'Local');

      remote.failIds.clear();
      await service.sync();
      expect(
        (await database.anyCustomer(7, 'c1'))!.syncState,
        SyncStates.synced,
      );
      expect(remote.pushes, hasLength(2));
    },
  );

  test(
    'local rows, pending pushes, and pull cursors remain isolated by user',
    () async {
      final now = DateTime.utc(2026, 10, 1);
      await database.saveCustomer(
        CustomerRow(
          id: 'user-a-customer',
          userId: 1,
          name: 'User A only',
          contactInfo: null,
          createdAt: now,
          updatedAt: now,
          syncState: SyncStates.pendingUpsert,
        ),
      );
      await database.setLastSyncAt(1, DateTime.utc(2026, 10, 6));

      final remoteB = _FakeRemote();
      await SyncService(
        remote: remoteB,
        database: database,
        userId: () async => 2,
      ).sync();

      expect(await database.watchCustomers(2).first, isEmpty);
      expect(remoteB.pushes, isEmpty);
      expect(remoteB.pullSince, [DateTime.utc(1970)]);
      expect(await database.lastSyncAt(1), DateTime.utc(2026, 10, 6));
      expect(await database.lastSyncAt(2), DateTime.utc(2026, 10, 7, 1));
      expect(await database.anyCustomer(2, 'user-a-customer'), isNull);
      expect(
        (await database.anyCustomer(1, 'user-a-customer'))!.syncState,
        SyncStates.pendingUpsert,
      );

      expect(await database.markDeletedCustomer(2, 'user-a-customer'), 0);
      expect(
        (await database.anyCustomer(1, 'user-a-customer'))!.deletedAt,
        isNull,
      );
      await expectLater(
        database.saveCustomer(
          CustomerRow(
            id: 'user-a-customer',
            userId: 2,
            name: 'Attempted overwrite',
            contactInfo: null,
            createdAt: now,
            updatedAt: now,
            syncState: SyncStates.pendingUpsert,
          ),
        ),
        throwsStateError,
      );
      expect(
        (await database.anyCustomer(1, 'user-a-customer'))!.name,
        'User A only',
      );
    },
  );

  test('legacy global last_sync_at cursor is ignored', () async {
    await database
        .into(database.syncMeta)
        .insert(
          SyncMetaCompanion.insert(
            key: 'last_sync_at',
            value: DateTime.utc(2020).toIso8601String(),
          ),
        );
    expect(await database.lastSyncAt(1), isNull);
    expect(await database.lastSyncAt(2), isNull);
  });

  test(
    'pull restores rows and does not overwrite a pending local edit',
    () async {
      final created = DateTime.utc(2026, 10, 1);
      await database.saveCustomer(
        CustomerRow(
          id: 'pending',
          userId: 7,
          name: 'Local edit',
          contactInfo: null,
          createdAt: created,
          updatedAt: created,
          syncState: SyncStates.pendingUpsert,
        ),
      );
      final remote = _FakeRemote(
        nextPull: SyncPullResult(
          serverTime: DateTime.utc(2026, 10, 7, 8),
          customers: [
            RemoteCustomer(
              id: 'pending',
              name: 'Server',
              contactInfo: null,
              createdAt: created,
              updatedAt: DateTime.utc(2026, 10, 7),
              deletedAt: null,
            ),
            RemoteCustomer(
              id: 'remote',
              name: 'Restored',
              contactInfo: 'desk',
              createdAt: created,
              updatedAt: DateTime.utc(2026, 10, 7),
              deletedAt: null,
            ),
          ],
          sites: const [],
          notes: const [],
        ),
      );
      remote.failIds.add('pending');
      final service = SyncService(
        remote: remote,
        database: database,
        userId: () async => 7,
      );
      await expectLater(service.sync(), throwsA(isA<SyncException>()));

      final pending = await database.anyCustomer(7, 'pending');
      expect(pending!.name, 'Local edit');
      expect(pending.syncState, SyncStates.pendingUpsert);
      final restored = await database.anyCustomer(7, 'remote');
      expect(restored!.name, 'Restored');
      expect(restored.syncState, SyncStates.synced);
      expect(await database.lastSyncAt(7), DateTime.utc(2026, 10, 7, 8));
    },
  );

  test(
    'customer session stop clears cached rows before another account watches',
    () async {
      final now = DateTime.utc(2026, 10, 1);
      await database.saveCustomer(
        CustomerRow(
          id: 'a-only',
          userId: 1,
          name: 'Private A',
          contactInfo: null,
          createdAt: now,
          updatedAt: now,
          syncState: SyncStates.synced,
        ),
      );
      final bloc = CustomerBloc(CustomerRepository(database, LocalChangeBus()));
      addTearDown(bloc.close);

      final userALoaded = bloc.stream.firstWhere(
        (state) => !state.loading && state.customers.isNotEmpty,
      );
      bloc.add(const CustomersWatch(1));
      expect((await userALoaded).customers.single.name, 'Private A');

      final stopped = bloc.stream.firstWhere(
        (state) => !state.loading && state.customers.isEmpty,
      );
      bloc.add(const CustomersStopped());
      expect((await stopped).customers, isEmpty);

      final userBLoaded = bloc.stream.firstWhere((state) => !state.loading);
      bloc.add(const CustomersWatch(2));
      expect((await userBLoaded).customers, isEmpty);
    },
  );

  test('queued syncs keep each payload bound to its account token', () async {
    final now = DateTime.utc(2026, 10, 1);
    for (final userId in [1, 2]) {
      await database.saveCustomer(
        CustomerRow(
          id: 'customer-$userId',
          userId: userId,
          name: 'User $userId',
          contactInfo: null,
          createdAt: now,
          updatedAt: now,
          syncState: SyncStates.pendingUpsert,
        ),
      );
    }
    final remote = _FakeRemote(blockFirstPush: true);
    var token = _tokenFor(1);
    final service = SyncService(
      remote: remote,
      database: database,
      userId: () async => null,
      accessToken: () async => token,
    );

    final first = service.sync();
    await remote.firstPushStarted.future;
    token = _tokenFor(2);
    final second = service.sync();
    remote.releaseFirstPush.complete();
    await Future.wait([first, second]);

    expect(remote.pushAccessTokens, [_tokenFor(1), _tokenFor(2)]);
    expect(remote.pushes[0].customers.single['id'], 'customer-1');
    expect(remote.pushes[1].customers.single['id'], 'customer-2');
  });

  test(
    'applied delete is removed locally and a repeated push is safe',
    () async {
      final now = DateTime.utc(2026, 10, 2);
      await database.saveCustomer(
        CustomerRow(
          id: 'c1',
          userId: 7,
          name: 'Gone',
          contactInfo: null,
          createdAt: now,
          updatedAt: now,
          syncState: SyncStates.pendingDelete,
          deletedAt: now,
        ),
      );
      final remote = _FakeRemote();
      final service = SyncService(
        remote: remote,
        database: database,
        userId: () async => 7,
      );
      await service.sync();
      expect(await database.anyCustomer(7, 'c1'), isNull);
      await service.sync();
      expect(remote.pushes, hasLength(1));
    },
  );

  test('pull removes a note the server deleted', () async {
    final now = DateTime.utc(2026, 10, 3);
    await database.saveCustomer(
      CustomerRow(
        id: 'c1',
        userId: 7,
        name: 'Acme',
        contactInfo: null,
        createdAt: now,
        updatedAt: now,
        syncState: SyncStates.synced,
      ),
    );
    await database.saveSite(
      SiteRow(
        id: 's1',
        userId: 7,
        customerId: 'c1',
        siteName: 'Yard',
        address: null,
        createdAt: now,
        updatedAt: now,
        syncState: SyncStates.synced,
      ),
    );
    await database.saveNote(
      FieldNoteRow(
        id: 'n1',
        userId: 7,
        siteId: 's1',
        title: 'Old',
        description: null,
        latitude: null,
        longitude: null,
        notedAt: now,
        status: 'OPEN',
        createdAt: now,
        updatedAt: now,
        syncState: SyncStates.synced,
        localPhotoPath: null,
        photoSyncState: PhotoSync.none,
        remoteHasPhoto: false,
      ),
    );
    final remote = _FakeRemote(
      nextPull: SyncPullResult(
        serverTime: DateTime.utc(2026, 10, 7, 9),
        customers: const [],
        sites: const [],
        notes: [
          RemoteNote(
            id: 'n1',
            siteId: 's1',
            title: 'Old',
            description: null,
            latitude: null,
            longitude: null,
            notedAt: now,
            status: 'OPEN',
            photoUrl: null,
            createdAt: now,
            updatedAt: DateTime.utc(2026, 10, 7, 9),
            deletedAt: DateTime.utc(2026, 10, 7, 9),
          ),
        ],
      ),
    );
    await SyncService(
      remote: remote,
      database: database,
      userId: () async => 7,
    ).sync();
    expect(await database.anyNote(7, 'n1'), isNull);
  });

  test(
    'location validation rejects incomplete and out-of-range coordinates',
    () {
      expect(locationValidationMessage(null, null), isNull);
      expect(locationValidationMessage(23.81, 90.41), isNull);
      expect(locationValidationMessage(23.81, null), contains('both'));
      expect(locationValidationMessage(91, 90), contains('Latitude'));
      expect(locationValidationMessage(23, 181), contains('Longitude'));
      expect(locationValidationMessage(double.nan, 90), contains('finite'));
      expect(
        locationValidationMessage(23, double.infinity),
        contains('finite'),
      );
    },
  );
}

class _UnusedRemote implements SyncRemote {
  @override
  Future<List<int>> downloadPhoto(String noteId) async => const [];

  @override
  Future<SyncPullResult> pull(DateTime since, {String? accessToken}) =>
      throw UnimplementedError();

  @override
  Future<SyncPushResult> push(SyncPushBody body, {String? accessToken}) =>
      throw UnimplementedError();

  @override
  Future<void> uploadPhoto(
    String noteId,
    String filePath, {
    String? accessToken,
  }) async {}
}

class _FakeRemote implements SyncRemote {
  _FakeRemote({
    SyncPullResult? nextPull,
    Set<String>? failIds,
    this.blockFirstPush = false,
  }) : nextPull = nextPull,
       failIds = failIds ?? {};

  final SyncPullResult? nextPull;
  final Set<String> failIds;
  final bool blockFirstPush;
  final pushes = <SyncPushBody>[];
  final pushAccessTokens = <String?>[];
  final pullSince = <DateTime>[];
  final firstPushStarted = Completer<void>();
  final releaseFirstPush = Completer<void>();

  @override
  Future<SyncPushResult> push(SyncPushBody body, {String? accessToken}) async {
    pushAccessTokens.add(accessToken);
    if (blockFirstPush && pushes.isEmpty) {
      firstPushStarted.complete();
      await releaseFirstPush.future;
    }
    pushes.add(body);
    SyncItemResult resultFor(Map<String, dynamic> item) {
      final id = item['id'] as String;
      if (failIds.contains(id)) {
        return SyncItemResult(id: id, status: 'ERROR', error: 'nope');
      }
      return SyncItemResult(
        id: id,
        status: 'APPLIED',
        updatedAt: DateTime.utc(2026, 10, 7, 1),
      );
    }

    return SyncPushResult(
      serverTime: DateTime.utc(2026, 10, 7, 1),
      customers: body.customers.map(resultFor).toList(),
      sites: body.sites.map(resultFor).toList(),
      notes: body.notes.map(resultFor).toList(),
    );
  }

  @override
  Future<SyncPullResult> pull(DateTime since, {String? accessToken}) async {
    pullSince.add(since);
    return nextPull ??
        SyncPullResult(
          serverTime: DateTime.utc(2026, 10, 7, 1),
          customers: const [],
          sites: const [],
          notes: const [],
        );
  }

  @override
  Future<void> uploadPhoto(
    String noteId,
    String filePath, {
    String? accessToken,
  }) async {}

  @override
  Future<List<int>> downloadPhoto(String noteId) async => const [];
}

String _tokenFor(int userId) {
  String part(Map<String, Object> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'sub': userId})}.signature';
}
