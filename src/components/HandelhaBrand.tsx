import React from 'react';

interface HandelhaMarkProps {
  size?: number;
  dark?: boolean;
  className?: string;
  animated?: boolean;
}

/**
 * Handalha Brand Icon:
 * The signature Handalha logo representing untangling chaos into focused clarity.
 * A tangled loop unravelling upward towards a crisp checkmark achievement badge.
 */
export const HandelhaMark: React.FC<HandelhaMarkProps> = ({
  size = 40,
  dark,
  className = '',
  animated = false,
}) => {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 128 128"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={`inline-block select-none shrink-0 ${
        animated ? 'transition-transform duration-300 hover:scale-105 active:scale-95' : ''
      } ${className}`}
    >
      {/* Achievement Checkmark Circle (Top Right) */}
      <circle
        cx="102"
        cy="34"
        r="17"
        className={dark ? 'fill-[#244C43]' : 'fill-[#D3ECE6] dark:fill-[#244C43]'}
      />

      {/* Terracotta/Coral Checkmark */}
      <path
        d="M95 34.5 L100 39.5 L110 28.5"
        className={dark ? 'stroke-[#F28E79]' : 'stroke-[#C56852] dark:stroke-[#F28E79]'}
        strokeWidth="3.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />

      {/* Primary Untangling Loops (Chaos to Clarity) */}
      <path
        d="M 38 72 C 26 80 14 74 15 58 C 16 43 30 40 44 48 C 58 56 64 78 48 88 C 34 96 18 88 22 70"
        className={dark ? 'stroke-[#76C6B7]' : 'stroke-[#235D55] dark:stroke-[#76C6B7]'}
        strokeWidth="11"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />

      <path
        d="M 28 60 C 38 42 54 36 62 50 C 70 64 62 82 46 78 C 34 74 38 52 52 42 C 66 32 78 54 84 66 C 89 74 94 68 96 56 L 98 46"
        className={dark ? 'stroke-[#76C6B7]' : 'stroke-[#235D55] dark:stroke-[#76C6B7]'}
        strokeWidth="11"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />

      {/* Arrowhead heading directly to achievement */}
      <path
        d="M 87 50 L 98 44 L 102 55"
        className={dark ? 'stroke-[#76C6B7]' : 'stroke-[#235D55] dark:stroke-[#76C6B7]'}
        strokeWidth="10"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />
    </svg>
  );
};

interface HandelhaLogoProps {
  markSize?: number;
  fontSize?: number;
  dark?: boolean;
  showWordmark?: boolean;
  showArabic?: boolean;
  subtitle?: string;
  className?: string;
}

/**
 * Handalha Logo Lockup:
 * Displays the signature Handalha logo mark alongside the wordmark and Arabic badge.
 */
export const HandelhaLogo: React.FC<HandelhaLogoProps> = ({
  markSize = 38,
  fontSize = 20,
  dark,
  showWordmark = true,
  showArabic = true,
  subtitle,
  className = '',
}) => {
  const textColorClass =
    dark === true
      ? 'text-[#EFF6F2]'
      : dark === false
      ? 'text-[#1B2926]'
      : 'text-[#1B2926] dark:text-[#EFF6F2]';

  return (
    <div className={`flex items-center gap-3 select-none ${className}`}>
      <HandelhaMark size={markSize} dark={dark} animated={true} />

      {showWordmark && (
        <div className="flex flex-col text-right">
          <div className="flex items-center gap-2">
            <span
              style={{ fontSize: `${fontSize}px` }}
              className={`font-black tracking-tight leading-none ${textColorClass}`}
            >
              Handalha
            </span>
            {showArabic && (
              <span className="text-xs font-bold px-2 py-0.5 rounded-lg bg-[#235D55]/10 dark:bg-[#76C6B7]/20 text-[#235D55] dark:text-[#76C6B7] leading-none">
                هندلها
              </span>
            )}
          </div>
          {subtitle && (
            <span className="text-[11px] text-[#637974] dark:text-[#9FB3AE] mt-1 font-medium leading-tight">
              {subtitle}
            </span>
          )}
        </div>
      )}
    </div>
  );
};
