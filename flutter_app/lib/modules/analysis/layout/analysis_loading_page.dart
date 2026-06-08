// ==============================================================
//  FaceInsight – lib/modules/analysis/layout/analysis_loading_page.dart
//  Scanning / loading screen — exact replica of design mockup:
//    • Dark camera-preview placeholder with cyan corner brackets
//    • Animated face landmark dots inside
//    • "Mapping facial landmarks…" status with pulse icon
//    • Cyan progress bar + "25% Complete" label
//    • Progress driven by REAL backend job polling (not simulated)
// ==============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/fi_app_bar.dart';
import '../service/analysis_service.dart';

// ── Analysis stages with estimated times ────────────────────────
const _stages = [
  (pct: 0.10, label: 'Detecting face…'),
  (pct: 0.25, label: 'Mapping facial landmarks…'),
  (pct: 0.45, label: 'Analysing skin texture…'),
  (pct: 0.65, label: 'Computing symmetry score…'),
  (pct: 0.80, label: 'Running skin condition model…'),
  (pct: 0.95, label: 'Generating recommendations…'),
  (pct: 1.00, label: 'Complete!'),
];

class AnalysisLoadingPage extends StatefulWidget {
  final String? jobId; // Job ID to poll (can be null for testing)

  const AnalysisLoadingPage({super.key, this.jobId});

  @override
  State<AnalysisLoadingPage> createState() => _AnalysisLoadingPageState();
}

