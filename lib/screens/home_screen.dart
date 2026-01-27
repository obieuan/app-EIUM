import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_summary.dart';
import '../models/checkin_result.dart';
import '../models/challenge_summary.dart';
import '../models/event_summary.dart';
import '../models/feed_item.dart';
import '../models/user_profile.dart';
import '../models/weekly_challenge.dart';
import '../services/api_exceptions.dart';
import '../services/auth_service.dart';
import '../services/challenge_service.dart';
import '../services/events_service.dart';
import '../services/profile_service.dart';
import 'album_screen.dart';
import 'card_preview_screen.dart';
import 'event_checkin_screen.dart';
import 'qr_scanner_screen.dart';
import 'store_screen.dart';
import 'user_card_screen.dart';
import '../widgets/bubble_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final EventsService _eventsService = EventsService();
  final ChallengeService _challengeService = ChallengeService();

  UserProfile? _profile;
  List<FeedItem> _todayItems = [];
  List<FeedItem> _upcomingItems = [];
  int _hurraBalance = 0;
  int _antorchaBalance = 0;
  int _weeklyRequirement = 1;
  List<WeeklyChallenge> _weeklyChallenges = [];
  bool _isCheckingIn = false;
  String? _errorMessage;
  bool _isLoading = true;
  int _selectedIndex = 0;
  Set<int> _claimedChallengeIds = {};

  @override
  void initState() {
    super.initState();
    _loadClaimedChallenges();
    _loadDashboard();
  }

  Future<void> _loadClaimedChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('claimed_challenge_ids') ?? [];
    setState(() {
      _claimedChallengeIds = ids.map(int.parse).toSet();
    });
  }

  Future<void> _saveClaimedChallenge(int id) async {
    _claimedChallengeIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'claimed_challenge_ids',
      _claimedChallengeIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = await _authService.getValidSession();
    final token = session?.idToken;

    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }
    if (kDebugMode) {
      debugPrint('API DEBUG token_length=${token.length}');
    }

    try {
      final results = await Future.wait([
        _profileService.fetchProfile(token),
        _eventsService.fetchEvents(token),
        _eventsService.fetchActivities(token),
        _challengeService.fetchSummary(token),
        _challengeService.fetchWeeklyChallenges(token),
      ]);

      final profile = results[0] as UserProfile?;
      final events = results[1] as List<EventSummary>;
      final activities = results[2] as List<ActivitySummary>;
      final challenges = results[3] as ChallengeSummary;
      final weeklyChallenges = results[4] as List<WeeklyChallenge>;

      // Combine events and activities into feed items
      final feedItems = [
        ...events.map((e) => FeedItem.fromEvent(e)),
        ...activities.map((a) => FeedItem.fromActivity(a)),
      ];

      final todayItems = _filterTodayItems(feedItems);
      final upcomingItems = _filterUpcomingItems(feedItems);

      final fallbackHurra = profile?.points ?? 0;
      final hurraValue =
          challenges.permissionDenied ? fallbackHurra : challenges.hurraTotal;
      final antorchaValue =
          challenges.permissionDenied ? 0 : challenges.antorchaTotal;

      setState(() {
        _profile = profile;
        _todayItems = todayItems;
        _upcomingItems = upcomingItems;
        _hurraBalance = hurraValue;
        _antorchaBalance = antorchaValue;
        _weeklyRequirement = challenges.weeklyRequirement;
        _weeklyChallenges = weeklyChallenges;
        _isLoading = false;
      });
    } on TokenExpiredException {
      final refreshed = await _authService.refreshSession();
      final refreshedToken = refreshed?.idToken;
      if (refreshedToken == null || refreshedToken.isEmpty) {
        await _authService.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Tu sesion expiro. Inicia sesion de nuevo.';
        });
        return;
      }

      try {
        final results = await Future.wait([
          _profileService.fetchProfile(refreshedToken),
          _eventsService.fetchEvents(refreshedToken),
          _eventsService.fetchActivities(refreshedToken), 
          _challengeService.fetchSummary(refreshedToken),
          _challengeService.fetchWeeklyChallenges(refreshedToken),
        ]);

        final profile = results[0] as UserProfile?;
        final events = results[1] as List<EventSummary>;
        final activities = results[2] as List<ActivitySummary>;
        final challenges = results[3] as ChallengeSummary;
        final weeklyChallenges = results[4] as List<WeeklyChallenge>;

        // Combine events and activities
        final feedItems = [
          ...events.map((e) => FeedItem.fromEvent(e)),
          ...activities.map((a) => FeedItem.fromActivity(a)),
        ];

        final todayItems = _filterTodayItems(feedItems);
        final upcomingItems = _filterUpcomingItems(feedItems);

        final fallbackHurra = profile?.points ?? 0;
        final hurraValue = challenges.permissionDenied
            ? fallbackHurra
            : challenges.hurraTotal;
        final antorchaValue =
            challenges.permissionDenied ? 0 : challenges.antorchaTotal;

        setState(() {
          _profile = profile;
          _todayItems = todayItems;
          _upcomingItems = upcomingItems;
          _hurraBalance = hurraValue;
          _antorchaBalance = antorchaValue;
          _weeklyRequirement = challenges.weeklyRequirement;
          _weeklyChallenges = weeklyChallenges;
          _isLoading = false;
        });
      } catch (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudo cargar el perfil.';
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar la informacion.';
      });
    }
  }

  Future<void> _handleCheckin(WeeklyChallenge challenge) async {
    if (_isCheckingIn) {
      return;
    }

    setState(() {
      _isCheckingIn = true;
    });

    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCheckingIn = false;
      });
      _showSnackBar('No hay sesion activa.');
      return;
    }

    try {
      final result = await _challengeService.checkin(token, date: DateTime.now());
      if (!mounted) {
        return;
      }
      _showSnackBar(_checkinMessage(result));
      await _loadDashboard();
    } on TokenExpiredException {
      if (!mounted) {
        return;
      }
      _showSnackBar('Tu sesion expiro. Inicia sesion de nuevo.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('No se pudo registrar el check-in.');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  void _handleClaim(WeeklyChallenge challenge) {
    // Mark as claimed and save
    _saveClaimedChallenge(challenge.id);
    setState(() {}); // Refresh UI to hide button
    
    // Show celebration dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.celebration,
          color: Color(0xFF22C55E),
          size: 56,
        ),
        title: const Text('¡Felicidades!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Completaste el reto:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              challenge.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (challenge.givesHurra && challenge.hurraReward > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE566),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFB8860B), size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '+${challenge.hurraReward} Hurra',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB8860B),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('¡Genial!'),
          ),
        ],
      ),
    );
  }

  String _checkinMessage(CheckinResult result) {
    if (result.message != null && result.message!.isNotEmpty) {
      return result.message!;
    }
    if (result.isCompleted) {
      return 'Check-in completado. +Hurra aplicado.';
    }
    if (result.isDuplicate) {
      return 'Ya registraste tu check-in hoy.';
    }
    if (result.isProgress) {
      return 'Check-in registrado (${result.days}/${result.required}).';
    }
    return 'Check-in registrado.';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<FeedItem> _filterTodayItems(List<FeedItem> items) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return items.where((item) {
      final start = item.startAt;
      final end = item.endAt;
      
      if (start == null) return false;
      
      // Include if:
      // 1. Starts today, OR
      // 2. Started before today AND (no end OR ends today or later)
      final startsToday = start.isAfter(startOfToday.subtract(const Duration(seconds: 1))) &&
                         start.isBefore(endOfToday);
      final inProgressToday = start.isBefore(endOfToday) &&
                              (end == null || end.isAfter(startOfToday));
      
      return startsToday || inProgressToday;
    }).toList()
      ..sort((a, b) => (a.startAt ?? DateTime(0)).compareTo(b.startAt ?? DateTime(0)));
  }

  List<FeedItem> _filterUpcomingItems(List<FeedItem> items) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    
    final upcoming = items
        .where((item) => item.startAt != null)
        .where((item) => item.startAt!.isAfter(endOfToday))
        .toList();
    upcoming.sort((a, b) => a.startAt!.compareTo(b.startAt!));
    return upcoming.take(4).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateLabel(DateTime? date) {
    if (date == null) {
      return '--';
    }
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final monthLabel = months[date.month - 1];
    return '${date.day} $monthLabel';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final hurraBalance = _hurraBalance;
    final antorchaBalance = _antorchaBalance;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildQrButton(profile?.matricula),
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: _buildTabContent(profile, hurraBalance, antorchaBalance),
          ),
          Positioned(
            bottom: 100,
            right: 16,
            child: _buildBubbleMenu(profile),
          ),
          // Full-screen loading overlay
          if (_isLoading)
            Container(
              color: const Color(0xFFF6F7FB),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A2A6B)),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Cargando...',
                      style: TextStyle(
                        color: Color(0xFF5B6B86),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    UserProfile? profile,
    int hurraBalance,
    int antorchaBalance,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(profile, hurraBalance, antorchaBalance);
      case 1:
        return UserCardScreen(
          profile: profile,
          hurraBalance: hurraBalance,
          antorchaBalance: antorchaBalance,
        );
      case 2:
        return StoreScreen(
          hurraBalance: hurraBalance,
          onPurchase: _loadDashboard,
        );
      case 3:
        return _buildPassScreen();
      default:
        return _buildDashboardContent(profile, hurraBalance, antorchaBalance);
    }
  }

  Widget _buildDashboardContent(
    UserProfile? profile,
    int hurraBalance,
    int antorchaBalance,
  ) {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(showSettings: true),
            const SizedBox(height: 8),
            _buildProfileHeader(profile),
            const SizedBox(height: 18),
            _buildCoins(hurraBalance, antorchaBalance),
            const SizedBox(height: 20),
            _buildSectionTitle('Hoy'),
            const SizedBox(height: 12),
            _buildTodaySection(_todayItems),
            const SizedBox(height: 22),
            _buildSectionTitle('Próximas actividades'),
            const SizedBox(height: 12),
            _buildUpcomingSection(_upcomingItems),
            if (_isLoading) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 18),
              Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB64C3C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String label) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F1B2D),
            ),
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            child: Text(
              'Proximamente.',
              style: TextStyle(
                color: Color(0xFF5B6B86),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6EFE4),
            Color(0xFFE6EEF9),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -40,
            child: _SoftCircle(
              size: 220,
              color: Color(0x66FFD8A6),
            ),
          ),
          Positioned(
            top: 180,
            right: -80,
            child: _SoftCircle(
              size: 260,
              color: Color(0x664A7BD9),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _SoftCircle(
              size: 180,
              color: Color(0x662E9D8F),
            ),
          ),
        ],
      ),
    );
  }

