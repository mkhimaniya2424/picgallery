class ChatMessageModel {
  final String id;
  final String connectionId;
  final String senderId;
  final String senderRole; // 'client' or 'studio'
  final String text;
  final DateTime sentAt;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    this.isRead = false,
  });

  ChatMessageModel copyWith({
    String? id,
    String? connectionId,
    String? senderId,
    String? senderRole,
    String? text,
    DateTime? sentAt,
    bool? isRead,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      connectionId: connectionId ?? this.connectionId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'connectionId': connectionId,
        'senderId': senderId,
        'senderRole': senderRole,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
        'isRead': isRead,
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        connectionId: json['connectionId'] as String,
        senderId: json['senderId'] as String,
        senderRole: json['senderRole'] as String,
        text: json['text'] as String,
        sentAt: json['sentAt'] != null
            ? DateTime.parse(json['sentAt'] as String)
            : DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
      );

  /// Serializes this model for the real backend API — mirrors
  /// `ChatMessageRead` in `app/schemas/chat.py`.
  ///
  /// The API uses `thread_id` (not `connectionId`), `sender_role`
  /// (not `senderRole`), and `created_at` (not `sentAt`) — all
  /// different key names from the local [toJson] shape.
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'thread_id': connectionId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'text': text,
        'is_read': isRead,
        'created_at': sentAt.toIso8601String(),
      };

  /// Parses one message from the real backend's `ChatMessageRead`
  /// response shape (`GET /chat/threads/{id}/messages`,
  /// `POST /chat/threads/{id}/messages`).
  ///
  /// API fields map as:
  ///   `thread_id` -> `connectionId` (in this model, thread == connection)
  ///   `sender_role` -> `senderRole`
  ///   `created_at` -> `sentAt`
  factory ChatMessageModel.fromApiJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        connectionId: json['thread_id'] as String,
        senderId: json['sender_id'] as String,
        senderRole: json['sender_role'] as String? ?? 'client',
        text: json['text'] as String,
        sentAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        isRead: json['is_read'] as bool? ?? false,
      );
}
