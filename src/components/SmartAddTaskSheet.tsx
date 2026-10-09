import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import {
  X,
  Sparkles,
  Mic,
  Flag,
  Layers,
  Clock,
  Calendar,
  Zap,
  ChevronDown,
  ChevronUp,
  Check,
} from 'lucide-react';
import { TaskPriority } from '../types';

export const SmartAddTaskSheet: React.FC = () => {
  const { isSmartAddOpen, setIsSmartAddOpen, createTask, isDarkMode } = useApp();

  const [input, setInput] = useState('');
  const [title, setTitle] = useState('');
  const [notes, setNotes] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [priority, setPriority] = useState<TaskPriority>('high');
  const [phase, setPhase] = useState('مرحلة التطوير');
  const [duration, setDuration] = useState('45 دقيقة');
  const [dueDate, setDueDate] = useState('غداً، 2:00 م');
  const [showManualForm, setShowManualForm] = useState(true);

  const phases = ['التخطيط', 'التصميم', 'مرحلة التطوير', 'الاختبار والإطلاق'];
  const durations = ['20 دقيقة', '30 دقيقة', '45 دقيقة', '60 دقيقة', '90 دقيقة'];
  const dates = ['اليوم، 5:00 م', 'غداً، 2:00 م', 'الخميس، 12:00 م', 'نهاية الأسبوع'];

  useEffect(() => {
    if (!input.trim()) return;

    setTitle(input);

    const t = input.toLowerCase();
    if (t.includes('عاجل') || t.includes('ضروري') || t.includes('طوارئ') || t.includes('طحن') || t.includes('موت')) {
      setPriority('urgent');
    } else if (t.includes('مهم') || t.includes('عالي') || t.includes('أولوية') || t.includes('لازم')) {
      setPriority('high');
    } else if (t.includes('هادي') || t.includes('خفيف') || t.includes('بسيط') || t.includes('رايق') || t.includes('على الهادي')) {
      setPriority('low');
    } else {
      setPriority('medium');
    }

    if (t.includes('تصميم') || t.includes('ديزاين') || t.includes('ui') || t.includes('واجهة') || t.includes('ألوان')) {
      setPhase('التصميم');
    } else if (t.includes('تطوير') || t.includes('كود') || t.includes('برمجة') || t.includes('دخول') || t.includes('فرونت') || t.includes('باك')) {
      setPhase('مرحلة التطوير');
    } else if (t.includes('تخطيط') || t.includes('أفكار') || t.includes('خطة') || t.includes('ترتيب')) {
      setPhase('التخطيط');
    } else if (t.includes('اختبار') || t.includes('تست') || t.includes('إطلاق') || t.includes('نشر')) {
      setPhase('الاختبار والإطلاق');
    }

    if (t.includes('ساعة')) {
      setDuration(t.includes('نص') ? '30 دقيقة' : '60 دقيقة');
    } else if (t.includes('ربع')) {
      setDuration('15 دقيقة');
    } else if (t.includes('تلت')) {
      setDuration('20 دقيقة');
    } else if (t.includes('دقيقة') || t.includes('دقايق')) {
      setDuration('25 دقيقة');
    } else {
      setDuration('45 دقيقة');
    }

    if (t.includes('النهاردة') || t.includes('اليوم')) {
      setDueDate('اليوم، 5:00 م');
    } else if (t.includes('بكرة') || t.includes('غداً')) {
      setDueDate('غداً، 2:00 م');
    } else if (t.includes('الخميس')) {
      setDueDate('الخميس، 12:00 م');
    } else if (t.includes('الجمعة')) {
      setDueDate('الجمعة، 4:00 م');
    }
  }, [input]);

  if (!isSmartAddOpen) return null;

  const handleVoiceToggle = () => {
    setIsListening(true);
    setTimeout(() => {
      setInput('إنهاء شاشة تسجيل الدخول بكرة بعد الضهر محتاجة 45 دقيقة أولوية عالية');
      setIsListening(false);
    }, 1200);
  };

  const handleQuickTemplate = () => {
    setInput('مكالمة المهندس ومراجعة المستلزمات النهاردة بعد العصر تاخد ربع ساعة على الرايق');
  };

  const cyclePriority = () => {
    const list: TaskPriority[] = ['low', 'medium', 'high', 'urgent'];
    const idx = list.indexOf(priority);
    setPriority(list[(idx + 1) % list.length]);
  };

  const cyclePhase = () => {
    const idx = phases.indexOf(phase);
    setPhase(phases[(idx + 1) % phases.length]);
  };

  const cycleDuration = () => {
    const idx = durations.indexOf(duration);
    setDuration(durations[(idx + 1) % durations.length]);
  };

  const cycleDueDate = () => {
    const idx = dates.indexOf(dueDate);
    setDueDate(dates[(idx + 1) % dates.length]);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const taskTitle = title.trim() || input.trim();
    if (!taskTitle) return;

    let targetDueAt: string | undefined = undefined;
    const now = new Date();
    if (dueDate.includes('اليوم')) {
      now.setHours(17, 0, 0, 0);
      targetDueAt = now.toISOString();
    } else if (dueDate.includes('غداً') || dueDate.includes('بكرة')) {
      now.setDate(now.getDate() + 1);
      now.setHours(14, 0, 0, 0);
      targetDueAt = now.toISOString();
    } else {
      now.setDate(now.getDate() + 2);
      targetDueAt = now.toISOString();
    }

    createTask({
      title: taskTitle,
      description: notes.trim() || undefined,
      priority,
      status: 'planned',
      estimatedDurationMinutes: parseInt(duration) || 45,
      timeSlot: dueDate,
      dueAt: targetDueAt,
      source: 'ai',
    });

    setIsSmartAddOpen(false);
    setInput('');
    setTitle('');
    setNotes('');
  };

  const getPriorityInfo = (p: TaskPriority) => {
    switch (p) {
      case 'urgent':
        return { label: 'عاجلة', color: 'text-[#B96368] dark:text-[#D58B91]', bg: 'bg-[#F4DFE0] dark:bg-[#3D2527]' };
      case 'high':
        return { label: 'عالية', color: 'text-[#C9826C] dark:text-[#D39A83]', bg: 'bg-[#F3E1DB] dark:bg-[#563A32]' };
      case 'medium':
        return { label: 'متوسطة', color: 'text-[#B7863C] dark:text-[#D4B16B]', bg: 'bg-[#F5EBCF] dark:bg-[#3A3223]' };
      case 'low':
        return { label: 'هادئة', color: 'text-[#2F6F68] dark:text-[#76BCAF]', bg: 'bg-[#D9ECE8] dark:bg-[#244F48]' };
    }
  };

  const priorityMeta = getPriorityInfo(priority);

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-xs p-0 sm:p-4 overflow-y-auto animate-in fade-in duration-200">
      <div className="w-full max-w-xl rounded-t-3xl sm:rounded-3xl p-6 max-h-[92vh] overflow-y-auto shadow-2xl transition-all bg-white dark:bg-[#182724] border border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-[#EFF6F2]">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-[#D9ECE8] dark:bg-[#244F48] text-[#245650] dark:text-[#9DD2C5]">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-xl font-extrabold flex items-center gap-2">
                <span>إضافة مهمة ذكية</span>
                <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-[#2F6F68]/10 text-[#2F6F68] dark:bg-[#76BCAF]/20 dark:text-[#76BCAF]">
                  مصري 🇪🇬
                </span>
              </h3>
              <p className="text-xs text-[#647370] dark:text-[#B7C9C2]">
                اكتبها بالعامية المصرية أو قولها بصوتك، وهنهندلها ونرتبها لك
              </p>
            </div>
          </div>
          <button
            onClick={() => setIsSmartAddOpen(false)}
            className="p-1 rounded-full hover:bg-black/5 dark:hover:bg-white/10 text-[#99A6A2]"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div
          className={`rounded-2xl p-4 border transition-all ${
            isListening
              ? 'border-[#B96368] ring-2 ring-[#B96368]/20 bg-[#F4DFE0]/30 dark:bg-[#3D2527]/30'
              : 'bg-[#F7F8F6] dark:bg-[#203530] border-[#DDE7E2] dark:border-[#354D46]'
          }`}
        >
          <textarea
            autoFocus
            rows={3}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="مثال: أخلّص شاشة تسجيل الدخول بكرة بعد الضهر هتاخد 45 دقيقة وأولوية عالية على الرايق..."
            className="w-full bg-transparent resize-none border-none focus:outline-hidden text-sm leading-relaxed text-[#1E2D2B] dark:text-[#EFF6F2] placeholder-[#99A6A2] dark:placeholder-[#81948E]"
          />

          <div className="flex items-center justify-between pt-2 border-t border-black/5 dark:border-white/5">
            <button
              type="button"
              onClick={handleVoiceToggle}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-bold transition-all cursor-pointer ${
                isListening
                  ? 'bg-[#B96368] text-white animate-pulse'
                  : 'bg-white dark:bg-[#182724] border border-[#DDE7E2] dark:border-[#354D46] text-[#2F6F68] dark:text-[#76BCAF]'
              }`}
            >
              <Mic className="w-3.5 h-3.5" />
              {isListening ? 'بيسمعك دلوقتي...' : 'تسجيل صوتي'}
            </button>

            <button
              type="button"
              onClick={handleQuickTemplate}
              className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-lg bg-[#D9ECE8]/60 dark:bg-[#244F48]/60 text-[#245650] dark:text-[#9DD2C5] hover:opacity-80 cursor-pointer"
            >
              <Zap className="w-3 h-3" />
              تجربة سريعة
            </button>
          </div>
        </div>

        <div className="mt-4 p-4 rounded-2xl bg-[#EEF3F0]/60 dark:bg-[#203530]/50 border border-[#DDE7E2] dark:border-[#354D46]">
          <div className="flex items-center gap-2 mb-2.5">
            <Sparkles className="w-4 h-4 text-[#B7863C] dark:text-[#D4B16B]" />
            <span className="text-xs font-bold text-[#1E2D2B] dark:text-[#EFF6F2]">
              فهمت منك (شرائح ذكية قابلة للتبديل بالضغط):
            </span>
          </div>

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={cyclePriority}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border border-current/20 cursor-pointer transition-transform active:scale-95 ${priorityMeta.bg} ${priorityMeta.color}`}
            >
              <Flag className="w-3.5 h-3.5" />
              الأولوية: {priorityMeta.label}
            </button>

            <button
              type="button"
              onClick={cyclePhase}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-[#D9ECE8] dark:bg-[#244F48] text-[#245650] dark:text-[#9DD2C5] border border-current/20 cursor-pointer transition-transform active:scale-95"
            >
              <Layers className="w-3.5 h-3.5" />
              المرحلة: {phase}
            </button>

            <button
              type="button"
              onClick={cycleDuration}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-[#E9E8F2] dark:bg-[#3D3B5C] text-[#7773A1] dark:text-[#A9A7CD] border border-current/20 cursor-pointer transition-transform active:scale-95"
            >
              <Clock className="w-3.5 h-3.5" />
              المدة: {duration}
            </button>

            <button
              type="button"
              onClick={cycleDueDate}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-[#E2EDF4] dark:bg-[#29423B] text-[#5683A5] dark:text-[#8CB4D1] border border-current/20 cursor-pointer transition-transform active:scale-95"
            >
              <Calendar className="w-3.5 h-3.5" />
              الموعد: {dueDate}
            </button>
          </div>
        </div>

        <div className="mt-4">
          <button
            type="button"
            onClick={() => setShowManualForm(!showManualForm)}
            className="w-full flex items-center justify-between py-2 text-xs font-bold text-[#647370] dark:text-[#B7C9C2] hover:opacity-80"
          >
            <span>النموذج اليدوي للتأكيد والتعديل</span>
            {showManualForm ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>

          {showManualForm && (
            <div className="mt-2 space-y-3">
              <div>
                <label className="block text-xs font-semibold mb-1 text-[#647370] dark:text-[#B7C9C2]">
                  اسم المهمة
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="عنوان المهمة..."
                  className={`w-full px-3.5 py-2.5 rounded-xl text-sm border focus:outline-hidden ${
                    isDarkMode
                      ? 'bg-[#203530] border-[#354D46] text-white'
                      : 'bg-[#F7F8F6] border-[#DDE7E2] text-[#1E2D2B]'
                  }`}
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className={`p-3 rounded-xl border ${isDarkMode ? 'bg-[#203530] border-[#354D46]' : 'bg-[#F7F8F6] border-[#DDE7E2]'}`}>
                  <span className="text-[10px] font-semibold text-[#99A6A2]">الموعد</span>
                  <div className="font-bold text-xs mt-0.5">{dueDate}</div>
                </div>
                <div className={`p-3 rounded-xl border ${isDarkMode ? 'bg-[#203530] border-[#354D46]' : 'bg-[#F7F8F6] border-[#DDE7E2]'}`}>
                  <span className="text-[10px] font-semibold text-[#99A6A2]">المدة التقديرية</span>
                  <div className="font-bold text-xs mt-0.5">{duration}</div>
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1 text-[#647370] dark:text-[#B7C9C2]">
                  ملاحظات وتفاصيل إضافية (اختياري)
                </label>
                <textarea
                  rows={2}
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="أي روابط أو نقاط فرعية..."
                  className={`w-full px-3.5 py-2.5 rounded-xl text-sm border focus:outline-hidden ${
                    isDarkMode
                      ? 'bg-[#203530] border-[#354D46] text-white'
                      : 'bg-[#F7F8F6] border-[#DDE7E2] text-[#1E2D2B]'
                  }`}
                />
              </div>
            </div>
          )}
        </div>

        <div className="mt-6 flex items-center gap-3">
          <button
            type="button"
            onClick={handleSubmit}
            className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl font-bold text-sm bg-[#245650] text-white dark:bg-[#9DD2C5] dark:text-[#101A18] hover:opacity-90 transition-opacity cursor-pointer"
          >
            <Check className="w-4 h-4" />
            إضافة المهمة للمشروع
          </button>
          <button
            type="button"
            onClick={() => setIsSmartAddOpen(false)}
            className="px-5 py-3 rounded-xl font-bold text-sm border border-[#DDE7E2] dark:border-[#354D46] text-[#647370] dark:text-[#B7C9C2] hover:bg-black/5 dark:hover:bg-white/5 cursor-pointer"
          >
            إلغاء
          </button>
        </div>
      </div>
    </div>
  );
};
