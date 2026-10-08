import 'dart:io';

import 'package:field_notes/core/constants.dart';
import 'package:field_notes/data/local/app_database.dart';
import 'package:field_notes/data/remote/field_notes_api.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:field_notes/sync/local_change_bus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class NoteRepository {
  NoteRepository(this._db, this._changes, this._remote, {this.photoDirectory});

  final AppDatabase _db;
  final LocalChangeBus _changes;
  final SyncRemote _remote;
  final Directory? photoDirectory;
  final _uuid = const Uuid();

  Stream<List<FieldNote>> watch({
    required int userId,
    String? status,
    String? siteId,
    String? query,
  }) {
    return _db
        .watchNotes(
          userId: userId,
          status: status,
          siteId: siteId,
          query: query,
        )
        .map((rows) => rows.map(_mapJoined).toList());
  }

  Stream<FieldNote?> watchById(int userId, String id) {
    return watch(userId: userId).map((notes) {
      for (final note in notes) {
        if (note.id == id) return note;
      }
      return null;
    });
  }

  Future<FieldNote?> get(int userId, String id) async {
    final row = await _db.noteById(userId, id);
    if (row == null) return null;
    final note = row.readTable(_db.fieldNotes);
    if (note.deletedAt != null || note.syncState == SyncStates.pendingDelete) {
      return null;
    }
    return _mapJoined(row);
  }

  Future<void> save({required int userId, required NoteDraft draft}) async {
    final now = DateTime.now().toUtc();
    final site = await _db.siteById(userId, draft.siteId);
    if (site == null) {
      throw StateError('Site is not available for this account.');
    }
    final existing = draft.id == null
        ? null
        : await _db.anyNote(userId, draft.id!);
    final id = draft.id ?? _uuid.v4();
    var photoPath = existing?.localPhotoPath;
    var photoState = existing?.photoSyncState ?? PhotoSync.none;
    var remoteHasPhoto = existing?.remoteHasPhoto ?? false;
    if (draft.newPhotoPath != null) {
      photoPath = await _copyPhoto(id, draft.newPhotoPath!);
      photoState = PhotoSync.pendingUpload;
    }
    await _db.saveNote(
      FieldNoteRow(
        id: id,
        userId: userId,
        siteId: draft.siteId,
        title: draft.title.trim(),
        description: _blank(draft.description),
        latitude: draft.latitude,
        longitude: draft.longitude,
        notedAt: draft.notedAt.toUtc(),
        status: draft.status,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: null,
        syncState: SyncStates.pendingUpsert,
        localPhotoPath: photoPath,
        photoSyncState: photoState,
        remoteHasPhoto: remoteHasPhoto,
      ),
    );
    _changes.notify();
  }

  Future<void> delete(int userId, String id) async {
    await _db.markDeletedNote(userId, id);
    _changes.notify();
  }

  Future<String?> ensurePhoto(int userId, String id) async {
    final row = await _db.anyNote(userId, id);
    if (row == null) return null;
    if (row.localPhotoPath != null && File(row.localPhotoPath!).existsSync()) {
      return row.localPhotoPath;
    }
    if (!row.remoteHasPhoto || row.photoSyncState == PhotoSync.pendingUpload) {
      return row.localPhotoPath;
    }
    final bytes = await _remote.downloadPhoto(id);
    final dir =
        photoDirectory ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'photos'),
        );
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$id.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    await _db.setLocalPhoto(userId, id, file.path);
    return file.path;
  }

  Future<String> _copyPhoto(String id, String sourcePath) async {
    final dir =
        photoDirectory ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'photos'),
        );
    await dir.create(recursive: true);
    final dest = File(p.join(dir.path, '$id.jpg'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  FieldNote _mapJoined(dynamic row) {
    final note = row.readTable(_db.fieldNotes) as FieldNoteRow;
    final site = row.readTable(_db.sites) as SiteRow;
    final customer = row.readTable(_db.customers) as CustomerRow;
    return FieldNote(
      id: note.id,
      userId: note.userId,
      siteId: note.siteId,
      siteName: site.siteName,
      siteAddress: site.address,
      customerId: customer.id,
      customerName: customer.name,
      title: note.title,
      description: note.description,
      latitude: note.latitude,
      longitude: note.longitude,
      notedAt: note.notedAt.toUtc(),
      status: note.status,
      createdAt: note.createdAt.toUtc(),
      updatedAt: note.updatedAt.toUtc(),
      localPhotoPath: note.localPhotoPath,
      remoteHasPhoto: note.remoteHasPhoto,
    );
  }

  String? _blank(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
