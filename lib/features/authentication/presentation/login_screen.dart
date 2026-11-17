import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale/language_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_privacy_policy_sheet.dart';
import '../../../shared/widgets/handelha_segmented_switch.dart';
import '../data/social_auth_service.dart';
import '../domain/app_user.dart';
import 'auth_providers.dart';

enum _AuthTab { login, signup }

/// Maps an authentication failure to a user-facing message in the active language.
String localizeAuthError(WidgetRef ref, AppFailure failure) {
  final isEn = ref.read(appLanguageProvider).isEnglish;
  if (!isEn) return failure.message;
  return switch (failure) {
    SocialSignInFailure() =>
      'Sign-in could not be completed. Check your connection and try again.',
    InvalidCredentialsFailure() => 'Invalid email or password.',
    UserNotFoundFailure() =>
      'No account found on this device. Create a new account or continue with Google or Facebook.',
    EmailAlreadyInUseFailure() =>
      'An account already exists on this device. Sign in instead.',
    WeakPasswordFailure() =>
      'Password must be at least 8 characters with letters and numbers.',
    ValidationFailure() => 'Please check the entered details.',
    _ => 'Something went wrong. Please try again.',
  };
}

/// شاشة تسجيل الدخول مع دعم كامل للغتين.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
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
                // Top nav strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        final router = GoRouter.maybeOf(context);
                        if (router != null && router.canPop()) {
                          router.pop();
                        } else {
                          router?.go('/onboarding');
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
                              appLang.tr('تسجيل الدخول', 'Sign In'),
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
                  appLang.tr('وحشتنا! نكمّل منين؟', 'Welcome back! Ready to continue?'),
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
                    'ادخل لحسابك، وخطوتك الجاية مستنياك.',
                    'Sign in to your account — your next step is waiting.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Main auth card
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
                        HandelhaSegmentedSwitch<_AuthTab>(
                          selected: _AuthTab.login,
                          onChanged: (tab) {
                            if (tab == _AuthTab.signup) {
                              context.go('/signup');
                            }
                          },
                          options: [
                            HandelhaSegmentOption(
                              value: _AuthTab.login,
                              label: appLang.tr('تسجيل الدخول', 'Sign In'),
                            ),
                            HandelhaSegmentOption(
                              value: _AuthTab.signup,
                              label: appLang.tr('إنشاء حساب', 'Create Account'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Social buttons row
                        Row(
                          children: [
                            Expanded(
                              child: _SocialPillButton(
                                label: appLang.tr('جوجل', 'Google'),
                                badge: _GoogleMark(),
                                onTap: () =>
                                    _socialAuth(AuthProviderType.google),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SocialPillButton(
                                label: appLang.tr('فيسبوك', 'Facebook'),
                                badge: _FacebookMark(),
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
                            Flexible(
                              flex: 3,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
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
                            if (email.length > 120 ||
                                !RegExp(r'^[\w.\-+]+@[\w\-]+\.\w{2,}$')
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
                          onFieldSubmitted: (_) => _submitEmail(),
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
                            if (v == null || v.isEmpty) {
                              return appLang.tr(
                                'كلمة السر مطلوبة.',
                                'Password is required.',
                              );
                            }
                            if (v.length > 128) {
                              return appLang.tr(
                                'كلمة السر طويلة جدًا.',
                                'Password is too long.',
                              );
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            child: Text(
                              appLang.tr('نسيت كلمة السر؟', 'Forgot password?'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitEmail,
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
                                      Flexible(
                                        child: Text(
                                          appLang.tr('تسجيل الدخول', 'Sign In'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: c.textOnPrimary,
                                          ),
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
                            onPressed: () => context.go('/signup'),
                            child: Text(
                              appLang.tr(
                                'أول مرة هنا؟ اعمل حساب',
                                'First time here? Create an account',
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

/// حقل إدخال موحّد ومتناسق الأبعاد مع محاذاة مثالية للأيقونة والنص في اللغتين.
class AuthLabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const AuthLabeledField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.textDirection,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? c.surfaceSoft : const Color(0xFFFAFBF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textDirection: textDirection,
                  textAlign: TextAlign.start,
                  textInputAction: textInputAction,
                  obscureText: obscureText,
                  validator: validator,
                  onFieldSubmitted: onFieldSubmitted,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 14.5,
                      color: c.textSecondary.withValues(alpha: 0.7),
                    ),
                    isDense: true,
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
              ),
              if (suffixIcon != null) ...[
                const SizedBox(width: 8),
                suffixIcon!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialPillButton extends StatelessWidget {
  final String label;
  final Widget badge;
  final VoidCallback onTap;

  const _SocialPillButton({
    required this.label,
    required this.badge,
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
              badge,
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

class _GoogleMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

class _FacebookMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1877F2),
      ),
      child: const Text(
        'f',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.05,
        ),
      ),
    );
  }
}

/// Result returned when the user confirms social sign-in in [HandelhaSocialAuthSheet].
class SocialAccountSelection {
  const SocialAccountSelection({this.email, this.displayName});

  final String? email;
  final String? displayName;
}

/// Interactive bottom sheet for Google & Facebook sign-in.
class HandelhaSocialAuthSheet extends ConsumerStatefulWidget {
  const HandelhaSocialAuthSheet({super.key, required this.provider});

  final AuthProviderType provider;

  static Future<SocialAccountSelection?> show(
    BuildContext context, {
    required AuthProviderType provider,
  }) {
    return showModalBottomSheet<SocialAccountSelection>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HandelhaSocialAuthSheet(provider: provider),
    );
  }

  @override
  ConsumerState<HandelhaSocialAuthSheet> createState() =>
      _HandelhaSocialAuthSheetState();
}

class _HandelhaSocialAuthSheetState
    extends ConsumerState<HandelhaSocialAuthSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  SocialProfile? _savedProfile;
  bool _pickingDeviceAccount = false;
  String? _validationError;

  bool get _isGoogle => widget.provider == AuthProviderType.google;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await SocialAuthService.loadSavedProfile(widget.provider);
    if (!mounted || saved == null) return;
    setState(() {
      _savedProfile = saved;
      _nameController.text = saved.displayName ?? '';
      _emailController.text = saved.email ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDeviceGoogleAccount() async {
    if (_pickingDeviceAccount) return;
    setState(() {
      _pickingDeviceAccount = true;
      _validationError = null;
    });
    final email = await SocialAuthService.pickDeviceGoogleEmail();
    if (!mounted) return;
    setState(() => _pickingDeviceAccount = false);
    if (email != null && email.isNotEmpty) {
      Navigator.of(context).pop(
        SocialAccountSelection(
          email: email,
          displayName: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
        ),
      );
    }
  }

  void _confirm() {
    final rawEmail = _emailController.text.trim();
    final rawName = _nameController.text.trim();
    if (rawEmail.isNotEmpty &&
        !RegExp(r'^[\w.\-+]+@[\w\-]+\.\w{2,}$').hasMatch(rawEmail)) {
      final appLang = ref.read(appLanguageProvider);
      setState(() {
        _validationError = appLang.tr(
          'أدخل بريدًا إلكترونيًا صالحًا أو اتركه فارغًا للمتابعة السريعة.',
          'Enter a valid email address or leave it blank for quick sign-in.',
        );
      });
      return;
    }
    Navigator.of(context).pop(
      SocialAccountSelection(
        email: rawEmail.isEmpty ? null : rawEmail,
        displayName: rawName.isEmpty ? null : rawName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final appLang = ref.watch(appLanguageProvider);
    final isEn = appLang.isEnglish;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final providerNameAr = _isGoogle ? 'جوجل' : 'فيسبوك';
    final providerNameEn = _isGoogle ? 'Google' : 'Facebook';
    final brandColor =
        _isGoogle ? const Color(0xFF4285F4) : const Color(0xFF1877F2);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _isGoogle ? _GoogleMark() : _FacebookMark(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn
                                ? 'Continue with $providerNameEn'
                                : 'المتابعة باستخدام $providerNameAr',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEn
                                ? 'Sign in to sync your profile on this device'
                                : 'سجّل دخولك بسرعة وابدأ تنظيم يومك',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_savedProfile != null) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(
                      SocialAccountSelection(
                        email: _savedProfile!.email,
                        displayName: _savedProfile!.displayName,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: c.primary,
                            child: Text(
                              (_savedProfile!.displayName ?? 'U')
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: TextStyle(
                                color: c.textOnPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _savedProfile!.displayName ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                                if (_savedProfile!.email != null)
                                  Text(
                                    _savedProfile!.email!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            isEn
                                ? Icons.arrow_forward_ios_rounded
                                : Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: c.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isGoogle) ...[
                  OutlinedButton.icon(
                    onPressed:
                        _pickingDeviceAccount ? null : _pickDeviceGoogleAccount,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _pickingDeviceAccount
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.account_circle_outlined, size: 20),
                    label: Text(
                      appLang.tr(
                        'اختيار حساب جوجل مسجّل على الهاتف',
                        'Choose Google Account from Device',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AuthLabeledField(
                  label: appLang.tr('الاسم', 'Name'),
                  hint: appLang.tr('اسمك في التطبيق', 'Your display name'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                AuthLabeledField(
                  label: appLang.tr(
                    'البريد الإلكتروني لحساب $providerNameAr',
                    '$providerNameEn Email',
                  ),
                  hint: _isGoogle ? 'name@gmail.com' : 'name@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _confirm(),
                ),
                if (_validationError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _validationError!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isEn
                          ? 'Continue with $providerNameEn'
                          : 'المتابعة باستخدام $providerNameAr',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
