import React, { useState, useEffect } from 'react';
import { Check } from 'lucide-react';
import { fireGoalCelebration, CelebrationOptions } from '../utils/celebration';

interface CelebrationCheckboxProps {
  checked: boolean;
  onChange: (e: React.MouseEvent<HTMLButtonElement>) => void;
  size?: 'sm' | 'md' | 'lg';
  celebrationIntensity?: CelebrationOptions['intensity'];
  ariaLabel?: string;
  className?: string;
  onCelebrated?: () => void;
}

export const CelebrationCheckbox: React.FC<CelebrationCheckboxProps> = ({
  checked,
  onChange,
  size = 'md',
  celebrationIntensity = 'subtle',
  ariaLabel = 'تحديد كمنجز',
  className = '',
  onCelebrated,
}) => {
  const [isAnimating, setIsAnimating] = useState(false);

  useEffect(() => {
    if (isAnimating) {
      const timer = setTimeout(() => {
        setIsAnimating(false);
      }, 750);
      return () => clearTimeout(timer);
    }
  }, [isAnimating]);

  const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
    if (!checked) {
      // Trigger subtle celebratory animation on check
      setIsAnimating(true);
      fireGoalCelebration(e, { intensity: celebrationIntensity });
      if (onCelebrated) {
        onCelebrated();
      }
    }
    onChange(e);
  };

  const sizeClasses = {
    sm: 'w-5 h-5 rounded-md',
    md: 'w-6 h-6 rounded-lg',
    lg: 'w-7 h-7 rounded-xl',
  }[size];

  const iconSizes = {
    sm: 'w-3.5 h-3.5',
    md: 'w-4 h-4',
    lg: 'w-4.5 h-4.5',
  }[size];

  return (
    <button
      type="button"
      onClick={handleClick}
      aria-label={ariaLabel}
      aria-checked={checked}
      role="checkbox"
      className={`relative flex items-center justify-center shrink-0 cursor-pointer select-none transition-all duration-300 ease-out active:scale-90 ${sizeClasses} ${
        checked
          ? 'bg-[#2F6F68] text-white shadow-xs border border-[#2F6F68]'
          : 'border-2 border-[#BACAC4] dark:border-[#405650] hover:border-[#2F6F68] dark:hover:border-[#76BCAF] text-transparent bg-white dark:bg-[#1A2825]'
      } ${
        isAnimating
          ? 'scale-110 ring-4 ring-[#2F6F68]/30 dark:ring-[#76BCAF]/30 shadow-md'
          : ''
      } ${className}`}
    >
      {/* Ripple ring on celebratory trigger */}
      {isAnimating && (
        <span
          className={`absolute -inset-1 rounded-xl bg-[#2F6F68]/25 dark:bg-[#76BCAF]/30 animate-ping pointer-events-none`}
        />
      )}

      {/* Floating micro-sparkle badge */}
      {isAnimating && (
        <span
          className="absolute -top-3.5 -right-2 text-[11px] leading-none select-none pointer-events-none animate-bounce"
          aria-hidden="true"
        >
          ✨
        </span>
      )}

      {/* Animated Checkmark icon */}
      <Check
        className={`${iconSizes} stroke-[3] transition-all duration-300 ease-out ${
          checked
            ? 'scale-100 rotate-0 opacity-100'
            : 'scale-0 -rotate-45 opacity-0'
        } ${isAnimating ? 'animate-pulse' : ''}`}
      />
    </button>
  );
};
