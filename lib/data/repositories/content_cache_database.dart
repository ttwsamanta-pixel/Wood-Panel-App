import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class ContentCacheEntry {
  const ContentCacheEntry(this.payload, this.savedAt);
  final String payload;
  final int savedAt;
}

/// Indexed, edition-isolated response cache. PDF files and user data are separate.
class ContentCacheDatabase {
  ContentCacheDatabase({this.factory, this.path});
  static final instance = ContentCacheDatabase();
  final DatabaseFactory? factory;
  final String? path;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open().catchError((Object e) {
        _opening = null;
        throw e;
      });

  Future<Database> _open() async {
    final driver = factory ?? databaseFactory;
    final location =
        path ?? '${await driver.getDatabasesPath()}/content_cache.db';
    final db = await driver.openDatabase(location,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
                'CREATE TABLE content_cache (cache_key TEXT PRIMARY KEY, edition TEXT NOT NULL, payload TEXT NOT NULL, saved_at INTEGER NOT NULL)');
            await db.execute(
                'CREATE INDEX cache_edition ON content_cache(edition)');
            await db.execute('CREATE TABLE cache_meta (name TEXT PRIMARY KEY)');
          },
        ));
    try {
      await _migrate(db);
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  String _edition(String key) =>
      key.startsWith('content_cache_v2:') ? key.split(':')[1] : 'shared';

  Future<void> _migrate(Database db) async {
    if ((await db.query('cache_meta',
            where: 'name = ?', whereArgs: ['preferences_v1']))
        .isNotEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) =>
            key.startsWith('content_cache_v2:') && !key.endsWith(':saved_at'))
        .toList();
    await db.transaction((txn) async {
      for (final key in keys) {
        final value = prefs.get(key);
        if (value is! String) continue;
        try {
          jsonDecode(value);
        } on FormatException {
          continue;
        }
        await txn.insert(
            'content_cache',
            {
              'cache_key': key,
              'edition': _edition(key),
              'payload': value,
              'saved_at': prefs.getInt('$key:saved_at') ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.insert('cache_meta', {'name': 'preferences_v1'});
    });
    // Remove only content copies after the migration transaction commits.
    for (final key in keys) {
      await prefs.remove(key);
      await prefs.remove('$key:saved_at');
    }
  }

  Future<ContentCacheEntry?> read(String key) async {
    final rows = await (await database).query('content_cache',
        where: 'cache_key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return ContentCacheEntry(
        rows.first['payload'] as String, rows.first['saved_at'] as int);
  }

  Future<void> write(String key, String payload) async {
    await (await database).insert(
        'content_cache',
        {
          'cache_key': key,
          'edition': _edition(key),
          'payload': payload,
          'saved_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
