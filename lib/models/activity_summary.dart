class ActivitySummary {
  final int id;
  final String title;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? imagePath;
  final String? locationName;
  final String? eventTitle;
  final String? typeName;
  final bool registrationOpen;
  final bool isOnline;

  const ActivitySummary({
    required this.id,
    required this.title,
    this.description,
    this.startAt,
    this.endAt,
    this.imagePath,
    this.locationName,
    this.eventTitle,
    this.typeName,
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
      locationName: json['location_name']?.toString(),
      eventTitle: json['event_title']?.toString(),
      typeName: json['type_name']?.toString(),
      registrationOpen: _parseBool(json['registration_open']),
      isOnline: _parseBool(json['is_online']),
    );
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
