class ItemRecord {
  final String? id;
  final String tagId;
  final String itemName;
  final String? imagePath;
  final String? videoPath;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItemRecord({
    this.id,
    required this.tagId,
    required this.itemName,
    this.imagePath,
    this.videoPath,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tagId': tagId,
      'itemName': itemName,
      'imagePath': imagePath,
      'videoPath': videoPath,
      'remark': remark,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ItemRecord.fromMap(Map<String, dynamic> map) {
    return ItemRecord(
      id: map['id'] as String?,
      tagId: map['tagId'] as String,
      itemName: map['itemName'] as String,
      imagePath: map['imagePath'] as String?,
      videoPath: map['videoPath'] as String?,
      remark: map['remark'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  ItemRecord copyWith({
    String? id,
    String? tagId,
    String? itemName,
    String? imagePath,
    bool clearImagePath = false,
    String? videoPath,
    bool clearVideoPath = false,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemRecord(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      itemName: itemName ?? this.itemName,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      videoPath: clearVideoPath ? null : (videoPath ?? this.videoPath),
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
