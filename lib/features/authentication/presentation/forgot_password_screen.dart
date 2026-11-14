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
  bool _submitting = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
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

    final result = await ref
        .read(authNotifierProvider.notifier)
        .sendPasswordResetEmail(_emailController.text.trim());

    if (!mounted) return;
    final appLang = ref.read(appLanguageProvider);
    setState(() {
      _submitting = false;
      if (result is Success<void>) {
        _isError = false;
        _statusMessage = appLang.tr(
          'تم إرسال تعليمات الاستعادة إلى بريدك الإلكتروني.',
          'Recovery instructions have been sent to your email.',
        );
      } else if (result is Failure<void>) {
        _isError = true;
        _statusMessage = appLang.isEnglish
            ? 'Your account and tasks are stored only on your device, so we can\'t send a recovery link by email. You can continue with Google or Facebook instead.'
            : result.failure.message;
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
                            'أدخل بريدك الإلكتروني المسجّل على الجهاز.',
                            'Enter the email registered on this device.',
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
                                      'إرسال طلب الاستعادة',
                                      'Send Recovery Request',
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
