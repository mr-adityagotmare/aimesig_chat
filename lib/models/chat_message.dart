class ChatMessage {
  final String id;

  final String sender;
  final String receiver;

  final String message;

  final int timestamp;

  final bool mine;

  bool delivered;

  bool read;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.timestamp,
    required this.mine,
    this.delivered = false,
    this.read = false,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "sender": sender,
      "receiver": receiver,
      "message": message,
      "timestamp": timestamp,
      "mine": mine ? 1 : 0,
      "delivered": delivered ? 1 : 0,
      "read": read ? 1 : 0,
    };
  }

  factory ChatMessage.fromMap(
    Map<String, dynamic> map,
  ) {
    return ChatMessage(
      id: map["id"],

      sender: map["sender"],
      receiver: map["receiver"],

      message: map["message"],

      timestamp: map["timestamp"],

      mine: map["mine"] == 1,

      delivered: map["delivered"] == 1,

      read: map["read"] == 1,
    );
  }
}