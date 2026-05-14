import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static Database? _db;

  /// Call once at app startup (before any DB access) on desktop platforms.
  static void initFfiIfNeeded() {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'aimesig_chat.db');

    return openDatabase(
      path,
      version: 4, // bumped for group tables
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id        TEXT PRIMARY KEY,
            sender    TEXT,
            receiver  TEXT,
            message   TEXT,
            timestamp INTEGER,
            mine      INTEGER,
            type      INTEGER DEFAULT 0,
            filePath  TEXT,
            fileName  TEXT,
            fileSize  INTEGER,
            delivered INTEGER DEFAULT 0,
            read      INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE groups(
            id              TEXT PRIMARY KEY,
            name            TEXT,
            creatorDeviceId TEXT,
            memberDeviceIds TEXT,
            memberNames     TEXT,
            createdAt       INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE group_messages(
            id        TEXT PRIMARY KEY,
            groupId   TEXT,
            sender    TEXT,
            receiver  TEXT,
            message   TEXT,
            timestamp INTEGER,
            mine      INTEGER,
            type      INTEGER DEFAULT 0,
            filePath  TEXT,
            fileName  TEXT,
            fileSize  INTEGER,
            delivered INTEGER DEFAULT 0,
            read      INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE messages ADD COLUMN delivered INTEGER DEFAULT 0');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN read INTEGER DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE messages ADD COLUMN type INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE messages ADD COLUMN filePath TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN fileName TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN fileSize INTEGER');
        }
        if (oldVersion < 4) {
          // Add group tables on upgrade
          await db.execute('''
            CREATE TABLE IF NOT EXISTS groups(
              id              TEXT PRIMARY KEY,
              name            TEXT,
              creatorDeviceId TEXT,
              memberDeviceIds TEXT,
              memberNames     TEXT,
              createdAt       INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS group_messages(
              id        TEXT PRIMARY KEY,
              groupId   TEXT,
              sender    TEXT,
              receiver  TEXT,
              message   TEXT,
              timestamp INTEGER,
              mine      INTEGER,
              type      INTEGER DEFAULT 0,
              filePath  TEXT,
              fileName  TEXT,
              fileSize  INTEGER,
              delivered INTEGER DEFAULT 0,
              read      INTEGER DEFAULT 0
            )
          ''');
        }
      },
    );
  }
}
