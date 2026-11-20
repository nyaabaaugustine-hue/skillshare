import 'package:flutter/material.dart';

/// Gives any tappable widget a tactile "press" response: it eases down a few
/// percent while a finger or mouse button is held, then springs back.
///
/// It listens to raw pointer events, so it never competes with the child's own
/// tap handling (InkWell, GestureDetector, buttons) and never swallows a tap or
/// a scroll. Respects the system "reduce motion" setting.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.965,
  });

  final Widget child;

  /// Disabled widgets do not animate (pass `onTap != null`).
  final bool enabled;

  /// Scale while pressed; 1.0 is full size.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final pressed = _down && widget.enabled && !reduced;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1,
        duration: Duration(milliseconds: pressed ? 90 : 220),
        curve: pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
