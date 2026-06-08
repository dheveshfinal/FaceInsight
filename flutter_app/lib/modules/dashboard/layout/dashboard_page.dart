// ==============================================================
//  FaceInsight – lib/modules/dashboard/layout/dashboard_page.dart
//  Full result dashboard — 3 tabs matching screenshots 4-7:
//
//  TAB 1 Overview  : circular skin-health score + 2x2 condition grid
//                    + scrollable analysis history
//  TAB 2 Analysis  : per-zone progress bars (Forehead, Eyes, Nose…)
//                    + analysis history
//  TAB 3 Recommendations : grouped bullet lists
//                    + analysis history
//  Footer : "New Analysis" floating pill button
// ==============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/fi_app_bar.dart';
import '../../auth/layout/login_modal.dart';
import '../../analysis/service/analysis_service.dart';
import '../types/dashboard_types.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _initialized = false;
  bool _isLoading = true;
  String? _errorMsg;
  AnalysisResult? _result;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      final jobId = args is String ? args : null;
      _fetchData(jobId);
    }
  }

  Future<void> _fetchData(String? jobId) async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      String? targetJobId = jobId;
      List<Map<String, dynamic>> history = [];

      try {
        history = await AnalysisService.instance.getHistory();
      } catch (e) {
        debugPrint('Failed to load history: $e');
      }

      if (targetJobId == null && history.isNotEmpty) {
        targetJobId = history.first['job_id'] as String?;
      }

      if (targetJobId == null) {
        setState(() {
          _result = null;
          _isLoading = false;
        });
        return;
      }

      final resultsMap = await AnalysisService.instance.getResults(jobId: targetJobId);
      setState(() {
        _result = AnalysisResult.fromJson(resultsMap, history);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _isLoading = false;
        _result = null;
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final jobId = args is String ? args : null;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const FiAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.accentCyan),
              ),
            )
          : _errorMsg != null
              ? _buildErrorView(jobId)
              : _result == null
                  ? _buildNoResultView()
                  : Column(
                      children: [
                        // ── Tab bar ───────────────────────────────────────
                        _DashboardTabBar(controller: _tabCtrl),

                        // ── Tab views ─────────────────────────────────────
                        Expanded(
                          child: TabBarView(
                            controller: _tabCtrl,
                            children: [
                              _OverviewTab(result: _result!),
                              _AnalysisTab(result: _result!),
                              _RecommendationsTab(result: _result!),
                            ],
                          ),
                        ),
                      ],
                    ),

      // ── New Analysis FAB ───────────────────────────────────
      bottomNavigationBar: _NewAnalysisBar(
        onTap: () =>
            Navigator.pushReplacementNamed(context, AppRoutes.home),
      ),
    );
  }

  Widget _buildErrorView(String? jobId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Analysis',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _fetchData(jobId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.accentCyan, AppColors.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(Icons.face_retouching_natural, color: Colors.black, size: 48),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Your Skin Health Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Capture a photo to instantly generate your personalised skin health profile — no account required.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.cyanBlueGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'START ANALYSIS',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Optional login note — not a CTA, just info
            GestureDetector(
              onTap: () => showLoginModal(context),
              child: const Text(
                'Log in to save your history across sessions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} // _DashboardPageState

// ══════════════════════════════════════════════════════════════
//  TAB BAR
// ══════════════════════════════════════════════════════════════

class _DashboardTabBar extends StatelessWidget {
  final TabController controller;
  const _DashboardTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    const labels = ['Overview', 'Analysis', 'Recommendations'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.bgPrimary,
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = controller.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: selected
                      ? AppColors.cyanBlueGradient
                      : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: selected
                      ? null
                      : Border.all(color: AppColors.border, width: 1),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selected
                          ? Colors.black
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 1 — OVERVIEW
// ══════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final AnalysisResult result;
  const _OverviewTab({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // ── Circular score ──────────────────────────────────
        const SizedBox(height: 16),
        Center(
          child: _SkinScoreRing(score: result.skinHealthScore),
        ),
        const SizedBox(height: 28),

        // ── Divider ─────────────────────────────────────────
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 20),

        // ── 2x2 condition grid ───────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          children: result.conditions
              .map((c) => _ConditionCell(condition: c))
              .toList(),
        ),

        const SizedBox(height: 20),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 20),

        // ── Facial Structure & Attributes ────────────────────
        const Text(
          'Facial Structure & Attributes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _StructureCard(
              label: 'Facial Symmetry',
              value: result.symmetryScore != null
                  ? '${(result.symmetryScore! * 100).round()}%'
                  : '88%',
              icon: Icons.face,
            ),
            _StructureCard(
              label: 'Golden Ratio',
              value: result.goldenRatioScore != null
                  ? '${(result.goldenRatioScore! * 100).round()}%'
                  : '82%',
              icon: Icons.grid_3x3,
            ),
            _StructureCard(
              label: 'Face Shape',
              value: result.faceShape ?? 'Oval',
              icon: Icons.portrait,
            ),
            _StructureCard(
              label: 'Estimated Age',
              value: result.ageEstimate ?? '26 yrs',
              icon: Icons.calendar_today,
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 24),

        // ── History ─────────────────────────────────────────
        _HistorySection(entries: result.history),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StructureCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StructureCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentCyan, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


// ── Circular skin score ring ───────────────────────────────────

class _SkinScoreRing extends StatefulWidget {
  final int score;
  const _SkinScoreRing({required this.score});

  @override
  State<_SkinScoreRing> createState() => _SkinScoreRingState();
}

class _SkinScoreRingState extends State<_SkinScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: 180,
        height: 180,
        child: CustomPaint(
          painter: _RingPainter(
              progress: _anim.value * widget.score / 100),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(widget.score * _anim.value).round()}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Skin Health Score',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 10;

    // Track
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    // Progress arc
    final rect =
        Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final arcPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.accentCyan, AppColors.accentBlue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Condition cell ─────────────────────────────────────────────

class _ConditionCell extends StatelessWidget {
  final SkinConditionResult condition;
  const _ConditionCell({required this.condition});

  Color _colorFor(ConditionSeverity s) {
    switch (s) {
      case ConditionSeverity.low:      return AppColors.statusLow;
      case ConditionSeverity.moderate: return AppColors.statusModerate;
      case ConditionSeverity.good:     return AppColors.statusGood;
      case ConditionSeverity.excellent:return AppColors.statusExcellent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            condition.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            condition.value,
            style: TextStyle(
              color: _colorFor(condition.severity),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 2 — ANALYSIS (zone bars)
// ══════════════════════════════════════════════════════════════

class _AnalysisTab extends StatelessWidget {
  final AnalysisResult result;
  const _AnalysisTab({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        ...result.zones.map((z) => _ZoneBar(zone: z)),
        const SizedBox(height: 12),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 24),
        _HistorySection(entries: result.history),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ZoneBar extends StatefulWidget {
  final ZoneAnalysis zone;
  const _ZoneBar({required this.zone});

  @override
  State<_ZoneBar> createState() => _ZoneBarState();
}

class _ZoneBarState extends State<_ZoneBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 100), _ctrl.forward);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.zone.zone,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Text(
                  '${(widget.zone.score * _anim.value * 100).round()}%',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.zone.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          // Progress bar
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.zone.score * _anim.value,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(
                    AppColors.accentCyan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 3 — RECOMMENDATIONS
// ══════════════════════════════════════════════════════════════

class _RecommendationsTab extends StatelessWidget {
  final AnalysisResult result;
  const _RecommendationsTab({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        ...result.recommendations.map(
          (g) => _RecommendationGroup(group: g),
        ),
        const SizedBox(height: 12),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 24),
        _HistorySection(entries: result.history),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RecommendationGroup extends StatelessWidget {
  final RecommendationGroup group;
  const _RecommendationGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with left cyan border accent
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.accentCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                group.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Bullet items
          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5, right: 10),
                    child: Icon(Icons.circle,
                        size: 5, color: AppColors.accentCyan),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
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

// ══════════════════════════════════════════════════════════════
//  SHARED — HISTORY SECTION (appears on all 3 tabs)
// ══════════════════════════════════════════════════════════════

class _HistorySection extends StatelessWidget {
  final List<AnalysisHistoryEntry> entries;
  const _HistorySection({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analysis History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...entries.map((e) => _HistoryEntry(entry: e)),
      ],
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  final AnalysisHistoryEntry entry;
  const _HistoryEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.delta.startsWith('+');
    final deltaColor = isPositive
        ? AppColors.statusLow
        : (entry.delta == '-' ? AppColors.textMuted : Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.date,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.score}',
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.delta,
            style: TextStyle(
              color: deltaColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  BOTTOM — NEW ANALYSIS BAR
// ══════════════════════════════════════════════════════════════

class _NewAnalysisBar extends StatelessWidget {
  final VoidCallback onTap;
  const _NewAnalysisBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.fromLTRB(60, 10, 60, 24),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2540),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.face_retouching_natural,
                  color: AppColors.textSecondary, size: 18),
              SizedBox(width: 8),
              Text(
                'New Analysis',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
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