import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/card_selection.dart';
import '../models/public_card_data.dart';
import '../services/album_service.dart';
import '../services/api_exceptions.dart';
import '../services/auth_service.dart';

class CardPreviewScreen extends StatefulWidget {
  final String matricula;

  const CardPreviewScreen({super.key, required this.matricula});

  @override
  State<CardPreviewScreen> createState() => _CardPreviewScreenState();
}

class _CardPreviewScreenState extends State<CardPreviewScreen> {
  static const _placeholders = {
    'background': 'assets/card/backgrounds/default.svg',
    'banner': 'assets/card/banners/default.png',
    'title_badge': 'assets/card/title_badges/default.svg',
    'medal': 'assets/card/medals/placeholder.svg',
  };
  static const _backgroundAspectRatio = 750 / 1189.5;
  static const _frameWidthRatio = 701.25 / 750;
  static const _frameAspectRatio = 701.25 / 898.5;
  static const _bannerAspectRatio = 701.25 / 405.75;
  static const _titleBadgeWidthRatio = 372 / 701.25;
  static const _titleBadgeAspectRatio = 372 / 84.75;
  static const _titleBadgeRightInsetRatio = 0.06;
  static const _frameCornerRadius = 15.0;
  static const _bannerCornerRadius = 15.0;
  static const _medalSize = 155.0;
  static const _medalsLeftOffset = 25.0;
  static const _medalsRightOffset = 0.0;
  static const _medalsVerticalOffset = 75.0;
  static const _medalGapAdjustment = 55;
  static const _medalsSideInsetRatio = 0.2;
  static const _defaultFrameAsset = 'assets/card/frames/default.svg';

  final GlobalKey _cardKey = GlobalKey();
  final AuthService _authService = AuthService();
  final AlbumService _albumService = AlbumService();

  PublicCardData? _cardData;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
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
      final data = await _albumService.fetchPreview(token, widget.matricula);
      if (!mounted) return;

