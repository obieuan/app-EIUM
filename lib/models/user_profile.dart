class UserProfile {
  final String name;
  final String career;
  final String matricula;
  final int points;
  final String? photoUrl;

  const UserProfile({
    required this.name,
    required this.career,
    required this.matricula,
    required this.points,
    this.photoUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: (json['name'] ?? '').toString(),
      career: (json['career'] ?? '').toString(),
      matricula: (json['matricula'] ?? '').toString(),
      points: _parsePoints(json['points']),
      photoUrl: json['photo_url']?.toString(),
    );
  }

  static int _parsePoints(dynamic value) {
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
