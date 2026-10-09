import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import {
  X,
  Sparkles,
  Calendar,
  Clock,
  Flag,
  Folder,
  Zap,
  Check,
  Flame,
  Coffee,
  Leaf,
  ChevronDown,
  ChevronUp,
  AlertCircle,
} from 'lucide-react';
import { TaskPriority, EnergyLevel } from '../types';
import { parseEgyptianTaskInput, formatEgyptianDateSlot } from '../utils/taskParser';

export const QuickAddModal: React.FC = () => {
  const {
    isQuickAddOpen,
    setIsQuickAddOpen,
    createTask,
    setIsSmartAddOpen,
    projects,
  } = useApp();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [priority, setPriority] = useState<TaskPriority>('medium');
  const [durationMinutes, setDurationMinutes] = useState<number>(25);
  const [customDuration, setCustomDuration] = useState<string>('');
  const [projectId, setProjectId] = useState<string>('');
  const [energyLevel, setEnergyLevel] = useState<EnergyLevel>('medium');

  // Deadline state
  const [deadlinePreset, setDeadlinePreset] = useState<'today' | 'tomorrow' | 'afterTomorrow' | 'weekend' | 'custom' | 'none'>('tomorrow');
  const [selectedDate, setSelectedDate] = useState<string>('');
  const [selectedTime, setSelectedTime] = useState<string>('17:00');
  const [showDescription, setShowDescription] = useState(false);
  const [detectedSuggestion, setDetectedSuggestion] = useState<any>(null);

  // Initialize dates
  useEffect(() => {
    const today = new Date();
    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const d = String(today.getDate()).padStart(2, '0');
    
    // Default tomorrow
    const tom = new Date(today);
    tom.setDate(today.getDate() + 1);
    const ty = tom.getFullYear();
    const tm = String(tom.getMonth() + 1).padStart(2, '0');
    const td = String(tom.getDate()).padStart(2, '0');
    setSelectedDate(`${ty}-${tm}-${td}`);
    setSelectedTime('17:00');
  }, [isQuickAddOpen]);

  // Smart suggestion detection when typing title
  useEffect(() => {
    if (!title.trim() || title.length < 5) {
      setDetectedSuggestion(null);
      return;
    }
    const parsed = parseEgyptianTaskInput(title);
    if (parsed.dueAt || parsed.priority !== 'medium' || parsed.estimatedDurationMinutes !== 25) {
      setDetectedSuggestion(parsed);
    } else {
      setDetectedSuggestion(null);
    }
  }, [title]);

  if (!isQuickAddOpen) return null;

  const handleApplySuggestion = () => {
    if (!detectedSuggestion) return;
    setTitle(detectedSuggestion.title);
    setPriority(detectedSuggestion.priority);
    setDurationMinutes(detectedSuggestion.estimatedDurationMinutes);
    if (detectedSuggestion.dateString) {
      setSelectedDate(detectedSuggestion.dateString);
      setDeadlinePreset('custom');
    }
    if (detectedSuggestion.timeString) {
      setSelectedTime(detectedSuggestion.timeString);
    }
    setDetectedSuggestion(null);
  };

  const handlePresetChange = (preset: 'today' | 'tomorrow' | 'afterTomorrow' | 'weekend' | 'custom' | 'none') => {
    setDeadlinePreset(preset);
    const now = new Date();

    if (preset === 'today') {
      const y = now.getFullYear();
      const m = String(now.getMonth() + 1).padStart(2, '0');
      const d = String(now.getDate()).padStart(2, '0');
      setSelectedDate(`${y}-${m}-${d}`);
      if (!selectedTime) setSelectedTime('18:00');
    } else if (preset === 'tomorrow') {
      const tom = new Date(now);
      tom.setDate(now.getDate() + 1);
      const y = tom.getFullYear();
      const m = String(tom.getMonth() + 1).padStart(2, '0');
      const d = String(tom.getDate()).padStart(2, '0');
      setSelectedDate(`${y}-${m}-${d}`);
      if (!selectedTime) setSelectedTime('17:00');
    } else if (preset === 'afterTomorrow') {
      const aft = new Date(now);
      aft.setDate(now.getDate() + 2);
      const y = aft.getFullYear();
      const m = String(aft.getMonth() + 1).padStart(2, '0');
      const d = String(aft.getDate()).padStart(2, '0');
      setSelectedDate(`${y}-${m}-${d}`);
      if (!selectedTime) setSelectedTime('14:00');
    } else if (preset === 'weekend') {
      const wk = new Date(now);
      const day = now.getDay();
      const diffToFriday = (5 - day + 7) % 7 || 7;
      wk.setDate(now.getDate() + diffToFriday);
      const y = wk.getFullYear();
      const m = String(wk.getMonth() + 1).padStart(2, '0');
      const d = String(wk.getDate()).padStart(2, '0');
      setSelectedDate(`${y}-${m}-${d}`);
      setSelectedTime('16:00');
    } else if (preset === 'none') {
      setSelectedDate('');
    }
  };

  // Compute calculated deadline display
  const getCalculatedDeadline = () => {
    if (deadlinePreset === 'none' || !selectedDate) {
      return { label: 'بدون موعد محدد (صندوق الوارد)', isNone: true };
    }

    try {
      const [year, month, day] = selectedDate.split('-').map(Number);
      const [hour, minute] = (selectedTime || '12:00').split(':').map(Number);
      const d = new Date(year, month - 1, day, hour || 0, minute || 0);

      const slot = formatEgyptianDateSlot(d, Boolean(selectedTime));
      const iso = d.toISOString();
      return { label: slot, iso, isNone: false };
    } catch {
      return { label: 'موعد محدد', isNone: false };
    }
  };

  const currentDeadline = getCalculatedDeadline();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    let dueAtIso: string | undefined = undefined;
    let timeSlotLabel: string | undefined = undefined;

    if (deadlinePreset !== 'none' && selectedDate) {
      try {
        const [year, month, day] = selectedDate.split('-').map(Number);
        const [hour, minute] = (selectedTime || '12:00').split(':').map(Number);
        const d = new Date(year, month - 1, day, hour || 0, minute || 0);
        dueAtIso = d.toISOString();
        timeSlotLabel = formatEgyptianDateSlot(d, Boolean(selectedTime));
      } catch {
        // Fallback
      }
    }

    const duration = customDuration ? parseInt(customDuration, 10) || durationMinutes : durationMinutes;

    createTask({
      title: title.trim(),
      description: description.trim() || undefined,
      priority,
      status: 'planned',
      estimatedDurationMinutes: duration,
      dueAt: dueAtIso,
      timeSlot: timeSlotLabel,
      projectId: projectId || undefined,
      energyLevel,
      source: 'manual',
    });

    // Reset & Close
    setTitle('');
    setDescription('');
    setCustomDuration('');
    setIsQuickAddOpen(false);
  };

  const priorityOptions: Array<{ id: TaskPriority; label: string; icon: any; color: string; activeClass: string }> = [
    {
      id: 'urgent',
      label: 'عاجل جداً',
      icon: Flame,
      color: 'text-[#B83A3A] dark:text-[#F39F9F]',
      activeClass: 'bg-[#FBE8E6] dark:bg-[#462020] border-[#E8A5A5] dark:border-[#7A3636] text-[#B83A3A] dark:text-[#F39F9F]',
    },
    {
      id: 'high',
      label: 'أولوية عالية',
      icon: Flag,
      color: 'text-[#B76F1D] dark:text-[#ECC28C]',
      activeClass: 'bg-[#FDF0DE] dark:bg-[#3D2C1B] border-[#EAC28E] dark:border-[#6C4C2B] text-[#B76F1D] dark:text-[#ECC28C]',
    },
    {
      id: 'medium',
      label: 'متوسطة',
      icon: Leaf,
      color: 'text-[#2F6F68] dark:text-[#88C6B9]',
      activeClass: 'bg-[#EEF3F0] dark:bg-[#1E332E] border-[#B7D8D0] dark:border-[#2C524A] text-[#2F6F68] dark:text-[#88C6B9]',
    },
    {
      id: 'low',
      label: 'هادئة',
      icon: Coffee,
      color: 'text-[#3E7092] dark:text-[#88BCD8]',
      activeClass: 'bg-[#EBF3F8] dark:bg-[#1A2C38] border-[#A8CCE1] dark:border-[#2C485C] text-[#3E7092] dark:text-[#88BCD8]',
    },
  ];

  const durationPresets = [
    { value: 15, label: '١٥ د (سريعة)' },
    { value: 25, label: '٢٥ د (بومودورو ⏱️)' },
    { value: 45, label: '٤٥ د (تركيز عميق)' },
    { value: 60, label: 'ساعة كاملة' },
    { value: 90, label: '٩٠ دقيقة' },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-xs p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-xl max-h-[92vh] overflow-y-auto rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl transition-all bg-white dark:bg-[#162522] border border-[#DDE7E2] dark:border-[#2C443E] text-[#1E2D2B] dark:text-[#EFF6F2]">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-3 mb-3 border-b border-[#E7EFEA] dark:border-[#243B35]">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-[#E8F4F1] dark:bg-[#203D37] text-[#2F6F68] dark:text-[#8AD3C4] flex items-center justify-center">
              <Calendar className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-lg font-black text-[#1E2D2B] dark:text-white">إضافة مهمة جديدة</h3>
              <p className="text-[11px] text-[#6A7E7A] dark:text-[#9FB3AE]">
                حدد الديدلاين والأولوية بدقة وبدون مواعيد عشوائية
              </p>
            </div>
          </div>
          <button
            onClick={() => setIsQuickAddOpen(false)}
            className="p-1.5 rounded-full hover:bg-black/5 dark:hover:bg-white/10 text-[#647370] dark:text-[#B7C9C2] cursor-pointer transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          
          {/* Title Input */}
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7] flex items-center justify-between">
              <span>عنوان المهمة *</span>
              <span className="text-[11px] text-[#7A8E8A] dark:text-[#8FA39E] font-normal">
                اكتب العنوان أو مواعيدها بالعربي
              </span>
            </label>
            <input
              type="text"
              autoFocus
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="مثال: ميتنج مراجعة التصميم مع الفريق..."
              className="w-full px-4 py-2.5 rounded-2xl text-sm border focus:outline-hidden transition-all bg-[#F9FAF8] dark:bg-[#1E302C] border-[#DCE5E0] dark:border-[#2B423C] text-[#1E2D2B] dark:text-white placeholder-[#96A6A2] dark:placeholder-[#768C86] focus:border-[#2F6F68] dark:focus:border-[#76BCAF] font-medium"
            />
          </div>

          {/* Smart suggestion hint banner */}
          {detectedSuggestion && (
            <div className="p-3 rounded-2xl bg-[#EBF7F4] dark:bg-[#1B3832] border border-[#C5E5DC] dark:border-[#2B564C] flex items-center justify-between gap-2 text-xs">
              <div className="space-y-0.5">
                <span className="font-bold text-[#205A53] dark:text-[#8EE0D1] flex items-center gap-1">
                  <Sparkles className="w-3.5 h-3.5" />
                  اقتراح ذكي من النص:
                </span>
                <p className="text-[11px] text-[#3E5C56] dark:text-[#A7C8C0]">
                  {detectedSuggestion.timeSlot && `📅 ${detectedSuggestion.timeSlot}`}
                  {` • أولوية ${detectedSuggestion.priorityLabel}`}
                  {` • ${detectedSuggestion.durationLabel}`}
                </p>
              </div>
              <button
                type="button"
                onClick={handleApplySuggestion}
                className="shrink-0 px-3 py-1.5 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white font-bold text-[11px] cursor-pointer transition-colors shadow-2xs"
              >
                تطبيق التفاصيل
              </button>
            </div>
          )}

          {/* Description toggle */}
          <div>
            {!showDescription ? (
              <button
                type="button"
                onClick={() => setShowDescription(true)}
                className="text-xs font-semibold text-[#2F6F68] dark:text-[#76BCAF] hover:underline flex items-center gap-1 cursor-pointer"
              >
                <span>+ إضافة ملاحظات أو تفاصيل للمهمة</span>
              </button>
            ) : (
              <div className="space-y-1">
                <div className="flex items-center justify-between text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7]">
                  <span>تفاصيل وملاحظات (اختياري)</span>
                  <button
                    type="button"
                    onClick={() => setShowDescription(false)}
                    className="text-[11px] text-[#7A8E8A] hover:underline cursor-pointer"
                  >
                    إخفاء
                  </button>
                </div>
                <textarea
                  rows={2}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="ملاحظات خفيفة أو نقاط مساعدة..."
                  className="w-full px-3.5 py-2 rounded-2xl text-xs border focus:outline-hidden transition-all bg-[#F9FAF8] dark:bg-[#1E302C] border-[#DCE5E0] dark:border-[#2B423C] text-[#1E2D2B] dark:text-white placeholder-[#96A6A2] dark:placeholder-[#768C86] focus:border-[#2F6F68] dark:focus:border-[#76BCAF]"
                />
              </div>
            )}
          </div>

          {/* DEADLINE SECTION (Exact Dates - No Random Deadlines!) */}
          <div className="space-y-2 p-3.5 rounded-2xl bg-[#F6FAF8] dark:bg-[#1B2B28] border border-[#DEE7E2] dark:border-[#283C37]">
            <div className="flex items-center justify-between">
              <label className="text-xs font-bold text-[#1E2D2B] dark:text-white flex items-center gap-1.5">
                <Calendar className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#76BCAF]" />
                <span>الديدلاين والموعد (المحدد بدقة)</span>
              </label>

              {/* Status pill of the chosen deadline */}
              <span className={`text-[11px] font-bold px-2.5 py-0.5 rounded-full ${
                currentDeadline.isNone
                  ? 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300'
                  : 'bg-[#D9ECE8] dark:bg-[#224842] text-[#205A53] dark:text-[#9BE0D1]'
              }`}>
                {currentDeadline.label}
              </span>
            </div>

            {/* Quick Presets */}
            <div className="flex flex-wrap items-center gap-1.5 pt-1">
              {[
                { id: 'today', label: 'النهاردة' },
                { id: 'tomorrow', label: 'بكرة' },
                { id: 'afterTomorrow', label: 'بعد بكرة' },
                { id: 'weekend', label: 'نهاية الأسبوع' },
                { id: 'custom', label: 'تاريخ مخصص' },
                { id: 'none', label: 'بدون ديدلاين' },
              ].map((p) => {
                const isActive = deadlinePreset === p.id;
                return (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => handlePresetChange(p.id as any)}
                    className={`px-3 py-1 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                      isActive
                        ? 'bg-[#2F6F68] text-white shadow-2xs scale-102'
                        : 'bg-white dark:bg-[#203430] border border-[#DCE5E1] dark:border-[#2C443E] text-[#556965] dark:text-[#9FB3AE] hover:bg-[#EEF5F2] dark:hover:bg-[#28423C]'
                    }`}
                  >
                    {p.label}
                  </button>
                );
              })}
            </div>

            {/* Date & Time Picker inputs if not 'none' */}
            {deadlinePreset !== 'none' && (
              <div className="grid grid-cols-2 gap-2 pt-2 border-t border-[#E3EDE8] dark:border-[#263D37]">
                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-[#627773] dark:text-[#92A7A2]">
                    تاريخ الاستحقاق
                  </label>
                  <input
                    type="date"
                    value={selectedDate}
                    onChange={(e) => {
                      setSelectedDate(e.target.value);
                      setDeadlinePreset('custom');
                    }}
                    className="w-full px-3 py-1.5 rounded-xl text-xs bg-white dark:bg-[#203430] border border-[#D7E3DE] dark:border-[#2A423C] text-[#1E2D2B] dark:text-white focus:outline-hidden focus:border-[#2F6F68]"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[10px] font-bold text-[#627773] dark:text-[#92A7A2]">
                    الساعة المحددة
                  </label>
                  <input
                    type="time"
                    value={selectedTime}
                    onChange={(e) => {
                      setSelectedTime(e.target.value);
                      setDeadlinePreset('custom');
                    }}
                    className="w-full px-3 py-1.5 rounded-xl text-xs bg-white dark:bg-[#203430] border border-[#D7E3DE] dark:border-[#2A423C] text-[#1E2D2B] dark:text-white focus:outline-hidden focus:border-[#2F6F68]"
                  />
                </div>
              </div>
            )}
          </div>

          {/* PRIORITY SELECTOR */}
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7] flex items-center gap-1.5">
              <Flag className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#76BCAF]" />
              <span>الأولوية</span>
            </label>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {priorityOptions.map((opt) => {
                const Icon = opt.icon;
                const isSelected = priority === opt.id;
                return (
                  <button
                    key={opt.id}
                    type="button"
                    onClick={() => setPriority(opt.id)}
                    className={`p-2.5 rounded-2xl border text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                      isSelected
                        ? `${opt.activeClass} shadow-2xs scale-102`
                        : 'bg-white dark:bg-[#1C2C29] border-[#DFE7E3] dark:border-[#283C37] text-[#5A6F6B] dark:text-[#9BB0AB] hover:bg-[#F2F7F5] dark:hover:bg-[#233833]'
                    }`}
                  >
                    <Icon className="w-3.5 h-3.5" />
                    <span>{opt.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* DURATION & PROJECT ROW */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {/* Duration */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7] flex items-center gap-1.5">
                <Clock className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#76BCAF]" />
                <span>المدة المتوقعة (دقائق)</span>
              </label>
              <div className="flex flex-wrap items-center gap-1.5">
                {durationPresets.map((d) => (
                  <button
                    key={d.value}
                    type="button"
                    onClick={() => {
                      setDurationMinutes(d.value);
                      setCustomDuration('');
                    }}
                    className={`px-2.5 py-1 rounded-xl text-[11px] font-bold transition-all cursor-pointer ${
                      durationMinutes === d.value && !customDuration
                        ? 'bg-[#2F6F68] text-white shadow-2xs'
                        : 'bg-white dark:bg-[#203430] border border-[#DEE7E2] dark:border-[#283C37] text-[#5B6F6B] dark:text-[#99AFA9] hover:bg-[#F2F7F5] dark:hover:bg-[#243B35]'
                    }`}
                  >
                    {d.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Project Selector */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7] flex items-center gap-1.5">
                <Folder className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#76BCAF]" />
                <span>المشروع المرتبط</span>
              </label>
              <select
                value={projectId}
                onChange={(e) => setProjectId(e.target.value)}
                className="w-full px-3 py-2 rounded-2xl text-xs bg-white dark:bg-[#203430] border border-[#DCE5E1] dark:border-[#2C443E] text-[#1E2D2B] dark:text-white focus:outline-hidden focus:border-[#2F6F68] cursor-pointer font-medium"
              >
                <option value="">بدون مشروع (مهمة مستقلة)</option>
                {projects.map((proj) => (
                  <option key={proj.id} value={proj.id}>
                    📁 {proj.title}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Footer Actions */}
          <div className="flex items-center justify-between pt-3 border-t border-[#E8EFEA] dark:border-[#243B35]">
            <button
              type="button"
              onClick={() => {
                setIsQuickAddOpen(false);
                setIsSmartAddOpen(true);
              }}
              className="flex items-center gap-1.5 text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline cursor-pointer"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>مساعد الإضافة الصوتية</span>
            </button>

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setIsQuickAddOpen(false)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-[#647370] dark:text-[#A7BCB7] hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer"
              >
                إلغاء
              </button>

              <button
                type="submit"
                disabled={!title.trim()}
                className="px-5 py-2.5 rounded-xl font-bold text-xs bg-[#245650] hover:bg-[#1b433e] text-white dark:bg-[#9DD2C5] dark:text-[#101A18] hover:opacity-95 disabled:opacity-50 transition-all shadow-sm cursor-pointer active:scale-95"
              >
                إضافة المهمة بالتفاصيل
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
