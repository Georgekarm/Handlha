import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/result/result.dart';
import '../../../shared/widgets/handelha_brand.dart';
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
  bool _agreedToTerms = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'من فضلك وافق على شروط الاستخدام للمتابعة');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(authNotifierProvider.notifier).createAccount(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result is Failure<AppUser>) {
      setState(() => _errorMessage = result.failure.message);
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Logo
                    Center(
                      child: HandelhaLogo(
                        markSize: 48,
                        fontSize: 26,
                        dark: isDark,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card Container
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title & Subtitle
                          Text(
                            'إنشاء حساب',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '.نبدأ خطوة خطوة. اعمل حسابك في هندلها',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: textSecColor,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF4A2B28) : const Color(0xFFFDE8E6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? AppColors.salmonBadge : AppColors.danger,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Field: الاسم
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'الاسم',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            textDirection: TextDirection.rtl,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'اكتب اسمك',
                              hintStyle: TextStyle(color: textSecColor.withValues(alpha: 0.5)),
                              prefixIcon: Icon(Icons.person_outline_rounded, color: textSecColor, size: 20),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك اكتب اسمك' : null,
                          ),
                          const SizedBox(height: 16),

                          // Field: البريد الإلكتروني
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'البريد الإلكتروني',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'name@example.com',
                              hintStyle: TextStyle(color: textSecColor.withValues(alpha: 0.5)),
                              prefixIcon: Icon(Icons.email_outlined, color: textSecColor, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'من فضلك اكتب البريد الإلكتروني';
                              if (!v.contains('@')) return 'البريد غير صحيح';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Field: كلمة المرور
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'كلمة المرور',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'اختار كلمة مرور',
                              hintStyle: TextStyle(color: textSecColor.withValues(alpha: 0.5)),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: textSecColor, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: textSecColor,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 8) return '٨ أحرف على الأقل، فيها حروف وأرقام';
                              return null;
                            },
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '.٨ أحرف على الأقل، فيها حروف وأرقام',
                              style: TextStyle(fontSize: 11, color: textSecColor.withValues(alpha: 0.7)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Checkbox: أوافق على شروط الاستخدام وسياسة الخصوصية
                          Row(
                            children: [
                              Checkbox(
                                value: _agreedToTerms,
                                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              ),
                              Expanded(
                                child: Text(
                                  'أوافق على شروط الاستخدام وسياسة الخصوصية.',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: textSecColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Submit Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'إنشاء حساب',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? AppColors.darkBackground : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                        color: isDark ? AppColors.darkBackground : Colors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Footer Link to Sign In
                    Center(
                      child: GestureDetector(
                        onTap: () => context.go('/login'),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13.5, color: textSecColor),
                            children: [
                              const TextSpan(text: 'عندك حساب بالفعل؟ '),
                              TextSpan(
                                text: 'تسجيل الدخول',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
