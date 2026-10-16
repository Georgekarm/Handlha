import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/handelha_brand.dart';
import '../domain/project.dart';

class ProjectWithAccent {
  final Project project;
  final Color accentColor;
  final List<String> subtasks;

  const ProjectWithAccent({
    required this.project,
    required this.accentColor,
    required this.subtasks,
  });
}

// Mock projects with Calm Productivity palette
final _mockProjectsWithAccent = [
  ProjectWithAccent(
    project: Project(
      id: '1',
      userId: 'user1',
      title: 'إطلاق نسخة هندلها',
      description: 'نشر نسخة تجريبية قابلة للاستخدام.',
      status: ProjectStatus.active,
      progressPercent: 0.65,
      nextStepTitle: 'مراجعة تدفق المهام',
      targetDate: DateTime.now().add(const Duration(days: 20)),
      taskIds: const [],
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      updatedAt: DateTime.now(),
    ),
    accentColor: AppColors.projectSage,
    subtasks: const [
      'تحديث نظام الألوان الهادئ (منجز)',
      'ضبط تدفق الشات والمقترحات (منجز)',
      'إعداد جلسة التركيز التفاعلية',
    ],
  ),
  ProjectWithAccent(
    project: Project(
      id: '2',
      userId: 'user1',
      title: 'تنظيم مساحة العمل',
      description: 'تهيئة مكان مريح للتركيز والإنجاز.',
      status: ProjectStatus.active,
      progressPercent: 0.40,
      nextStepTitle: 'ترتيب أوراق المشاريع المؤجلة',
      targetDate: DateTime.now().add(const Duration(days: 10)),
      taskIds: const [],
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now(),
    ),
    accentColor: AppColors.projectDustyBlue,
    subtasks: const [
      'فرز الملاحظات الورقية',
      'تنظيم الملفات الرقمية في مجلدات هادئة',
      'إعداد إضاءة مريحة للقراءة',
    ],
  ),
  ProjectWithAccent(
    project: Project(
      id: '3',
      userId: 'user1',
      title: 'قراءة كتاب التركيز',
      description: 'قراءة هادئة على مهل، فصلًا بعد فصل.',
      status: ProjectStatus.paused,
      progressPercent: 0.25,
      nextStepTitle: 'العودة للفصل الثالث',
      taskIds: const [],
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now(),
    ),
    accentColor: AppColors.projectSoftSand,
    subtasks: const [
      'قراءة المقدمة والفصل 1 (منجز)',
      'قراءة الفصل 2 (منجز)',
      'تلخيص النقاط الذهبية',
    ],
  ),
  ProjectWithAccent(
    project: Project(
      id: '4',
      userId: 'user1',
      title: 'تطوير موقع البورتفوليو',
      description: 'عرض الأعمال والمشاريع بأسلوب Minimal.',
      status: ProjectStatus.completed,
      progressPercent: 1.0,
      nextStepTitle: null,
      taskIds: const [],
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    accentColor: AppColors.projectLavender,
    subtasks: const [
      'اختيار التصميم والخطوط',
      'كتابة نبذة عن الخبرات',
      'نشر الموقع على الدومين',
    ],
  ),
];

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  ProjectStatus? _filterStatus;
  late final List<ProjectWithAccent> _projects = List.of(_mockProjectsWithAccent);

  List<ProjectWithAccent> get _filteredProjects {
    if (_filterStatus == null) return _projects;
    return _projects
        .where((p) => p.project.status == _filterStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مشاريعي', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkPrimary : AppColors.primaryStrong)),
            const SizedBox(height: 4),
            Text('كل مشاريعك في مكان واحد', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'بحث',
            onPressed: () {},
            icon: Icon(Icons.search_rounded, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary, size: 28),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: IconButton(
              tooltip: 'مشروع جديد',
              onPressed: () => _showNewProjectSheet(context),
              icon: Icon(Icons.add_rounded, color: isDark ? AppColors.darkPrimaryStrong : AppColors.primaryStrong, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimarySoft : AppColors.primarySoft,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'الكل',
                  isSelected: _filterStatus == null,
                  onTap: () => setState(() => _filterStatus = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'شغّالة',
                  isSelected: _filterStatus == ProjectStatus.active,
                  onTap: () =>
                      setState(() => _filterStatus = ProjectStatus.active),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'مؤجلة',
                  isSelected: _filterStatus == ProjectStatus.paused,
                  onTap: () =>
                      setState(() => _filterStatus = ProjectStatus.paused),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'مكتملة',
                  isSelected: _filterStatus == ProjectStatus.completed,
                  onTap: () =>
                      setState(() => _filterStatus = ProjectStatus.completed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Projects list
          Expanded(
            child: _filteredProjects.isEmpty
                ? _EmptyProjectsView()
                : ListView.separated(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      16,
                      8,
                      16,
                      MediaQuery.of(context).padding.bottom + 100,
                    ),
                    itemCount: _filteredProjects.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _ProjectCardItem(
                      item: _filteredProjects[i],
                      onTap: () =>
                          _openProjectWorkspace(context, _filteredProjects[i]),
                      onStartFocus: () =>
                          _openFocusSession(context, _filteredProjects[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openProjectWorkspace(BuildContext context, ProjectWithAccent item) {
    context.push(
      '/project-workspace',
      extra: {
        'id': item.project.id,
        'title': item.project.title,
        'goal': item.project.description ?? 'إطلاق أول نسخة تجريبية من التطبيق',
        'color': item.accentColor.value.toString(),
      },
    );
  }

  Future<void> _showNewProjectSheet(BuildContext context) async {
    final project = await showModalBottomSheet<ProjectWithAccent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewProjectSheet(),
    );
    if (project != null && mounted) {
      setState(() => _projects.insert(0, project));
    }
  }

  void _openFocusSession(BuildContext context, ProjectWithAccent item) {
    context.push(
      '/focus-session',
      extra: item.project.nextStepTitle ?? item.project.title,
    );
  }
}

// ---------------------------------------------------------------------------
// شريط الإحصائيات الهادئة
// ---------------------------------------------------------------------------
class _StatsBar extends StatelessWidget {
  final List<ProjectWithAccent> projects;
  const _StatsBar({required this.projects});

  @override
  Widget build(BuildContext context) {
    final active = projects
        .where((p) => p.project.status == ProjectStatus.active)
        .length;
    final completed = projects
        .where((p) => p.project.status == ProjectStatus.completed)
        .length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final successColor = isDark ? AppColors.darkSuccess : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: '${projects.length}', label: 'كل المشاريع'),
          Container(width: 1, height: 28, color: dividerColor),
          _StatItem(
            value: '$active',
            label: 'قيد التنفيذ',
            color: primaryColor,
          ),
          Container(width: 1, height: 28, color: dividerColor),
          _StatItem(
            value: '$completed',
            label: 'مكتملة',
            color: successColor,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _StatItem({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة المشروع الهادئة
// ---------------------------------------------------------------------------
class _ProjectCardItem extends StatelessWidget {
  final ProjectWithAccent item;
  final VoidCallback onStartFocus;
  final VoidCallback onTap;

  const _ProjectCardItem({
    required this.item,
    required this.onStartFocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final project = item.project;
    final isCompleted = project.status == ProjectStatus.completed;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? (isDark ? AppColors.darkSuccess.withValues(alpha: 0.2) : const Color(0xFFE8F5E9)) : (isDark ? AppColors.darkWarning.withValues(alpha: 0.2) : const Color(0xFFFFF3E0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted ? 'مكتمل' : 'قيد التنفيذ',
                    style: TextStyle(
                      color: isCompleted ? (isDark ? AppColors.darkSuccess : const Color(0xFF2E7D32)) : (isDark ? AppColors.darkWarning : const Color(0xFFE65100)),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${(project.progressPercent * 10).round()} مهام متبقية',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: project.progressPercent,
                backgroundColor: isDark ? AppColors.darkDivider : AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.primaryStrong),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// Filter Chip
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? AppColors.darkPrimary : AppColors.primary;
    final activeFg = isDark ? const Color(0xFF111A19) : Colors.white;
    final inactiveBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final inactiveFg =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeBg : borderColor,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected ? activeFg : inactiveFg,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyProjectsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: AppColors.primaryDark,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'مفيش مشاريع في هذا القسم',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'تقدر تضيف مشروع هادئ جديد في أي وقت.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New Project Sheet
// ---------------------------------------------------------------------------
class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('مشروع جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'اسم المشروع...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'أهداف المشروع...',
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: borderColor)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primaryStrong, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  if (_titleCtrl.text.trim().isNotEmpty) {
                    final now = DateTime.now();
                    Navigator.pop(
                      context,
                      ProjectWithAccent(
                        project: Project(
                          id: 'project-${now.microsecondsSinceEpoch}',
                          userId: 'user1',
                          title: _titleCtrl.text.trim(),
                          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                          status: ProjectStatus.active,
                          progressPercent: 0,
                          nextStepTitle: null,
                          targetDate: null,
                          taskIds: const [],
                          createdAt: now,
                          updatedAt: now,
                        ),
                        accentColor: AppColors.primaryStrong,
                        subtasks: const [],
                      ),
                    );
                  }
                },
                child: const Text('إضافة المشروع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