class _AnalysisLoadingPageState extends State<AnalysisLoadingPage>
    with TickerProviderStateMixin {
  // Progress
  double _progress   = 0.0;
  String _stage      = 'Initializing…';
  String? _error;

  // Animations
  late final AnimationController _scanCtrl;   // scan line
  late final AnimationController _pulseCtrl;  // dot pulse
  late final AnimationController _bracketCtrl;// corner bracket appear

  late final Animation<double> _bracketAnim;

  // Polling
  Timer? _pollingTimer;
  int _pollingAttempts = 0;
  final int _maxPollingAttempts = 300; // 10 minutes timeout

  @override
  void initState() {
    super.initState();

    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    _bracketCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bracketAnim = CurvedAnimation(
        parent: _bracketCtrl, curve: Curves.easeOut);
    _bracketCtrl.forward();

    // Start polling job status from backend
    _startPollingJobStatus();
  }

  void _startPollingJobStatus() {
    if (widget.jobId == null) {
      // Fallback: simulate progress if no job ID (for testing)
      _simulateFallbackProgress();
      return;
    }

    // Poll backend for real job status
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pollingAttempts++;

      // Timeout after max attempts
      if (_pollingAttempts > _maxPollingAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() => _error = 'Analysis timed out. Please try again.');
        }
        return;
      }

      try {
        final status = await AnalysisService.instance.getJobStatus(
          jobId: widget.jobId!,
        );

        if (!mounted) return;

        setState(() {
          _stage = status.stage ?? 'Processing…';
          _progress = status.progress ?? 0.0;

          if (status.isComplete) {
            _pollingTimer?.cancel();

            if (status.isSuccess) {
              // Navigate to results after a brief delay
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.analysisResult,
                    arguments: widget.jobId,
                  );
                }
              });
            } else {
              _error = status.errorMessage ?? 'Analysis failed';
            }
          }
        });
      } catch (e) {
        // Log but don't crash - keep polling
        debugPrint('Polling error: $e');
      }
    });
  }

  void _simulateFallbackProgress() {
    // Fallback simulation if no job ID provided
    int stageIdx = 0;
    Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (stageIdx >= _stages.length - 1) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
                context, AppRoutes.analysisResult);
          }
        });
        return;
      }
      stageIdx++;
      setState(() {
        _progress = _stages[stageIdx].pct;
        _stage = _stages[stageIdx].label;
      });
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _bracketCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const FiAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // ── Camera preview box ──────────────────────────
            Expanded(
              flex: 58,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AnimatedBuilder(
                  animation: _bracketAnim,
                  builder: (_, child) => Opacity(
                    opacity: _bracketAnim.value,
                    child: child,
                  ),
                  child: _ScanBox(
                    scanCtrl:  _scanCtrl,
                    pulseCtrl: _pulseCtrl,
                  ),
                ),
              ),
            ),

            // ── Status + progress ───────────────────────────
            Expanded(
              flex: 42,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Error message (if any)
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red, width: 1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    else
                      ...[
                        // Status label with pulse icon
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) {
                            final pulse = math.sin(
                                    _pulseCtrl.value * math.pi * 2) *
                                0.4 +
                                0.6;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.monitor_heart_outlined,
                                    color: AppColors.accentCyan
                                        .withOpacity(pulse),
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _stage,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 18),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: _progress),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeInOut,
                            builder: (_, val, __) => LinearProgressIndicator(
                              value: val,
                              minHeight: 6,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.accentCyan),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Percentage label
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _progress),
                          duration: const Duration(milliseconds: 700),
                          builder: (_, val, __) => Text(
                            '${(val * 100).round()}% Complete',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera preview box with corner brackets + scan ────────────

class _ScanBox extends StatelessWidget {
  final AnimationController scanCtrl;
  final AnimationController pulseCtrl;

  const _ScanBox({required this.scanCtrl, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight);
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              // Dark preview bg
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF080D18),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),

              // Corner brackets
              CustomPaint(
                size: Size(side, side),
                painter: _BracketPainter(),
              ),

              // Face dot landmarks inside box
              AnimatedBuilder(
                animation: Listenable.merge([scanCtrl, pulseCtrl]),
                builder: (_, __) => CustomPaint(
                  size: Size(side, side),
                  painter: _InBoxFacePainter(
                    scanProgress: scanCtrl.value,
                    pulse:        pulseCtrl.value,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Corner bracket painter ─────────────────────────────────────

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentCyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r   = 6.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    _drawCorner(canvas, paint, Offset(0, 0),      len, r, 0);
    // Top-right
    _drawCorner(canvas, paint, Offset(w, 0),      len, r, 1);
    // Bottom-left
    _drawCorner(canvas, paint, Offset(0, h),      len, r, 2);
    // Bottom-right
    _drawCorner(canvas, paint, Offset(w, h),      len, r, 3);
  }

  void _drawCorner(Canvas c, Paint p, Offset o, double len, double r, int q) {
    final xs = q == 1 || q == 3 ? -1.0 : 1.0;
    final ys = q == 2 || q == 3 ? -1.0 : 1.0;

    // Horizontal line
    c.drawLine(
      Offset(o.dx + xs * r, o.dy),
      Offset(o.dx + xs * len, o.dy),
      p,
    );
    // Vertical line
    c.drawLine(
      Offset(o.dx, o.dy + ys * r),
      Offset(o.dx, o.dy + ys * len),
      p,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter _) => false;
}

// ── Face dots inside scan box ──────────────────────────────────

class _InBoxFacePainter extends CustomPainter {
  final double scanProgress;
  final double pulse;

  const _InBoxFacePainter({
    required this.scanProgress,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  * 0.50;
    final cy = size.height * 0.44;

    // Horizontal cross-hair lines
    final linePaint = Paint()
      ..color = AppColors.accentTeal.withOpacity(0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), linePaint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), linePaint);

    // Scan line
    final sweepY = size.height * scanProgress;
    final sweepPaint = Paint()
      ..color = AppColors.accentCyan.withOpacity(0.45)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(0, sweepY), Offset(size.width, sweepY), sweepPaint);

    // Landmark dots  (relative to cx, cy)
    final dots = [
      Offset(cx - size.width * 0.10, cy - size.height * 0.08), // left eye
      Offset(cx + size.width * 0.08, cy - size.height * 0.08), // right eye
      Offset(cx,                     cy + size.height * 0.01), // nose
      Offset(cx - size.width * 0.08, cy + size.height * 0.10), // mouth L
      Offset(cx + size.width * 0.06, cy + size.height * 0.10), // mouth R
    ];

    final pulseFactor =
        1.0 + math.sin(pulse * math.pi * 2) * 0.2;

    for (final d in dots) {
      canvas.drawCircle(
        d,
        5.0 * pulseFactor,
        Paint()
          ..color = AppColors.accentBlue.withOpacity(0.9)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        d,
        3.5,
        Paint()..color = AppColors.accentCyan,
      );
    }
  }

  @override
  bool shouldRepaint(_InBoxFacePainter old) =>
      old.scanProgress != scanProgress || old.pulse != pulse;
}