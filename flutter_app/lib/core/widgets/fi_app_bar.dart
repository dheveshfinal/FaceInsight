// ==============================================================
//  FaceInsight – lib/core/widgets/fi_app_bar.dart
//  Shared top nav bar: logo + Login / Register buttons
// ==============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../router/app_router.dart';

class FiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FiAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── Logo ────────────────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [AppColors.accentCyan, AppColors.accentBlue],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.face_retouching_natural,
                color: Colors.black, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'FaceInsight',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),

          const Spacer(),

          // ── Login ────────────────────────────────────────────
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.login),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Login',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),

          // ── Register ─────────────────────────────────────────
          GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.register),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textSecondary, width: 1.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Register',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}