import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  ArrowRight,
  MoreHorizontal,
  Plus,
  Sparkles,
  CheckCircle2,
  Check,
  Clock,
  Play,
  Calendar,
  Layers,
  BarChart3,
  ChevronLeft,
  Trash2,
} from 'lucide-react';
import { Task, TaskPriority } from '../types';

export const ProjectWorkspaceScreen: React.FC = () => {
  const {
    activeProjectWorkspace,
    updateProject,
    tasks,
    createTask,
    toggleTaskCompletion,
    setActiveFocusTask,
    setIsAiBreakdownOpen,
    navigate,
  } = useApp();

  const [activeTab, setActiveTab] = useState<'tasks' | 'phases' | 'overview'>('tasks');
  const [newTaskInput, setNewTaskInput] = useState('');

  const project = activeProjectWorkspace;

  if (!project) {
    return (
      <div className="min-h-[70vh] flex flex-col items-center justify-center p-6 text-center space-y-4">
        <p className="text-base font-bold text-[#1E2D2B] dark:text-white">لم يتم تحديد مشروع</p>
        <button
          onClick={() => navigate('/projects')}
          className="px-4 py-2 rounded-xl bg-[#2F6F68] text-white text-xs font-bold"
        >
          العودة للمشاريع
        </button>
      </div>
    );
  }

  const projectTasks = tasks.filter(t => t.projectId === project.id);
  const pct = Math.round(project.progressPercent * 100);

  const handleAddQuickTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTaskInput.trim()) return;

    createTask({
      title: newTaskInput.trim(),
      projectId: project.id,
      priority: 'medium',
      status: 'planned',
      estimatedDurationMinutes: 30,
    });
    setNewTaskInput('');
  };

  const handleToggleSubtask = (index: number) => {
    if (!project.subtasks) return;
    const current = project.subtasks[index];
    const isDone = current.includes('(منجز)');
    let updatedText = current;
    if (isDone) {
      updatedText = current.replace(' (منجز)', '');
    } else {
      updatedText = `${current} (منجز)`;
    }

    const updatedSubtasks = [...project.subtasks];
    updatedSubtasks[index] = updatedText;
    
    // Recalculate progress
    const completedCount = updatedSubtasks.filter(s => s.includes('(منجز)')).length;
    const newProgress = updatedSubtasks.length > 0 ? completedCount / updatedSubtasks.length : 0;

    updateProject(project.id, {
      subtasks: updatedSubtasks,
      progressPercent: Number(newProgress.toFixed(2)),
    });
  };

  return (
    <div className="pb-28 pt-4 px-4 sm:px-6 space-y-6">
      {/* Top Header */}
      <header className="flex items-center justify-between pt-2">
        <button
          onClick={() => navigate('/projects')}
          className="flex items-center gap-1.5 p-2 rounded-xl text-[#576F6A] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white hover:bg-[#EEF5F2] dark:hover:bg-[#1E332E] transition-colors cursor-pointer"
        >
          <ArrowRight className="w-5 h-5" />
          <span className="text-xs font-bold">المشاريع</span>
        </button>

        <h2 className="text-sm font-bold text-[#556965] dark:text-[#A8BBB6]">
          مساحة المشروع
        </h2>

        <button
          onClick={() => setIsAiBreakdownOpen(true)}
          className="p-2 rounded-xl text-[#2F6F68] dark:text-[#88C6B9] hover:bg-[#EAF3F0] dark:hover:bg-[#1E3731] transition-colors cursor-pointer flex items-center gap-1 text-xs font-bold"
          title="تقسيم إضافي بالذكاء الاصطناعي"
        >
          <Sparkles className="w-4 h-4" />
          <span>تقسيم</span>
        </button>
      </header>

      {/* Project Hero Card */}
      <div className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] shadow-xs space-y-4">
        <div className="flex items-start justify-between gap-3">
          <div className="space-y-1 flex-1">
            <span
              className="inline-block text-[10px] font-bold px-2 py-0.5 rounded-md text-white mb-1"
              style={{ backgroundColor: project.accentColor || '#2F6F68' }}
            >
              {project.status === 'active' ? 'مشروع نشط' : project.status === 'completed' ? 'مكتمل' : 'مؤجل'}
            </span>
            <h1 className="text-xl font-bold text-[#1E2D2B] dark:text-white">
              {project.title}
            </h1>
            <p className="text-xs text-[#6A7E7A] dark:text-[#99ADA8] leading-relaxed">
              {project.description}
            </p>
          </div>

          <div className="text-left shrink-0">
            <div className="text-2xl font-black text-[#2F6F68] dark:text-[#7BC3B6]">
              %{pct}
            </div>
            <span className="text-[10px] text-[#788D88] dark:text-[#91A5A0]">نسبة الإنجاز</span>
          </div>
        </div>

        {/* Progress bar */}
        <div className="w-full h-2.5 bg-[#EDF3F0] dark:bg-[#253935] rounded-full overflow-hidden p-0.5">
          <div
            className="h-full rounded-full transition-all duration-300"
            style={{
              width: `${pct}%`,
              backgroundColor: project.accentColor || '#2F6F68',
            }}
          />
        </div>

        {/* Action Row */}
        <div className="flex items-center justify-between pt-1 text-xs">
          {project.nextStepTitle && (
            <div className="flex items-center gap-2">
              <span className="text-[#6C817D] dark:text-[#94A9A4]">التالي:</span>
              <span className="font-bold text-[#1E2D2B] dark:text-white truncate max-w-[150px]">
                {project.nextStepTitle}
              </span>
            </div>
          )}

          <button
            onClick={() => {
              setActiveFocusTask(project.nextStepTitle || project.title);
              navigate('/focus-session');
            }}
            className="px-3.5 py-1.5 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white font-bold flex items-center gap-1.5 shadow-2xs cursor-pointer active:scale-95 transition-all mr-auto"
          >
            <Play className="w-3.5 h-3.5 fill-current" />
            <span>جلسة تركيز</span>
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-[#DFEAE4] dark:border-[#273B36] text-xs font-bold">
        <button
          onClick={() => setActiveTab('tasks')}
          className={`flex-1 py-3 text-center border-b-2 transition-all cursor-pointer ${
            activeTab === 'tasks'
              ? 'border-[#2F6F68] text-[#2F6F68] dark:border-[#76BCAF] dark:text-[#76BCAF]'
              : 'border-transparent text-[#6D817D] dark:text-[#98ADA7] hover:text-[#1E2D2B] dark:hover:text-white'
          }`}
        >
          المراحل والخطوات ({project.subtasks?.length || 0})
        </button>

        <button
          onClick={() => setActiveTab('overview')}
          className={`flex-1 py-3 text-center border-b-2 transition-all cursor-pointer ${
            activeTab === 'overview'
              ? 'border-[#2F6F68] text-[#2F6F68] dark:border-[#76BCAF] dark:text-[#76BCAF]'
              : 'border-transparent text-[#6D817D] dark:text-[#98ADA7] hover:text-[#1E2D2B] dark:hover:text-white'
          }`}
        >
          نظرة عامة والتحليلات
        </button>
      </div>

      {/* Tab Contents */}
      {activeTab === 'tasks' && (
        <div className="space-y-4">
          {/* Quick task adder */}
          <form onSubmit={handleAddQuickTask} className="flex gap-2">
            <input
              type="text"
              value={newTaskInput}
              onChange={(e) => setNewTaskInput(e.target.value)}
              placeholder="أضف خطوة سريعة لهذا المشروع..."
              className="flex-1 px-4 py-2.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-xs text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] focus:outline-hidden focus:border-[#2F6F68]"
            />
            <button
              type="submit"
              className="px-4 py-2.5 rounded-2xl bg-[#2F6F68] text-white text-xs font-bold hover:bg-[#245650] flex items-center gap-1 cursor-pointer shrink-0"
            >
              <Plus className="w-4 h-4" />
              إضافة
            </button>
          </form>

          {/* Subtasks checklist */}
          <div className="space-y-2">
            {project.subtasks && project.subtasks.length > 0 ? (
              project.subtasks.map((step, idx) => {
                const isDone = step.includes('(منجز)');
                const cleanStep = step.replace(' (منجز)', '');

                return (
                  <div
                    key={idx}
                    className={`flex items-center justify-between p-3.5 rounded-2xl border transition-all ${
                      isDone
                        ? 'bg-[#F2F6F4] dark:bg-[#152320] border-[#DFECE6] dark:border-[#22332F] opacity-75'
                        : 'bg-white dark:bg-[#1A2825] border-[#DFE9E4] dark:border-[#283C37]'
                    }`}
                  >
                    <div className="flex items-center gap-3 flex-1 min-w-0">
                      <button
                        onClick={() => handleToggleSubtask(idx)}
                        className={`w-5 h-5 rounded-md flex items-center justify-center transition-all cursor-pointer shrink-0 ${
                          isDone
                            ? 'bg-[#2F6F68] text-white'
                            : 'border-2 border-[#B9C9C3] dark:border-[#425A54] hover:border-[#2F6F68]'
                        }`}
                      >
                        {isDone && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                      </button>

                      <span
                        className={`text-xs font-semibold ${
                          isDone
                            ? 'line-through text-[#798D88] dark:text-[#7C918C]'
                            : 'text-[#1E2D2B] dark:text-[#E7F0ED]'
                        }`}
                      >
                        {cleanStep}
                      </span>
                    </div>

                    {!isDone && (
                      <button
                        onClick={() => {
                          setActiveFocusTask(cleanStep);
                          navigate('/focus-session');
                        }}
                        className="p-1.5 rounded-lg text-[#667E78] dark:text-[#9AB1AB] hover:text-[#2F6F68] hover:bg-[#EEF5F2] dark:hover:bg-[#243B35] transition-colors cursor-pointer"
                        title="جلسة تركيز لهذه الخطوة"
                      >
                        <Play className="w-3.5 h-3.5 fill-current" />
                      </button>
                    )}
                  </div>
                );
              })
            ) : (
              <div className="p-8 text-center bg-white dark:bg-[#1A2825] rounded-3xl border border-[#DFE9E4] dark:border-[#283C37] space-y-2">
                <p className="text-xs text-[#6A7E7A] dark:text-[#96ABA5]">لا توجد خطوات مضافة بعد</p>
                <button
                  onClick={() => setIsAiBreakdownOpen(true)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#EAF5F2] text-[#2F6F68] text-xs font-bold"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  قسّم المشروع بالذكاء الاصطناعي
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'overview' && (
        <div className="space-y-4">
          <div className="p-4 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-3">
            <h3 className="text-xs font-bold text-[#4F6863] dark:text-[#A1B6B1] flex items-center gap-1.5">
              <BarChart3 className="w-4 h-4 text-[#2F6F68]" />
              إحصائيات الإنجاز
            </h3>

            <div className="grid grid-cols-2 gap-3 text-center">
              <div className="p-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#1F332E]">
                <span className="text-xl font-bold text-[#2F6F68] dark:text-[#88C6B9]">
                  {project.subtasks?.filter(s => s.includes('(منجز)')).length || 0}
                </span>
                <p className="text-[10px] text-[#697E7A] dark:text-[#9BB0AB] mt-0.5">خطوات منجزة</p>
              </div>

              <div className="p-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#1F332E]">
                <span className="text-xl font-bold text-[#5A6F6B] dark:text-[#A7BCB7]">
                  {project.subtasks?.filter(s => !s.includes('(منجز)')).length || 0}
                </span>
                <p className="text-[10px] text-[#697E7A] dark:text-[#9BB0AB] mt-0.5">خطوات متبقية</p>
              </div>
            </div>
          </div>

          <div className="p-4 rounded-3xl bg-[#EEF5F2] dark:bg-[#1E302C] border border-[#D5E3DD] dark:border-[#29423B] space-y-2">
            <h4 className="text-xs font-bold text-[#2F6F68] dark:text-[#88C6B9]">
              نصيحة هندلها الهادئة 🌱
            </h4>
            <p className="text-xs text-[#4F6662] dark:text-[#BDD1CC] leading-relaxed">
              ركز فقط على الخطوة التالية، ولا تشغل تفكيرك بباقي الخطوات حتى تفرغ منها. الهدوء يضاعف الإتقان.
            </p>
          </div>
        </div>
      )}
    </div>
  );
};
