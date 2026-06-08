// ==============================================================
//  FaceInsight – lib/modules/analysis/layout/camera_capture_page.dart
//
//  Full-screen live camera page.
//  • Web  → uses dart:html / dart:ui_web to embed a <video> element
//            with getUserMedia (front camera), with canvas capture.
//  • Mobile → uses image_picker with ImageSource.camera
//  Returns XFile via Navigator.pop(context, xfile).
// ==============================================================

import 'package:flutter/material.dart';

// Conditional imports: web vs mobile implementation
import 'camera_capture_web.dart'
    if (dart.library.io) 'camera_capture_mobile.dart';

import '../../../core/theme/app_theme.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with TickerProviderStateMixin {
  late final AnimationController _scanCtrl;
  late final AnimationController _pulseCtrl;

  bool _capturing = false;
  String _statusMsg = 'Position your face in the oval';

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onCapture(dynamic xfile) {
    if (mounted) Navigator.of(context).pop(xfile);
  }

  void _onStatusChange(String msg) {
    if (mounted) setState(() => _statusMsg = msg);
  }

  void _onCapturing(bool v) {
    if (mounted) setState(() => _capturing = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Camera feed ───────────────────────────────────
          CameraFeedWidget(
            onCapture: _onCapture,
            onStatusChange: _onStatusChange,
            onCapturing: _onCapturing,
          ),

          // ── 2. Animated face oval overlay ───────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_scanCtrl, _pulseCtrl]),
                builder: (_, __) => CustomPaint(
                  painter: FaceOvalPainter(
                    scanProgress: _scanCtrl.value,
                    pulseValue: _pulseCtrl.value,
                    capturing: _capturing,
                  ),
                ),
              ),
            ),
          ),

          // ── 3. Status text ───────────────────────────────────
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusMsg,
                  key: ValueKey(_statusMsg),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Top bar ───────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _GlassButton(
                      onTap: () => Navigator.of(context).pop(null),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.cyanBlueGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'FaceInsight',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40), // balance close button
                  ],
                ),
              ),
            ),
          ),

          // ── 5. Capture button (bottom) ────────────────────────
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: CaptureButton(
              capturing: _capturing,
              onCapture: _onCapture,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Face oval overlay painter ──────────────────────────────────

class FaceOvalPainter extends CustomPainter {
  final double scanProgress;
  final double pulseValue;
  final bool capturing;

  const FaceOvalPainter({
    required this.scanProgress,
    required this.pulseValue,
    required this.capturing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final rx = size.width * 0.34;
    final ry = rx * 1.35;

    // Darken everything outside the oval
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2));
    bgPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(
      bgPath,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..style = PaintingStyle.fill,
    );

    // Oval border with glow
    final borderColor =
        capturing ? const Color(0xFF00FF88) : const Color(0xFF00D4FF);
    final glowPaint = Paint()
      ..color = borderColor.withOpacity(0.25 + 0.15 * pulseValue)
      ..strokeWidth = 3 + 2 * pulseValue
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy), width: rx * 2 + 4, height: ry * 2 + 4),
        glowPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy), width: rx * 2, height: ry * 2),
        borderPaint);

    // Scan line inside oval
    if (!capturing) {
      final scanY = cy - ry + scanProgress * ry * 2;
      canvas.save();
      final clipPath = Path()
        ..addOval(Rect.fromCenter(
            center: Offset(cx, cy), width: rx * 2, height: ry * 2));
      canvas.clipPath(clipPath);

      final scanPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF00D4FF).withOpacity(0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(cx - rx, scanY - 20, rx * 2, 40));

      canvas.drawRect(
          Rect.fromLTWH(cx - rx, scanY - 20, rx * 2, 40), scanPaint);
      canvas.restore();
    }

    // Corner brackets (decorative)
    _drawCornerBrackets(canvas, cx, cy, rx, ry, borderColor);
  }

  void _drawCornerBrackets(Canvas canvas, double cx, double cy, double rx,
      double ry, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 18.0;
    const pad = 14.0;

    final tl = Offset(cx - rx - pad, cy - ry - pad);
    final tr = Offset(cx + rx + pad, cy - ry - pad);
    final bl = Offset(cx - rx - pad, cy + ry + pad);
    final br = Offset(cx + rx + pad, cy + ry + pad);

    // top-left
    canvas.drawLine(tl, tl + const Offset(len, 0), p);
    canvas.drawLine(tl, tl + const Offset(0, len), p);
    // top-right
    canvas.drawLine(tr, tr + const Offset(-len, 0), p);
    canvas.drawLine(tr, tr + const Offset(0, len), p);
    // bottom-left
    canvas.drawLine(bl, bl + const Offset(len, 0), p);
    canvas.drawLine(bl, bl + const Offset(0, -len), p);
    // bottom-right
    canvas.drawLine(br, br + const Offset(-len, 0), p);
    canvas.drawLine(br, br + const Offset(0, -len), p);
  }

  @override
  bool shouldRepaint(FaceOvalPainter old) =>
      old.scanProgress != scanProgress ||
      old.pulseValue != pulseValue ||
      old.capturing != capturing;
}

// ── Glass button helper ────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _GlassButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Center(child: child),
        ),
      );
}
