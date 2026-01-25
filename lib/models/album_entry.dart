class AlbumEntry {
  final int id;
  final String targetMatricula;
  final String targetName;
  final String? targetPhotoUrl;
  final String? snapshotUrl;
  final DateTime? createdAt;

  const AlbumEntry({
    required this.id,
    required this.targetMatricula,
    required this.targetName,
    this.targetPhotoUrl,
    this.snapshotUrl,
    this.createdAt,
  });

  factory AlbumEntry.fromJson(Map<String, dynamic> json) {
    return AlbumEntry(
      id: _parseInt(json['id']),
      targetMatricula: (json['target_matricula'] ?? '').toString(),
      targetName: (json['target_name'] ?? '').toString(),
      targetPhotoUrl: json['target_photo_url']?.toString(),
      snapshotUrl: json['snapshot_url']?.toString(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
