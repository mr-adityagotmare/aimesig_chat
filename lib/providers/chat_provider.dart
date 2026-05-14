import 'package:flutter/material.dart';

import '../core/database/database_helper.dart';
import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  String? currentOpenChat;
  final Map<String, List<ChatMessage>> _messages = {};

  Map<String, List<ChatMessage>> get messages => _messages;

  List<ChatMessage> getMessages(String peer) => _messages[peer] ?? [];

  int get totalUnread => _messages.values
      .expand((msgs) => msgs)
      .where((m) => !m.mine && !m.read)
      .length;

  int unreadCount(String peer) =>
      _messages[peer]?.where((e) => !e.mine && !e.read).length ?? 0;

  // ── Add / update ────────────────────────────────────────────────────────────

  Future<void> addMessage(String peer, ChatMessage message) async {
    _messages.putIfAbsent(peer, () => []);
    _messages[peer]!.add(message);
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.insert('messages', message.toMap());
  }

  /// Update transient transfer progress (not persisted).
  void updateTransferProgress(String messageId, double progress) {
    _mutateMessage(messageId, (msg) {
      msg.transferProgress = progress;
    });
    notifyListeners();
  }

  /// Reset a failed transfer so the bubble shows progress again.
  void resetTransferFailed(String messageId) {
    _mutateMessage(messageId, (msg) {
      msg.transferFailed = false;
      msg.transferProgress = 0.0;
    });
    notifyListeners();
  }

  /// Mark a file transfer as failed (not persisted).
  void markTransferFailed(String messageId) {
    _mutateMessage(messageId, (msg) {
      msg.transferFailed = true;
    });
    notifyListeners();
  }

  /// Update the saved file path after download completes.
  Future<void> updateFilePath(String messageId, String path) async {
    // Replace the message object with a copy that has the new path
    for (final chat in _messages.values) {
      for (int i = 0; i < chat.length; i++) {
        if (chat[i].id == messageId) {
          chat[i] = chat[i].copyWith(filePath: path, transferProgress: 1.0);
          notifyListeners();

          final db = await DatabaseHelper.database;
          await db.update(
            'messages',
            {'filePath': path, 'delivered': 1},
            where: 'id=?',
            whereArgs: [messageId],
          );
          return;
        }
      }
    }
  }

  // ── Status updates ───────────────────────────────────────────────────────────

  Future<void> markDelivered(String messageId) async {
    _mutateMessage(messageId, (msg) => msg.delivered = true);
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.update('messages', {'delivered': 1},
        where: 'id=?', whereArgs: [messageId]);
  }

  Future<void> markRead(String messageId) async {
    _mutateMessage(messageId, (msg) => msg.read = true);
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.update('messages', {'read': 1},
        where: 'id=?', whereArgs: [messageId]);
  }

  Future<void> markChatRead(String peer) async {
    final msgs = _messages[peer];
    if (msgs == null) return;

    final db = await DatabaseHelper.database;
    for (final msg in msgs) {
      if (!msg.mine && !msg.read) {
        msg.read = true;
        await db.update('messages', {'read': 1},
            where: 'id=?', whereArgs: [msg.id]);
      }
    }
    notifyListeners();
  }

  // ── Chat open / close ────────────────────────────────────────────────────────

  void openChat(String peer) {
    currentOpenChat = peer;
    notifyListeners();
  }

  void closeChat() {
    currentOpenChat = null;
    notifyListeners();
  }

  // ── Delete / clear ───────────────────────────────────────────────────────────

  Future<void> clearChat(String peer) async {
    _messages[peer]?.clear();
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.delete('messages',
        where: 'sender=? OR receiver=?', whereArgs: [peer, peer]);
  }

  Future<void> deleteChat(String peer) async {
    _messages.remove(peer);
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.delete('messages',
        where: 'sender=? OR receiver=?', whereArgs: [peer, peer]);
  }

  // ── Load from DB ─────────────────────────────────────────────────────────────

  Future<void> loadMessages() async {
    final db = await DatabaseHelper.database;
    final result = await db.query('messages', orderBy: 'timestamp ASC');

    _messages.clear();
    for (final row in result) {
      final msg = ChatMessage.fromMap(row);
      final peer = msg.mine ? msg.receiver : msg.sender;
      _messages.putIfAbsent(peer, () => []);
      _messages[peer]!.add(msg);
    }
    notifyListeners();
  }

  // ── Internal helper ──────────────────────────────────────────────────────────

  void _mutateMessage(String id, void Function(ChatMessage) fn) {
    for (final chat in _messages.values) {
      for (final msg in chat) {
        if (msg.id == id) {
          fn(msg);
          return;
        }
      }
    }
  }
}