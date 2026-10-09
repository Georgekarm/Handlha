import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaLogo, HandelhaMark } from '../components/HandelhaBrand';
import {
  X,
  Play,
  Pause,
  RotateCcw,
  Sparkles,
  Volume2,
  VolumeX,
  CheckCircle2,
  Coffee,
  Check,
} from 'lucide-react';

export const HandelhaFocusSessionScreen: React.FC = () => {
  const { activeFocusTask, navigate, isDarkMode } = useApp();

  const [selectedDuration, setSelectedDuration] = useState<number>(25 * 60); // seconds
  const [timeLeft, setTimeLeft] = useState<number>(25 * 60);
  const [isRunning, setIsRunning] = useState<boolean>(false);
  const [isBreak, setIsBreak] = useState<boolean>(false);
  const [isCompleted, setIsCompleted] = useState<boolean>(false);
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);

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
    }
    return () => clearInterval(interval);
  }, [isRunning, timeLeft]);

  const toggleTimer = () => {
    setIsRunning(!isRunning);
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

  const handleTakeBreak = () => {
    setIsBreak(true);
    const breakSec = 5 * 60;
    setSelectedDuration(breakSec);
    resetTimer(breakSec);
    setIsRunning(true);
  };

  // Format time mm:ss
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Progress percentage
  const total = selectedDuration || 1;
  const progressPercent = Math.max(0, Math.min(100, Math.round(((total - timeLeft) / total) * 100)));

  return (
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#0F1816] text-[#1E2D2B] dark:text-[#EAF3EF] flex flex-col justify-between p-6">
      {/* Top Header */}
      <header className="flex items-center justify-between">
        <button
          onClick={() => navigate('/home')}
          className="p-2.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#637A75] dark:text-[#A1B6B1] hover:text-[#1E2D2B] dark:hover:text-white transition-colors cursor-pointer"
          title="إغلاق الجلسة"
        >
          <X className="w-5 h-5" />
        </button>

        <div className="flex items-center gap-2">
          <HandelhaMark size={32} />
          <span className="text-xs font-bold text-[#2F6F68] dark:text-[#80C6B9]">
            {isBreak ? 'استراحة هادئة' : 'جلسة تركيز هندلها'}
          </span>
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
      <main className="flex-1 flex flex-col items-center justify-center my-6 space-y-8">
        {/* Task Focus Title Card */}
        <div className="max-w-md w-full text-center space-y-2 px-4">
          <span className="text-[11px] font-bold px-3 py-1 rounded-full bg-[#E5EFEA] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9]">
            {isBreak ? '☕ استراحة 5 دقائق' : '🎯 المهمة الحالية'}
          </span>
          <h1 className="text-xl sm:text-2xl font-bold text-[#1E2D2B] dark:text-white leading-relaxed">
            {isBreak ? 'تنفس بعمق واسترح عينيك قليلاً' : activeFocusTask || 'التركيز على الخطوة المحددة'}
          </h1>
        </div>

        {/* Circular / Ring Timer */}
        <div className="relative w-64 h-64 sm:w-72 sm:h-72 flex items-center justify-center">
          {/* Outer SVG Ring */}
          <svg className="w-full h-full -rotate-90 transform" viewBox="0 0 100 100">
            {/* Background circle */}
            <circle
              cx="50"
              cy="50"
              r="44"
              className="text-[#E2ECE7] dark:text-[#1F332E]"
              strokeWidth="5"
              stroke="currentColor"
              fill="transparent"
            />
            {/* Progress circle */}
            <circle
              cx="50"
              cy="50"
              r="44"
              className="text-[#2F6F68] dark:text-[#76BCAF] transition-all duration-1000 ease-linear"
              strokeWidth="5"
              strokeDasharray={276.46}
              strokeDashoffset={276.46 - (276.46 * progressPercent) / 100}
              strokeLinecap="round"
              stroke="currentColor"
              fill="transparent"
            />
          </svg>

          {/* Time Display Inside */}
          <div className="absolute flex flex-col items-center justify-center space-y-1">
            <span className="text-5xl sm:text-6xl font-black tracking-tight font-mono text-[#1E2D2B] dark:text-white">
              {formatTime(timeLeft)}
            </span>
            <span className="text-xs text-[#718883] dark:text-[#9FB5B0] font-medium">
              {isRunning ? 'الجلسة جارية الآن' : isCompleted ? 'اكتملت الجلسة بنجاح!' : 'جاهز للبدء'}
            </span>
          </div>
        </div>

        {/* Completion Celebration banner */}
        {isCompleted && (
          <div className="p-4 rounded-3xl bg-[#EEF5F2] dark:bg-[#1E332E] border border-[#CDE1D9] dark:border-[#2C4942] text-center space-y-3 max-w-sm w-full animate-bounce-subtle">
            <div className="w-10 h-10 mx-auto rounded-full bg-[#2F6F68] text-white flex items-center justify-center">
              <Check className="w-5 h-5 stroke-[3]" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                الله ينور عليك! 🎉
              </h3>
              <p className="text-xs text-[#5D736E] dark:text-[#A2B7B2]">
                أتممت جلسة التركيز بنجاح. وقت استراحة قصيرة لتجديد نشاطك.
              </p>
            </div>
            <button
              onClick={handleTakeBreak}
              className="px-4 py-2 rounded-xl bg-[#2F6F68] text-white text-xs font-bold hover:bg-[#245650] cursor-pointer"
            >
              بدء استراحة 5 دقائق ☕
            </button>
          </div>
        )}

        {/* Controls */}
        <div className="flex items-center gap-4">
          <button
            onClick={() => resetTimer()}
            className="p-3.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#637A75] dark:text-[#A1B6B1] hover:text-[#1E2D2B] dark:hover:text-white transition-all cursor-pointer"
            title="إعادة ضبط المؤقت"
          >
            <RotateCcw className="w-5 h-5" />
          </button>

          <button
            onClick={toggleTimer}
            className="px-8 py-4 rounded-3xl bg-[#2F6F68] hover:bg-[#245650] text-white font-bold flex items-center gap-2.5 shadow-md hover:shadow-lg transition-all cursor-pointer active:scale-95"
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
            className="p-3.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#637A75] dark:text-[#A1B6B1] hover:text-[#1E2D2B] dark:hover:text-white transition-all cursor-pointer"
            title="استراحة 5 دقائق"
          >
            <Coffee className="w-5 h-5" />
          </button>
        </div>

        {/* Duration Presets */}
        <div className="flex items-center gap-2">
          {[15, 25, 45, 60].map((mins) => {
            const isSelected = selectedDuration === mins * 60 && !isBreak;
            return (
              <button
                key={mins}
                onClick={() => handleSelectPreset(mins)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                  isSelected
                    ? 'bg-[#2F6F68] text-white shadow-xs'
                    : 'bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#647974] dark:text-[#A1B5B0] hover:bg-[#F2F7F5] dark:hover:bg-[#223631]'
                }`}
              >
                {mins} د
              </button>
            );
          })}
        </div>
      </main>

      {/* Gentle Footer Reminder */}
      <footer className="text-center text-xs text-[#7B928D] dark:text-[#8EA39F]">
        «التركيز الهادئ يولد نتائج عظيمة دون إجهاد عصبي.»
      </footer>
    </div>
  );
};
