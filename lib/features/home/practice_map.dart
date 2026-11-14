import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:skillbridge_python_lab/app/theme.dart';
import 'package:skillbridge_python_lab/features/exercises/exercise.dart';

/// Warm palette for the Practice trail, kept separate from the cool blue
/// course path so the two maps read as different worlds.
class _Warm {
  const _Warm._();

  static const Color gold = Color(0xFFFFC857);
  static const Color ember = Color(0xFFFF9A3C);
  static const Color deep = Color(0xFF8A4B1E);
  static const Color trail = Color(0xFFB4713A);
  static const Color sand = Color(0xFF1C1305);
  static const Color ink = Color(0xFF241608);
}

/// Winding trail of practice challenges.
///
/// Each exercise is a warm shield node on a dashed sandy path; tapping one
/// springs the node, throws a spark burst and opens the challenge straight
/// away (navigation is synchronous so tests and real taps behave the same).
///
/// This widget is a *sliver*: it is meant to sit directly in a
/// `CustomScrollView`'s `slivers` list so the list stays lazy.
class PracticeMap extends StatelessWidget {
  const PracticeMap({
    super.key,
    required this.exercises,
    required this.hasDraft,
    required this.onOpen,
  });

  final List<Exercise> exercises;
  final bool Function(String exerciseId) hasDraft;
  final ValueChanged<Exercise> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return _PracticeRow(
          exercise: exercise,
          index: index,
          isLast: index == exercises.length - 1,
          hasDraft: hasDraft(exercise.id),
          onOpen: () => onOpen(exercise),
        );
      },
    );
  }
}

class _PracticeRow extends StatefulWidget {
  const _PracticeRow({
    required this.exercise,
    required this.index,
    required this.isLast,
    required this.hasDraft,
    required this.onOpen,
  });

  final Exercise exercise;
  final int index;
  final bool isLast;
  final bool hasDraft;
  final VoidCallback onOpen;

  @override
  State<_PracticeRow> createState() => _PracticeRowState();
}

class _PracticeRowState extends State<_PracticeRow>
    with SingleTickerProviderStateMixin {
  /// Node geometry shared by every row so the dashed trail lands exactly on
  /// the next node.
  static const double _nodeSize = 84;
  static const double _rowHeight = 168;
  static const double _labelTop = 92;
  static const double _labelWidth = 208;

  static const List<double> _wiggle = <double>[
    0,
    0.5,
    0.95,
    0.62,
    0.08,
    -0.52,
    -0.95,
    -0.44,
  ];

  late final AnimationController _controller;
  late final Animation<double> _spring;
  late final Animation<double> _burst;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _spring = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.09,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.09,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 56,
      ),
    ]).animate(_controller);
    _burst = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.06, 0.75, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: 'Task ${widget.index + 1}: ${widget.exercise.title}',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final amplitude = math.min(width * 0.21, 66.0);
            final centerX =
                width / 2 + _wiggle[widget.index % _wiggle.length] * amplitude;
            final nodeLeft = (centerX - _nodeSize / 2)
                .clamp(12.0, math.max(12.0, width - _nodeSize - 12))
                .toDouble();
            final labelLeft = (centerX - _labelWidth / 2)
                .clamp(12.0, math.max(12.0, width - _labelWidth - 12))
                .toDouble();

            return SizedBox(
              height: _rowHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!widget.isLast)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TrailPainter(
                          from: Offset(nodeLeft + _nodeSize / 2, _nodeSize / 2),
                          to: Offset(
                            nodeLeft + _nodeSize / 2,
                            _rowHeight + _nodeSize / 2,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: nodeLeft,
                    top: 0,
                    width: _nodeSize,
                    height: _nodeSize,
                    child: ScaleTransition(
                      scale: _spring,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _burst,
                                builder: (context, _) => CustomPaint(
                                  painter: _BurstPainter(
                                    progress: _burst.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _WarmShieldNode(
                            number: widget.index + 1,
                            hasDraft: widget.hasDraft,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: labelLeft,
                    top: _labelTop,
                    width: _labelWidth,
                    child: _TaskLabel(
                      number: widget.index + 1,
                      exercise: widget.exercise,
                      hasDraft: widget.hasDraft,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WarmShieldNode extends StatelessWidget {
  const _WarmShieldNode({required this.number, required this.hasDraft});

  final int number;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Chunky warm lip gives the node its 3D edge.
          Positioned.fill(
            child: ClipPath(
              clipper: const _ShieldClipper(),
              child: const ColoredBox(color: _Warm.deep),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 7,
            child: ClipPath(
              clipper: const _ShieldClipper(),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD98A), _Warm.ember],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: _Warm.ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 7,
            child: CustomPaint(
              painter: _ShieldBorderPainter(
                color: _Warm.gold.withValues(alpha: 0.9),
                strokeWidth: 2,
              ),
            ),
          ),
          if (hasDraft)
            Positioned(
              right: -2,
              bottom: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _Warm.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Warm.gold, width: 2),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: _Warm.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskLabel extends StatelessWidget {
  const _TaskLabel({
    required this.number,
    required this.exercise,
    required this.hasDraft,
  });

  final int number;
  final Exercise exercise;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'TASK ${number.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: _Warm.trail,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          exercise.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: SkillBridgeColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          exercise.instructions,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: SkillBridgeColors.textMuted,
            fontSize: 11,
          ),
        ),
        if (hasDraft) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _Warm.ember.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _Warm.ember.withValues(alpha: 0.55)),
            ),
            child: const Text(
              'DRAFT',
              style: TextStyle(
                color: _Warm.gold,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dashed sandy path from this node to the next one. Painted with
/// `Clip.none` so the dashes can spill into the following row and slide
/// behind the next node.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = (from.dy + to.dy) / 2;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = _Warm.sand,
    );

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = _Warm.trail;
    const dashLength = 11.0;
    const dashStep = 20.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), dash);
        distance += dashStep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}

/// Expanding ring + spark particles thrown when a task is tapped.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final t = progress;
    final fade = 1 - t;

    canvas.drawCircle(
      center,
      size.width / 2 + 4 + 34 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + 2.5 * fade
        ..color = _Warm.gold.withValues(alpha: 0.85 * fade),
    );
    canvas.drawCircle(
      center,
      size.width / 2 + 8 + 20 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * fade
        ..color = _Warm.ember.withValues(alpha: 0.7 * fade),
    );

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + 0.35;
      final distance = 16 + 30 * t;
      final offset = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      canvas.drawCircle(
        offset,
        4.2 - 2.6 * t,
        Paint()
          ..color = (i.isEven ? _Warm.gold : _Warm.ember).withValues(
            alpha: 0.95 * fade,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ShieldClipper extends CustomClipper<Path> {
  const _ShieldClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.3;
    final shoulder = h * 0.6;
    return Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, shoulder)
      ..quadraticBezierTo(w, h * 0.88, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.88, 0, shoulder)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ShieldBorderPainter extends CustomPainter {
  _ShieldBorderPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      const _ShieldClipper().getClip(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
