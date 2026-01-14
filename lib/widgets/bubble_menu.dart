import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A floating action button that expands to reveal multiple menu items.
class BubbleMenu extends StatefulWidget {
  final List<BubbleMenuItem> items;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const BubbleMenu({
    super.key,
    required this.items,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<BubbleMenu> createState() => _BubbleMenuState();
}

class _BubbleMenuState extends State<BubbleMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      _toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems =
        widget.items.where((item) => item.visible).toList();
    final bgColor = widget.backgroundColor ?? const Color(0xFF0A2A6B);
    final fgColor = widget.foregroundColor ?? Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Menu items (shown when open)
        ...List.generate(visibleItems.length, (index) {
          final item = visibleItems[visibleItems.length - 1 - index];
          return AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _expandAnimation,
                axisAlignment: 1.0,
                child: FadeTransition(
                  opacity: _expandAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12, right: 8),
                    child: child,
                  ),
                ),
              );
            },
            child: _BubbleItem(
              item: item,
              onTap: () {
                _close();
                item.onTap();
              },
            ),
          );
        }),
        // Main FAB
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: FloatingActionButton(
            onPressed: _toggle,
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _expandAnimation.value * math.pi / 4,
                  child: widget.icon ?? const Icon(Icons.add, size: 28),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleItem extends StatelessWidget {
  final BubbleMenuItem item;
  final VoidCallback onTap;

  const _BubbleItem({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.label != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              item.label!,
              style: const TextStyle(
                color: Color(0xFF0F1B2D),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        if (item.label != null) const SizedBox(width: 12),
        Material(
          elevation: 4,
          shape: const CircleBorder(),
          color: item.backgroundColor ?? const Color(0xFF1D76F2),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                item.icon,
                color: item.foregroundColor ?? Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Represents an item in the bubble menu.
class BubbleMenuItem {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool visible;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const BubbleMenuItem({
    required this.icon,
    this.label,
    required this.onTap,
    this.visible = true,
    this.backgroundColor,
    this.foregroundColor,
  });
}
