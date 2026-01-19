import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/card_asset.dart';
import '../models/card_selection.dart';
import '../models/user_profile.dart';
import '../services/api_exceptions.dart';
import '../services/auth_service.dart';
import '../services/card_service.dart';
import '../services/profile_service.dart';

class UserCardScreen extends StatefulWidget {
  final UserProfile? profile;
  final int hurraBalance;
  final int antorchaBalance;

  const UserCardScreen({
    super.key,
    required this.profile,
    required this.hurraBalance,
    required this.antorchaBalance,
  });

  @override
  State<UserCardScreen> createState() => _UserCardScreenState();
}

class _UserCardScreenState extends State<UserCardScreen> {
  static const _sections = [
    'background',
    'banner',
    'title_badge',
    'medal',
  ];

  static const _sectionLabels = {
    'background': 'Fondo',
    'banner': 'Banner',
    'title_badge': 'Titulo',
    'medal': 'Medallas',
  };

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
  static const _primaryAccent = Color(0xFF5D7CFF);
  static const _appBackground = Color(0xFFF6F7FB);

  final AuthService _authService = AuthService();
  final CardService _cardService = CardService();
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, List<CardAsset>> _assetsBySection = {};
  CardSelection? _selection;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _showEditor = false;
  String? _errorMessage;
  String? _photoOverrideUrl;
  int _activeMedalSlot = 1;

  @override
  void initState() {
    super.initState();
    _loadCardData();
  }

