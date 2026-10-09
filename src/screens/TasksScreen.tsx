import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { CelebrationCheckbox } from '../components/CelebrationCheckbox';
import {
  Search,
  Plus,
  Check,
  Calendar,
  Clock,
  Flag,
  Inbox,
  FileCheck2,
  X,
  Trash2,
  Sparkles,
  Play,
  Filter,
  Pencil,
} from 'lucide-react';
import { Task, TaskPriority, TaskStatus } from '../types';
import { formatEgyptianFullDeadline } from '../utils/taskParser';
import { EditTaskModal } from '../components/EditTaskModal';

export const TasksScreen: React.FC = () => {
  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const {
    tasks,
    toggleTaskCompletion,
    deleteTask,
    setIsQuickAddOpen,
    setIsSmartAddOpen,
    setActiveFocusTask,
    navigate,
  } = useApp();

  const [activeFilter, setActiveFilter] = useState<'all' | 'planned' | 'inbox' | 'completed'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const filterTabs = [
    { key: 'all', label: 'الكل' },
    { key: 'planned', label: 'المجدولة' },
    { key: 'inbox', label: 'صندوق الوارد' },
    { key: 'completed', label: 'المنجزة' },
  ] as const;

  const filteredTasks = tasks.filter((t) => {
    // Search query filter
    if (searchQuery.trim()) {
      const matchTitle = t.title.toLowerCase().includes(searchQuery.toLowerCase());
      const matchDesc = t.description?.toLowerCase().includes(searchQuery.toLowerCase());
      if (!matchTitle && !matchDesc) return false;
    }

    // Status filter
    if (activeFilter === 'planned') {
      return t.status === 'planned' || t.status === 'inProgress';
    }
    if (activeFilter === 'inbox') {
      return t.status === 'inbox';
    }
    if (activeFilter === 'completed') {
      return t.status === 'completed';
    }
    return true;
  });

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

  const startFocus = (taskTitle: string) => {
    setActiveFocusTask(taskTitle);
    navigate('/focus-session');
  };

  return (
    <div className="pb-28 pt-4 px-4 sm:px-6 space-y-5">
      {/* Header */}
      <header className="flex items-center justify-between pt-2">
        <div>
          <h1 className="text-2xl font-bold text-[#1E2D2B] dark:text-white">مهامك</h1>
          <p className="text-xs text-[#627773] dark:text-[#97AEA8]">
            خطوات صغيرة تصنع فرقاً كبيراً في يومك
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsSmartAddOpen(true)}
            className="p-2.5 rounded-2xl bg-[#EAF5F2] dark:bg-[#203D37] text-[#2F6F68] dark:text-[#8AD3C4] border border-[#CCE2DC] dark:border-[#2C524A] hover:bg-[#D9ECE8] transition-colors cursor-pointer flex items-center gap-1.5 text-xs font-bold"
            title="إضافة ذكية"
          >
            <Sparkles className="w-4 h-4" />
            <span>ذكية</span>
          </button>

          <button
            onClick={() => setIsQuickAddOpen(true)}
            className="p-2.5 rounded-2xl bg-[#2F6F68] text-white hover:bg-[#245650] shadow-sm transition-all cursor-pointer flex items-center gap-1.5 text-xs font-bold active:scale-95"
          >
            <Plus className="w-4 h-4" />
            <span>مهمة جديدة</span>
          </button>
        </div>
      </header>

      {/* Search Input */}
      <div className="relative">
        <div className="absolute inset-y-0 right-0 pr-3.5 flex items-center pointer-events-none text-[#758B86] dark:text-[#8FA5A0]">
          <Search className="w-4 h-4" />
        </div>
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="ابحث في مهامك أو تفاصيلها..."
          className="w-full pr-10 pl-9 py-2.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-sm text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] dark:placeholder-[#6C817D] focus:outline-hidden focus:border-[#2F6F68] dark:focus:border-[#76BCAF] transition-all"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery('')}
            className="absolute inset-y-0 left-0 pl-3 flex items-center text-[#758B86] hover:text-[#1E2D2B] dark:hover:text-white cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Filter Tabs */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
        {filterTabs.map((tab) => {
          const isActive = activeFilter === tab.key;
          return (
            <button
              key={tab.key}
              onClick={() => setActiveFilter(tab.key)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all cursor-pointer ${
                isActive
                  ? 'bg-[#2F6F68] text-white shadow-xs'
                  : 'bg-white dark:bg-[#1A2825] text-[#5B6F6B] dark:text-[#99AFA9] border border-[#DEE7E2] dark:border-[#283C37] hover:bg-[#F2F7F5] dark:hover:bg-[#223631]'
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Task List */}
      <div className="space-y-3">
        {filteredTasks.length === 0 ? (
          <div className="p-10 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#E1ECE7] dark:border-[#263A35] text-center space-y-3">
            <div className="w-14 h-14 mx-auto rounded-2xl bg-[#EEF5F2] dark:bg-[#203631] text-[#2F6F68] dark:text-[#86C9BD] flex items-center justify-center">
              <FileCheck2 className="w-7 h-7 stroke-[1.5]" />
            </div>
            <div className="space-y-1">
              <h3 className="text-base font-bold text-[#1E2D2B] dark:text-white">
                مفيش مهام في هذا التصنيف حالياً
              </h3>
              <p className="text-xs text-[#6A7E7A] dark:text-[#9CB0AC] max-w-xs mx-auto">
                تقدر تضيف مهمة جديدة الآن، أو تستخدم المساعد الذكي لتقسيم أي فكرة خطوة بخطوة.
              </p>
            </div>
            <button
              onClick={() => setIsQuickAddOpen(true)}
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-[#2F6F68] text-white text-xs font-bold hover:bg-[#245650] transition-colors cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              أضف مهمة
            </button>
          </div>
        ) : (
          filteredTasks.map((task) => {
            const isCompleted = task.status === 'completed';
            const badge = getPriorityBadge(task.priority);

            return (
              <div
                key={task.id}
                className={`p-4 rounded-3xl border transition-all ${
                  isCompleted
                    ? 'bg-[#F2F6F4] dark:bg-[#152320] border-[#DFECE6] dark:border-[#22332F] opacity-75'
                    : 'bg-white dark:bg-[#1A2825] border-[#DFE9E4] dark:border-[#283C37] shadow-2xs hover:border-[#2F6F68]/30'
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <CelebrationCheckbox
                      checked={isCompleted}
                      onChange={() => toggleTaskCompletion(task.id)}
                      size="md"
                      celebrationIntensity="subtle"
                      ariaLabel={task.title}
                      className="mt-0.5"
                    />

                    <div
                      className="min-w-0 flex-1 space-y-1 cursor-pointer select-none"
                      onClick={() => setEditingTask(task)}
                      title="انقر لتعديل المهمة"
                    >
                      <h3
                        className={`text-sm font-bold leading-snug hover:text-[#2F6F68] transition-colors ${
                          isCompleted
                            ? 'line-through text-[#798D88] dark:text-[#7C918C]'
                            : 'text-[#1E2D2B] dark:text-[#E7F0ED]'
                        }`}
                      >
                        {task.title}
                      </h3>

                      {task.description && (
                        <p className="text-xs text-[#6A7E7A] dark:text-[#99AEA9] leading-relaxed line-clamp-2">
                          {task.description}
                        </p>
                      )}

                      {/* Meta chips */}
                      <div className="flex flex-wrap items-center gap-2 pt-1.5 text-[11px] text-[#697E7A] dark:text-[#9AB1AC]">
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md ${badge.bg}`}>
                          {badge.label}
                        </span>

                        {(task.timeSlot || task.dueAt) && (
                          <span className="flex items-center gap-1 text-[#8A5A1B] dark:text-[#E8BD7C] bg-[#FDF5E6] dark:bg-[#322818] px-2 py-0.5 rounded-md font-semibold text-[10px] border border-[#F4E3C1] dark:border-[#4B3B22]">
                            <Calendar className="w-3 h-3" />
                            <span>الديدلاين: {task.timeSlot || formatEgyptianFullDeadline(task.dueAt)}</span>
                          </span>
                        )}

                        <span className="flex items-center gap-1 font-medium">
                          <Clock className="w-3 h-3 text-[#2F6F68] dark:text-[#88C6B9]" />
                          <span>{task.estimatedDurationMinutes || 25} دقيقة</span>
                        </span>

                        {task.source === 'chat' && (
                          <span className="px-1.5 py-0.5 rounded-md bg-[#E8F3EE] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9] font-medium text-[10px]">
                            عبر المساعد ✨
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-1 shrink-0">
                    <button
                      onClick={() => setEditingTask(task)}
                      className="p-2 rounded-xl text-[#576F6A] dark:text-[#A0B5B0] hover:text-[#2F6F68] hover:bg-[#EEF5F2] dark:hover:bg-[#253D37] transition-colors cursor-pointer"
                      title="تعديل المهمة"
                    >
                      <Pencil className="w-4 h-4" />
                    </button>

                    {!isCompleted && (
                      <button
                        onClick={() => startFocus(task.title)}
                        className="p-2 rounded-xl text-[#576F6A] dark:text-[#A0B5B0] hover:text-[#2F6F68] hover:bg-[#EEF5F2] dark:hover:bg-[#253D37] transition-colors cursor-pointer"
                        title="بدء جلسة تركيز"
                      >
                        <Play className="w-4 h-4 fill-current" />
                      </button>
                    )}

                    <button
                      onClick={() => deleteTask(task.id)}
                      className="p-2 rounded-xl text-[#8E9F9B] hover:text-[#C64545] hover:bg-[#FDF1F0] dark:hover:bg-[#3B1F20] transition-colors cursor-pointer"
                      title="حذف المهمة"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Edit Task Modal */}
      <EditTaskModal
        task={editingTask}
        isOpen={Boolean(editingTask)}
        onClose={() => setEditingTask(null)}
      />
    </div>
  );
};
