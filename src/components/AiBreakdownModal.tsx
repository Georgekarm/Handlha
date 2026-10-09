import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  X,
  Sparkles,
  Clock,
  Layers,
  CheckCircle2,
  HelpCircle,
  ChevronDown,
  ChevronUp,
  Link as LinkIcon,
  Timer,
  Flag,
} from 'lucide-react';
import { ProposedPhaseItem } from '../types';

export const AiBreakdownModal: React.FC = () => {
  const { isAiBreakdownOpen, setIsAiBreakdownOpen, activeProjectWorkspace, isDarkMode, createTask, updateProject } = useApp();

  const [answeredQuestion, setAnsweredQuestion] = useState(false);
  const [isAnsweringNow, setIsAnsweringNow] = useState(false);
  const [answerText, setAnswerText] = useState('');
  const [clarification, setClarification] = useState<string | null>(null);
  const [expandedPhase, setExpandedPhase] = useState<number>(0);

  const phases: ProposedPhaseItem[] = [
    {
      title: 'المرحلة 1: التخطيط والمتطلبات الأساسية',
      duration: '5 ساعات',
      tasks: [
        {
          title: 'تحديد ميزات الـ MVP واستبعاد المشتتات',
          duration: '2س',
          priority: 'عالية',
          priorityColor: '#C9826C',
        },
        {
          title: 'هندسة بنية المجلدات وإدارة الحالة ومسارات التنقل',
          duration: '3س',
          priority: 'متوسطة',
          priorityColor: '#B7863C',
          dependency: 'اعتماد الميزات',
        },
      ],
    },
    {
      title: 'المرحلة 2: التصميم وبناء هوية الهدوء',
      duration: '7 ساعات',
      tasks: [
        {
          title: 'تصميم شاشات التدفق الرئيسي ونظام الألوان الهادئ',
          duration: '4س',
          priority: 'عالية',
          priorityColor: '#C9826C',
        },
        {
          title: 'مراجعة المكونات المشتركة ونصوص الواجهة واللغة العربية',
          duration: '3س',
          priority: 'هادئة',
          priorityColor: '#245650',
          dependency: 'اكتمال التصميم الأولي',
        },
      ],
    },
    {
      title: 'المرحلة 3: التطوير والربط الذكي',
      duration: '8 ساعات',
      tasks: [
        {
          title: 'برمجة شاشة تسجيل الدخول والمصادقة وتدفق الاستخدام',
          duration: '3س',
          priority: 'عالية',
          priorityColor: '#B96368',
        },
        {
          title: 'بناء تبويبات مساحة المشروع والتحليلات الأسبوعية',
          duration: '5س',
          priority: 'عالية',
          priorityColor: '#C9826C',
          dependency: 'شاشة المصادقة',
        },
      ],
    },
    {
      title: 'المرحلة 4: الاختبار والإطلاق التجريبي',
      duration: '4 ساعات',
      tasks: [
        {
          title: 'فحص الأداء والتجربة على مختلف الشاشات والأجهزة',
          duration: '2.5س',
          priority: 'متوسطة',
          priorityColor: '#B7863C',
        },
        {
          title: 'إنشاء أول نسخة تجريبية ونشرها للمختبرين لجمع الآراء',
          duration: '1.5س',
          priority: 'عالية',
          priorityColor: '#C9826C',
          dependency: 'فحص الأداء',
        },
      ],
    },
  ];

  if (!isAiBreakdownOpen) return null;

  const handleAcceptAll = () => {
    phases.forEach((p) => {
      p.tasks.forEach((t) => {
        createTask({
          title: t.title,
          priority: t.priority === 'عالية' ? 'high' : t.priority === 'عاجلة' ? 'urgent' : 'medium',
          status: 'planned',
          projectId: activeProjectWorkspace?.id,
        });
      });
    });

    if (activeProjectWorkspace) {
      updateProject(activeProjectWorkspace.id, {
        progressPercent: 0.15,
        subtasks: phases.map((p) => p.title),
      });
    }

    setIsAiBreakdownOpen(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-xs p-0 sm:p-4 overflow-y-auto animate-in fade-in duration-200">
      <div className="w-full max-w-2xl rounded-t-3xl sm:rounded-3xl p-6 max-h-[90vh] overflow-y-auto shadow-2xl transition-all bg-white dark:bg-[#182724] border border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-[#EFF6F2]">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-[#D9ECE8] dark:bg-[#244F48] text-[#245650] dark:text-[#9DD2C5]">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-xl font-black flex items-center gap-2">
                <span>تقسيم المشروع على الرايق</span>
                <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-[#2F6F68]/10 text-[#2F6F68] dark:bg-[#76BCAF]/20 dark:text-[#76BCAF]">
                  مصري 🇪🇬
                </span>
              </h3>
              <p className="text-xs text-[#647370] dark:text-[#B7C9C2]">
                صيغتلك خطة متكتكة تناسب هدفك بدون كروكة ولا تشتيت
              </p>
            </div>
          </div>
          <button
            onClick={() => setIsAiBreakdownOpen(false)}
            className="p-1.5 rounded-full hover:bg-black/5 dark:hover:bg-white/10 text-[#99A6A2]"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-4 rounded-2xl bg-[#F7F8F6] dark:bg-[#203530] border border-[#DDE7E2] dark:border-[#354D46] mb-4">
          <div className="flex items-center gap-2 mb-1 text-xs font-bold text-[#245650] dark:text-[#76BCAF]">
            <Flag className="w-3.5 h-3.5" />
            <span>الهدف الأساسي:</span>
          </div>
          <p className="text-sm font-extrabold text-[#1E2D2B] dark:text-[#EFF6F2] mb-3">
            {activeProjectWorkspace?.description || 'إطلاق أول نسخة تجريبية قابلة للاستخدام.'}
          </p>

          <div className="grid grid-cols-3 gap-2">
            <div className="p-2.5 rounded-xl bg-[#D9ECE8]/50 dark:bg-[#244F48]/40 border border-[#2F6F68]/20 text-center">
              <Clock className="w-4 h-4 mx-auto mb-1 text-[#245650] dark:text-[#76BCAF]" />
              <div className="text-xs font-bold text-[#245650] dark:text-[#9DD2C5]">24 ساعة</div>
              <div className="text-[10px] text-[#647370] dark:text-[#B7C9C2]">التقدير الأولي</div>
            </div>
            <div className="p-2.5 rounded-xl bg-[#E9E8F2]/50 dark:bg-[#3D3B5C]/40 border border-[#7773A1]/20 text-center">
              <Layers className="w-4 h-4 mx-auto mb-1 text-[#7773A1] dark:text-[#A9A7CD]" />
              <div className="text-xs font-bold text-[#7773A1] dark:text-[#A9A7CD]">4 مراحل</div>
              <div className="text-[10px] text-[#647370] dark:text-[#B7C9C2]">المراحل المنظمة</div>
            </div>
            <div className="p-2.5 rounded-xl bg-[#F3E1DB]/50 dark:bg-[#563A32]/40 border border-[#C9826C]/20 text-center">
              <CheckCircle2 className="w-4 h-4 mx-auto mb-1 text-[#C9826C] dark:text-[#D39A83]" />
              <div className="text-xs font-bold text-[#C9826C] dark:text-[#D39A83]">18 مهمة</div>
              <div className="text-[10px] text-[#647370] dark:text-[#B7C9C2]">المهام المقترحة</div>
            </div>
          </div>
        </div>

        <div className="p-4 rounded-2xl bg-[#F5EBCF]/60 dark:bg-[#3A3223]/50 border border-[#B7863C]/30 mb-5">
          <div className="flex items-center gap-2 mb-2">
            <HelpCircle className="w-4 h-4 text-[#B7863C] dark:text-[#D4B16B]" />
            <span className="text-xs font-bold text-[#B7863C] dark:text-[#D4B16B]">
              نقطة محتاجة توضيح يا بطل:
            </span>
          </div>
          <p className="text-xs leading-relaxed text-[#1E2D2B] dark:text-[#EFF6F2] mb-3">
            «تسجيل الدخول هيكون بإيميل بس ولا سوشيال كمان (Google / Apple)؟ علشان نظبط الوقت بالمللي ومنتعطلش.»
          </p>

          {answeredQuestion ? (
            <div className="flex items-center gap-2 p-2.5 rounded-xl bg-white dark:bg-[#182724] border border-[#4E9B77]/30 text-xs text-[#1E2D2B] dark:text-[#EFF6F2]">
              <CheckCircle2 className="w-4 h-4 text-[#4E9B77] dark:text-[#7CCAA2]" />
              <span>تسلم يا غالي، اتوضحت: {clarification || 'إيميل وسوشيال معاً'} (كده الخطة اتظبطت بالمللي) 👌</span>
            </div>
          ) : isAnsweringNow ? (
            <div className="space-y-2">
              <input
                type="text"
                value={answerText}
                onChange={(e) => setAnswerText(e.target.value)}
                placeholder="اكتب إجابتك هنا..."
                className="w-full px-3 py-2 rounded-xl text-xs border focus:outline-hidden bg-white dark:bg-[#182724] border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-white"
              />
              <div className="flex gap-2">
                <button
                  onClick={() => {
                    setAnsweredQuestion(true);
                    setClarification(answerText || 'إيميل وسوشيال معاً');
                    setIsAnsweringNow(false);
                  }}
                  className="px-3 py-1.5 rounded-lg text-xs font-bold bg-[#B7863C] text-white hover:opacity-90"
                >
                  تأكيد الإجابة
                </button>
                <button
                  onClick={() => setIsAnsweringNow(false)}
                  className="px-3 py-1.5 rounded-lg text-xs text-[#647370] dark:text-[#B7C9C2]"
                >
                  إلغاء
                </button>
              </div>
            </div>
          ) : (
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setIsAnsweringNow(true)}
                className="px-3 py-1.5 rounded-lg text-xs font-bold bg-[#B7863C] text-white hover:opacity-90 cursor-pointer"
              >
                أجاوب دلوقتي
              </button>
              <button
                type="button"
                onClick={() => {
                  setAnsweredQuestion(true);
                  setClarification('سيبها لاحقاً حسب الوقت');
                }}
                className="px-3 py-1.5 rounded-lg text-xs font-medium border border-[#B7863C]/40 text-[#B7863C] dark:text-[#D4B16B] hover:bg-black/5 cursor-pointer"
              >
                سيبها لاحقاً
              </button>
            </div>
          )}
        </div>

        <div className="space-y-3 mb-6">
          <div className="flex items-center justify-between text-xs font-bold text-[#647370] dark:text-[#B7C9C2]">
            <span>المراحل والمهام المقترحة:</span>
            <span>قابلة للطي والتعديل</span>
          </div>

          {phases.map((phase, idx) => (
            <div
              key={idx}
              className={`rounded-2xl border transition-all ${
                isDarkMode ? 'bg-[#203530]/50 border-[#354D46]' : 'bg-[#F7F8F6] border-[#DDE7E2]'
              }`}
            >
              <button
                type="button"
                onClick={() => setExpandedPhase(expandedPhase === idx ? -1 : idx)}
                className="w-full flex items-center justify-between p-3.5 text-right cursor-pointer"
              >
                <div className="flex items-center gap-2.5">
                  <div className="p-1.5 rounded-lg bg-[#D9ECE8] dark:bg-[#244F48] text-[#245650] dark:text-[#9DD2C5]">
                    <Layers className="w-4 h-4" />
                  </div>
                  <div>
                    <h4 className="text-xs font-bold text-[#1E2D2B] dark:text-[#EFF6F2]">
                      {phase.title}
                    </h4>
                    <span className="text-[11px] text-[#647370] dark:text-[#B7C9C2]">
                      {phase.duration} • {phase.tasks.length} مهام
                    </span>
                  </div>
                </div>
                {expandedPhase === idx ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
              </button>

              {expandedPhase === idx && (
                <div className="px-3.5 pb-3.5 space-y-2 border-t border-black/5 dark:border-white/5 pt-2">
                  {phase.tasks.map((task, tIdx) => (
                    <div
                      key={tIdx}
                      className={`p-3 rounded-xl border ${
                        isDarkMode ? 'bg-[#182724] border-[#354D46]' : 'bg-white border-[#DDE7E2]'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-2 mb-1.5">
                        <span className="text-xs font-bold leading-snug">{task.title}</span>
                        <span
                          style={{ color: task.priorityColor }}
                          className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-black/5 dark:bg-white/5 whitespace-nowrap"
                        >
                          {task.priority}
                        </span>
                      </div>
                      <div className="flex items-center gap-3 text-[11px] text-[#647370] dark:text-[#B7C9C2]">
                        <span className="flex items-center gap-1">
                          <Timer className="w-3 h-3 text-[#99A6A2]" />
                          {task.duration}
                        </span>
                        {task.dependency && (
                          <span className="flex items-center gap-1 text-[#7773A1] dark:text-[#A9A7CD]">
                            <LinkIcon className="w-3 h-3" />
                            تعتمد على: {task.dependency}
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>

        <div className="flex items-center gap-3 pt-3 border-t border-black/5 dark:border-white/5">
          <button
            type="button"
            onClick={handleAcceptAll}
            className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl font-bold text-sm bg-[#245650] text-white dark:bg-[#9DD2C5] dark:text-[#101A18] hover:opacity-90 cursor-pointer transition-opacity"
          >
            <CheckCircle2 className="w-4 h-4" />
            قبول الكل واعتماد الخطة
          </button>
          <button
            type="button"
            onClick={() => setIsAiBreakdownOpen(false)}
            className="px-5 py-3 rounded-xl font-bold text-sm border border-[#DDE7E2] dark:border-[#354D46] text-[#647370] dark:text-[#B7C9C2] hover:bg-black/5 dark:hover:bg-white/5 cursor-pointer"
          >
            إلغاء
          </button>
        </div>
      </div>
    </div>
  );
};
