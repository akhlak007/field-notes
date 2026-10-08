import 'package:field_notes/core/constants.dart';
import 'package:field_notes/data/local/app_database.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:field_notes/sync/local_change_bus.dart';
import 'package:uuid/uuid.dart';

class SiteRepository {
  SiteRepository(this._db, this._changes);

  final AppDatabase _db;
  final LocalChangeBus _changes;
  final _uuid = const Uuid();

  Stream<List<Site>> watch(int userId, {String? customerId}) {
    return _db.watchSites(userId, customerId: customerId).asyncMap((
      rows,
    ) async {
      final names = <String, String>{};
      for (final row in rows) {
        names[row.customerId] ??=
            (await _db.customerById(userId, row.customerId))?.name ??
            'Customer';
      }
      return rows
          .map(
            (row) => Site(
              id: row.id,
              userId: row.userId,
              customerId: row.customerId,
              customerName: names[row.customerId] ?? 'Customer',
              siteName: row.siteName,
              address: row.address,
              createdAt: row.createdAt.toUtc(),
              updatedAt: row.updatedAt.toUtc(),
            ),
          )
          .toList();
    });
  }

  Future<Site?> get(int userId, String id) async {
    final row = await _db.siteById(userId, id);
    if (row == null) return null;
    final customer = await _db.customerById(userId, row.customerId);
    return Site(
      id: row.id,
      userId: row.userId,
      customerId: row.customerId,
      customerName: customer?.name ?? 'Customer',
      siteName: row.siteName,
      address: row.address,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  Future<void> save({
    String? id,
    required int userId,
    required String customerId,
    required String siteName,
    String? address,
  }) async {
    final now = DateTime.now().toUtc();
    final customer = await _db.customerById(userId, customerId);
    if (customer == null) {
      throw StateError('Customer is not available for this account.');
    }
    final existing = id == null ? null : await _db.anySite(userId, id);
    await _db.saveSite(
      SiteRow(
        id: id ?? _uuid.v4(),
        userId: userId,
        customerId: customerId,
        siteName: siteName.trim(),
        address: _blank(address),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: null,
        syncState: SyncStates.pendingUpsert,
      ),
    );
    _changes.notify();
  }

  Future<void> delete(int userId, String id) async {
    await _db.markDeletedSite(userId, id);
    _changes.notify();
  }

  String? _blank(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
