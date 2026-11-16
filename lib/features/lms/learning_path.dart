import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:skillbridge_python_lab/core/di/app_dependencies.dart';

import '../../app/theme.dart';
import 'learning_map.dart';

/// Compact, game-style summary of the 8 lessons in Unit 1: a unit header, a
/// winding path of pentagon nodes (done / current / locked) and a detail card
/// for whichever node the learner taps. Replaces the long list of lesson
/// tiles so all 8 lessons are visible at a glance.
class LearningPathView extends StatefulWidget {
  const LearningPathView({super.key});

  @override
  State<LearningPathView> createState() => _LearningPathViewState();
}

class _LearningPathViewState extends State<LearningPathView> {
  static const _nodeSize = 92.0;
  static const _step = 118.0;
  static const _topPad = 52.0;

  /// Horizontal wiggle of each node, as a fraction of the available swing.
  static const _wiggle = <double>[0, 0.9, 0.35, -0.7, 0, 0.9, 0.3, -0.7];

  static const _icons = <IconData>[
    Icons.psychology_rounded,
    Icons.terminal_rounded,
    Icons.code_rounded,
    Icons.compare_arrows_rounded,
    Icons.bolt_rounded,
    Icons.settings_suggest_rounded,
    Icons.category_rounded,
    Icons.data_object_rounded,
  ];

  int _completed = 0;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    try {
      final deps = context.read<AppDependencies>();
      final progress = await deps.lmsClient.fetchProgress();
      if (!mounted) return;
      setState(() {
        _completed = progress.completedChallenges.clamp(
          0,
          learningPlaces.length,
        );
      });
    } catch (_) {
      // Keep the first place as the starting point when offline.
    }
  }

  _NodeState _stateFor(int i) {
    if (i < _completed) return _NodeState.done;
    if (i == _completed) return _NodeState.current;
    return _NodeState.locked;
  }

  @override
  Widget build(BuildContext context) {
    final count = learningPlaces.length;
    final current = _completed.clamp(0, count - 1);
    final selected = _selected ?? current;
    final height = _topPad + _step * (count - 1) + _nodeSize + 24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _UnitHeader(),
        const SizedBox(height: 14),
        const _SectionDivider(label: 'PYTHON KICKSTART'),
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final swing = (w - _nodeSize) / 2 * 0.62;
            final centers = <Offset>[
              for (var i = 0; i < count; i++)
                Offset(
                  w / 2 + _wiggle[i % _wiggle.length] * swing,
                  _topPad + _nodeSize / 2 + _step * i,
                ),
            ];
            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _PathPainter(centers)),
                  ),
                  for (var i = 0; i < count; i++)
                    Positioned(
                      left: centers[i].dx - _nodeSize / 2,
                      top: centers[i].dy - _nodeSize / 2,
                      width: _nodeSize,
                      height: _nodeSize + 8,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selected = i),
                        child: _PentagonNode(
                          icon: _icons[i % _icons.length],
                          state: _stateFor(i),
                          highlighted: i == selected,
                        ),
                      ),
                    ),
                  Positioned(
                    left: centers[current].dx - 45,
                    top: centers[current].dy - _nodeSize / 2 - 40,
                    width: 90,
                    child: const _StartBubble(),
                  ),
                ],
              ),
            );
          },
        ),
        _DetailCard(
          place: learningPlaces[selected],
          state: _stateFor(selected),
        ),
      ],
    );
  }
}

enum _NodeState { done, current, locked }

class _UnitHeader extends StatelessWidget {
  const _UnitHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: SkillBridgeColors.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SkillBridgeColors.outline, width: 1.4),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0A0D12), offset: Offset(0, 6)),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECTION FOUNDATIONS',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: SkillBridgeColors.textMuted,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Unit 1: Python Kickstart',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(color: SkillBridgeColors.outline, thickness: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: SkillBridgeColors.textMuted,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _StartBubble extends StatelessWidget {
  const _StartBubble();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          decoration: BoxDecoration(
            color: SkillBridgeColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SkillBridgeColors.outline),
          ),
          child: const Text(
            'Start',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: SkillBridgeColors.textMuted,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(14, 7),
          painter: _TrianglePainter(SkillBridgeColors.outline),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// The thick winding trail that joins the lesson nodes.
class _PathPainter extends CustomPainter {
  _PathPainter(this.centers);

  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1];
      final b = centers[i];
      final mid = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, mid, b.dx, mid, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1E2430),
    );
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.centers != centers;
}

class _PentagonNode extends StatelessWidget {
  const _PentagonNode({
    required this.icon,
    required this.state,
    required this.highlighted,
  });

  final IconData icon;
  final _NodeState state;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final (face, edge, iconColor) = switch (state) {
      _NodeState.current => (
        const Color(0xFF1E90FF),
        const Color(0xFF0B5FC4),
        Colors.white,
      ),
      _NodeState.done => (
        const Color(0xFF3CCB6C),
        const Color(0xFF218A47),
        Colors.white,
      ),
      _NodeState.locked => (
        const Color(0xFF3A3F50),
        const Color(0xFF262A37),
        const Color(0xFF9AA1B5),
      ),
    };
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        CustomPaint(
          size: const Size(92, 100),
          painter: _PentagonPainter(
            face: face,
            edge: edge,
            ring: highlighted || state == _NodeState.current,
            ringColor: state == _NodeState.done
                ? const Color(0xFF3CCB6C)
                : SkillBridgeColors.primary,
          ),
        ),
        SizedBox(
          width: 92,
          height: 86,
          child: Icon(
            state == _NodeState.done ? Icons.check_rounded : icon,
            size: 38,
            color: iconColor,
          ),
        ),
      ],
    );
  }
}

class _PentagonPainter extends CustomPainter {
  _PentagonPainter({
    required this.face,
    required this.edge,
    required this.ring,
    required this.ringColor,
  });

  final Color face;
  final Color edge;
  final bool ring;
  final Color ringColor;

  Path _shape(double w, double h, double dy) => Path()
    ..moveTo(w * 0.5, dy)
    ..lineTo(w, dy + h * 0.38)
    ..lineTo(w * 0.82, dy + h)
    ..lineTo(w * 0.18, dy + h)
    ..lineTo(0, dy + h * 0.38)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - 12;
    const h = 80.0;
    canvas.save();
    canvas.translate(6, 4);
    if (ring) {
      canvas.drawPath(
        _shape(w, h, 0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.round
          ..color = ringColor.withValues(alpha: 0.28),
      );
    }
    void draw(Path p, Color c) {
      canvas.drawPath(p, Paint()..color = c);
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.round
          ..color = c,
      );
    }

    draw(_shape(w, h, 8), edge); // 3D base
    draw(_shape(w, h, 0), face); // top face
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PentagonPainter old) =>
      old.face != face || old.ring != ring || old.edge != edge;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.place, required this.state});

  final LearningPlace place;
  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    final locked = state == _NodeState.locked;
    final done = state == _NodeState.done;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SkillBridgeColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SkillBridgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: SkillBridgeColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: SkillBridgeColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'LESSON ${place.number}',
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: Color(0xFF6FB0FF),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            place.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            place.duration,
            style: const TextStyle(color: SkillBridgeColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: locked
                ? null
                : () => Navigator.of(context).pushNamed(
                    '/lms-video',
                    arguments: {
                      'title': place.title,
                      'subtitle': place.duration,
                      'publicId': place.publicId,
                    },
                  ),
            child: Text(
              locked
                  ? 'LOCKED…'
                  : done
                  ? 'REVIEW'
                  : 'START',
            ),
          ),
        ],
      ),
    );
  }
}
