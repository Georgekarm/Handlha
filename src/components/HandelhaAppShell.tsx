import React from 'react';
import { useApp } from '../context/AppContext';
import {
  Home,
  CheckCircle2,
  Folder,
  MessageSquare,
  Plus,
  BarChart3,
  Sparkles,
} from 'lucide-react';
import { QuickAddModal } from './QuickAddModal';
import { SmartAddTaskSheet } from './SmartAddTaskSheet';
import { AiBreakdownModal } from './AiBreakdownModal';
import { NewProjectModal } from './NewProjectModal';
import { AddChoiceModal } from './AddChoiceModal';

interface HandelhaAppShellProps {
  children: React.ReactNode;
}

export const HandelhaAppShell: React.FC<HandelhaAppShellProps> = ({ children }) => {
  const { currentRoute, navigate, setIsAddChoiceOpen, setIsQuickAddOpen } = useApp();

  const isShellRoute = ['/home', '/tasks', '/projects', '/chat', '/project-workspace', '/analytics'].includes(currentRoute);

  const handleCentralAdd = () => {
    if (currentRoute === '/projects' || currentRoute === '/project-workspace') {
      setIsAddChoiceOpen(true);
    } else {
      setIsQuickAddOpen(true);
    }
  };

  return (
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] text-[#1E2D2B] dark:text-[#EFF6F2] transition-colors duration-200">
      <div className="max-w-2xl mx-auto min-h-screen flex flex-col justify-between relative shadow-xs">
        <div className="flex-1 w-full pb-32 sm:pb-28">
          {children}
        </div>

        {isShellRoute && (
          <nav className="fixed bottom-0 inset-x-0 z-30 pointer-events-none">
            <div className="max-w-2xl mx-auto px-4 pb-2">
              <div className="pointer-events-auto rounded-3xl border shadow-lg backdrop-blur-md px-3 py-1.5 flex items-center justify-around transition-all bg-white/95 dark:bg-[#182724]/95 border-[#DDE7E2] dark:border-[#354D46]">
                {/* 1. Home */}
                <button
                  onClick={() => navigate('/home')}
                  className="flex-1 flex flex-col items-center gap-0.5 py-1 cursor-pointer transition-transform active:scale-95 outline-hidden"
                >
                  <div
                    className={`w-10 h-7 rounded-full flex items-center justify-center transition-all ${
                      currentRoute === '/home'
                        ? 'bg-[#D9ECE8] dark:bg-[#203D37] text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                    }`}
                  >
                    <Home className="w-5 h-5 stroke-[2.2]" />
                  </div>
                  <span
                    className={`text-[11px] font-bold ${
                      currentRoute === '/home'
                        ? 'text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE]'
                    }`}
                  >
                    الرئيسية
                  </span>
                </button>

                {/* 2. Tasks */}
                <button
                  onClick={() => navigate('/tasks')}
                  className="flex-1 flex flex-col items-center gap-0.5 py-1 cursor-pointer transition-transform active:scale-95 outline-hidden"
                >
                  <div
                    className={`w-10 h-7 rounded-full flex items-center justify-center transition-all ${
                      currentRoute === '/tasks'
                        ? 'bg-[#D9ECE8] dark:bg-[#203D37] text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                    }`}
                  >
                    <CheckCircle2 className="w-5 h-5 stroke-[2.2]" />
                  </div>
                  <span
                    className={`text-[11px] font-bold ${
                      currentRoute === '/tasks'
                        ? 'text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE]'
                    }`}
                  >
                    المهام
                  </span>
                </button>

                {/* 3. Central Add Button */}
                <div className="flex-1 flex flex-col items-center justify-center">
                  <button
                    onClick={handleCentralAdd}
                    className="w-12 h-12 -mt-5 rounded-full bg-linear-to-tr from-[#235D55] to-[#34786E] dark:from-[#76C6B7] dark:to-[#4EB5A2] text-white dark:text-[#101A18] shadow-md hover:shadow-lg hover:scale-105 active:scale-95 transition-all flex items-center justify-center cursor-pointer border-3 border-white dark:border-[#182724]"
                    title="إضافة"
                    aria-label="إضافة"
                  >
                    <Plus className="w-6 h-6 stroke-[2.8]" />
                  </button>
                  <span className="text-[10px] font-bold text-[#235D55] dark:text-[#76C6B7] mt-0.5">
                    إضافة
                  </span>
                </div>

                {/* 4. Projects */}
                <button
                  onClick={() => navigate('/projects')}
                  className="flex-1 flex flex-col items-center gap-0.5 py-1 cursor-pointer transition-transform active:scale-95 outline-hidden"
                >
                  <div
                    className={`w-10 h-7 rounded-full flex items-center justify-center transition-all ${
                      currentRoute === '/projects' || currentRoute === '/project-workspace'
                        ? 'bg-[#D9ECE8] dark:bg-[#203D37] text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                    }`}
                  >
                    <Folder className="w-5 h-5 stroke-[2.2]" />
                  </div>
                  <span
                    className={`text-[11px] font-bold ${
                      currentRoute === '/projects' || currentRoute === '/project-workspace'
                        ? 'text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE]'
                    }`}
                  >
                    المشاريع
                  </span>
                </button>

                {/* 5. Analytics / Tracking */}
                <button
                  onClick={() => navigate('/analytics')}
                  className="flex-1 flex flex-col items-center gap-0.5 py-1 cursor-pointer transition-transform active:scale-95 outline-hidden"
                >
                  <div
                    className={`w-10 h-7 rounded-full flex items-center justify-center transition-all ${
                      currentRoute === '/analytics'
                        ? 'bg-[#D9ECE8] dark:bg-[#203D37] text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                    }`}
                  >
                    <BarChart3 className="w-5 h-5 stroke-[2.2]" />
                  </div>
                  <span
                    className={`text-[11px] font-bold ${
                      currentRoute === '/analytics'
                        ? 'text-[#245650] dark:text-[#88C6B9]'
                        : 'text-[#647370] dark:text-[#9FB3AE]'
                    }`}
                  >
                    المتابعة
                  </span>
                </button>
              </div>
            </div>
          </nav>
        )}

        {/* Floating AI Bot Action Button (Bottom Right) */}
        {currentRoute !== '/chat' && (
          <div className="fixed bottom-22 right-4 sm:right-6 z-40">
            <button
              onClick={() => navigate('/chat')}
              className="group relative flex items-center gap-2 p-3 sm:px-4 sm:py-3 rounded-full bg-linear-to-r from-[#245650] to-[#2F6F68] dark:from-[#2A756B] dark:to-[#388D82] text-white shadow-lg hover:shadow-xl hover:scale-105 active:scale-95 transition-all duration-200 cursor-pointer border-2 border-white/80 dark:border-[#203D37]"
              title="تحدث مع مساعد هندلها الذكي"
              aria-label="تحدث مع مساعد هندلها الذكي"
            >
              <div className="relative">
                <MessageSquare className="w-5 h-5" />
                <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-[#E88C78] rounded-full ring-2 ring-[#245650]" />
              </div>
              <span className="hidden sm:inline text-xs font-bold whitespace-nowrap">
                مساعد هندلها
              </span>
              <Sparkles className="w-3.5 h-3.5 text-[#E6C687] animate-pulse hidden sm:inline" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
