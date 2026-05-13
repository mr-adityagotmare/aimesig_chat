import 'package:flutter/material.dart';

import '../core/database/database_helper.dart';

import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
    String? currentOpenChat;
  final Map<String, List<ChatMessage>> _messages =
      {};

  Map<String, List<ChatMessage>> get messages =>
      _messages;

  List<ChatMessage> getMessages(String peer) {
    return _messages[peer] ?? [];
  }

  int unreadCount(String peer) {
    return _messages[peer]
            ?.where(
              (e) => !e.mine && !e.read,
            )
            .length ??
        0;
  }

  Future<void> addMessage(
    String peer,
    ChatMessage message,
  ) async {
    _messages.putIfAbsent(peer, () => []);

    _messages[peer]!.add(message);

    notifyListeners();

    final db = await DatabaseHelper.database;

    await db.insert(
      "messages",
      message.toMap(),
    );
  }

  Future<void> markDelivered(
    String messageId,
  ) async {
    for (final chat in _messages.values) {
      for (final msg in chat) {
        if (msg.id == messageId) {
          msg.delivered = true;
        }
      }
    }

    notifyListeners();

    final db = await DatabaseHelper.database;

    await db.update(
      "messages",
      {
        "delivered": 1,
      },
      where: "id=?",
      whereArgs: [messageId],
    );
  }

  void openChat(String peer) {
  currentOpenChat = peer;

  notifyListeners();
}

void closeChat() {
  currentOpenChat = null;

  notifyListeners();
}


Future<void> clearChat(String peer) async {
  _messages[peer]?.clear();

  notifyListeners();

  final db = await DatabaseHelper.database;

  await db.delete(
    'messages',
    where: 'sender=? OR receiver=?',
    whereArgs: [peer, peer],
  );
}



  Future<void> markRead(
    String messageId,
  ) async {
    for (final chat in _messages.values) {
      for (final msg in chat) {
        if (msg.id == messageId) {
          msg.read = true;
        }
      }
    }

    notifyListeners();

    final db = await DatabaseHelper.database;

    await db.update(
      "messages",
      {
        "read": 1,
      },
      where: "id=?",
      whereArgs: [messageId],
    );
  }

  Future<void> markChatRead(
    String peer,
  ) async {
    final msgs = _messages[peer];

    if (msgs == null) return;

    final db = await DatabaseHelper.database;

    for (final msg in msgs) {
      if (!msg.mine) {
        msg.read = true;

        await db.update(
          "messages",
          {
            "read": 1,
          },
          where: "id=?",
          whereArgs: [msg.id],
        );
      }
    }

    notifyListeners();
  }


Future<void> deleteChat(String peer) async {
  _messages.remove(peer);

  notifyListeners();

  final db = await DatabaseHelper.database;

  await db.delete(
    'messages',
    where: 'sender=? OR receiver=?',
    whereArgs: [peer, peer],
  );
}

  Future<void> loadMessages() async {
    final db = await DatabaseHelper.database;

    final result = await db.query(
      "messages",
      orderBy: "timestamp ASC",
    );

    _messages.clear();

    for (final row in result) {
      final msg = ChatMessage.fromMap(row);

      final peer = msg.mine
          ? msg.receiver
          : msg.sender;

      _messages.putIfAbsent(peer, () => []);

      _messages[peer]!.add(msg);
    }

    notifyListeners();
  }
}