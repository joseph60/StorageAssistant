enum MediaType { image, video }

/// 媒体记录：用于在内存中描述一张图片 / 一段视频（含可选缩略图）。
/// 当前实现中媒体路径直接写在 items 表的 imagePath / videoPath 字段里，
/// 此模型主要作为 MediaService 与调用方之间的数据传输对象，
/// 不再对应独立的 media 数据表（该表已在 database_service 中移除）。
class MediaRecord {
  final String? id;
  final String filePath;
  final MediaType type;
  final String? thumbnailPath;
  final DateTime createdAt;

  MediaRecord({
    this.id,
    required this.filePath,
    required this.type,
    this.thumbnailPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'type': type.index,
      'thumbnailPath': thumbnailPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  MediaRecord copyWith({
    String? id,
    String? filePath,
    MediaType? type,
    String? thumbnailPath,
    DateTime? createdAt,
  }) {
    return MediaRecord(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
