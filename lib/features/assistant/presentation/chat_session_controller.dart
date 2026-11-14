import 'dart:async';

import 'package:ai_assistant/ai_assistant.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ChatSessionController extends ChangeNotifier {
  ChatSessionController({AIAssistantController? assistant, Uuid? uuid})
      // ignore: prefer_initializing_formals
      : _assistant = assistant,
        _uuid = uuid ?? const Uuid();

  AIAssistantController? _assistant;
  final Uuid _uuid;
  bool _initializing = false;
  bool _disposed = false;

  StreamSubscription<AssistantState>? _stateSub;
  StreamSubscription<AssistantEvent>? _eventSub;
  StreamSubscription<AssistantResponse>? _responseSub;

  List<ConversationMessage> _messages = const [];
  List<ConversationMetadata> _conversations = const [];
  String _currentConversationId = '';
  bool _isSending = false;
  String? _error;
  String? _pendingText;
  String? _pendingMessageId;
  AssistantState _assistantState = AssistantState.idle;
  String _partialTranscript = '';

  List<ConversationMessage> get messages => _messages;
  List<ConversationMetadata> get conversations => _conversations;
  String get currentConversationId => _currentConversationId;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get canRetry => _pendingText != null && !_isSending;
  AssistantState get assistantState => _assistantState;
  String get partialTranscript => _partialTranscript;
  bool get isVoiceBusy =>
      _assistantState == AssistantState.listening ||
      _assistantState == AssistantState.transcribing ||
      _assistantState == AssistantState.thinking ||
      _assistantState == AssistantState.executing ||
      _assistantState == AssistantState.speaking;

  void bind(AIAssistantController assistant) {
    if (identical(_assistant, assistant)) return;
    _cancelSubscriptions();
    _assistant = assistant;
    _assistantState = assistant.state;

    _stateSub = assistant.stateStream.listen((next) {
      _assistantState = next;
      if (next == AssistantState.idle) {
        _partialTranscript = '';
      }
      notifyListeners();
    });

    _eventSub = assistant.events.listen((event) {
      if (event.kind == AssistantEventKind.partialTranscript ||
          event.kind == AssistantEventKind.finalTranscript) {
        _partialTranscript = event.text ?? '';
        notifyListeners();
      } else if (event.kind == AssistantEventKind.error &&
          event.text != null &&
          event.text!.isNotEmpty) {
        _error = event.text;
        notifyListeners();
      }
    });

    _responseSub = assistant.responses.listen((resp) async {
      await _loadMessages();
      if (_assistant != null) {
        _conversations = await _assistant!.conversations.listConversations();
      }
      if (resp.type == AssistantResponse.typeError) {
        _error = resp.text;
      } else {
        _error = null;
      }
      notifyListeners();
    });

    initialize();
  }

  void _cancelSubscriptions() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    _responseSub?.cancel();
    _stateSub = null;
    _eventSub = null;
    _responseSub = null;
  }

  void reportError(String message) {
    _error = message;
    _initializing = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    final assistant = _assistant;
    if (assistant == null || _initializing || _isSending) return;
    _initializing = true;
    _error = null;
    notifyListeners();
    try {
      _conversations = await assistant.conversations.listConversations();
      if (_conversations.isNotEmpty) {
        _currentConversationId = _conversations.first.id;
        await _loadMessages();
      } else {
        _currentConversationId = _newConversationId();
        _messages = const [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshConversations() async {
    final assistant = _assistant;
    if (assistant == null) return;
    _conversations = await assistant.conversations.listConversations();
    notifyListeners();
  }

  Future<void> newConversation() async {
    if (_isSending) return;
    _currentConversationId = _newConversationId();
    _messages = const [];
    _clearPending();
    notifyListeners();
  }

  Future<void> selectConversation(String id) async {
    if (_isSending || id == _currentConversationId) return;
    _currentConversationId = id;
    _clearPending();
    try {
      await _loadMessages();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> toggleVoice() async {
    final assistant = _assistant;
    if (assistant == null) return;
    _error = null;
    if (_assistantState == AssistantState.listening) {
      await assistant.stopVoiceInteraction();
    } else if (isVoiceBusy) {
      await assistant.cancelInteraction();
    } else {
      await assistant.startVoiceInteraction(
        conversationId: _currentConversationId,
      );
    }
  }

  Future<void> stopVoiceOrSpeaking() async {
    final assistant = _assistant;
    if (assistant == null) return;
    if (_assistantState == AssistantState.listening) {
      await assistant.stopVoiceInteraction();
    } else {
      await assistant.cancelInteraction();
    }
  }

  Future<void> send(String text, {String? messageId}) async {
    final assistant = _assistant;
    final cleaned = text.trim();
    if (assistant == null || cleaned.isEmpty || _isSending) return;
    final id = messageId ?? _uuid.v4();
    _isSending = true;
    _error = null;
    _pendingText = cleaned;
    _pendingMessageId = id;
    if (!_messages.any((m) => m.id == id)) {
      _messages = [..._messages, ConversationMessage.user(cleaned, id: id)];
    }
    notifyListeners();

    try {
      final response = await assistant.sendTextMessage(
        cleaned,
        conversationId: _currentConversationId,
        messageId: id,
        speak: false,
      );
      await _loadMessages();
      _conversations = await assistant.conversations.listConversations();
      if (response.type == AssistantResponse.typeError) {
        _error = response.text;
      } else if (response.type == AssistantResponse.typeResponse) {
        _clearPending();
      }
    } catch (_) {
      _error = 'الرد ما وصلش. رسالتك محفوظة وتقدر تجرب تاني.';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> retry() {
    final text = _pendingText;
    final id = _pendingMessageId;
    if (text == null || id == null) return Future<void>.value();
    return send(text, messageId: id);
  }

  Future<void> _loadMessages() async {
    final history =
        await _assistant!.conversations.history(_currentConversationId);
    _messages = history
        .where(
          (m) =>
              (m.role == MessageRole.user || m.role == MessageRole.assistant) &&
              m.content.trim().isNotEmpty,
        )
        .toList();
  }

  void _clearPending() {
    _error = null;
    _pendingText = null;
    _pendingMessageId = null;
  }

  String _newConversationId() => 'conversation_${_uuid.v4()}';

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelSubscriptions();
    super.dispose();
  }
}
