enum MessageType { text, image }

/// One chat message between a student and their center — currently backed
/// by dummy, in-memory data ([ChatScreen]'s local state) rather than a real
/// `/chat` endpoint.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.body,
    required this.senderId,
    required this.receiverId,
    this.type = MessageType.text,
    required this.isMine,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String body;
  final int senderId;
  final int receiverId;
  final MessageType type;
  final bool isMine;
  final DateTime createdAt;
  final DateTime? readAt;
}
