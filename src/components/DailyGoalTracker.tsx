import React, { useState, useEffect, useRef } from 'react';
import { useApp } from '../context/AppContext';
import { DailyGoalSettings, CustomMilestone } from '../types';
import { CelebrationCheckbox } from './CelebrationCheckbox';
import { fireGoalCelebration } from '../utils/celebration';
import {
  Target,
  Sparkles,
  CheckCircle2,
  Check,
  Clock,
  Play,
  Plus,
  Trash2,
  Sliders,
  X,
  Award,
  Zap,
  BookOpen,
  Heart,
  ChevronDown,
  ChevronUp,
  RotateCcw,
} from 'lucide-react';

const STORAGE_KEY = 'handelha_daily_goals';

const getTodayDateString = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const defaultSettings: DailyGoalSettings = {
  targetTasksCount: 4,
  targetFocusMinutes: 50,
  highlightGoal: 'إتمام المراجعة الأساسية للمشروع الأهم',
  highlightCompleted: false,
  loggedFocusMinutes: 25,
  customMilestones: [
    { id: 'cm-1', title: 'استراحة هادئة بدون شاشات (١٥ د)', completed: true, category: 'wellness' },
    { id: 'cm-2', title: 'قراءة ملهمة أو تعلم جديد', completed: false, category: 'learning' },
  ],
  lastActiveDate: getTodayDateString(),
};

