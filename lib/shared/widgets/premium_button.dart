import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skillbridge_python_lab/app/theme.dart';

/// A glossy, gradient call-to-action button with a soft glow, a light sweep
/// highlight and a springy press. Used for the primary actions on Home.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gold = false,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Gold variant for reward-style actions; blue is the default.
  final bool gold;
  final double height;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = widget.gold
        ? const [Color(0xFFFFD66B), Color(0xFFF2A81D)]
        // Deep enough for white label text to stay legible (AA), unlike the
        // previous #3FA0FF top step.
        : const [Color(0xFF2270D6), Color(0xFF0A57B8)];
    final glow = widget.gold ? const Color(0xFFF2A81D) : SkillBridgeColors.primary;
    final fg = widget.gold ? const Color(0xFF2A1D00) : Colors.white;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: _down ? 0.25 : 0.45),
                    blurRadius: _down ? 10 : 22,
                    offset: Offset(0, _down ? 3 : 9),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Soft top highlight gives the glossy premium finish.
                  Positioned(
                    left: 14,
                    right: 14,
                    top: 4,
                    height: widget.height * 0.36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.32),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: fg, size: 24),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
