import React from 'react';
import { useApp } from '../context/AppContext';
import { Bell, Sparkles, Moon, AlertCircle, ArrowLeft, X, CheckCheck } from 'lucide-react';

export const SmartNotificationToast: React.FC = () => {
  const { activeToast, dismissToast, navigate, markNotificationRead, setActiveFocusTask } = useApp();

  if (!activeToast) return null;

  const handleAction = () => {
    if (activeToast.id) {
      markNotificationRead(activeToast.id);
    }
    if (activeToast.actionUrl) {
      if (activeToast.actionUrl === '/focus-session' && activeToast.title) {
        // Find task title if available
        setActiveFocusTask(activeToast.title.includes('مهمة') ? activeToast.title : 'جلسة تركيز هندلها');
      }
      navigate(activeToast.actionUrl, { targetTaskId: activeToast.taskId });
    }
    dismissToast();
  };

  const getIcon = () => {
    switch (activeToast.category) {
      case 'encouragement':
        return <Sparkles className="w-5 h-5 text-[#B77322] dark:text-[#E9BE88]" />;
      case 'focus':
        return <Moon className="w-5 h-5 text-[#3E7092] dark:text-[#8CBEDC]" />;
      case 'important':
        return <AlertCircle className="w-5 h-5 text-[#C44A42] dark:text-[#E88E88]" />;
      case 'reminder':
      default:
        return <Bell className="w-5 h-5 text-[#2F6F68] dark:text-[#88C6B9]" />;
    }
  };

  const getBorderColor = () => {
    switch (activeToast.category) {
      case 'encouragement':
        return 'border-[#F5C78E]/60 dark:border-[#B77322]/50 bg-[#FDF9F3] dark:bg-[#2A231B]';
      case 'focus':
        return 'border-[#94BCD8]/60 dark:border-[#3E7092]/50 bg-[#F3F7FA] dark:bg-[#1A2631]';
      case 'important':
        return 'border-[#EFA39E]/60 dark:border-[#C44A42]/50 bg-[#FDF5F5] dark:bg-[#2C1C1C]';
      case 'reminder':
      default:
        return 'border-[#2F6F68]/30 dark:border-[#76BCAF]/40 bg-white dark:bg-[#182925]';
    }
  };

  return (
    <div className="fixed top-4 inset-x-0 z-50 pointer-events-none flex justify-center px-4 animate-in fade-in slide-in-from-top-4 duration-300">
      <div
        className={`pointer-events-auto max-w-md w-full rounded-3xl border shadow-xl backdrop-blur-md p-4 transition-all ${getBorderColor()}`}
      >
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 rounded-2xl bg-white/80 dark:bg-black/20 flex items-center justify-center shrink-0 shadow-2xs">
            {getIcon()}
          </div>

          <div className="flex-1 min-w-0 space-y-1">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[11px] font-bold text-[#2F6F68] dark:text-[#76BCAF]">
                تنبيه ذكي من هندلها
              </span>
              <button
                onClick={dismissToast}
                className="text-[#788E89] hover:text-[#1E2D2B] dark:hover:text-white p-1 rounded-lg cursor-pointer"
                title="إغلاق"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <h4 className="text-sm font-bold text-[#1E2D2B] dark:text-white leading-snug">
              {activeToast.title}
            </h4>

            <p className="text-xs text-[#526662] dark:text-[#A7BCB7] leading-relaxed">
              {activeToast.body}
            </p>

            {activeToast.actionLabel && (
              <div className="pt-2 flex items-center gap-2">
                <button
                  onClick={handleAction}
                  className="px-3.5 py-1.5 rounded-xl bg-[#2F6F68] dark:bg-[#76BCAF] text-white dark:text-[#101A18] text-xs font-bold hover:opacity-90 transition-all flex items-center gap-1.5 cursor-pointer shadow-xs active:scale-95"
                >
                  <span>{activeToast.actionLabel}</span>
                  <ArrowLeft className="w-3.5 h-3.5" />
                </button>
                <button
                  onClick={dismissToast}
                  className="px-2.5 py-1.5 rounded-xl text-xs text-[#6A7E7A] dark:text-[#9FB3AE] hover:underline cursor-pointer"
                >
                  بعدين
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
