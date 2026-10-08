import 'package:field_notes/data/remote/field_notes_api.dart';
import 'package:field_notes/data/remote/token_storage.dart';

class Session {
  const Session({required this.userId, required this.email});

  final int userId;
  final String email;
}

class AuthRepository {
  AuthRepository({required FieldNotesApi api, required TokenStorage tokens})
    : _api = api,
      _tokens = tokens;

  final FieldNotesApi _api;
  final TokenStorage _tokens;

  Future<Session?> current() async {
    final userId = await _tokens.userId();
    final email = await _tokens.email();
    final access = await _tokens.accessToken();
    if (userId == null || email == null || access == null) return null;
    return Session(userId: userId, email: email);
  }

  Future<Session> registerAndLogin({
    required String email,
    required String password,
  }) async {
    await _api.register(email: email.trim(), password: password);
    return login(email: email, password: password);
  }

  Future<Session> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final tokens = await _api.login(email: normalized, password: password);
    final userId = userIdFromToken(tokens.accessToken);
    await _tokens.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      userId: userId,
      email: normalized,
    );
    return Session(userId: userId, email: normalized);
  }

  Future<void> logout() => _tokens.clear();
}
