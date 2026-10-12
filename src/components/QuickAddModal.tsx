import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import {
  X,
  Calendar,
  Clock,
  Folder,
  ChevronDown,
  CheckSquare,
} from 'lucide-react';
import { TaskPriority, EnergyLevel } from '../types';
import { parseEgyptianTaskInput, formatEgyptianDateSlot } from '../utils/taskParser';
import { CustomSelect } from './CustomSelect';
import { CustomDatePicker } from './CustomDatePicker';

export const QuickAddModal: React.FC = () => {
  const {
    isQuickAddOpen,
    setIsQuickAddOpen,
    createTask,
    projects,
    activeProjectWorkspace,
  } = useApp();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [priority, setPriority] = useState<TaskPriority>('medium');
  const [durationMinutes, setDurationMinutes] = useState<number>(25);
  const [projectId, setProjectId] = useState<string>('');
  const [energyLevel, setEnergyLevel] = useState<EnergyLevel>('medium');

  // Deadline state
  const [deadlinePreset, setDeadlinePreset] = useState<'today' | 'tomorrow' | 'afterTomorrow' | 'custom' | 'none'>('tomorrow');
  const [selectedDate, setSelectedDate] = useState<string>('');
  const [selectedTime, setSelectedTime] = useState<string>('17:00');
  const [showDescription, setShowDescription] = useState(false);

  // Initialize dates and default project
  useEffect(() => {
    if (isQuickAddOpen) {
      if (activeProjectWorkspace) {
        setProjectId(activeProjectWorkspace.id);
      }
    }
    const today = new Date();
    const tom = new Date(today);
    tom.setDate(today.getDate() + 1);
    const ty = tom.getFullYear();
    const tm = String(tom.getMonth() + 1).padStart(2, '0');
    const td = String(tom.getDate()).padStart(2, '0');
    setSelectedDate(`${ty}-${tm}-${td}`);
    setSelectedTime('17:00');
  }, [isQuickAddOpen, activeProjectWorkspace]);

  if (!isQuickAddOpen) return null;

  const handlePresetChange = (preset: 'today' | 'tomorrow' | 'afterTomorrow' | 'custom' | 'none') => {
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
    } else if (preset === 'none') {
      setSelectedDate('');
    }
  };

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

    createTask({
      title: title.trim(),
      description: description.trim() || undefined,
      priority,
      status: 'planned',
      estimatedDurationMinutes: durationMinutes,
      dueAt: dueAtIso,
      timeSlot: timeSlotLabel,
      projectId: projectId || undefined,
      energyLevel,
      source: 'manual',
    });

    // Reset & Close
    setTitle('');
    setDescription('');
    setIsQuickAddOpen(false);
  };

  const priorityTabs: Array<{ id: TaskPriority; label: string; dotColor: string }> = [
    { id: 'urgent', label: 'عاجل', dotColor: 'bg-[#D25C54]' },
    { id: 'high', label: 'أولوية عالية', dotColor: 'bg-[#C27803]' },
    { id: 'medium', label: 'متوسطة', dotColor: 'bg-[#2F6F68]' },
    { id: 'low', label: 'هادئة', dotColor: 'bg-[#5B788C]' },
  ];

  const durationOptions = [
    { value: 15, label: '15 د' },
    { value: 25, label: '25 د' },
    { value: 45, label: '45 د' },
    { value: 60, label: 'ساعة' },
    { value: 90, label: '90 د' },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-xs p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-lg max-h-[92vh] overflow-y-auto rounded-t-3xl sm:rounded-3xl p-5 sm:p-6 shadow-2xl transition-all bg-white dark:bg-[#162522] border border-[#DDE7E2] dark:border-[#2C443E] text-[#1E2D2B] dark:text-[#EFF6F2]">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-3 mb-4 border-b border-[#E7EFEA] dark:border-[#243B35]">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-xl bg-[#E8F4F1] dark:bg-[#203D37] text-[#2F6F68] dark:text-[#8AD3C4] flex items-center justify-center">
              <Calendar className="w-4 h-4" />
            </div>
            <h3 className="text-base font-bold text-[#1E2D2B] dark:text-white">
              إضافة مهمة جديدة
            </h3>
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
          <div className="space-y-1">
            <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7]">
              اسم المهمة *
            </label>
            <input
              type="text"
              autoFocus
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="ما الذي تريد إنجازه؟"
              className="w-full px-4 py-2.5 rounded-2xl text-sm border focus:outline-hidden transition-all bg-[#F9FAF8] dark:bg-[#1E302C] border-[#DCE5E0] dark:border-[#2B423C] text-[#1E2D2B] dark:text-white placeholder-[#96A6A2] dark:placeholder-[#768C86] focus:border-[#2F6F68] dark:focus:border-[#76BCAF] font-medium"
            />
          </div>

          {/* Optional Notes Toggle */}
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
                  <span>ملاحظات (اختياري)</span>
                  <button
                    type="button"
                    onClick={() => setShowDescription(false)}
                    className="text-[11px] text-[#7A8E8A] hover:underline cursor-pointer"
                  >
                    إلغاء الملاحظات
                  </button>
                </div>
                <textarea
                  rows={2}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="ملاحظات توضيحية أو روابط..."
                  className="w-full px-3.5 py-2 rounded-2xl text-xs border focus:outline-hidden transition-all bg-[#F9FAF8] dark:bg-[#1E302C] border-[#DCE5E0] dark:border-[#2B423C] text-[#1E2D2B] dark:text-white placeholder-[#96A6A2] dark:placeholder-[#768C86] focus:border-[#2F6F68] dark:focus:border-[#76BCAF]"
                />
              </div>
            )}
          </div>

          {/* Deadline Section */}
          <div className="space-y-2 pt-1">
            <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7] flex items-center gap-1.5">
              <Calendar className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#76BCAF]" />
              <span>الموعد والديدلاين</span>
            </label>

            {/* Presets Segmented Buttons */}
            <div className="p-1 rounded-2xl bg-[#F0F5F2] dark:bg-[#1A2C28] flex items-center gap-1 text-xs font-medium">
              {[
                { id: 'today', label: 'النهاردة' },
                { id: 'tomorrow', label: 'بكرة' },
                { id: 'afterTomorrow', label: 'بعد بكرة' },
                { id: 'custom', label: 'مخصص' },
                { id: 'none', label: 'بدون موعد' },
              ].map((p) => {
                const isActive = deadlinePreset === p.id;
                return (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => handlePresetChange(p.id as any)}
                    className={`flex-1 py-1.5 rounded-xl transition-all cursor-pointer text-center text-xs font-bold ${
                      isActive
                        ? 'bg-white dark:bg-[#25423B] text-[#2F6F68] dark:text-[#88C6B9] shadow-xs'
                        : 'text-[#627772] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                    }`}
                  >
                    {p.label}
                  </button>
                );
              })}
            </div>

            {/* Interactive Arabic Date & Time Picker */}
            {deadlinePreset !== 'none' && (
              <div className="pt-1">
                <CustomDatePicker
                  selectedDate={selectedDate}
                  onSelectDate={(newDate) => {
                    setSelectedDate(newDate);
                    setDeadlinePreset('custom');
                  }}
                  selectedTime={selectedTime}
                  onSelectTime={setSelectedTime}
                  defaultOpen={deadlinePreset === 'custom'}
                />
              </div>
            )}
          </div>

          {/* Priority Section */}
          <div className="space-y-1.5 pt-1">
            <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7]">
              الأولوية
            </label>

            <div className="grid grid-cols-4 gap-1.5 p-1 rounded-2xl bg-[#F0F5F2] dark:bg-[#1A2C28]">
              {priorityTabs.map((p) => {
                const isActive = priority === p.id;
                return (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => setPriority(p.id)}
                    className={`py-1.5 px-2 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                      isActive
                        ? 'bg-white dark:bg-[#25423B] text-[#1E2D2B] dark:text-white shadow-xs'
                        : 'text-[#627772] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                    }`}
                  >
                    <span className={`w-2 h-2 rounded-full ${p.dotColor}`} />
                    <span>{p.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Duration & Project Row */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
            {/* Duration */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7] flex items-center gap-1.5">
                <Clock className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#76BCAF]" />
                <span>المدة المتوقعة</span>
              </label>
              <div className="flex items-center gap-1 p-1 rounded-2xl bg-[#F0F5F2] dark:bg-[#1A2C28]">
                {durationOptions.map((d) => (
                  <button
                    key={d.value}
                    type="button"
                    onClick={() => setDurationMinutes(d.value)}
                    className={`flex-1 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer text-center ${
                      durationMinutes === d.value
                        ? 'bg-white dark:bg-[#25423B] text-[#2F6F68] dark:text-[#88C6B9] shadow-xs'
                        : 'text-[#627772] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                    }`}
                  >
                    {d.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Project Selector with CustomSelect */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#CBDCD7] flex items-center gap-1.5">
                <Folder className="w-3.5 h-3.5 text-[#2F6F68] dark:text-[#76BCAF]" />
                <span>المشروع أو السكشن</span>
              </label>
              <CustomSelect
                value={projectId}
                onChange={setProjectId}
                options={[
                  {
                    value: '',
                    label: 'مهمة عامة (بدون مشروع)',
                    icon: <CheckSquare className="w-3.5 h-3.5" />,
                  },
                  ...projects.map((proj) => ({
                    value: proj.id,
                    label: proj.title,
                    color: proj.accentColor || '#2F6F68',
                    icon: <Folder className="w-3.5 h-3.5" />,
                  })),
                ]}
                placeholder="اختر المشروع أو السكشن..."
              />
            </div>
          </div>

          {/* Footer Actions (Voice button removed as requested!) */}
          <div className="flex items-center justify-end gap-2 pt-3 border-t border-[#E8EFEA] dark:border-[#243B35]">
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
              className="px-5 py-2.5 rounded-xl font-bold text-xs bg-[#2F6F68] hover:bg-[#245650] text-white disabled:opacity-40 transition-all shadow-xs cursor-pointer active:scale-95"
            >
              إضافة المهمة
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
