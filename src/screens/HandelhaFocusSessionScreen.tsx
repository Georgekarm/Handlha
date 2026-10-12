import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';
import {
  X,
  Play,
  Pause,
  RotateCcw,
  Sparkles,
  Volume2,
  VolumeX,
  Coffee,
  Check,
  Plus,
  Minus,
  Sliders,
  Flame,
} from 'lucide-react';

export const HandelhaFocusSessionScreen: React.FC = () => {
  const {
    activeFocusTask,
    navigate,
    triggerFocusStartNotification,
    completeFocusSession,
    triggerBreakFinishNotification,
    focusSessionsCount,
    totalFocusMinutes,
  } = useApp();

  const [selectedDuration, setSelectedDuration] = useState<number>(25 * 60); // seconds
  const [timeLeft, setTimeLeft] = useState<number>(25 * 60);
  const [isRunning, setIsRunning] = useState<boolean>(false);
  const [isBreak, setIsBreak] = useState<boolean>(false);
  const [isCompleted, setIsCompleted] = useState<boolean>(false);
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);
  const [showCustomModal, setShowCustomModal] = useState<boolean>(false);
  const [customHours, setCustomHours] = useState<number>(1);
  const [customMinutes, setCustomMinutes] = useState<number>(30);

  // Timer interval
  useEffect(() => {
    let interval: any = null;
    if (isRunning && timeLeft > 0) {
      interval = setInterval(() => {
        setTimeLeft((prev) => prev - 1);
      }, 1000);
    } else if (timeLeft === 0 && isRunning) {
      setIsRunning(false);
      setIsCompleted(true);
      if (!isBreak) {
        completeFocusSession(Math.round(selectedDuration / 60), activeFocusTask || 'جلسة تركيز هندلها');
      } else {
        triggerBreakFinishNotification();
      }
    }
    return () => clearInterval(interval);
  }, [isRunning, timeLeft, isBreak, selectedDuration, activeFocusTask, completeFocusSession, triggerBreakFinishNotification]);

  const toggleTimer = () => {
    const nextState = !isRunning;
    setIsRunning(nextState);
    if (nextState && !isBreak) {
      triggerFocusStartNotification(activeFocusTask || 'جلسة تركيز هندلها');
    }
  };

  const resetTimer = (duration: number = selectedDuration) => {
    setIsRunning(false);
    setTimeLeft(duration);
    setIsCompleted(false);
  };

  const handleSelectPreset = (minutes: number) => {
    const sec = minutes * 60;
    setSelectedDuration(sec);
    resetTimer(sec);
    setIsBreak(false);
  };

  const handleAdjustMinutes = (deltaMinutes: number) => {
    if (isRunning) return;
    const currentMins = Math.round(selectedDuration / 60);
    const nextMins = Math.max(5, Math.min(240, currentMins + deltaMinutes));
    handleSelectPreset(nextMins);
  };

  const handleApplyCustomDuration = (e: React.FormEvent) => {
    e.preventDefault();
    const totalMins = (customHours * 60) + customMinutes;
    if (totalMins > 0) {
      handleSelectPreset(totalMins);
      setShowCustomModal(false);
    }
  };

  const handleTakeBreak = () => {
    setIsBreak(true);
    const breakSec = 5 * 60;
    setSelectedDuration(breakSec);
    resetTimer(breakSec);
    setIsRunning(true);
  };

  // Format time hh:mm:ss or mm:ss
  const formatTime = (seconds: number) => {
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hrs > 0) {
      return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const getDurationHumanLabel = (seconds: number) => {
    const totalMins = Math.round(seconds / 60);
    if (totalMins === 25) return '25 دقيقة (بومودورو قياسي)';
    if (totalMins === 45) return '45 دقيقة (تركيز عميق)';
    if (totalMins === 60) return 'ساعة كاملة (60 دقيقة)';
    if (totalMins === 90) return 'ساعة ونصف (90 دقيقة)';
    if (totalMins === 120) return 'ساعتان كاملتان (120 دقيقة)';
    if (totalMins > 60) {
      const h = Math.floor(totalMins / 60);
      const m = totalMins % 60;
      return m > 0 ? `${h} ساعة و ${m} دقيقة` : `${h} ساعات كاملة`;
    }
    return `${totalMins} دقيقة تركيز`;
  };

  // Progress percentage
  const total = selectedDuration || 1;
  const progressPercent = Math.max(0, Math.min(100, Math.round(((total - timeLeft) / total) * 100)));

  return (
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] text-[#1E2D2B] dark:text-[#EFF6F2] flex flex-col justify-between p-4 sm:p-6 transition-colors duration-200">
      {/* Top Header */}
      <header className="flex items-center justify-between max-w-xl w-full mx-auto">
        <button
          onClick={() => navigate('/home')}
          className="p-2.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#637A75] dark:text-[#A1B6B1] hover:text-[#1E2D2B] dark:hover:text-white transition-colors cursor-pointer"
          title="إغلاق والعودة"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="flex items-center gap-2">
          <HandelhaMark size={32} />
          <div className="text-right">
            <span className="text-xs font-bold text-[#2F6F68] dark:text-[#80C6B9] block leading-none">
              {isBreak ? 'استراحة هادئة' : 'جلسة تركيز هندلها'}
            </span>
            <span className="text-[10px] text-[#768C87] dark:text-[#8FA39E]">
              الجلسة رقم #{focusSessionsCount + 1}
            </span>
          </div>
        </div>

        <button
          onClick={() => setSoundEnabled(!soundEnabled)}
          className="p-2.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#637A75] dark:text-[#A1B6B1] hover:text-[#1E2D2B] dark:hover:text-white transition-colors cursor-pointer"
          title={soundEnabled ? 'كتم الإشعارات الصوتية' : 'تفعيل الإشعارات الصوتية'}
        >
          {soundEnabled ? <Volume2 className="w-5 h-5" /> : <VolumeX className="w-5 h-5" />}
        </button>
      </header>

      {/* Main Focus Area */}
      <main className="flex-1 flex flex-col items-center justify-center my-4 space-y-6 max-w-xl w-full mx-auto">
        {/* Task Focus Title Card */}
        <div className="max-w-md w-full text-center space-y-2 px-4">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#E5EFEA] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9] text-xs font-bold shadow-2xs">
            {isBreak ? (
              <>
                <Coffee className="w-3.5 h-3.5" />
                <span>استراحة 5 دقائق</span>
              </>
            ) : (
              <>
                <Sparkles className="w-3.5 h-3.5 text-[#D89230]" />
                <span>المهمة الحالية للتركيز</span>
              </>
            )}
          </div>
          <h1 className="text-xl sm:text-2xl font-black text-[#1E2D2B] dark:text-white leading-relaxed">
            {isBreak ? 'تنفس بعمق واسترح عينيك قليلاً' : activeFocusTask || 'التركيز على الخطوة المحددة'}
          </h1>
          <p className="text-xs text-[#677F7A] dark:text-[#9FB3AE]">
            {getDurationHumanLabel(selectedDuration)}
          </p>
        </div>

        {/* Circular Ring Timer */}
        <div className="relative w-72 h-72 sm:w-80 sm:h-80 flex items-center justify-center select-none">
          {/* Subtle Ambient Radial Glow */}
          <div
            className={`absolute inset-4 rounded-full transition-all duration-700 blur-2xl ${
              isRunning
                ? 'bg-[#2F6F68]/15 dark:bg-[#76BCAF]/20 scale-105'
                : 'bg-transparent'
            }`}
          />

          {/* SVG Progress Circle */}
          <svg className="w-full h-full -rotate-90 transform drop-shadow-sm" viewBox="0 0 100 100">
            <defs>
              <linearGradient id="timer-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#245650" />
                <stop offset="100%" stopColor="#76BCAF" />
              </linearGradient>
            </defs>

            {/* Background track circle */}
            <circle
              cx="50"
              cy="50"
              r="43"
              className="text-[#E0ECE6] dark:text-[#1B302B]"
              strokeWidth="4.5"
              stroke="currentColor"
              fill="transparent"
            />

            {/* Active animated progress circle */}
            <circle
              cx="50"
              cy="50"
              r="43"
              stroke="url(#timer-gradient)"
              strokeWidth="5"
              strokeDasharray={270.17}
              strokeDashoffset={270.17 - (270.17 * progressPercent) / 100}
              strokeLinecap="round"
              fill="transparent"
              className="transition-all duration-1000 ease-linear"
            />
          </svg>

          {/* Time Display Inside */}
          <div className="absolute flex flex-col items-center justify-center space-y-1.5 text-center">
            <span
              className={`font-black tracking-tight font-mono text-[#1E2D2B] dark:text-white transition-all ${
                selectedDuration >= 3600 ? 'text-4xl sm:text-5xl' : 'text-5xl sm:text-6xl'
              }`}
            >
              {formatTime(timeLeft)}
            </span>

            <div className="flex items-center gap-1.5 text-xs font-bold text-[#6D847F] dark:text-[#9FB3AE]">
              {isRunning && (
                <span className="w-2 h-2 rounded-full bg-[#2F6F68] dark:bg-[#76BCAF] animate-ping" />
              )}
              <span>
                {isRunning
                  ? 'الجلسة جارية الآن'
                  : isCompleted
                  ? 'اكتملت الجلسة بنجاح!'
                  : 'جاهز للانطلاق'}
              </span>
            </div>

            {!isRunning && !isBreak && (
              <span className="text-[10px] text-[#8EA29E] dark:text-[#7A938E]">
                نسبة التقدم: {progressPercent}%
              </span>
            )}
          </div>
        </div>

        {/* Completion Celebration banner */}
        {isCompleted && (
          <div className="p-4 rounded-3xl bg-[#EEF5F2] dark:bg-[#1E332E] border border-[#CDE1D9] dark:border-[#2C4942] text-center space-y-3 max-w-sm w-full animate-bounce-subtle shadow-xs">
            <div className="w-11 h-11 mx-auto rounded-full bg-[#2F6F68] text-white flex items-center justify-center shadow-xs">
              <Check className="w-6 h-6 stroke-[3]" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                الله ينور عليك يا فنان! 🎉
              </h3>
              <p className="text-xs text-[#5D736E] dark:text-[#A2B7B2] mt-1">
                أتممت {Math.round(selectedDuration / 60)} دقيقة تركيز بنجاح وتم تسجيلها في إحصائياتك.
              </p>
            </div>
            <button
              onClick={handleTakeBreak}
              className="px-5 py-2.5 rounded-2xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold transition-all cursor-pointer shadow-2xs"
            >
              بدء استراحة 5 دقائق ☕
            </button>
          </div>
        )}

        {/* Quick Steppers (-15 min / +15 min / +30 min) */}
        {!isRunning && !isBreak && (
          <div className="flex items-center gap-2">
            <button
              onClick={() => handleAdjustMinutes(-15)}
              disabled={selectedDuration <= 15 * 60}
              className="px-3 py-1.5 rounded-xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-xs font-bold text-[#627773] dark:text-[#A1B5B0] hover:text-[#1E2D2B] dark:hover:text-white disabled:opacity-40 transition-colors cursor-pointer flex items-center gap-1"
              title="تقليل 15 دقيقة"
            >
              <Minus className="w-3 h-3" />
              <span>15 د</span>
            </button>

            <button
              onClick={() => handleAdjustMinutes(15)}
              className="px-3 py-1.5 rounded-xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:bg-[#EEF5F2] transition-colors cursor-pointer flex items-center gap-1"
              title="زيادة 15 دقيقة"
            >
              <Plus className="w-3 h-3" />
              <span>15 د</span>
            </button>

            <button
              onClick={() => handleAdjustMinutes(30)}
              className="px-3 py-1.5 rounded-xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:bg-[#EEF5F2] transition-colors cursor-pointer flex items-center gap-1"
              title="زيادة 30 دقيقة"
            >
              <Plus className="w-3 h-3" />
              <span>30 د</span>
            </button>

            <button
              onClick={() => setShowCustomModal(true)}
              className="px-3 py-1.5 rounded-xl bg-[#EAF3F0] dark:bg-[#1E3731] text-xs font-bold text-[#235D55] dark:text-[#88C6B9] hover:bg-[#D9ECE7] transition-colors cursor-pointer flex items-center gap-1"
              title="تحديد مدة مخصصة"
            >
              <Sliders className="w-3.5 h-3.5" />
              <span>مخصص</span>
            </button>
          </div>
        )}

        {/* Main Controls (Play / Pause / Reset / Break) */}
        <div className="flex items-center gap-4">
          <button
            onClick={() => resetTimer()}
            className="p-3.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#637A75] dark:text-[#A1B6B1] hover:text-[#1E2D2B] dark:hover:text-white transition-all cursor-pointer shadow-2xs hover:scale-105 active:scale-95"
            title="إعادة ضبط المؤقت"
          >
            <RotateCcw className="w-5 h-5" />
          </button>

          <button
            onClick={toggleTimer}
            className="px-10 py-4 rounded-3xl bg-linear-to-r from-[#245650] to-[#2F6F68] hover:from-[#1D4842] hover:to-[#245650] text-white font-bold flex items-center gap-2.5 shadow-md hover:shadow-lg transition-all cursor-pointer active:scale-95"
          >
            {isRunning ? (
              <>
                <Pause className="w-5 h-5 fill-current" />
                <span>إيقاف مؤقت</span>
              </>
            ) : (
              <>
                <Play className="w-5 h-5 fill-current" />
                <span>{timeLeft === 0 ? 'إعادة البدء' : 'ابدأ التركيز'}</span>
              </>
            )}
          </button>

          <button
            onClick={handleTakeBreak}
            className="p-3.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#637A75] dark:text-[#A1B6B1] hover:text-[#1E2D2B] dark:hover:text-white transition-all cursor-pointer shadow-2xs hover:scale-105 active:scale-95"
            title="استراحة 5 دقائق"
          >
            <Coffee className="w-5 h-5" />
          </button>
        </div>

        {/* Extended Duration Presets (بما يشمل أكثر من ساعة: 60 د، 90 د، 120 د) */}
        {!isRunning && !isBreak && (
          <div className="space-y-1.5 text-center">
            <span className="text-[11px] font-bold text-[#6D837E] dark:text-[#9FB3AE]">
              خيارات الوقت الجاهزة (تشمل أكثر من ساعة):
            </span>
            <div className="flex items-center gap-1.5 flex-wrap justify-center">
              {[
                { mins: 25, label: '25 د (بومودورو)' },
                { mins: 45, label: '45 د' },
                { mins: 60, label: 'ساعة (60 د)' },
                { mins: 90, label: 'ساعة ونصف (90 د)' },
                { mins: 120, label: 'ساعتان (120 د)' },
              ].map((item) => {
                const isSelected = selectedDuration === item.mins * 60 && !isBreak;
                return (
                  <button
                    key={item.mins}
                    onClick={() => handleSelectPreset(item.mins)}
                    className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-[#2F6F68] text-white shadow-xs scale-105'
                        : 'bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#647974] dark:text-[#A1B5B0] hover:bg-[#F2F7F5] dark:hover:bg-[#223631]'
                    }`}
                  >
                    {item.label}
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </main>

      {/* Gentle Footer Stats & Reminder */}
      <footer className="text-center space-y-1 text-xs text-[#7B928D] dark:text-[#8EA39F] max-w-xl mx-auto w-full pt-2">
        <div className="flex items-center justify-center gap-3 text-[11px] font-bold text-[#2F6F68] dark:text-[#80C6B9]">
          <span className="flex items-center gap-1">
            <Flame className="w-3.5 h-3.5 text-[#E68267]" />
            {focusSessionsCount} جلسات مكتملة
          </span>
          <span>•</span>
          <span>{totalFocusMinutes} دقيقة إجمالية</span>
        </div>
        <p className="text-[11px]">
          «التركيز الهادئ يولد نتائج عظيمة دون إجهاد عصبي.»
        </p>
      </footer>

      {/* Custom Duration Modal */}
      {showCustomModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm rounded-3xl bg-white dark:bg-[#182724] border border-[#D5E3DD] dark:border-[#2E4740] p-5 space-y-4 shadow-xl">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-bold text-[#1E2D2B] dark:text-white flex items-center gap-2">
                <Sliders className="w-4 h-4 text-[#2F6F68]" />
                تحديد وقت الجلسة المخصص
              </h3>
              <button
                onClick={() => setShowCustomModal(false)}
                className="p-1 rounded-xl text-[#6B807B] hover:text-[#1E2D2B] dark:hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleApplyCustomDuration} className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-bold text-[#556A65] dark:text-[#A5BBB6]">
                    الساعات (0 - 4):
                  </label>
                  <input
                    type="number"
                    min="0"
                    max="4"
                    value={customHours}
                    onChange={(e) => setCustomHours(Math.max(0, parseInt(e.target.value, 10) || 0))}
                    className="w-full p-2.5 rounded-xl border border-[#D0E0DA] dark:border-[#2F4741] bg-[#F7F9F8] dark:bg-[#152320] text-sm font-bold text-center text-[#1E2D2B] dark:text-white"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-bold text-[#556A65] dark:text-[#A5BBB6]">
                    الدقائق (0 - 59):
                  </label>
                  <input
                    type="number"
                    min="0"
                    max="59"
                    value={customMinutes}
                    onChange={(e) => setCustomMinutes(Math.max(0, parseInt(e.target.value, 10) || 0))}
                    className="w-full p-2.5 rounded-xl border border-[#D0E0DA] dark:border-[#2F4741] bg-[#F7F9F8] dark:bg-[#152320] text-sm font-bold text-center text-[#1E2D2B] dark:text-white"
                  />
                </div>
              </div>

              <div className="p-3 rounded-2xl bg-[#EEF5F2] dark:bg-[#1E332E] text-center text-xs font-bold text-[#235D55] dark:text-[#88C6B9]">
                الإجمالي: {customHours > 0 ? `${customHours} ساعة و ` : ''}{customMinutes} دقيقة
              </div>

              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setShowCustomModal(false)}
                  className="flex-1 py-2.5 rounded-xl bg-gray-100 dark:bg-[#20312D] text-xs font-bold text-[#5E736E] dark:text-[#9FB3AE] cursor-pointer"
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold transition-colors cursor-pointer shadow-xs"
                >
                  تطبيق الوقت
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
