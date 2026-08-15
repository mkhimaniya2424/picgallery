import '../core/network/api_client.dart';
import '../models/chat_message_model.dart';

/// A thread summary as returned by `GET /chat/threads`.
class ChatThreadSummary {
  final String id;
  final String connectionId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String otherPartyName;
  final String? otherPartyAvatar;

  ChatThreadSummary({
    required this.id,
    required this.connectionId,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.otherPartyName,
    this.otherPartyAvatar,
  });

  factory ChatThreadSummary.fromApiJson(Map<String, dynamic> json) =>
      ChatThreadSummary(
        id: json['id'] as String,
        connectionId: json['connection_id'] as String,
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'] as String)
            : null,
        lastMessagePreview: json['last_message_preview'] as String?,
        otherPartyName: json['other_party_name'] as String? ?? 'Unknown',
        otherPartyAvatar: json['other_party_avatar'] as String?,
      );
}

abstract class ChatRepository {
  Future<List<ChatThreadSummary>> fetchThreads();
  Future<List<ChatMessageModel>> fetchMessages(String threadId,
      {int limit = 50, int offset = 0});
  Future<ChatMessageModel> sendMessage(
      String threadId, String connectionId, String text);
  Future<ChatMessageModel> sendMessageByConnection(
      String connectionId, String text);
}

/// API-backed chat repository talking to `app/api/routes/chat.py`
/// via [ApiClient] — mirrors [ApiConnectionsRepository]'s shape.
class ApiChatRepository implements ChatRepository {
  ApiChatRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ChatThreadSummary>> fetchThreads() async {
    final json = await _apiClient.get('/chat/threads');
    final list = json as List<dynamic>;
    return list
        .map((e) => ChatThreadSummary.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<ChatMessageModel>> fetchMessages(String threadId,
      {int limit = 50, int offset = 0}) async {
    final json = await _apiClient.get(
      '/chat/threads/$threadId/messages?limit=$limit&offset=$offset',
    );
    final data = json as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items
        .map((e) =>
            ChatMessageModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<ChatMessageModel> sendMessage(
      String threadId, String connectionId, String text) async {
    final json = await _apiClient.post(
      '/chat/threads/$threadId/messages',
      body: {'text': text},
    );
    return ChatMessageModel.fromApiJson(json as Map<String, dynamic>);
  }

  @override
  Future<ChatMessageModel> sendMessageByConnection(
      String connectionId, String text) async {
    final json = await _apiClient.post(
      '/chat/by-connection/$connectionId/messages',
      body: {'text': text},
    );
    return ChatMessageModel.fromApiJson(json as Map<String, dynamic>);
  }
}
