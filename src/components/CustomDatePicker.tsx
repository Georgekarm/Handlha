import React, { useState, useRef, useEffect } from 'react';
import { Calendar as CalendarIcon, Clock, ChevronLeft, ChevronRight, Check } from 'lucide-react';

interface CustomDatePickerProps {
  selectedDate: string; // YYYY-MM-DD
  onSelectDate: (dateStr: string) => void;
  selectedTime?: string; // HH:mm
  onSelectTime?: (timeStr: string) => void;
  defaultOpen?: boolean;
}

const ARABIC_MONTHS = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const ARABIC_WEEKDAYS_SHORT = [
  'سبت',
  'أحد',
  'إثنين',
  'ثلاثاء',
  'أربعاء',
  'خميس',
  'جمعة',
];

export const CustomDatePicker: React.FC<CustomDatePickerProps> = ({
  selectedDate,
  onSelectDate,
  selectedTime = '17:00',
  onSelectTime,
  defaultOpen = false,
}) => {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  const containerRef = useRef<HTMLDivElement>(null);

  // Parse initial year and month
  const initialDate = selectedDate ? new Date(selectedDate) : new Date();
  const [currentYear, setCurrentYear] = useState(
    isNaN(initialDate.getFullYear()) ? new Date().getFullYear() : initialDate.getFullYear()
  );
  const [currentMonth, setCurrentMonth] = useState(
    isNaN(initialDate.getMonth()) ? new Date().getMonth() : initialDate.getMonth()
  );

  // Close when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  // Navigate months
  const handlePrevMonth = () => {
    if (currentMonth === 0) {
      setCurrentMonth(11);
      setCurrentYear((y) => y - 1);
    } else {
      setCurrentMonth((m) => m - 1);
    }
  };

  const handleNextMonth = () => {
    if (currentMonth === 11) {
      setCurrentMonth(0);
      setCurrentYear((y) => y + 1);
    } else {
      setCurrentMonth((m) => m + 1);
    }
  };

  // Helper to get total days in currentMonth
  const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();

  // First day of currentMonth weekday index
  // Note: in JS, 0 is Sunday, 1 is Monday, ..., 6 is Saturday.
  // In our Arabic week starting on Saturday:
  // Saturday = 0, Sunday = 1, Monday = 2, Tuesday = 3, Wednesday = 4, Thursday = 5, Friday = 6
  const getArabicDayOffset = (year: number, month: number) => {
    const jsDay = new Date(year, month, 1).getDay(); // 0 is Sun, 6 is Sat
    return (jsDay + 1) % 7;
  };

  const leadingEmptyDays = getArabicDayOffset(currentYear, currentMonth);

  // Format date display label in friendly Arabic
  const formatFriendlyDate = (dateStr: string) => {
    if (!dateStr) return 'اختر يوماً من التقويم...';
    try {
      const [y, m, d] = dateStr.split('-').map(Number);
      const dateObj = new Date(y, m - 1, d);
      const today = new Date();
      const isToday =
        dateObj.getFullYear() === today.getFullYear() &&
        dateObj.getMonth() === today.getMonth() &&
        dateObj.getDate() === today.getDate();

      const tomorrow = new Date(today);
      tomorrow.setDate(today.getDate() + 1);
      const isTomorrow =
        dateObj.getFullYear() === tomorrow.getFullYear() &&
        dateObj.getMonth() === tomorrow.getMonth() &&
        dateObj.getDate() === tomorrow.getDate();

      const weekdayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      const dayName = weekdayNames[dateObj.getDay()];
      const monthName = ARABIC_MONTHS[dateObj.getMonth()];

      if (isToday) return `النهاردة • ${dayName} ${d} ${monthName}`;
      if (isTomorrow) return `بكرة • ${dayName} ${d} ${monthName}`;
      return `${dayName}، ${d} ${monthName} ${y}`;
    } catch {
      return dateStr;
    }
  };

  // Quick preset selector
  const handleQuickSelect = (offsetDays: number) => {
    const target = new Date();
    target.setDate(target.getDate() + offsetDays);
    const y = target.getFullYear();
    const m = String(target.getMonth() + 1).padStart(2, '0');
    const d = String(target.getDate()).padStart(2, '0');
    onSelectDate(`${y}-${m}-${d}`);
    setCurrentYear(y);
    setCurrentMonth(target.getMonth());
  };

  const todayObj = new Date();
  const todayStr = `${todayObj.getFullYear()}-${String(todayObj.getMonth() + 1).padStart(2, '0')}-${String(
    todayObj.getDate()
  ).padStart(2, '0')}`;

  return (
    <div ref={containerRef} className="relative w-full space-y-2">
      {/* Trigger Button with Selected Date & Time */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <button
          type="button"
          onClick={() => setIsOpen(!isOpen)}
          className={`w-full px-3.5 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center justify-between cursor-pointer border text-right ${
            isOpen
              ? 'border-[#2F6F68] dark:border-[#76BCAF] ring-2 ring-[#2F6F68]/20 bg-white dark:bg-[#1A2825]'
              : 'border-[#DCE5E0] dark:border-[#2B423C] bg-[#F9FAF8] dark:bg-[#1E302C] hover:border-[#2F6F68]/60'
          }`}
        >
          <div className="flex items-center gap-2 truncate">
            <CalendarIcon className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF] shrink-0" />
            <span className="truncate text-[#1E2D2B] dark:text-white">
              {formatFriendlyDate(selectedDate)}
            </span>
          </div>
          <span className="text-[10px] text-[#2F6F68] dark:text-[#76BCAF] font-bold shrink-0 mr-1">
            {isOpen ? 'إغلاق ✕' : 'تغيير ▾'}
          </span>
        </button>

        {/* Time input */}
        {onSelectTime && (
          <div className="relative">
            <div className="flex items-center gap-1.5 w-full px-3.5 py-2.5 rounded-2xl bg-[#F9FAF8] dark:bg-[#1E302C] border border-[#DCE5E0] dark:border-[#2B423C] text-xs font-bold text-[#1E2D2B] dark:text-white">
              <Clock className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF] shrink-0" />
              <span className="text-[11px] text-[#637772] dark:text-[#95ABA5] shrink-0">
                الساعة:
              </span>
              <input
                type="time"
                value={selectedTime}
                onChange={(e) => onSelectTime(e.target.value)}
                className="bg-transparent border-none text-xs font-bold text-[#1E2D2B] dark:text-white focus:outline-hidden w-full cursor-pointer"
              />
            </div>
          </div>
        )}
      </div>

      {/* Interactive Calendar Dropdown / Popover */}
      {isOpen && (
        <div className="p-3.5 rounded-2xl bg-white dark:bg-[#182724] border border-[#D5E3DE] dark:border-[#2A413B] shadow-xl space-y-3 animate-in fade-in slide-in-from-top-2 duration-150 z-40">
          {/* Quick Presets Pills */}
          <div className="flex items-center gap-1.5 flex-wrap pb-2 border-b border-[#E8EFEA] dark:border-[#243A34]">
            {[
              { label: 'النهاردة', offset: 0 },
              { label: 'بكرة', offset: 1 },
              { label: 'بعد بكرة', offset: 2 },
              { label: 'الأسبوع القادم', offset: 7 },
            ].map((preset) => (
              <button
                key={preset.label}
                type="button"
                onClick={() => handleQuickSelect(preset.offset)}
                className="px-2.5 py-1 rounded-xl text-[11px] font-bold bg-[#EAF5F2] dark:bg-[#203D37] text-[#245650] dark:text-[#88C6B9] hover:bg-[#D4EBE5] transition-colors cursor-pointer"
              >
                {preset.label}
              </button>
            ))}
          </div>

          {/* Month / Year Navigator */}
          <div className="flex items-center justify-between px-1">
            <button
              type="button"
              onClick={handlePrevMonth}
              className="p-1.5 rounded-xl hover:bg-black/5 dark:hover:bg-white/5 text-[#5F7570] dark:text-[#9DB3AE] transition-colors cursor-pointer"
              title="الشهر السابق"
            >
              <ChevronRight className="w-4 h-4" />
            </button>

            <span className="text-xs font-bold text-[#1E2D2B] dark:text-white">
              {ARABIC_MONTHS[currentMonth]} {currentYear}
            </span>

            <button
              type="button"
              onClick={handleNextMonth}
              className="p-1.5 rounded-xl hover:bg-black/5 dark:hover:bg-white/5 text-[#5F7570] dark:text-[#9DB3AE] transition-colors cursor-pointer"
              title="الشهر القادم"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
          </div>

          {/* Weekday Row */}
          <div className="grid grid-cols-7 gap-1 text-center text-[10px] font-bold text-[#6D827E] dark:text-[#9FB3AE]">
            {ARABIC_WEEKDAYS_SHORT.map((wd) => (
              <div key={wd} className="py-1">
                {wd}
              </div>
            ))}
          </div>

          {/* Days Grid */}
          <div className="grid grid-cols-7 gap-1">
            {/* Empty Leading Days */}
            {Array.from({ length: leadingEmptyDays }).map((_, idx) => (
              <div key={`empty-${idx}`} className="aspect-square" />
            ))}

            {/* Month Days */}
            {Array.from({ length: daysInMonth }).map((_, idx) => {
              const dayNum = idx + 1;
              const dateKey = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(
                dayNum
              ).padStart(2, '0')}`;
              const isSelected = selectedDate === dateKey;
              const isToday = todayStr === dateKey;

              return (
                <button
                  key={dayNum}
                  type="button"
                  onClick={() => {
                    onSelectDate(dateKey);
                    // keep open or close
                  }}
                  className={`aspect-square rounded-xl text-xs font-bold transition-all cursor-pointer flex flex-col items-center justify-center relative ${
                    isSelected
                      ? 'bg-[#2F6F68] text-white shadow-xs scale-105 z-10'
                      : isToday
                      ? 'bg-[#EAF5F2] dark:bg-[#1E3832] text-[#2F6F68] dark:text-[#88C6B9] border border-[#2F6F68]/30 font-extrabold'
                      : 'text-[#2D3F3B] dark:text-[#D5E4DF] hover:bg-[#F0F5F2] dark:hover:bg-[#20332E]'
                  }`}
                >
                  <span>{dayNum}</span>
                  {isToday && !isSelected && (
                    <span className="w-1 h-1 rounded-full bg-[#E27D66] absolute bottom-1" />
                  )}
                </button>
              );
            })}
          </div>

          {/* Quick Time Presets & Confirm */}
          {onSelectTime && (
            <div className="pt-2 border-t border-[#E8EFEA] dark:border-[#243A34] flex items-center justify-between gap-2 flex-wrap text-xs">
              <div className="flex items-center gap-1">
                <span className="text-[10px] text-[#637974] dark:text-[#9DB2AD]">
                  أوقات شائعة:
                </span>
                {[
                  { label: '09:00 ص', val: '09:00' },
                  { label: '01:00 م', val: '13:00' },
                  { label: '05:00 م', val: '17:00' },
                  { label: '09:00 م', val: '21:00' },
                ].map((t) => (
                  <button
                    key={t.val}
                    type="button"
                    onClick={() => onSelectTime(t.val)}
                    className={`px-1.5 py-0.5 rounded-md text-[10px] font-bold cursor-pointer transition-colors ${
                      selectedTime === t.val
                        ? 'bg-[#2F6F68] text-white'
                        : 'bg-[#F0F5F2] dark:bg-[#1E302C] text-[#3B4E4A] dark:text-[#CBDCD7] hover:bg-[#E3EEE9]'
                    }`}
                  >
                    {t.label}
                  </button>
                ))}
              </div>

              <button
                type="button"
                onClick={() => setIsOpen(false)}
                className="px-3 py-1.5 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white font-bold text-xs cursor-pointer flex items-center gap-1 mr-auto transition-all"
              >
                <Check className="w-3.5 h-3.5" />
                <span>تم</span>
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
