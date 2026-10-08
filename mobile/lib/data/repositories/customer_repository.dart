import 'package:field_notes/core/constants.dart';
import 'package:field_notes/data/local/app_database.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:field_notes/sync/local_change_bus.dart';
import 'package:uuid/uuid.dart';

class CustomerRepository {
  CustomerRepository(this._db, this._changes);

  final AppDatabase _db;
  final LocalChangeBus _changes;
  final _uuid = const Uuid();

  Stream<List<Customer>> watch(int userId) {
    return _db.watchCustomers(userId).map((rows) => rows.map(_map).toList());
  }

  Future<Customer?> get(int userId, String id) async {
    final row = await _db.customerById(userId, id);
    return row == null ? null : _map(row);
  }

  Future<void> save({
    String? id,
    required int userId,
    required String name,
    String? contactInfo,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = id == null ? null : await _db.anyCustomer(userId, id);
    await _db.saveCustomer(
      CustomerRow(
        id: id ?? _uuid.v4(),
        userId: userId,
        name: name.trim(),
        contactInfo: _blank(contactInfo),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: null,
        syncState: SyncStates.pendingUpsert,
      ),
    );
    _changes.notify();
  }

  Future<void> delete(int userId, String id) async {
    await _db.markDeletedCustomer(userId, id);
    _changes.notify();
  }

  Customer _map(CustomerRow row) {
    return Customer(
      id: row.id,
      userId: row.userId,
      name: row.name,
      contactInfo: row.contactInfo,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  String? _blank(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
