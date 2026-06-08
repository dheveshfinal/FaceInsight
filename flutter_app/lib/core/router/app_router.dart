// ==============================================================
//  FaceInsight – lib/core/router/app_router.dart
//  Named route definitions — single source of truth for navigation
// ==============================================================

import 'package:flutter/material.dart';

import '../../modules/analysis/layout/home_page.dart';
import '../../modules/analysis/layout/analysis_loading_page.dart';
import '../../modules/analysis/layout/camera_capture_page.dart';
import '../../modules/auth/layout/login_modal.dart';
import '../../modules/auth/layout/register_modal.dart';
import '../../modules/dashboard/layout/dashboard_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String home            = '/';
  static const String login           = '/login';
  static const String register        = '/register';
  static const String camera          = '/camera';
  static const String analysisLoading = '/analysis/loading';
  static const String analysisResult  = '/analysis/result';
  static const String dashboard       = '/dashboard';

  // Navigate to analysis loading with job ID
  static String analysisLoadingWithJob(String jobId) =>
      '/analysis/loading?jobId=$jobId';
}

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return _fade(const HomePage(), settings);

      case AppRoutes.camera:
        return _fade(const CameraCapturePage(), settings);

      case AppRoutes.login:
        // Login is a modal — push it over the home page
        return _fade(const _ModalHost(modal: 'login'), settings);

      case AppRoutes.register:
        return _fade(const _ModalHost(modal: 'register'), settings);

      case AppRoutes.analysisLoading:
        final jobId = settings.arguments as String?;
        return _fade(AnalysisLoadingPage(jobId: jobId), settings);

      case AppRoutes.analysisResult:
      case AppRoutes.dashboard:
        return _fade(const DashboardPage(), settings);

      default:
        return _fade(const HomePage(), settings);
    }
  }

  static PageRoute _fade(Widget page, RouteSettings settings) => PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

/// Hosts the home page and immediately shows the requested modal on top.
class _ModalHost extends StatefulWidget {
  final String modal;
  const _ModalHost({required this.modal});

  @override
  State<_ModalHost> createState() => _ModalHostState();
}

class _ModalHostState extends State<_ModalHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.modal == 'login') {
        showLoginModal(context);
      } else {
        showRegisterModalReal(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const HomePage();
}