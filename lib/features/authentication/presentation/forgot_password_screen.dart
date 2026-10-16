import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_background.dart';
import '../../../shared/widgets/handelha_illustration.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendLink({bool validate = true}) async {
    if (validate && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await ref.read(authNotifierProvider.notifier).sendPasswordResetEmail(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() { _loading = false; _emailSent = true; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(tooltip: 'رجوع', onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      extendBodyBehindAppBar: true,
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 34, 24, 28),
                child: _emailSent
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: HandelhaIllustration(type: HandelhaIllustrationType.sent, height: 180)),
                          const SizedBox(height: 16),
                          Text('راجع بريدك', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('بعتنالك رابط تغيير كلمة المرور.\nلو ما لقيتوش، بصّ في الرسائل غير المرغوب فيها.', style: theme.textTheme.titleMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.normal), textAlign: TextAlign.center),
                          const SizedBox(height: 32),
                          PrimaryButton(text: 'الرجوع لتسجيل الدخول', onPressed: () => context.go('/login')),
                          const SizedBox(height: 24),
                          Center(
                            child: InkWell(
                              onTap: () => _sendLink(validate: false),
                              child: Text(
                                'ابعت الرابط تاني',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primaryStrong,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 32),
                            Text('نسيت كلمة المرور؟', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.start),
                            const SizedBox(height: 12),
                            Text('ولا يهمك! اكتب بريدك الإلكتروني وهنبعتلك كود لتأكيد حسابك وتغيير كلمة المرور.', style: theme.textTheme.titleMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.normal, height: 1.5), textAlign: TextAlign.start),
                            const SizedBox(height: 48),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _sendLink(),
                              decoration: const InputDecoration(hintText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline_rounded)),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'اكتب بريدك الإلكتروني';
                                if (!RegExp(r'^[\w.\-]+@[\w-]+\.\w{2,}$').hasMatch(value.trim())) return 'البريد الإلكتروني غير صحيح';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(text: 'إرسال الكود', isLoading: _loading, onPressed: _sendLink),
                            const SizedBox(height: 32),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => context.go('/login'), 
                                icon: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primaryStrong),
                                label: Text('الرجوع لتسجيل الدخول', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.primaryStrong, fontWeight: FontWeight.w700))
                              ),
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