  Future<void> _loadCardData() async {
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
      final selection = await _cardService.fetchSelection(token);
      final results = await Future.wait(
        _sections.map((section) => _cardService.fetchAssetsBySection(
              token,
              section,
            )),
      );

      final assetsBySection = <String, List<CardAsset>>{};
      for (var i = 0; i < _sections.length; i++) {
        assetsBySection[_sections[i]] = results[i];
      }

      setState(() {
        _selection = selection;
        _assetsBySection = assetsBySection;
        _isLoading = false;
      });
    } on TokenExpiredException {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tu sesion expiro. Inicia sesion de nuevo.';
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar la tarjeta.';
      });
    }
  }

  Future<void> _reloadSection(String section) async {
    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final assets = await _cardService.fetchAssetsBySection(token, section);
      if (!mounted) {
        return;
      }
      setState(() {
        _assetsBySection[section] = assets;
      });
    } on TokenExpiredException {
      if (!mounted) {
        return;
      }
      _showSnackBar('Tu sesion expiro. Inicia sesion de nuevo.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('No se pudo actualizar la coleccion.');
    }
  }

  Future<void> _applySelection({
    required String section,
    required CardAsset asset,
    int? slot,
  }) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null || token.isEmpty) {
      _showSnackBar('No hay sesion activa.');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      final ok = await _cardService.updateSelection(
        token,
        section: section,
        assetId: asset.id,
        slot: slot,
      );
      if (!mounted) {
        return;
      }
      if (ok) {
        setState(() {
          final current = _selection;
          if (current == null) {
            _selection = CardSelection(
              sections: section == 'medal' ? {} : {section: asset},
              medals: section == 'medal' && slot != null ? {slot: asset} : {},
            );
          } else if (section == 'medal' && slot != null) {
            final updatedMedals = Map<int, CardAsset>.from(current.medals);
            updatedMedals[slot] = asset;
            _selection = CardSelection(
              sections: current.sections,
              medals: updatedMedals,
            );
          } else {
            final updatedSections =
                Map<String, CardAsset?>.from(current.sections);
            updatedSections[section] = asset;
            _selection = CardSelection(
              sections: updatedSections,
              medals: current.medals,
            );
          }
        });
      } else {
        _showSnackBar('No se pudo guardar la seleccion.');
      }
    } on TokenExpiredException {
      if (mounted) {
        _showSnackBar('Tu sesion expiro. Inicia sesion de nuevo.');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo guardar la seleccion.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleAssetTap(String section, CardAsset asset) async {
    if (asset.owned) {
      await _applySelection(
        section: section,
        asset: asset,
        slot: section == 'medal' ? _activeMedalSlot : null,
      );
      return;
    }

    if (asset.availability != 'purchasable') {
      _showSnackBar('Asset bloqueado.');
      return;
    }

    final shouldBuy = await _confirmPurchase(asset);
    if (!shouldBuy) {
      return;
    }

    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null || token.isEmpty) {
      _showSnackBar('No hay sesion activa.');
      return;
    }

    try {
      final ok = await _cardService.purchaseAsset(token, asset.id);
      if (!mounted) {
        return;
      }
      if (!ok) {
        _showSnackBar('No se pudo completar la compra.');
        return;
      }
      await _reloadSection(section);
      await _applySelection(
        section: section,
        asset: asset.copyWith(owned: true),
        slot: section == 'medal' ? _activeMedalSlot : null,
      );
      _showSnackBar('Compra completada.');
    } on TokenExpiredException {
      if (mounted) {
        _showSnackBar('Tu sesion expiro. Inicia sesion de nuevo.');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo completar la compra.');
      }
    }
  }

  Future<bool> _confirmPurchase(CardAsset asset) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Comprar asset'),
          content: Text(
            'Precio: ${asset.priceHurra} hurras.\nQuieres comprarlo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Comprar'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _updateProfilePhoto() async {
    if (_isUploadingPhoto) {
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 90,
    );
    if (image == null) {
      return;
    }

    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null || token.isEmpty) {
      _showSnackBar('No hay sesion activa.');
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final url = await _profileService.updatePhoto(token, image);
      if (!mounted) {
        return;
      }
      if (url != null && url.isNotEmpty) {
        setState(() {
          _photoOverrideUrl = url;
        });
      }
      _showSnackBar('Foto actualizada.');
    } on TokenExpiredException {
      if (mounted) {
        _showSnackBar('Tu sesion expiro. Inicia sesion de nuevo.');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo actualizar la foto.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final displayName =
        (profile?.name ?? '').isNotEmpty ? profile!.name : 'Nombre Apellido';
    final displayCareer =
        (profile?.career ?? '').isNotEmpty ? profile!.career : 'Carrera';
    final displayMatricula =
        (profile?.matricula ?? '').isNotEmpty ? profile!.matricula : '000000';

    return ColoredBox(
      color: _appBackground,
      child: RefreshIndicator(
        onRefresh: _loadCardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi tarjeta',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0A2A6B),
                    ),
              ),
              const SizedBox(height: 12),
              if (_selection == null && _isLoading)
                _buildCardLoading()
              else
                _buildCard(
                  displayName: displayName,
                  displayCareer: displayCareer,
                  displayMatricula: displayMatricula,
                  photoUrl: _photoOverrideUrl ?? profile?.photoUrl,
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUploadingPhoto ? null : _updateProfilePhoto,
                  icon: _isUploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    _isUploadingPhoto ? 'Subiendo foto...' : 'Cambiar foto',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => setState(() => _showEditor = !_showEditor),
                  child: Text(
                    _showEditor ? 'Ocultar editor' : 'Editar tarjeta',
                  ),
                ),
              ),
              if (_showEditor) ...[
                const SizedBox(height: 20),
                Text(
                  'Editor de tarjeta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0A2A6B),
                      ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB64C3C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildEditorPanel(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String displayName,
    required String displayCareer,
    required String displayMatricula,
    required String? photoUrl,
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
            final radius = 28.0;
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
                          _selection?.sections['background']?.imageUrl,
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
                              _selection?.sections['banner']?.imageUrl,
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
                            _selection?.sections['title_badge']?.imageUrl,
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

  Widget _buildCardLoading() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: AspectRatio(
          aspectRatio: _backgroundAspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
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
        ),
      ),
    );
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
          final medal = _selection?.medals[slot];
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

  ImageProvider _resolvePhoto(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return const AssetImage('assets/images/profile_placeholder.png');
  }

  Widget _buildEditorPanel() {
    final panelHeight = (MediaQuery.of(context).size.height * 0.46)
        .clamp(280.0, 420.0)
        .toDouble();

    return DefaultTabController(
      length: 4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            TabBar(
              labelColor: const Color(0xFF0F1B2D),
              unselectedLabelColor: const Color(0xFF7B8BA3),
              indicatorColor: _primaryAccent,
              indicatorWeight: 3,
              tabs: [
                Tab(text: _sectionLabels['background'] ?? 'Fondo'),
                Tab(text: _sectionLabels['banner'] ?? 'Banner'),
                Tab(text: _sectionLabels['title_badge'] ?? 'Titulo'),
                Tab(text: _sectionLabels['medal'] ?? 'Medallas'),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: panelHeight,
              child: TabBarView(
                children: [
                  _buildAssetGrid(section: 'background'),
                  _buildAssetGrid(section: 'banner'),
                  _buildAssetGrid(section: 'title_badge'),
                  _buildMedalTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetGrid({
    required String section,
    int? selectedId,
    String? emptyLabel,
  }) {
    final allAssets = _assetsBySection[section] ?? [];
    // Only show assets the user owns or that are globally available
    final assets = allAssets
        .where((a) => a.owned || a.availability.toLowerCase() == 'global')
        .toList();
    final resolvedSelectedId = selectedId ?? _selection?.sections[section]?.id;
    final label = emptyLabel ?? 'Sin assets disponibles.';

    if (assets.isEmpty) {
      return Center(
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF7B8BA3)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 360 ? 2 : 3;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            return _AssetTile(
              asset: asset,
              isSelected: resolvedSelectedId == asset.id,
              onTap: () => _handleAssetTap(section, asset),
            );
          },
        );
      },
    );
  }

  Widget _buildMedalTab() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildMedalSlots(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildAssetGrid(
              section: 'medal',
              selectedId: _selection?.medals[_activeMedalSlot]?.id,
              emptyLabel: 'Sin medallas disponibles.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedalSlots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        final slot = index + 1;
        final medal = _selection?.medals[slot];
        final isActive = _activeMedalSlot == slot;
        return GestureDetector(
          onTap: () => setState(() => _activeMedalSlot = slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEFF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? _primaryAccent : const Color(0xFFD6DFEC),
                width: isActive ? 2 : 1,
              ),
            ),
            child: SizedBox(
              width: 52,
              height: 52,
              child: _buildAssetImage(
                medal?.imageUrl,
                _placeholders['medal']!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      }),
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

class _AssetTile extends StatelessWidget {
  static const _selectedBorder = Color(0xFF5D7CFF);

  final CardAsset asset;
  final bool isSelected;
  final VoidCallback onTap;

  const _AssetTile({
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(asset.rarity);
    final locked = !asset.owned;
    final isThumbnail = asset.section == 'background' || asset.section == 'banner';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _selectedBorder : rarityColor,
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Asset image
              _assetPreview(asset, isThumbnail: isThumbnail),
              // Lock overlay
              if (locked)
                Container(
                  color: Colors.white.withOpacity(0.7),
                ),
              if (locked)
                const Center(
                  child: Icon(
                    Icons.lock_outline,
                    color: Color(0xFF7B8BA3),
                    size: 28,
                  ),
                ),
              // Price badge for purchasable items
              if (locked && asset.availability == 'purchasable')
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D76F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD54F),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${asset.priceHurra}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Selected indicator
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5D7CFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assetPreview(CardAsset asset, {required bool isThumbnail}) {
    final url = asset.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFFF0F4F8),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Color(0xFFB0BEC5),
            size: 32,
          ),
        ),
      );
    }

    final fit = isThumbnail ? BoxFit.cover : BoxFit.contain;

    if (url.toLowerCase().endsWith('.svg')) {
      return Container(
        color: isThumbnail ? null : Colors.transparent,
        padding: isThumbnail ? null : const EdgeInsets.all(8),
        child: SvgPicture.network(
          url,
          fit: fit,
          placeholderBuilder: (_) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      padding: isThumbnail ? null : const EdgeInsets.all(8),
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFFB0BEC5),
            size: 32,
          ),
        ),
      ),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'raro':
        return const Color(0xFF3B82F6);
      case 'epico':
        return const Color(0xFF8B5CF6);
      case 'legendario':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFD0D7E5);
    }
  }
}
