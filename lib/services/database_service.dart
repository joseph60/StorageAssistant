import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tag_record.dart';
import '../models/item_record.dart';
import '../models/media_record.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'storage_assistant.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        tagId TEXT NOT NULL UNIQUE,
        tagName TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastAccessAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        tagId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        imagePath TEXT,
        videoPath TEXT,
        remark TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (tagId) REFERENCES tags (tagId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE media (
        id TEXT PRIMARY KEY,
        filePath TEXT NOT NULL,
        type INTEGER NOT NULL,
        thumbnailPath TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_items_tagId ON items (tagId)');
    await db.execute('CREATE INDEX idx_tags_tagId ON tags (tagId)');
  }

  Future<int> insertTag(TagRecord tag) async {
    final db = await database;
    return await db.insert(
      'tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTag(TagRecord tag) async {
    final db = await database;
    return await db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  Future<int> deleteTag(String id) async {
    final db = await database;
    return await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TagRecord?> getTagByTagId(String tagId) async {
    final db = await database;
    final maps = await db.query(
      'tags',
      where: 'tagId = ?',
      whereArgs: [tagId],
    );
    if (maps.isEmpty) return null;
    return TagRecord.fromMap(maps.first);
  }

  Future<List<TagRecord>> getAllTags() async {
    final db = await database;
    final maps = await db.query('tags', orderBy: 'lastAccessAt DESC');
    return maps.map((map) => TagRecord.fromMap(map)).toList();
  }

  Future<int> insertItem(ItemRecord item) async {
    final db = await database;
    return await db.insert(
      'items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateItem(ItemRecord item) async {
    final db = await database;
    final result = await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return result;
  }

  Future<int> deleteItem(String id) async {
    final db = await database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<ItemRecord?> getItemById(String id) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ItemRecord.fromMap(maps.first);
  }

  Future<List<ItemRecord>> getItemsByTagId(String tagId) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'tagId = ?',
      whereArgs: [tagId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => ItemRecord.fromMap(map)).toList();
  }

  Future<List<ItemRecord>> getAllItems() async {
    final db = await database;
    final maps = await db.query('items', orderBy: 'updatedAt DESC');
    return maps.map((map) => ItemRecord.fromMap(map)).toList();
  }

  Future<int> insertMedia(MediaRecord media) async {
    final db = await database;
    return await db.insert(
      'media',
      media.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteMedia(String id) async {
    final db = await database;
    return await db.delete(
      'media',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<MediaRecord?> getMediaById(String id) async {
    final db = await database;
    final maps = await db.query(
      'media',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return MediaRecord.fromMap(maps.first);
  }

  Future<List<MediaRecord>> getAllMedia() async {
    final db = await database;
    final maps = await db.query('media', orderBy: 'createdAt DESC');
    return maps.map((map) => MediaRecord.fromMap(map)).toList();
  }

  Future<List<String>> getUsedMediaPaths() async {
    final db = await database;
    final List<String> paths = [];
    
    final imagePaths = await db.query('items', columns: ['imagePath'], where: 'imagePath IS NOT NULL');
    for (var map in imagePaths) {
      if (map['imagePath'] != null) {
        paths.add(map['imagePath'] as String);
      }
    }
    
    final videoPaths = await db.query('items', columns: ['videoPath'], where: 'videoPath IS NOT NULL');
    for (var map in videoPaths) {
      if (map['videoPath'] != null) {
        paths.add(map['videoPath'] as String);
      }
    }
    
    return paths;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
