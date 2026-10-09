import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  ArrowRight,
  Sun,
  Moon,
  Laptop,
  MessageSquare,
  Sparkles,
  Bell,
  Clock,
  ShieldCheck,
  Download,
  LogOut,
  User,
  ChevronDown,
  ChevronUp,
  Check,
} from 'lucide-react';
import { AssistantTone } from '../types';

export const SettingsScreen: React.FC = () => {
  const {
    user,
    themeMode,
    setThemeMode,
    updateUserProfile,
    logout,
    navigate,
    tasks,
    projects,
  } = useApp();

  const [isEditingName, setIsEditingName] = useState(false);
  const [nameInput, setNameInput] = useState(user?.displayName || '');
  const [exportNotice, setExportNotice] = useState(false);

  const handleSaveName = (e: React.FormEvent) => {
    e.preventDefault();
    if (nameInput.trim()) {
      updateUserProfile({ displayName: nameInput.trim() });
    }
    setIsEditingName(false);
  };

  const handleExportData = () => {
    const data = {
      user,
      tasks,
      projects,
      exportedAt: new Date().toISOString(),
      app: 'Handelha',
    };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `handelha-backup-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    setExportNotice(true);
    setTimeout(() => setExportNotice(false), 3000);
  };

  const tones: { id: AssistantTone; title: string; desc: string }[] = [
    {
      id: 'friendly',
      title: 'ودودة ومصرية هادئة ✨',
      desc: 'بلهجة مصرية محببة وكلمات تشجيع خفيفة على القلب دون إلحاح.',
    },
    {
      id: 'concise',
      title: 'مختصرة ومباشرة ⚡',
      desc: 'خطوات عملية محددة دون مقدمات طويلة، مناسبة لأوقات السرعة.',
    },
    {
      id: 'formal',
      title: 'فصحى رسمية 🌿',
      desc: 'لغة عربية فصحى راقية ومرتبة لأعلى درجات الاتزان.',
    },
  ];

  return (
    <div className="pb-28 pt-4 px-4 sm:px-6 space-y-6">
      {/* Header */}
      <header className="flex items-center justify-between pt-2">
        <div className="flex items-center gap-2">
          <button
            onClick={() => navigate('/home')}
            className="p-2 rounded-xl text-[#576F6A] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white hover:bg-[#EEF5F2] dark:hover:bg-[#1E332E] transition-colors cursor-pointer"
          >
            <ArrowRight className="w-5 h-5" />
          </button>
          <h1 className="text-xl font-bold text-[#1E2D2B] dark:text-white">
            إعداداتك
          </h1>
        </div>
      </header>

      {/* Profile Card */}
      <div className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] shadow-xs space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-3.5">
            <div className="w-13 h-13 rounded-2xl bg-[#D9ECE8] dark:bg-[#203D37] text-[#2F6F68] dark:text-[#88C6B9] flex items-center justify-center text-lg font-bold">
              {user?.displayName ? user.displayName.charAt(0) : 'أ'}
            </div>

            <div>
              <h2 className="text-base font-bold text-[#1E2D2B] dark:text-white">
                {user?.displayName || 'حساب هندلها'}
              </h2>
              <p className="text-xs text-[#6A7E7A] dark:text-[#9FB4AF]">
                {user?.email || 'ahmed@handelha.app'}
              </p>
            </div>
          </div>

          <button
            onClick={() => {
              setNameInput(user?.displayName || '');
              setIsEditingName(!isEditingName);
            }}
            className="px-3.5 py-1.5 rounded-xl border border-[#D5E3DD] dark:border-[#2B433D] text-xs font-bold text-[#2F6F68] dark:text-[#78C2B4] hover:bg-[#EEF5F2] dark:hover:bg-[#203631] transition-colors cursor-pointer"
          >
            {isEditingName ? 'إلغاء' : 'تعديل'}
          </button>
        </div>

        {isEditingName && (
          <form onSubmit={handleSaveName} className="flex gap-2 pt-2 border-t border-[#E5EFEA] dark:border-[#283C37]">
            <input
              type="text"
              value={nameInput}
              onChange={(e) => setNameInput(e.target.value)}
              placeholder="اكتب اسمك المفضل..."
              className="flex-1 px-3 py-1.5 rounded-xl border border-[#D0E0DA] dark:border-[#2D453F] bg-[#F9FBFA] dark:bg-[#152320] text-xs text-[#1E2D2B] dark:text-white focus:outline-hidden focus:border-[#2F6F68]"
            />
            <button
              type="submit"
              className="px-4 py-1.5 rounded-xl bg-[#2F6F68] text-white text-xs font-bold hover:bg-[#245650] cursor-pointer"
            >
              حفظ
            </button>
          </form>
        )}
      </div>

      {/* Theme Selection */}
      <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-3">
        <h3 className="text-xs font-bold text-[#556965] dark:text-[#A7BCB7] flex items-center gap-2">
          <Sun className="w-4 h-4 text-[#2F6F68]" />
          المظهر والسمة
        </h3>

        <div className="grid grid-cols-3 gap-2">
          {[
            { id: 'light', label: 'فاتح', icon: Sun },
            { id: 'dark', label: 'داكن', icon: Moon },
            { id: 'system', label: 'تلقائي', icon: Laptop },
          ].map((theme) => {
            const Icon = theme.icon;
            const isSelected = themeMode === theme.id;

            return (
              <button
                key={theme.id}
                onClick={() => setThemeMode(theme.id as any)}
                className={`py-2.5 px-3 rounded-2xl flex flex-col items-center gap-1.5 text-xs font-bold transition-all cursor-pointer border ${
                  isSelected
                    ? 'bg-[#EEF5F2] dark:bg-[#203D37] border-[#2F6F68] dark:border-[#76BCAF] text-[#2F6F68] dark:text-[#88C6B9] shadow-2xs'
                    : 'bg-[#F9FCFA] dark:bg-[#152320] border-[#E2EBE6] dark:border-[#253934] text-[#697D79] dark:text-[#9CB0AC] hover:bg-white dark:hover:bg-[#1A2926]'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{theme.label}</span>
              </button>
            );
          })}
        </div>
      </section>

      {/* Tone of Assistant */}
      <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold text-[#556965] dark:text-[#A7BCB7] flex items-center gap-2">
            <MessageSquare className="w-4 h-4 text-[#2F6F68]" />
            أسلوب مساعد هندلها
          </h3>
          <span className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF]">
            {tones.find(t => t.id === (user?.preferredTone || 'friendly'))?.title}
          </span>
        </div>

        <div className="space-y-2 pt-1">
          {tones.map((t) => {
            const isSelected = (user?.preferredTone || 'friendly') === t.id;

            return (
              <button
                key={t.id}
                onClick={() => updateUserProfile({ preferredTone: t.id })}
                className={`w-full p-3.5 rounded-2xl text-right border transition-all cursor-pointer ${
                  isSelected
                    ? 'bg-[#EEF5F2] dark:bg-[#203D37] border-[#2F6F68] dark:border-[#76BCAF]'
                    : 'bg-[#F9FCFA] dark:bg-[#152320] border-[#E2EBE6] dark:border-[#253934] hover:border-[#C4D7D0] dark:hover:border-[#334B44]'
                }`}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-bold text-[#1E2D2B] dark:text-white">
                    {t.title}
                  </span>
                  {isSelected && <Check className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF] stroke-[3]" />}
                </div>
                <p className="text-[11px] text-[#6A7F7A] dark:text-[#9FB3AE] leading-relaxed">
                  {t.desc}
                </p>
              </button>
            );
          })}
        </div>
      </section>

      {/* Data & Privacy */}
      <section className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] space-y-3">
        <h3 className="text-xs font-bold text-[#556965] dark:text-[#A7BCB7] flex items-center gap-2">
          <ShieldCheck className="w-4 h-4 text-[#2F6F68]" />
          الخصوصية والبيانات المحلية
        </h3>

        <div className="space-y-2 text-xs">
          <div className="p-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#152320] flex items-center justify-between">
            <span className="text-[#3F5450] dark:text-[#B5CAC5]">حفظ البيانات محلياً وبشكل آمن</span>
            <span className="font-bold text-[#2F6F68] dark:text-[#78C2B4]">مفعّل</span>
          </div>

          <button
            onClick={handleExportData}
            className="w-full p-3 rounded-2xl border border-[#DCE8E2] dark:border-[#283E38] hover:bg-[#EEF5F2] dark:hover:bg-[#1C2C28] transition-colors flex items-center justify-center gap-2 font-bold text-[#2F6F68] dark:text-[#7BC2B4] cursor-pointer"
          >
            <Download className="w-4 h-4" />
            {exportNotice ? 'تم تنزيل النسخة الاحتياطية بنجاح ✓' : 'تصدير بياناتي بصيغة JSON'}
          </button>
        </div>
      </section>

      {/* Logout */}
      <div className="pt-2">
        <button
          onClick={logout}
          className="w-full p-4 rounded-3xl border border-[#F3CECC] dark:border-[#4B2525] bg-[#FDF5F5] dark:bg-[#251515] text-[#C64545] dark:text-[#F38C8C] hover:bg-[#FCEAEA] dark:hover:bg-[#321B1B] text-xs font-bold flex items-center justify-center gap-2 transition-colors cursor-pointer"
        >
          <LogOut className="w-4 h-4" />
          تسجيل الخروج
        </button>
      </div>

      {/* Calm Footer */}
      <div className="text-center text-[11px] text-[#7A908B] dark:text-[#8D9F9B] space-y-1 pt-4">
        <p>تطبيق «هندلها» • النسخة ١.٠.٠</p>
        <p>صُمّم لإنتاجية هادئة، صافية الذهن وخالية من التوتر.</p>
      </div>
    </div>
  );
};
