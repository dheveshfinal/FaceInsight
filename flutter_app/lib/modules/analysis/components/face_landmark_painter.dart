// ==============================================================
//  FaceInsight – lib/modules/analysis/components/face_landmark_painter.dart
//  Animated face-landmark illustration matching the design mockup:
//    • Oval face outline (teal stroke)
//    • Horizontal brow line with two endpoint dots
//    • 8 landmark dots (eyes, nose, mouth region)
//    • Subtle scan-line sweep animation
//    • Floating particle dots in background
// ==============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ── Painter ───────────────────────────────────────────────────

class FaceLandmarkPainter extends CustomPainter {
  final double scanProgress;   // 0.0 → 1.0  (scan line sweep)
  final double pulseValue;     // 0.0 → 1.0  (dot pulse)
  final double appearValue;    // 0.0 → 1.0  (initial appear)

  const FaceLandmarkPainter({
    required this.scanProgress,
    required this.pulseValue,
    required this.appearValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Oval face outline ──────────────────────────────────────
    final ovalW = size.width * 0.52;
    final ovalH = size.height * 0.72;
    final ovalRect = Rect.fromCenter(
      center: Offset(cx, cy - size.height * 0.03),
      width: ovalW,
      height: ovalH,
    );

    final ovalPaint = Paint()
      ..color = AppColors.accentTeal.withOpacity(0.75 * appearValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(ovalRect, ovalPaint);

    // ── Horizontal scan line (chin level) ─────────────────────
    final lineY = cy + ovalH * 0.10;
    final lineLeft  = cx - ovalW * 0.46;
    final lineRight = cx + ovalW * 0.46;

    final linePaint = Paint()
      ..color = AppColors.accentTeal.withOpacity(0.55 * appearValue)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(lineLeft, lineY), Offset(lineRight, lineY), linePaint);

    // ── Landmark dots ─────────────────────────────────────────
    // Positions are relative to oval centre
    final landmarks = <_Dot>[
      // Brow / top line endpoints
      _Dot(dx: -ovalW * 0.28, dy: -ovalH * 0.20, r: 4.8), // left brow
      _Dot(dx:  ovalW * 0.22, dy: -ovalH * 0.20, r: 4.8), // right brow

      // Eye inner corners
      _Dot(dx: -ovalW * 0.19, dy: -ovalH * 0.08, r: 4.0),
      _Dot(dx:  ovalW * 0.13, dy: -ovalH * 0.08, r: 4.0),

      // Nose tip
      _Dot(dx:  ovalW * 0.00, dy:  ovalH * 0.04, r: 4.2),

      // Mouth corners
      _Dot(dx: -ovalW * 0.14, dy:  ovalH * 0.15, r: 3.8),
      _Dot(dx:  ovalW * 0.06, dy:  ovalH * 0.18, r: 3.5),
      _Dot(dx:  ovalW * 0.14, dy:  ovalH * 0.15, r: 3.8),
    ];

    final dotCx = cx;
    final dotCy = cy - size.height * 0.03;

    for (final dot in landmarks) {
      final pulse = 1.0 + math.sin(pulseValue * math.pi * 2 + dot.dx) * 0.18;
      final dotPaint = Paint()
        ..color = AppColors.accentBlue.withOpacity(0.9 * appearValue)
        ..style = PaintingStyle.fill;

      // Glow halo
      final glowPaint = Paint()
        ..color = AppColors.accentCyan.withOpacity(0.18 * appearValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(
          Offset(dotCx + dot.dx, dotCy + dot.dy), dot.r * pulse * 1.6,
          glowPaint);
      canvas.drawCircle(
          Offset(dotCx + dot.dx, dotCy + dot.dy), dot.r * pulse, dotPaint);
    }

    // ── Brow line connecting left + right brow dots ────────────
    final browPaint = Paint()
      ..color = AppColors.accentTeal.withOpacity(0.6 * appearValue)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(dotCx - ovalW * 0.28, dotCy - ovalH * 0.20),
      Offset(dotCx + ovalW * 0.22, dotCy - ovalH * 0.20),
      browPaint,
    );

    // ── Scan line sweep (animated horizontal line) ─────────────
    final sweepY = ovalRect.top + ovalRect.height * scanProgress;
    if (sweepY > ovalRect.top && sweepY < ovalRect.bottom) {
      final sweepPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accentCyan.withOpacity(0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(
            ovalRect.left, sweepY - 1, ovalRect.width, 2));
      canvas.drawLine(
        Offset(ovalRect.left, sweepY),
        Offset(ovalRect.right, sweepY),
        sweepPaint..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(FaceLandmarkPainter old) =>
      old.scanProgress != scanProgress ||
      old.pulseValue != pulseValue ||
      old.appearValue != appearValue;
}

class _Dot {
  final double dx, dy, r;
  const _Dot({required this.dx, required this.dy, required this.r});
}

// ── Particle painter (background sparkles) ─────────────────────

class ParticlePainter extends CustomPainter {
  final double t;
  final List<Particle> particles;

  const ParticlePainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final alpha = (math.sin(t * p.speed + p.phase) * 0.5 + 0.5) * 0.35;
      paint.color = AppColors.accentCyan.withOpacity(alpha);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => old.t != t;
}

class Particle {
  final double x, y, size, speed, phase;
  const Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

List<Particle> generateParticles(int count, math.Random rng) =>
    List.generate(count, (_) => Particle(
      x:     rng.nextDouble(),
      y:     rng.nextDouble(),
      size:  rng.nextDouble() * 1.8 + 0.5,
      speed: rng.nextDouble() * 1.5 + 0.5,
      phase: rng.nextDouble() * math.pi * 2,
    ));