import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';
import { Mail, Lock, Eye, EyeOff, Sparkles, ArrowLeft, Check, ShieldCheck } from 'lucide-react';

export const LoginScreen: React.FC = () => {
  const { login, navigate } = useApp();

  const [email, setEmail] = useState('ahmed@handelha.app');
  const [password, setPassword] = useState('123456');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [socialLoading, setSocialLoading] = useState<'google' | 'apple' | 'facebook' | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) return;

    setIsLoading(true);
    setTimeout(() => {
      setIsLoading(false);
      login(email.trim(), 'أحمد');
      navigate('/home');
    }, 600);
  };

  const handleSocialLogin = (provider: 'google' | 'apple' | 'facebook', name: string) => {
    setSocialLoading(provider);
    setTimeout(() => {
      setSocialLoading(null);
      login(`user.${provider}@handelha.app`, name);
      navigate('/home');
    }, 700);
  };

  return (
    <div className="min-h-screen bg-linear-to-b from-[#FDF9F5] via-[#F8FAF9] to-[#EEF5F2] dark:from-[#0E1715] dark:via-[#111C19] dark:to-[#162723] flex flex-col justify-center items-center px-4 sm:px-6 py-10 transition-colors duration-300 relative overflow-hidden select-none">
      {/* Background Aesthetic Ambient Shapes & Gradients */}
      <div className="absolute -top-24 -right-24 w-96 h-96 bg-linear-to-br from-[#E27D66]/15 to-[#F5A392]/5 dark:from-[#E27D66]/10 dark:to-transparent rounded-full blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 -left-28 w-80 h-80 bg-linear-to-tr from-[#235D55]/15 to-[#76C6B7]/10 dark:from-[#235D55]/20 dark:to-transparent rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -bottom-20 right-1/4 w-96 h-96 bg-linear-to-t from-[#2F6F68]/12 to-transparent rounded-full blur-3xl pointer-events-none" />

      {/* Subtle organic decorative ring */}
      <div className="absolute top-12 left-1/2 -translate-x-1/2 w-[600px] h-[600px] rounded-full border border-[#235D55]/5 dark:border-[#76C6B7]/5 pointer-events-none" />

      <div className="max-w-md w-full relative z-10 space-y-6 animate-in fade-in slide-in-from-bottom-5 duration-500">
        {/* Brand Header with Redesigned Emblem */}
        <div className="text-center space-y-3">
          <div className="inline-flex p-3 rounded-[28px] bg-white/80 dark:bg-[#182724]/80 backdrop-blur-md border border-[#DEE7E2]/70 dark:border-[#273D38] shadow-md hover:scale-105 transition-transform duration-300">
            <HandelhaMark size={56} animated={true} />
          </div>

          <div className="space-y-1">
            <div className="flex items-center justify-center gap-2">
              <h1 className="text-2xl font-black text-[#1B2926] dark:text-white tracking-tight">
                Handalha
              </h1>
              <span className="text-xs font-bold px-2 py-0.5 rounded-lg bg-[#235D55]/10 dark:bg-[#76C6B7]/20 text-[#235D55] dark:text-[#76C6B7]">
                هندلها
              </span>
            </div>
            <h2 className="text-lg font-bold text-[#1E2D2B] dark:text-white">
              تسجيل الدخول
            </h2>
            <p className="text-xs text-[#5E736E] dark:text-[#9FB3AE]">
              أهلاً بك مجدداً.. خطوات هادية وإنجاز أكيد
            </p>
          </div>
        </div>

        {/* Floating Modern Auth Card */}
        <div className="p-6 sm:p-8 rounded-[32px] bg-white/95 dark:bg-[#182724]/95 backdrop-blur-xl border border-[#DFE8E3] dark:border-[#283C37] shadow-xl shadow-black/5 space-y-5">
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email Field */}
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

            {/* Password Field */}
            <div className="space-y-1.5 text-right">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-[#3B4E4A] dark:text-[#BACCC7]">
                  كلمة المرور
                </label>
                <button
                  type="button"
                  onClick={() => navigate('/forgot-password')}
                  className="text-[11px] font-bold text-[#E26D58] hover:text-[#C55743] hover:underline cursor-pointer"
                >
                  نسيت كلمة المرور؟
                </button>
              </div>

              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  dir="ltr"
                  className="w-full pl-10 pr-10 py-3 rounded-2xl text-xs bg-[#F8FAF9] dark:bg-[#152320] border border-[#D7E3DE] dark:border-[#2A403A] text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] focus:outline-hidden focus:border-[#235D55] dark:focus:border-[#76C6B7] focus:ring-2 focus:ring-[#235D55]/15 transition-all text-left font-mono tracking-widest"
                />
                <div className="absolute inset-y-0 right-0 pr-3.5 flex items-center pointer-events-none text-[#718782] dark:text-[#8AA09A]">
                  <Lock className="w-4 h-4" />
                </div>
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 left-0 pl-3.5 flex items-center text-[#718782] dark:text-[#8AA09A] hover:text-[#1E2D2B] dark:hover:text-white transition-colors cursor-pointer"
                  title={showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور'}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Remember Me */}
            <div className="flex items-center justify-between pt-1 text-xs">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                  className="w-4 h-4 rounded-md border-[#C3D4CE] text-[#235D55] focus:ring-[#235D55] accent-[#235D55] cursor-pointer"
                />
                <span className="text-[#556A65] dark:text-[#9FB3AE] text-xs">
                  تذكر بيانات الدخول
                </span>
              </label>
            </div>

            {/* Primary Submit Button */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3.5 px-4 rounded-2xl bg-linear-to-r from-[#235D55] via-[#2F6F68] to-[#3B7F76] hover:from-[#1D4E47] hover:to-[#2B635B] text-white text-xs font-bold transition-all shadow-md shadow-[#235D55]/25 hover:shadow-lg hover:shadow-[#235D55]/30 flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50 active:scale-98"
            >
              {isLoading ? (
                <div className="flex items-center gap-2">
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  <span>جاري الدخول...</span>
                </div>
              ) : (
                <>
                  <span>تسجيل الدخول</span>
                  <ArrowLeft className="w-4 h-4" />
                </>
              )}
            </button>
          </form>

          {/* Elegant Divider */}
          <div className="relative flex items-center justify-center pt-1">
            <div className="border-t border-[#E3ECE7] dark:border-[#273D38] w-full" />
            <span className="bg-white dark:bg-[#182724] px-3 text-[11px] text-[#788E89] dark:text-[#8CA09A] shrink-0 font-medium">
              أو المتابعة باستخدام
            </span>
          </div>

          {/* Modern Circular / Rounded Social Buttons */}
          <div className="flex items-center justify-center gap-4">
            {/* Google */}
            <button
              type="button"
              onClick={() => handleSocialLogin('google', 'أحمد (Google)')}
              disabled={socialLoading !== null || isLoading}
              className="w-12 h-12 rounded-2xl bg-[#F7FAF8] dark:bg-[#152320] border border-[#D5E3DE] dark:border-[#2A413B] hover:border-[#235D55]/40 hover:bg-white dark:hover:bg-[#1B2C28] flex items-center justify-center transition-all shadow-2xs hover:shadow-xs hover:scale-105 active:scale-95 cursor-pointer disabled:opacity-50"
              title="Google"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                />
              </svg>
            </button>

            {/* Apple */}
            <button
              type="button"
              onClick={() => handleSocialLogin('apple', 'أحمد (Apple)')}
              disabled={socialLoading !== null || isLoading}
              className="w-12 h-12 rounded-2xl bg-[#F7FAF8] dark:bg-[#152320] border border-[#D5E3DE] dark:border-[#2A413B] hover:border-[#235D55]/40 hover:bg-white dark:hover:bg-[#1B2C28] flex items-center justify-center text-[#1E2D2B] dark:text-white transition-all shadow-2xs hover:shadow-xs hover:scale-105 active:scale-95 cursor-pointer disabled:opacity-50"
              title="Apple"
            >
              <svg className="w-5 h-5 fill-current" viewBox="0 0 24 24">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.63-.78 1.06-1.85.94-2.94-.93.04-2.02.63-2.67 1.39-.58.67-.99 1.76-.85 2.81 1.04.08 2.06-.52 2.58-1.26z" />
              </svg>
            </button>

            {/* Facebook */}
            <button
              type="button"
              onClick={() => handleSocialLogin('facebook', 'أحمد (Facebook)')}
              disabled={socialLoading !== null || isLoading}
              className="w-12 h-12 rounded-2xl bg-[#F7FAF8] dark:bg-[#152320] border border-[#D5E3DE] dark:border-[#2A413B] hover:border-[#235D55]/40 hover:bg-white dark:hover:bg-[#1B2C28] flex items-center justify-center text-[#1877F2] transition-all shadow-2xs hover:shadow-xs hover:scale-105 active:scale-95 cursor-pointer disabled:opacity-50"
              title="Facebook"
            >
              <svg className="w-5 h-5 fill-current" viewBox="0 0 24 24">
                <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
              </svg>
            </button>
          </div>
        </div>

        {/* Switch to Sign Up */}
        <div className="text-center">
          <p className="text-xs text-[#5E736E] dark:text-[#9FB3AE]">
            ليس لديك حساب بعد؟{' '}
            <button
              type="button"
              onClick={() => navigate('/signup')}
              className="font-bold text-[#235D55] dark:text-[#76C6B7] hover:underline cursor-pointer"
            >
              إنشاء حساب جديد
            </button>
          </p>
        </div>
      </div>
    </div>
  );
};
