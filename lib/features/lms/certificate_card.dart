import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';


/// Everything the certificate needs to render itself.
class CertificateModel {
  const CertificateModel({
    required this.learnerName,
    required this.courseTitle,
    required this.completedOn,
    required this.xpEarned,
    required this.stepCount,
  });

  final String learnerName;
  final String courseTitle;
  final DateTime completedOn;
  final int xpEarned;
  final int stepCount;

  /// Stable, human-readable certificate reference: year, completed steps and
  /// XP. Printed in the footer so a certificate can be checked by hand.
  String get certificateId =>
      'SB-${completedOn.year}-'
      '${stepCount.toString().padLeft(3, '0')}-'
      '${(xpEarned % 100000).toString().padLeft(5, '0')}';
}

/// A premium, print-ready completion certificate.
///
/// Deliberately styled like a physical award: warm paper with a guilloche
/// rosette, a double gold frame, the transparent brand mark blended into the
/// paper (no white tile), the learner's name in the largest type on the page,
/// a foiled seal with ribbon tails, a signature line and a verification code.
/// It is a plain widget so it can be shown locked, previewed as a sample, or
/// captured to an image for download.
class CertificateCard extends StatelessWidget {
  const CertificateCard({
    super.key,
    required this.model,
    this.width = 720,
  });

  final CertificateModel model;
  final double width;

  static const _navy = Color(0xFF0C2C5B);
  static const _gold = Color(0xFFC9A227);
  static const _ink = Color(0xFF1B2A3F);
  static const _body = Color(0xFF6A5F4B);

  double _clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  @override
  Widget build(BuildContext context) {
    final pad = width * 0.042;
    final titleSize = _clamp(width * 0.045, 17, 33);
    final nameSize = _clamp(width * 0.058, 21, 43);
    final courseSize = _clamp(width * 0.026, 12.5, 19);
    final bodySize = _clamp(width * 0.0185, 9.5, 14);
    final sealSize = _clamp(width * 0.105, 46, 78);

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF7), Color(0xFFF6EEDC), Color(0xFFFBF6E9)],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(_clamp(width * 0.024, 14, 20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_clamp(width * 0.024, 14, 20)),
        child: Stack(
          children: [
            // Engraved paper pattern, drawn behind every element.
            Positioned.fill(
              child: CustomPaint(painter: const _PaperPainter()),
            ),
            // Faint brand watermark, centred behind the wording.
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.055,
                  child: Image.asset(
                    'assets/icon/app_mark.png',
                    width: width * 0.58,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(pad * 0.55),
              child: Container(
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  border: Border.all(color: _gold, width: 2.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: pad * 0.9,
                    vertical: pad,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _navy.withValues(alpha: 0.22),
                      width: 0.9,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Emblem(width: _clamp(width * 0.115, 52, 86)),
                      SizedBox(height: pad * 0.7),
                      Text(
                        'SKILLSBRIDGE ACADEMY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _navy,
                          fontSize: _clamp(width * 0.0135, 8, 13),
                          fontWeight: FontWeight.w800,
                          letterSpacing: width * 0.0044,
                        ),
                      ),
                      SizedBox(height: pad * 0.55),
                      _GoldRule(width: width * 0.5),
                      SizedBox(height: pad * 0.75),
                      Text(
                        'Certificate of Completion',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _navy,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          height: 1.12,
                        ),
                      ),
                      SizedBox(height: pad * 0.6),
                      Text(
                        'This certificate is proudly presented to',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _body,
                          fontSize: bodySize,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: pad * 0.4),
                      Text(
                        model.learnerName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: nameSize,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: pad * 0.22),
                      Container(
                        width: width * 0.46,
                        height: 1.4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _gold.withValues(alpha: 0.0),
                              _gold,
                              _gold.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: pad * 0.5),
                      Text(
                        'for successfully completing the course',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _body, fontSize: bodySize),
                      ),
                      SizedBox(height: pad * 0.3),
                      Text(
                        model.courseTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _navy,
                          fontSize: courseSize,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: pad * 0.6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetricChip(
                            icon: Icons.emoji_events_rounded,
                            label: '${model.stepCount} lessons completed',
                            fontSize: bodySize * 0.86,
                          ),
                          _MetricChip(
                            icon: Icons.bolt_rounded,
                            label: '${model.xpEarned} XP earned',
                            fontSize: bodySize * 0.86,
                          ),
                          _MetricChip(
                            icon: Icons.verified_rounded,
                            label: 'Verified award',
                            fontSize: bodySize * 0.86,
                          ),
                        ],
                      ),
                      SizedBox(height: pad * 0.95),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _FooterField(
                              value: _formatDate(model.completedOn),
                              caption: 'DATE COMPLETED',
                              color: _navy,
                              fontSize: bodySize,
                            ),
                          ),
                          _RibbonSeal(size: sealSize),
                          Expanded(
                            child: _FooterField(
                              value: 'SkillsBridge Academy',
                              caption: 'AUTHORISED SIGNATURE',
                              color: _navy,
                              fontSize: bodySize,
                              italic: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: pad * 0.7),
                      Text(
                        'Certificate ID ${model.certificateId}  ·  '
                        'Verify at skillsbridge.academy/verify',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _body.withValues(alpha: 0.8),
                          fontSize: _clamp(width * 0.0115, 7, 10.5),
                          letterSpacing: 0.9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// The brand mark in a gold medallion. The asset is transparent, so the paper
/// shows through instead of a white tile.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width,
      padding: EdgeInsets.all(width * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFF7DF), Color(0xFFF4E3B2)],
        ),
        border: Border.all(
          color: const Color(0xFFC9A227),
          width: width * 0.022,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC9A227).withValues(alpha: 0.28),
            blurRadius: width * 0.18,
            offset: Offset(0, width * 0.05),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/app_mark.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _GoldRule extends StatelessWidget {
  const _GoldRule({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 8,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFC9A227).withValues(alpha: 0.7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 5,
                height: 5,
                color: const Color(0xFFC9A227),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFC9A227).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.fontSize,
  });

  final IconData icon;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.7,
        vertical: fontSize * 0.32,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A227).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC9A227).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize * 1.05, color: const Color(0xFF8A6D10)),
          SizedBox(width: fontSize * 0.34),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF6B5410),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The wax/foil seal with two ribbon tails hanging below it.
