import 'dart:convert';

import 'package:dio/dio.dart';

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}

class SyncItemResult {
  const SyncItemResult({
    required this.id,
    required this.status,
    this.error,
    this.updatedAt,
  });

  final String id;
  final String status;
  final String? error;
  final DateTime? updatedAt;

  bool get applied => status == 'APPLIED';
}

class RemoteCustomer {
  const RemoteCustomer({
    required this.id,
    required this.name,
    required this.contactInfo,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String name;
  final String? contactInfo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class RemoteSite {
  const RemoteSite({
    required this.id,
    required this.customerId,
    required this.siteName,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String customerId;
  final String siteName;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class RemoteNote {
  const RemoteNote({
    required this.id,
    required this.siteId,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.notedAt,
    required this.status,
    required this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String siteId;
  final String title;
  final String? description;
  final double? latitude;
  final double? longitude;
  final DateTime notedAt;
  final String status;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

class SyncPushBody {
  const SyncPushBody({
    required this.customers,
    required this.sites,
    required this.notes,
  });

  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> sites;
  final List<Map<String, dynamic>> notes;

  Map<String, dynamic> toJson() => {
    'customers': customers,
    'sites': sites,
    'notes': notes,
  };
}

class SyncPushResult {
  const SyncPushResult({
    required this.serverTime,
    required this.customers,
    required this.sites,
    required this.notes,
  });

  final DateTime serverTime;
  final List<SyncItemResult> customers;
  final List<SyncItemResult> sites;
  final List<SyncItemResult> notes;
}

class SyncPullResult {
  const SyncPullResult({
    required this.serverTime,
    required this.customers,
    required this.sites,
    required this.notes,
  });

  final DateTime serverTime;
  final List<RemoteCustomer> customers;
  final List<RemoteSite> sites;
  final List<RemoteNote> notes;
}

abstract class SyncRemote {
  Future<SyncPushResult> push(SyncPushBody body, {String? accessToken});
  Future<SyncPullResult> pull(DateTime since, {String? accessToken});
  Future<void> uploadPhoto(
    String noteId,
    String filePath, {
    String? accessToken,
  });
  Future<List<int>> downloadPhoto(String noteId);
}

class FieldNotesApi implements SyncRemote {
  FieldNotesApi(this._dio);

  final Dio _dio;

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _dio.post<dynamic>(
      '/api/auth/register',
      data: {'email': email, 'password': password},
    );
  }

  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    return _tokens(response.data ?? {});
  }

  @override
  Future<SyncPushResult> push(SyncPushBody body, {String? accessToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/sync/push',
      data: body.toJson(),
      options: _sessionOptions(accessToken),
    );
    final data = response.data ?? {};
    return SyncPushResult(
      serverTime: _time(data['serverTime']) ?? DateTime.now().toUtc(),
      customers: _items(data['customers']),
      sites: _items(data['sites']),
      notes: _items(data['notes']),
    );
  }

  @override
  Future<SyncPullResult> pull(DateTime since, {String? accessToken}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/sync/pull',
      queryParameters: {'since': since.toUtc().toIso8601String()},
      options: _sessionOptions(accessToken),
    );
    final data = response.data ?? {};
    return SyncPullResult(
      serverTime: _time(data['serverTime']) ?? DateTime.now().toUtc(),
      customers: _list(data['customers']).map(_customer).toList(),
      sites: _list(data['sites']).map(_site).toList(),
      notes: _list(data['notes']).map(_note).toList(),
    );
  }

  @override
  Future<void> uploadPhoto(
    String noteId,
    String filePath, {
    String? accessToken,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: 'note.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    await _dio.post<dynamic>(
      '/api/notes/$noteId/photo',
      data: form,
      options: _sessionOptions(accessToken),
    );
  }

  @override
  Future<List<int>> downloadPhoto(String noteId) async {
    final response = await _dio.get<List<int>>(
      '/api/notes/$noteId/photo',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const [];
  }

  TokenPair _tokens(Map<String, dynamic> data) {
    return TokenPair(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      expiresIn: (data['expiresIn'] as num).toInt(),
    );
  }

  List<SyncItemResult> _items(dynamic raw) {
    return _list(raw).map((item) {
      return SyncItemResult(
        id: item['id'].toString(),
        status: item['status'] as String? ?? 'ERROR',
        error: item['error'] as String?,
        updatedAt: _time(item['updatedAt']),
      );
    }).toList();
  }

  RemoteCustomer _customer(Map<String, dynamic> json) {
    return RemoteCustomer(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      contactInfo: json['contactInfo'] as String?,
      createdAt: _time(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _time(json['updatedAt']) ?? DateTime.now().toUtc(),
      deletedAt: _time(json['deletedAt']),
    );
  }

  RemoteSite _site(Map<String, dynamic> json) {
    return RemoteSite(
      id: json['id'].toString(),
      customerId: json['customerId'].toString(),
      siteName: json['siteName'] as String? ?? '',
      address: json['address'] as String?,
      createdAt: _time(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _time(json['updatedAt']) ?? DateTime.now().toUtc(),
      deletedAt: _time(json['deletedAt']),
    );
  }

  RemoteNote _note(Map<String, dynamic> json) {
    return RemoteNote(
      id: json['id'].toString(),
      siteId: json['siteId'].toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notedAt: _time(json['notedAt']) ?? DateTime.now().toUtc(),
      status: json['status'] as String? ?? 'OPEN',
      photoUrl: json['photoUrl'] as String?,
      createdAt: _time(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _time(json['updatedAt']) ?? DateTime.now().toUtc(),
      deletedAt: _time(json['deletedAt']),
    );
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  DateTime? _time(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.parse(value).toUtc();
  }

  Options? _sessionOptions(String? accessToken) {
    if (accessToken == null || accessToken.isEmpty) return null;
    return Options(
      headers: {'Authorization': 'Bearer $accessToken'},
      extra: const {'sessionBound': true},
    );
  }
}

int userIdFromToken(String token) {
  final parts = token.split('.');
  if (parts.length < 2) {
    throw const FormatException('Invalid access token');
  }
  final normalized = base64Url.normalize(parts[1]);
  final payload = jsonDecode(
    utf8.decode(base64Url.decode(normalized)),
  ) as Map<String, dynamic>;
  return int.parse(payload['sub'].toString());
}

String apiErrorMessage(
  DioException error, {
  String fallback = 'Something went wrong. Try again.',
}) {
  final data = error.response?.data;
  if (data is Map &&
      data['message'] is String &&
      (data['message'] as String).isNotEmpty) {
    return data['message'] as String;
  }
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return 'The server is waking up or unreachable. Wait about a minute and try again. Your notes stay on this device.';
  }
  return fallback;
}
