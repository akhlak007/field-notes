import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  Future<void> _writes = Future<void>.value();
  int _generation = 0;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _userId = 'user_id';
  static const _email = 'email';

  int get generation => _generation;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String email,
  }) async {
    _generation += 1;
    await _enqueue(() async {
      await _storage.write(key: _access, value: accessToken);
      await _storage.write(key: _refresh, value: refreshToken);
      await _storage.write(key: _userId, value: userId.toString());
      await _storage.write(key: _email, value: email);
    });
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _generation += 1;
    await _enqueue(() async {
      await _storage.write(key: _access, value: accessToken);
      await _storage.write(key: _refresh, value: refreshToken);
    });
  }

  Future<bool> saveTokensIfCurrent({
    required int expectedGeneration,
    required String accessToken,
    required String refreshToken,
  }) async {
    if (_generation != expectedGeneration) return false;
    _generation += 1;
    await _enqueue(() async {
      await _storage.write(key: _access, value: accessToken);
      await _storage.write(key: _refresh, value: refreshToken);
    });
    return true;
  }

  Future<String?> accessToken() async {
    await _writes;
    return _storage.read(key: _access);
  }

  Future<String?> refreshToken() async {
    await _writes;
    return _storage.read(key: _refresh);
  }

  Future<String?> email() async {
    await _writes;
    return _storage.read(key: _email);
  }

  Future<int?> userId() async {
    await _writes;
    final value = await _storage.read(key: _userId);
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> clear() async {
    _generation += 1;
    await _enqueue(_storage.deleteAll);
  }

  Future<bool> clearIfCurrent(int expectedGeneration) async {
    if (_generation != expectedGeneration) return false;
    _generation += 1;
    await _enqueue(_storage.deleteAll);
    return true;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
