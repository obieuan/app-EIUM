class CheckinResult {
  final String status;
  final int days;
  final int required;
  final String? message;

  const CheckinResult({
    required this.status,
    required this.days,
    required this.required,
    this.message,
  });

  bool get isCompleted =>
      status == 'completed' || status == 'already_completed';
  bool get isProgress => status == 'progress';
  bool get isDuplicate => status == 'already_checked_in';

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    return CheckinResult(
      status: (json['status'] as String?) ?? 'unknown',
      days: _parseInt(json['days']),
      required: _parseInt(json['required']),
      message: json['message'] as String?,
    );
  }

  factory CheckinResult.error(String message) {
    return CheckinResult(
      status: 'error',
      days: 0,
      required: 0,
      message: message,
    );
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
