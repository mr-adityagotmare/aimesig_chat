enum MessageType { text, file, image }

class ChatMessage {
  final String id;
  final String sender;
  final String receiver;
  final String message; // text content OR file name for file messages
  final int timestamp;
  final bool mine;

  bool delivered;
  bool read;

  // File transfer fields
  final MessageType type;
  final String? filePath;   // local path after receive / before send
  final String? fileName;
  final int? fileSize;

  // Transfer progress (transient — not persisted)
  double transferProgress;
  bool transferFailed;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.timestamp,
    required this.mine,
    this.delivered = false,
    this.read = false,
    this.type = MessageType.text,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.transferProgress = 0.0,
    this.transferFailed = false,
  });

  bool get isFile => type == MessageType.file || type == MessageType.image;

  bool get isImage {
    if (type == MessageType.image) return true;
    final name = (fileName ?? message).toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'receiver': receiver,
      'message': message,
      'timestamp': timestamp,
      'mine': mine ? 1 : 0,
      'delivered': delivered ? 1 : 0,
      'read': read ? 1 : 0,
      'type': type.index,
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['type'] as int?) ?? 0;
    return ChatMessage(
      id: map['id'],
      sender: map['sender'],
      receiver: map['receiver'],
      message: map['message'],
      timestamp: map['timestamp'],
      mine: map['mine'] == 1,
      delivered: map['delivered'] == 1,
      read: map['read'] == 1,
      type: MessageType.values[typeIndex.clamp(0, MessageType.values.length - 1)],
      filePath: map['filePath'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
    );
  }

  ChatMessage copyWith({
    double? transferProgress,
    bool? transferFailed,
    bool? delivered,
    bool? read,
    String? filePath,
  }) {
    return ChatMessage(
      id: id,
      sender: sender,
      receiver: receiver,
      message: message,
      timestamp: timestamp,
      mine: mine,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
      type: type,
      filePath: filePath ?? this.filePath,
      fileName: fileName,
      fileSize: fileSize,
      transferProgress: transferProgress ?? this.transferProgress,
      transferFailed: transferFailed ?? this.transferFailed,
    );
  }
}