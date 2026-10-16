import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_background.dart';
import '../../../shared/widgets/handelha_brand.dart';
import '../../../shared/widgets/handelha_illustration.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../authentication/domain/app_user.dart';
import '../../authentication/presentation/auth_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameCtrl = TextEditingController();
  int _page = 0;
  OnboardingUsageType _usage = OnboardingUsageType.mixed;
  String _activity = 'morning';
  String _notifications = 'gentle';
  AssistantTone _tone = AssistantTone.friendly;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final name = ref.read(authNotifierProvider).value?.displayName;
    if (name != null && name.isNotEmpty) _nameCtrl.text = name;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(authNotifierProvider.notifier).markOnboardingComplete();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (_page == 0 || _page > 2)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 10),
                  child: Row(
                    children: [
                      if (_page == 3) ...[
                        Text('${_page + 1} من ٥', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        TextButton(
                          onPressed: _finish, 
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('تخطي', style: TextStyle(fontWeight: FontWeight.bold)),
                              Icon(Icons.chevron_left_rounded, size: 20),
                            ],
                          )
                        ),
                      ] else ...[
                        Text('${_page + 1} من ٥', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        TextButton(onPressed: _finish, child: const Text('تخطي', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 10),
                  child: Row(
                    children: [
                      const HandelhaLogo(markSize: 24, fontSize: 16),
                      const Spacer(),
                      Row(
                        children: List.generate(5, (index) {
                          final num = 5 - index; // RTL 5 to 1
                          final active = num == (_page + 1);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Row(
                              children: [
                                if (index > 0)
                                  Container(
                                    width: 16,
                                    height: 1,
                                    color: AppColors.border,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: active ? AppColors.primaryStrong : AppColors.primarySoft,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('$num', style: TextStyle(color: active ? Colors.white : AppColors.primaryStrong, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      TextButton(onPressed: _finish, child: const Text('تخطي', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              if (_page == 0 || _page > 2)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 2),
                  child: Row(
                    children: List.generate(5, (index) {
                      final active = index <= _page;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? AppColors.primaryStrong : (isDark ? AppColors.darkBorder : AppColors.primarySoft),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _page = index),
                  children: [
                    _StepPage(
                      title: 'أهلاً بيك، تحب نناديك بإيه؟',
                      subtitle: 'هنساعدك ترتّب يومك بهدوء، ونناديك بالاسم اللي تحبه.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text('اسمك الأول أو اللقب المفضل', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: 'اكتب هنا...', 
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StepPage(
                      title: 'إيه أكتر مجال محتاج ترتبه ؟',
                      subtitle: 'سنقترح عليك خططًا واقعية تناسب طبيعة يومك.',
                      child: Column(children: [
                        _ChoiceCard(icon: Icons.work_rounded, title: 'العمل والمشاريع المهنية', subtitle: 'متابعة المهام ومواعيد التسليم', selected: _usage == OnboardingUsageType.work, onTap: () => setState(() => _usage = OnboardingUsageType.work)),
                        _ChoiceCard(icon: Icons.school_rounded, title: 'الدراسة والتعلم', subtitle: 'تنظيم أوقات المذاكرة والأبحاث', selected: _usage == OnboardingUsageType.study, onTap: () => setState(() => _usage = OnboardingUsageType.study)),
                        _ChoiceCard(icon: Icons.home_rounded, title: 'الحياة اليومية والراحة', subtitle: 'ترتيب الأولويات الشخصية والصحية', selected: _usage == OnboardingUsageType.personal, onTap: () => setState(() => _usage = OnboardingUsageType.personal)),
                        _ChoiceCard(icon: Icons.grid_view_rounded, title: 'مزيج متوازن من كل شيء', subtitle: 'تنظيم شامل للحياة والعمل', selected: _usage == OnboardingUsageType.mixed, onTap: () => setState(() => _usage = OnboardingUsageType.mixed)),
                      ]),
                    ),
                    _StepPage(
                      title: 'ما هي أفضل أوقات نشاطك؟',
                      subtitle: 'لتحديد فترات تركيزك وحماية أوقات راحتك من أي تشتيت.',
                      child: Column(children: [
                        _ChoiceCard(icon: Icons.wb_sunny_rounded, title: 'صباحي بامتياز', subtitle: 'أعلى طاقتي بين ٨ صباحًا و ٢ ظهرًا', selected: _activity == 'morning', onTap: () => setState(() => _activity = 'morning')),
                        _ChoiceCard(icon: Icons.nightlight_round, title: 'مسائي وهادئ', subtitle: 'أفضّل التركيز بين ٢ ظهرًا و ٨ مساءً', selected: _activity == 'afternoon', onTap: () => setState(() => _activity = 'afternoon')),
                        _ChoiceCard(icon: Icons.dashboard_customize_rounded, title: 'أوقات مرنة', subtitle: 'طاقتي تتغير حسب جدول اليوم', selected: _activity == 'flexible', onTap: () => setState(() => _activity = 'flexible')),
                      ]),
                    ),
                    _StepPage(
                      title: 'طريقة التنبيهات المريحة لك',
                      subtitle: 'تطبيقنا مبني على فلسفة الهدوء وعدم الإزعاج أو التشتيت.',
                      child: Column(children: [
                        _ChoiceCard(radioRight: true, title: 'تذكير لطيف قبل المهام فقط', subtitle: 'إشعار واحد هادئ عند اقتراب الموعد', selected: _notifications == 'gentle', onTap: () => setState(() => _notifications = 'gentle')),
                        _ChoiceCard(radioRight: true, title: 'ملخص يومي خفيف', subtitle: 'رسالة واحدة صباحاً بأهم أولويات اليوم', selected: _notifications == 'summaryOnly', onTap: () => setState(() => _notifications = 'summaryOnly')),
                        _ChoiceCard(radioRight: true, title: 'صامت وبدون إشعارات', subtitle: 'أفتح التطبيق وقتما أريد دون إزعاج', selected: _notifications == 'silent', onTap: () => setState(() => _notifications = 'silent')),
                      ]),
                    ),
                    _StepPage(
                      title: 'نبرة المساعد التي تفضلها',
                      subtitle: 'اختر كيف يتحدث معك المساعد داخل المحادثة وأثناء الترتيب.',
                      child: Column(children: [
                        _ChoiceCard(radioRight: true, title: 'ودودة ومصرية', subtitle: 'صباح الفل، نبدأ بإيه الأول النهارده؟ خلينا ناخدها\nخطوة صغيرة.', selected: _tone == AssistantTone.friendly, onTap: () => setState(() => _tone = AssistantTone.friendly)),
                        _ChoiceCard(radioRight: true, title: 'عربية فصحى هادئة', subtitle: 'مرحبًا بك، دعنا نرتب أولويات يومك بهدوء ووضوح.', selected: _tone == AssistantTone.formal, onTap: () => setState(() => _tone = AssistantTone.formal)),
                        _ChoiceCard(radioRight: true, title: 'موجزة ومباشرة', subtitle: 'تم ترتيب المهمة، الخطوة التالية بعد ١٥ دقيقة.', selected: _tone == AssistantTone.brief, onTap: () => setState(() => _tone = AssistantTone.brief)),
                      ]),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 5, 20, 18),
                child: PrimaryButton(
                  text: _page == 4 ? 'ابدأ يومك بهدوء' : 'المتابعة',
                  icon: _page >= 3 ? const Icon(Icons.arrow_back_rounded) : null,
                  isLoading: _finishing,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 24, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontWeight: FontWeight.normal, height: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({this.icon, this.radioRight = false, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData? icon;
  final bool radioRight;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final content = Column(
      crossAxisAlignment: radioRight ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
      ],
    );

    final radioButton = Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppColors.primaryStrong : AppColors.textMuted, size: 26);
    
    Widget leadingWidget;
    Widget trailingWidget;
    
    if (radioRight) {
      leadingWidget = radioButton;
      trailingWidget = const SizedBox.shrink();
    } else {
      leadingWidget = icon != null ? Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: selected ? AppColors.primaryStrong : (isDark ? AppColors.darkSurface2 : AppColors.primarySoft), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: selected ? Colors.white : AppColors.primaryStrong, size: 26),
      ) : const SizedBox.shrink();
      trailingWidget = radioButton;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? (isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft.withValues(alpha: 0.5)) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.primaryStrong : (isDark ? AppColors.darkBorder : AppColors.border), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              leadingWidget,
              const SizedBox(width: 16),
              Expanded(child: content),
              if (!radioRight) const SizedBox(width: 16),
              if (!radioRight) trailingWidget,
            ],
          ),
        ),
      ),
    );
  }
}
