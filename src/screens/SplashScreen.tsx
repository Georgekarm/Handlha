import React, { useEffect, useState } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';
import { Sparkles, ArrowLeft } from 'lucide-react';

export const SplashScreen: React.FC = () => {
  const { navigate, user } = useApp();
  const [stage, setStage] = useState<'initial' | 'badge' | 'ready'>('initial');

  useEffect(() => {
    const t1 = setTimeout(() => setStage('badge'), 350);
    const t2 = setTimeout(() => setStage('ready'), 900);
    const t3 = setTimeout(() => {
      if (user) {
        navigate('/home');
      } else {
        navigate('/login');
      }
    }, 2400);

    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
      clearTimeout(t3);
    };
  }, [user, navigate]);

  const handleSkip = () => {
    if (user) {
      navigate('/home');
    } else {
      navigate('/login');
    }
  };

  return (
    <div
      onClick={handleSkip}
      className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] flex flex-col items-center justify-center p-6 text-center select-none overflow-hidden relative cursor-pointer"
    >
      {/* Ambient background glowing orbs */}
      <div className="absolute top-1/2 left-1/2 w-96 h-96 bg-[#235D55]/15 dark:bg-[#76C6B7]/15 rounded-full blur-3xl pointer-events-none animate-glow-spread" />
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 w-64 h-64 bg-[#D3ECE6]/30 dark:bg-[#1C3E37]/30 rounded-full blur-2xl pointer-events-none" />

      <div className="relative z-10 flex flex-col items-center space-y-6 max-w-xs w-full">
        {/* Animated Brand Mark Container with Float and Glow */}
        <div className="relative">
          {/* Subtle decorative pulsing halo ring */}
          <div className="absolute -inset-2 bg-linear-to-tr from-[#235D55]/20 to-[#76C6B7]/20 rounded-4xl blur-md pointer-events-none animate-gentle-pulse" />

          <div
            className={`relative p-5 bg-white dark:bg-[#1A2825] rounded-3xl shadow-xl border border-[#DCE8E3] dark:border-[#263D37] transform transition-all duration-700 ease-out animate-float-slow ${
              stage === 'initial'
                ? 'scale-70 opacity-0 -translate-y-6'
                : 'scale-100 opacity-100 translate-y-0'
            }`}
          >
            <HandelhaMark size={88} animated={true} />
          </div>
        </div>

        {/* Brand Names & Slogan with Staggered Reveal */}
        <div
          className={`space-y-2 transition-all duration-700 delay-150 ease-out ${
            stage === 'ready'
              ? 'opacity-100 translate-y-0'
              : 'opacity-0 translate-y-4'
          }`}
        >
          <div className="flex items-center justify-center gap-2.5">
            <h1 className="text-3xl font-black text-[#1B2926] dark:text-white tracking-tight">
              Handalha
            </h1>
            <span className="text-xs font-bold px-2.5 py-1 rounded-lg bg-[#235D55]/10 dark:bg-[#76C6B7]/20 text-[#235D55] dark:text-[#76C6B7] shadow-2xs">
              هندلها
            </span>
          </div>

          <p className="text-xs font-semibold text-[#4F645F] dark:text-[#A7BCB7] tracking-wide">
            رتّب فوضاك.. وهندلها على الرايق
          </p>
        </div>

        {/* Calm Progress bar */}
        <div className="w-32 h-1.5 bg-[#D3E3DD] dark:bg-[#253D37] rounded-full overflow-hidden mt-2 shadow-inner">
          <div
            className="h-full bg-linear-to-r from-[#235D55] via-[#4EB5A2] to-[#76C6B7] rounded-full transition-all duration-1200 ease-out"
            style={{ width: stage === 'ready' ? '100%' : stage === 'badge' ? '50%' : '15%' }}
          />
        </div>

        {/* Skip Hint */}
        <div
          className={`pt-2 transition-opacity duration-500 text-[11px] font-medium text-[#7C918C] dark:text-[#7B928D] flex items-center gap-1 ${
            stage === 'ready' ? 'opacity-80' : 'opacity-0'
          }`}
        >
          <span>اضغط في أي مكان للبدء فوراً</span>
          <ArrowLeft className="w-3 h-3" />
        </div>
      </div>
    </div>
  );
};
