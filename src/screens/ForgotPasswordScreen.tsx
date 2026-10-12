import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';
import { Mail, ArrowRight, CheckCircle2, ArrowLeft } from 'lucide-react';

export const ForgotPasswordScreen: React.FC = () => {
  const { navigate } = useApp();

  const [email, setEmail] = useState('');
  const [isSent, setIsSent] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;
    setIsSent(true);
  };

  return (
    <div className="min-h-screen bg-linear-to-b from-[#FDF9F5] via-[#F8FAF9] to-[#EEF5F2] dark:from-[#0E1715] dark:via-[#111C19] dark:to-[#162723] flex flex-col justify-center items-center px-4 sm:px-6 py-10 transition-colors duration-300 relative overflow-hidden select-none">
      {/* Background Aesthetic Ambient Shapes & Gradients */}
      <div className="absolute -top-24 -right-24 w-96 h-96 bg-linear-to-br from-[#E27D66]/15 to-[#F5A392]/5 dark:from-[#E27D66]/10 dark:to-transparent rounded-full blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 -left-28 w-80 h-80 bg-linear-to-tr from-[#235D55]/15 to-[#76C6B7]/10 dark:from-[#235D55]/20 dark:to-transparent rounded-full blur-3xl pointer-events-none" />

      <div className="max-w-md w-full relative z-10 space-y-6 animate-in fade-in slide-in-from-bottom-5 duration-500">
        <button
          onClick={() => navigate('/login')}
          className="inline-flex items-center gap-1.5 text-xs font-bold text-[#556965] dark:text-[#A8BBB6] hover:text-[#1E2D2B] dark:hover:text-white cursor-pointer px-3 py-1.5 rounded-xl bg-white/60 dark:bg-[#182724]/60 border border-[#DEE7E2] dark:border-[#283C37] backdrop-blur-sm"
        >
          <ArrowRight className="w-4 h-4" />
          <span>العودة لتسجيل الدخول</span>
        </button>

        {/* Brand Header */}
        <div className="text-center space-y-3">
          <div className="inline-flex p-3 rounded-[28px] bg-white/80 dark:bg-[#182724]/80 backdrop-blur-md border border-[#DEE7E2]/70 dark:border-[#273D38] shadow-md">
            <HandelhaMark size={56} animated={true} />
          </div>

          <div className="space-y-1">
            <h1 className="text-xl font-black text-[#1E2D2B] dark:text-white">
              استعادة كلمة المرور
            </h1>
            <p className="text-xs text-[#5D736E] dark:text-[#9FB3AE]">
              أدخل بريدك الإلكتروني وسنرسل لك رابطاً آمناً لإعادة الضبط بهدوء
            </p>
          </div>
        </div>

        {/* Card Form */}
        <div className="p-6 sm:p-8 rounded-[32px] bg-white/95 dark:bg-[#182724]/95 backdrop-blur-xl border border-[#DFE8E3] dark:border-[#283C37] shadow-xl shadow-black/5 space-y-4">
          {isSent ? (
            <div className="text-center space-y-3 py-4">
              <div className="w-14 h-14 mx-auto rounded-3xl bg-[#EEF7F4] dark:bg-[#1B352F] text-[#235D55] dark:text-[#76C6B7] flex items-center justify-center shadow-xs">
                <CheckCircle2 className="w-7 h-7 stroke-[2.5]" />
              </div>
              <h3 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                تم إرسال الرابط بنجاح!
              </h3>
              <p className="text-xs text-[#6A7E7A] dark:text-[#9FB3AE] leading-relaxed">
                راجع صندوق الوارد في بريدك ({email}) واتبع الخطوات البسيطة لإعادة الضبط.
              </p>
              <button
                onClick={() => navigate('/login')}
                className="mt-3 w-full py-3 rounded-2xl bg-linear-to-r from-[#235D55] via-[#2F6F68] to-[#3B7F76] text-white text-xs font-bold shadow-md cursor-pointer transition-all flex items-center justify-center gap-2"
              >
                <span>العودة لتسجيل الدخول</span>
                <ArrowLeft className="w-4 h-4" />
              </button>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-1.5 text-right">
                <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#BACCC7]">
                  البريد الإلكتروني
                </label>
                <div className="relative">
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="name@example.com"
                    dir="ltr"
                    className="w-full pl-3.5 pr-10 py-3 rounded-2xl text-xs bg-[#F8FAF9] dark:bg-[#152320] border border-[#D7E3DE] dark:border-[#2A403A] text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] focus:outline-hidden focus:border-[#235D55] dark:focus:border-[#76C6B7] focus:ring-2 focus:ring-[#235D55]/15 transition-all text-left font-mono"
                  />
                  <div className="absolute inset-y-0 right-0 pr-3.5 flex items-center pointer-events-none text-[#718782] dark:text-[#8AA09A]">
                    <Mail className="w-4 h-4" />
                  </div>
                </div>
              </div>

              <button
                type="submit"
                className="w-full py-3.5 px-4 rounded-2xl bg-linear-to-r from-[#235D55] via-[#2F6F68] to-[#3B7F76] hover:from-[#1D4E47] hover:to-[#2B635B] text-white text-xs font-bold transition-all shadow-md shadow-[#235D55]/25 hover:shadow-lg flex items-center justify-center gap-2 cursor-pointer active:scale-98"
              >
                <span>إرسال الرابط الآمن</span>
                <ArrowLeft className="w-4 h-4" />
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};
