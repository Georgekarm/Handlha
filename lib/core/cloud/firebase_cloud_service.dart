import 'dart:convert';
import 'dart:io';

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

/// Pure-Dart Firebase Auth (Identity Toolkit v1) & Cloud Firestore REST sync client.
/// Activates automatically when `FIREBASE_API_KEY` and `FIREBASE_PROJECT_ID`
/// are supplied via `--dart-define`, while degrading cleanly to local-first
/// storage in offline or test environments.
class FirebaseCloudService {
  FirebaseCloudService._();

  static final FirebaseCloudService instance = FirebaseCloudService._();
  static const String _tag = 'FirebaseCloud';

  bool get isEnabled => FirebaseCloudConfig.isConfigured;

  Future<Result<FirebaseAuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!isEnabled) {
      return const Failure(AuthFailure('Cloud Auth is not configured.'));
    }
    final res = await _postJson(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FirebaseCloudConfig.apiKey}',
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
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FirebaseCloudConfig.apiKey}',
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
        'https://identitytoolkit.googleapis.com/v1/accounts:update?key=${FirebaseCloudConfig.apiKey}',
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
      'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${FirebaseCloudConfig.apiKey}',
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

  Future<void> syncWorkspaceJson({
    required String userId,
    required String backupJson,
  }) async {
    if (!isEnabled || userId.trim().isEmpty) return;
    final idToken = await SecureStorageService.instance.read(
      SecureStorageKeys.accessToken,
    );
    if (idToken == null || idToken.isEmpty) return;
    final url =
        'https://firestore.googleapis.com/v1/projects/${FirebaseCloudConfig.projectId}/databases/(default)/documents/users/${Uri.encodeComponent(userId)}/workspaces/primary';
    await _requestJson(
      method: 'PATCH',
      url: url,
      bearerToken: idToken,
      body: {
        'fields': {
          'userId': {'stringValue': userId},
          'payloadJson': {'stringValue': backupJson},
          'updatedAt': {
            'timestampValue': DateTime.now().toUtc().toIso8601String(),
          },
        },
      },
    );
  }

  Future<String?> fetchWorkspaceJson(String userId) async {
    if (!isEnabled || userId.trim().isEmpty) return null;
    final idToken = await SecureStorageService.instance.read(
      SecureStorageKeys.accessToken,
    );
    if (idToken == null || idToken.isEmpty) return null;
    final url =
        'https://firestore.googleapis.com/v1/projects/${FirebaseCloudConfig.projectId}/databases/(default)/documents/users/${Uri.encodeComponent(userId)}/workspaces/primary';
    final res = await _requestJson(
      method: 'GET',
      url: url,
      bearerToken: idToken,
    );
    if (res is Success<Map<String, dynamic>>) {
      final fields = res.data['fields'];
      if (fields is Map) {
        final payload = fields['payloadJson'];
        if (payload is Map && payload['stringValue'] is String) {
          return payload['stringValue'] as String;
        }
      }
    }
    return null;
  }

  Future<void> deleteUserCloudData(String? userId) async {
    if (!isEnabled) return;
    final idToken = await SecureStorageService.instance.read(
      SecureStorageKeys.accessToken,
    );
    if (idToken == null || idToken.isEmpty) return;

    if (userId != null && userId.trim().isNotEmpty) {
      final docUrl =
          'https://firestore.googleapis.com/v1/projects/${FirebaseCloudConfig.projectId}/databases/(default)/documents/users/${Uri.encodeComponent(userId)}/workspaces/primary';
      await _requestJson(
        method: 'DELETE',
        url: docUrl,
        bearerToken: idToken,
      );
      final userUrl =
          'https://firestore.googleapis.com/v1/projects/${FirebaseCloudConfig.projectId}/databases/(default)/documents/users/${Uri.encodeComponent(userId)}';
      await _requestJson(
        method: 'DELETE',
        url: userUrl,
        bearerToken: idToken,
      );
    }

    await _postJson(
      'https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${FirebaseCloudConfig.apiKey}',
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
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse(url);
      final req = await client.openUrl(method, uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
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
      final decoded = raw.isNotEmpty ? jsonDecode(raw) : const <String, dynamic>{};
      final map = decoded is Map
          ? decoded.cast<String, dynamic>()
          : <String, dynamic>{};
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return Success(map);
      }
      final errCode = ((map['error'] is Map)
              ? (map['error']['message'] ?? '')
              : '')
          .toString();
      if (errCode.contains('INVALID_LOGIN_CREDENTIALS') ||
          errCode.contains('INVALID_PASSWORD')) {
        return const Failure(InvalidCredentialsFailure());
      }
      if (errCode.contains('EMAIL_NOT_FOUND')) {
        return const Failure(UserNotFoundFailure());
      }
      if (errCode.contains('EMAIL_EXISTS')) {
        return const Failure(EmailAlreadyInUseFailure());
      }
      if (errCode.contains('WEAK_PASSWORD')) {
        return const Failure(WeakPasswordFailure());
      }
      return const Failure(AuthFailure('تعذّر إتمام العملية عبر الخادم حاليًا.'));
    } catch (e) {
      AppLogger.warning('Cloud request failed', tag: _tag, error: e);
      return const Failure(NetworkFailure());
    } finally {
      client.close(force: true);
    }
  }
}
