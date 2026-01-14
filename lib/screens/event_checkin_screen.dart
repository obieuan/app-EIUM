import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import 'qr_scanner_screen.dart';

class EventCheckinScreen extends StatefulWidget {
  const EventCheckinScreen({super.key});

  @override
  State<EventCheckinScreen> createState() => _EventCheckinScreenState();
}

class _EventCheckinScreenState extends State<EventCheckinScreen> {
  final AuthService _authService = AuthService();
  
  List<CheckinActivity> _activities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No hay sesion activa';
        });
      }
      return;
    }

    try {
      final activities = await CheckinService.fetchActivities(token);
      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanAndCheckin(CheckinActivity activity) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (result == null || result.isEmpty || !mounted) return;

    _performCheckin(activity, result);
  }

  Future<void> _performCheckin(CheckinActivity activity, String matricula) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final session = await _authService.getValidSession();
      final token = session?.idToken;
      if (token == null) throw Exception('No autenticado');

      final result = await CheckinService.checkin(
        token: token,
        activityId: activity.id,
        matricula: matricula,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      _showResultDialog(result, activity);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      _showErrorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showResultDialog(CheckinResult result, CheckinActivity activity) {
    final isSuccess = result.isSuccess;
    final isAlready = result.isAlreadyCheckedIn;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isSuccess
              ? Icons.check_circle
              : (isAlready ? Icons.info : Icons.error),
          color: isSuccess
              ? const Color(0xFF22C55E)
              : (isAlready ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
          size: 48,
        ),
        title: Text(
          isSuccess
              ? '¡Check-in exitoso!'
              : (isAlready ? 'Ya registrado' : 'Error'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.userName ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              activity.title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (isSuccess || isAlready)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _scanAndCheckin(activity);
              },
              child: const Text('Escanear otro'),
            ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Check-in de Eventos'),
        backgroundColor: const Color(0xFF0A2A6B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadActivities,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay actividades con check-in abierto',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadActivities,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          final activity = _activities[index];
          return _buildActivityCard(activity);
        },
      ),
    );
  }

  Widget _buildActivityCard(CheckinActivity activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _scanAndCheckin(activity),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2A6B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F1B2D),
                      ),
                    ),
                    if (activity.eventTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        activity.eventTitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (activity.startDatetime != null) ...[
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatTime(activity.startDatetime)} - ${_formatTime(activity.endDatetime)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                        if (activity.locationName != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              activity.locationName!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF7B8BA3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
