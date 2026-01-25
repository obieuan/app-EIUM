import 'dart:convert';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;

class CheckinActivity {
  final int id;
  final String title;
  final String? eventTitle;
  final DateTime? startDatetime;
  final DateTime? endDatetime;
  final String? locationName;

  const CheckinActivity({
    required this.id,
    required this.title,
    this.eventTitle,
    this.startDatetime,
    this.endDatetime,
    this.locationName,
  });

  factory CheckinActivity.fromJson(Map<String, dynamic> json) {
    return CheckinActivity(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      eventTitle: json['event_title']?.toString(),
      startDatetime: json['start_datetime'] != null
          ? DateTime.tryParse(json['start_datetime'].toString())
          : null,
      endDatetime: json['end_datetime'] != null
          ? DateTime.tryParse(json['end_datetime'].toString())
          : null,
      locationName: json['location_name']?.toString(),
    );
  }
}

class CheckinResult {
  final String status;
  final int? attendanceId;
  final String? userName;
  final String? activityTitle;

  const CheckinResult({
    required this.status,
    this.attendanceId,
    this.userName,
    this.activityTitle,
  });

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    return CheckinResult(
      status: (json['status'] ?? '').toString(),
      attendanceId: json['attendance_id'] as int?,
      userName: json['user_name']?.toString(),
      activityTitle: json['activity_title']?.toString(),
    );
  }

  bool get isSuccess => status == 'checked_in';
  bool get isAlreadyCheckedIn => status == 'already_checked_in';
}

class CheckinService {
  static String _getBaseUrl() {
    final base = AppConfig.eventsApiBaseUrl.isNotEmpty
        ? AppConfig.eventsApiBaseUrl
        : AppConfig.apiBaseUrl;
                 '';
    var url = base.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static Future<List<CheckinActivity>> fetchActivities(String token) async {
    final baseUrl = _getBaseUrl();
    final response = await http.get(
      Uri.parse('$baseUrl/api/mobile/checkin/activities'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => CheckinActivity.fromJson(e)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('No tienes permisos para esta función');
    } else {
      throw Exception('Error al cargar actividades');
    }
  }

  static Future<CheckinResult> checkin({
    required String token,
    required int activityId,
    required String matricula,
  }) async {
    final baseUrl = _getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/checkin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'activity_id': activityId,
        'matricula': matricula,
      }),
    );

    if (response.statusCode == 200) {
      return CheckinResult.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw Exception('Usuario no encontrado');
    } else if (response.statusCode == 403) {
      throw Exception('No tienes permisos');
    } else {
      throw Exception('Error al registrar asistencia');
    }
  }
}
