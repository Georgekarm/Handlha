import React, { useState, useRef, useEffect } from 'react';
import { ChevronDown, Check } from 'lucide-react';

export interface SelectOption {
  value: string;
  label: string;
  icon?: React.ReactNode;
  color?: string;
  badge?: string;
}

interface CustomSelectProps {
  value: string;
  onChange: (value: string) => void;
  options: SelectOption[];
  placeholder?: string;
  className?: string;
  disabled?: boolean;
}

export const CustomSelect: React.FC<CustomSelectProps> = ({
  value,
  onChange,
  options,
  placeholder = 'اختر...',
  className = '',
  disabled = false,
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  // Close on outside click
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

  const selectedOption = options.find((opt) => opt.value === value);

  return (
    <div ref={containerRef} className={`relative w-full ${className}`}>
      {/* Trigger Button */}
      <button
        type="button"
        disabled={disabled}
        onClick={() => setIsOpen(!isOpen)}
        className={`w-full px-3.5 py-2.5 rounded-2xl text-xs font-bold transition-all flex items-center justify-between cursor-pointer border text-right ${
          isOpen
            ? 'border-[#2F6F68] dark:border-[#76BCAF] ring-2 ring-[#2F6F68]/20 bg-white dark:bg-[#1A2825]'
            : 'border-[#DCE5E0] dark:border-[#2B423C] bg-[#F9FAF8] dark:bg-[#1E302C] hover:border-[#2F6F68]/60'
        } ${disabled ? 'opacity-50 cursor-not-allowed' : ''}`}
      >
        <div className="flex items-center gap-2 min-w-0">
          {selectedOption?.icon && (
            <span className="shrink-0">{selectedOption.icon}</span>
          )}
          {selectedOption?.color && (
            <span
              className="w-2.5 h-2.5 rounded-full shrink-0"
              style={{ backgroundColor: selectedOption.color }}
            />
          )}
          <span className="truncate text-[#1E2D2B] dark:text-white">
            {selectedOption ? selectedOption.label : placeholder}
          </span>
        </div>

        <ChevronDown
          className={`w-4 h-4 text-[#7B928D] dark:text-[#90A7A2] shrink-0 transition-transform duration-200 ${
            isOpen ? 'rotate-180 text-[#2F6F68] dark:text-[#76BCAF]' : ''
          }`}
        />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <div className="absolute z-50 mt-1.5 inset-x-0 bg-white dark:bg-[#182724] border border-[#DCE5E0] dark:border-[#2A413B] rounded-2xl shadow-xl overflow-hidden py-1.5 animate-in fade-in slide-in-from-top-2 duration-150 max-h-60 overflow-y-auto">
          {options.map((opt) => {
            const isSelected = opt.value === value;
            return (
              <button
                key={opt.value}
                type="button"
                onClick={() => {
                  onChange(opt.value);
                  setIsOpen(false);
                }}
                className={`w-full px-3.5 py-2.5 flex items-center justify-between text-xs font-semibold cursor-pointer transition-colors text-right ${
                  isSelected
                    ? 'bg-[#EAF5F2] dark:bg-[#203D37] text-[#245650] dark:text-[#88C6B9] font-bold'
                    : 'text-[#2D3F3B] dark:text-[#D5E4DF] hover:bg-[#F2F7F5] dark:hover:bg-[#1F332E]'
                }`}
              >
                <div className="flex items-center gap-2.5 min-w-0">
                  {opt.icon && (
                    <span className="shrink-0 text-[#2F6F68] dark:text-[#76BCAF]">
                      {opt.icon}
                    </span>
                  )}
                  {opt.color && (
                    <span
                      className="w-2.5 h-2.5 rounded-full shrink-0"
                      style={{ backgroundColor: opt.color }}
                    />
                  )}
                  <span className="truncate">{opt.label}</span>
                  {opt.badge && (
                    <span className="text-[10px] px-1.5 py-0.5 rounded-md bg-[#D9ECE8] dark:bg-[#284841] text-[#245650] dark:text-[#93D7C9] font-bold">
                      {opt.badge}
                    </span>
                  )}
                </div>

                {isSelected && (
                  <Check className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF] shrink-0 mr-2" />
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
};
