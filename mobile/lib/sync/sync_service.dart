import 'package:field_notes/core/constants.dart';
import 'package:field_notes/data/local/app_database.dart';
import 'package:field_notes/data/remote/field_notes_api.dart';

class SyncService {
  SyncService({
    required this.remote,
    required this.database,
    required this.userId,
    this.accessToken,
  });

  final SyncRemote remote;
  final AppDatabase database;
  final Future<int?> Function() userId;
  final Future<String?> Function()? accessToken;
  Future<void> _tail = Future<void>.value();

  Future<void> sync() {
    final run = _tail.then((_) => _syncOnce());
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> _syncOnce() async {
    final token = await accessToken?.call();
    if (accessToken != null && token == null) return;
    final id = token == null ? await userId() : userIdFromToken(token);
    if (id == null) return;
    final pushFailed = await _push(id, token);
    final photoFailed = await _uploadPhotos(id, token);
    await _pull(id, token);
    if (pushFailed || photoFailed) {
      throw const SyncException(
        'Some changes could not be synced. They are safe on this device.',
      );
    }
  }

  Future<bool> _push(int userId, String? accessToken) async {
    final customers = await database.pendingCustomers(userId);
    final sites = await database.pendingSites(userId);
    final notes = await database.pendingNotes(userId);
    if (customers.isEmpty && sites.isEmpty && notes.isEmpty) return false;
    final result = await remote.push(
      SyncPushBody(
        customers: customers.map(_customerItem).toList(),
        sites: sites.map(_siteItem).toList(),
        notes: notes.map(_noteItem).toList(),
      ),
      accessToken: accessToken,
    );
    var failed = false;
    for (final item in result.customers) {
      final row = _find(customers, item.id);
      if (!item.applied || row == null) {
        failed = true;
        continue;
      }
      if (row.syncState == SyncStates.pendingDelete) {
        await database.removeCustomer(userId, row.id);
      } else {
        await database.markCustomerSynced(
          userId,
          row.id,
          item.updatedAt ?? DateTime.now().toUtc(),
        );
      }
    }
    for (final item in result.sites) {
      final row = _findSite(sites, item.id);
      if (!item.applied || row == null) {
        failed = true;
        continue;
      }
      if (row.syncState == SyncStates.pendingDelete) {
        await database.removeSite(userId, row.id);
      } else {
        await database.markSiteSynced(
          userId,
          row.id,
          item.updatedAt ?? DateTime.now().toUtc(),
        );
      }
    }
    for (final item in result.notes) {
      final row = _findNote(notes, item.id);
      if (!item.applied || row == null) {
        failed = true;
        continue;
      }
      if (row.syncState == SyncStates.pendingDelete) {
        await database.removeNote(userId, row.id);
      } else {
        await database.markNoteSynced(
          userId,
          row.id,
          item.updatedAt ?? DateTime.now().toUtc(),
        );
      }
    }
    return failed;
  }

  Future<bool> _uploadPhotos(int userId, String? accessToken) async {
    final notes = await database.notesPendingPhoto(userId);
    var failed = false;
    for (final note in notes) {
      final path = note.localPhotoPath;
      if (path == null) continue;
      try {
        await remote.uploadPhoto(note.id, path, accessToken: accessToken);
        await database.markPhotoSynced(userId, note.id);
      } catch (_) {
        // One photo failure stays pending and does not block the rest of the sync.
        failed = true;
      }
    }
    return failed;
  }

  Future<void> _pull(int userId, String? accessToken) async {
    final since = await database.lastSyncAt(userId) ?? DateTime.utc(1970);
    final page = await remote.pull(since, accessToken: accessToken);
    await database.transaction(() async {
      for (final row in page.customers) {
        await _applyCustomer(userId, row);
      }
      for (final row in page.sites) {
        await _applySite(userId, row);
      }
      for (final row in page.notes) {
        await _applyNote(userId, row);
      }
      await database.setLastSyncAt(userId, page.serverTime);
    });
  }

  Future<void> _applyCustomer(int userId, RemoteCustomer row) async {
    final local = await database.anyCustomer(userId, row.id);
    if (local != null && local.syncState != SyncStates.synced) return;
    if (row.deletedAt != null) {
      if (local != null) await database.removeCustomer(userId, row.id);
      return;
    }
    await database.saveCustomer(
      CustomerRow(
        id: row.id,
        userId: userId,
        name: row.name,
        contactInfo: row.contactInfo,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: null,
        syncState: SyncStates.synced,
      ),
    );
  }

  Future<void> _applySite(int userId, RemoteSite row) async {
    final local = await database.anySite(userId, row.id);
    if (local != null && local.syncState != SyncStates.synced) return;
    if (row.deletedAt != null) {
      if (local != null) await database.removeSite(userId, row.id);
      return;
    }
    await database.saveSite(
      SiteRow(
        id: row.id,
        userId: userId,
        customerId: row.customerId,
        siteName: row.siteName,
        address: row.address,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: null,
        syncState: SyncStates.synced,
      ),
    );
  }

  Future<void> _applyNote(int userId, RemoteNote row) async {
    final local = await database.anyNote(userId, row.id);
    if (local != null && local.syncState != SyncStates.synced) return;
    if (row.deletedAt != null) {
      if (local != null) await database.removeNote(userId, row.id);
      return;
    }
    final keepLocalPhoto = local?.photoSyncState == PhotoSync.pendingUpload;
    await database.saveNote(
      FieldNoteRow(
        id: row.id,
        userId: userId,
        siteId: row.siteId,
        title: row.title,
        description: row.description,
        latitude: row.latitude,
        longitude: row.longitude,
        notedAt: row.notedAt,
        status: row.status,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: null,
        syncState: SyncStates.synced,
        localPhotoPath: local?.localPhotoPath,
        photoSyncState: keepLocalPhoto
            ? PhotoSync.pendingUpload
            : (row.photoUrl != null
                  ? PhotoSync.synced
                  : (local?.photoSyncState ?? PhotoSync.none)),
        remoteHasPhoto: keepLocalPhoto
            ? (local?.remoteHasPhoto ?? false)
            : row.photoUrl != null,
      ),
    );
  }

  Map<String, dynamic> _customerItem(CustomerRow row) {
    return {
      'id': row.id,
      'name': row.name,
      'contactInfo': row.contactInfo,
      'createdAt': row.createdAt.toUtc().toIso8601String(),
      'deleted': row.syncState == SyncStates.pendingDelete,
    };
  }

  Map<String, dynamic> _siteItem(SiteRow row) {
    return {
      'id': row.id,
      'customerId': row.customerId,
      'siteName': row.siteName,
      'address': row.address,
      'createdAt': row.createdAt.toUtc().toIso8601String(),
      'deleted': row.syncState == SyncStates.pendingDelete,
    };
  }

  Map<String, dynamic> _noteItem(FieldNoteRow row) {
    return {
      'id': row.id,
      'siteId': row.siteId,
      'title': row.title,
      'description': row.description,
      'latitude': row.latitude,
      'longitude': row.longitude,
      'notedAt': row.notedAt.toUtc().toIso8601String(),
      'status': row.status,
      'createdAt': row.createdAt.toUtc().toIso8601String(),
      'deleted': row.syncState == SyncStates.pendingDelete,
    };
  }

  CustomerRow? _find(List<CustomerRow> rows, String id) {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  SiteRow? _findSite(List<SiteRow> rows, String id) {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  FieldNoteRow? _findNote(List<FieldNoteRow> rows, String id) {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }
}

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}
