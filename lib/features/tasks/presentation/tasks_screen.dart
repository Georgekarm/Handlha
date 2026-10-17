import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/quick_add_bottom_sheet.dart';

enum _TaskFilterTab { today, inbox, completed }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _TaskFilterTab _currentTab = _TaskFilterTab.today;
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedTaskIds = {'1', '2'}; // Simulated 2 selected matching Page 5
  final bool _isOffline = false;
  bool _isSimulatingError = false;
  final bool _isSimulatingLoading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  // Top Header: + button on left, Title on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.add_rounded, color: textColor, size: 24),
                          onPressed: () => QuickAddBottomSheet.show(context),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'مهامك، على مهلك',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '٣ خلصوا • ٥ خطوات لسه قدامك',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _searchCtrl,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: '...دوّر على مهمة',
                        hintStyle: TextStyle(color: textMutedColor, fontSize: 13.5),
                        suffixIcon: Icon(Icons.search_rounded, color: textMutedColor, size: 22),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Segmented Tabs: [اليوم ٨] [الوارد] [المكتملة ٣]
                  Row(
                    children: [
                      Expanded(
                        child: _SegmentTab(
                          label: 'المكتملة ٣',
                          active: _currentTab == _TaskFilterTab.completed,
                          isDark: isDark,
                          onTap: () => setState(() => _currentTab = _TaskFilterTab.completed),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SegmentTab(
                          label: 'الوارد',
                          active: _currentTab == _TaskFilterTab.inbox,
                          isDark: isDark,
                          onTap: () => setState(() => _currentTab = _TaskFilterTab.inbox),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SegmentTab(
                          label: 'اليوم ٨',
                          active: _currentTab == _TaskFilterTab.today,
                          isDark: isDark,
                          onTap: () => setState(() => _currentTab = _TaskFilterTab.today),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter & Sort Row
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (_selectedTaskIds.isEmpty) {
                              _selectedTaskIds.addAll(['1', '2']);
                            } else {
                              _selectedTaskIds.clear();
                            }
                          });
                        },
                        child: Text(
                          _selectedTaskIds.isEmpty ? 'تحديد' : 'إلغاء التحديد',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecColor),
                        ),
                      ),
                      const Spacer(),
                      // Sort
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 16, color: textSecColor),
                            const SizedBox(width: 4),
                            Text('الموعد', style: TextStyle(fontSize: 12, color: textColor)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Projects Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textSecColor),
                            const SizedBox(width: 4),
                            Text('كل المشاريع', style: TextStyle(fontSize: 12, color: textColor)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter icon
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(Icons.tune_rounded, size: 18, color: textColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // State Demonstration switch (Page 36 shimmer, 37 empty, 38 error, 39 offline)
                  if (_isOffline)
                    _buildOfflineBanner(),

                  // Content based on tab and simulation states:
                  if (_isSimulatingLoading)
                    _buildShimmerLoadingState(surfaceColor, borderColor)
                  else if (_isSimulatingError)
                    _buildErrorState(surfaceColor, borderColor, textColor, textSecColor, primaryColor, isDark)
                  else if (_currentTab == _TaskFilterTab.inbox)
                    _buildEmptyInboxState(surfaceColor, borderColor, textColor, textSecColor, primaryColor, isDark)
                  else ...[
                    // Header: "الأولوية دلوقتي"
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الأولوية دلوقتي',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tasks items
                    _buildTaskItem(
                      id: '1',
                      title: 'مراجعة تدفق المهام وتجربة المستخدم',
                      line1: '١٢:٠٠ م • ٢٥ دقيقة • طاقة متوسطة',
                      line2: 'أولوية عالية • إطلاق نسخة هندلها',
                      isCompleted: true,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecColor: textSecColor,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildTaskItem(
                      id: '2',
                      title: 'إعداد جلسة الاختبار التفاعلية',
                      line1: '١:٠٠ م • ٣٠ دقيقة • طاقة متوسطة',
                      line2: 'أولوية متوسطة • إطلاق نسخة هندلها',
                      isCompleted: true,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecColor: textSecColor,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildTaskItem(
                      id: '3',
                      title: 'ترتيب ملفات المشروع',
                      line1: '٤:٠٠ م • ١٥ دقيقة • طاقة متوسطة',
                      line2: 'أولوية منخفضة • تنظيم مساحة العمل',
                      isCompleted: false,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecColor: textSecColor,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Selection Action Bar (when tasks are selected, matching Page 5)
            if (_selectedTaskIds.isNotEmpty && !_isSimulatingLoading && !_isSimulatingError && _currentTab == _TaskFilterTab.today)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13201D) : const Color(0xFFF0F5F3),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'مهمتين متحددين • لسه ما اكتملوش',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Button 1: أرشفة ٢
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() => _selectedTaskIds.clear());
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: surfaceColor,
                              foregroundColor: textColor,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(
                              'أرشفة ${_selectedTaskIds.length}',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Button 2: تعديل
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              backgroundColor: surfaceColor,
                              foregroundColor: textColor,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(
                              'تعديل',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Button 3: إكمال ٢ ✓ (Mint Green button)
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _selectedTaskIds.clear());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم إكمال المهام المحددة! خطوة ممتازة.'), behavior: SnackBarBehavior.floating),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(
                              'إكمال ${_selectedTaskIds.length} ✓',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkBackground : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem({
    required String id,
    required String title,
    required String line1,
    required String line2,
    required bool isCompleted,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecColor,
    required Color primaryColor,
    required bool isDark,
  }) {
    final isSelected = _selectedTaskIds.contains(id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? primaryColor.withValues(alpha: 0.6) : borderColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.edit_outlined, size: 18, color: textSecColor),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line1,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: textSecColor),
              ),
              const SizedBox(height: 2),
              Text(
                line2,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: textSecColor),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Checkbox / selection indicator
          GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedTaskIds.remove(id);
                } else {
                  _selectedTaskIds.add(id);
                }
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected ? primaryColor : textSecColor,
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: isDark ? AppColors.darkBackground : Colors.white,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // Page 39: Offline Warning Banner
  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A2B28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.salmonBadge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.wifi_off_rounded, color: AppColors.salmonBadge, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنت مش متصل بالإنترنت',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'المعروض آخر بيانات متاحة. الإضافة والمساعد محتاجين اتصال؛ مفيش مزامنة مضمونة.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Page 37: Empty Inbox state
  Widget _buildEmptyInboxState(Color surfaceColor, Color borderColor, Color textColor, Color textSecColor, Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.inbox_outlined, size: 32, color: primaryColor),
          ),
          const SizedBox(height: 18),
          Text(
            'مساحة لفكرة جديدة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'الوارد فاضي. أي حاجة في بالك، اكتبها هنا ونرتبها سوا.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: textSecColor, height: 1.45),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => QuickAddBottomSheet.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              minimumSize: const Size(200, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              '+ اكتب أول مهمة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Page 38: Error state
  Widget _buildErrorState(Color surfaceColor, Color borderColor, Color textColor, Color textSecColor, Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.salmonBadge.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.refresh_rounded, size: 32, color: AppColors.salmonBadge),
          ),
          const SizedBox(height: 18),
          Text(
            'المهام ما ظهرتش',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'في مشكلة في تحميل القائمة؛ جرّب تاني؛ مش محتاج تعيد كتابة حاجة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: textSecColor, height: 1.45),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _isSimulatingError = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              minimumSize: const Size(200, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'حاول تاني ↻',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkBackground : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Page 36: Shimmer / skeleton loading
  Widget _buildShimmerLoadingState(Color surfaceColor, Color borderColor) {
    return Column(
      children: [
        for (int i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 180, height: 12, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(width: 120, height: 10, decoration: BoxDecoration(color: borderColor.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Center(
          child: Text('...بنجّهز مهامك', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF1F3530) : const Color(0xFFC7E6DE);
    final inactiveBg = isDark ? AppColors.darkSurface : Colors.white;
    final activeText = isDark ? AppColors.darkPrimary : AppColors.primaryStrong;
    final inactiveText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: active ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? (isDark ? AppColors.darkPrimary.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.4))
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }
}
