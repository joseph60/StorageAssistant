import 'dart:io';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:uuid/uuid.dart';
import '../models/tag_record.dart';
import '../models/item_record.dart';
import '../models/media_record.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';
import '../services/nfc_service.dart';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  final Uuid _uuid = const Uuid();
  final DatabaseService _db = DatabaseService();
  final MediaService _media = MediaService();
  final NfcService _nfc = NfcService();

  NfcService get nfcService => _nfc;
  MediaService get mediaService => _media;

  Future<bool> isNfcAvailable() async {
    return await _nfc.isNfcAvailable();
  }

  Future<void> startNfcSession({
    required Function(NfcTag) onTagDiscovered,
    String? alertMessage,
    String? errorMessage,
  }) async {
    await _nfc.startSession(
      onTagDiscovered: onTagDiscovered,
      alertMessage: alertMessage,
      errorMessage: errorMessage,
    );
  }

  Future<void> stopNfcSession({
    String? alertMessage,
    String? errorMessage,
  }) async {
    await _nfc.stopSession(
      alertMessage: alertMessage,
      errorMessage: errorMessage,
    );
  }

  String? getTagId(NfcTag tag) {
    return _nfc.getTagId(tag);
  }

  Future<Map<String, dynamic>> readTag(NfcTag tag) async {
    return await _nfc.readTag(tag);
  }

  Future<Map<String, dynamic>> writeTagName(NfcTag tag, String tagName) async {
    return await _nfc.writeTextToTag(tag, tagName);
  }

  Future<TagRecord?> getOrCreateTag(String tagId, String tagName) async {
    TagRecord? tag = await _db.getTagByTagId(tagId);
    final now = DateTime.now();

    if (tag == null) {
      tag = TagRecord(
        id: tagId,
        tagId: tagId,
        tagName: tagName,
        createdAt: now,
        lastAccessAt: now,
      );
      await _db.insertTag(tag);
    } else {
      tag = tag.copyWith(
        tagName: tagName,
        lastAccessAt: now,
      );
      await _db.updateTag(tag);
    }

    return tag;
  }

  Future<TagRecord?> getTagByTagId(String tagId) async {
    return await _db.getTagByTagId(tagId);
  }

  Future<TagRecord> createTag(String tagId, String tagName) async {
    final now = DateTime.now();
    final tag = TagRecord(
      id: tagId,
      tagId: tagId,
      tagName: tagName,
      createdAt: now,
      lastAccessAt: now,
    );
    await _db.insertTag(tag);
    return tag;
  }

  Future<List<TagRecord>> getAllTags() async {
    return await _db.getAllTags();
  }

  Future<void> updateTagName(String tagId, String tagName) async {
    final tag = await _db.getTagByTagId(tagId);
    if (tag != null) {
      final updatedTag = tag.copyWith(
        tagName: tagName,
        lastAccessAt: DateTime.now(),
      );
      await _db.updateTag(updatedTag);
    }
  }

  Future<ItemRecord> createItem({
    required String tagId,
    required String itemName,
    String? imagePath,
    String? videoPath,
    String? remark,
  }) async {
    // 确保tag存在
    final tag = await _db.getTagByTagId(tagId);
    if (tag == null) {
      // 如果tag不存在，创建一个默认的tag
      final now = DateTime.now();
      final newTag = TagRecord(
        id: tagId,
        tagId: tagId,
        tagName: '未命名容器',
        createdAt: now,
        lastAccessAt: now,
      );
      await _db.insertTag(newTag);
    }
    
    final now = DateTime.now();
    final item = ItemRecord(
      id: _uuid.v4(),
      tagId: tagId,
      itemName: itemName,
      imagePath: imagePath,
      videoPath: videoPath,
      remark: remark,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertItem(item);
    return item;
  }

  Future<ItemRecord?> getItem(String id) async {
    return await _db.getItemById(id);
  }

  Future<List<ItemRecord>> getItemsByTag(String tagId) async {
    final items = await _db.getItemsByTagId(tagId);
    final updated = <ItemRecord>[];
    for (var item in items) {
      if (item.id == null || item.id!.isEmpty) {
        final newId = _uuid.v4();
        final updatedItem = item.copyWith(id: newId);
        updated.add(updatedItem);
      } else {
        updated.add(item);
      }
    }
    if (updated.isNotEmpty) {
      for (var i = 0; i < items.length; i++) {
        if (updated[i].id != items[i].id) {
          await _db.updateItem(updated[i]);
        }
      }
    }
    return updated;
  }

  Map<String, dynamic> itemToMap(ItemRecord item) {
    if (item.id == null) {
      return {
        'id': _uuid.v4(),
        'tagId': item.tagId,
        'itemName': item.itemName,
        'imagePath': item.imagePath,
        'videoPath': item.videoPath,
        'remark': item.remark,
        'createdAt': item.createdAt.toIso8601String(),
        'updatedAt': item.updatedAt.toIso8601String(),
      };
    }
    return {
      'id': item.id!,
      'tagId': item.tagId,
      'itemName': item.itemName,
      'imagePath': item.imagePath,
      'videoPath': item.videoPath,
      'remark': item.remark,
      'createdAt': item.createdAt.toIso8601String(),
      'updatedAt': item.updatedAt.toIso8601String(),
    };
  }

  Future<List<ItemRecord>> getAllItems() async {
    return await _db.getAllItems();
  }

  Future<ItemRecord> updateItem(ItemRecord item) async {
    final updatedItem = item.copyWith(updatedAt: DateTime.now());
    await _db.updateItem(updatedItem);
    return updatedItem;
  }

  Future<void> deleteItem(String id) async {
    // 先删数据库记录（失败则直接中止，保留媒体文件等待人工处理），
    // 再删媒体文件（失败可被 cleanOrphanedMedia 兜底）。
    // 原顺序是"先删媒体再删记录"，媒体删除失败会导致孤儿文件残留。
    final item = await _db.getItemById(id);
    if (item != null) {
      await _db.deleteItem(id);
      if (item.imagePath != null) {
        await _media.deleteMediaFile(item.imagePath!);
      }
      if (item.videoPath != null) {
        await _media.deleteMediaFile(item.videoPath!);
      }
    }
  }

  Future<void> deleteItemsByTag(String tagId) async {
    final items = await _db.getItemsByTagId(tagId);
    for (var item in items) {
      await deleteItem(item.id!);
    }
  }

  Future<void> deleteTag(String tagId) async {
    await deleteItemsByTag(tagId);
    await _db.deleteTag(tagId);
  }

  Future<MediaRecord?> pickImage(MediaSource source) async {
    return await _media.pickImage(source);
  }

  Future<MediaRecord?> pickVideo(MediaSource source) async {
    return await _media.pickVideo(source);
  }

  Future<int> cleanOrphanedMedia() async {
    final usedPaths = await _db.getUsedMediaPaths();
    return await _media.cleanOrphanedMedia(usedPaths);
  }

  Future<int> getMediaStorageSize() async {
    return await _media.getMediaStorageSize();
  }

  String formatFileSize(int bytes) {
    return _media.formatFileSize(bytes);
  }

  Future<void> clearAllData() async {
    final db = await _db.database;
    await db.transaction((tx) async {
      // 一次性清空两张表（媒体文件稍后在 cleanOrphanedMedia 中清理）
      await tx.rawDelete('DELETE FROM items');
      await tx.rawDelete('DELETE FROM tags');
    });
    await cleanOrphanedMedia();
  }

  /// 获取数据库文件路径。先确保数据库已初始化，保证文件存在（用于备份）。
  Future<String> getDatabasePath() async {
    await _db.database;
    return await _db.getDatabasePath();
  }

  /// 用 [sourcePath] 指向的备份文件覆盖当前数据库。
  /// 覆盖前先校验 SQLite 文件头，并关闭当前数据库连接；
  /// DatabaseService 下次访问时会自动重新打开新数据库。
  Future<void> restoreDatabase(String sourcePath) async {
    final source = File(sourcePath);
    // SQLite 文件头固定为 "SQLite format 3\0"（16 字节），
    // 防止用非数据库文件覆盖导致数据层损坏
    final raf = await source.open();
    final header = await raf.read(16);
    await raf.close();
    if (header.length < 16 ||
        String.fromCharCodes(header.sublist(0, 15)) != 'SQLite format 3') {
      throw Exception('所选文件不是有效的 SQLite 数据库');
    }

    final dbPath = await _db.getDatabasePath();
    await _db.close();
    await source.copy(dbPath);
  }
}
