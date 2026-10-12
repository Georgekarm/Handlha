import React from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaLogo } from '../components/HandelhaBrand';
import { CelebrationCheckbox } from '../components/CelebrationCheckbox';
import {
  Bell,
  Play,
  FolderOpen,
  Calendar,
  ChevronLeft,
  Plus,
  Pencil,
  BarChart3,
} from 'lucide-react';
import { Task, TaskPriority } from '../types';
import { formatEgyptianFullDeadline } from '../utils/taskParser';
import { EditTaskModal } from '../components/EditTaskModal';

export const DashboardScreen: React.FC = () => {
  const [editingTask, setEditingTask] = React.useState<Task | null>(null);
  const {
    user,
    tasks,
    projects,
    notifications,
    toggleTaskCompletion,
    navigate,
    setIsQuickAddOpen,
    setIsNewProjectOpen,
    setActiveFocusTask,
    setActiveProjectWorkspace,
  } = useApp();

  const unreadCount = notifications.filter(n => !n.isRead).length;

  const todayTasks = tasks.filter(t => t.status !== 'cancelled');
  const completedToday = todayTasks.filter(t => t.status === 'completed').length;
  const progressRatio = todayTasks.length > 0 ? completedToday / todayTasks.length : 0;
  const progressPercent = Math.round(progressRatio * 100);

  // Dynamic time-based greeting
  const currentHour = new Date().getHours();
  const timeGreeting = currentHour >= 5 && currentHour < 12 ? 'صباح النور' : 'مساء الخير';

  // Focus candidate task (first uncompleted task)
  const focusTask = todayTasks.find(t => t.status !== 'completed');

  const getPriorityBadge = (p: TaskPriority) => {
    switch (p) {
      case 'urgent':
        return { label: 'عاجل', bg: 'bg-[#FBE8E6] text-[#B83A3A] dark:bg-[#462020] dark:text-[#F39F9F]' };
      case 'high':
        return { label: 'أولوية عالية', bg: 'bg-[#FDF0DE] text-[#B76F1D] dark:bg-[#3D2C1B] dark:text-[#ECC28C]' };
      case 'medium':
        return { label: 'متوسط', bg: 'bg-[#EEF3F0] text-[#2F6F68] dark:bg-[#1E332E] dark:text-[#88C6B9]' };
      case 'low':
      default:
        return { label: 'هادئ', bg: 'bg-[#EBF3F8] text-[#3E7092] dark:bg-[#1A2C38] dark:text-[#88BCD8]' };
    }
  };

  const startFocusSessionFor = (taskTitle: string) => {
    setActiveFocusTask(taskTitle);
    navigate('/focus-session');
  };

  const openProject = (project: any) => {
    setActiveProjectWorkspace(project);
    navigate('/project-workspace');
  };

  return (
    <div className="pb-28 pt-4 px-4 sm:px-6 space-y-6 max-w-xl mx-auto">
      {/* Top Header */}
      <header className="flex items-center justify-between pt-1">
        <HandelhaLogo subtitle="خطوات هادية، وإنجاز أكيد" />

        <div className="flex items-center gap-2">


          {/* Notifications Button */}
          <button
            onClick={() => navigate('/notifications')}
            className="relative p-2.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#E3ECE8] dark:border-[#2C403B] text-[#556965] dark:text-[#AFC1BC] hover:text-[#245650] dark:hover:text-white transition-colors cursor-pointer"
            title="التنبيهات"
          >
            <Bell className="w-5 h-5" />
            {unreadCount > 0 && (
              <span className="absolute top-1.5 right-1.5 w-2.5 h-2.5 bg-[#D25C54] rounded-full ring-2 ring-white dark:ring-[#1A2825]" />
            )}
          </button>

          {/* Profile / Settings Button */}
          <button
            onClick={() => navigate('/settings')}
            className="p-2 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#E3ECE8] dark:border-[#2C403B] text-[#556965] dark:text-[#AFC1BC] hover:text-[#245650] dark:hover:text-white transition-colors cursor-pointer flex items-center gap-1.5"
            title="الإعدادات"
          >
            <div className="w-6 h-6 rounded-full bg-[#D9ECE8] dark:bg-[#254B44] text-[#2F6F68] dark:text-[#8FD0C3] flex items-center justify-center text-xs font-bold">
              {user?.displayName ? user.displayName.charAt(0) : 'أ'}
            </div>
          </button>
        </div>
      </header>

      {/* Calm Greeting Card */}
      <div className="relative overflow-hidden rounded-3xl bg-linear-to-l from-[#2F6F68] to-[#245650] text-white p-6 shadow-sm">
        {/* Soft background glow */}
        <div className="absolute -top-12 -left-12 w-48 h-48 bg-white/10 rounded-full blur-2xl pointer-events-none" />
        <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-[#4E9B77]/20 rounded-full blur-xl pointer-events-none" />

        <div className="relative z-10 space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold px-3 py-1 rounded-full bg-white/15 backdrop-blur-xs text-[#E1F3EE] flex items-center gap-1.5">
              <Calendar className="w-3.5 h-3.5" />
              اليوم المنظم
            </span>
            <span className="text-xs text-white/80">
              {new Date().toLocaleDateString('ar-EG', { weekday: 'long', day: 'numeric', month: 'long' })}
            </span>
          </div>

          <div>
            <h1 className="text-2xl font-bold tracking-tight text-white mb-1">
              {timeGreeting}، {user?.displayName || 'صديقي'} ✨
            </h1>
            <p className="text-sm text-[#D7ECE7] leading-relaxed">
              خطة اليوم هادية وموزونة. خطوة واحدة في كل مرة بتفرق في هدوء بالك وإنجازك.
            </p>
          </div>

          {/* Calm Daily Progress */}
          <div className="pt-2">
            <div className="flex justify-between items-center text-xs font-medium text-[#E1F3EE] mb-2">
              <span>إنجاز اليوم: {completedToday} من {todayTasks.length} مهام</span>
              <span className="font-bold">{progressPercent}%</span>
            </div>
            <div className="w-full h-2.5 bg-black/20 rounded-full overflow-hidden p-0.5">
              <div
                className="h-full bg-linear-to-r from-[#81CDBF] to-[#E3F4EF] rounded-full transition-all duration-500 ease-out"
                style={{ width: `${progressPercent}%` }}
              />
            </div>

            {/* Quick Analytics Link */}
            <div className="pt-2 flex items-center justify-between">
              <button
                onClick={() => navigate('/analytics')}
                className="text-[11px] font-bold text-[#E1F3EE] hover:text-white flex items-center gap-1.5 cursor-pointer hover:underline"
              >
                <BarChart3 className="w-3.5 h-3.5" />
                <span>عرض تقرير المتابعة، تقدم المشاريع والوقت المتبقي</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* The Next Calm Focus Step */}
      {focusTask && (
        <section className="space-y-2.5">
          <div className="flex items-center justify-between">
            <h2 className="text-xs font-bold text-[#4B635F] dark:text-[#A7BCB7] flex items-center gap-1.5 uppercase tracking-wide">
              <span className="w-2 h-2 rounded-full bg-[#2F6F68] dark:bg-[#77BCB0] animate-pulse" />
              الخطوة التالية الموصى بها
            </h2>
            <button
              onClick={() => startFocusSessionFor(focusTask.title)}
              className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline flex items-center gap-1 cursor-pointer"
            >
              جلسة تركيز
              <ChevronLeft className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DFEAE5] dark:border-[#2A3E39] shadow-xs hover:border-[#2F6F68]/40 transition-all">
            <div className="flex items-start justify-between gap-3">
              <div className="space-y-1.5 flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md ${getPriorityBadge(focusTask.priority).bg}`}>
                    {getPriorityBadge(focusTask.priority).label}
                  </span>
                  {(focusTask.timeSlot || focusTask.dueAt) && (
                    <span className="text-[11px] text-[#8A5A1B] dark:text-[#E8BD7C] bg-[#FDF5E6] dark:bg-[#322818] px-2 py-0.5 rounded-md font-semibold flex items-center gap-1 border border-[#F4E3C1] dark:border-[#4B3B22]">
                      <Calendar className="w-3 h-3" />
                      <span>{focusTask.timeSlot || formatEgyptianFullDeadline(focusTask.dueAt)}</span>
                    </span>
                  )}
                </div>

                <h3 className="text-base font-bold text-[#1E2D2B] dark:text-white truncate">
                  {focusTask.title}
                </h3>
                {focusTask.description && (
                  <p className="text-xs text-[#627773] dark:text-[#98ADA7] leading-relaxed line-clamp-2">
                    {focusTask.description}
                  </p>
                )}
              </div>

              <button
                onClick={() => startFocusSessionFor(focusTask.title)}
                className="shrink-0 px-4 py-2.5 rounded-2xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold flex items-center gap-1.5 shadow-sm hover:shadow transition-all cursor-pointer active:scale-95"
              >
                <Play className="w-3.5 h-3.5 fill-current" />
                ابدأ (٢٥ د)
              </button>
            </div>
          </div>
        </section>
      )}

      {/* Today's Tasks List */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h2 className="text-base font-bold text-[#1E2D2B] dark:text-white">
              مهام اليوم المجدولة
            </h2>
            <span className="text-xs px-2 py-0.5 rounded-full bg-[#E5EFEA] dark:bg-[#203933] text-[#2F6F68] dark:text-[#88C6B9] font-bold">
              {todayTasks.length}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setIsQuickAddOpen(true)}
              className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline flex items-center gap-1 cursor-pointer"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>مهمة جديدة</span>
            </button>
            <span className="text-[#B9CAC4] dark:text-[#38514A]">•</span>
            <button
              onClick={() => navigate('/tasks')}
              className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline flex items-center gap-1 cursor-pointer"
            >
              عرض الكل
              <ChevronLeft className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        <div className="space-y-2.5">
          {todayTasks.length === 0 ? (
            <div className="p-6 rounded-3xl bg-white dark:bg-[#1A2825] border border-dashed border-[#CFDDD7] dark:border-[#2B403A] text-center space-y-2">
              <p className="text-sm font-semibold text-[#3A534E] dark:text-[#A7BCB7]">
                مفيش مهام مجدولة لليوم حتى الآن 🌿
              </p>
              <p className="text-xs text-[#708580] dark:text-[#8D9F9B]">
                يومك رايق وهادي، تقدر تبدأ بإضافة مهمة جديدة وتحديد خواصها بكل هدوء
              </p>
              <button
                onClick={() => setIsQuickAddOpen(true)}
                className="mt-2 inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-[#235D55] text-white text-xs font-bold hover:bg-[#1C4B45] transition-all cursor-pointer shadow-xs"
              >
                <Plus className="w-4 h-4" />
                <span>إضافة مهمة جديدة</span>
              </button>
            </div>
          ) : (
            todayTasks.slice(0, 4).map((task) => {
              const isCompleted = task.status === 'completed';
              const badge = getPriorityBadge(task.priority);

              return (
                <div
                  key={task.id}
                  className={`flex items-center justify-between p-3.5 rounded-2xl border transition-all ${
                    isCompleted
                      ? 'bg-[#F2F6F4] dark:bg-[#15221F] border-[#E1ECE6] dark:border-[#22332F] opacity-75'
                      : 'bg-white dark:bg-[#1A2825] border-[#DFE9E4] dark:border-[#283C37] shadow-2xs hover:border-[#2F6F68]/30'
                  }`}
                >
                  <div className="flex items-center gap-3 flex-1 min-w-0">
                    <CelebrationCheckbox
                      checked={isCompleted}
                      onChange={() => toggleTaskCompletion(task.id)}
                      size="md"
                      celebrationIntensity="subtle"
                      ariaLabel={task.title}
                    />

                    <div
                      className="min-w-0 flex-1 cursor-pointer select-none"
                      onClick={() => setEditingTask(task)}
                      title="انقر لتعديل المهمة"
                    >
                      <p
                        className={`text-sm font-semibold truncate hover:text-[#2F6F68] transition-colors ${
                          isCompleted
                            ? 'line-through text-[#798D88] dark:text-[#7C918C]'
                            : 'text-[#1E2D2B] dark:text-[#E7F0ED]'
                        }`}
                      >
                        {task.title}
                      </p>
                      <div className="flex items-center gap-2 mt-0.5 text-[11px] text-[#697E7A] dark:text-[#9AB1AC]">
                        {(task.timeSlot || task.dueAt) && (
                          <span className="flex items-center gap-1 text-[#8A5A1B] dark:text-[#E8BD7C] font-semibold">
                            <Calendar className="w-3 h-3" />
                            <span>{task.timeSlot || formatEgyptianFullDeadline(task.dueAt)}</span>
                          </span>
                        )}
                        <span>• {task.estimatedDurationMinutes || 25} دقيقة</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5 shrink-0 pr-2">
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md ${badge.bg}`}>
                      {badge.label}
                    </span>
                    <button
                      onClick={() => setEditingTask(task)}
                      className="p-1.5 rounded-lg text-[#657C77] hover:text-[#2F6F68] hover:bg-[#EEF5F2] dark:hover:bg-[#253D37] transition-colors cursor-pointer"
                      title="تعديل المهمة"
                    >
                      <Pencil className="w-3.5 h-3.5" />
                    </button>
                    {!isCompleted && (
                      <button
                        onClick={() => startFocusSessionFor(task.title)}
                        className="p-1.5 rounded-lg text-[#657C77] hover:text-[#2F6F68] hover:bg-[#EEF5F2] dark:hover:bg-[#253D37] transition-colors cursor-pointer"
                        title="جلسة تركيز"
                      >
                        <Play className="w-3.5 h-3.5 fill-current" />
                      </button>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </section>

      {/* Active Projects / Sections */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h2 className="text-base font-bold text-[#1E2D2B] dark:text-white">
              مشاريعك الحالية
            </h2>
            <span className="text-xs px-2 py-0.5 rounded-full bg-[#E5EFEA] dark:bg-[#203933] text-[#2F6F68] dark:text-[#88C6B9] font-bold">
              {projects.length}
            </span>
          </div>

          <button
            onClick={() => navigate('/projects')}
            className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline flex items-center gap-1 cursor-pointer"
          >
            عرض الكل
            <ChevronLeft className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {projects.slice(0, 2).map((proj) => {
            const pct = Math.round(proj.progressPercent * 100);

            return (
              <div
                key={proj.id}
                onClick={() => openProject(proj)}
                className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#273B36] hover:border-[#2F6F68] transition-all cursor-pointer group shadow-2xs"
              >
                <div className="flex items-start justify-between mb-3">
                  <div
                    className="w-9 h-9 rounded-xl flex items-center justify-center text-white"
                    style={{ backgroundColor: proj.accentColor || '#2F6F68' }}
                  >
                    <FolderOpen className="w-4 h-4" />
                  </div>
                  <span className="text-xs font-bold text-[#4B615D] dark:text-[#A1B8B3]">
                    %{pct}
                  </span>
                </div>

                <h3 className="text-sm font-bold text-[#1E2D2B] dark:text-white mb-1 group-hover:text-[#2F6F68] dark:group-hover:text-[#77BCB0] transition-colors">
                  {proj.title}
                </h3>
                <p className="text-xs text-[#6B807B] dark:text-[#95ABA5] line-clamp-2 leading-relaxed mb-3">
                  {proj.description}
                </p>

                {/* Progress bar */}
                <div className="w-full h-1.5 bg-[#EDF3F0] dark:bg-[#253935] rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all"
                    style={{
                      width: `${pct}%`,
                      backgroundColor: proj.accentColor || '#2F6F68',
                    }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Edit Task Modal */}
      <EditTaskModal
        task={editingTask}
        isOpen={Boolean(editingTask)}
        onClose={() => setEditingTask(null)}
      />
    </div>
  );
};
