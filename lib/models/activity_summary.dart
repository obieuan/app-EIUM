class ActivitySummary {
  final int id;
  final String title;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? imagePath;
  final String? eventTitle;
  final List<String> tags;
  final bool registrationOpen;
  final bool isOnline;

  const ActivitySummary({
    required this.id,
    required this.title,
    this.description,
    this.startAt,
    this.endAt,
    this.imagePath,
    this.eventTitle,
    this.tags = const [],
    required this.registrationOpen,
    required this.isOnline,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      id: _parseInt(json['id']),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      startAt: _parseDate(json['start_datetime']),
      endAt: _parseDate(json['end_datetime']),
      imagePath: json['image']?.toString(),
      eventTitle: json['event_title']?.toString(),
      tags: _parseTags(json['tags']),
      registrationOpen: _parseBool(json['registration_open']),
      isOnline: _parseBool(json['is_online']),
    );
  }

  static List<String> _parseTags(dynamic value) {
    if (value == null) {
      return [];
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString();
    if (raw.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
