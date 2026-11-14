import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../shared/widgets/icon_badge.dart';

/// Cold-start splash on a clean white canvas.
///
/// The SkillBridge mark rises into the centre while two counter-rotating
/// rings of learning icons orbit it. Icons on the far side of the orbit are
/// drawn behind the mark, smaller and dimmer; icons on the near side are drawn
/// in front, larger and brighter, so the rings read as real depth rather than a
/// flat carousel. Soft ripples pulse outwards, the brand text cascades in, and
/// an indeterminate bar holds until the dependency graph is ready.
///
/// The gate is [ready]: the splash never finishes before the app can actually
/// show the next screen, and never before [minDuration] has elapsed so the
/// animation reads as intentional instead of a flash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onDone,
    this.ready = false,
    this.minDuration = const Duration(milliseconds: 3000),
  });

  final VoidCallback onDone;
  final bool ready;
  final Duration minDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _inkMuted = Color(0xFF5A6B82);

  /// One-shot choreography: mark rises, icons fan out, text cascades.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  /// Gentle breathing loop for the halo, bobbing and the startup bar.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// Continuous orbit clocks: the icon ring turns clockwise, the spark ring
  /// counter-clockwise at a different speed, which makes the two rings feel
  /// independent instead of locked together.
  late final AnimationController _outerSpin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );
  late final AnimationController _innerSpin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 17),
  );

  /// Expanding ripple rings.
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  Timer? _gate;
  bool _done = false;
  bool _elapsed = false;
  bool _started = false;

  static const _orbitIcons = <_OrbitIcon>[
    _OrbitIcon(Icons.code_rounded, IconBadge.blue),
    _OrbitIcon(Icons.menu_book_rounded, IconBadge.teal),
    _OrbitIcon(Icons.emoji_events_rounded, IconBadge.gold),
    _OrbitIcon(Icons.rocket_launch_rounded, IconBadge.coral),
    _OrbitIcon(Icons.psychology_rounded, IconBadge.purple),
    _OrbitIcon(Icons.bolt_rounded, IconBadge.green),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _entrance.value = 1;
      _elapsed = true;
      _finishWhenReady();
    } else {
      _entrance.forward();
      _loop.repeat(reverse: true);
      _outerSpin.repeat();
      _innerSpin.repeat();
      _ripple.repeat();
      _gate = Timer(widget.minDuration, () {
        _elapsed = true;
        _finishWhenReady();
      });
    }
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready != oldWidget.ready) _finishWhenReady();
  }

  void _finishWhenReady() {
    if (_done || !_elapsed || !widget.ready || !mounted) return;
    _done = true;
    _gate?.cancel();
    scheduleMicrotask(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _gate?.cancel();
    _entrance.dispose();
    _loop.dispose();
    _outerSpin.dispose();
    _innerSpin.dispose();
    _ripple.dispose();
    super.dispose();
  }

  Widget _stagger({
    required double from,
    required double to,
    required Widget child,
  }) {
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(from, to, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final pulse = CurvedAnimation(parent: _loop, curve: Curves.easeInOut);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                SizedBox(
                  width: 360,
                  height: 360,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Expanding ripples behind everything.
                      if (!reduced)
                        AnimatedBuilder(
                          animation: _ripple,
                          builder: (context, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < 3; i++)
                                _RippleRing(
                                  t: (_ripple.value + i / 3) % 1.0,
                                  maxSize: 340,
                                ),
                            ],
                          ),
                        ),
                      // Soft brand halo behind the mark.
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (context, child) => Container(
                          width: 224 + pulse.value * 34,
                          height: 224 + pulse.value * 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                SkillBridgeColors.primary.withValues(
                                  alpha: 0.16 - pulse.value * 0.06,
                                ),
                                SkillBridgeColors.primary.withValues(
                                  alpha: 0.04,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.62, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Dashed orbit tracks, spinning with their rings.
                      if (!reduced) ...[
                        AnimatedBuilder(
                          animation: _outerSpin,
                          builder: (context, _) => CustomPaint(
                            size: const Size.square(320),
                            painter: _OrbitRingPainter(
                              radius: 150,
                              rotation: _outerSpin.value * 2 * math.pi,
                              color: SkillBridgeColors.primary,
                              alpha: 0.16,
                              dash: 5,
                              gap: 11,
                              width: 1.6,
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _innerSpin,
                          builder: (context, _) => CustomPaint(
                            size: const Size.square(300),
                            painter: _OrbitRingPainter(
                              radius: 104,
                              rotation: -_innerSpin.value * 2 * math.pi,
                              color: SkillBridgeColors.primaryDeep,
                              alpha: 0.10,
                              dash: 3,
                              gap: 9,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ],
                      // Back half of the orbit sits behind the mark.
                      _OrbitLayer(
                        key: const ValueKey('orbit-back'),
                        front: false,
                        reduced: reduced,
                        entrance: _entrance,
                        loop: _loop,
                        outerSpin: _outerSpin,
                        innerSpin: _innerSpin,
                      ),
                      // Brand mark, gently bobbing once settled.
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, -3 + pulse.value * 7),
                          child: child,
                        ),
                        child: ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _entrance,
                            curve: const Interval(
                              0.0,
                              0.6,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _entrance,
                              curve: const Interval(0.0, 0.35),
                            ),
                            child: _LogoMark(
                              size: 190 + pulse.value * 4,
                            ),
                          ),
                        ),
                      ),
                      // Front half of the orbit sits over the mark.
                      _OrbitLayer(
                        key: const ValueKey('orbit-front'),
                        front: true,
                        reduced: reduced,
                        entrance: _entrance,
                        loop: _loop,
                        outerSpin: _outerSpin,
                        innerSpin: _innerSpin,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _stagger(
                  from: 0.45,
                  to: 0.75,
                  child: const Text(
                    'SKILLBRIDGE ACADEMY',
                    style: TextStyle(
                      color: _inkMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _stagger(
                  from: 0.55,
                  to: 0.85,
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [Color(0xFF0B3E75), Color(0xFF1273E6)],
                    ).createShader(rect),
                    child: const Text(
                      'Python Development',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 33,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _stagger(
                  from: 0.65,
                  to: 1.0,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 34),
                    child: Text(
                      'Learning that connects students, parents and teachers — '
                      'anywhere, even offline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _inkMuted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                _stagger(
                  from: 0.7,
                  to: 1.0,
                  child: _StartupBar(animation: reduced ? null : _loop),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The SkillBridge mark, drawn from the transparent asset so it sits directly
/// on the white canvas without a white tile around it.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          'assets/icon/app_mark.png',
          width: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'SkillBridge Academy logo',
        ),
      ),
    );
  }
}

/// One half of the orbiting system. Splitting into back/front layers is what
/// gives the ring its sense of depth: the same angle maths drives both, but the
/// near half is scaled up, brighter, and drawn on top of the mark.
class _OrbitLayer extends StatelessWidget {
  const _OrbitLayer({
    super.key,
    required this.front,
    required this.reduced,
    required this.entrance,
    required this.loop,
    required this.outerSpin,
    required this.innerSpin,
  });

  final bool front;
  final bool reduced;
  final Animation<double> entrance;
  final Animation<double> loop;
  final Animation<double> outerSpin;
  final Animation<double> innerSpin;

  static const _icons = _SplashScreenState._orbitIcons;

  @override
  Widget build(BuildContext context) {
    if (reduced) {
      // Static, fully settled ring so reduced-motion users still see the
      // arrangement rather than an empty canvas.
      return _buildFrame(
        entranceValue: 1,
        loopValue: 0.5,
        outerValue: 0,
        innerValue: 0,
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, loop, outerSpin, innerSpin]),
      builder: (context, _) => _buildFrame(
        entranceValue: entrance.value,
        loopValue: loop.value,
        outerValue: outerSpin.value,
        innerValue: innerSpin.value,
      ),
    );
  }

  Widget _buildFrame({
    required double entranceValue,
    required double loopValue,
    required double outerValue,
    required double innerValue,
  }) {
    final breathe = math.sin(loopValue * 2 * math.pi);
    final children = <Widget>[];

    // Outer ring: icon badges, clockwise.
    for (var i = 0; i < _icons.length; i++) {
      final base = i * 2 * math.pi / _icons.length;
      final angle = outerValue * 2 * math.pi + base;
      final a = angle - math.pi / 2;
      final depth = (math.sin(a) + 1) / 2; // 0 at the back, 1 at the front.
      if ((depth >= 0.5) != front) continue;

      final stagger = const Interval(0.12, 0.62).transform(
        ((entranceValue - i * 0.045) / (1 - i * 0.045)).clamp(0.0, 1.0),
      );
      final enter = Curves.easeOutCubic.transform(stagger);
      final fan = Curves.easeOutBack.transform(stagger);
      final radius = 150 * fan + breathe * 2.5;
      final scale =
          (0.45 + 0.55 * enter) * (0.78 + 0.30 * depth) * (0.97 + 0.03 * breathe);
      final opacity = enter * (0.58 + 0.42 * depth);
      final badge = _icons[i];

      children.add(
        _orbiter(
          angle: a,
          radius: radius,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: 0.14 * math.sin(loopValue * 2 * math.pi + i),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: badge.colors.last.withValues(
                          alpha: 0.20 + 0.24 * depth,
                        ),
                        blurRadius: 8 + 16 * depth,
                        offset: Offset(0, 3 + 6 * depth),
                      ),
                    ],
                  ),
                  child: IconBadge(
                    icon: badge.icon,
                    colors: badge.colors,
                    size: 44,
                    glow: false,
                    circle: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Inner ring: tiny spark dots, counter-clockwise, always behind the mark.
    if (!front) {
      for (var i = 0; i < 8; i++) {
        final angle = -innerValue * 2 * math.pi + i * 2 * math.pi / 8;
        final a = angle - math.pi / 2;
        final depth = (math.sin(a) + 1) / 2;
        final enter = Curves.easeOutCubic.transform(
          const Interval(0.3, 0.8).transform(entranceValue),
        );
        children.add(
          _orbiter(
            angle: a,
            radius: 104 * enter,
            child: Opacity(
              opacity: enter * (0.35 + 0.55 * depth),
              child: Container(
                width: i.isEven ? 7 : 5,
                height: i.isEven ? 7 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (i.isEven
                          ? SkillBridgeColors.primary
                          : SkillBridgeColors.accent)
                      .withValues(alpha: 0.85),
                  boxShadow: [
                    BoxShadow(
                      color: SkillBridgeColors.primary.withValues(alpha: 0.28),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: children,
    );
  }

  /// Places [child] on a circle of [radius] at [angle] (0 = 12 o'clock).
  Widget _orbiter({
    required double angle,
    required double radius,
    required Widget child,
  }) {
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      child: child,
    );
  }
}

class _OrbitIcon {
  const _OrbitIcon(this.icon, this.colors);

  final IconData icon;
  final List<Color> colors;
}

/// A thin dashed circle used as an orbit track.
class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({
    required this.radius,
    required this.rotation,
    required this.color,
    required this.alpha,
    required this.dash,
    required this.gap,
    required this.width,
  });

  final double radius;
  final double rotation;
  final Color color;
  final double alpha;
  final double dash;
  final double gap;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final circumference = 2 * math.pi * radius;
    final step = (dash + gap) / circumference * 2 * math.pi;
    final sweep = dash / circumference * 2 * math.pi;

    for (var a = rotation; a < rotation + 2 * math.pi; a += step) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.radius != radius ||
      oldDelegate.alpha != alpha;
}

/// One expanding, fading ring. [t] runs 0 → 1 over its life.
class _RippleRing extends StatelessWidget {
  const _RippleRing({required this.t, required this.maxSize});

  final double t;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final size = 140 + (maxSize - 140) * Curves.easeOut.transform(t);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: SkillBridgeColors.primary.withValues(alpha: (1 - t) * 0.18),
          width: 1.4,
        ),
      ),
    );
  }
}

/// Thin indeterminate bar under the brand block; doubles as the "still
/// starting" signal while the dependency graph loads.
class _StartupBar extends StatelessWidget {
  const _StartupBar({required this.animation});

  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    const width = 180.0;
    return SizedBox(
      width: width,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Container(color: const Color(0xFFE6EDF7)),
            if (animation == null)
              const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: width,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Colors.transparent,
                    color: SkillBridgeColors.primary,
                  ),
                ),
              )
            else
              AnimatedBuilder(
                animation: animation!,
                builder: (context, child) {
                  final t = animation!.value;
                  final x = (width - 68) * t;
                  return Transform.translate(
                    offset: Offset(x, 0),
                    child: child,
                  );
                },
                child: Container(
                  width: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: SkillBridgeColors.brandGradient,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
