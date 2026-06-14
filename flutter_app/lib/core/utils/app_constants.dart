// ==============================================================
//  FaceInsight – lib/core/utils/app_constants.dart
//  Single source of truth for all API endpoints + config
// ==============================================================

class AppConstants {
  AppConstants._();

  // ── Base URLs (from --dart-define in Dockerfile) ───────────
  // API_BASE_URL and WS_BASE_URL are set by flutter build --dart-define
  static const String _apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://faceinsight-y0sc.onrender.com/api/v1',
  );

  static const String _wsBase = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://faceinsight-y0sc.onrender.com/ws',
  );

  // ── Auth endpoints ─────────────────────────────────────────
  static String get loginUrl => '$_apiBase/auth/login';
  static String get registerUrl => '$_apiBase/auth/register';
  static String get logoutUrl => '$_apiBase/auth/logout';
  static String get refreshTokenUrl => '$_apiBase/auth/refresh';

  // ── Upload endpoints ───────────────────────────────────────
  static String get uploadImageUrl => '$_apiBase/upload/image';

  // ── Analysis endpoints ─────────────────────────────────────
  static String get analyzeJobUrl => '$_apiBase/analyze/job';
  static String get jobStatusUrl => '$_apiBase/analyze/job'; // GET /{jobId} for status

  // ── Results endpoints ──────────────────────────────────────
  static String get analysisResultUrl => '$_apiBase/results/analysis';
  static String get analysisHistoryUrl => '$_apiBase/results/history';

  // ── Reports endpoints ──────────────────────────────────────
  static String get reportUrl => '$_apiBase/report';

  // ── WebSocket ──────────────────────────────────────────────
  static String get jobProgressWsUrl => '$_wsBase/job-progress';

  // ── Timeouts ───────────────────────────────────────────────
  static const Duration httpTimeout = Duration(minutes: 2);
  static const Duration pollingInterval = Duration(seconds: 2);
  static const int maxPollingAttempts = 300; // 10 minutes max

  // ── Response limits ───────────────────────────────────────
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
}
