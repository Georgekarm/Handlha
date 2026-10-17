import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import 'auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController(text: 'ahmed@handelha.app');
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _loading = true);
    await ref.read(authNotifierProvider.notifier).sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: textSecColor, size: 26),
                    onPressed: () => context.pop(),
                  ),
                  Text(
                    'هندلها',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Page 12: Sent Confirmation State
              if (_sent) ...[
                Text(
                  'بصّ على بريدك',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'لو البريد ده مسجّل عندنا، هتلاقي عليه رابط لتغيير كلمة المرور.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: textSecColor, height: 1.4),
                ),
                const SizedBox(height: 32),

                // Mail icon card
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
                    color: isDark ? AppColors.darkSurface2 : const Color(0xFFEFF5F3),
                  ),
                  child: Icon(Icons.mark_email_read_outlined, size: 44, color: primaryColor),
                ),
                const SizedBox(height: 24),

                Text(
                  _emailCtrl.text,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                Text(
                  'الرابط صالح لمدة ٣٠ دقيقة. لو مش ظاهر، راجع الرسائل غير المرغوب فيها.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: textMutedColor, height: 1.45),
                ),
                const Spacer(),

                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('الرجوع لتسجيل الدخول', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _submit(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Text('إعادة الإرسال بعد ٠٠:٤٥', style: TextStyle(color: textSecColor, fontWeight: FontWeight.w600)),
                ),
              ]
              // Page 11: Request Reset Form
              else ...[
                Text(
                  'نسيت كلمة المرور؟',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '.ولا يهمك. اكتب بريدك وهنبعتلك رابط ترجع بيه لحسابك',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: textSecColor, height: 1.4),
                ),
                const SizedBox(height: 32),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'البريد الإلكتروني',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecColor),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined, color: textSecColor, size: 20),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ابعت رابط الاستعادة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkBackground : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: isDark ? AppColors.darkBackground : Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                InkWell(
                  onTap: () => context.pop(),
                  child: Text(
                    'افتكَرتها؟ ارجع للدخول',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecColor),
                  ),
                ),
                const Spacer(),
              ],

              const SizedBox(height: 16),
              Text(
                'خصوصيتك مهمة. إنت اللي تختار إيه يتحفظ.',
                style: TextStyle(fontSize: 11.5, color: textMutedColor),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
