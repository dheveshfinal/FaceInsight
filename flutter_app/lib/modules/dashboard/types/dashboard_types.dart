// ==============================================================
//  FaceInsight – lib/modules/dashboard/types/dashboard_types.dart
//  Data models for analysis result + history
//  Includes fromJson factories to hydrate from real API response
// ==============================================================

class SkinConditionResult {
  final String label;
  final String value;
  final ConditionSeverity severity;

  const SkinConditionResult({
    required this.label,
    required this.value,
    required this.severity,
  });

  factory SkinConditionResult.fromJson(Map<String, dynamic> j) {
    return SkinConditionResult(
      label:    j['label']    as String? ?? 'Unknown',
      value:    j['value']    as String? ?? 'Low',
      severity: _parseSeverity(j['severity'] as String?),
    );
  }

  static ConditionSeverity _parseSeverity(String? s) {
    switch (s) {
      case 'moderate': return ConditionSeverity.moderate;
      case 'high':
      case 'severe':   return ConditionSeverity.moderate;
      case 'good':     return ConditionSeverity.good;
      case 'excellent':return ConditionSeverity.excellent;
      default:         return ConditionSeverity.low;
    }
  }
}

enum ConditionSeverity { low, moderate, good, excellent }

class ZoneAnalysis {
  final String zone;
  final String description;
  final double score;

  const ZoneAnalysis({
    required this.zone,
    required this.description,
    required this.score,
  });

  factory ZoneAnalysis.fromJson(Map<String, dynamic> j) => ZoneAnalysis(
        zone:        j['zone']        as String? ?? 'Zone',
        description: j['description'] as String? ?? '',
        score:       _toDouble(j['score']) ?? 0.5,
      );

  static double? _toDouble(dynamic v) {
    if (v == null)   return null;
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class RecommendationGroup {
  final String title;
  final List<String> items;

  const RecommendationGroup({required this.title, required this.items});

  factory RecommendationGroup.fromJson(Map<String, dynamic> j) =>
      RecommendationGroup(
        title: j['title'] as String? ?? 'Tips',
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}

class AnalysisHistoryEntry {
  final String date;
  final int score;
  final String delta;

  const AnalysisHistoryEntry({
    required this.date,
    required this.score,
    required this.delta,
  });

  factory AnalysisHistoryEntry.fromJson(Map<String, dynamic> j) {
    final rawDate = j['date'] as String? ?? '';
    // Format ISO date to readable string
    String dateStr = rawDate;
    try {
      final dt = DateTime.parse(rawDate);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      dateStr = '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {}

    return AnalysisHistoryEntry(
      date:  dateStr,
      score: (j['score'] as num?)?.toInt() ?? 0,
      delta: j['delta'] as String? ?? '-',
    );
  }
}

class AnalysisResult {
  final String jobId;
  final int skinHealthScore;
  final double? symmetryScore;
  final double? goldenRatioScore;
  final String? ageEstimate;
  final String? gender;
  final String? skinTone;
  final String? skinToneHex;
  final String? faceShape;
  final List<SkinConditionResult> conditions;
  final List<ZoneAnalysis> zones;
  final List<RecommendationGroup> recommendations;
  final List<AnalysisHistoryEntry> history;

  const AnalysisResult({
    required this.jobId,
    required this.skinHealthScore,
    this.symmetryScore,
    this.goldenRatioScore,
    this.ageEstimate,
    this.gender,
    this.skinTone,
    this.skinToneHex,
    this.faceShape,
    required this.conditions,
    required this.zones,
    required this.recommendations,
    required this.history,
  });

  // ── Build from real API response ──────────────────────────
  factory AnalysisResult.fromJson(
    Map<String, dynamic> json,
    List<Map<String, dynamic>> historyJson,
  ) {
    final age = json['age_estimate'];
    String? ageStr;
    if (age != null) {
      ageStr = '${(age as num).round()} yrs';
    }

    return AnalysisResult(
      jobId:            json['job_id'] as String? ?? '',
      skinHealthScore:  (json['skin_health_score'] as num?)?.toInt() ?? 70,
      symmetryScore:    _toDouble(json['symmetry_score']),
      goldenRatioScore: _toDouble(json['golden_ratio_score']),
      ageEstimate:      ageStr,
      gender:           json['gender'] as String?,
      skinTone:         json['skin_tone'] as String?,
      skinToneHex:      json['skin_tone_hex'] as String?,
      faceShape:        json['face_shape'] as String?,
      conditions:       (json['conditions'] as List<dynamic>? ?? [])
          .map((e) => SkinConditionResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      zones:            (json['zones'] as List<dynamic>? ?? [])
          .map((e) => ZoneAnalysis.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations:  (json['recommendations'] as List<dynamic>? ?? [])
          .map((e) => RecommendationGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      history:          historyJson
          .map((e) => AnalysisHistoryEntry.fromJson(e))
          .toList(),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null)   return null;
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static const mock = AnalysisResult(
    jobId: 'mock-job-id',
    skinHealthScore: 84,
    symmetryScore: 0.88,
    goldenRatioScore: 0.82,
    ageEstimate: '26 yrs',
    gender: 'Male',
    skinTone: 'Fair',
    skinToneHex: '#F3D2C1',
    faceShape: 'Oval',
    conditions: [
      SkinConditionResult(
        label: 'Acne',
        value: 'Low',
        severity: ConditionSeverity.low,
      ),
      SkinConditionResult(
        label: 'Wrinkles',
        value: 'None',
        severity: ConditionSeverity.good,
      ),
      SkinConditionResult(
        label: 'Dark Circles',
        value: 'Moderate',
        severity: ConditionSeverity.moderate,
      ),
      SkinConditionResult(
        label: 'Pores',
        value: 'Low',
        severity: ConditionSeverity.low,
      ),
    ],
    zones: [
      ZoneAnalysis(
        zone: 'Forehead',
        description: 'Smooth, healthy texture',
        score: 0.88,
      ),
      ZoneAnalysis(
        zone: 'Eyes',
        description: 'Mild dark circles detected',
        score: 0.74,
      ),
      ZoneAnalysis(
        zone: 'Cheeks',
        description: 'Optimal hydration levels',
        score: 0.90,
      ),
      ZoneAnalysis(
        zone: 'Nose & Chin',
        description: 'Slight sebum accumulation',
        score: 0.79,
      ),
    ],
    recommendations: [
      RecommendationGroup(
        title: 'Morning Routine',
        items: [
          'Cleanse with a gentle foaming cleanser.',
          'Apply Vitamin C serum to brighten skin and boost collagen.',
          'Use a lightweight, oil-free moisturizer.',
          'Apply broad-spectrum SPF 30+ sunscreen.',
        ],
      ),
      RecommendationGroup(
        title: 'Evening Routine',
        items: [
          'Double cleanse to remove sebum and pollutants.',
          'Apply Niacinamide or Retinol treatment to address pores/dark circles.',
          'Use a rich, hydrating night cream containing Ceramides.',
        ],
      ),
    ],
    history: [
      AnalysisHistoryEntry(
        date: 'Jun 8, 2026',
        score: 84,
        delta: '+2% vs last week',
      ),
      AnalysisHistoryEntry(
        date: 'Jun 1, 2026',
        score: 82,
        delta: '+5% vs baseline',
      ),
      AnalysisHistoryEntry(
        date: 'May 25, 2026',
        score: 77,
        delta: '-',
      ),
    ],
  );
}