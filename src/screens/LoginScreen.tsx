import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaLogo, HandelhaMark } from '../components/HandelhaBrand';
import { Mail, Lock, Eye, EyeOff, Sparkles, ArrowLeft } from 'lucide-react';

export const LoginScreen: React.FC = () => {
  const { login, navigate } = useApp();

  const [email, setEmail] = useState('ahmed@handelha.app');
  const [password, setPassword] = useState('123456');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;

    setIsLoading(true);
    setTimeout(() => {
      setIsLoading(false);
      login(email.trim(), 'أحمد');
    }, 600);
  };

  return (
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] flex flex-col justify-center px-4 sm:px-6 py-12">
      <div className="max-w-md w-full mx-auto space-y-8">
        {/* Brand Hero */}
        <div className="text-center space-y-3">
          <div className="flex justify-center">
            <HandelhaMark size={56} />
          </div>
          <div>
            <h1 className="text-3xl font-black text-[#1E2D2B] dark:text-white tracking-tight">
              هندلها
            </h1>
            <p className="text-xs text-[#556965] dark:text-[#A8BBB6] mt-1">
              مرحباً بعودتك إلى مساحتك الهادئة
            </p>
          </div>
        </div>

        {/* Card Form */}
        <div className="p-6 sm:p-8 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] shadow-sm space-y-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email Field */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#BACCC7]">
                البريد الإلكتروني
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 right-0 pr-3.5 flex items-center pointer-events-none text-[#718782] dark:text-[#8AA09A]">
                  <Mail className="w-4 h-4" />
                </div>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@example.com"
                  dir="ltr"
                  className="w-full pr-10 pl-4 py-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#152320] border border-[#DEE7E2] dark:border-[#283C37] text-sm text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] focus:outline-hidden focus:border-[#2F6F68] transition-colors"
                />
              </div>
            </div>

            {/* Password Field */}
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#BACCC7]">
                  كلمة المرور
                </label>
                <button
                  type="button"
                  onClick={() => navigate('/forgot-password')}
                  className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline cursor-pointer"
                >
                  نسيت كلمة المرور؟
                </button>
              </div>
              <div className="relative">
                <div className="absolute inset-y-0 right-0 pr-3.5 flex items-center pointer-events-none text-[#718782] dark:text-[#8AA09A]">
                  <Lock className="w-4 h-4" />
                </div>
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  dir="ltr"
                  className="w-full pr-10 pl-10 py-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#152320] border border-[#DEE7E2] dark:border-[#283C37] text-sm text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] focus:outline-hidden focus:border-[#2F6F68] transition-colors"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 left-0 pl-3.5 flex items-center text-[#718782] hover:text-[#1E2D2B] dark:hover:text-white cursor-pointer"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3.5 px-4 rounded-2xl bg-[#2F6F68] hover:bg-[#245650] text-white text-sm font-bold shadow-md hover:shadow-lg transition-all cursor-pointer flex items-center justify-center gap-2 disabled:opacity-50 active:scale-98"
            >
              {isLoading ? (
                <span>جاري تسجيل الدخول...</span>
              ) : (
                <>
                  <span>تسجيل الدخول</span>
                  <ArrowLeft className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {/* Quick Demo Access */}
          <div className="pt-2 border-t border-[#EDF4F1] dark:border-[#223531]">
            <button
              type="button"
              onClick={() => {
                login('ahmed@handelha.app', 'أحمد');
              }}
              className="w-full py-2.5 px-4 rounded-xl bg-[#EEF5F2] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9] text-xs font-bold hover:bg-[#DEEDE7] transition-colors cursor-pointer flex items-center justify-center gap-1.5"
            >
              <Sparkles className="w-4 h-4" />
              <span>دخول تجريبي فوري (أحمد)</span>
            </button>
          </div>
        </div>

        {/* Footer Link */}
        <div className="text-center text-xs text-[#5D736E] dark:text-[#9FB3AE]">
          ليس لديك حساب؟{' '}
          <button
            onClick={() => navigate('/signup')}
            className="font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline cursor-pointer"
          >
            إنشاء حساب جديد
          </button>
        </div>
      </div>
    </div>
  );
};
