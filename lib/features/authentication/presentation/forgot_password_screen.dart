import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale/language_controller.dart';
import '../../../app/theme/app_theme_extension.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/handelha_ambient_background.dart';
import '../../../shared/widgets/handelha_header.dart';
import 'auth_providers.dart';
import 'login_screen.dart';

/// شاشة استعادة كلمة المرور بتصميم هادئ ومتسق مع المرجع باللغتين.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _statusMessage = null;
      _isError = false;
    });

    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text;
    final notifier = ref.read(authNotifierProvider.notifier);

    final result = newPassword.isNotEmpty
        ? await notifier.resetLocalPassword(
            email: email,
            newPassword: newPassword,
          )
        : await notifier.sendPasswordResetEmail(email);

    if (!mounted) return;
    final appLang = ref.read(appLanguageProvider);
    setState(() {
      _submitting = false;
      if (result is Success<void>) {
        _isError = false;
        _newPasswordController.clear();
        _statusMessage = appLang.tr(
          'تم تحديث كلمة السر بنجاح! تقدر تسجّل دخولك دلوقتي بكلمة السر الجديدة.',
          'Password updated! You can now sign in with your new password.',
        );
      } else if (result is Failure<void>) {
        _isError = true;
        _statusMessage = localizeAuthError(ref, result.failure);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final appLang = ref.watch(appLanguageProvider);

    return Scaffold(
      body: HandelhaAmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandelhaHeader(
                  title: appLang.tr('نسيت كلمة السر؟', 'Forgot Password?'),
                  subtitle: appLang.tr(
                    'ولا يهمّك، نراجع حسابك خطوة خطوة',
                    "No worries, let's check your account step by step",
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                  onBack: () {
                    final router = GoRouter.maybeOf(context);
                    if (router != null && router.canPop()) {
                      router.pop();
                    } else {
                      router?.go('/login');
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          appLang.tr(
                            'أدخل بريدك الإلكتروني المسجّل على الجهاز وكلمة السر الجديدة لتحديثها فورًا.',
                            'Enter the email registered on this device and a new password to update it immediately.',
                          ),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: c.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                          label: appLang.tr(
                            'كلمة السر الجديدة',
                            'New Password',
                          ),
                          hint: '••••••••••',
                          controller: _newPasswordController,
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
                            if (pass.isEmpty) {
                              return appLang.tr(
                                'اكتب كلمة السر الجديدة.',
                                'Please enter a new password.',
                              );
                            }
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
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _isError ? c.accentSoft : c.primarySoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _statusMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _isError ? c.danger : c.primary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: c.textOnPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _submitting
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: c.textOnPrimary,
                                    ),
                                  )
                                : Text(
                                    appLang.tr(
                                      'تحديث كلمة السر',
                                      'Update Password',
                                    ),
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.textOnPrimary,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: () => context.go('/login'),
                            style: FilledButton.styleFrom(
                              backgroundColor: c.primarySoft,
                              foregroundColor: c.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              appLang.tr(
                                'الرجوع لتسجيل الدخول',
                                'Back to Sign In',
                              ),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: c.primary,
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
