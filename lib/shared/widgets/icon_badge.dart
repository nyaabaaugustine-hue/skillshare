import 'package:flutter/material.dart';

/// A glossy rounded-square icon tile: gradient fill, soft coloured glow and a
/// thin light rim. Used for the orbiting icons on the splash screen and the
/// role cards on the sign-in screen so the app's iconography feels consistent.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.colors = const [Color(0xFF3FA0FF), Color(0xFF0B63D6)],
    this.iconColor = Colors.white,
    this.glow = true,
    this.circle = false,
  });

  final IconData icon;
  final double size;
  final List<Color> colors;
  final Color iconColor;
  final bool glow;
  final bool circle;

  /// Ready-made palettes so call sites stay readable.
  static const blue = [Color(0xFF3FA0FF), Color(0xFF0B63D6)];
  static const gold = [Color(0xFFFFD66B), Color(0xFFF2A81D)];
  static const green = [Color(0xFF5BE49B), Color(0xFF16A34A)];
  static const purple = [Color(0xFFB794F6), Color(0xFF6D3BD2)];
  static const coral = [Color(0xFFFF8A8A), Color(0xFFE5484D)];
  static const teal = [Color(0xFF5EEAD4), Color(0xFF0D9488)];

  @override
  Widget build(BuildContext context) {
    final radius = circle
        ? BorderRadius.circular(size)
        : BorderRadius.circular(size * 0.3);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.45),
                  blurRadius: size * 0.45,
                  offset: Offset(0, size * 0.14),
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: iconColor, size: size * 0.52),
    );
  }
}
