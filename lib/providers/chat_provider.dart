import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import 'auth_providers.dart';

/// Provider for the API-backed chat repository.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ApiChatRepository(apiClient: ref.watch(apiClientProvider));
});

/// Current user id — used by [ChatNotifier] to determine "my" side vs the
/// other party, and the sender_role for messages.
final _currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).user?.id;
});

/// Holds both the thread list and the per-thread message cache.
class ChatState {
  final List<ChatThreadSummary> threads;
  final Map<String, List<ChatMessageModel>> messagesByThread;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.threads = const [],
    this.messagesByThread = const {},
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatThreadSummary>? threads,
    Map<String, List<ChatMessageModel>>? messagesByThread,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      threads: threads ?? this.threads,
      messagesByThread: messagesByThread ?? this.messagesByThread,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<ChatMessageModel> messagesForThread(String threadId) {
    return messagesByThread[threadId] ?? [];
  }
}

class ChatNotifier extends Notifier<ChatState> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  String? get _currentUserId => ref.read(_currentUserIdProvider);

  Timer? _pollTimer;

  @override
  ChatState build() {
    _fetchThreads();
    _startPolling();
    ref.onDispose(() => _pollTimer?.cancel());
    return const ChatState();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Poll every 10 seconds for new messages
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchThreads();
      // Also refresh messages for any thread we have cached
      final currentThreads = state.threads;
      for (final t in currentThreads) {
        _fetchMessages(t.id, silently: true);
      }
    });
  }

  /// Fetches the thread list from the API.
  Future<void> _fetchThreads() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final threads = await _repo.fetchThreads();
      state = state.copyWith(threads: threads, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load chat threads.',
      );
    }
  }

  /// Fetches messages for a given thread. When [silently] is true, the
  /// loading indicator isn't set — used by the polling timer so the UI
  /// doesn't flicker on every poll cycle.
  Future<void> _fetchMessages(String threadId, {bool silently = false}) async {
    if (!silently) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final messages = await _repo.fetchMessages(threadId);
      final updatedCache = Map<String, List<ChatMessageModel>>.from(
        state.messagesByThread,
      );
      updatedCache[threadId] = messages;
      state = state.copyWith(
        messagesByThread: updatedCache,
        isLoading: silently ? state.isLoading : false,
      );
    } catch (e) {
      if (!silently) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not load messages.',
        );
      }
    }
  }

  /// Public: re-fetches the thread list (pull-to-refresh).
  Future<void> refresh() => _fetchThreads();

  /// Public: loads messages for a given thread id.
  Future<void> loadMessages(String threadId) => _fetchMessages(threadId);

  /// Sends a message via the convenience endpoint
  /// (`POST /chat/by-connection/{connectionId}/messages`). The thread
  /// is auto-created server-side if it doesn't exist yet.
  Future<void> sendMessageByConnection(
    String connectionId,
    String text,
  ) async {
    try {
      final message = await _repo.sendMessageByConnection(connectionId, text);
      // Optimistically add to the local cache
      final threadId = message.connectionId; // thread_id == connectionId
      final updatedCache = Map<String, List<ChatMessageModel>>.from(
        state.messagesByThread,
      );
      final existing = List<ChatMessageModel>.from(
        updatedCache[threadId] ?? [],
      );
      existing.add(message);
      updatedCache[threadId] = existing;
      state = state.copyWith(messagesByThread: updatedCache);

      // Refresh threads to update last_message_at/preview
      _fetchThreads();
    } catch (e) {
      state = state.copyWith(error: 'Failed to send message.');
    }
  }

  /// Sends a message to an existing thread.
  Future<void> sendMessage(String threadId, String text) async {
    try {
      // We need the connectionId — find it from threads
      final thread = state.threads.where((t) => t.id == threadId).firstOrNull;
      final connectionId = thread?.connectionId ?? threadId;
      final message = await _repo.sendMessage(threadId, connectionId, text);
      // Optimistically add to the local cache
      final updatedCache = Map<String, List<ChatMessageModel>>.from(
        state.messagesByThread,
      );
      final existing = List<ChatMessageModel>.from(
        updatedCache[threadId] ?? [],
      );
      existing.add(message);
      updatedCache[threadId] = existing;
      state = state.copyWith(messagesByThread: updatedCache);

      // Refresh threads to update last_message_at/preview
      _fetchThreads();
    } catch (e) {
      state = state.copyWith(error: 'Failed to send message.');
    }
  }

  /// Returns messages for a thread sorted chronologically.
  List<ChatMessageModel> messagesForConnection(String threadId) {
    final msgs = state.messagesForThread(threadId);
    final sorted = List<ChatMessageModel>.from(msgs);
    sorted.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return sorted;
  }

  /// Marks all messages in a thread from the other party as read — the
  /// API does this automatically on `GET /messages`, but we also track
  /// it locally for instant UI feedback.
  void markAsRead(String threadId) {
    final updatedCache = Map<String, List<ChatMessageModel>>.from(
      state.messagesByThread,
    );
    final existing = updatedCache[threadId];
    if (existing == null) return;
    updatedCache[threadId] = existing
        .map((m) => m.senderId != _currentUserId ? m.copyWith(isRead: true) : m)
        .toList();
    state = state.copyWith(messagesByThread: updatedCache);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

