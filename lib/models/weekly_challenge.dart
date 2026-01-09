class WeeklyChallenge {
  final int id;
  final String title;
  final String description;
  final String category;
  final String status;
  final bool givesHurra;
  final int hurraReward;
  final bool givesHurraExtra;
  final int hurraExtraValue;
  final int checkinRequiredDays;
  final int progressDays;
  final bool countsForWeekly;
  final DateTime? completedAt;

  const WeeklyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.givesHurra,
    required this.hurraReward,
    required this.givesHurraExtra,
    required this.hurraExtraValue,
    required this.checkinRequiredDays,
    required this.progressDays,
    required this.countsForWeekly,
    required this.completedAt,
  });

  bool get isCompleted => status == 'completed' || completedAt != null;
  bool get isCheckin => category.toUpperCase() == 'CHECKIN';

  factory WeeklyChallenge.fromJson(Map<String, dynamic> json) {
    final template = json['template'];
    final templateMap =
        template is Map<String, dynamic> ? template : <String, dynamic>{};

    final progress = json['progress'];
    final progressDays = progress is Map<String, dynamic>
        ? _parseInt(progress['days'])
        : 0;

    final completedAtRaw = json['completed_at'];
    DateTime? completedAt;
    if (completedAtRaw is String && completedAtRaw.isNotEmpty) {
      completedAt = DateTime.tryParse(completedAtRaw);
    }

    return WeeklyChallenge(
      id: _parseInt(json['id']),
      title: (templateMap['title'] as String?) ?? 'Reto',
      description: (templateMap['description'] as String?) ?? '',
      category: (templateMap['category'] as String?) ?? 'UNIVERSAL',
      status: (json['status'] as String?) ?? 'assigned',
      givesHurra: _parseBool(templateMap['gives_hurra']),
      hurraReward: _parseInt(templateMap['hurra_reward']),
      givesHurraExtra: _parseBool(templateMap['gives_hurra_extra']),
      hurraExtraValue: _parseInt(templateMap['hurra_extra_value']),
      checkinRequiredDays: _parseInt(templateMap['checkin_required_days']),
      progressDays: progressDays,
      countsForWeekly:
          _parseBool(templateMap['counts_for_weekly_participation']),
      completedAt: completedAt,
    );
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
