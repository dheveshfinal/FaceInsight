// ==============================================================
//  FaceInsight – lib/modules/analysis/layout/home_page.dart
//  Landing screen:
//   • Tap "START ANALYSIS" → live camera opens (front cam)
//   • User captures face → uploaded → AnalysisLoadingPage
//   • Registration is optional (guest session auto-created)
// ==============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/fi_app_bar.dart';
import '../components/face_landmark_painter.dart';
import '../service/analysis_service.dart';
import './camera_capture_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────
  late final AnimationController _appearCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _btnCtrl;

  late final Animation<double> _appearAnim;
  late final Animation<double> _btnScale;

  // Particles generated once
  final _rng = math.Random(42);
  late final List<Particle> _particles;

  // Upload state
  bool   _uploading = false;
  String _uploadMsg = '';

  @override
  void initState() {
    super.initState();

    _particles = generateParticles(28, _rng);

    _appearCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _appearAnim = CurvedAnimation(parent: _appearCtrl, curve: Curves.easeOut);
    _appearCtrl.forward();

    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat();

    _btnCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        lowerBound: 0.95,
        upperBound: 1.0,
        value: 1.0);
    _btnScale = _btnCtrl;
  }

  @override
  void dispose() {
    _appearCtrl.dispose();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  // ── Main CTA handler ───────────────────────────────────────
  Future<void> _onStartAnalysis() async {
    // 1. Open live camera page — returns XFile on capture or null on cancel
    final xfile = await Navigator.of(context).push<dynamic>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CameraCapturePage(),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(position: slide, child: child);
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );

    if (xfile == null || !mounted) return;

    // 3. Upload captured frame to backend → get real job_id
    setState(() {
      _uploading = true;
      _uploadMsg = 'Uploading image…';
    });

    try {
      final job = await AnalysisService.instance.uploadXFile(xfile);

      if (!mounted) return;

      // 4. Navigate to loading page with real job ID
      Navigator.pushNamed(
        context,
        AppRoutes.analysisLoading,
        arguments: job.jobId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const FiAppBar(),
      body: Stack(
        children: [
          // ── 1. Background particle field ──────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: ParticlePainter(
                  t: _particleCtrl.value * math.pi * 2,
                  particles: _particles,
                ),
              ),
            ),
          ),

          // ── 2. Upload overlay ──────────────────────────────
          if (_uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.65),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.accentCyan),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _uploadMsg,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 3. Main content ───────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Face illustration (top ~60%) ───────────
                Expanded(
                  flex: 62,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_appearAnim, _scanCtrl, _pulseCtrl]),
                      builder: (_, __) {
                        final illustW = math.min(size.width * 0.72, 320.0);
                        final illustH = illustW * 1.15;
                        return SizedBox(
                          width: illustW,
                          height: illustH,
                          child: CustomPaint(
                            painter: FaceLandmarkPainter(
                              scanProgress: _scanCtrl.value,
                              pulseValue:   _pulseCtrl.value,
                              appearValue:  _appearAnim.value,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Bottom text + button ─────────────────────
                Expanded(
                  flex: 38,
                  child: AnimatedBuilder(
                    animation: _appearAnim,
                    builder: (_, child) => Opacity(
                      opacity: _appearAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - _appearAnim.value)),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          // ── Headline ─────────────────────
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.cyanBlueGradient.createShader(bounds),
                            blendMode: BlendMode.srcIn,
                            child: const Text(
                              'AI Facial Analysis',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.15,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Subtitle ──────────────────────
                          const Text(
                            'Point your front camera at your face — our AI\nanalyses your skin and gives real personalised results.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── CTA Button ────────────────────
                          _StartAnalysisButton(
                            scaleAnimation: _btnScale,
                            controller:    _btnCtrl,
                            uploading:     _uploading,
                            onTap:         _onStartAnalysis,
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Start Analysis CTA ─────────────────────────────────────────

class _StartAnalysisButton extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final AnimationController controller;
  final bool uploading;
  final VoidCallback onTap;

  const _StartAnalysisButton({
    required this.scaleAnimation,
    required this.controller,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: uploading ? null : (_) => controller.reverse(),
      onTapUp:   uploading ? null : (_) { controller.forward(); onTap(); },
      onTapCancel: uploading ? null : () => controller.forward(),
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: uploading
                ? const LinearGradient(
                    colors: [Color(0xFF336677), Color(0xFF224488)])
                : const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF0077FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: uploading
                ? []
                : [
                    BoxShadow(
                      color: AppColors.accentCyan.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: uploading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera_alt_outlined,
                        color: Colors.black, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'START ANALYSIS',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.black, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}