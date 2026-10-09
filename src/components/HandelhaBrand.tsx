import React from 'react';

interface HandelhaMarkProps {
  size?: number;
  dark?: boolean;
  className?: string;
}

export const HandelhaMark: React.FC<HandelhaMarkProps> = ({
  size = 42,
  dark,
  className = '',
}) => {
  const stemClass =
    dark === true
      ? 'stroke-[#76BCAF]'
      : dark === false
      ? 'stroke-[#245650]'
      : 'stroke-[#245650] dark:stroke-[#76BCAF]';

  const leftLeafClass =
    dark === true
      ? 'fill-[#76BCAF]'
      : dark === false
      ? 'fill-[#2F6F68]'
      : 'fill-[#2F6F68] dark:fill-[#76BCAF]';

  const rightLeafClass =
    dark === true
      ? 'fill-[#9DD2C5]'
      : dark === false
      ? 'fill-[#4E9B77]'
      : 'fill-[#4E9B77] dark:fill-[#9DD2C5]';

  const veinClass =
    dark === true
      ? 'stroke-[rgba(16,26,24,0.72)]'
      : dark === false
      ? 'stroke-[rgba(255,255,255,0.72)]'
      : 'stroke-[rgba(255,255,255,0.72)] dark:stroke-[rgba(16,26,24,0.72)]';

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={`inline-block select-none ${className}`}
    >
      <line
        x1="50"
        y1="83"
        x2="50"
        y2="39"
        className={stemClass}
        strokeWidth="7"
        strokeLinecap="round"
      />
      <line
        x1="50"
        y1="64"
        x2="34"
        y2="48"
        className={stemClass}
        strokeWidth="7"
        strokeLinecap="round"
      />
      <path
        d="M 34 49 C 14 47 13 29 17 18 C 35 20 45 32 42 48 C 39 51 36 51 34 49 Z"
        className={leftLeafClass}
      />
      <line
        x1="21"
        y1="23"
        x2="37"
        y2="43"
        className={veinClass}
        strokeWidth="2"
        strokeLinecap="round"
      />
      <path
        d="M 51 41 C 52 20 68 10 84 12 C 84 31 74 44 54 47 C 52 46 51 44 51 41 Z"
        className={rightLeafClass}
      />
      <line
        x1="79"
        y1="17"
        x2="56"
        y2="40"
        className={veinClass}
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
};

interface HandelhaLogoProps {
  markSize?: number;
  fontSize?: number;
  dark?: boolean;
  showWordmark?: boolean;
  subtitle?: string;
  className?: string;
}

export const HandelhaLogo: React.FC<HandelhaLogoProps> = ({
  markSize = 36,
  fontSize = 22,
  dark,
  showWordmark = true,
  subtitle,
  className = '',
}) => {
  const textColorClass =
    dark === true
      ? 'text-[#EFF6F2]'
      : dark === false
      ? 'text-[#1E2D2B]'
      : 'text-[#1E2D2B] dark:text-[#EFF6F2]';

  return (
    <div className={`flex items-center gap-2 select-none ${className}`}>
      <HandelhaMark size={markSize} dark={dark} />
      {showWordmark && (
        <div className="flex flex-col">
          <span
            style={{ fontSize: `${fontSize}px` }}
            className={`font-black tracking-tight leading-none ${textColorClass}`}
          >
            هندلها
          </span>
          {subtitle && (
            <span className="text-[10px] text-[#637974] dark:text-[#9FB3AE] mt-0.5 font-medium">
              {subtitle}
            </span>
          )}
        </div>
      )}
    </div>
  );
};
