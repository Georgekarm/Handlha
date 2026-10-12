import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import {
  X,
  Calendar,
  Clock,
  Flag,
  Folder,
  Check,
  Flame,
  Coffee,
  Leaf,
  Trash2,
  CheckCircle2,
  Play,
  RotateCcw,
  CheckSquare,
} from 'lucide-react';
import { Task, TaskPriority, TaskStatus, EnergyLevel } from '../types';
import { formatEgyptianDateSlot } from '../utils/taskParser';
import { CustomSelect } from './CustomSelect';
import { CustomDatePicker } from './CustomDatePicker';

interface EditTaskModalProps {
  task: Task | null;
  isOpen: boolean;
  onClose: () => void;
}

export const EditTaskModal: React.FC<EditTaskModalProps> = ({ task, isOpen, onClose }) => {
  const { updateTask, deleteTask, projects, setActiveFocusTask, navigate } = useApp();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [priority, setPriority] = useState<TaskPriority>('medium');
  const [status, setStatus] = useState<TaskStatus>('planned');
  const [durationMinutes, setDurationMinutes] = useState<number>(25);
  const [customDuration, setCustomDuration] = useState<string>('');
  const [projectId, setProjectId] = useState<string>('');
  const [energyLevel, setEnergyLevel] = useState<EnergyLevel>('medium');

  // Deadline state
  const [deadlinePreset, setDeadlinePreset] = useState<'today' | 'tomorrow' | 'afterTomorrow' | 'weekend' | 'custom' | 'none'>('custom');
  const [selectedDate, setSelectedDate] = useState<string>('');
  const [selectedTime, setSelectedTime] = useState<string>('17:00');

  // Sync state when task changes
  useEffect(() => {
    if (!task) return;

    setTitle(task.title || '');
    setDescription(task.description || '');
    setPriority(task.priority || 'medium');
    setStatus(task.status || 'planned');
    setDurationMinutes(task.estimatedDurationMinutes || 25);
    setProjectId(task.projectId || '');
    setEnergyLevel(task.energyLevel || 'medium');

    if (task.dueAt) {
      const d = new Date(task.dueAt);
      if (!isNaN(d.getTime())) {
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        setSelectedDate(`${y}-${m}-${day}`);

        const hh = String(d.getHours()).padStart(2, '0');
        const mm = String(d.getMinutes()).padStart(2, '0');
        setSelectedTime(`${hh}:${mm}`);
        setDeadlinePreset('custom');
      } else {
        setDeadlinePreset('none');
      }
    } else {
      setDeadlinePreset('none');
      const today = new Date();
      const y = today.getFullYear();
      const m = String(today.getMonth() + 1).padStart(2, '0');
      const day = String(today.getDate()).padStart(2, '0');
      setSelectedDate(`${y}-${m}-${day}`);
      setSelectedTime('17:00');
    }
  }, [task, isOpen]);

  if (!isOpen || !task) return null;

  // Handle Preset selection
  const handleSelectPreset = (preset: 'today' | 'tomorrow' | 'afterTomorrow' | 'weekend' | 'custom' | 'none') => {
    setDeadlinePreset(preset);
    if (preset === 'none') return;

    const base = new Date();
    if (preset === 'today') {
      // today
    } else if (preset === 'tomorrow') {
      base.setDate(base.getDate() + 1);
    } else if (preset === 'afterTomorrow') {
      base.setDate(base.getDate() + 2);
    } else if (preset === 'weekend') {
      // Next Thursday in Egypt
      const currentDay = base.getDay();
      let diff = 4 - currentDay;
      if (diff <= 0) diff += 7;
      base.setDate(base.getDate() + diff);
    }

    const y = base.getFullYear();
    const m = String(base.getMonth() + 1).padStart(2, '0');
    const d = String(base.getDate()).padStart(2, '0');
    setSelectedDate(`${y}-${m}-${d}`);
  };

  const calculateFinalDeadline = () => {
    if (deadlinePreset === 'none') {
      return { dueAt: undefined, timeSlot: undefined };
    }

    if (!selectedDate) {
      return { dueAt: undefined, timeSlot: undefined };
    }

    const [year, month, day] = selectedDate.split('-').map(Number);
    const [hours, minutes] = (selectedTime || '17:00').split(':').map(Number);

    const d = new Date(year, month - 1, day, hours, minutes, 0, 0);
    if (isNaN(d.getTime())) {
      return { dueAt: undefined, timeSlot: undefined };
    }

    const slot = formatEgyptianDateSlot(d, Boolean(selectedTime));
    return {
      dueAt: d.toISOString(),
      timeSlot: slot,
    };
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const { dueAt, timeSlot } = calculateFinalDeadline();
    const finalDuration = customDuration ? parseInt(customDuration, 10) || durationMinutes : durationMinutes;

    updateTask(task.id, {
      title: title.trim(),
      description: description.trim() || undefined,
      priority,
      status,
      estimatedDurationMinutes: finalDuration,
      projectId: projectId || undefined,
      dueAt,
      timeSlot,
      energyLevel,
    });

    onClose();
  };

  const handleDelete = () => {
    deleteTask(task.id);
    onClose();
  };

  const handleStartFocus = () => {
    setActiveFocusTask(task.title);
    onClose();
    navigate('/focus-session');
  };

  const priorities: Array<{ id: TaskPriority; label: string; icon: React.ReactNode; color: string; border: string }> = [
    {
      id: 'urgent',
      label: 'عاجل جداً',
      icon: <Flame className="w-3.5 h-3.5 text-[#B83A3A]" />,
      color: 'bg-[#FBE8E6] text-[#B83A3A] dark:bg-[#462020] dark:text-[#F39F9F]',
      border: 'border-[#B83A3A]',
    },
    {
      id: 'high',
      label: 'أولوية عالية',
      icon: <Flag className="w-3.5 h-3.5 text-[#B76F1D]" />,
      color: 'bg-[#FDF0DE] text-[#B76F1D] dark:bg-[#3D2C1B] dark:text-[#ECC28C]',
      border: 'border-[#B76F1D]',
    },
    {
      id: 'medium',
      label: 'متوسطة',
      icon: <Leaf className="w-3.5 h-3.5 text-[#2F6F68]" />,
      color: 'bg-[#EEF3F0] text-[#2F6F68] dark:bg-[#1E332E] dark:text-[#88C6B9]',
      border: 'border-[#2F6F68]',
    },
    {
      id: 'low',
      label: 'هادئة',
      icon: <Coffee className="w-3.5 h-3.5 text-[#3E7092]" />,
      color: 'bg-[#EBF3F8] text-[#3E7092] dark:bg-[#1A2C38] dark:text-[#88BCD8]',
      border: 'border-[#3E7092]',
    },
  ];

  const durationOptions = [15, 25, 45, 60, 90];

  const statusOptions: Array<{ id: TaskStatus; label: string; icon: React.ReactNode }> = [
    { id: 'planned', label: 'مخططة', icon: <RotateCcw className="w-3 h-3" /> },
    { id: 'inProgress', label: 'قيد التنفيذ', icon: <Play className="w-3 h-3" /> },
    { id: 'completed', label: 'مكتملة', icon: <CheckCircle2 className="w-3 h-3 text-emerald-600" /> },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200">
      <div
        className="w-full max-w-lg bg-white dark:bg-[#172421] rounded-3xl shadow-2xl border border-[#DFEDE7] dark:border-[#243A34] overflow-hidden flex flex-col max-h-[90vh]"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-[#E7EFEA] dark:border-[#223530] flex items-center justify-between bg-[#F8FCFA] dark:bg-[#131F1C]">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-[#2F6F68]/10 dark:bg-[#2F6F68]/20 text-[#2F6F68] dark:text-[#88C6B9] flex items-center justify-center">
              <Calendar className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#1E2D2B] dark:text-white">تعديل المهمة</h2>
              <p className="text-[11px] text-[#647974] dark:text-[#90A5A0]">عدّل الميعاد أو الأولوية أو التفاصيل</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-[#6B807B] hover:text-[#1E2D2B] hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSave} className="p-4 sm:p-5 overflow-y-auto space-y-4 flex-1">
          {/* Title */}
          <div>
            <label className="block text-xs font-bold text-[#2D3F3B] dark:text-[#D1E0DC] mb-1.5">
              عنوان المهمة
            </label>
            <input
              type="text"
              value={title}
              onChange={e => setTitle(e.target.value)}
              placeholder="اكتب عنوان المهمة..."
              className="w-full px-3.5 py-2.5 rounded-xl border border-[#D5E3DE] dark:border-[#283E38] bg-white dark:bg-[#1A2825] text-sm text-[#1E2D2B] dark:text-white focus:outline-none focus:ring-2 focus:ring-[#2F6F68] transition-all"
              required
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-xs font-bold text-[#2D3F3B] dark:text-[#D1E0DC] mb-1.5">
              ملاحظات وتفاصيل (اختياري)
            </label>
            <textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              placeholder="اكتب أي ملاحظات أو تفاصيل إضافية..."
              rows={2}
              className="w-full px-3.5 py-2.5 rounded-xl border border-[#D5E3DE] dark:border-[#283E38] bg-white dark:bg-[#1A2825] text-xs text-[#1E2D2B] dark:text-white focus:outline-none focus:ring-2 focus:ring-[#2F6F68] transition-all resize-none"
            />
          </div>

          {/* Status selector */}
          <div>
            <label className="block text-xs font-bold text-[#2D3F3B] dark:text-[#D1E0DC] mb-1.5">
              حالة المهمة
            </label>
            <div className="grid grid-cols-3 gap-2">
              {statusOptions.map(opt => (
                <button
                  type="button"
                  key={opt.id}
                  onClick={() => setStatus(opt.id)}
                  className={`py-2 px-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer border ${
                    status === opt.id
                      ? 'bg-[#2F6F68] text-white border-[#2F6F68] shadow-2xs'
                      : 'bg-white dark:bg-[#1B2926] border-[#D9E6E1] dark:border-[#293F3A] text-[#4F6460] dark:text-[#9FB3AE]'
                  }`}
                >
                  {opt.icon}
                  <span>{opt.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Priority selector */}
          <div>
            <label className="block text-xs font-bold text-[#2D3F3B] dark:text-[#D1E0DC] mb-1.5">
              الأولوية
            </label>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {priorities.map(p => {
                const isSelected = priority === p.id;
                return (
                  <button
                    type="button"
                    key={p.id}
                    onClick={() => setPriority(p.id)}
                    className={`py-2 px-2 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all cursor-pointer border ${
                      isSelected
                        ? `${p.color} ${p.border} ring-2 ring-offset-1 ring-[#2F6F68] shadow-2xs font-extrabold`
                        : 'bg-white dark:bg-[#1B2926] border-[#D9E6E1] dark:border-[#293F3A] text-[#4F6460] dark:text-[#9FB3AE] hover:border-[#2F6F68]'
                    }`}
                  >
                    {p.icon}
                    <span>{p.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Duration selector */}
          <div>
            <label className="block text-xs font-bold text-[#2D3F3B] dark:text-[#D1E0DC] mb-1.5">
              المدة المقدرة
            </label>
            <div className="flex flex-wrap items-center gap-2">
              {durationOptions.map(min => {
                const isSelected = durationMinutes === min && !customDuration;
                return (
                  <button
                    type="button"
                    key={min}
                    onClick={() => {
                      setDurationMinutes(min);
                      setCustomDuration('');
                    }}
                    className={`py-1.5 px-3 rounded-xl text-xs font-bold transition-all cursor-pointer border ${
                      isSelected
                        ? 'bg-[#2F6F68] text-white border-[#2F6F68]'
                        : 'bg-white dark:bg-[#1B2926] border-[#D9E6E1] dark:border-[#293F3A] text-[#4F6460] dark:text-[#9FB3AE] hover:border-[#2F6F68]'
                    }`}
                  >
                    {min} دقيقة
                  </button>
                );
              })}
              <div className="flex items-center gap-1">
                <input
                  type="number"
                  min="5"
                  max="480"
                  placeholder="مخصصة..."
                  value={customDuration}
                  onChange={e => setCustomDuration(e.target.value)}
                  className="w-20 px-2.5 py-1.5 rounded-xl border border-[#D9E6E1] dark:border-[#293F3A] bg-white dark:bg-[#1B2926] text-xs text-[#1E2D2B] dark:text-white focus:outline-none focus:ring-1 focus:ring-[#2F6F68]"
                />
                <span className="text-[11px] text-[#697F7A] dark:text-[#8FA5A0]">د</span>
              </div>
            </div>
          </div>

          {/* Deadline Section */}
          <div className="p-3.5 rounded-2xl bg-[#F8FCFA] dark:bg-[#14221F] border border-[#DEEDE7] dark:border-[#223832] space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-[#1E2D2B] dark:text-white flex items-center gap-1.5">
                <Calendar className="w-4 h-4 text-[#2F6F68] dark:text-[#88C6B9]" />
                الديدلاين والميعاد
              </span>
            </div>

            {/* Presets */}
            <div className="flex flex-wrap items-center gap-1.5">
              {[
                { id: 'today', label: 'النهاردة' },
                { id: 'tomorrow', label: 'بكرة' },
                { id: 'afterTomorrow', label: 'بعد بكرة' },
                { id: 'weekend', label: 'نهاية الأسبوع' },
                { id: 'custom', label: 'تاريخ مخصص' },
                { id: 'none', label: 'بدون ديدلاين' },
              ].map(p => (
                <button
                  type="button"
                  key={p.id}
                  onClick={() => handleSelectPreset(p.id as any)}
                  className={`text-[11px] font-bold px-2.5 py-1.5 rounded-lg transition-all cursor-pointer border ${
                    deadlinePreset === p.id
                      ? 'bg-[#2F6F68] text-white border-[#2F6F68]'
                      : 'bg-white dark:bg-[#1C2C28] border-[#D9E6E1] dark:border-[#293F3A] text-[#556965] dark:text-[#A1B5B0] hover:border-[#2F6F68]'
                  }`}
                >
                  {p.label}
                </button>
              ))}
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

          {/* Project selector with CustomSelect */}
          {projects.length > 0 && (
            <div>
              <label className="block text-xs font-bold text-[#2D3F3B] dark:text-[#D1E0DC] mb-1.5">
                المشروع
              </label>
              <CustomSelect
                value={projectId}
                onChange={setProjectId}
                options={[
                  {
                    value: '',
                    label: 'بدون مشروع (مهمة عامة)',
                    icon: <CheckSquare className="w-3.5 h-3.5" />,
                  },
                  ...projects.map((proj) => ({
                    value: proj.id,
                    label: proj.title,
                    color: proj.accentColor || '#2F6F68',
                    icon: <Folder className="w-3.5 h-3.5" />,
                  })),
                ]}
                placeholder="اختر المشروع..."
              />
            </div>
          )}
        </form>

        {/* Modal Actions */}
        <div className="p-4 sm:p-5 border-t border-[#E7EFEA] dark:border-[#223530] bg-[#F8FCFA] dark:bg-[#131F1C] flex items-center justify-between gap-2 flex-wrap">
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleDelete}
              className="p-2.5 rounded-xl text-[#B83A3A] hover:bg-[#FBE8E6] dark:hover:bg-[#3D1D1D] transition-colors cursor-pointer text-xs font-bold flex items-center gap-1.5"
              title="حذف المهمة"
            >
              <Trash2 className="w-4 h-4" />
              <span className="hidden sm:inline">حذف</span>
            </button>

            <button
              type="button"
              onClick={handleStartFocus}
              className="px-3 py-2 rounded-xl bg-[#EAF5F2] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9] hover:bg-[#D9ECE8] transition-colors cursor-pointer text-xs font-bold flex items-center gap-1.5"
              title="بدء جلسة تركيز لهذه المهمة"
            >
              <Play className="w-3.5 h-3.5 fill-current" />
              <span>جلسة تركيز</span>
            </button>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2.5 rounded-xl border border-[#D9E6E1] dark:border-[#293F3A] text-xs font-bold text-[#556965] dark:text-[#A1B5B0] hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer"
            >
              إلغاء
            </button>

            <button
              onClick={handleSave}
              className="px-5 py-2.5 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold flex items-center gap-1.5 shadow-sm transition-all cursor-pointer active:scale-95"
            >
              <Check className="w-4 h-4 stroke-[3]" />
              <span>حفظ التعديلات</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
