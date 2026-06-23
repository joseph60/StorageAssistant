class TagRecord {
  final String? id;
  final String tagId;
  final String tagName;
  final DateTime createdAt;
  final DateTime lastAccessAt;

  TagRecord({
    this.id,
    required this.tagId,
    required this.tagName,
    required this.createdAt,
    required this.lastAccessAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tagId': tagId,
      'tagName': tagName,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessAt': lastAccessAt.toIso8601String(),
    };
  }

  factory TagRecord.fromMap(Map<String, dynamic> map) {
    return TagRecord(
      id: map['id'] as String?,
      tagId: map['tagId'] as String,
      tagName: map['tagName'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastAccessAt: DateTime.parse(map['lastAccessAt'] as String),
    );
  }

  TagRecord copyWith({
    String? id,
    String? tagId,
    String? tagName,
    DateTime? createdAt,
    DateTime? lastAccessAt,
  }) {
    return TagRecord(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      createdAt: createdAt ?? this.createdAt,
      lastAccessAt: lastAccessAt ?? this.lastAccessAt,
    );
  }
}
