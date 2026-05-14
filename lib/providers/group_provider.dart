import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/group.dart';
import '../models/chat_message.dart';

class GroupProvider extends ChangeNotifier {
  final Map<String, Group> _groups = {};
  final Map<String, List<ChatMessage>> _groupMessages = {};

  String? currentOpenGroup;

  List<Group> get groups => _groups.values.toList();

  Map<String, List<ChatMessage>> get groupMessages => _groupMessages;

  List<ChatMessage> getGroupMessages(String groupId) =>
      _groupMessages[groupId] ?? [];

  Group? getGroup(String groupId) => _groups[groupId];

  int unreadGroupCount(String groupId) =>
      _groupMessages[groupId]?.where((e) => !e.mine && !e.read).length ?? 0;

  int get totalGroupUnread => _groupMessages.values
      .expand((msgs) => msgs)
      .where((m) => !m.mine && !m.read)
      .length;

  // ── Group CRUD ────────────────────────────────────────────────────────────

  Future<void> addGroup(Group group) async {
    _groups[group.id] = group;
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.insert('groups', group.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGroup(Group group) async {
    _groups[group.id] = group;
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.update('groups', group.toMap(),
        where: 'id=?', whereArgs: [group.id]);
  }

  Future<void> removeGroup(String groupId) async {
    _groups.remove(groupId);
    _groupMessages.remove(groupId);
    notifyListeners();

    final db = await DatabaseHelper.database;
    await db.delete('groups', where: 'id=?', whereArgs: [groupId]);
    await db.delete('group_messages', where: 'groupId=?', whereArgs: [groupId]);
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<void> addGroupMessage(String groupId, ChatMessage msg) async {
    _groupMessages.putIfAbsent(groupId, () => []);
    _groupMessages[groupId]!.add(msg);
    notifyListeners();

    final db = await DatabaseHelper.database;
    final row = msg.toMap();
    row['groupId'] = groupId;
    await db.insert('group_messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markGroupRead(String groupId) async {
    final msgs = _groupMessages[groupId];
    if (msgs == null) return;

    final db = await DatabaseHelper.database;
    for (final msg in msgs) {
      if (!msg.mine && !msg.read) {
        msg.read = true;
        await db.update('group_messages', {'read': 1},
            where: 'id=?', whereArgs: [msg.id]);
      }
    }
    notifyListeners();
  }

  void openGroup(String groupId) {
    currentOpenGroup = groupId;
    notifyListeners();
  }

  void closeGroup() {
    currentOpenGroup = null;
    notifyListeners();
  }

  // ── Load from DB ──────────────────────────────────────────────────────────

  Future<void> loadGroups() async {
    final db = await DatabaseHelper.database;

    final groupRows = await db.query('groups');
    _groups.clear();
    for (final row in groupRows) {
      final g = Group.fromMap(row);
      _groups[g.id] = g;
    }

    final msgRows =
        await db.query('group_messages', orderBy: 'timestamp ASC');
    _groupMessages.clear();
    for (final row in msgRows) {
      final msg = ChatMessage.fromMap(row);
      final gid = row['groupId'] as String;
      _groupMessages.putIfAbsent(gid, () => []);
      _groupMessages[gid]!.add(msg);
    }

    notifyListeners();
  }
}