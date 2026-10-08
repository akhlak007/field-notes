import 'package:drift/drift.dart';
import 'package:field_notes/core/constants.dart';

part 'app_database.g.dart';

@DataClassName('CustomerRow')
class Customers extends Table {
  TextColumn get id => text()();
  IntColumn get userId => integer()();
  TextColumn get name => text()();
  TextColumn get contactInfo => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SiteRow')
class Sites extends Table {
  TextColumn get id => text()();
  IntColumn get userId => integer()();
  TextColumn get customerId => text()();
  TextColumn get siteName => text()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FieldNoteRow')
class FieldNotes extends Table {
  TextColumn get id => text()();
  IntColumn get userId => integer()();
  TextColumn get siteId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get notedAt => dateTime()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text()();
  TextColumn get localPhotoPath => text().nullable()();
  TextColumn get photoSyncState =>
      text().withDefault(const Constant(PhotoSync.none))();
  BoolColumn get remoteHasPhoto =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'field_notes';
}

class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  String get tableName => 'sync_meta';
}

@DriftDatabase(tables: [Customers, Sites, FieldNotes, SyncMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  Expression<bool> _visibleCustomer(Customers c) =>
      c.deletedAt.isNull() & c.syncState.equals(SyncStates.pendingDelete).not();

  Expression<bool> _visibleSite(Sites s) =>
      s.deletedAt.isNull() & s.syncState.equals(SyncStates.pendingDelete).not();

  Stream<List<CustomerRow>> watchCustomers(int userId) {
    return (select(customers)
          ..where((c) => c.userId.equals(userId) & _visibleCustomer(c))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<CustomerRow?> customerById(int userId, String id) {
    return (select(customers)..where(
          (c) =>
              c.userId.equals(userId) & c.id.equals(id) & _visibleCustomer(c),
        ))
        .getSingleOrNull();
  }

  Stream<List<SiteRow>> watchSites(int userId, {String? customerId}) {
    return (select(sites)
          ..where((s) {
            var expr = s.userId.equals(userId) & _visibleSite(s);
            if (customerId != null) {
              expr = expr & s.customerId.equals(customerId);
            }
            return expr;
          })
          ..orderBy([(s) => OrderingTerm.asc(s.siteName)]))
        .watch();
  }

  Future<SiteRow?> siteById(int userId, String id) {
    return (select(sites)..where(
          (s) => s.userId.equals(userId) & s.id.equals(id) & _visibleSite(s),
        ))
        .getSingleOrNull();
  }

  Stream<List<TypedResult>> watchNotes({
    required int userId,
    String? status,
    String? siteId,
    String? query,
  }) {
    final joined = select(fieldNotes).join([
      innerJoin(sites, sites.id.equalsExp(fieldNotes.siteId)),
      innerJoin(customers, customers.id.equalsExp(sites.customerId)),
    ]);
    joined.where(
      fieldNotes.userId.equals(userId) &
          sites.userId.equals(userId) &
          customers.userId.equals(userId),
    );
    joined.where(
      fieldNotes.deletedAt.isNull() &
          fieldNotes.syncState.equals(SyncStates.pendingDelete).not(),
    );
    joined.where(_visibleSite(sites));
    joined.where(_visibleCustomer(customers));
    if (status != null && status.isNotEmpty) {
      joined.where(fieldNotes.status.equals(status));
    }
    if (siteId != null && siteId.isNotEmpty) {
      joined.where(fieldNotes.siteId.equals(siteId));
    }
    final pattern = _like(query);
    if (pattern != null) {
      joined.where(
        fieldNotes.title.lower().like(pattern) |
            fieldNotes.description.lower().like(pattern) |
            sites.siteName.lower().like(pattern) |
            customers.name.lower().like(pattern),
      );
    }
    joined.orderBy([OrderingTerm.desc(fieldNotes.notedAt)]);
    return joined.watch();
  }

  Future<TypedResult?> noteById(int userId, String id) {
    final joined =
        select(fieldNotes).join([
          innerJoin(sites, sites.id.equalsExp(fieldNotes.siteId)),
          innerJoin(customers, customers.id.equalsExp(sites.customerId)),
        ])..where(
          fieldNotes.userId.equals(userId) &
              sites.userId.equals(userId) &
              customers.userId.equals(userId) &
              fieldNotes.id.equals(id),
        );
    return joined.getSingleOrNull();
  }

  Future<void> saveCustomer(CustomerRow row) async {
    final existing = await (select(
      customers,
    )..where((c) => c.id.equals(row.id))).getSingleOrNull();
    _requireOwner(existing?.userId, row.userId, 'Customer');
    await into(customers).insertOnConflictUpdate(row);
  }

  Future<void> saveSite(SiteRow row) async {
    final existing = await (select(
      sites,
    )..where((s) => s.id.equals(row.id))).getSingleOrNull();
    _requireOwner(existing?.userId, row.userId, 'Site');
    await into(sites).insertOnConflictUpdate(row);
  }

  Future<void> saveNote(FieldNoteRow row) async {
    final existing = await (select(
      fieldNotes,
    )..where((n) => n.id.equals(row.id))).getSingleOrNull();
    _requireOwner(existing?.userId, row.userId, 'Note');
    await into(fieldNotes).insertOnConflictUpdate(row);
  }

  Future<int> markDeletedCustomer(int userId, String id) async {
    final now = DateTime.now().toUtc();
    return transaction(() async {
      final siteIds =
          await (select(sites)..where(
                (s) => s.userId.equals(userId) & s.customerId.equals(id),
              ))
              .map((s) => s.id)
              .get();
      if (siteIds.isNotEmpty) {
        await (update(fieldNotes)
              ..where((n) => n.userId.equals(userId) & n.siteId.isIn(siteIds)))
            .write(
              FieldNotesCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                syncState: const Value(SyncStates.pendingDelete),
              ),
            );
      }
      await (update(
        sites,
      )..where((s) => s.userId.equals(userId) & s.customerId.equals(id))).write(
        SitesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value(SyncStates.pendingDelete),
        ),
      );
      return (update(
        customers,
      )..where((c) => c.userId.equals(userId) & c.id.equals(id))).write(
        CustomersCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value(SyncStates.pendingDelete),
        ),
      );
    });
  }

  Future<int> markDeletedSite(int userId, String id) async {
    final now = DateTime.now().toUtc();
    return transaction(() async {
      await (update(
        fieldNotes,
      )..where((n) => n.userId.equals(userId) & n.siteId.equals(id))).write(
        FieldNotesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value(SyncStates.pendingDelete),
        ),
      );
      return (update(
        sites,
      )..where((s) => s.userId.equals(userId) & s.id.equals(id))).write(
        SitesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value(SyncStates.pendingDelete),
        ),
      );
    });
  }

  Future<int> markDeletedNote(int userId, String id) {
    final now = DateTime.now().toUtc();
    return (update(
      fieldNotes,
    )..where((n) => n.userId.equals(userId) & n.id.equals(id))).write(
      FieldNotesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncState: const Value(SyncStates.pendingDelete),
      ),
    );
  }

  Future<List<CustomerRow>> pendingCustomers(int userId) {
    return (select(customers)..where(
          (c) =>
              c.userId.equals(userId) &
              c.syncState.equals(SyncStates.synced).not(),
        ))
        .get();
  }

  Future<List<SiteRow>> pendingSites(int userId) {
    return (select(sites)..where(
          (s) =>
              s.userId.equals(userId) &
              s.syncState.equals(SyncStates.synced).not(),
        ))
        .get();
  }

  Future<List<FieldNoteRow>> pendingNotes(int userId) {
    return (select(fieldNotes)..where(
          (n) =>
              n.userId.equals(userId) &
              n.syncState.equals(SyncStates.synced).not(),
        ))
        .get();
  }

  Future<List<FieldNoteRow>> notesPendingPhoto(int userId) {
    return (select(fieldNotes)..where(
          (n) =>
              n.userId.equals(userId) &
              n.syncState.equals(SyncStates.synced) &
              n.photoSyncState.equals(PhotoSync.pendingUpload) &
              n.deletedAt.isNull(),
        ))
        .get();
  }

  Future<void> markCustomerSynced(int userId, String id, DateTime updatedAt) {
    return (update(
      customers,
    )..where((c) => c.userId.equals(userId) & c.id.equals(id))).write(
      CustomersCompanion(
        syncState: const Value(SyncStates.synced),
        updatedAt: Value(updatedAt),
        deletedAt: const Value(null),
      ),
    );
  }

  Future<void> markSiteSynced(int userId, String id, DateTime updatedAt) {
    return (update(
      sites,
    )..where((s) => s.userId.equals(userId) & s.id.equals(id))).write(
      SitesCompanion(
        syncState: const Value(SyncStates.synced),
        updatedAt: Value(updatedAt),
        deletedAt: const Value(null),
      ),
    );
  }

  Future<void> markNoteSynced(int userId, String id, DateTime updatedAt) {
    return (update(
      fieldNotes,
    )..where((n) => n.userId.equals(userId) & n.id.equals(id))).write(
      FieldNotesCompanion(
        syncState: const Value(SyncStates.synced),
        updatedAt: Value(updatedAt),
        deletedAt: const Value(null),
      ),
    );
  }

  Future<void> markPhotoSynced(int userId, String id) {
    return (update(
      fieldNotes,
    )..where((n) => n.userId.equals(userId) & n.id.equals(id))).write(
      const FieldNotesCompanion(
        photoSyncState: Value(PhotoSync.synced),
        remoteHasPhoto: Value(true),
      ),
    );
  }

  Future<void> setLocalPhoto(int userId, String id, String path) {
    return (update(
      fieldNotes,
    )..where((n) => n.userId.equals(userId) & n.id.equals(id))).write(
      FieldNotesCompanion(
        localPhotoPath: Value(path),
        remoteHasPhoto: const Value(true),
        photoSyncState: const Value(PhotoSync.synced),
      ),
    );
  }

  Future<void> removeCustomer(int userId, String id) => (delete(
    customers,
  )..where((c) => c.userId.equals(userId) & c.id.equals(id))).go();

  Future<void> removeSite(int userId, String id) => (delete(
    sites,
  )..where((s) => s.userId.equals(userId) & s.id.equals(id))).go();

  Future<void> removeNote(int userId, String id) => (delete(
    fieldNotes,
  )..where((n) => n.userId.equals(userId) & n.id.equals(id))).go();

  Future<CustomerRow?> anyCustomer(int userId, String id) {
    return (select(customers)
          ..where((c) => c.userId.equals(userId) & c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<SiteRow?> anySite(int userId, String id) {
    return (select(sites)
          ..where((s) => s.userId.equals(userId) & s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<FieldNoteRow?> anyNote(int userId, String id) {
    return (select(fieldNotes)
          ..where((n) => n.userId.equals(userId) & n.id.equals(id)))
        .getSingleOrNull();
  }

  Future<DateTime?> lastSyncAt(int userId) async {
    await ignoreLegacyGlobalCursor();
    final row = await (select(
      syncMeta,
    )..where((m) => m.key.equals('last_sync_at:$userId'))).getSingleOrNull();
    if (row == null || row.value.isEmpty) return null;
    return DateTime.parse(row.value).toUtc();
  }

  /// Older builds stored a single `last_sync_at` for the whole device.
  Future<void> ignoreLegacyGlobalCursor() {
    return (delete(syncMeta)..where((m) => m.key.equals('last_sync_at'))).go();
  }

  Future<void> setLastSyncAt(int userId, DateTime time) {
    return into(syncMeta).insertOnConflictUpdate(
      SyncMetaCompanion.insert(
        key: 'last_sync_at:$userId',
        value: time.toUtc().toIso8601String(),
      ),
    );
  }

  Future<int> pendingCount(int userId) async {
    final customerCount = customers.id.count();
    final siteCount = sites.id.count();
    final noteCount = fieldNotes.id.count();
    final customersRow =
        await (selectOnly(customers)
              ..addColumns([customerCount])
              ..where(
                customers.userId.equals(userId) &
                    customers.syncState.equals(SyncStates.synced).not(),
              ))
            .getSingle();
    final sitesRow =
        await (selectOnly(sites)
              ..addColumns([siteCount])
              ..where(
                sites.userId.equals(userId) &
                    sites.syncState.equals(SyncStates.synced).not(),
              ))
            .getSingle();
    final notesRow =
        await (selectOnly(fieldNotes)
              ..addColumns([noteCount])
              ..where(
                fieldNotes.userId.equals(userId) &
                    (fieldNotes.syncState.equals(SyncStates.synced).not() |
                        fieldNotes.photoSyncState.equals(
                          PhotoSync.pendingUpload,
                        )),
              ))
            .getSingle();
    return ((customersRow.read(customerCount) ?? 0) +
            (sitesRow.read(siteCount) ?? 0) +
            (notesRow.read(noteCount) ?? 0))
        .toInt();
  }

  Future<void> clearAll() {
    return transaction(() async {
      await delete(fieldNotes).go();
      await delete(sites).go();
      await delete(customers).go();
      await delete(syncMeta).go();
    });
  }

  String? _like(String? query) {
    if (query == null || query.trim().isEmpty) return null;
    final escaped = query
        .trim()
        .toLowerCase()
        .replaceAll('\\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  void _requireOwner(int? existingUserId, int incomingUserId, String entity) {
    if (existingUserId != null && existingUserId != incomingUserId) {
      throw StateError('$entity belongs to another local account.');
    }
  }
}