export const DailyGoalTracker: React.FC = () => {
  const { tasks, navigate, setActiveFocusTask } = useApp();

  const [settings, setSettings] = useState<DailyGoalSettings>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed: DailyGoalSettings = JSON.parse(stored);
        const today = getTodayDateString();
        // If a new day has arrived, preserve target preferences but reset daily check-offs
        if (parsed.lastActiveDate !== today) {
          return {
            ...parsed,
            highlightCompleted: false,
            loggedFocusMinutes: 0,
            customMilestones: parsed.customMilestones.map(m => ({ ...m, completed: false })),
            lastActiveDate: today,
          };
        }
        return parsed;
      }
    } catch {
      // ignore
    }
    return defaultSettings;
  });

  const [isEditing, setIsEditing] = useState(false);
  const [newMilestoneText, setNewMilestoneText] = useState('');
  const [newMilestoneCategory, setNewMilestoneCategory] = useState<'task' | 'focus' | 'wellness' | 'learning'>('task');
  const [tempTasksTarget, setTempTasksTarget] = useState(settings.targetTasksCount);
  const [tempFocusTarget, setTempFocusTarget] = useState(settings.targetFocusMinutes);
  const [tempHighlight, setTempHighlight] = useState(settings.highlightGoal);
  const [celebrationToast, setCelebrationToast] = useState<{ message: string; sub?: string } | null>(null);

  // Auto-dismiss celebration toast
  useEffect(() => {
    if (celebrationToast) {
      const timer = setTimeout(() => {
        setCelebrationToast(null);
      }, 3800);
      return () => clearTimeout(timer);
    }
  }, [celebrationToast]);

  // Synchronize state to localStorage
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
    } catch {
      // ignore
    }
  }, [settings]);

  // Count today's completed tasks from app state
  const completedTasksCount = tasks.filter(t => t.status === 'completed').length;
  const tasksTarget = Math.max(1, settings.targetTasksCount);
  const tasksProgress = Math.min(1, completedTasksCount / tasksTarget);

  // Focus progress
  const focusTarget = Math.max(1, settings.targetFocusMinutes);
  const focusProgress = Math.min(1, settings.loggedFocusMinutes / focusTarget);

  // Highlight goal progress
  const highlightProgress = settings.highlightCompleted ? 1 : 0;

  // Custom milestones progress
  const totalCustom = settings.customMilestones.length;
  const completedCustom = settings.customMilestones.filter(m => m.completed).length;
  const customProgress = totalCustom > 0 ? completedCustom / totalCustom : 1;

  // Total Milestone Score: 4 pillars
  // 1. Task milestone
  // 2. Focus milestone
  // 3. Highlight milestone
  // 4. Custom milestones
  const milestoneWeights = totalCustom > 0 ? [0.35, 0.25, 0.25, 0.15] : [0.45, 0.30, 0.25];
  let calculatedScore = 0;
  if (totalCustom > 0) {
    calculatedScore =
      tasksProgress * milestoneWeights[0] +
      focusProgress * milestoneWeights[1] +
      highlightProgress * milestoneWeights[2] +
      customProgress * milestoneWeights[3];
  } else {
    calculatedScore =
      tasksProgress * milestoneWeights[0] +
      focusProgress * milestoneWeights[1] +
      highlightProgress * milestoneWeights[2];
  }

  const overallPercent = Math.round(calculatedScore * 100);

  // Milestone stages check
  const isStartPassed = completedTasksCount >= 1 || settings.loggedFocusMinutes >= 15;
  const isFocusMilestonePassed = settings.loggedFocusMinutes >= settings.targetFocusMinutes;
  const isTasksMilestonePassed = completedTasksCount >= settings.targetTasksCount;
  const isHighlightPassed = settings.highlightCompleted;

  // Count achieved stages
  const milestonesPassedCount = [
    isStartPassed,
    isFocusMilestonePassed,
    isTasksMilestonePassed,
    isHighlightPassed,
  ].filter(Boolean).length;

  // Track 100% milestone completion for grand celebratory confetti burst
  const prevPercentRef = useRef(overallPercent);
  useEffect(() => {
    if (prevPercentRef.current < 100 && overallPercent >= 100) {
      fireGoalCelebration(null, { intensity: 'grand' });
      setCelebrationToast({
        message: 'الله ينور عليك يا فنان! قفّلت كل محطات الإنتاجية للنهاردة 🏆🌱',
        sub: 'إنجاز متكتك بخطوات رايقة وبدون أي كروكة أو وجع دماغ',
      });
    }
    prevPercentRef.current = overallPercent;
  }, [overallPercent]);

  // Milestone status label
  const getEncouragementText = () => {
    if (overallPercent >= 100) return 'الله ينور عليك! أتممت محطات اليوم كلها على الرايق وبأعلى إتقان 🏆🌱';
    if (overallPercent >= 75) return 'عاش والله يا بطل! قربت تخلّص كل محطاتك الباقية ✨';
    if (overallPercent >= 50) return 'نص المشوار اتظبط بالمللي.. كمّل خطواتك على الهادي 🌿';
    if (overallPercent >= 25) return 'بداية زي الفل! خطوة ورا خطوة وهنهندلها كلها 💫';
    return 'حدد محطاتك النهاردة وابدأ بخطوة صغيرة ورايقة 🎯';
  };

  const toggleHighlight = () => {
    setSettings(prev => {
      const nextCompleted = !prev.highlightCompleted;
      if (nextCompleted) {
        setCelebrationToast({
          message: 'تسلم إيدك! أنجزت أهم هدف لليوم يا بطل ⭐',
          sub: 'خطوة أساسية تروّق يومك وتشيل عنك التوتر',
        });
      }
      return { ...prev, highlightCompleted: nextCompleted };
    });
  };

  const addFocusMinutes = (mins: number, e?: React.MouseEvent) => {
    setSettings(prev => {
      const prevMins = prev.loggedFocusMinutes;
      const nextMins = Math.min(prev.targetFocusMinutes + 60, prevMins + mins);
      if (prevMins < prev.targetFocusMinutes && nextMins >= prev.targetFocusMinutes) {
        fireGoalCelebration(e || null, { intensity: 'milestone' });
        setCelebrationToast({
          message: 'يا سيدي على الروقان! كمّلت دقائق التركيز المستهدفة ⏱️✨',
          sub: `عاش والله.. قعدت مركز ${prev.targetFocusMinutes} دقيقة بدون ما تشتت نفسك`,
        });
      }
      return {
        ...prev,
        loggedFocusMinutes: nextMins,
      };
    });
  };

  const toggleCustomMilestone = (id: string, title?: string) => {
    setSettings(prev => {
      let justCompleted = false;
      const updated = prev.customMilestones.map(m => {
        if (m.id === id) {
          const nextState = !m.completed;
          if (nextState) justCompleted = true;
          return { ...m, completed: nextState };
        }
        return m;
      });
      if (justCompleted) {
        setCelebrationToast({
          message: `عاش يا بطل! أتممت محطة: ${title || 'المحطة المخصصة'} 🌿`,
        });
      }
      return { ...prev, customMilestones: updated };
    });
  };

  const removeCustomMilestone = (id: string) => {
    setSettings(prev => ({
      ...prev,
      customMilestones: prev.customMilestones.filter(m => m.id !== id),
    }));
  };

  const handleAddCustomMilestone = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMilestoneText.trim()) return;

    const newMilestone: CustomMilestone = {
      id: `cm-${Date.now()}`,
      title: newMilestoneText.trim(),
      completed: false,
      category: newMilestoneCategory,
    };

    setSettings(prev => ({
      ...prev,
      customMilestones: [...prev.customMilestones, newMilestone],
    }));
    setNewMilestoneText('');
  };

  const handleSaveSettings = () => {
    setSettings(prev => ({
      ...prev,
      targetTasksCount: tempTasksTarget,
      targetFocusMinutes: tempFocusTarget,
      highlightGoal: tempHighlight.trim() || 'المعلم الأهم لليوم',
    }));
    setIsEditing(false);
  };

  const handleResetSettings = () => {
    setSettings(defaultSettings);
    setTempTasksTarget(defaultSettings.targetTasksCount);
    setTempFocusTarget(defaultSettings.targetFocusMinutes);
    setTempHighlight(defaultSettings.highlightGoal);
    setIsEditing(false);
  };

  const startFocusSession = () => {
    setActiveFocusTask(settings.highlightGoal || 'جلسة تركيز لتحقيق معلم اليوم');
    navigate('/focus-session');
  };

  return (
    <section className="p-5 sm:p-6 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#273B36] shadow-xs hover:border-[#2F6F68]/30 transition-all space-y-5">
      {/* Tracker Header */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-[#EEF5F2] dark:bg-[#203D37] text-[#2F6F68] dark:text-[#88C6B9] flex items-center justify-center shrink-0">
            <Target className="w-5 h-5 stroke-[2.2]" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-base font-bold text-[#1E2D2B] dark:text-white">
                محطات الإنتاجية اليومية
              </h2>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-[#E5EFEA] dark:bg-[#24423C] text-[#2F6F68] dark:text-[#8AD3C4]">
                {milestonesPassedCount} من ٤ محطات
              </span>
            </div>
            <p className="text-xs text-[#667C77] dark:text-[#9BB0AB] mt-0.5">
              {getEncouragementText()}
            </p>
          </div>
        </div>

        {/* Customization Button */}
        <button
          onClick={() => {
            setTempTasksTarget(settings.targetTasksCount);
            setTempFocusTarget(settings.targetFocusMinutes);
            setTempHighlight(settings.highlightGoal);
            setIsEditing(!isEditing);
          }}
          className="px-3 py-1.5 rounded-xl border border-[#D8E4DF] dark:border-[#2B403B] hover:border-[#2F6F68] dark:hover:border-[#74B8AC] text-xs font-semibold text-[#4F6561] dark:text-[#AFD0C9] hover:text-[#2F6F68] dark:hover:text-white bg-[#F9FBFA] dark:bg-[#152320] flex items-center gap-1.5 transition-all cursor-pointer"
          title="تخصيص أهداف اليوم"
        >
          <Sliders className="w-3.5 h-3.5" />
          <span>{isEditing ? 'إغلاق الإعدادات' : 'تخصيص الأهداف'}</span>
        </button>
      </div>

      {/* Celebratory Feedback Banner */}
      {celebrationToast && (
        <div className="relative overflow-hidden p-3.5 rounded-2xl bg-linear-to-r from-[#E7F5F0] via-[#F2F8F5] to-[#EAE6F8] dark:from-[#1D352F] dark:via-[#1B2F2A] dark:to-[#27233E] border border-[#A8DACB] dark:border-[#3A6054] shadow-sm animate-in fade-in slide-in-from-top-2 duration-300">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <span className="w-8 h-8 rounded-xl bg-[#2F6F68] text-white flex items-center justify-center shrink-0 shadow-xs">
                <Sparkles className="w-4 h-4" />
              </span>
              <div>
                <h4 className="text-xs font-bold text-[#1E2D2B] dark:text-white">
                  {celebrationToast.message}
                </h4>
                {celebrationToast.sub && (
                  <p className="text-[11px] text-[#556F68] dark:text-[#A7C5BD] mt-0.5">
                    {celebrationToast.sub}
                  </p>
                )}
              </div>
            </div>
            <button
              onClick={() => setCelebrationToast(null)}
              className="p-1 rounded-lg text-[#718782] dark:text-[#8CA49E] hover:text-[#2F6F68] dark:hover:text-white hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer"
              title="إغلاق التنبيه"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      )}

      {/* Visual Milestone Track / Path */}
      <div className="p-4 rounded-2xl bg-[#F7FAF9] dark:bg-[#152320] border border-[#E4EDE9] dark:border-[#223530] space-y-3">
        <div className="flex items-center justify-between text-xs">
          <span className="font-bold text-[#2A3C38] dark:text-[#D5E6E2] flex items-center gap-1.5">
            <Sparkles className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#7EBDB2]" />
            مسار إنجاز اليوم
          </span>
          <span className="font-extrabold text-[#2F6F68] dark:text-[#8AD3C4]">
            %{overallPercent} مكتمل
          </span>
        </div>

        {/* Multi-step Milestone Path */}
        <div className="relative pt-2 pb-1">
          {/* Background Track Line */}
          <div className="absolute top-6 left-4 right-4 h-1.5 bg-[#DFEBE6] dark:bg-[#253935] -translate-y-1/2 rounded-full" />
          {/* Active Track Line */}
          <div
            className="absolute top-6 right-4 h-1.5 bg-linear-to-l from-[#2F6F68] to-[#4EA392] -translate-y-1/2 rounded-full transition-all duration-700 ease-out"
            style={{ width: `calc(${Math.min(100, Math.max(5, overallPercent))}% - 2rem)` }}
          />

          {/* 4 Checkpoint Nodes */}
          <div className="relative flex justify-between items-start text-center">
            {/* Step 1: Start */}
            <div className="flex flex-col items-center">
              <div
                className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-xs ${
                  isStartPassed
                    ? 'bg-[#2F6F68] text-white ring-4 ring-[#E1F1ED] dark:ring-[#22443C]'
                    : 'bg-white dark:bg-[#1A2825] border-2 border-[#BACAC4] dark:border-[#3D524D] text-[#7C908B]'
                }`}
              >
                {isStartPassed ? <Check className="w-3.5 h-3.5 stroke-[3]" /> : '١'}
              </div>
              <span className="text-[11px] font-bold text-[#2A3C38] dark:text-[#D5E6E2] mt-1.5">
                الانطلاقة
              </span>
              <span className="text-[10px] text-[#7B8F8A] dark:text-[#8AA09B]">
                أول مهمة
              </span>
            </div>

            {/* Step 2: Focus */}
            <div className="flex flex-col items-center">
              <div
                className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-xs ${
                  isFocusMilestonePassed
                    ? 'bg-[#2F6F68] text-white ring-4 ring-[#E1F1ED] dark:ring-[#22443C]'
                    : 'bg-white dark:bg-[#1A2825] border-2 border-[#BACAC4] dark:border-[#3D524D] text-[#7C908B]'
                }`}
              >
                {isFocusMilestonePassed ? <Check className="w-3.5 h-3.5 stroke-[3]" /> : '٢'}
              </div>
              <span className="text-[11px] font-bold text-[#2A3C38] dark:text-[#D5E6E2] mt-1.5">
                التركيز العميق
              </span>
              <span className="text-[10px] text-[#7B8F8A] dark:text-[#8AA09B]">
                {settings.loggedFocusMinutes}/{settings.targetFocusMinutes} د
              </span>
            </div>

            {/* Step 3: Highlight Goal */}
            <div className="flex flex-col items-center">
              <div
                className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-xs ${
                  isHighlightPassed
                    ? 'bg-[#2F6F68] text-white ring-4 ring-[#E1F1ED] dark:ring-[#22443C]'
                    : 'bg-white dark:bg-[#1A2825] border-2 border-[#BACAC4] dark:border-[#3D524D] text-[#7C908B]'
                }`}
              >
                {isHighlightPassed ? <Check className="w-3.5 h-3.5 stroke-[3]" /> : '٣'}
              </div>
              <span className="text-[11px] font-bold text-[#2A3C38] dark:text-[#D5E6E2] mt-1.5">
                المعلم الأهم
              </span>
              <span className="text-[10px] text-[#7B8F8A] dark:text-[#8AA09B]">
                {isHighlightPassed ? 'منجز ✓' : 'قيد العمل'}
              </span>
            </div>

            {/* Step 4: Comprehensive Finish */}
            <div className="flex flex-col items-center">
              <div
                className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-xs ${
                  overallPercent >= 100
                    ? 'bg-[#2F6F68] text-white ring-4 ring-[#E1F1ED] dark:ring-[#22443C]'
                    : 'bg-white dark:bg-[#1A2825] border-2 border-[#BACAC4] dark:border-[#3D524D] text-[#7C908B]'
                }`}
              >
                {overallPercent >= 100 ? <Award className="w-3.5 h-3.5" /> : '٤'}
              </div>
              <span className="text-[11px] font-bold text-[#2A3C38] dark:text-[#D5E6E2] mt-1.5">
                اليوم المثمر
              </span>
              <span className="text-[10px] text-[#7B8F8A] dark:text-[#8AA09B]">
                {completedTasksCount}/{settings.targetTasksCount} مهام
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Goal Customization Editor Panel */}
      {isEditing && (
        <div className="p-4 rounded-2xl bg-[#F4F9F7] dark:bg-[#162723] border border-[#D5E5DE] dark:border-[#274039] space-y-4 animate-in fade-in duration-200">
          <div className="flex items-center justify-between border-b border-[#DDECE6] dark:border-[#233B35] pb-2.5">
            <h3 className="text-xs font-bold text-[#1E2D2B] dark:text-white flex items-center gap-1.5">
              <Sliders className="w-3.5 h-3.5 text-[#2F6F68]" />
              تعديل أهداف ومحطات اليوم
            </h3>
            <button
              onClick={handleResetSettings}
              className="text-[11px] text-[#708480] dark:text-[#95ABA5] hover:text-[#B83A3A] flex items-center gap-1 cursor-pointer"
              title="استعادة الأهداف الافتراضية"
            >
              <RotateCcw className="w-3 h-3" />
              استعادة الافتراضي
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Target Tasks Stepper */}
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold text-[#3B4E4A] dark:text-[#BACEC9] block">
                مستهدف المهام اليومية:
              </label>
              <div className="flex items-center gap-2">
                {[2, 3, 4, 5, 6].map(num => (
                  <button
                    key={num}
                    type="button"
                    onClick={() => setTempTasksTarget(num)}
                    className={`flex-1 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer ${
                      tempTasksTarget === num
                        ? 'bg-[#2F6F68] text-white border-[#2F6F68]'
                        : 'bg-white dark:bg-[#1A2825] border-[#D4E2DC] dark:border-[#2B403B] text-[#334642] dark:text-[#AFC3BF]'
                    }`}
                  >
                    {num}
                  </button>
                ))}
              </div>
            </div>

            {/* Target Focus Minutes */}
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold text-[#3B4E4A] dark:text-[#BACEC9] block">
                مستهدف دقائق التركيز:
              </label>
              <div className="flex items-center gap-2">
                {[25, 50, 75, 100].map(mins => (
                  <button
                    key={mins}
                    type="button"
                    onClick={() => setTempFocusTarget(mins)}
                    className={`flex-1 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer ${
                      tempFocusTarget === mins
                        ? 'bg-[#2F6F68] text-white border-[#2F6F68]'
                        : 'bg-white dark:bg-[#1A2825] border-[#D4E2DC] dark:border-[#2B403B] text-[#334642] dark:text-[#AFC3BF]'
                    }`}
                  >
                    {mins} د
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Target Highlight Goal Input */}
          <div className="space-y-1.5">
            <label className="text-[11px] font-bold text-[#3B4E4A] dark:text-[#BACEC9] block">
              المعلم المحوري لليوم (الهدف الأهم):
            </label>
            <input
              type="text"
              value={tempHighlight}
              onChange={e => setTempHighlight(e.target.value)}
              placeholder="مثال: إنهاء مقترح العمل ومراجعته بهدوء"
              className="w-full px-3.5 py-2 text-xs rounded-xl border border-[#D0E2DB] dark:border-[#2E453F] bg-white dark:bg-[#1A2825] text-[#1E2D2B] dark:text-white focus:outline-hidden focus:border-[#2F6F68] dark:focus:border-[#7ABCB1]"
            />
          </div>

          {/* Action buttons */}
          <div className="flex items-center justify-end gap-2 pt-1">
            <button
              onClick={() => setIsEditing(false)}
              className="px-3.5 py-1.5 rounded-xl border border-[#D5E1DC] dark:border-[#2C413C] text-xs font-semibold text-[#546A66] dark:text-[#9FB5B0] hover:bg-black/5 dark:hover:bg-white/5 cursor-pointer"
            >
              إلغاء
            </button>
            <button
              onClick={handleSaveSettings}
              className="px-4 py-1.5 rounded-xl bg-[#2F6F68] hover:bg-[#255852] text-white text-xs font-bold shadow-xs cursor-pointer"
            >
              حفظ الأهداف
            </button>
          </div>
        </div>
      )}

      {/* Core Productivity Milestones Cards (Grid) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3.5">
        {/* Milestone 1: Tasks Target Card */}
        <div className="p-4 rounded-2xl border border-[#E0EBE6] dark:border-[#273B36] bg-white dark:bg-[#1A2825] hover:border-[#2F6F68]/30 transition-all flex flex-col justify-between space-y-3">
          <div>
            <div className="flex items-center justify-between text-xs mb-1.5">
              <span className="font-bold text-[#20312E] dark:text-[#E2EFEB] flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4 text-[#2F6F68] dark:text-[#7EBDB2]" />
                محطة إنجاز المهام
              </span>
              <span className="font-bold text-[#2F6F68] dark:text-[#88C6B9]">
                {completedTasksCount} / {settings.targetTasksCount} مهام
              </span>
            </div>
            <p className="text-[11px] text-[#697E7A] dark:text-[#97AEA9]">
              {completedTasksCount >= settings.targetTasksCount
                ? 'تم تجاوز المستهدف بنجاح! 👏'
                : `متبقي ${settings.targetTasksCount - completedTasksCount} مهام للوصول إلى هدفك اليومي.`}
            </p>
          </div>

          <div>
            {/* Progress Bar */}
            <div className="w-full h-2 bg-[#EDF4F1] dark:bg-[#253935] rounded-full overflow-hidden mb-2">
              <div
                className="h-full bg-[#2F6F68] dark:bg-[#7EBDB2] rounded-full transition-all duration-500 ease-out"
                style={{ width: `${Math.min(100, (completedTasksCount / settings.targetTasksCount) * 100)}%` }}
              />
            </div>

            <div className="flex items-center justify-between pt-1">
              <button
                onClick={() => navigate('/tasks')}
                className="text-[11px] font-bold text-[#2F6F68] dark:text-[#86C6BA] hover:underline cursor-pointer"
              >
                إدارة قائمة المهام ←
              </button>
              {completedTasksCount >= settings.targetTasksCount && (
                <span className="text-[10px] font-bold text-[#2F6F68] dark:text-[#82C5B8] flex items-center gap-0.5">
                  <Check className="w-3 h-3 stroke-[3]" /> مكتملة
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Milestone 2: Focus Time Target Card */}
        <div className="p-4 rounded-2xl border border-[#E0EBE6] dark:border-[#273B36] bg-white dark:bg-[#1A2825] hover:border-[#2F6F68]/30 transition-all flex flex-col justify-between space-y-3">
          <div>
            <div className="flex items-center justify-between text-xs mb-1.5">
              <span className="font-bold text-[#20312E] dark:text-[#E2EFEB] flex items-center gap-1.5">
                <Clock className="w-4 h-4 text-[#D3782D] dark:text-[#ECA56B]" />
                محطة التركيز الهادئ
              </span>
              <span className="font-bold text-[#D3782D] dark:text-[#ECA56B]">
                {settings.loggedFocusMinutes} / {settings.targetFocusMinutes} دقيقة
              </span>
            </div>
            <p className="text-[11px] text-[#697E7A] dark:text-[#97AEA9]">
              {settings.loggedFocusMinutes >= settings.targetFocusMinutes
                ? 'حققت وقت التركيز المستهدف اليوم بكل سلاسة!'
                : `متبقي ${settings.targetFocusMinutes - settings.loggedFocusMinutes} دقيقة للوصول للمعلم.`}
            </p>
          </div>

          <div>
            {/* Progress Bar */}
            <div className="w-full h-2 bg-[#EDF4F1] dark:bg-[#253935] rounded-full overflow-hidden mb-2.5">
              <div
                className="h-full bg-linear-to-r from-[#D3782D] to-[#E59858] rounded-full transition-all duration-500 ease-out"
                style={{ width: `${Math.min(100, (settings.loggedFocusMinutes / settings.targetFocusMinutes) * 100)}%` }}
              />
            </div>

            <div className="flex items-center justify-between gap-2">
              <button
                onClick={startFocusSession}
                className="px-2.5 py-1 rounded-xl bg-[#2F6F68] hover:bg-[#255852] text-white text-[11px] font-bold flex items-center gap-1 cursor-pointer transition-all shadow-xs"
              >
                <Play className="w-3 h-3 fill-current" />
                بدء جلسة (٢٥د)
              </button>

              <button
                onClick={(e) => addFocusMinutes(15, e)}
                className="px-2.5 py-1 rounded-xl border border-[#DCE8E3] dark:border-[#293E39] text-[#4F6460] dark:text-[#A7BCB7] hover:text-[#2F6F68] dark:hover:text-white text-[11px] font-semibold bg-[#F9FBFA] dark:bg-[#162723] hover:border-[#2F6F68] transition-colors cursor-pointer active:scale-95"
                title="تسجيل 15 دقيقة تركيز بدون مؤقت"
              >
                + ١٥ دقيقة تركيز
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Highlight of the Day (Daily Core Milestone) */}
      <div
        className={`p-4 rounded-2xl border transition-all ${
          settings.highlightCompleted
            ? 'bg-[#F2F8F5] dark:bg-[#162723] border-[#CCE2D8] dark:border-[#2A473F]'
            : 'bg-linear-to-l from-[#FAF7F2] to-white dark:from-[#24211A] dark:to-[#1A2825] border-[#E8DEC8] dark:border-[#3E3422]'
        }`}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-start gap-3 flex-1 min-w-0">
            <CelebrationCheckbox
              checked={settings.highlightCompleted}
              onChange={toggleHighlight}
              size="md"
              celebrationIntensity="milestone"
              ariaLabel="تحديد المعلم الأهم كمنجز"
              className="mt-0.5"
            />

            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2 mb-0.5">
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-[#F4EADA] dark:bg-[#3D3322] text-[#8C6228] dark:text-[#E2BF84]">
                  المعلم الأهم لليوم ⭐
                </span>
                {settings.highlightCompleted && (
                  <span className="text-[11px] font-bold text-[#2F6F68] dark:text-[#80C4B6] flex items-center gap-1 animate-in fade-in duration-300">
                    <Sparkles className="w-3 h-3 text-[#2F6F68] dark:text-[#80C4B6]" />
                    منجز بنجاح!
                  </span>
                )}
              </div>
              <p
                className={`text-sm font-bold leading-relaxed transition-colors ${
                  settings.highlightCompleted
                    ? 'line-through text-[#738883] dark:text-[#7A908B]'
                    : 'text-[#1E2D2B] dark:text-white'
                }`}
              >
                {settings.highlightGoal}
              </p>
            </div>
          </div>

          <button
            onClick={() => {
              setIsEditing(true);
              setTempHighlight(settings.highlightGoal);
            }}
            className="text-[11px] font-semibold text-[#806B49] dark:text-[#C5B396] hover:text-[#2F6F68] dark:hover:text-white px-2 py-1 rounded-lg hover:bg-black/5 dark:hover:bg-white/5 cursor-pointer shrink-0"
            title="تعديل هذا المعلم"
          >
            تعديل
          </button>
        </div>
      </div>

      {/* Custom Daily Milestones (المحطات المخصصة) */}
      <div className="space-y-3 pt-1">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold text-[#3B504C] dark:text-[#A7BCB7] flex items-center gap-1.5">
            <Zap className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#7EBDB2]" />
            محطات إضافية لليوم ({completedCustom}/{totalCustom})
          </h3>
          <span className="text-[10px] text-[#718681] dark:text-[#90A7A1]">
            محطات عادات وهدوء وتعلم
          </span>
        </div>

        {/* List of Custom Milestones */}
        <div className="space-y-2">
          {settings.customMilestones.map(m => {
            const getCategoryBadge = () => {
              switch (m.category) {
                case 'wellness':
                  return { label: 'راحة وهدوء', icon: Heart, bg: 'text-[#C95E58] bg-[#FAECEB] dark:bg-[#3E2321] dark:text-[#F19B96]' };
                case 'learning':
                  return { label: 'تعلم', icon: BookOpen, bg: 'text-[#3E7092] bg-[#EBF3F8] dark:bg-[#1D2F3C] dark:text-[#90C5E5]' };
                case 'focus':
                  return { label: 'تركيز', icon: Clock, bg: 'text-[#D3782D] bg-[#FDF1E6] dark:bg-[#3E2917] dark:text-[#E8AF83]' };
                default:
                  return { label: 'إنجاز', icon: Sparkles, bg: 'text-[#2F6F68] bg-[#EEF5F2] dark:bg-[#203D37] dark:text-[#88C6B9]' };
              }
            };
            const cat = getCategoryBadge();
            const Icon = cat.icon;

            return (
              <div
                key={m.id}
                className={`flex items-center justify-between p-3 rounded-xl border transition-all ${
                  m.completed
                    ? 'bg-[#F4F8F6] dark:bg-[#162522] border-[#DEECE5] dark:border-[#223530] opacity-80'
                    : 'bg-white dark:bg-[#1A2825] border-[#E3EDE8] dark:border-[#293E39] shadow-2xs hover:border-[#2F6F68]/30'
                }`}
              >
                <div className="flex items-center gap-3 flex-1 min-w-0">
                  <CelebrationCheckbox
                    checked={m.completed}
                    onChange={() => toggleCustomMilestone(m.id, m.title)}
                    size="sm"
                    celebrationIntensity="subtle"
                    ariaLabel={m.title}
                  />

                  <div className="flex items-center gap-2 min-w-0 flex-1">
                    <span
                      className={`text-xs font-semibold truncate transition-colors ${
                        m.completed
                          ? 'line-through text-[#798D88] dark:text-[#7A908B]'
                          : 'text-[#1E2D2B] dark:text-white'
                      }`}
                    >
                      {m.title}
                    </span>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md flex items-center gap-1 shrink-0 ${cat.bg}`}>
                      <Icon className="w-2.5 h-2.5" />
                      {cat.label}
                    </span>
                  </div>
                </div>

                <button
                  onClick={() => removeCustomMilestone(m.id)}
                  className="p-1 rounded-lg text-[#859994] dark:text-[#7A908A] hover:text-[#B83A3A] transition-colors cursor-pointer shrink-0"
                  title="حذف المحطة"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            );
          })}
        </div>

        {/* Quick Add Custom Milestone Form */}
        <form onSubmit={handleAddCustomMilestone} className="flex items-center gap-2 pt-1">
          <input
            type="text"
            value={newMilestoneText}
            onChange={e => setNewMilestoneText(e.target.value)}
            placeholder="إضافة محطة خاصة لليوم (مثال: شرب الماء بانتظام، قراءة 15 دقيقة)..."
            className="flex-1 px-3.5 py-2 text-xs rounded-xl border border-[#D8E6E0] dark:border-[#2B403B] bg-[#FDFEFE] dark:bg-[#172522] text-[#1E2D2B] dark:text-white placeholder-[#879C97] dark:placeholder-[#6C827D] focus:outline-hidden focus:border-[#2F6F68] dark:focus:border-[#7ABCB1]"
          />

          <select
            value={newMilestoneCategory}
            onChange={e => setNewMilestoneCategory(e.target.value as any)}
            className="px-2.5 py-2 text-xs rounded-xl border border-[#D8E6E0] dark:border-[#2B403B] bg-[#FDFEFE] dark:bg-[#172522] text-[#3E534F] dark:text-[#C5D9D4] focus:outline-hidden cursor-pointer"
          >
            <option value="task">إنجاز</option>
            <option value="wellness">هدوء</option>
            <option value="learning">تعلم</option>
            <option value="focus">تركيز</option>
          </select>

          <button
            type="submit"
            disabled={!newMilestoneText.trim()}
            className="p-2 rounded-xl bg-[#2F6F68] hover:bg-[#255852] disabled:opacity-40 text-white transition-all cursor-pointer shrink-0 shadow-xs"
            title="إضافة المحطة"
          >
            <Plus className="w-4 h-4" />
          </button>
        </form>
      </div>

      {/* Gentle Achievement Banner */}
      {overallPercent >= 100 && (
        <div className="p-3.5 rounded-2xl bg-linear-to-r from-[#E7F5F0] to-[#E3F2EE] dark:from-[#1A3730] dark:to-[#17302A] border border-[#B9E0D4] dark:border-[#2C5247] flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-[#2F6F68] text-white flex items-center justify-center shrink-0">
            <Award className="w-4 h-4" />
          </div>
          <div className="flex-1 min-w-0">
            <h4 className="text-xs font-bold text-[#1E2D2B] dark:text-white">
              تهانينا! اكتملت جميع محطات الإنتاجية اليوم
            </h4>
            <p className="text-[11px] text-[#4F6863] dark:text-[#A7C8C0] mt-0.5">
              حققت يومك المتزن بدون تسرع ولا ضغط ذهني. استمتع ببقية يومك بهدوء.
            </p>
          </div>
        </div>
      )}
    </section>
  );
};
