enum MediaType { image, video }

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

  factory MediaRecord.fromMap(Map<String, dynamic> map) {
    return MediaRecord(
      id: map['id'] as String?,
      filePath: map['filePath'] as String,
      type: MediaType.values[map['type'] as int],
      thumbnailPath: map['thumbnailPath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
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
