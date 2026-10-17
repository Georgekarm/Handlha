import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 1; // 1 or 2
  final Set<int> _selectedGoals = {0}; // Step 1 goals
  int _energyLevel = 1; // 0: قليلة, 1: متوسطة, 2: عالية
  int _assistantTone = 0; // 0: بهدوء ومن غير ضغط, 1: مختصر ومباشر

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              // Top Navigation: "تخطي" on left, "الخطوة ١ من ٢" in center, back chevron on right if step 2
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text('تخطي', style: TextStyle(color: textSecColor, fontSize: 13)),
                  ),
                  Text(
                    'الخطوة $_currentStep من ٢',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecColor),
                  ),
                  if (_currentStep == 2)
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: textSecColor),
                      onPressed: () => setState(() => _currentStep = 1),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 8),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _currentStep == 1 ? 0.5 : 1.0,
                  minHeight: 4,
                  backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              const SizedBox(height: 28),

              Expanded(
                child: SingleChildScrollView(
                  child: _currentStep == 1
                      ? _buildStep1(surfaceColor, borderColor, textColor, textSecColor, primaryColor, isDark)
                      : _buildStep2(surfaceColor, borderColor, textColor, textSecColor, textMutedColor, primaryColor, isDark),
                ),
              ),

              // Bottom Button
              ElevatedButton(
                onPressed: () {
                  if (_currentStep == 1) {
                    setState(() => _currentStep = 2);
                  } else {
                    context.go('/home');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentStep == 1 ? 'كمّل' : 'تمام، نرتّب يومي',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkBackground : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20, color: isDark ? AppColors.darkBackground : Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Footer Note
              Text(
                _currentStep == 1
                    ? 'اختياراتك بتساعدنا نبدأ، مش بتقيدك'
                    : 'اختياراتك قابلة للتغيير من الإعدادات',
                style: TextStyle(fontSize: 11.5, color: textMutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step 1: تحب هندلها يساعدك في إيه؟ (Page 13)
  Widget _buildStep1(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تحب هندلها يساعدك في إيه؟',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'اختار اللي شبهك؛ ممكن تختار أكثر من حاجة. مفيش طريقة واحدة صح.',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 13.5, color: textSecColor, height: 1.45),
        ),
        const SizedBox(height: 24),

        _buildOptionCard(
          index: 0,
          title: 'أنظّم يومي',
          subtitle: 'أولويات واضحة، بدل قائمة بتطوّل',
          icon: Icons.checklist_rounded,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 14),

        _buildOptionCard(
          index: 1,
          title: 'أتابع مشاريعي',
          subtitle: 'أقسّم الهدف لخطوات أقدر أبدأها',
          icon: Icons.folder_outlined,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 14),

        _buildOptionCard(
          index: 2,
          title: 'أفضّي اللي في دماغي',
          subtitle: 'أكتب بطريقتي، وهندلها يساعدني أرتّب',
          icon: Icons.edit_note_rounded,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecColor,
    required Color primaryColor,
  }) {
    final selected = _selectedGoals.contains(index);

    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedGoals.remove(index);
          } else {
            _selectedGoals.add(index);
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primaryColor : borderColor,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(color: selected ? primaryColor : borderColor, width: 1.8),
              ),
              child: selected ? Icon(Icons.check_rounded, size: 16, color: primaryColor) : null,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: textSecColor),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Icon(icon, size: 24, color: textSecColor),
          ],
        ),
      ),
    );
  }

  // Step 2: على قد طاقتك، وبطريقتك (Page 14)
  Widget _buildStep2(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color textSecColor,
    Color textMutedColor,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'على قد طاقتك، وبطريقتك',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'مش كل الأيام زي بعض. نبدأ بإعداد مريح، وتقدر تغيّره في أي وقت.',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 13.5, color: textSecColor, height: 1.45),
        ),
        const SizedBox(height: 26),

        // Section 1: طاقتك غالبًا في بداية اليوم؟
        Text(
          'طاقتك غالبًا في بداية اليوم؟',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildEnergyChip(2, 'عالية', surfaceColor, borderColor, textColor, primaryColor),
            const SizedBox(width: 10),
            _buildEnergyChip(1, 'متوسطة', surfaceColor, borderColor, textColor, primaryColor),
            const SizedBox(width: 10),
            _buildEnergyChip(0, 'قليلة', surfaceColor, borderColor, textColor, primaryColor),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'هنقترح خطوات تناسب وقتك وطاقتك، مش أكتر.',
            style: TextStyle(fontSize: 12, color: textMutedColor),
          ),
        ),
        const SizedBox(height: 28),

        // Section 2: تحب المساعد يتكلم إزاي؟
        Text(
          'تحب المساعد يتكلم إزاي؟',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
        ),
        const SizedBox(height: 14),

        _buildToneCard(
          index: 0,
          title: 'بهدوء ومن غير ضغط',
          subtitle: 'خطوات صغيرة، وتشجيع على قدّك',
          icon: Icons.auto_awesome_rounded,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 12),

        _buildToneCard(
          index: 1,
          title: 'مختصر ومباشر',
          subtitle: 'اقتراح واضح ومن غير كلام كتير',
          icon: Icons.menu_rounded,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textColor: textColor,
          textSecColor: textSecColor,
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildEnergyChip(
    int index,
    String label,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color primaryColor,
  ) {
    final active = _energyLevel == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _energyLevel = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: active ? primaryColor.withValues(alpha: 0.2) : surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? primaryColor : borderColor,
              width: active ? 1.8 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? primaryColor : textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToneCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecColor,
    required Color primaryColor,
  }) {
    final selected = _assistantTone == index;

    return InkWell(
      onTap: () => setState(() => _assistantTone = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primaryColor : borderColor,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(color: selected ? primaryColor : borderColor, width: 1.8),
              ),
              child: selected ? Icon(Icons.check_rounded, size: 16, color: primaryColor) : null,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: textSecColor),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Icon(icon, size: 22, color: textSecColor),
          ],
        ),
      ),
    );
  }
}
