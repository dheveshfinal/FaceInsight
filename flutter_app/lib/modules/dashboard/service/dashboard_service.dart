// ==============================================================
//  FaceInsight – lib/modules/dashboard/service/dashboard_service.dart
//  Fetches analysis result + history from FastAPI backend
//  All URLs from AppConstants — never hardcoded
// ==============================================================

import 'package:http/http.dart' as http;

import '../../../core/utils/app_constants.dart';
import '../types/dashboard_types.dart';

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  // ── Fetch result for a specific job ───────────────────────
  Future<AnalysisResult> fetchResult({
    required String jobId,
    required String accessToken,
  }) async {
    final res = await http.get(
      Uri.parse('${AppConstants.analysisResultUrl}/$jobId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch result: ${res.statusCode}');
    }

    // TODO: parse real response — returning mock for now
    return AnalysisResult.mock;
  }

  // ── Fetch analysis history ─────────────────────────────────
  Future<List<AnalysisHistoryEntry>> fetchHistory({
    required String accessToken,
  }) async {
    final res = await http.get(
      Uri.parse(AppConstants.analysisHistoryUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch history: ${res.statusCode}');
    }

    // TODO: parse real response — returning mock for now
    return AnalysisResult.mock.history;
  }
}