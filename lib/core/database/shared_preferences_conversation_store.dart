import 'dart:async';
import 'dart:convert';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../secure_storage/secure_storage_service.dart';

class SharedPreferencesConversationStore implements ConversationStore {
  SharedPreferencesConversationStore._(
    this._prefs,
    this._key,
    this._states,
  );

  static const schemaVersion = 1;

  final SharedPreferences? _prefs;
  final String _key;
  final Map<String, ConversationState> _states;
  Completer<void>? _activeLock;

  static Future<SharedPreferencesConversationStore> open({
    required String userId,
    SharedPreferences? preferences,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }
    final prefs = preferences;
    final key = 'ai_conversations_${userId.trim()}';
    final states = <String, ConversationState>{};
    final raw = preferences != null
        ? prefs!.getString(key)
        : await SecureStorageService.instance.read(key);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Conversation storage is not an object');
      }
      final json = Map<String, dynamic>.from(decoded);
      final version = json['schema_version'];
      if (version != schemaVersion) {
        throw FormatException('Unsupported conversation schema: $version');
      }
      final conversations = json['conversations'];
      if (conversations is! List) {
        throw const FormatException('Conversation list is missing');
      }
      for (final value in conversations) {
        if (value is! Map) {
          throw const FormatException('Invalid conversation record');
        }
        final state = ConversationState.fromJson(
          Map<String, dynamic>.from(value),
        );
        states[state.metadata.id] = state;
      }
    }
    return SharedPreferencesConversationStore._(preferences, key, states);
  }

  @override
  Future<ConversationState> load(String conversationId) async {
    _validateId(conversationId);
    return _states.putIfAbsent(conversationId, () {
      final now = DateTime.now();
      return ConversationState(
        metadata: ConversationMetadata(
          id: conversationId,
          title: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<List<ConversationMetadata>> list() async {
    final result = _states.values
        .where((s) => s.messages.isNotEmpty)
        .map((s) => s.metadata)
        .toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<void> save(String conversationId, ConversationState state) {
    _validateId(conversationId);
    if (state.metadata.id != conversationId) {
      throw ArgumentError('Conversation metadata id does not match the key');
    }
    _states[conversationId] = state;
    return _enqueueWrite();
  }

  @override
  Future<void> clear(String conversationId) {
    _validateId(conversationId);
    _states.remove(conversationId);
    return _enqueueWrite();
  }

  Future<void> flush() async {
    while (_activeLock != null) {
      try {
        await _activeLock!.future;
      } catch (_) {}
    }
  }

  Future<void> _enqueueWrite() async {
    final snapshot = jsonEncode({
      'schema_version': schemaVersion,
      'conversations': _states.values.map((s) => s.toJson()).toList(),
    });
    while (_activeLock != null) {
      try {
        await _activeLock!.future;
      } catch (_) {}
    }
    final lock = Completer<void>();
    _activeLock = lock;
    try {
      final prefs = _prefs;
      if (prefs != null) {
        final saved = await prefs.setString(_key, snapshot);
        if (!saved) throw StateError('Conversation storage write was rejected');
      } else {
        await SecureStorageService.instance.write(_key, snapshot);
      }
    } finally {
      _activeLock = null;
      lock.complete();
    }
  }

  static Future<void> clearForUser(String userId, {SharedPreferences? preferences}) async {
    final key = 'ai_conversations_${userId.trim()}';
    if (preferences != null) {
      await preferences.remove(key);
    } else {
      await SecureStorageService.instance.delete(key);
    }
  }

  void _validateId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'conversationId', 'Must not be empty');
    }
  }
}
