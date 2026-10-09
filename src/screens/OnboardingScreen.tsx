import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';
import { Sparkles, ArrowLeft, ArrowRight, Check } from 'lucide-react';
import { AssistantTone } from '../types';

export const OnboardingScreen: React.FC = () => {
  const { completeOnboarding, navigate } = useApp();

  const [step, setStep] = useState(1);
  const [challenge, setChallenge] = useState('clutter');
  const [preferredTime, setPreferredTime] = useState<'morning' | 'afternoon' | 'night'>('morning');
  const [tone, setTone] = useState<AssistantTone>('friendly');

  const handleFinish = () => {
    completeOnboarding({
      activityTime: preferredTime,
      preferredTone: tone,
    });
    navigate('/home');
  };

  return (
    <div className="min-h-screen bg-[#F7F8F6] dark:bg-[#101A18] flex flex-col justify-between p-6 max-w-lg mx-auto">
      {/* Top Header */}
      <header className="flex items-center justify-between pt-4">
        <HandelhaMark size={36} />
        <div className="flex items-center gap-1.5">
          {[1, 2, 3].map((s) => (
            <div
              key={s}
              className={`h-2 rounded-full transition-all duration-300 ${
                s === step
                  ? 'w-7 bg-[#2F6F68] dark:bg-[#76BCAF]'
                  : s < step
                  ? 'w-2.5 bg-[#4E9B77]'
                  : 'w-2.5 bg-[#DCE7E2] dark:bg-[#283C37]'
              }`}
            />
          ))}
        </div>
      </header>

      {/* Step Content */}
      <main className="my-auto py-8 space-y-6">
        {step === 1 && (
          <div className="space-y-4">
            <div className="space-y-1">
              <span className="text-[11px] font-bold text-[#2F6F68] dark:text-[#7BC3B6]">
                الخطوة الأولى
              </span>
              <h1 className="text-2xl font-bold text-[#1E2D2B] dark:text-white">
                إيه أكتر تحدي بيقابلك في يومك؟
              </h1>
              <p className="text-xs text-[#637974] dark:text-[#9FB3AE]">
                هنساعدك تهندل يومك بأقل مجهود ذهني ممكن.
              </p>
            </div>

            <div className="space-y-2.5 pt-2">
              {[
                { id: 'clutter', title: 'تشتت المهام وتراكمها في دماغي', desc: 'أفكار كتير ومش عارف أبدأ منين' },
                { id: 'procrastination', title: 'التسويف وصعوبة البدء في أول خطوة', desc: 'الحاجة شكلها كبير وبتكسّل أبدأ' },
                { id: 'focus', title: 'صعوبة الحفاظ على التركيز المتواصل', desc: 'أي إشعار أو فكرة جانبية بتشتتني' },
              ].map((opt) => {
                const isSelected = challenge === opt.id;
                return (
                  <button
                    key={opt.id}
                    onClick={() => setChallenge(opt.id)}
                    className={`w-full p-4 rounded-3xl border text-right transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-[#EEF5F2] dark:bg-[#1E3731] border-[#2F6F68] dark:border-[#76BCAF]'
                        : 'bg-white dark:bg-[#1A2825] border-[#DFE8E3] dark:border-[#283C37]'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                        {opt.title}
                      </span>
                      {isSelected && <Check className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF] stroke-[3]" />}
                    </div>
                    <p className="text-xs text-[#647974] dark:text-[#9FB3AE]">{opt.desc}</p>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-4">
            <div className="space-y-1">
              <span className="text-[11px] font-bold text-[#2F6F68] dark:text-[#7BC3B6]">
                الخطوة الثانية
              </span>
              <h1 className="text-2xl font-bold text-[#1E2D2B] dark:text-white">
                إيه الوقت اللي طاقتك فيه في أحسن حالاتها؟
              </h1>
              <p className="text-xs text-[#637974] dark:text-[#9FB3AE]">
                هننظم المهام الأهم والأعمق في ساعتك الذهبية.
              </p>
            </div>

            <div className="space-y-2.5 pt-2">
              {[
                { id: 'morning', title: '🌅 الصباح الباكر', desc: 'الذهن صافي والهدوء عالي (قبل الظهر)' },
                { id: 'afternoon', title: '☀️ منتصف النهار', desc: 'في أوج النشاط والتفاعل (الظهر والعصر)' },
                { id: 'night', title: '🌙 المساء والليل', desc: 'هدوء الليل والتركيز في السكون' },
              ].map((opt) => {
                const isSelected = preferredTime === opt.id;
                return (
                  <button
                    key={opt.id}
                    onClick={() => setPreferredTime(opt.id as any)}
                    className={`w-full p-4 rounded-3xl border text-right transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-[#EEF5F2] dark:bg-[#1E3731] border-[#2F6F68] dark:border-[#76BCAF]'
                        : 'bg-white dark:bg-[#1A2825] border-[#DFE8E3] dark:border-[#283C37]'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                        {opt.title}
                      </span>
                      {isSelected && <Check className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF] stroke-[3]" />}
                    </div>
                    <p className="text-xs text-[#647974] dark:text-[#9FB3AE]">{opt.desc}</p>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="space-y-4">
            <div className="space-y-1">
              <span className="text-[11px] font-bold text-[#2F6F68] dark:text-[#7BC3B6]">
                الخطوة الثالثة
              </span>
              <h1 className="text-2xl font-bold text-[#1E2D2B] dark:text-white">
                تحب أسلوب مساعد هندلها إزاي؟
              </h1>
              <p className="text-xs text-[#637974] dark:text-[#9FB3AE]">
                تقدر تغير الأسلوب في أي وقت من الإعدادات.
              </p>
            </div>

            <div className="space-y-2.5 pt-2">
              {[
                { id: 'friendly', title: 'ودودة ومصرية هادئة ✨', desc: 'لهجة مريحة، تفاؤل، وتشجيع هادي بدون ضغط' },
                { id: 'concise', title: 'مختصرة وسريعة ⚡', desc: 'خطوات عملية واضحة على طول بدون إطالة' },
                { id: 'formal', title: 'فصحى متزنة 🌿', desc: 'لغة رصينة وهادئة بوضوح وتنظيم فائق' },
              ].map((opt) => {
                const isSelected = tone === opt.id;
                return (
                  <button
                    key={opt.id}
                    onClick={() => setTone(opt.id as any)}
                    className={`w-full p-4 rounded-3xl border text-right transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-[#EEF5F2] dark:bg-[#1E3731] border-[#2F6F68] dark:border-[#76BCAF]'
                        : 'bg-white dark:bg-[#1A2825] border-[#DFE8E3] dark:border-[#283C37]'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                        {opt.title}
                      </span>
                      {isSelected && <Check className="w-4 h-4 text-[#2F6F68] dark:text-[#76BCAF] stroke-[3]" />}
                    </div>
                    <p className="text-xs text-[#647974] dark:text-[#9FB3AE]">{opt.desc}</p>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </main>

      {/* Bottom Navigation */}
      <footer className="pt-4 flex items-center justify-between gap-4">
        {step > 1 ? (
          <button
            onClick={() => setStep(step - 1)}
            className="px-5 py-3 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-xs font-bold text-[#556965] dark:text-[#A7BCB7] hover:text-[#1E2D2B] cursor-pointer flex items-center gap-1"
          >
            <ArrowRight className="w-4 h-4" />
            السابق
          </button>
        ) : (
          <div />
        )}

        {step < 3 ? (
          <button
            onClick={() => setStep(step + 1)}
            className="px-6 py-3 rounded-2xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold flex items-center gap-1.5 shadow-md cursor-pointer transition-all"
          >
            <span>التالي</span>
            <ArrowLeft className="w-4 h-4" />
          </button>
        ) : (
          <button
            onClick={handleFinish}
            className="px-7 py-3 rounded-2xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold flex items-center gap-2 shadow-md cursor-pointer transition-all active:scale-95"
          >
            <Sparkles className="w-4 h-4" />
            <span>ابدأ يومك بهدوء</span>
          </button>
        )}
      </footer>
    </div>
  );
};
