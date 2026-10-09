import React from 'react';
import { useApp } from '../context/AppContext';
import {
  Home,
  CheckCircle2,
  Folder,
  MessageSquare,
} from 'lucide-react';
import { QuickAddModal } from './QuickAddModal';
import { SmartAddTaskSheet } from './SmartAddTaskSheet';
import { AiBreakdownModal } from './AiBreakdownModal';
import { NewProjectModal } from './NewProjectModal';

interface HandelhaAppShellProps {
  children: React.ReactNode;
}

export const HandelhaAppShell: React.FC<HandelhaAppShellProps> = ({ children }) => {
  const { currentRoute, navigate, isDarkMode } = useApp();

  const navItems = [
    { route: '/home', label: 'الرئيسية', icon: Home },
    { route: '/tasks', label: 'المهام', icon: CheckCircle2 },
    { route: '/projects', label: 'المشاريع', icon: Folder },
    { route: '/chat', label: 'المساعد', icon: MessageSquare },
  ];

  const isShellRoute = ['/home', '/tasks', '/projects', '/chat'].includes(currentRoute);

  return (
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] text-[#1E2D2B] dark:text-[#EFF6F2] transition-colors duration-200">
      <div className="max-w-2xl mx-auto min-h-screen flex flex-col justify-between relative shadow-xs">
        <div className="flex-1 w-full">
          {children}
        </div>

        {isShellRoute && (
          <nav className="fixed bottom-0 inset-x-0 z-30 pointer-events-none">
            <div className="max-w-2xl mx-auto px-4 pb-2">
              <div className="pointer-events-auto rounded-3xl border shadow-lg backdrop-blur-md px-3 py-2 flex items-center justify-around transition-all bg-white/95 dark:bg-[#182724]/95 border-[#DDE7E2] dark:border-[#354D46]">
                {navItems.map((item) => {
                  const Icon = item.icon;
                  const isActive = currentRoute === item.route;

                  return (
                    <button
                      key={item.route}
                      onClick={() => navigate(item.route)}
                      className="flex-1 flex flex-col items-center gap-1 py-1 cursor-pointer transition-transform active:scale-95 outline-hidden focus:outline-hidden"
                    >
                      <div
                        className={`w-11 h-8 rounded-full flex items-center justify-center transition-all ${
                          isActive
                            ? 'bg-[#D9ECE8] dark:bg-[#203D37] text-[#245650] dark:text-[#88C6B9]'
                            : 'text-[#647370] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white'
                        }`}
                      >
                        <Icon className="w-5 h-5 stroke-[2.2]" />
                      </div>

                      <span
                        className={`text-[11px] font-bold transition-colors ${
                          isActive
                            ? 'text-[#245650] dark:text-[#88C6B9]'
                            : 'text-[#647370] dark:text-[#9FB3AE]'
                        }`}
                      >
                        {item.label}
                      </span>

                      <span
                        className={`h-0.5 rounded-full transition-all duration-300 ${
                          isActive
                            ? 'w-6 bg-[#2F6F68] dark:bg-[#76BCAF]'
                            : 'w-0 bg-transparent'
                        }`}
                      />
                    </button>
                  );
                })}
              </div>
            </div>
          </nav>
        )}

        <QuickAddModal />
        <SmartAddTaskSheet />
        <AiBreakdownModal />
        <NewProjectModal />
      </div>
    </div>
  );
};
