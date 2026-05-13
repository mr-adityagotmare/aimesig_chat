import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;

    _db = await _init();

    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(
      await getDatabasesPath(),
      'aimesig_chat.db',
    );

    return openDatabase(
      path,
      version: 2,

      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE messages(
          id TEXT PRIMARY KEY,
          sender TEXT,
          receiver TEXT,
          message TEXT,
          timestamp INTEGER,
          mine INTEGER,
          delivered INTEGER,
          read INTEGER
        )
        ''');
      },

      onUpgrade: (
        db,
        oldVersion,
        newVersion,
      ) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN delivered INTEGER DEFAULT 0',
          );

          await db.execute(
            'ALTER TABLE messages ADD COLUMN read INTEGER DEFAULT 0',
          );
        }
      },
    );
  }
}