// import 'splash_screen.dart'; // REMOVED

// ...

  Widget _buildTopBar({bool showSettings = false}) {
    if (!showSettings) return const SizedBox(height: 48);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF0F1B2D)),
            onPressed: _showSettingsMenu,
          ),
        ),
      ],
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFB64C3C)),
                title: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Color(0xFFB64C3C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
  }

  Widget _buildProfileHeader(UserProfile? profile) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Alumno';
    final career =
        profile?.career.isNotEmpty == true ? profile!.career : 'Carrera';
    final matricula =
        profile?.matricula.isNotEmpty == true ? profile!.matricula : '0000000';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProfileAvatar(photoUrl: profile?.photoUrl),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F1B2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            career,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5B6B86),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            matricula,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 0.4,
              color: Color(0xFF8190AA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoins(int hurra, int antorchas) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE3E7F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoinChip(
              icon: SvgPicture.asset(
                'assets/images/coinHurra.svg',
                width: 18,
                height: 18,
              ),
              color: const Color(0xFF1D76F2),
              value: hurra,
            ),
            const SizedBox(width: 16),
            _CoinChip(
              icon: const Icon(
                Icons.local_fire_department,
                color: Color(0xFF1C4DA6),
                size: 18,
              ),
              color: const Color(0xFF1C4DA6),
              value: antorchas,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1B2235),
      ),
    );
  }

  Widget _buildWeeklyChallengesSection() {
    if (_weeklyChallenges.isEmpty) {
      return _InfoCard(
        child: Text(
          'Aun no tienes retos asignados.',
          style: const TextStyle(
            color: Color(0xFF5B6B86),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final completedWeekly = _weeklyChallenges
        .where((challenge) => challenge.countsForWeekly && challenge.isCompleted)
        .length;
    final requirement = _weeklyRequirement > 0 ? _weeklyRequirement : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoCard(
          child: Text(
            'Completa $completedWeekly de $requirement retos para ganar Antorcha.',
            style: const TextStyle(
              color: Color(0xFF2C3A52),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: PageView.builder(
            itemCount: _weeklyChallenges.length,
            padEnds: false,
            controller: PageController(viewportFraction: 0.92),
            itemBuilder: (context, index) {
              final challenge = _weeklyChallenges[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _WeeklyChallengeTile(
                  challenge: challenge,
                  onCheckin: challenge.isCheckin && !challenge.isCompleted
                      ? () => _handleCheckin(challenge)
                      : null,
                  onClaim: challenge.isCompleted && !_claimedChallengeIds.contains(challenge.id)
                      ? () => _handleClaim(challenge)
                      : null,
                  isCheckingIn: _isCheckingIn,
                ),
              );
            },
          ),
        ),
        if (_weeklyChallenges.length > 1) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Desliza para ver más retos',
              style: TextStyle(
                color: const Color(0xFF5B6B86).withOpacity(0.6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPassScreen() {
    final completedWeekly = _weeklyChallenges
        .where((challenge) => challenge.countsForWeekly && challenge.isCompleted)
        .length;
    final requirement = _weeklyRequirement > 0 ? _weeklyRequirement : 1;

    // Progress value between 0.0 and 1.0 (currently hardcoded at 0.5)
    final progressValue = 0.5;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            const SizedBox(height: 20),
            // Torch Icon in Hexagon
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4A7BD9),
                      Color(0xFF0A2A6B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A2A6B).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  size: 80,
                  color: Color(0xFFFFB800),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Season Title
            const Center(
              child: Text(
                'Temporada 1',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F1B2D),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Motivational Subtitle
            Center(
              child: Text(
                'Completa retos, gana Hurras,\nparticipa activamente',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: const Color(0xFF5B6B86).withOpacity(0.9),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Progress Bar Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3E7F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Progress value label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D76F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$completedWeekly / $requirement',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3E7F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progressValue,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1D76F2),
                                Color(0xFF0A2A6B),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '0',
                        style: TextStyle(
                          color: Color(0xFF5B6B86),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFFFFB800),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            requirement.toString(),
                            style: const TextStyle(
                              color: Color(0xFF5B6B86),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Divider
            const Divider(color: Color(0xFFE3E7F0), thickness: 1),
            const SizedBox(height: 24),
            // Weekly Challenges Section
            _buildSectionTitle('Retos semanales'),
            const SizedBox(height: 16),
            if (_weeklyChallenges.isEmpty)
              _InfoCard(
                child: Text(
                  'Aun no tienes retos asignados.',
                  style: const TextStyle(
                    color: Color(0xFF5B6B86),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ..._weeklyChallenges.map((challenge) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WeeklyChallengeTile(
                    challenge: challenge,
                    onCheckin: challenge.isCheckin && !challenge.isCompleted
                        ? () => _handleCheckin(challenge)
                        : null,
                    onClaim: challenge.isCompleted && !_claimedChallengeIds.contains(challenge.id)
                        ? () => _handleClaim(challenge)
                        : null,
                    isCheckingIn: _isCheckingIn,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySection(List<FeedItem> items) {
    if (items.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Sin eventos ni actividades',
            style: TextStyle(
              color: const Color(0xFF5B6B86).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return _EventCard(
            item: item,
            onTap: () => _showEventDetails(item),
          );
        },
      ),
    );
  }

  String _formatTimeLabel(DateTime? date) {
    if (date == null) return '--';
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Widget _buildUpcomingSection(List<FeedItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Sin próximos eventos',
          style: TextStyle(
            color: const Color(0xFF5B6B86).withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          return _EventCard(
            item: item,
            onTap: () => _showEventDetails(item),
          );
        },
      ),
    );
  }

  Widget _buildBubbleMenu(UserProfile? profile) {
    final isStaff = profile?.isStaff ?? false;
    return BubbleMenu(
      icon: const Icon(Icons.menu, size: 26),
      items: [
        BubbleMenuItem(
          icon: Icons.qr_code_scanner,
          label: 'Escanear',
          onTap: _openQrScanner,
        ),
        BubbleMenuItem(
          icon: Icons.photo_album,
          label: 'Album',
          onTap: _openAlbum,
        ),
        BubbleMenuItem(
          icon: Icons.check_circle_outline,
          label: 'Check-in',
          onTap: _openEventCheckin,
          visible: isStaff,
          backgroundColor: const Color(0xFF22C55E),
        ),
      ],
    );
  }

  void _openEventCheckin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EventCheckinScreen()),
    );
  }

  void _openAlbum() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlbumScreen()),
    );
  }

  Widget _buildQrButton(String? matricula) {
    return FloatingActionButton(
      heroTag: 'home_qr_scan_btn',
      onPressed: () => _showQr(matricula),
      backgroundColor: const Color(0xFF0A2A6B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.qr_code_2, size: 28, color: Colors.white),
    );
  }

  Widget _buildBottomNav() {
    const activeColor = Color(0xFFEAF0FF);
    const inactiveColor = Color(0xFFB9C7E6);

    return BottomAppBar(
      color: const Color(0xFF0A2A6B),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                isActive: _selectedIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _setIndex(0),
              ),
              _NavItem(
                icon: Icons.badge,
                label: 'Mi tarjeta',
                isActive: _selectedIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _setIndex(1),
              ),
              const SizedBox(width: 48),
              _NavItem(
                icon: Icons.storefront,
                label: 'Tienda',
                isActive: _selectedIndex == 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _setIndex(2),
              ),
              _NavItem(
                icon: Icons.emoji_events,
                label: 'Pase',
                isActive: _selectedIndex == 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _setIndex(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showQr(String? matricula) {
    final qrValue =
        (matricula == null || matricula.isEmpty) ? 'SIN_MATRICULA' : matricula;

    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0D1E3A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mi QR personal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrValue,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  qrValue,
                  style: const TextStyle(
                    color: Color(0xFFD3DDF2),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Color(0xFFD3DDF2)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openQrScanner() async {
    final rawResult = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (!mounted || rawResult == null || rawResult.isEmpty) {
      return;
    }
    
    final result = rawResult.trim();

    // Check if it's a location QR
    if (result.startsWith('LOCATION:') || result.startsWith('L:')) {
      await _handleLocationScan(result);
      return;
    }

    // Check for potential invalid formats before assuming it's a student card
    // Student IDs shouldn't have colons or be excessively long
    if (result.contains(':') || result.length > 20) {
      _showErrorDialog('Código no reconocido', 'El QR escaneado no es válido para esta app.');
      return;
    }

    // Navigate to CardPreviewScreen to show the scanned user's card
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CardPreviewScreen(matricula: result),
      ),
    );

    if (saved == true && mounted) {
      _showSnackBar('Tarjeta guardada en tu album.');
      // Navigate to Album screen
      _openAlbum();
    }
  }

  Future<void> _handleLocationScan(String qrResult) async {
    // Show verification loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final session = await _authService.getValidSession();
      final token = session?.idToken;
      
      if (token == null) {
        if (mounted) Navigator.pop(context); // Close loading
        _showSnackBar('No hay sesión activa');
        return;
      }

      final result = await _challengeService.scanLocation(token, qrResult);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      final locationName = result['location_name'] ?? 'Ubicación';
      final message = result['message'] ?? 'Check-in exitoso';
      final completed = result['challenges_completed'] as List<dynamic>? ?? [];

      _showLocationResultDialog(
        locationName: locationName,
        message: message,
        rewards: completed,
      );
      
      // Refresh dashboard to show updated coins/progress
      _loadDashboard();

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      _showErrorDialog('Error al escanear', errorMsg);
    }
  }

  void _showLocationResultDialog({
    required String locationName,
    required String message,
    required List<dynamic> rewards,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EEF9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map, color: Color(0xFF4A7BD9)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                locationName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            if (rewards.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                '¡Retos Completados!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 8),
              ...rewards.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, size: 18, color: Color(0xFFF1C40F)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r['name'] ?? 'Reto completado')),
                    if (r['hurras'] != null)
                       Text(
                        '+${r['hurras']} H',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Genial'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Color(0xFFB64C3C))),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(FeedItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventDetailsModal(item: item),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;

  const _ProfileAvatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final imageProvider = (photoUrl != null && photoUrl!.isNotEmpty)
        ? NetworkImage(photoUrl!)
        : const AssetImage('assets/images/profile_placeholder.png')
            as ImageProvider;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0D2D7A), width: 2),
      ),
      child: CircleAvatar(
        radius: 46,
        backgroundImage: imageProvider,
        backgroundColor: const Color(0xFFE5ECF8),
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final Widget icon;
  final Color color;
  final int value;

  const _CoinChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: icon,
        ),
        const SizedBox(width: 6),
        Text(
          value.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1B2D),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback? onTap;

  const _EventCard({
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = item.isEvent ? 'Evento' : 'Actividad';
    final badgeColor = item.isEvent ? const Color(0xFF0A2A6B) : const Color(0xFF16A085);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(bottom: 50), // Space for overlapping container
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Image container with overlay gradient
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Background image
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2A6B),
                        image: item.imagePath != null && item.imagePath!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(item.imagePath!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: item.imagePath == null || item.imagePath!.isEmpty
                          ? Center(
                              child: Icon(
                                item.isEvent ? Icons.event : Icons.local_activity,
                                size: 60,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            )
                          : null,
                    ),
                    // Gradient overlay
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    // Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info container (overlapping at bottom)
            Positioned(
              bottom: -40,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF0F1B2D),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: Color(0xFF5B6B86),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeLabel(item.startAt),
                          style: const TextStyle(
                            color: Color(0xFF5B6B86),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeLabel(DateTime? date) {
    if (date == null) return '--';
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

class _WeeklyChallengeTile extends StatelessWidget {
  final WeeklyChallenge challenge;
  final VoidCallback? onCheckin;
  final VoidCallback? onClaim;
  final bool isCheckingIn;
  final bool isClaiming;

  const _WeeklyChallengeTile({
    required this.challenge,
    this.onCheckin,
    this.onClaim,
    required this.isCheckingIn,
    this.isClaiming = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = challenge.isCompleted;
    final requiredDays =
        challenge.checkinRequiredDays > 0 ? challenge.checkinRequiredDays : 3;
    final progressLabel = challenge.isCheckin
        ? '${challenge.progressDays}/$requiredDays dias'
        : null;

    final statusColor =
        isCompleted ? const Color(0xFF1F9D69) : const Color(0xFF9AA7BD);
    final statusLabel = isCompleted ? 'Completado' : 'Pendiente';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  challenge.isCheckin
                      ? Icons.check_circle_outline
                      : Icons.flag_outlined,
                  size: 18,
                  color: const Color(0xFF0A2A6B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B2235),
                      ),
                    ),
                    if (challenge.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        challenge.description,
                        style: const TextStyle(
                          color: Color(0xFF5B6B86),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (progressLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Progreso: $progressLabel',
                        style: const TextStyle(
                          color: Color(0xFF5B6B86),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _RewardBadge(
                    givesHurra: challenge.givesHurra,
                    hurraReward: challenge.hurraReward,
                    givesHurraExtra: challenge.givesHurraExtra,
                    hurraExtraValue: challenge.hurraExtraValue,
                  ),
                ],
              ),
            ],
          ),
          // Check-in button (for checkin challenges not yet completed)
          if (onCheckin != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isCheckingIn ? null : onCheckin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0A2A6B),
                  side: const BorderSide(color: Color(0xFFB8C6E5)),
                ),
                child: Text(isCheckingIn ? 'Registrando...' : 'Check-in hoy'),
              ),
            ),
          ],
          // Claim button (for completed challenges)
          if (onClaim != null && isCompleted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isClaiming ? null : onClaim,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                ),
                icon: isClaiming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.card_giftcard, size: 18),
                label: Text(isClaiming ? 'Reclamando...' : '¡Reclamar recompensa!'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final bool givesHurra;
  final int hurraReward;
  final bool givesHurraExtra;
  final int hurraExtraValue;

  const _RewardBadge({
    required this.givesHurra,
    required this.hurraReward,
    required this.givesHurraExtra,
    required this.hurraExtraValue,
  });

  @override
  Widget build(BuildContext context) {
    if (!givesHurra && !givesHurraExtra) {
      return const SizedBox.shrink();
    }

    final total = (givesHurra ? hurraReward : 0) +
        (givesHurraExtra ? hurraExtraValue : 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '+$total Hurra',
        style: const TextStyle(
          color: Color(0xFF1D76F2),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;

  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EventTile extends StatelessWidget {
  final String dateLabel;
  final String title;
  final String? badge;
  final int points;
  final Color? accentColor;

  const _EventTile({
    required this.dateLabel,
    required this.title,
    this.badge,
    required this.points,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = accentColor ?? const Color(0xFF0A2A6B);

    return Container(
      height: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withOpacity(0.85),
            baseColor,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateBadge(label: dateLabel),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                points.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String label;

  const _DateBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2051),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SoftCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EventDetailsModal extends StatelessWidget {
  final FeedItem item;

  const _EventDetailsModal({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Event image
                if (item.imagePath != null && item.imagePath!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      item.imagePath!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: const Color(0xFFE6EEF9),
                        child: Icon(
                          item.isEvent ? Icons.event : Icons.local_activity,
                          size: 60,
                          color: const Color(0xFF0A2A6B).withOpacity(0.3),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EEF9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(
                        item.isEvent ? Icons.event : Icons.local_activity,
                        size: 80,
                        color: const Color(0xFF0A2A6B).withOpacity(0.3),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.isEvent ? const Color(0xFF0A2A6B) : const Color(0xFF16A085),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.isEvent ? 'Evento' : 'Actividad',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1B2D),
                  ),
                ),
                const SizedBox(height: 16),
                // Date and time
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: _formatFullDate(item.startAt),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.schedule,
                  label: _formatTimeRange(item.startAt, item.endAt),
                ),
                if (item.locationName != null && item.locationName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.location_on,
                    label: item.locationName!,
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                // Description
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F1B2D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description ?? 'Sin descripción disponible.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5B6B86),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2A6B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatFullDate(DateTime? date) {
    if (date == null) return '--';
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]}, ${date.year}';
  }

  String _formatTimeRange(DateTime? start, DateTime? end) {
    if (start == null) return '--';
    final startTime = _formatTime(start);
    if (end == null) return startTime;
    final endTime = _formatTime(end);
    return '$startTime - $endTime';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6EEF9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF0A2A6B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF2C3A52),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
