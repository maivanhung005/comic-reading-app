import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/comic_entity.dart';
import '../../models/chapter_model.dart';

class LocalDataSource {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = p.join(await getDatabasesPath(), 'comic_reader_clean_v1.db');
    _database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE app_cache (cache_key TEXT PRIMARY KEY, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE favorites (user_id INTEGER NOT NULL, comic_id INTEGER NOT NULL, added_at TEXT NOT NULL, PRIMARY KEY(user_id, comic_id))');
        await db.execute('CREATE TABLE favorite_queue (user_id INTEGER NOT NULL, comic_id INTEGER NOT NULL, is_favorite INTEGER NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(user_id, comic_id))');
        await db.execute('CREATE TABLE followed_authors (user_id INTEGER NOT NULL, author_key TEXT NOT NULL, author_name TEXT NOT NULL, added_at TEXT NOT NULL, PRIMARY KEY(user_id, author_key))');
        await db.execute('CREATE TABLE author_follow_queue (user_id INTEGER NOT NULL, author_key TEXT NOT NULL, author_name TEXT NOT NULL, is_following INTEGER NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(user_id, author_key))');
        await db.execute('CREATE TABLE reading_history (local_id INTEGER PRIMARY KEY AUTOINCREMENT, remote_id INTEGER, user_id INTEGER NOT NULL, comic_id INTEGER NOT NULL, chapter_id INTEGER NOT NULL, chapter_number INTEGER NOT NULL, page_number INTEGER NOT NULL, read_at TEXT NOT NULL, is_synced INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE downloaded_chapters (chapter_id INTEGER PRIMARY KEY, comic_id INTEGER NOT NULL, comic_title TEXT NOT NULL, chapter_title TEXT NOT NULL, chapter_number INTEGER NOT NULL, payload TEXT NOT NULL, downloaded_at TEXT NOT NULL)');
        await db.execute('CREATE TABLE unlocked_chapters (user_id INTEGER NOT NULL, chapter_id INTEGER NOT NULL, method TEXT NOT NULL, unlocked_at TEXT NOT NULL, PRIMARY KEY(user_id, chapter_id))');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE followed_authors (user_id INTEGER NOT NULL, author_key TEXT NOT NULL, author_name TEXT NOT NULL, added_at TEXT NOT NULL, PRIMARY KEY(user_id, author_key))');
          await db.execute('CREATE TABLE author_follow_queue (user_id INTEGER NOT NULL, author_key TEXT NOT NULL, author_name TEXT NOT NULL, is_following INTEGER NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(user_id, author_key))');
        }
      },
    );
    return _database!;
  }

  Future<void> cacheComics(List<Map<String, dynamic>> comics) async {
    final db = await database;
    await db.insert('app_cache', {'cache_key': 'comics', 'payload': jsonEncode(comics)}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCachedComics() async {
    final db = await database;
    final rows = await db.query('app_cache', where: 'cache_key = ?', whereArgs: ['comics'], limit: 1);
    if (rows.isEmpty) return [];
    final decoded = jsonDecode(rows.first['payload'] as String) as List;
    return decoded.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> setFavoriteLocal(int userId, int comicId, bool isFavorite) async {
    final db = await database;
    await db.transaction((txn) async {
      if (isFavorite) {
        await txn.insert('favorites', {'user_id': userId, 'comic_id': comicId, 'added_at': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await txn.delete('favorites', where: 'user_id = ? AND comic_id = ?', whereArgs: [userId, comicId]);
      }
      await txn.insert('favorite_queue', {
        'user_id': userId, 'comic_id': comicId, 'is_favorite': isFavorite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> getFavoriteQueue(int userId) async {
    final db = await database;
    return db.query('favorite_queue', where: 'user_id = ?', whereArgs: [userId], orderBy: 'updated_at ASC');
  }

  Future<void> clearFavoriteQueue(int userId, int comicId) async {
    final db = await database;
    await db.delete('favorite_queue', where: 'user_id = ? AND comic_id = ?', whereArgs: [userId, comicId]);
  }

  Future<Set<int>> getFavoriteIds(int userId) async {
    final db = await database;
    final rows = await db.query('favorites', columns: ['comic_id'], where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => r['comic_id'] as int).toSet();
  }

  Future<void> replaceFavoritesFromServer(int userId, List<int> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('favorites', where: 'user_id = ?', whereArgs: [userId]);
      for (final id in ids.toSet()) {
        await txn.insert('favorites', {'user_id': userId, 'comic_id': id, 'added_at': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final pending = await txn.query('favorite_queue', where: 'user_id = ?', whereArgs: [userId]);
      for (final row in pending) {
        final comicId = row['comic_id'] as int;
        if (row['is_favorite'] == 1) {
          await txn.insert('favorites', {'user_id': userId, 'comic_id': comicId, 'added_at': row['updated_at']}, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await txn.delete('favorites', where: 'user_id = ? AND comic_id = ?', whereArgs: [userId, comicId]);
        }
      }
    });
  }

  String _authorKey(String authorName) => authorName.trim().toLowerCase();

  Future<void> setFollowedAuthorLocal(int userId, String authorName, bool isFollowing) async {
    final cleanName = authorName.trim();
    if (cleanName.isEmpty) return;
    final key = _authorKey(cleanName);
    final now = DateTime.now().toIso8601String();
    final db = await database;
    await db.transaction((txn) async {
      if (isFollowing) {
        await txn.insert('followed_authors', {
          'user_id': userId, 'author_key': key, 'author_name': cleanName, 'added_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await txn.delete('followed_authors', where: 'user_id = ? AND author_key = ?', whereArgs: [userId, key]);
      }
      await txn.insert('author_follow_queue', {
        'user_id': userId, 'author_key': key, 'author_name': cleanName,
        'is_following': isFollowing ? 1 : 0, 'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> getAuthorFollowQueue(int userId) async {
    final db = await database;
    return db.query('author_follow_queue', where: 'user_id = ?', whereArgs: [userId], orderBy: 'updated_at ASC');
  }

  Future<void> clearAuthorFollowQueue(int userId, String authorName) async {
    final db = await database;
    await db.delete('author_follow_queue', where: 'user_id = ? AND author_key = ?', whereArgs: [userId, _authorKey(authorName)]);
  }

  Future<Set<String>> getFollowedAuthors(int userId) async {
    final db = await database;
    final rows = await db.query('followed_authors', columns: ['author_name'], where: 'user_id = ?', whereArgs: [userId], orderBy: 'author_name COLLATE NOCASE ASC');
    return rows.map((row) => (row['author_name'] ?? '').toString()).where((name) => name.isNotEmpty).toSet();
  }

  Future<void> replaceFollowedAuthorsFromServer(int userId, List<String> authors) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('followed_authors', where: 'user_id = ?', whereArgs: [userId]);
      for (final author in authors.map((name) => name.trim()).where((name) => name.isNotEmpty)) {
        await txn.insert('followed_authors', {
          'user_id': userId, 'author_key': _authorKey(author), 'author_name': author,
          'added_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Apply local actions that have not reached the server so refresh does not hide them.
      final pending = await txn.query('author_follow_queue', where: 'user_id = ?', whereArgs: [userId]);
      for (final row in pending) {
        final key = (row['author_key'] ?? '').toString();
        final name = (row['author_name'] ?? '').toString();
        if (row['is_following'] == 1) {
          await txn.insert('followed_authors', {
            'user_id': userId, 'author_key': key, 'author_name': name,
            'added_at': row['updated_at'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await txn.delete('followed_authors', where: 'user_id = ? AND author_key = ?', whereArgs: [userId, key]);
        }
      }
    });
  }

  Future<int> addHistoryPending({required int userId, required int comicId, required int chapterId, required int chapterNumber, required int pageNumber}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    // Coalesce offline page updates into one pending row per user/comic/chapter.
    // This prevents a long offline reading session from creating an unbounded sync queue.
    final pending = await db.query(
      'reading_history',
      columns: ['local_id'],
      where: 'user_id = ? AND comic_id = ? AND chapter_id = ? AND is_synced = 0',
      whereArgs: [userId, comicId, chapterId],
      orderBy: 'local_id DESC',
      limit: 1,
    );
    final values = {
      'chapter_number': chapterNumber,
      'page_number': pageNumber,
      'read_at': now,
    };
    if (pending.isNotEmpty) {
      final localId = pending.first['local_id'] as int;
      await db.update('reading_history', values, where: 'local_id = ?', whereArgs: [localId]);
      return localId;
    }
    return db.insert('reading_history', {
      'user_id': userId,
      'comic_id': comicId,
      'chapter_id': chapterId,
      ...values,
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingHistory(int userId) async {
    final db = await database;
    return db.query('reading_history', where: 'user_id = ? AND is_synced = 0', whereArgs: [userId], orderBy: 'local_id ASC');
  }

  Future<void> markHistorySynced(int localId, int remoteId) async {
    final db = await database;
    await db.update('reading_history', {'is_synced': 1, 'remote_id': remoteId}, where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<void> mergeHistoryFromServer(int userId, List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('reading_history', where: 'user_id = ? AND is_synced = 1', whereArgs: [userId]);
      for (final row in rows) {
        await txn.insert('reading_history', {
          'remote_id': _toInt(row['id']), 'user_id': _toInt(row['userId'] ?? userId),
          'comic_id': _toInt(row['comicId']), 'chapter_id': _toInt(row['chapterId']),
          'chapter_number': _toInt(row['chapterNumber']), 'page_number': _toInt(row['pageNumber']),
          'read_at': (row['readAt'] ?? DateTime.now().toIso8601String()).toString(), 'is_synced': 1,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getHistoryRows(int userId) async {
    final db = await database;
    return db.query('reading_history', where: 'user_id = ?', whereArgs: [userId], orderBy: 'read_at DESC');
  }

  Future<void> replaceUnlocked(int userId, List<int> chapterIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('unlocked_chapters', where: 'user_id = ?', whereArgs: [userId]);
      for (final id in chapterIds.toSet()) {
        await txn.insert('unlocked_chapters', {'user_id': userId, 'chapter_id': id, 'method': 'SERVER', 'unlocked_at': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveUnlockedLocal(int userId, int chapterId, String method) async {
    final db = await database;
    await db.insert('unlocked_chapters', {
      'user_id': userId, 'chapter_id': chapterId, 'method': method,
      'unlocked_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<int>> getUnlockedIds(int userId) async {
    final db = await database;
    final rows = await db.query('unlocked_chapters', columns: ['chapter_id'], where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => r['chapter_id'] as int).toSet();
  }

  Future<void> saveDownloadedChapter(ComicEntity comic, ChapterEntity chapter, String payload) async {
    final db = await database;
    await db.insert('downloaded_chapters', {
      'chapter_id': chapter.id, 'comic_id': comic.id, 'comic_title': comic.title,
      'chapter_title': chapter.title, 'chapter_number': chapter.chapterNumber,
      'payload': payload, 'downloaded_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getDownloadedChapterPayload(int chapterId) async {
    final db = await database;
    final rows = await db.query('downloaded_chapters', columns: ['payload'], where: 'chapter_id = ?', whereArgs: [chapterId], limit: 1);
    return rows.isEmpty ? null : rows.first['payload'] as String;
  }

  Future<List<Map<String, dynamic>>> getDownloadedChapters() async {
    final db = await database;
    return db.query('downloaded_chapters', columns: ['chapter_id', 'comic_id', 'comic_title', 'chapter_title', 'chapter_number', 'downloaded_at'], orderBy: 'downloaded_at DESC');
  }

  Future<bool> isChapterDownloaded(int chapterId) async {
    final db = await database;
    final rows = await db.query('downloaded_chapters', columns: ['chapter_id'], where: 'chapter_id = ?', whereArgs: [chapterId], limit: 1);
    return rows.isNotEmpty;
  }

  static int _toInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
}
