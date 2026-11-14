import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale/language_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_privacy_policy_sheet.dart';
import '../../../shared/widgets/handelha_segmented_switch.dart';
import '../domain/app_user.dart';
import 'auth_providers.dart';
import 'login_screen.dart';

enum _SignUpTab { login, signup }

/// شاشة إنشاء حساب جديد مع دعم كامل للغتين.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref.read(authNotifierProvider.notifier).createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    switch (result) {
      case Success<AppUser>():
        break;
      case Failure<AppUser>(failure: final f):
        setState(() => _errorMessage = localizeAuthError(ref, f));
    }
  }

  Future<void> _socialAuth(AuthProviderType provider) async {
    if (_isSubmitting) return;
    final selection = await HandelhaSocialAuthSheet.show(
      context,
      provider: provider,
    );
    if (!mounted || selection == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final notifier = ref.read(authNotifierProvider.notifier);
    final res = provider == AuthProviderType.google
        ? await notifier.signInWithGoogle(
            email: selection.email,
            displayName: selection.displayName,
          )
        : await notifier.signInWithFacebook(
            email: selection.email,
            displayName: selection.displayName,
          );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (res is Failure<AppUser>) {
      if (res.failure is CancelledFailure) return;
      setState(() => _errorMessage = localizeAuthError(ref, res.failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final appLang = ref.watch(appLanguageProvider);
    final isEn = appLang.isEnglish;

    return Scaffold(
      body: HandelhaAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        final router = GoRouter.maybeOf(context);
                        if (router != null && router.canPop()) {
                          router.pop();
                        } else {
                          router?.go('/login');
                        }
                      },
                      icon: Icon(
                        isEn
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 28,
                        color: c.primary,
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                ref.read(appLanguageProvider.notifier).setLanguage(
                                      isEn ? AppLanguage.arEg : AppLanguage.en,
                                    );
                              },
                              icon: Icon(
                                Icons.language_rounded,
                                size: 16,
                                color: c.primary,
                              ),
                              label: Text(
                                isEn ? 'عربي' : 'EN',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              appLang.tr('حساب جديد', 'New Account'),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Image.asset(
                  'assets/images/logo.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  appLang.tr('هندلها', 'Handelha'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appLang.tr('خلّينا نتعرف عليك', "Let's get to know you"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appLang.tr(
                    'خطوة بسيطة، ويومك يبدأ يرتّب نفسه.',
                    'One simple step, and your day starts organizing itself.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: c.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HandelhaSegmentedSwitch<_SignUpTab>(
                          selected: _SignUpTab.signup,
                          onChanged: (tab) {
                            if (tab == _SignUpTab.login) {
                              context.go('/login');
                            }
                          },
                          options: [
                            HandelhaSegmentOption(
                              value: _SignUpTab.login,
                              label: appLang.tr('تسجيل الدخول', 'Sign In'),
                            ),
                            HandelhaSegmentOption(
                              value: _SignUpTab.signup,
                              label: appLang.tr('إنشاء حساب', 'Create Account'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _SignUpSocialButton(
                                label: appLang.tr('جوجل', 'Google'),
                                badgeText: 'G',
                                badgeColor: const Color(0xFF4285F4),
                                onTap: () =>
                                    _socialAuth(AuthProviderType.google),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SignUpSocialButton(
                                label: appLang.tr('فيسبوك', 'Facebook'),
                                badgeText: 'f',
                                badgeFilledColor: const Color(0xFF1877F2),
                                onTap: () =>
                                    _socialAuth(AuthProviderType.facebook),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: c.divider)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                appLang.tr('أو بالبريد الإلكتروني', 'Or with email'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: c.divider)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: c.danger.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        AuthLabeledField(
                          label: appLang.tr('اسمك', 'Your Name'),
                          hint: appLang.tr('تحب نناديك بإيه؟', 'What should we call you?'),
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return appLang.tr(
                                'اكتب اسمك عشان نناديك بيه.',
                                'Please enter your name.',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        AuthLabeledField(
                          label: appLang.tr('البريد الإلكتروني', 'Email Address'),
                          hint: 'name@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final email = v?.trim() ?? '';
                            if (email.isEmpty) {
                              return appLang.tr(
                                'البريد الإلكتروني مطلوب.',
                                'Email address is required.',
                              );
                            }
                            if (!RegExp(r'^[\w.\-+]+@[\w\-]+\.\w{2,}$')
                                .hasMatch(email)) {
                              return appLang.tr(
                                'البريد الإلكتروني غير صالح.',
                                'Enter a valid email address.',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        AuthLabeledField(
                          label: appLang.tr('كلمة السر', 'Password'),
                          hint: '••••••••••',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          suffixIcon: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final pass = v ?? '';
                            if (pass.length < 8) {
                              return appLang.tr(
                                'استخدم ٨ أحرف أو أكثر.',
                                'Use 8 or more characters.',
                              );
                            }
                            if (!RegExp(r'[A-Za-z]').hasMatch(pass) ||
                                !RegExp(r'\d').hasMatch(pass)) {
                              return appLang.tr(
                                'لازم تحتوي على حروف وأرقام.',
                                'Must include both letters and numbers.',
                              );
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: c.textOnPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: c.textOnPrimary,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        appLang.tr('إنشاء حساب', 'Create Account'),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: c.textOnPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isEn
                                            ? Icons.arrow_forward_rounded
                                            : Icons.arrow_back_rounded,
                                        size: 18,
                                        color: c.textOnPrimary,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                              appLang.tr(
                                'عندك حساب؟ سجّل دخول',
                                'Already have an account? Sign in',
                              ),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: c.primary,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => HandelhaPrivacyPolicySheet.show(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              appLang.tr(
                                'بالمتابعة، إنت موافق على شروط الاستخدام والخصوصية.',
                                'By continuing, you agree to the Terms of Use & Privacy Policy.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: c.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _SignUpSocialButton extends StatelessWidget {
  final String label;
  final String badgeText;
  final Color? badgeColor;
  final Color? badgeFilledColor;
  final VoidCallback onTap;

  const _SignUpSocialButton({
    required this.label,
    required this.badgeText,
    this.badgeColor,
    this.badgeFilledColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (badgeFilledColor != null)
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeFilledColor,
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                )
              else
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