class _RibbonSeal extends StatelessWidget {
  const _RibbonSeal({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size * 1.45,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: size * 0.7,
            child: CustomPaint(
              size: Size(size * 1.35, size * 0.8),
              painter: const _RibbonPainter(),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [Color(0xFFFFE9A8), Color(0xFFD8AE32), Color(0xFFFFE9A8)],
              ),
              border: Border.all(
                color: const Color(0xFF9C7A14),
                width: size * 0.035,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9C7A14).withValues(alpha: 0.35),
                  blurRadius: size * 0.16,
                  offset: Offset(0, size * 0.06),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: const Color(0xFF5A3E00),
                    size: size * 0.42,
                  ),
                  Text(
                    'OFFICIAL',
                    style: TextStyle(
                      color: const Color(0xFF5A3E00),
                      fontSize: size * 0.105,
                      fontWeight: FontWeight.w900,
                      letterSpacing: size * 0.006,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two satin ribbons tucked behind the seal.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final left = Path()
      ..moveTo(size.width * 0.30, 0)
      ..lineTo(size.width * 0.42, size.height * 0.92)
      ..lineTo(size.width * 0.50, size.height * 0.72)
      ..lineTo(size.width * 0.58, size.height)
      ..lineTo(size.width * 0.62, 0)
      ..close();
    final right = Path()
      ..moveTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.58, size.height)
      ..lineTo(size.width * 0.66, size.height * 0.78)
      ..lineTo(size.width * 0.76, size.height * 0.95)
      ..lineTo(size.width * 0.80, 0)
      ..close();

    canvas.drawPath(
      left,
      Paint()
        ..color = const Color(0xFFB31B2D)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      right,
      Paint()
        ..color = const Color(0xFF8D1523)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}

class _FooterField extends StatelessWidget {
  const _FooterField({
    required this.value,
    required this.caption,
    required this.color,
    required this.fontSize,
    this.italic = false,
  });

  final String value;
  final String caption;
  final Color color;
  final double fontSize;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: fontSize * 1.02,
            fontWeight: FontWeight.w700,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1,
          color: color.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF9A8B6B),
            fontSize: fontSize * 0.72,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Warm paper texture: a guilloche rosette under the emblem and fine hatch
/// marks around the edge. All strokes are low-alpha gold so the certificate
/// still reads as paper rather than a pattern.
class _PaperPainter extends CustomPainter {
  const _PaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = const Color(0xFFC9A227);

    // Fine diagonal paper grain.
    final grain = Paint()
      ..color = gold.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;
    for (double x = -size.height; x < size.width; x += 9) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        grain,
      );
    }

    // Guilloche rosette behind the emblem.
    final rosette = Paint()
      ..color = gold.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final center = Offset(size.width / 2, size.height * 0.19);
    final radius = size.width * 0.115;
    for (var i = 0; i < 10; i++) {
      final r = radius * (0.45 + i * 0.055);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 10);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.62),
        rosette,
      );
      canvas.restore();
    }

    // Corner flourishes.
    final corner = Paint()
      ..color = gold.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final inset = size.width * 0.028;
    final arm = size.width * 0.045;
    for (final flipX in [false, true]) {
      for (final flipY in [false, true]) {
        canvas.save();
        canvas.translate(
          flipX ? size.width - inset : inset,
          flipY ? size.height - inset : inset,
        );
        canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
        final path = Path()
          ..moveTo(0, arm)
          ..lineTo(0, 0)
          ..lineTo(arm, 0)
          ..moveTo(arm * 0.25, arm * 0.55)
          ..quadraticBezierTo(
            arm * 0.25,
            arm * 0.25,
            arm * 0.55,
            arm * 0.25,
          );
        canvas.drawPath(path, corner);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) => false;
}

/// Captures [boundary]'s current pixels as a PNG.
///
/// Used to turn the on-screen certificate into a downloadable image without
/// pulling in a rendering dependency.
Future<Uint8List?> capturePng(
  GlobalKey boundary, {
  double pixelRatio = 3.0,
}) async {
  final object = boundary.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  final image = await object.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
