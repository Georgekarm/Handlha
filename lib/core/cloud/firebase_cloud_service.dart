import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../logger/app_logger.dart';
import '../result/result.dart';
import '../secure_storage/secure_storage_service.dart';

class FirebaseCloudConfig {
  const FirebaseCloudConfig._();

  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isConfigured =>
      apiKey.trim().isNotEmpty && projectId.trim().isNotEmpty;
}

class FirebaseAuthSession {
  const FirebaseAuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    this.displayName,
  });

  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final String? displayName;
}

enum CloudSyncState {
  localOnly,
  synced,
  conflictDetected,
  authExpired,
  payloadTooLarge,
  failed,
}

@immutable
class CloudSyncStatus {
  const CloudSyncStatus({
    required this.state,
    this.lastSyncedAt,
    this.lastError,
  });

  const CloudSyncStatus.localOnly()
      : state = CloudSyncState.localOnly,
        lastSyncedAt = null,
        lastError = null;

  final CloudSyncState state;
  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get isSynced => state == CloudSyncState.synced;
}

@immutable
class CloudHttpResponse {
  const CloudHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, dynamic> body;
}

typedef CloudHttpExecutor = Future<CloudHttpResponse> Function({
  required String method,
  required String url,
  Map<String, dynamic>? body,
  String? bearerToken,
});

/// Pure-Dart Firebase Auth (Identity Toolkit v1) & Cloud Firestore REST snapshot client.
///
/// Activates only when `FIREBASE_API_KEY` and `FIREBASE_PROJECT_ID` are supplied
/// via `--dart-define`. Surfaces explicit sync results, token expiry handling,
/// payload-size protection (below Firestore's 1 MiB document cap), and remote
/// timestamp conflict detection instead of failing silently.
class FirebaseCloudService {
  FirebaseCloudService._({
    this._enabledOverride,
    this._apiKeyOverride,
    this._projectIdOverride,
    this._httpExecutor,
  });

  static final FirebaseCloudService instance = FirebaseCloudService._();

  @visibleForTesting
  factory FirebaseCloudService.forTesting({
    required bool enabled,
    String apiKey = 'test-api-key',
    String projectId = 'test-project',
    required CloudHttpExecutor httpExecutor,
  }) =>
      FirebaseCloudService._(
        enabledOverride: enabled,
        apiKeyOverride: apiKey,
        projectIdOverride: projectId,
        httpExecutor: httpExecutor,
      );

  static const String _tag = 'FirebaseCloud';

  /// Safe ceiling below Cloud Firestore's documented 1 MiB (1,048,576 B) limit.
  static const int maxSafePayloadBytes = 900 * 1024;

  final bool? _enabledOverride;
  final String? _apiKeyOverride;
  final String? _projectIdOverride;
  final CloudHttpExecutor? _httpExecutor;

  CloudSyncStatus _lastSyncStatus = const CloudSyncStatus.localOnly();

  String get _apiKey => _apiKeyOverride ?? FirebaseCloudConfig.apiKey;
  String get _projectId => _projectIdOverride ?? FirebaseCloudConfig.projectId;

  bool get isEnabled => _enabledOverride ?? FirebaseCloudConfig.isConfigured;

  CloudSyncStatus get lastSyncStatus =>
      isEnabled ? _lastSyncStatus : const CloudSyncStatus.localOnly();

  void _recordStatus(CloudSyncStatus status) {
    _lastSyncStatus = status;
  }

