import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/auth_background.dart';
import '../../../shared/widgets/handelha_brand.dart';
import '../../../shared/widgets/handelha_illustration.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/app_user.dart';
import 'auth_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'وافق على الشروط وسياسة الخصوصية عشان نكمل.');
      return;
    }
    setState(() { _loading = true; _errorMessage = null; });
    final result = await ref.read(authNotifierProvider.notifier).createAccount(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result is Success<AppUser>) {
      context.go('/onboarding');
    } else if (result is Failure<AppUser>) {
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
                padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const HandelhaLogo(markSize: 28, fontSize: 18),
                        const Spacer(),
                        IconButton(tooltip: 'رجوع', onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                      ]),
                      const SizedBox(height: 2),
                      const Center(child: HandelhaIllustration(type: HandelhaIllustrationType.calendar, height: 158)),
                      const SizedBox(height: 16),
                      Text('خلّي البداية سهلة', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 28), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text('حسابك يجهّزك لترتيب يومك خطوة خطوة.', style: theme.textTheme.titleMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.normal), textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(13)),
                          child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'الاسم اللي تحبه', prefixIcon: Icon(Icons.person_outline_rounded)),
                        validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسمك' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        decoration: const InputDecoration(hintText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'اكتب بريدك الإلكتروني';
                          if (!RegExp(r'^[\w.\-]+@[\w-]+\.\w{2,}$').hasMatch(value.trim())) return 'البريد الإلكتروني غير صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _handleSignUp(),
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'اكتب كلمة المرور';
                          if (value.length < 8) return 'كلمة المرور لازم تكون ٨ أحرف على الأقل';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _PasswordMeter(password: _passwordCtrl.text),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Checkbox(
                                value: _agreedToTerms,
                                onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                                activeColor: AppColors.primaryStrong,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              ),
                              const SizedBox(width: 8),
                              Text('أوافق على الشروط وسياسة الخصوصية', style: theme.textTheme.titleSmall),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(text: 'إنشاء حساب', isLoading: _loading, onPressed: _handleSignUp),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('عندك حساب؟ ', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                          TextButton(
                            onPressed: () => context.go('/login'), 
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.w800))
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

class _PasswordMeter extends StatelessWidget {
  const _PasswordMeter({required this.password});
  final String password;
  @override
  Widget build(BuildContext context) {
    final strength = password.isEmpty ? 0 : password.length < 8 ? 1 : password.length < 12 ? 2 : 3;
    final color = strength < 2 ? AppColors.accent : strength == 2 ? AppColors.secondary : AppColors.primary;
    return Row(children: [
      Expanded(child: Row(children: List.generate(4, (index) => Expanded(child: Container(margin: EdgeInsetsDirectional.only(end: index == 3 ? 0 : 5), height: 5, decoration: BoxDecoration(color: index < strength ? color : AppColors.border, borderRadius: BorderRadius.circular(8))))))),
    ]);
  }
}
