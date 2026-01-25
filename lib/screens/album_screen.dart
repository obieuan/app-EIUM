import 'package:flutter/material.dart';

import '../models/album_entry.dart';
import '../services/album_service.dart';
import '../services/api_exceptions.dart';
import '../services/auth_service.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final AuthService _authService = AuthService();
  final AlbumService _albumService = AlbumService();

  List<AlbumEntry> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
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

    try {
      final entries = await _albumService.fetchAlbum(token);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } on TokenExpiredException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tu sesion expiro.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar el album.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF6F7FB),
      child: RefreshIndicator(
        onRefresh: _loadAlbum,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Mi album',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0A2A6B),
                      ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFF5B6B86)),
                  ),
                ),
              )
            else if (_entries.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_album_outlined,
                        size: 64,
                        color: Color(0xFFB9C7E6),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tu album esta vacio.',
                        style: TextStyle(
                          color: Color(0xFF5B6B86),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escanea el QR de otros usuarios\npara guardar sus tarjetas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8190AA),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _AlbumCard(entry: _entries[index]),
                    childCount: _entries.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.58,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final AlbumEntry entry;

  const _AlbumCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasSnapshot =
        entry.snapshotUrl != null && entry.snapshotUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => _showCardPopup(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: hasSnapshot
                    ? Image.network(
                        entry.snapshotUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.targetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F1B2D),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.targetMatricula,
                    style: const TextStyle(
                      color: Color(0xFF8190AA),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardPopup(BuildContext context) {
    final hasSnapshot =
        entry.snapshotUrl != null && entry.snapshotUrl!.isNotEmpty;

    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 340,
                  maxHeight: 540,
                ),
                child: hasSnapshot
                    ? Image.network(
                        entry.snapshotUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 340,
                          height: 540,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF0A2A6B),
                                Color(0xFF1E4A9A),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Color(0xFFB9C7E6),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Error al cargar\nla imagen',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFD3DDF2),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 340,
                        height: 540,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0A2A6B),
                              Color(0xFF1E4A9A),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.badge_outlined,
                                size: 80,
                                color: Color(0xFFB9C7E6),
                              ),
                              SizedBox(height: 20),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'Próximamente\npreview de tarjeta',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFD3DDF2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'Disponible próximamente en la app móvil',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF8FA8CC),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1E3A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Cerrar',
                      style: TextStyle(
                        color: Color(0xFFD3DDF2),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A2A6B),
            const Color(0xFF1E4A9A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 48,
              color: Color(0xFFB9C7E6),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Próximamente\npreview de tarjeta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD3DDF2),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
