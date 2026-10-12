import React from 'react';
import { useApp } from '../context/AppContext';
import { X, FolderPlus, CheckSquare, Plus, ArrowLeft } from 'lucide-react';

export const AddChoiceModal: React.FC = () => {
  const {
    isAddChoiceOpen,
    setIsAddChoiceOpen,
    setIsNewProjectOpen,
    setIsQuickAddOpen,
  } = useApp();

  if (!isAddChoiceOpen) return null;

  const handleSelectAddSection = () => {
    setIsAddChoiceOpen(false);
    setIsNewProjectOpen(true);
  };

  const handleSelectAddTask = () => {
    setIsAddChoiceOpen(false);
    setIsQuickAddOpen(true);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200"
      onClick={() => setIsAddChoiceOpen(false)}
    >
      <div
        className="w-full max-w-md bg-white dark:bg-[#182724] rounded-t-3xl sm:rounded-3xl shadow-2xl border border-[#DFEDE7] dark:border-[#273D38] overflow-hidden p-6 space-y-5 animate-in slide-in-from-bottom-5 duration-300"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-[#235D55]/10 dark:bg-[#76C6B7]/20 text-[#235D55] dark:text-[#76C6B7] flex items-center justify-center">
              <Plus className="w-5 h-5 stroke-[2.5]" />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#1B2926] dark:text-white">
                ماذا تريد أن تضيف؟
              </h2>
              <p className="text-xs text-[#5E726E] dark:text-[#9FB3AE]">
                اختر إضافة سكشن متكامل أو مهمة محددة
              </p>
            </div>
          </div>

          <button
            onClick={() => setIsAddChoiceOpen(false)}
            className="p-2 rounded-xl text-[#6B807B] hover:text-[#1E2D2B] hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* The Two Choices */}
        <div className="space-y-3 pt-1">
          {/* Option 1: Add a Section with Tasks */}
          <button
            onClick={handleSelectAddSection}
            className="w-full p-4 rounded-2xl border border-[#D5E3DE] dark:border-[#2A413B] bg-[#F7FBF9] dark:bg-[#14211E] hover:border-[#235D55] dark:hover:border-[#76C6B7] hover:shadow-md transition-all text-right group cursor-pointer flex items-center justify-between active:scale-[0.99]"
          >
            <div className="flex items-start gap-3.5">
              <div className="w-11 h-11 rounded-2xl bg-[#235D55] text-white flex items-center justify-center shrink-0 group-hover:scale-105 transition-transform shadow-xs">
                <FolderPlus className="w-5 h-5" />
              </div>
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-bold text-[#1B2926] dark:text-white group-hover:text-[#235D55] dark:group-hover:text-[#76C6B7] transition-colors">
                    إضافة سكشن جديد وإضافة مهام بداخله
                  </h3>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-[#235D55]/10 text-[#235D55] dark:bg-[#76C6B7]/20 dark:text-[#76C6B7]">
                    سكشن + مهام
                  </span>
                </div>
                <p className="text-xs text-[#5A706B] dark:text-[#9AB0AA] leading-relaxed">
                  أنشئ سكشن جديد وضع قائمة المهام التابعة له بداخله مباشرة دفعة واحدة
                </p>
              </div>
            </div>

            <ArrowLeft className="w-4 h-4 text-[#8AA09A] group-hover:text-[#235D55] dark:group-hover:text-[#76C6B7] transition-colors shrink-0 mr-2" />
          </button>

          {/* Option 2: Add a Single Task with Section Picker */}
          <button
            onClick={handleSelectAddTask}
            className="w-full p-4 rounded-2xl border border-[#D5E3DE] dark:border-[#2A413B] bg-[#F7FBF9] dark:bg-[#14211E] hover:border-[#235D55] dark:hover:border-[#76C6B7] hover:shadow-md transition-all text-right group cursor-pointer flex items-center justify-between active:scale-[0.99]"
          >
            <div className="flex items-start gap-3.5">
              <div className="w-11 h-11 rounded-2xl bg-[#D3ECE6] dark:bg-[#203D37] text-[#235D55] dark:text-[#76C6B7] flex items-center justify-center shrink-0 group-hover:scale-105 transition-transform">
                <CheckSquare className="w-5 h-5" />
              </div>
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-bold text-[#1B2926] dark:text-white group-hover:text-[#235D55] dark:group-hover:text-[#76C6B7] transition-colors">
                    إضافة مهمة وتحديد سكشن معين موجود
                  </h3>
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-[#EDF4F1] dark:bg-[#233833] text-[#4E625D] dark:text-[#B0C5C0]">
                    مهمة + تحديد سكشن
                  </span>
                </div>
                <p className="text-xs text-[#5A706B] dark:text-[#9AB0AA] leading-relaxed">
                  أضف مهمة محددة واختر السكشن الخاص بها مع تحديد الوقت والأولوية
                </p>
              </div>
            </div>

            <ArrowLeft className="w-4 h-4 text-[#8AA09A] group-hover:text-[#235D55] dark:group-hover:text-[#76C6B7] transition-colors shrink-0 mr-2" />
          </button>
        </div>
      </div>
    </div>
  );
};
