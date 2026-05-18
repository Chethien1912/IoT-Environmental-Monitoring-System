import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppPalette {
  static const Color midnight = Color(0xFF07111F);
  static const Color night = Color(0xFF0B1830);
  static const Color panel = Color(0xFF101D35);
  static const Color panelSoft = Color(0xFF172742);
  static const Color stroke = Color(0x26FFFFFF);
  static const Color cyan = Color(0xFF74F7E8);
  static const Color aqua = Color(0xFF4CC9F0);
  static const Color blue = Color(0xFF3A6FF7);
  static const Color indigo = Color(0xFF6A6FFB);
  static const Color violet = Color(0xFF8E7CFF);
  static const Color coral = Color(0xFFFF8A65);
  static const Color amber = Color(0xFFFFC857);
  static const Color mint = Color(0xFF36E7B4);
  static const Color success = Color(0xFF45F0B6);
  static const Color danger = Color(0xFFFF718F);
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF040A14),
            Color(0xFF0A1630),
            Color(0xFF07111F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -90,
            left: -40,
            child: _GlowOrb(color: AppPalette.aqua, size: 240),
          ),
          const Positioned(
            top: 160,
            right: -60,
            child: _GlowOrb(color: AppPalette.violet, size: 220),
          ),
          const Positioned(
            bottom: -120,
            left: 60,
            child: _GlowOrb(color: AppPalette.cyan, size: 280),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.015),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: size * 0.42,
            spreadRadius: size * 0.02,
          ),
        ],
      ),
    );
  }
}

BoxDecoration glassPanelDecoration({
  List<Color>? colors,
  double radius = 30,
  Color borderColor = AppPalette.stroke,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      colors: colors ?? const [Color(0xCC14233E), Color(0xCC0B1527)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    border: Border.all(color: borderColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.24),
        blurRadius: 34,
        offset: const Offset(0, 18),
      ),
      const BoxShadow(
        color: Color(0x3300D1FF),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
    ],
  );
}

class ShellHero extends StatelessWidget {
  const ShellHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.badges = const <String>[],
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 24),
      decoration: glassPanelDecoration(
        colors: const [Color(0xFF183F6B), Color(0xFF111C37), Color(0xFF18132E)],
        radius: 34,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 26 : 34,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        height: 1.45,
                        fontSize: compact ? 13 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: badges
                  .map(
                    (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.4,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class PillInfo extends StatelessWidget {
  const PillInfo({
    super.key,
    required this.label,
    required this.value,
    this.accent = AppPalette.aqua,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricHeadline extends StatelessWidget {
  const MetricHeadline({
    super.key,
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final narrow = MediaQuery.sizeOf(context).width < 420;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: narrow ? 11 : (compact ? 12 : 13),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: narrow ? 16 : (compact ? 20 : 24),
            height: 1.15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class IntensityRing extends StatelessWidget {
  const IntensityRing({
    super.key,
    required this.progress,
    required this.label,
    required this.valueLabel,
    required this.color,
    this.size = 178,
  });

  final double progress;
  final String label;
  final String valueLabel;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IntensityRingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntensityRingPainter extends CustomPainter {
  _IntensityRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.09);
    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.1), color, Colors.white],
        stops: const [0.0, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      accentPaint,
    );

    final knobAngle = -math.pi / 2 + (math.pi * 2 * progress);
    final knobCenter = Offset(
      center.dx + radius * math.cos(knobAngle),
      center.dy + radius * math.sin(knobAngle),
    );
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(knobCenter, stroke * 0.7, glowPaint);
    canvas.drawCircle(knobCenter, stroke * 0.42, Paint()..color = Colors.white);
    canvas.drawCircle(knobCenter, stroke * 0.26, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _IntensityRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class ScoreRingPainter extends CustomPainter {
  ScoreRingPainter({required this.score});

  final int score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.10;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF17324E);
    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppPalette.cyan, AppPalette.blue, AppPalette.violet, AppPalette.cyan],
      ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (score / 100),
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScoreRingPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}

class HourlyPoint {
  const HourlyPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.points,
    required this.color,
  });

  final List<HourlyPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = const EdgeInsets.fromLTRB(26, 24, 18, 28);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.left - padding.right,
      size.height - padding.top - padding.bottom,
    );

    final panelPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D223C), Color(0xFF0A172A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chartRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(24)),
      panelPaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      final y = chartRect.top + (chartRect.height / 5) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    if (points.isEmpty) {
      return;
    }

    final maxValue = points.fold<double>(0, (maxValue, point) {
      return math.max(maxValue, point.value);
    });
    final safeMax = maxValue == 0 ? 1.0 : maxValue;
    final stepX = points.length == 1 ? 0.0 : chartRect.width / (points.length - 1);

    final linePath = Path();
    final fillPath = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = chartRect.left + stepX * i;
      final y = chartRect.bottom - (point.value / safeMax) * chartRect.height;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, chartRect.bottom);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(chartRect.right, chartRect.bottom)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.34),
          color.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chartRect);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = Colors.white;
    final accentPaint = Paint()..color = color;
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = chartRect.left + stepX * i;
      final y = chartRect.bottom - (point.value / safeMax) * chartRect.height;
      canvas.drawCircle(Offset(x, y), 6, dotPaint);
      canvas.drawCircle(Offset(x, y), 3.5, accentPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: point.label.substring(0, 2),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartRect.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
