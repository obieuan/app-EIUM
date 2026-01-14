import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/card_asset.dart';
import '../services/auth_service.dart';
import '../services/card_service.dart';

class StoreScreen extends StatefulWidget {
  final int hurraBalance;
  final VoidCallback? onPurchase;

  const StoreScreen({
    super.key,
    required this.hurraBalance,
    this.onPurchase,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  static const _sections = ['background', 'banner', 'title_badge', 'medal'];
  static const _sectionLabels = {
    'background': 'Fondos',
    'banner': 'Banners',
    'title_badge': 'Títulos',
    'medal': 'Medallas',
  };

  final AuthService _authService = AuthService();
  final CardService _cardService = CardService();

  late TabController _tabController;
  Map<String, List<CardAsset>> _assetsBySection = {};
  Set<int> _ownedAssetIds = {};
  bool _isLoading = true;
  String? _error;
  bool _isPurchasing = false;
  late int _currentBalance;

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.hurraBalance;
    _tabController = TabController(length: _sections.length, vsync: this);
    _loadAssets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final session = await _authService.getValidSession();
    final token = session?.idToken;
    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'No hay sesión activa';
      });
      return;
    }

    try {
      final Map<String, List<CardAsset>> assets = {};
      for (final section in _sections) {
        final list = await _cardService.fetchAssetsBySection(token, section);
        assets[section] = list;
        // Collect owned asset IDs from the assets themselves
        for (final asset in list) {
          if (asset.owned) {
            _ownedAssetIds.add(asset.id);
          }
        }
      }

      if (mounted) {
        setState(() {
          _assetsBySection = assets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar la tienda';
        });
      }
    }
  }

  Future<void> _purchaseAsset(CardAsset asset) async {
    if (_isPurchasing) return;

    final confirmed = await _confirmPurchase(asset);
    if (!confirmed) return;

    setState(() => _isPurchasing = true);

    try {
      final session = await _authService.getValidSession();
      final token = session?.idToken;
      if (token == null) throw Exception('No autenticado');

      final success = await _cardService.purchaseAsset(token, asset.id);
      if (!mounted) return;

      if (success) {
        setState(() {
          _ownedAssetIds.add(asset.id);
          _currentBalance -= asset.priceHurra;
        });
        _showSnackBar('¡Compra exitosa! Ya tienes "${asset.name}"');
        widget.onPurchase?.call();
      } else {
        _showSnackBar('No se pudo completar la compra');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al comprar');
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<bool> _confirmPurchase(CardAsset asset) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar compra'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (asset.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      asset.imageUrl!,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        size: 60,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  asset.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFB800), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${asset.priceHurra} Hurra',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB8860B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu balance: $_currentBalance Hurra',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                if (_currentBalance < asset.priceHurra)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No tienes suficientes Hurra',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _currentBalance >= asset.priceHurra
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('Comprar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF6F8FC),
      child: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0A2A6B),
            unselectedLabelColor: const Color(0xFF7B8BA3),
            indicatorColor: const Color(0xFF0A2A6B),
            tabs: _sections
                .map((s) => Tab(text: _sectionLabels[s] ?? s))
                .toList(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!,
                                style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loadAssets,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: _sections.map((section) {
                          final assets = _assetsBySection[section] ?? [];
                          return _buildAssetGrid(assets, section);
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Text(
            'Tienda',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0A2A6B),
                ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE566),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/coinHurra.svg',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_currentBalance',
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
    );
  }

  Widget _buildAssetGrid(List<CardAsset> assets, String section) {
    if (assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No hay items disponibles',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Filter to only show purchasable items (not owned)
    final purchasableAssets =
        assets.where((a) => !_ownedAssetIds.contains(a.id)).toList();

    if (purchasableAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
            const SizedBox(height: 12),
            Text(
              '¡Ya tienes todos los items de esta sección!',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final isThumbnail = section == 'background' || section == 'banner';

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isThumbnail ? 2 : 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isThumbnail ? 0.85 : 0.75,
      ),
      itemCount: purchasableAssets.length,
      itemBuilder: (context, index) {
        final asset = purchasableAssets[index];
        return _StoreAssetCard(
          asset: asset,
          isThumbnail: isThumbnail,
          onTap: () => _purchaseAsset(asset),
          isPurchasing: _isPurchasing,
        );
      },
    );
  }
}

class _StoreAssetCard extends StatelessWidget {
  final CardAsset asset;
  final bool isThumbnail;
  final VoidCallback onTap;
  final bool isPurchasing;

  const _StoreAssetCard({
    required this.asset,
    required this.isThumbnail,
    required this.onTap,
    required this.isPurchasing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isPurchasing ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: asset.imageUrl != null
                    ? Image.network(
                        asset.imageUrl!,
                        fit: isThumbnail ? BoxFit.cover : BoxFit.contain,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE566),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            size: 12, color: Color(0xFFB8860B)),
                        const SizedBox(width: 2),
                        Text(
                          '${asset.priceHurra}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFFB8860B),
                          ),
                        ),
                      ],
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

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFE8EEF8),
      child: const Center(
        child: Icon(Icons.image, size: 32, color: Color(0xFFB9C7E6)),
      ),
    );
  }
}
