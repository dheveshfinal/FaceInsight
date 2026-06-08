// ==============================================================
//  FaceInsight – lib/modules/auth/layout/register_modal.dart
//  "Create Account" modal — exact replica of design mockup:
//    • Semi-transparent dark overlay
//    • "Create Account" title + X close
//    • Email + Password fields
//    • Gradient "Create Account" button
//    • "Already have an account? Login" link
// ==============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../service/auth_service.dart';
import '../types/auth_types.dart';
import 'login_modal.dart'; // reuses AuthField, GradientButton, FieldLabel

// ── Show helper ───────────────────────────────────────────────

Future<void> showRegisterModalReal(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (_) => const RegisterModal(),
  );
}

// ── Modal widget ──────────────────────────────────────────────

class RegisterModal extends StatefulWidget {
  const RegisterModal({super.key});

  @override
  State<RegisterModal> createState() => _RegisterModalState();
}

class _RegisterModalState extends State<RegisterModal>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _obscurePass = true;
  bool _loading     = false;
  String? _errorMsg;

  late final AnimationController _animCtrl;
  late final Animation<double>    _scaleAnim;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _scaleAnim = Tween(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      await AuthService.instance.register(RegisterRequest(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      ));
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } on AuthError catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF141C2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────
                  Row(
                    children: [
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.close,
                            color: AppColors.textSecondary, size: 22),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Email ──────────────────────────────────
                  FieldLabel('Email'),
                  const SizedBox(height: 8),
                  AuthField(
                    controller: _emailCtrl,
                    hint: 'you@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Password ───────────────────────────────
                  FieldLabel('Password'),
                  const SizedBox(height: 8),
                  AuthField(
                    controller: _passwordCtrl,
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    obscure: _obscurePass,
                    suffix: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePass = !_obscurePass),
                      child: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password required';
                      if (v.length < 6) return 'Min 6 characters';
                      return null;
                    },
                  ),

                  // ── Error ──────────────────────────────────
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMsg!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  ],

                  const SizedBox(height: 28),

                  // ── Create Account button ──────────────────
                  GradientButton(
                    label: 'Create Account',
                    loading: _loading,
                    onTap: _submit,
                  ),

                  const SizedBox(height: 20),

                  // ── Login link ─────────────────────────────
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            showLoginModal(context);
                          },
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}