      if (data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se encontro el usuario.';
        });
        return;
      }

      setState(() {
        _cardData = data;
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
        _errorMessage = 'Error al cargar la tarjeta.';
      });
    }
  }

  Future<void> _saveToAlbum() async {
    if (_isSaving || _cardData == null) return;

    setState(() {
      _isSaving = true;
    });

    Uint8List? snapshot;
    try {
      snapshot = await _captureCard();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Snapshot capture error: $e');
      }
    }

    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showSnackBar('No hay sesion activa.');
        setState(() => _isSaving = false);
      }
      return;
    }

    try {
      final result = await _albumService.scanCard(
        token,
        widget.matricula,
        snapshot,
      );

      if (!mounted) return;

      if (result != null) {
        final albumStatus = result['album_status']?.toString() ?? 'created';
        final challenge = result['challenge'] as Map<String, dynamic>?;
        final challengeStatus = challenge?['status']?.toString();

        var message = albumStatus == 'updated'
            ? 'Tarjeta actualizada en tu album.'
            : 'Tarjeta guardada en tu album.';

        if (challengeStatus == 'completed') {
          message = 'Tarjeta guardada y reto completado.';
        } else if (challengeStatus == 'already_completed') {
          message = 'Tarjeta guardada. Reto ya completado.';
        }

        _showSnackBar(message);
        Navigator.of(context).pop(true);
      } else {
        _showSnackBar('No se pudo guardar la tarjeta.');
        setState(() => _isSaving = false);
      }
    } on TokenExpiredException {
      if (mounted) {
        _showSnackBar('Tu sesion expiro.');
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al guardar.');
        setState(() => _isSaving = false);
      }
    }
  }

  Future<Uint8List?> _captureCard() async {
    final boundary = _cardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Tarjeta'),
        backgroundColor: const Color(0xFF0A2A6B),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF5B6B86)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }

    final data = _cardData!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: _buildCard(
              displayName: data.name.isNotEmpty ? data.name : 'Usuario',
              displayCareer: data.career,
              displayMatricula: data.matricula,
              photoUrl: data.photoUrl,
              selection: data.cardSelection,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveToAlbum,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar en album'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String displayName,
    required String displayCareer,
    required String displayMatricula,
    required String? photoUrl,
    required CardSelection? selection,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            final cardHeight = cardWidth / _backgroundAspectRatio;
            final frameWidth = cardWidth * _frameWidthRatio;
            final frameHeight = frameWidth / _frameAspectRatio;
            final frameLeft = (cardWidth - frameWidth) / 2;
            final frameTop = (cardHeight - frameHeight) / 2;
            const radius = 28.0;
            final avatarSize = cardWidth * 0.3;
            final bannerWidth = frameWidth;
            final bannerHeight = bannerWidth / _bannerAspectRatio;
            final bannerBottom = frameTop + bannerHeight;
            final titleBadgeWidth = frameWidth * _titleBadgeWidthRatio;
            final titleBadgeHeight = titleBadgeWidth / _titleBadgeAspectRatio;
            final medalRowBaseWidth = _medalSize * 4;
            final medalsSideInset = frameWidth * _medalsSideInsetRatio;
            final availableMedalsWidth = frameWidth - (medalsSideInset * 2);
            final computedGap = (availableMedalsWidth - medalRowBaseWidth) / 3;
            final adjustedGap = computedGap + _medalGapAdjustment;
            final medalGap = adjustedGap > 0 ? 0.0 : adjustedGap;
            final medalsRowWidth = medalRowBaseWidth + (medalGap * 3);
            final textTop =
                bannerBottom + (avatarSize / 2) + (cardWidth * 0.04);
            final sideInset = frameLeft + (frameWidth * 0.05);

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildAssetImage(
                          selection?.sections['background']?.imageUrl,
                          _placeholders['background']!,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: frameLeft,
                        top: frameTop,
                        width: frameWidth,
                        height: frameHeight,
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_frameCornerRadius),
                          child: _buildAssetFromAsset(
                            _defaultFrameAsset,
                            BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: frameTop,
                        left: frameLeft,
                        child: SizedBox(
                          width: bannerWidth,
                          height: bannerHeight,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(_bannerCornerRadius),
                            child: _buildAssetImage(
                              selection?.sections['banner']?.imageUrl,
                              _placeholders['banner']!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: bannerBottom - (titleBadgeHeight / 2),
                        right: frameLeft +
                            (frameWidth * _titleBadgeRightInsetRatio),
                        child: SizedBox(
                          width: titleBadgeWidth,
                          height: titleBadgeHeight,
                          child: _buildAssetImage(
                            selection?.sections['title_badge']?.imageUrl,
                            _placeholders['title_badge']!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: bannerBottom - (avatarSize / 2),
                        left: sideInset,
                        child: _buildAvatar(photoUrl, avatarSize),
                      ),
                      Positioned(
                        left: sideInset,
                        right: sideInset,
                        top: textTop,
                        child: _buildUserText(
                          displayName: displayName,
                          displayCareer: displayCareer,
                          displayMatricula: displayMatricula,
                        ),
                      ),
                      Positioned(
                        left: frameLeft,
                        width: frameWidth,
                        bottom: frameTop +
                            (frameHeight * 0.005) -
                            _medalsVerticalOffset,
                        child: Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: _medalsLeftOffset,
                              right: _medalsRightOffset,
                            ),
                            child: SizedBox(
                              width: medalsRowWidth,
                              child: _buildMedalRow(
                                selection: selection,
                                medalSize: _medalSize,
                                gap: medalGap,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image(
          image: _resolvePhoto(photoUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/profile_placeholder.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  ImageProvider _resolvePhoto(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return const AssetImage('assets/images/profile_placeholder.png');
  }

  Widget _buildUserText({
    required String displayName,
    required String displayCareer,
    required String displayMatricula,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1B2D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayCareer,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374B6B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayMatricula,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            letterSpacing: 1.2,
            color: const Color(0xFF6D7C95),
          ),
        ),
      ],
    );
  }

  Widget _buildMedalRow({
    required CardSelection? selection,
    required double medalSize,
    required double gap,
  }) {
    final itemSpacing = medalSize + gap;
    final rowWidth = (medalSize * 4) + (gap * 3);

    return SizedBox(
      width: rowWidth,
      height: medalSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(4, (index) {
          final slot = index + 1;
          final medal = selection?.medals[slot];
          return Positioned(
            left: index * itemSpacing,
            child: SizedBox(
              width: medalSize,
              height: medalSize,
              child: _buildAssetImage(
                medal?.imageUrl,
                _placeholders['medal']!,
                fit: BoxFit.contain,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAssetImage(
    String? imageUrl,
    String placeholderAsset, {
    BoxFit fit = BoxFit.contain,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildAssetFromAsset(placeholderAsset, fit);
    }
    if (_isSvg(imageUrl)) {
      return SvgPicture.network(
        imageUrl,
        fit: fit,
        placeholderBuilder: (_) => _buildAssetFromAsset(placeholderAsset, fit),
      );
    }
    return Image.network(
      imageUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildAssetFromAsset(placeholderAsset, fit),
    );
  }

  Widget _buildAssetFromAsset(String assetPath, BoxFit fit) {
    if (_isSvg(assetPath)) {
      return SvgPicture.asset(assetPath, fit: fit);
    }
    return Image.asset(assetPath, fit: fit);
  }

  bool _isSvg(String path) {
    return path.toLowerCase().endsWith('.svg');
  }
}
