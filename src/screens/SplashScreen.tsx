import React, { useEffect } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';

export const SplashScreen: React.FC = () => {
  const { navigate, user } = useApp();

  useEffect(() => {
    const timer = setTimeout(() => {
      if (user) {
        navigate('/home');
      } else {
        navigate('/login');
      }
    }, 1800);
    return () => clearTimeout(timer);
  }, [user, navigate]);

  return (
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] flex flex-col items-center justify-center p-6 text-center select-none">
      <div className="space-y-4 animate-fade-in flex flex-col items-center">
        <div className="p-3 bg-white dark:bg-[#1A2825] rounded-3xl shadow-sm border border-[#DEE7E2] dark:border-[#283C37]">
          <HandelhaMark size={72} />
        </div>

        <div className="space-y-1">
          <h1 className="text-3xl font-black text-[#1E2D2B] dark:text-white tracking-tight">
            هندلها
          </h1>
          <p className="text-xs font-medium text-[#526662] dark:text-[#A7BCB7]">
            كل خطوة في وقتها.. بهدوء وإتقان
          </p>
        </div>

        <div className="w-12 h-1 bg-[#D3E3DD] dark:bg-[#253D37] rounded-full overflow-hidden mt-6">
          <div className="w-full h-full bg-[#2F6F68] dark:bg-[#76BCAF] animate-pulse" />
        </div>
      </div>
    </div>
  );
};
