import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';
import { Mail, ArrowRight, CheckCircle2 } from 'lucide-react';

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
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] flex flex-col justify-center px-4 sm:px-6 py-12">
      <div className="max-w-md w-full mx-auto space-y-6">
        <button
          onClick={() => navigate('/login')}
          className="inline-flex items-center gap-1.5 text-xs font-bold text-[#556965] dark:text-[#A8BBB6] hover:text-[#1E2D2B] dark:hover:text-white cursor-pointer"
        >
          <ArrowRight className="w-4 h-4" />
          <span>العودة لتسجيل الدخول</span>
        </button>

        <div className="text-center space-y-2">
          <div className="flex justify-center">
            <HandelhaMark size={48} />
          </div>
          <h1 className="text-2xl font-black text-[#1E2D2B] dark:text-white">
            استعادة كلمة المرور
          </h1>
          <p className="text-xs text-[#5D736E] dark:text-[#9FB3AE]">
            أدخل بريدك الإلكتروني وسنرسل لك رابطاً آمناً لإعادة الضبط بهدوء
          </p>
        </div>

        <div className="p-6 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] shadow-sm space-y-4">
          {isSent ? (
            <div className="text-center space-y-3 py-4">
              <div className="w-12 h-12 mx-auto rounded-full bg-[#E5EFEA] text-[#2F6F68] flex items-center justify-center">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <h3 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                تم إرسال الرابط بنجاح!
              </h3>
              <p className="text-xs text-[#6A7E7A] dark:text-[#9FB3AE]">
                راجع صندوق الوارد في بريدك ({email}) واتبع الخطوات البسيطة.
              </p>
              <button
                onClick={() => navigate('/login')}
                className="mt-2 w-full py-2.5 rounded-xl bg-[#2F6F68] text-white text-xs font-bold"
              >
                العودة لتسجيل الدخول
              </button>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#BACCC7]">
                  البريد الإلكتروني
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 right-0 pr-3.5 flex items-center pointer-events-none text-[#718782]">
                    <Mail className="w-4 h-4" />
                  </div>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="name@example.com"
                    dir="ltr"
                    className="w-full pr-10 pl-4 py-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#152320] border border-[#DEE7E2] dark:border-[#283C37] text-sm text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] focus:outline-hidden focus:border-[#2F6F68]"
                  />
                </div>
              </div>

              <button
                type="submit"
                className="w-full py-3.5 rounded-2xl bg-[#2F6F68] hover:bg-[#245650] text-white text-sm font-bold shadow-md cursor-pointer transition-all"
              >
                إرسال الرابط
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};
