import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/auth_background.dart';
import '../../../shared/widgets/handelha_brand.dart';
import '../../../shared/widgets/handelha_illustration.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/social_icons.dart';
import '../domain/app_user.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isFbLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    final result = await ref.read(authNotifierProvider.notifier).signInWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result is Failure<AppUser>) {
      setState(() => _errorMessage = result.failure.message);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });
    final result = await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (result is Failure<AppUser>) {
      setState(() => _errorMessage = result.failure.message);
    }
  }

  Future<void> _handleFacebook() async {
    setState(() { _isFbLoading = true; _errorMessage = null; });
    final result = await ref.read(authNotifierProvider.notifier).signInWithFacebook();
    if (!mounted) return;
    setState(() => _isFbLoading = false);
    if (result is Failure<AppUser>) {
      setState(() => _errorMessage = result.failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerStart, 
                        child: HandelhaLogo(markSize: 28, fontSize: 18)
                      ),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('أهلاً بعودتك', textAlign: TextAlign.start, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 32, height: 1.15)),
                                const SizedBox(height: 6),
                                Text('نكمّل من آخر خطوة.', style: theme.textTheme.titleMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.normal)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            flex: 2,
                            child: HandelhaIllustration(type: HandelhaIllustrationType.welcome, height: 140),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (_errorMessage != null) ...[
                        _AuthError(message: _errorMessage!),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'اكتب بريدك الإلكتروني';
                          if (!RegExp(r'^[\w.\+-]+@[\w-]+\.\w{2,}$').hasMatch(value.trim())) return 'البريد الإلكتروني غير صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'اكتب كلمة المرور' : null,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? AppColors.darkSecondary : AppColors.secondary,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(text: 'دخول', isLoading: _isLoading, onPressed: _handleLogin),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.border)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('أو', style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted))),
                        Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.border)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _SocialButton(label: 'Facebook', icon: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 22), loading: _isFbLoading, onPressed: _handleFacebook)),
                        const SizedBox(width: 12),
                        Expanded(child: _SocialButton(label: 'Google', icon: const GoogleLogoIcon(size: 20), loading: _isGoogleLoading, onPressed: _handleGoogle)),
                      ]),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('لسه ماعندكش حساب؟ ', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                          TextButton(
                            onPressed: () => context.push('/signup'),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text('إنشاء حساب', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, required this.loading, required this.onPressed});
  final String label;
  final Widget icon;
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      child: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]),
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.danger.withValues(alpha: 0.25))),
        child: Row(children: [const Icon(Icons.error_outline_rounded, color: AppColors.danger), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger)))]),
      );
}