  Future<Result<FirebaseAuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!isEnabled) {
      return const Failure(AuthFailure('Cloud Auth is not configured.'));
    }
    final res = await _postJson(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey',
      {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      },
    );
    return _parseAuthResponse(res, fallbackEmail: email);
  }

  Future<Result<FirebaseAuthSession>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!isEnabled) {
      return const Failure(AuthFailure('Cloud Auth is not configured.'));
    }
    final res = await _postJson(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey',
      {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      },
    );
    final parsed = await _parseAuthResponse(
      res,
      fallbackEmail: email,
      fallbackName: displayName,
    );
    if (parsed is Success<FirebaseAuthSession> &&
        displayName != null &&
        displayName.trim().isNotEmpty) {
      await _postJson(
        'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$_apiKey',
        {
          'idToken': parsed.data.idToken,
          'displayName': displayName.trim(),
          'returnSecureToken': false,
        },
      );
    }
    return parsed;
  }

  Future<Result<void>> sendPasswordResetEmail(String email) async {
    if (!isEnabled) {
      return const Failure(
        AuthFailure(
          'خدمة استعادة كلمة السر عبر السحابة غير مهيّأة في هذه النسخة.',
        ),
      );
    }
    final res = await _postJson(
      'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$_apiKey',
      {
        'requestType': 'PASSWORD_RESET',
        'email': email,
      },
    );
    if (res is Failure<Map<String, dynamic>>) {
      return Failure(res.failure);
    }
    return const Success(null);
  }

  /// Refreshes an expired Firebase ID token using the stored refresh token.
  Future<Result<String>> refreshIdToken() async {
    if (!isEnabled) {
      return const Failure(AuthFailure('السحابة غير مفعّلة في هذه النسخة.'));
    }
    final refreshToken = await SecureStorageService.instance.read(
      SecureStorageKeys.refreshToken,
    );
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      _recordStatus(
        const CloudSyncStatus(
          state: CloudSyncState.authExpired,
          lastError: 'انتهت جلسة المزامنة السحابية. سجّل الدخول مرة تانية.',
        ),
      );
      return const Failure(
        AuthFailure('انتهت جلسة المزامنة السحابية. سجّل الدخول مرة تانية.'),
      );
    }
    final res = await _postJson(
      'https://securetoken.googleapis.com/v1/token?key=$_apiKey',
      {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    if (res is Failure<Map<String, dynamic>>) {
      _recordStatus(
        CloudSyncStatus(
          state: CloudSyncState.authExpired,
          lastSyncedAt: _lastSyncStatus.lastSyncedAt,
          lastError: res.failure.message,
        ),
      );
      return Failure(res.failure);
    }
    final data = (res as Success<Map<String, dynamic>>).data;
    final newIdToken = (data['id_token'] ?? data['idToken'] ?? '').toString();
    final newRefresh =
        (data['refresh_token'] ?? data['refreshToken'] ?? '').toString();
    if (newIdToken.isEmpty) {
      const failure =
          AuthFailure('انتهت صلاحية رمز المزامنة السحابية. سجّل الدخول تاني.');
      _recordStatus(
        CloudSyncStatus(
          state: CloudSyncState.authExpired,
          lastSyncedAt: _lastSyncStatus.lastSyncedAt,
          lastError: failure.message,
        ),
      );
      return const Failure(failure);
    }
    await SecureStorageService.instance.write(
      SecureStorageKeys.accessToken,
      newIdToken,
    );
    if (newRefresh.isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.refreshToken,
        newRefresh,
      );
    }
    return Success(newIdToken);
  }

  /// Uploads a workspace snapshot to Cloud Firestore with explicit size, auth,
  /// conflict, and network failure reporting.
  Future<Result<DateTime>> syncWorkspaceJson({
    required String userId,
    required String backupJson,
    DateTime? expectedRemoteUpdatedAt,
    bool forceOverwrite = false,
  }) async {
    if (!isEnabled || userId.trim().isEmpty) {
      _recordStatus(const CloudSyncStatus.localOnly());
      return const Failure(
        AuthFailure('المزامنة السحابية غير مفعّلة في هذه النسخة المحلية.'),
      );
    }

    final payloadBytes = utf8.encode(backupJson).length;
    if (payloadBytes > maxSafePayloadBytes) {
      const msg =
          'حجم النسخة السحابية تجاوز الحد الآمن لوثيقة السحابة (900 KB). استخدم التصدير المحلي (JSON) مؤقتًا.';
      _recordStatus(
        CloudSyncStatus(
          state: CloudSyncState.payloadTooLarge,
          lastSyncedAt: _lastSyncStatus.lastSyncedAt,
          lastError: msg,
        ),
      );
      return const Failure(ValidationFailure(msg));
    }

    var idToken = await SecureStorageService.instance.read(
      SecureStorageKeys.accessToken,
    );
    if (idToken == null || idToken.isEmpty) {
      const msg = 'لا يوجد رمز مصادقة سحابي نشط. سجّل الدخول لإعادة المزامنة.';
      _recordStatus(
        CloudSyncStatus(
          state: CloudSyncState.authExpired,
          lastSyncedAt: _lastSyncStatus.lastSyncedAt,
          lastError: msg,
        ),
      );
      return const Failure(AuthFailure(msg));
    }

    if (!forceOverwrite && expectedRemoteUpdatedAt != null) {
      final remoteMeta = await _fetchWorkspaceDocument(userId, idToken);
      if (remoteMeta is Success<({String? payload, DateTime? updatedAt})>) {
        final remoteTime = remoteMeta.data.updatedAt;
        if (remoteTime != null && remoteTime.isAfter(expectedRemoteUpdatedAt)) {
          const msg =
              'توجد نسخة أحدث محفوظة على السحابة من جلسة أخرى. استرجع النسخة السحابية أو أكّد الاستبدال لتجنب فقدان التعديلات.';
          _recordStatus(
            CloudSyncStatus(
              state: CloudSyncState.conflictDetected,
              lastSyncedAt: _lastSyncStatus.lastSyncedAt,
              lastError: msg,
            ),
          );
          return const Failure(ValidationFailure(msg));
        }
      }
    }

    final syncedAt = DateTime.now().toUtc();
    final url =
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/${Uri.encodeComponent(userId)}/workspaces/primary';
    final body = {
      'fields': {
        'userId': {'stringValue': userId},
        'payloadJson': {'stringValue': backupJson},
        'updatedAt': {'timestampValue': syncedAt.toIso8601String()},
      },
    };

    var res = await _requestJsonRaw(
      method: 'PATCH',
      url: url,
      bearerToken: idToken,
      body: body,
    );

    if (res is _RawHttpSuccess && res.statusCode == 401) {
      final refreshed = await refreshIdToken();
      if (refreshed is Failure<String>) {
        return Failure(refreshed.failure);
      }
      idToken = (refreshed as Success<String>).data;
      res = await _requestJsonRaw(
        method: 'PATCH',
        url: url,
        bearerToken: idToken,
        body: body,
      );
    }

    if (res is _RawHttpSuccess && res.statusCode >= 200 && res.statusCode < 300) {
      _recordStatus(
        CloudSyncStatus(
          state: CloudSyncState.synced,
          lastSyncedAt: syncedAt,
        ),
      );
      return Success(syncedAt);
    }

    final failure = _mapRawFailure(res);
    final nextState = (res is _RawHttpSuccess && res.statusCode == 401)
        ? CloudSyncState.authExpired
        : CloudSyncState.failed;
    _recordStatus(
      CloudSyncStatus(
        state: nextState,
        lastSyncedAt: _lastSyncStatus.lastSyncedAt,
        lastError: failure.message,
      ),
    );
    return Failure(failure);
  }

  Future<Result<({String? payload, DateTime? updatedAt})>>
      fetchWorkspaceSnapshot(String userId) async {
    if (!isEnabled || userId.trim().isEmpty) {
      return const Success((payload: null, updatedAt: null));
    }
    var idToken = await SecureStorageService.instance.read(
      SecureStorageKeys.accessToken,
    );
    if (idToken == null || idToken.isEmpty) {
      return const Failure(
        AuthFailure('لا يوجد رمز مصادقة سحابي نشط.'),
      );
    }
    var res = await _fetchWorkspaceDocument(userId, idToken);
    if (res is Failure<({String? payload, DateTime? updatedAt})> &&
        res.failure is AuthFailure) {
      final refreshed = await refreshIdToken();
      if (refreshed is Success<String>) {
        res = await _fetchWorkspaceDocument(userId, refreshed.data);
      }
    }
    return res;
  }

  Future<String?> fetchWorkspaceJson(String userId) async {
    final snap = await fetchWorkspaceSnapshot(userId);
    if (snap is Success<({String? payload, DateTime? updatedAt})>) {
      return snap.data.payload;
    }
    return null;
  }

  Future<Result<({String? payload, DateTime? updatedAt})>>
      _fetchWorkspaceDocument(String userId, String idToken) async {
    final url =
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/${Uri.encodeComponent(userId)}/workspaces/primary';
    final raw = await _requestJsonRaw(
      method: 'GET',
      url: url,
      bearerToken: idToken,
    );
    if (raw is _RawHttpSuccess) {
      if (raw.statusCode == 404) {
        return const Success((payload: null, updatedAt: null));
      }
      if (raw.statusCode >= 200 && raw.statusCode < 300) {
        final fields = raw.body['fields'];
        String? payload;
        DateTime? updatedAt;
        if (fields is Map) {
          final payloadField = fields['payloadJson'];
          if (payloadField is Map && payloadField['stringValue'] is String) {
            payload = payloadField['stringValue'] as String;
          }
          final updatedField = fields['updatedAt'];
          if (updatedField is Map && updatedField['timestampValue'] is String) {
            updatedAt = DateTime.tryParse(updatedField['timestampValue'] as String);
          }
        }
        return Success((payload: payload, updatedAt: updatedAt));
      }
    }
    return Failure(_mapRawFailure(raw));
  }

  Future<void> deleteUserCloudData(String? userId) async {
    if (!isEnabled) return;
    final idToken = await SecureStorageService.instance.read(
      SecureStorageKeys.accessToken,
    );
    if (idToken == null || idToken.isEmpty) return;

    if (userId != null && userId.trim().isNotEmpty) {
      final docUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/${Uri.encodeComponent(userId)}/workspaces/primary';
      await _requestJson(
        method: 'DELETE',
        url: docUrl,
        bearerToken: idToken,
      );
      final userUrl =
          'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/${Uri.encodeComponent(userId)}';
      await _requestJson(
        method: 'DELETE',
        url: userUrl,
        bearerToken: idToken,
      );
    }

    await _postJson(
      'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$_apiKey',
      {'idToken': idToken},
    );
  }

  Future<Result<FirebaseAuthSession>> _parseAuthResponse(
    Result<Map<String, dynamic>> res, {
    required String fallbackEmail,
    String? fallbackName,
  }) async {
    if (res is Failure<Map<String, dynamic>>) {
      return Failure(res.failure);
    }
    final data = (res as Success<Map<String, dynamic>>).data;
    final uid = (data['localId'] ?? '').toString();
    final idToken = (data['idToken'] ?? '').toString();
    final refreshToken = (data['refreshToken'] ?? '').toString();
    if (uid.isEmpty || idToken.isEmpty) {
      return const Failure(AuthFailure('استجابة غير صالحة من خادم المصادقة.'));
    }
    await SecureStorageService.instance.write(
      SecureStorageKeys.accessToken,
      idToken,
    );
    if (refreshToken.isNotEmpty) {
      await SecureStorageService.instance.write(
        SecureStorageKeys.refreshToken,
        refreshToken,
      );
    }
    return Success(
      FirebaseAuthSession(
        uid: uid,
        email: (data['email'] ?? fallbackEmail).toString(),
        idToken: idToken,
        refreshToken: refreshToken,
        displayName:
            (data['displayName']?.toString().trim().isNotEmpty == true)
                ? data['displayName'].toString().trim()
                : fallbackName,
      ),
    );
  }

  Future<Result<Map<String, dynamic>>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) =>
      _requestJson(method: 'POST', url: url, body: body);

  Future<Result<Map<String, dynamic>>> _requestJson({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final raw = await _requestJsonRaw(
      method: method,
      url: url,
      body: body,
      bearerToken: bearerToken,
    );
    if (raw is _RawHttpSuccess && raw.statusCode >= 200 && raw.statusCode < 300) {
      return Success(raw.body);
    }
    return Failure(_mapRawFailure(raw));
  }

  AppFailure _mapRawFailure(_RawHttpResult raw) {
    if (raw is _RawHttpNetworkError) {
      return const NetworkFailure();
    }
    final ok = raw as _RawHttpSuccess;
    if (ok.statusCode == 401) {
      return const AuthFailure('انتهت جلسة المزامنة السحابية. سجّل الدخول مرة تانية.');
    }
    final errCode = ((ok.body['error'] is Map)
            ? (ok.body['error']['message'] ?? '')
            : '')
        .toString();
    if (errCode.contains('INVALID_LOGIN_CREDENTIALS') ||
        errCode.contains('INVALID_PASSWORD')) {
      return const InvalidCredentialsFailure();
    }
    if (errCode.contains('EMAIL_NOT_FOUND')) {
      return const UserNotFoundFailure();
    }
    if (errCode.contains('EMAIL_EXISTS')) {
      return const EmailAlreadyInUseFailure();
    }
    if (errCode.contains('WEAK_PASSWORD')) {
      return const WeakPasswordFailure();
    }
    return const AuthFailure('تعذّر إتمام العملية عبر الخادم حاليًا.');
  }

  Future<_RawHttpResult> _requestJsonRaw({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    if (_httpExecutor != null) {
      try {
        final resp = await _httpExecutor(
          method: method,
          url: url,
          body: body,
          bearerToken: bearerToken,
        );
        return _RawHttpSuccess(statusCode: resp.statusCode, body: resp.body);
      } catch (e) {
        AppLogger.warning('Cloud request failed', tag: _tag, error: e);
        return const _RawHttpNetworkError();
      }
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse(url);
      final req = await client.openUrl(method, uri);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      if (bearerToken != null && bearerToken.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
      }
      if (body != null) {
        final encoded = utf8.encode(jsonEncode(body));
        req.contentLength = encoded.length;
        req.add(encoded);
      }
      final resp = await req.close().timeout(const Duration(seconds: 12));
      final raw = await resp.transform(utf8.decoder).join();
      final decoded =
          raw.isNotEmpty ? jsonDecode(raw) : const <String, dynamic>{};
      final map = decoded is Map
          ? decoded.cast<String, dynamic>()
          : <String, dynamic>{};
      return _RawHttpSuccess(statusCode: resp.statusCode, body: map);
    } catch (e) {
      AppLogger.warning('Cloud request failed', tag: _tag, error: e);
      return const _RawHttpNetworkError();
    } finally {
      client.close(force: true);
    }
  }
}

sealed class _RawHttpResult {
  const _RawHttpResult();
}

final class _RawHttpSuccess extends _RawHttpResult {
  const _RawHttpSuccess({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic> body;
}

final class _RawHttpNetworkError extends _RawHttpResult {
  const _RawHttpNetworkError();
}
