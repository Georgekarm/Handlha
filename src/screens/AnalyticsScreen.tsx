import React, { useState, useMemo } from 'react';
import { useApp } from '../context/AppContext';
import {
  TrendingUp,
  Clock,
  CheckCircle2,
  Folder,
  Calendar,
  AlertCircle,
  Sparkles,
  Zap,
  Filter,
  Search,
  ArrowRight,
  ArrowLeft,
  Play,
  Layers,
  Check,
  ChevronDown,
  BarChart3,
  Flame,
  ArrowUpRight,
  ExternalLink,
  Lightbulb,
} from 'lucide-react';
import { Task, Project, TaskPriority } from '../types';
import { CelebrationCheckbox } from '../components/CelebrationCheckbox';

export const AnalyticsScreen: React.FC = () => {
  const {
    tasks,
    projects,
    toggleTaskCompletion,
    navigate,
    setActiveFocusTask,
    setActiveProjectWorkspace,
    focusSessionsCount,
    totalFocusMinutes,
  } = useApp();

  // Timeframe Filter: 'week' | 'month'
  const [timeframe, setTimeframe] = useState<'week' | 'month'>('week');

  // Task Association Filter: 'all' | 'project' | 'standalone'
  const [associationFilter, setAssociationFilter] = useState<'all' | 'project' | 'standalone'>('all');

  // Task Status Filter: 'all' | 'completed' | 'pending' | 'overdue'
  const [statusFilter, setStatusFilter] = useState<'all' | 'completed' | 'pending' | 'overdue'>('all');

  // Search Query
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Selected Project Filter (optional)
  const [selectedProjectId, setSelectedProjectId] = useState<string>('all');

  // Selected Day in GitHub Monthly Heatmap
  const [selectedHeatmapDay, setSelectedHeatmapDay] = useState<number | null>(12);

  // Calculations for current dataset
  const filteredTasks = useMemo(() => {
    return tasks.filter((task) => {
      // 1. Association filter
      if (associationFilter === 'project' && !task.projectId) return false;
      if (associationFilter === 'standalone' && task.projectId) return false;

      // 2. Project filter
      if (selectedProjectId !== 'all' && task.projectId !== selectedProjectId) return false;

      // 3. Status filter
      const isCompleted = task.status === 'completed';
      const isOverdue =
        !isCompleted &&
        Boolean(
          task.timeSlot &&
            (task.timeSlot.includes('البارحة') ||
              task.timeSlot.includes('أمس') ||
              task.timeSlot.includes('فات'))
        );

      if (statusFilter === 'completed' && !isCompleted) return false;
      if (statusFilter === 'pending' && isCompleted) return false;
      if (statusFilter === 'overdue' && !isOverdue) return false;

      // 4. Search query
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase().trim();
        const matchesTitle = task.title.toLowerCase().includes(query);
        const matchesDesc = (task.description || '').toLowerCase().includes(query);
        if (!matchesTitle && !matchesDesc) return false;
      }

      return true;
    });
  }, [tasks, associationFilter, selectedProjectId, statusFilter, searchQuery]);

  // Overall statistics (computed across all tasks or timeframe)
  const stats = useMemo(() => {
    const totalCount = tasks.length;
    const completedTasks = tasks.filter((t) => t.status === 'completed');
    const completedCount = completedTasks.length;
    const pendingTasks = tasks.filter((t) => t.status !== 'completed');
    const pendingCount = pendingTasks.length;

    const overdueTasks = pendingTasks.filter(
      (t) =>
        t.timeSlot &&
        (t.timeSlot.includes('البارحة') ||
          t.timeSlot.includes('أمس') ||
          t.timeSlot.includes('فات'))
    );
    const overdueCount = overdueTasks.length;

    // Remaining estimated minutes
    const remainingMinutes = pendingTasks.reduce(
      (acc, t) => acc + (t.estimatedDurationMinutes || 25),
      0
    );

    // Completed estimated minutes
    const completedMinutes = completedTasks.reduce(
      (acc, t) => acc + (t.actualDurationMinutes || t.estimatedDurationMinutes || 20),
      0
    );

    // Total planned minutes
    const totalMinutes = remainingMinutes + completedMinutes;

    // Completion percentage
    const completionRate = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

    // Tasks with project vs standalone
    const projectTasksCount = tasks.filter((t) => Boolean(t.projectId)).length;
    const standaloneTasksCount = tasks.filter((t) => !t.projectId).length;

    return {
      totalCount,
      completedCount,
      pendingCount,
      overdueCount,
      remainingMinutes,
      completedMinutes,
      totalMinutes,
      completionRate,
      projectTasksCount,
      standaloneTasksCount,
    };
  }, [tasks]);

  // Format minutes into Arabic hours and minutes
  const formatMinutesToArabic = (mins: number) => {
    if (mins <= 0) return '0 دقيقة';
    const hours = Math.floor(mins / 60);
    const remainingMins = mins % 60;

    if (hours === 0) return `${remainingMins} دقيقة`;
    if (remainingMins === 0) {
      if (hours === 1) return 'ساعة واحدة';
      if (hours === 2) return 'ساعتان';
      return `${hours} ساعات`;
    }
    return `${hours} س و ${remainingMins} د`;
  };

  // Day distribution mock data based on timeframe
  const weeklyDays = [
    { day: 'السبت', completed: 2, total: 3, percent: 66 },
    { day: 'الأحد', completed: 3, total: 4, percent: 75 },
    { day: 'الإثنين', completed: 4, total: 5, percent: 80 },
    { day: 'الثلاثاء', completed: 2, total: 2, percent: 100 },
    { day: 'الأربعاء', completed: 1, total: 3, percent: 33 },
    { day: 'الخميس', completed: 3, total: 4, percent: 75 },
    { day: 'الجمعة', completed: 1, total: 1, percent: 100 },
  ];

  // Full Month Days (October 2026 - 31 Days) for GitHub Heatmap
  interface MonthlyDayActivity {
    day: number;
    weekday: string;
    completed: number;
    focusMinutes: number;
    level: 0 | 1 | 2 | 3 | 4;
    isToday: boolean;
    isFuture: boolean;
    tasksSample: string[];
  }

  const monthlyDays: MonthlyDayActivity[] = [
    { day: 1, weekday: 'الخميس', completed: 2, focusMinutes: 50, level: 2, isToday: false, isFuture: false, tasksSample: ['إعداد خطة شهر أكتوبر', 'مراجعة الملاحظات'] },
    { day: 2, weekday: 'الجمعة', completed: 1, focusMinutes: 25, level: 1, isToday: false, isFuture: false, tasksSample: ['قراءة ملخص الأسبوع الهادئ'] },
    { day: 3, weekday: 'السبت', completed: 3, focusMinutes: 75, level: 3, isToday: false, isFuture: false, tasksSample: ['ترتيب مساحة المكتب', 'فرز الأوراق', 'جدولة المواعيد'] },
    { day: 4, weekday: 'الأحد', completed: 4, focusMinutes: 90, level: 3, isToday: false, isFuture: false, tasksSample: ['تطوير البورتفوليو', 'كتابة نبذة الخبرات', 'اختيار الألوان', 'مراجعة التصاميم'] },
    { day: 5, weekday: 'الإثنين', completed: 5, focusMinutes: 125, level: 4, isToday: false, isFuture: false, tasksSample: ['مراجعة تدفق الشات', 'جلسة تركيز 25 دقيقة', 'تقسيم أهداف المشروع', 'مكالمة هادئة', 'توثيق النتائج'] },
    { day: 6, weekday: 'الثلاثاء', completed: 2, focusMinutes: 50, level: 2, isToday: false, isFuture: false, tasksSample: ['تحديث أيقونات التطبيق', 'جلسة بومودورو'] },
    { day: 7, weekday: 'الأربعاء', completed: 0, focusMinutes: 0, level: 0, isToday: false, isFuture: false, tasksSample: [] },
    { day: 8, weekday: 'الخميس', completed: 3, focusMinutes: 70, level: 3, isToday: false, isFuture: false, tasksSample: ['تنظيم ملفات العمل', 'قراءة فصل كتاب التركيز', 'مراجعة اليوم'] },
    { day: 9, weekday: 'الجمعة', completed: 1, focusMinutes: 25, level: 1, isToday: false, isFuture: false, tasksSample: ['استراحة وملاحظات خفيفة'] },
    { day: 10, weekday: 'السبت', completed: 2, focusMinutes: 50, level: 2, isToday: false, isFuture: false, tasksSample: ['تجهيز قائمة المهام', 'مراجعة السكاشن'] },
    { day: 11, weekday: 'الأحد', completed: 3, focusMinutes: 80, level: 3, isToday: false, isFuture: false, tasksSample: ['تحديث ألوان هندلها', 'ضبط الإشعارات الذكية', 'جلسة تركيز'] },
    { day: 12, weekday: 'الإثنين', completed: 3, focusMinutes: 70, level: 3, isToday: true, isFuture: false, tasksSample: ['مراجعة تدفق المهام', 'إعداد جلسة التركيز التفاعلية', 'متابعة المشاريع'] },
    // Days 13 to 31 (Upcoming / Future Days)
    ...Array.from({ length: 19 }, (_, i) => {
      const d = i + 13;
      const weekdays = ['الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد', 'الإثنين'];
      const w = weekdays[i % 7];
      return {
        day: d,
        weekday: w,
        completed: 0,
        focusMinutes: 0,
        level: 0 as const,
        isToday: false,
        isFuture: true,
        tasksSample: [],
      };
    }),
  ];

  // Helper for heatmap square style
  const getHeatmapSquareStyle = (level: 0 | 1 | 2 | 3 | 4, isFuture: boolean) => {
    if (isFuture) {
      return 'bg-[#F4F7F5] dark:bg-[#162320] border-dashed border-[#DEE7E2] dark:border-[#263C36] text-[#8EA09B] opacity-60';
    }
    switch (level) {
      case 4:
        return 'bg-[#194D46] dark:bg-[#72C8B8] text-white dark:text-[#0C1A17] border-[#133F39] dark:border-[#83D5C5] shadow-xs';
      case 3:
        return 'bg-[#2F6F68] dark:bg-[#46A797] text-white dark:text-[#0E1F1C] border-[#255C56] dark:border-[#5CB6A7] shadow-2xs';
      case 2:
        return 'bg-[#64BBAE] dark:bg-[#287266] text-[#0F2D28] dark:text-white border-[#52A99C] dark:border-[#358B7D]';
      case 1:
        return 'bg-[#A8DAD1] dark:bg-[#1E4D44] text-[#16433D] dark:text-[#B5E2DA] border-[#93CBC1] dark:border-[#266358]';
      case 0:
      default:
        return 'bg-[#EBF2EE] dark:bg-[#1A2A26] text-[#6A7E79] dark:text-[#8D9F9B] border-[#DCE6E1] dark:border-[#253934]';
    }
  };

  // Helper to get project info
  const getProjectInfo = (projectId?: string) => {
    if (!projectId) return null;
    return projects.find((p) => p.id === projectId) || null;
  };

  const getPriorityBadge = (priority: TaskPriority) => {
    switch (priority) {
      case 'urgent':
        return { label: 'عاجل جداً', bg: 'bg-[#FDF2F2] dark:bg-[#321E1E] text-[#D25C54] dark:text-[#E88E88]' };
      case 'high':
        return { label: 'أولوية عالية', bg: 'bg-[#FEF7ED] dark:bg-[#342416] text-[#C27803] dark:text-[#EBB366]' };
      case 'medium':
        return { label: 'متوسطة', bg: 'bg-[#EEF5F2] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#76BCAF]' };
      case 'low':
      default:
        return { label: 'هادئة', bg: 'bg-[#F3F4F6] dark:bg-[#202E2B] text-[#6B7280] dark:text-[#9CA3AF]' };
    }
  };

  return (
    <div className="pb-28 pt-4 px-4 sm:px-6 space-y-6">
      {/* Header */}
      <header className="flex items-center justify-between pt-2">
        <div className="flex items-center gap-2">
          <button
            onClick={() => navigate('/home')}
            className="p-2 rounded-xl text-[#576F6A] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white hover:bg-[#EEF5F2] dark:hover:bg-[#1E332E] transition-colors cursor-pointer"
            title="العودة للرئيسية"
          >
            <ArrowRight className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-xl font-bold text-[#1E2D2B] dark:text-white flex items-center gap-2">
              لوحة المتابعة والتحليل
              <span className="text-xs px-2.5 py-0.5 rounded-full bg-[#D9ECE8] dark:bg-[#1F3E37] text-[#235D55] dark:text-[#88C6B9] font-bold">
                تحليل ذكي
              </span>
            </h1>
            <p className="text-xs text-[#5D726D] dark:text-[#9EB2AD]">
              متابعة تقدمك في المشاريع والمهام والوقت المتبقي بكل شفافية
            </p>
          </div>
        </div>

      </header>

      {/* Timeframe Selector (أسبوع أو شهر فقط بدون الإجمالي) */}
      <div className="p-1 rounded-2xl bg-white dark:bg-[#182724] border border-[#DEE7E2] dark:border-[#2B403A] flex items-center shadow-2xs">
        {[
          { id: 'week', label: 'على مدار الأسبوع' },
          { id: 'month', label: 'على مدار الشهر (خريطة الإنجاز)' },
        ].map((tab) => {
          const isActive = timeframe === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setTimeframe(tab.id as 'week' | 'month')}
              className={`flex-1 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer text-center ${
                isActive
                  ? 'bg-[#2F6F68] text-white shadow-xs'
                  : 'text-[#5E736E] dark:text-[#9EB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Smart Egyptian Suggestion Card (اقتراح ذكي بديل للشكل القديم) */}
      <div className="p-4 sm:p-5 rounded-3xl bg-linear-to-br from-[#F5FAF8] via-[#FAFDFB] to-[#FDFBF7] dark:from-[#182C27] dark:via-[#162723] dark:to-[#1E2721] border-2 border-[#D2E7E0] dark:border-[#2C4A42] space-y-3 shadow-xs relative overflow-hidden">
        {/* Soft decorative ambient glow */}
        <div className="absolute top-0 left-0 w-32 h-32 bg-[#2F6F68]/5 dark:bg-[#76BCAF]/10 rounded-full blur-2xl pointer-events-none" />

        {/* Suggestion Header */}
        <div className="flex items-center justify-between relative z-10">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-[#FDF0DE] dark:bg-[#3D2C1B] text-[#B76F1D] dark:text-[#ECC28C] flex items-center justify-center shadow-2xs">
              <Lightbulb className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[11px] font-bold text-[#B76F1D] dark:text-[#ECC28C] block leading-none">
                اقتراح هندلها الذكي
              </span>
              <h3 className="text-xs font-bold text-[#1E2D2B] dark:text-white mt-1">
                {stats.overdueCount > 0
                  ? '💡 تظبيط المهام المتأخرة بدون توتر'
                  : stats.completionRate >= 60
                  ? '🌟 المحافظة على رتم الإنجاز العالي'
                  : '🎯 خطة مقترحة لترتيب أولوياتك اليوم'}
              </h3>
            </div>
          </div>

          <span className="text-[10px] font-bold px-2.5 py-1 rounded-full bg-white/80 dark:bg-black/40 text-[#4E6762] dark:text-[#A1B8B3] border border-[#DEEAE5] dark:border-[#2A3E38]">
            مُقترح الآن
          </span>
        </div>

        {/* Suggestion Body */}
        <p className="text-xs text-[#2B3E3A] dark:text-[#D5E4DF] leading-relaxed relative z-10">
          {stats.completionRate >= 60 ? (
            <>
              <strong>الله ينور عليك يا فنان!</strong> إنت مخلّص{' '}
              <span className="font-bold text-[#235D55] dark:text-[#88C6B9]">
                {stats.completionRate}%
              </span>{' '}
              من المهام وماشي برتم هادئ وممتاز. باقي في حدود{' '}
              <strong>{formatMinutesToArabic(stats.remainingMinutes)}</strong> لتقفيل كل المخطط.. اقتراحنا تاخد بريك قهوة خفيف وتكمل جلسة تركيز قصيرة.
            </>
          ) : stats.overdueCount > 0 ? (
            <>
              <strong>ولا تشيل هم خالص يا بطل،</strong> عندك{' '}
              <span className="text-[#D25C54] font-bold">{stats.overdueCount} مهمة</span> محتاجة تظبيط بسيط لأن ميعادها فات.. اقتراحنا نبدأ بجلسة تركيز واحدة 25 دقيقة نخلص واحدة منهم ونشيل همّها!
            </>
          ) : (
            <>
              <strong>خطوة خطوة وبدون استعجال..</strong> عندك{' '}
              <span className="font-bold">{stats.pendingCount} مهام جارية</span>، بإجمالي وقت متوقع{' '}
              <strong>{formatMinutesToArabic(stats.remainingMinutes)}</strong>. نقترح عليك تختار أهم مهمة فقط وتبدأ فيها فوراً بدون تشتيت.
            </>
          )}
        </p>

        {/* Suggestion Action Buttons */}
        <div className="flex items-center gap-2 pt-1 relative z-10">
          <button
            onClick={() => {
              setActiveFocusTask(
                tasks.find((t) => t.status !== 'completed')?.title || 'جلسة تركيز مقترحة'
              );
              navigate('/focus-session');
            }}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold transition-all shadow-xs cursor-pointer active:scale-95"
          >
            <Play className="w-3.5 h-3.5 fill-current" />
            <span>ابدأ جلسة تركيز مقترحة</span>
          </button>

          <button
            onClick={() => navigate('/tasks')}
            className="flex items-center gap-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#1A2825] border border-[#CFE0DA] dark:border-[#2C423C] text-[#2F6F68] dark:text-[#88C6B9] hover:bg-[#EEF5F2] text-xs font-bold transition-colors cursor-pointer"
          >
            <span>عرض المهام</span>
            <ArrowLeft className="w-3 h-3" />
          </button>
        </div>
      </div>

      {/* Top KPI Cards (بما يشمل عدد جلسات التركيز المكتملة) */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
        {/* KPI 1: Remaining Time */}
        <div className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-1.5 shadow-2xs">
          <div className="flex items-center justify-between text-[#5C726D] dark:text-[#9AB0AB]">
            <span className="text-[11px] font-bold">الوقت المتبقي</span>
            <Clock className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF]" />
          </div>
          <div className="text-lg font-black text-[#1E2D2B] dark:text-white">
            {formatMinutesToArabic(stats.remainingMinutes)}
          </div>
          <div className="text-[10px] text-[#718782] dark:text-[#8E9F9B]">
            من إجمالي {formatMinutesToArabic(stats.totalMinutes)}
          </div>
        </div>

        {/* KPI 2: Completion Rate */}
        <div className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-1.5 shadow-2xs">
          <div className="flex items-center justify-between text-[#5C726D] dark:text-[#9AB0AB]">
            <span className="text-[11px] font-bold">نسبة الإنجاز</span>
            <CheckCircle2 className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF]" />
          </div>
          <div className="text-lg font-black text-[#1E2D2B] dark:text-white">
            {stats.completionRate}%
          </div>
          <div className="text-[10px] text-[#718782] dark:text-[#8E9F9B]">
            {stats.completedCount} من أصل {stats.totalCount} مهمة
          </div>
        </div>

        {/* KPI 3: Focus Sessions (عدد جلسات التركيز المكتملة) */}
        <div className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-1.5 shadow-2xs col-span-2 sm:col-span-1">
          <div className="flex items-center justify-between text-[#5C726D] dark:text-[#9AB0AB]">
            <span className="text-[11px] font-bold">جلسات التركيز</span>
            <Flame className="w-4 h-4 text-[#E26D58] dark:text-[#F28E79]" />
          </div>
          <div className="text-lg font-black text-[#1E2D2B] dark:text-white">
            {focusSessionsCount} جلسات
          </div>
          <div className="text-[10px] text-[#718782] dark:text-[#8E9F9B]">
            {totalFocusMinutes} دقيقة تركيز هادئ
          </div>
        </div>

        {/* KPI 4: Projects Breakdown */}
        <div className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-1.5 shadow-2xs">
          <div className="flex items-center justify-between text-[#5C726D] dark:text-[#9AB0AB]">
            <span className="text-[11px] font-bold">المشاريع النشطة</span>
            <Folder className="w-4 h-4 text-[#3E7092] dark:text-[#8CBEDC]" />
          </div>
          <div className="text-lg font-black text-[#1E2D2B] dark:text-white">
            {projects.length} مشاريع
          </div>
          <div className="text-[10px] text-[#718782] dark:text-[#8E9F9B]">
            {stats.projectTasksCount} مهمة مرتبطة بمشاريع
          </div>
        </div>

        {/* KPI 5: Standalone Tasks */}
        <div className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-1.5 shadow-2xs">
          <div className="flex items-center justify-between text-[#5C726D] dark:text-[#9AB0AB]">
            <span className="text-[11px] font-bold">مهام مستقلة</span>
            <Zap className="w-4 h-4 text-[#D89230] dark:text-[#EBB366]" />
          </div>
          <div className="text-lg font-black text-[#1E2D2B] dark:text-white">
            {stats.standaloneTasksCount} مهمة
          </div>
          <div className="text-[10px] text-[#718782] dark:text-[#8E9F9B]">
            بدون ربط بمشروع معين
          </div>
        </div>
      </div>

      {/* Projects Progress Section */}
      <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-4 shadow-2xs">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Folder className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF]" />
            <h2 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
              تقدم المشاريع والسكاشن
            </h2>
            <span className="text-[11px] font-bold text-[#6D827E] dark:text-[#9EB3AE]">
              ({projects.length})
            </span>
          </div>

          <button
            onClick={() => navigate('/projects')}
            className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline flex items-center gap-1 cursor-pointer"
          >
            <span>كل المشاريع</span>
            <ArrowLeft className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="space-y-3">
          {projects.map((proj) => {
            const projectTasks = tasks.filter((t) => t.projectId === proj.id);
            const pCompleted = projectTasks.filter((t) => t.status === 'completed').length;
            const pTotal = projectTasks.length || (proj.subtasks || []).length;
            const percent = pTotal > 0 ? Math.round((pCompleted / pTotal) * 100) : Math.round((proj.progressPercent || 0) * 100);

            const pRemainingMins = projectTasks
              .filter((t) => t.status !== 'completed')
              .reduce((acc, t) => acc + (t.estimatedDurationMinutes || 25), 0);

            return (
              <div
                key={proj.id}
                onClick={() => {
                  setActiveProjectWorkspace(proj);
                  navigate('/project-workspace');
                }}
                className="p-3.5 rounded-2xl bg-[#F8FAF9] dark:bg-[#152320] border border-[#E3ECE8] dark:border-[#243732] hover:border-[#2F6F68]/40 transition-all cursor-pointer space-y-2 group"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2.5">
                    <div
                      className="w-3 h-3 rounded-full shrink-0"
                      style={{ backgroundColor: proj.accentColor || '#2F6F68' }}
                    />
                    <h3 className="text-xs font-bold text-[#1E2D2B] dark:text-white group-hover:text-[#2F6F68] dark:group-hover:text-[#76BCAF] transition-colors">
                      {proj.title}
                    </h3>
                  </div>

                  <div className="flex items-center gap-2 text-xs">
                    <span className="text-[11px] text-[#637974] dark:text-[#9FB3AE]">
                      {pCompleted}/{pTotal} مهمة
                    </span>
                    <span className="font-bold text-[#1E2D2B] dark:text-white">
                      {percent}%
                    </span>
                  </div>
                </div>

                {/* Progress bar */}
                <div className="w-full h-2 rounded-full bg-[#E5EEEA] dark:bg-[#20332E] overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{
                      width: `${percent}%`,
                      backgroundColor: proj.accentColor || '#2F6F68',
                    }}
                  />
                </div>

                <div className="flex items-center justify-between text-[10px] text-[#697E79] dark:text-[#93A7A2] pt-0.5">
                  <span>
                    الوقت المتوقع المتبقي: <strong>{formatMinutesToArabic(pRemainingMins)}</strong>
                  </span>
                  <span className="text-[#2F6F68] dark:text-[#76BCAF] font-bold flex items-center gap-1 group-hover:translate-x-0.5 transition-transform">
                    فتح مساحة العمل
                    <ArrowLeft className="w-3 h-3" />
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Conditional: Month GitHub Heatmap vs Week Velocity Chart vs All-time Matrix */}
      {timeframe === 'month' ? (
        <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-4 shadow-2xs">
          {/* Section Header */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[#E7EFEA] dark:border-[#253A35]">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-xl bg-[#E8F4F1] dark:bg-[#1E3832] text-[#2F6F68] dark:text-[#88C6B9] flex items-center justify-center shrink-0">
                <Calendar className="w-4 h-4" />
              </div>
              <div>
                <h2 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                  خريطة نشاط وإنجاز الشهر
                </h2>
                <p className="text-xs font-semibold text-[#2F6F68] dark:text-[#76BCAF] mt-0.5">
                  أكتوبر 2026 • 31 يوماً
                </p>
              </div>
            </div>

            {/* GitHub-style Legend Bar (Less -> More) */}
            <div className="flex items-center gap-2 text-xs font-medium text-[#627772] dark:text-[#9DB2AD] whitespace-nowrap shrink-0 self-start sm:self-auto">
              <span className="text-[11px]">أقل</span>
              <div className="flex items-center gap-1">
                <div className="w-3.5 h-3.5 rounded-xs bg-[#EBF2EE] dark:bg-[#1A2A26] border border-[#DCE6E1] dark:border-[#253934]" title="0 مهام" />
                <div className="w-3.5 h-3.5 rounded-xs bg-[#A8DAD1] dark:bg-[#1E4D44] border border-[#93CBC1] dark:border-[#266358]" title="1 مهمة" />
                <div className="w-3.5 h-3.5 rounded-xs bg-[#64BBAE] dark:bg-[#287266] border border-[#52A99C] dark:border-[#358B7D]" title="2 مهام" />
                <div className="w-3.5 h-3.5 rounded-xs bg-[#2F6F68] dark:bg-[#46A797] border border-[#255C56] dark:border-[#5CB6A7]" title="3-4 مهام" />
                <div className="w-3.5 h-3.5 rounded-xs bg-[#194D46] dark:bg-[#72C8B8] border border-[#133F39] dark:border-[#83D5C5]" title="5+ مهام" />
              </div>
              <span className="text-[11px]">أكثر</span>
            </div>
          </div>

          <p className="text-[11px] text-[#637974] dark:text-[#9FB3AE]">
            كل مربع يمثل يوماً في الشهر، ويتلون بتدرج الإنتاجية حسب عدد المهام ودقائق التركيز المنجزة
          </p>

          {/* GitHub Month Heatmap Calendar Grid */}
          <div className="pt-1 space-y-2">
            {/* Weekday Column Headers (Desktop full names, Mobile short names) */}
            <div className="grid grid-cols-7 gap-1 sm:gap-2 text-center text-[10px] font-bold text-[#6D827E] dark:text-[#9FB3AE]">
              <div className="hidden sm:contents">
                {['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'].map((dayName, idx) => (
                  <div key={idx} className="py-1">
                    {dayName}
                  </div>
                ))}
              </div>
              <div className="contents sm:hidden">
                {['سبت', 'أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'].map((dayName, idx) => (
                  <div key={idx} className="py-1 text-[9px]">
                    {dayName}
                  </div>
                ))}
              </div>
            </div>

            {/* Heatmap Squares Grid (42 cells: 5 empty leading + 31 days + 6 empty trailing) */}
            <div className="grid grid-cols-7 gap-1 sm:gap-2">
              {/* 5 Leading Empty Padding Days (October 1 starts on Thursday) */}
              {Array.from({ length: 5 }).map((_, idx) => (
                <div
                  key={`empty-lead-${idx}`}
                  className="aspect-square rounded-xl bg-transparent opacity-20 pointer-events-none"
                />
              ))}

              {/* 31 Month Days */}
              {monthlyDays.map((item) => {
                const isSelected = selectedHeatmapDay === item.day;
                const squareStyle = getHeatmapSquareStyle(item.level, item.isFuture);

                return (
                  <button
                    key={item.day}
                    onClick={() => setSelectedHeatmapDay(item.day)}
                    className={`aspect-square rounded-xl border flex flex-col justify-between p-1 sm:p-2 transition-all cursor-pointer relative group text-right overflow-hidden ${squareStyle} ${
                      isSelected
                        ? 'ring-2 ring-[#2F6F68] dark:ring-[#76BCAF] ring-offset-2 ring-offset-white dark:ring-offset-[#1A2825] scale-105 z-10 shadow-md'
                        : 'hover:scale-102 hover:shadow-xs'
                    } ${
                      item.isToday
                        ? 'ring-2 ring-[#E27D66] dark:ring-[#F29F8D]'
                        : ''
                    }`}
                    title={`يوم ${item.weekday} ${item.day} أكتوبر: ${item.completed} مهام مكتملة`}
                  >
                    {/* Top Row: Day Number & Today indicator */}
                    <div className="flex items-center justify-between w-full">
                      <span className="text-[10px] sm:text-xs font-bold leading-none">
                        {item.day}
                      </span>
                      {item.isToday && (
                        <span className="w-1.5 h-1.5 rounded-full bg-[#E27D66] dark:bg-[#F29F8D] animate-ping shrink-0" />
                      )}
                    </div>

                    {/* Bottom: Task Count Badge or Status */}
                    <div className="w-full flex items-center justify-between text-[8px] sm:text-[9px] font-bold leading-none">
                      {item.completed > 0 ? (
                        <span className="px-1 py-0.5 rounded-xs bg-black/15 dark:bg-black/30">
                          {item.completed}✓
                        </span>
                      ) : item.isFuture ? (
                        <span className="text-[8px] opacity-40">-</span>
                      ) : (
                        <span className="text-[8px] opacity-40">0</span>
                      )}

                      {item.isToday && (
                        <span className="text-[8px] font-bold px-1 py-0.2 rounded-xs bg-[#E27D66] text-white shrink-0">
                          اليوم
                        </span>
                      )}
                    </div>
                  </button>
                );
              })}

              {/* 6 Trailing Empty Cells to complete 6 full rows */}
              {Array.from({ length: 6 }).map((_, idx) => (
                <div
                  key={`empty-trail-${idx}`}
                  className="aspect-square rounded-xl bg-transparent opacity-20 pointer-events-none"
                />
              ))}
            </div>
          </div>

          {/* Interactive Day Details Card */}
          {selectedHeatmapDay && (() => {
            const activeDayData = monthlyDays.find((d) => d.day === selectedHeatmapDay);
            if (!activeDayData) return null;

            return (
              <div className="p-3.5 sm:p-4 rounded-2xl bg-[#F8FAF9] dark:bg-[#152320] border border-[#E3ECE8] dark:border-[#243732] space-y-2.5 animate-in fade-in duration-200">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="w-2.5 h-2.5 rounded-full bg-[#2F6F68] dark:bg-[#76BCAF] shrink-0" />
                    <h4 className="text-xs sm:text-sm font-bold text-[#1E2D2B] dark:text-white flex items-center gap-2 flex-wrap">
                      <span>تفاصيل يوم {activeDayData.weekday} {activeDayData.day} أكتوبر 2026</span>
                      {activeDayData.isToday && (
                        <span className="inline-flex items-center text-[10px] px-2 py-0.5 rounded-md bg-[#E27D66] text-white font-bold whitespace-nowrap shrink-0 shadow-2xs">
                          اليوم الحالي
                        </span>
                      )}
                    </h4>
                  </div>

                  <span className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] whitespace-nowrap self-start sm:self-auto bg-[#E8F4F1] dark:bg-[#1E3832] px-2.5 py-1 rounded-xl">
                    {activeDayData.completed} مهام منجزة • {activeDayData.focusMinutes} دقيقة تركيز
                  </span>
                </div>

                {activeDayData.tasksSample.length > 0 ? (
                  <div className="space-y-1.5 pt-1">
                    <span className="text-[10px] font-bold text-[#6B807B] dark:text-[#98ADA7]">
                      المهام المحققة في هذا اليوم:
                    </span>
                    <div className="flex items-center gap-1.5 flex-wrap">
                      {activeDayData.tasksSample.map((taskName, tIdx) => (
                        <span
                          key={tIdx}
                          className="px-2.5 py-1 rounded-lg bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-xs font-medium text-[#2B3E3A] dark:text-[#D5E4DF] flex items-center gap-1"
                        >
                          <Check className="w-3 h-3 text-[#2F6F68] dark:text-[#76BCAF] stroke-[3]" />
                          <span>{taskName}</span>
                        </span>
                      ))}
                    </div>
                  </div>
                ) : activeDayData.isFuture ? (
                  <p className="text-xs text-[#6B807B] dark:text-[#98ADA7]">
                    يوم قادم في بقية الشهر.. لم تسجل مهام منجزة بعد، يمكنك جدولته وإضافة مهام له الآن.
                  </p>
                ) : (
                  <p className="text-xs text-[#6B807B] dark:text-[#98ADA7]">
                    يوم راحة وهدوء واستجمام بدون مهام مسجلة 🌿
                  </p>
                )}
              </div>
            );
          })()}

          {/* Month High-Level Highlights Bar */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-2 border-t border-[#E3ECE7] dark:border-[#283C37] text-center">
            <div className="p-2 rounded-xl bg-[#F6FAF8] dark:bg-[#152320]">
              <span className="text-[10px] text-[#697E79] dark:text-[#93A7A2] block">أيام الإنجاز</span>
              <span className="text-xs font-bold text-[#1E2D2B] dark:text-white">11 من 12 يوماً</span>
            </div>
            <div className="p-2 rounded-xl bg-[#F6FAF8] dark:bg-[#152320]">
              <span className="text-[10px] text-[#697E79] dark:text-[#93A7A2] block">أعلى يوم إنتاجية</span>
              <span className="text-xs font-bold text-[#235D55] dark:text-[#88C6B9]">5 مهام (الإثنين 5)</span>
            </div>
            <div className="p-2 rounded-xl bg-[#F6FAF8] dark:bg-[#152320]">
              <span className="text-[10px] text-[#697E79] dark:text-[#93A7A2] block">أطول سلسلة استمرار</span>
              <span className="text-xs font-bold text-[#D89230]">5 أيام متتالية 🔥</span>
            </div>
            <div className="p-2 rounded-xl bg-[#F6FAF8] dark:bg-[#152320]">
              <span className="text-[10px] text-[#697E79] dark:text-[#93A7A2] block">ساعات التركيز</span>
              <span className="text-xs font-bold text-[#1E2D2B] dark:text-white">12.5 ساعة</span>
            </div>
          </div>
        </section>
      ) : timeframe === 'week' ? (
        <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-4 shadow-2xs">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <BarChart3 className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF]" />
              <h2 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                توزيع الإنتاجية اليومي على مدار الأسبوع
              </h2>
            </div>
            <span className="text-[10px] text-[#6B807B] dark:text-[#98ADA7]">
              المهام المنجزة يومياً
            </span>
          </div>

          {/* Bar Chart Visualization */}
          <div className="grid grid-cols-7 gap-2 pt-2 pb-1">
            {weeklyDays.map((col, idx) => (
              <div key={idx} className="flex flex-col items-center gap-1.5">
                <span className="text-[10px] font-bold text-[#6D827E] dark:text-[#9FB3AE]">
                  {col.completed}
                </span>
                <div className="w-full bg-[#EDF3F0] dark:bg-[#20312D] h-24 rounded-xl relative flex items-end p-1 overflow-hidden">
                  <div
                    className="w-full rounded-lg bg-linear-to-t from-[#235D55] to-[#398075] dark:from-[#76C6B7] dark:to-[#4EB5A2] transition-all duration-500"
                    style={{ height: `${col.percent}%` }}
                  />
                </div>
                <span className="text-[10px] font-bold text-[#4B5E59] dark:text-[#A7BCB7]">
                  {col.day}
                </span>
              </div>
            ))}
          </div>
        </section>
      ) : (
        /* All-Time Extended GitHub Contribution Heatmap */
        <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-4 shadow-2xs">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <BarChart3 className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF]" />
              <h2 className="text-sm font-bold text-[#1E2D2B] dark:text-white flex items-center gap-2">
                خريطة المساهمات والإنجاز الكلي (GitHub Heatmap)
                <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-[#EEF5F2] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9]">
                  سجل الاستمرارية الكلي
                </span>
              </h2>
            </div>

            <div className="flex items-center gap-2 text-[10px] text-[#6A7F7A] dark:text-[#9FB3AE]">
              <span>أقل نشاط</span>
              <div className="flex items-center gap-1">
                <div className="w-3 h-3 rounded-xs bg-[#EBF2EE] dark:bg-[#1A2A26] border border-[#DCE6E1] dark:border-[#253934]" />
                <div className="w-3 h-3 rounded-xs bg-[#A8DAD1] dark:bg-[#1E4D44] border border-[#93CBC1] dark:border-[#266358]" />
                <div className="w-3 h-3 rounded-xs bg-[#64BBAE] dark:bg-[#287266] border border-[#52A99C] dark:border-[#358B7D]" />
                <div className="w-3 h-3 rounded-xs bg-[#2F6F68] dark:bg-[#46A797] border border-[#255C56] dark:border-[#5CB6A7]" />
                <div className="w-3 h-3 rounded-xs bg-[#194D46] dark:bg-[#72C8B8] border border-[#133F39] dark:border-[#83D5C5]" />
              </div>
              <span>أعلى نشاط</span>
            </div>
          </div>

          {/* Multi-Week Dense Contribution Matrix (like real GitHub contributions) */}
          <div className="overflow-x-auto pb-2 no-scrollbar">
            <div className="flex items-center gap-1.5 min-w-[500px]">
              {Array.from({ length: 14 }).map((_, weekIdx) => (
                <div key={weekIdx} className="flex flex-col gap-1.5 flex-1">
                  {Array.from({ length: 7 }).map((_, dayIdx) => {
                    const seed = (weekIdx * 7 + dayIdx) % 17;
                    const level = seed === 0 ? 0 : seed < 6 ? 1 : seed < 11 ? 2 : seed < 15 ? 3 : (4 as 0 | 1 | 2 | 3 | 4);
                    return (
                      <div
                        key={dayIdx}
                        className={`w-full aspect-square rounded-md border ${getHeatmapSquareStyle(level, false)}`}
                        title={`أسبوع ${weekIdx + 1} - يوم ${dayIdx + 1}: مستوى النشاط ${level}`}
                      />
                    );
                  })}
                </div>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-between text-xs text-[#5D726D] dark:text-[#9EB2AD] pt-1">
            <span>سجل إنجاز متواصل على مدار 14 أسبوعاً</span>
            <span className="font-bold text-[#235D55] dark:text-[#88C6B9]">
              إجمالي 142 مهمة منجزة هذا العام
            </span>
          </div>
        </section>
      )}

      {/* All Tasks Section (سواء كانت مرتبطة بمشروع أو مستقلة) */}
      <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-4 shadow-2xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h2 className="text-sm font-bold text-[#1E2D2B] dark:text-white flex items-center gap-2">
              كل المهام وقائمة المتابعة
              <span className="text-xs px-2 py-0.5 rounded-full bg-[#EEF5F2] dark:bg-[#203530] text-[#2F6F68] dark:text-[#76BCAF] font-bold">
                {filteredTasks.length} مهمة
              </span>
            </h2>
            <p className="text-[11px] text-[#657975] dark:text-[#9DB1AB]">
              عرض تفصيلي لجميع المهام مع حالتها، أوقاتها المقدرة، ومشاريعها
            </p>
          </div>

          {/* Search Box */}
          <div className="relative min-w-[200px]">
            <Search className="w-3.5 h-3.5 absolute right-3 top-2.5 text-[#7B908A]" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="ابحث في المهام..."
              className="w-full pr-8 pl-3 py-1.5 rounded-xl text-xs bg-[#F4F7F6] dark:bg-[#152320] border border-[#DEE7E2] dark:border-[#283C37] text-[#1E2D2B] dark:text-white placeholder-[#859994] focus:outline-hidden focus:border-[#2F6F68]"
            />
          </div>
        </div>

        {/* Filter Chips: Association (All vs Project vs Standalone) */}
        <div className="space-y-2">
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar text-xs">
            <span className="text-[11px] font-bold text-[#6D827E] dark:text-[#9FB3AE] shrink-0 ml-1">
              النوع:
            </span>
            {[
              { id: 'all', label: 'كل المهام (عامة)' },
              { id: 'project', label: 'مهام تابعة لمشاريع' },
              { id: 'standalone', label: 'مهام مستقلة وحرة' },
            ].map((f) => (
              <button
                key={f.id}
                onClick={() => setAssociationFilter(f.id as any)}
                className={`px-3 py-1.5 rounded-xl font-bold transition-all cursor-pointer shrink-0 ${
                  associationFilter === f.id
                    ? 'bg-[#2F6F68] text-white shadow-2xs'
                    : 'bg-[#F2F6F4] dark:bg-[#182825] text-[#556965] dark:text-[#9FB3AE] hover:bg-[#E5ECE9]'
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>

          {/* Status Filter Chips */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar text-xs">
            <span className="text-[11px] font-bold text-[#6D827E] dark:text-[#9FB3AE] shrink-0 ml-1">
              الحالة:
            </span>
            {[
              { id: 'all', label: 'الكل' },
              { id: 'pending', label: 'الجارية والمتبقية' },
              { id: 'completed', label: 'المكتملة' },
              { id: 'overdue', label: 'المتأخرة' },
            ].map((s) => (
              <button
                key={s.id}
                onClick={() => setStatusFilter(s.id as any)}
                className={`px-3 py-1 rounded-lg text-[11px] font-bold transition-all cursor-pointer shrink-0 ${
                  statusFilter === s.id
                    ? 'bg-[#1E2D2B] text-white dark:bg-white dark:text-[#101A18]'
                    : 'bg-white dark:bg-[#1B2A27] text-[#697E7A] dark:text-[#9FB3AE] border border-[#DEE7E2] dark:border-[#2C413B]'
                }`}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>

        {/* Tasks List Table / Cards */}
        <div className="space-y-2.5 pt-1">
          {filteredTasks.length === 0 ? (
            <div className="p-8 rounded-2xl bg-[#F8FAF9] dark:bg-[#152320] border border-dashed border-[#DEE7E2] dark:border-[#283C37] text-center space-y-2">
              <CheckCircle2 className="w-8 h-8 text-[#A0B4AE] mx-auto stroke-[1.5]" />
              <p className="text-xs text-[#6A7E7A] dark:text-[#9FB3AE]">
                لا توجد مهام تطابق هذا الفلتر
              </p>
            </div>
          ) : (
            filteredTasks.map((task) => {
              const isCompleted = task.status === 'completed';
              const proj = getProjectInfo(task.projectId);
              const priorityBadge = getPriorityBadge(task.priority);
              const isOverdue =
                !isCompleted &&
                Boolean(
                  task.timeSlot &&
                    (task.timeSlot.includes('البارحة') ||
                      task.timeSlot.includes('أمس') ||
                      task.timeSlot.includes('فات'))
                );

              return (
                <div
                  key={task.id}
                  className={`p-3.5 rounded-2xl border transition-all flex items-start justify-between gap-3 ${
                    isCompleted
                      ? 'bg-[#F9FCFA] dark:bg-[#152320]/60 border-[#E1ECE7] dark:border-[#20312D] opacity-75'
                      : 'bg-[#FCFDFC] dark:bg-[#172724] border-[#E3ECE8] dark:border-[#263C36] hover:border-[#2F6F68]/40 shadow-2xs'
                  }`}
                >
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <div className="pt-0.5">
                      <CelebrationCheckbox
                        checked={isCompleted}
                        onChange={() => toggleTaskCompletion(task.id)}
                      />
                    </div>

                    <div className="flex-1 min-w-0 space-y-1.5">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h4
                          className={`text-xs font-bold leading-snug ${
                            isCompleted
                              ? 'line-through text-[#7A8E89] dark:text-[#7A8E89]'
                              : 'text-[#1E2D2B] dark:text-white'
                          }`}
                        >
                          {task.title}
                        </h4>

                        {/* Project Badge vs Standalone Badge */}
                        {proj ? (
                          <span
                            className="text-[10px] px-2 py-0.5 rounded-full font-bold flex items-center gap-1 text-white shrink-0"
                            style={{ backgroundColor: proj.accentColor || '#2F6F68' }}
                          >
                            <Folder className="w-2.5 h-2.5" />
                            {proj.title}
                          </span>
                        ) : (
                          <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-[#EAEFF2] dark:bg-[#203239] text-[#476778] dark:text-[#90B5CA] flex items-center gap-1 shrink-0">
                            <Zap className="w-2.5 h-2.5" />
                            مهمة مستقلة
                          </span>
                        )}

                        {/* Priority Badge */}
                        <span
                          className={`text-[9px] px-1.5 py-0.5 rounded-md font-bold ${priorityBadge.bg}`}
                        >
                          {priorityBadge.label}
                        </span>

                        {isOverdue && (
                          <span className="text-[9px] px-1.5 py-0.5 rounded-md font-bold bg-[#FDF2F2] text-[#D25C54]">
                            متأخرة
                          </span>
                        )}
                      </div>

                      {task.description && (
                        <p className="text-[11px] text-[#637974] dark:text-[#9FB3AE] line-clamp-1">
                          {task.description}
                        </p>
                      )}

                      {/* Time Details & Metadata */}
                      <div className="flex items-center gap-3 text-[10px] text-[#6D827E] dark:text-[#92A7A2] pt-0.5">
                        <span className="flex items-center gap-1">
                          <Clock className="w-3 h-3 text-[#2F6F68] dark:text-[#76BCAF]" />
                          الوقت المتوقع: <strong>{task.estimatedDurationMinutes || 25} دقيقة</strong>
                        </span>

                        {task.actualDurationMinutes && (
                          <span>
                            المستهلك: <strong>{task.actualDurationMinutes} دقيقة</strong>
                          </span>
                        )}

                        {task.timeSlot && (
                          <span className="flex items-center gap-1">
                            <Calendar className="w-3 h-3" />
                            {task.timeSlot}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Actions for task */}
                  {!isCompleted && (
                    <button
                      onClick={() => {
                        setActiveFocusTask(task.title);
                        navigate('/focus-session');
                      }}
                      className="px-2.5 py-1.5 rounded-xl bg-[#EEF5F2] dark:bg-[#1E332E] text-[#2F6F68] dark:text-[#88C6B9] hover:bg-[#2F6F68] hover:text-white transition-all text-[11px] font-bold flex items-center gap-1 cursor-pointer shrink-0 shadow-2xs"
                      title="بدء جلسة تركيز لهذه المهمة"
                    >
                      <Play className="w-3 h-3 fill-current" />
                      <span>تركيز</span>
                    </button>
                  )}
                </div>
              );
            })
          )}
        </div>
      </section>

      {/* Floating Focus Callout */}
      <div className="p-4 rounded-3xl bg-[#235D55] text-white flex items-center justify-between gap-4 shadow-lg">
        <div className="space-y-0.5">
          <h3 className="text-xs font-bold flex items-center gap-1.5">
            <Flame className="w-4 h-4 text-[#F5C78E]" />
            جاهز تنجز جزء من الوقت المتبقي؟
          </h3>
          <p className="text-[11px] text-[#D0E5DF]">
            جلسة بومودورو 25 دقيقة هتفرق جداً في تقدمك الإجمالي اليوم!
          </p>
        </div>

        <button
          onClick={() => {
            const firstPending = tasks.find((t) => t.status !== 'completed');
            if (firstPending) setActiveFocusTask(firstPending.title);
            navigate('/focus-session');
          }}
          className="px-4 py-2 rounded-2xl bg-white text-[#235D55] font-bold text-xs hover:bg-[#F2F7F5] transition-all cursor-pointer shrink-0 shadow-xs"
        >
          ابدأ الجلسة
        </button>
      </div>
    </div>
  );
};
