import 'package:dio/dio.dart';
import 'package:field_notes/data/remote/token_storage.dart';
import 'package:field_notes/sync/session_events.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokens,
    required this.sessionEvents,
  });

  final Dio dio;
  final Dio refreshDio;
  final TokenStorage tokens;
  final SessionEvents sessionEvents;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokens.accessToken();
    if (token != null &&
        token.isNotEmpty &&
        !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final retried = err.requestOptions.extra['retried'] == true;
    if (status != 401 || path.contains('/api/auth/')) {
      handler.next(err);
      return;
    }

    final generation = tokens.generation;
    final currentAccess = await tokens.accessToken();
    final requestedAccess = _bearerToken(err.requestOptions);
    if (tokens.generation != generation ||
        (requestedAccess != null && requestedAccess != currentAccess)) {
      handler.next(err);
      return;
    }
    if (retried) {
      if (await tokens.clearIfCurrent(generation)) {
        sessionEvents.notifyExpired();
      }
      handler.next(err);
      return;
    }
    final refresh = await tokens.refreshToken();
    if (tokens.generation != generation) {
      handler.next(err);
      return;
    }
    if (refresh == null) {
      if (await tokens.clearIfCurrent(generation)) {
        sessionEvents.notifyExpired();
      }
      handler.next(err);
      return;
    }
    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = response.data ?? {};
      final access = data['accessToken'] as String;
      final nextRefresh = (data['refreshToken'] as String?) ?? refresh;
      final saved = await tokens.saveTokensIfCurrent(
        expectedGeneration: generation,
        accessToken: access,
        refreshToken: nextRefresh,
      );
      if (!saved) {
        handler.next(err);
        return;
      }
      final request = err.requestOptions;
      request.extra['retried'] = true;
      request.headers['Authorization'] = 'Bearer $access';
      final replay = await dio.fetch<dynamic>(request);
      handler.resolve(replay);
    } on DioException catch (refreshError) {
      if (refreshError.response?.statusCode == 401 ||
          refreshError.response?.statusCode == 403) {
        if (await tokens.clearIfCurrent(generation)) {
          sessionEvents.notifyExpired();
        }
      }
      handler.next(err);
    }
  }

  String? _bearerToken(RequestOptions request) {
    final value = request.headers['Authorization'];
    if (value is! String || !value.startsWith('Bearer ')) return null;
    return value.substring('Bearer '.length);
  }
}
