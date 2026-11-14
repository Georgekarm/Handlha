import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_extension.dart';
import '../../../shared/utils/arabic_formatters.dart';
import '../../assistant/data/user_energy_preferences.dart';

/// Multi-page interactive onboarding & customization wizard where the user
/// configures their peak energy hours, task/project breakdown style, and
/// hard-task ordering strategy for the AI Assistant & Planner.
class EnergyPreferencesWizardSheet extends ConsumerStatefulWidget {
  const EnergyPreferencesWizardSheet({
    super.key,
    this.initialPreferences,
    this.onSaved,
  });

  final UserEnergyPreferences? initialPreferences;
  final ValueChanged<UserEnergyPreferences>? onSaved;

  static Future<UserEnergyPreferences?> show(
    BuildContext context, {
    UserEnergyPreferences? initialPreferences,
    ValueChanged<UserEnergyPreferences>? onSaved,
  }) {
    return showModalBottomSheet<UserEnergyPreferences>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EnergyPreferencesWizardSheet(
        initialPreferences: initialPreferences,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<EnergyPreferencesWizardSheet> createState() =>
      _EnergyPreferencesWizardSheetState();
}

class _EnergyPreferencesWizardSheetState
    extends ConsumerState<EnergyPreferencesWizardSheet> {
  int _step = 0; // 0, 1, 2
  late String _peakPeriod;
  late int _sessionMinutes;
  late String _hardStrategy;
  late String _projectStyle;

  @override
  void initState() {
    super.initState();
    final UserEnergyPreferences init =
        widget.initialPreferences ?? UserEnergyPreferencesStore.current;
    _peakPeriod = init.peakEnergyPeriod;
    _sessionMinutes = init.preferredSessionMinutes;
    _hardStrategy = init.hardTaskStrategy;
    _projectStyle = init.projectBreakdownStyle;
  }

  Future<void> _saveAndClose() async {
    final updated = UserEnergyPreferences(
      peakEnergyPeriod: _peakPeriod,
      preferredSessionMinutes: _sessionMinutes,
      hardTaskStrategy: _hardStrategy,
      projectBreakdownStyle: _projectStyle,
      completedWizard: true,
    );
    await ref
        .read(userEnergyPreferencesProvider.notifier)
        .updatePreferences(updated);
    widget.onSaved?.call(updated);
    if (mounted) {
      Navigator.of(context).pop(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;
    final previewPrefs = UserEnergyPreferences(
      peakEnergyPeriod: _peakPeriod,
      preferredSessionMinutes: _sessionMinutes,
      hardTaskStrategy: _hardStrategy,
      projectBreakdownStyle: _projectStyle,
      completedWizard: true,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 36, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.border),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar with step badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isEn
                          ? 'Step ${_step + 1} of 3 • AI Personalization'
                          : 'خطوة ${ArabicFormatters.toArabicDigits(_step + 1)} من ٣ • بصمة طاقتك الذكية',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: c.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress bar
              Row(
                children: List.generate(3, (index) {
                  final active = index <= _step;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsetsDirectional.only(
                        end: index < 2 ? 6 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: active ? c.primary : c.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),

              if (_step == 0) ...[
                Text(
                  isEn
                      ? 'When is your energy at its peak?'
                      : 'إمتى طاقتك بتكون مليانة وفي قمتها؟ ⚡',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isEn
                      ? 'The AI model will schedule your hardest exams, tasks, and projects during your peak hours.'
                      : 'المودل هيحطلك أهم التاسكات والمذاكرة والمشاريع في الوقت اللي دماغك بتكون فايقة فيه.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _OptionCard(
                  icon: Icons.wb_sunny_rounded,
                  iconColor: const Color(0xFFF5A623),
                  title: isEn
                      ? 'Morning Peak ☀️ (8 AM – 3 PM)'
                      : 'كائن صباحي ☀️ (٨ صباحًا – ٣ عصرًا)',
                  subtitle: isEn
                      ? 'I love finishing deep study and important tasks early while fresh.'
                      : 'بحب أنجز المذاكرة والشغل المهم بدري الصبح وأنا بكامل طاقتي.',
                  selected: _peakPeriod == 'morning',
                  onTap: () => setState(() => _peakPeriod = 'morning'),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  icon: Icons.wb_cloudy_rounded,
                  iconColor: const Color(0xFF2196F3),
                  title: isEn
                      ? 'Afternoon Focus 🌤️ (12 PM – 7 PM)'
                      : 'نشاط بعد الظهر 🌤️ (١٢ ظهرًا – ٧ مساءً)',
                  subtitle: isEn
                      ? 'My focus warms up around midday and stays strong through the afternoon.'
                      : 'طاقتي بتبدأ تعلى من نص اليوم وبنجز أحسن حاجة من الظهر للمغرب.',
                  selected: _peakPeriod == 'afternoon',
                  onTap: () => setState(() => _peakPeriod = 'afternoon'),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  icon: Icons.nights_stay_rounded,
                  iconColor: const Color(0xFF7B61FF),
                  title: isEn
                      ? 'Night Owl 🌙 (5 PM – 11 PM)'
                      : 'كائن ليلي 🌙 (٥ مساءً – ١١ مساءً)',
                  subtitle: isEn
                      ? 'I focus best in the calm of the evening and night hours.'
                      : 'تركيزي وإبداعي بيوصلوا لقمتهم بليل في الهدوء بعيد عن الدوشة.',
                  selected: _peakPeriod == 'evening',
                  onTap: () => setState(() => _peakPeriod = 'evening'),
                ),
              ] else if (_step == 1) ...[
                Text(
                  isEn
                      ? 'How do you like splitting tasks & projects?'
                      : 'بتحب تقسم التاسكات والمشاريع إزاي؟ 🧩',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isEn
                      ? 'Controls how the assistant breaks down exams and big projects into steps.'
                      : 'بيحدد إزاي المساعد يقسملك أي امتحان أو مشروع كبير لخطوات على مقاس تركيزك.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _OptionCard(
                  icon: Icons.flash_on_rounded,
                  iconColor: const Color(0xFFF5A623),
                  title: isEn
                      ? 'Quick 25-Min Sprints ⚡ (Pomodoro)'
                      : 'جلسات سريعة ٢٥ دقيقة ⚡ (بومودورو)',
                  subtitle: isEn
                      ? 'Short micro-steps with frequent breaks so you never feel bored or overwhelmed.'
                      : 'تقسيم التاسكات لخطوات قصيرة وسريعة تمنع الزهق أو السرحان.',
                  selected: _sessionMinutes == 25,
                  onTap: () => setState(() {
                    _sessionMinutes = 25;
                    _projectStyle = 'micro_steps';
                  }),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  icon: Icons.track_changes_rounded,
                  iconColor: c.primary,
                  title: isEn
                      ? 'Balanced 45-Min Blocks 🎯'
                      : 'جلسات متوازنة ٤٥ دقيقة 🎯',
                  subtitle: isEn
                      ? 'Ideal balance for studying chapters, solving exams, and steady project work.'
                      : 'التقسيم المثالي لمذاكرة الدروس وحل الامتحانات وإنجاز المشاريع بتوازن.',
                  selected: _sessionMinutes == 45,
                  onTap: () => setState(() {
                    _sessionMinutes = 45;
                    _projectStyle = 'micro_steps';
                  }),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  icon: Icons.psychology_rounded,
                  iconColor: const Color(0xFF7B61FF),
                  title: isEn
                      ? 'Deep 60-Min Focus 🧠'
                      : 'تركيز عميق ٦٠ دقيقة 🧠 (للمشاريع التقيلة)',
                  subtitle: isEn
                      ? 'Long uninterrupted blocks for complex projects and deep study.'
                      : 'جلسات طويلة ومتصلة للمشاريع الكبيرة اللي بتحتاج اندماج كامل.',
                  selected: _sessionMinutes == 60,
                  onTap: () => setState(() {
                    _sessionMinutes = 60;
                    _projectStyle = 'milestone_blocks';
                  }),
                ),
              ] else ...[
                Text(
                  isEn
                      ? 'How should we order hard tasks?'
                      : 'تحب نبدأ بالتاسكات الصعبة إمتى؟ 🔥',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isEn
                      ? 'Choose how the assistant orders your daily schedule draft.'
                      : 'اختار الطريقة اللي تريحك لما السكرتير الذكي يرتبلك جدول يومك.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _OptionCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF6B35),
                  title: isEn
                      ? 'Hardest First at Peak Energy 🔥'
                      : 'أخلّص الأصعب في أول قمة طاقتي 🔥',
                  subtitle: isEn
                      ? 'Put exams and urgent tasks right at the start of my peak hours.'
                      : 'حطلي أثقل امتحان أو مهمة في أول وقت نشاطي عشان أرتاح باقي اليوم.',
                  selected: _hardStrategy == 'peak_first',
                  onTap: () => setState(() => _hardStrategy = 'peak_first'),
                ),
                const SizedBox(height: 10),
                _OptionCard(
                  icon: Icons.spa_rounded,
                  iconColor: c.primary,
                  title: isEn
                      ? 'Easy Warm-up Task First 🌱'
                      : 'أبدأ بمهمة خفيفة تفتح نفسي الأول 🌱',
                  subtitle: isEn
                      ? 'Schedule a quick 15-min win first to build momentum before heavy tasks.'
                      : 'ابدألي بمهمة سريعة وسهلة تحمسني وتديني دفعة قبل ما ندخل في التقيل.',
                  selected: _hardStrategy == 'warmup_first',
                  onTap: () => setState(() => _hardStrategy = 'warmup_first'),
                ),
                const SizedBox(height: 14),
                // Live AI Summary Preview
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: c.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 17,
                            color: c.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'How the AI Model Will Plan Your Day:'
                                  : 'إزاي المودل هيقسملك مهامك ومشاريعك:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: c.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEn
                            ? '• Peak Schedule Window: ${previewPrefs.peakLabelEn}\n'
                                '• Task & Project Breakdown: $_sessionMinutes-min steps\n'
                                '• Priority Order: ${previewPrefs.strategyLabelEn}'
                            : '• وقت الجدولة الأساسي: ${previewPrefs.peakLabelAr}\n'
                                '• تقسيم المهام والمشاريع: خطوات من ${ArabicFormatters.toArabicDigits(_sessionMinutes)} دقيقة\n'
                                '• ترتيب الأولويات: ${previewPrefs.strategyLabelAr}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isEn ? 'Back' : 'السابق',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_step < 2) {
                          setState(() => _step++);
                        } else {
                          _saveAndClose();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.textOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _step < 2
                            ? (isEn ? 'Next Step' : 'الخطوة الجاية')
                            : (isEn
                                ? 'Save My Energy Profile ⚡'
                                : 'اعتمد بصمة طاقتي وتفضيلاتي ⚡'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: c.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? c.primary : c.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
