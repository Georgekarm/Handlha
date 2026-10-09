import React, { useState, useRef, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import { HandelhaMark } from '../components/HandelhaBrand';
import {
  Send,
  Mic,
  Play,
  CheckCircle2,
  Check,
  Layers,
  Clock,
  Calendar,
  ArrowUpRight,
  Sparkles,
} from 'lucide-react';
import { TaskPriority } from '../types';

export const ChatScreen: React.FC = () => {
  const {
    chatMessages,
    sendChatMessage,
    sendVoiceMessage,
    confirmProposal,
    setIsAiBreakdownOpen,
    setActiveFocusTask,
    navigate,
    user,
  } = useApp();

  const [inputText, setInputText] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [chatMessages]);

  const handleSend = (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!inputText.trim()) return;

    sendChatMessage(inputText.trim());
    setInputText('');
  };

  const handleSimulateVoice = () => {
    setIsRecording(true);
    setTimeout(() => {
      setIsRecording(false);
      sendVoiceMessage('0:14');
    }, 1500);
  };

  const getPriorityBadge = (p?: TaskPriority) => {
    switch (p) {
      case 'urgent':
        return { label: 'عاجل جداً', bg: 'bg-[#FBE8E6] text-[#B83A3A] dark:bg-[#462020] dark:text-[#F39F9F]' };
      case 'high':
        return { label: 'أولوية عالية', bg: 'bg-[#FDF0DE] text-[#B76F1D] dark:bg-[#3D2C1B] dark:text-[#ECC28C]' };
      case 'medium':
        return { label: 'متوسطة', bg: 'bg-[#EEF3F0] text-[#2F6F68] dark:bg-[#1E332E] dark:text-[#88C6B9]' };
      case 'low':
      default:
        return { label: 'هادئة', bg: 'bg-[#EBF3F8] text-[#3E7092] dark:bg-[#1A2C38] dark:text-[#88BCD8]' };
    }
  };

  return (
    <div className="flex flex-col h-screen max-w-2xl mx-auto pb-24 pt-2">
      {/* Header */}
      <header className="px-4 py-3 border-b border-[#E3ECE7] dark:border-[#263C37] bg-white/80 dark:bg-[#1A2825]/80 backdrop-blur-md flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <HandelhaMark size={32} />
          <div>
            <h1 className="text-sm font-bold text-[#1E2D2B] dark:text-white flex items-center gap-1.5">
              <span>مساعد هندلها الذكي</span>
              <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-[#2F6F68]/10 text-[#2F6F68] dark:bg-[#76BCAF]/20 dark:text-[#76BCAF]">
                مصري وذكي
              </span>
            </h1>
            <p className="text-[11px] text-[#6A7E7A] dark:text-[#9FB3AE]">
              مساعدك الشخصي.. اسأل في أي موضوع أو حسابات أو نظّم مهامك وشغلك
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsAiBreakdownOpen(true)}
            className="p-2 rounded-xl bg-[#EEF5F2] dark:bg-[#203934] text-[#2F6F68] dark:text-[#88C6B9] text-xs font-bold flex items-center gap-1 hover:bg-[#DEEDE7] transition-colors cursor-pointer"
            title="تقسيم مشروع"
          >
            <Layers className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">تقسيم على الرايق</span>
          </button>
        </div>
      </header>

      {/* Messages Stream */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {chatMessages.map((msg) => {
          const isUser = msg.isFromUser || msg.sender === 'user';
          const hasProposal = Boolean(msg.proposalTitle || msg.proposal);
          const proposalTitle = msg.proposalTitle || msg.proposal?.title;
          const isConfirmed = msg.isConfirmed || msg.proposal?.isConfirmed || msg.isDirectCreatedTask;
          const hasAudio = msg.type === 'voiceNote' || msg.isAudio || Boolean(msg.audioDuration);
          const priorityBadge = getPriorityBadge(msg.proposalPriority);

          return (
            <div
              key={msg.id}
              className={`flex flex-col ${isUser ? 'items-end' : 'items-start'} space-y-1.5`}
            >
              {/* Message Bubble */}
              <div
                className={`max-w-[85%] sm:max-w-[75%] rounded-3xl p-4 text-sm leading-relaxed shadow-2xs ${
                  isUser
                    ? 'bg-[#D9ECE8] dark:bg-[#244F48] text-[#1E2D2B] dark:text-[#F0F7F4] rounded-bl-xs'
                    : 'bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-[#1E2D2B] dark:text-[#E8F0ED] rounded-br-xs'
                }`}
              >
                {/* Voice message bubble indicator */}
                {hasAudio && (
                  <div className="flex items-center gap-2 mb-2 p-2 rounded-xl bg-black/5 dark:bg-white/5">
                    <button className="w-7 h-7 rounded-full bg-[#2F6F68] text-white flex items-center justify-center">
                      <Play className="w-3.5 h-3.5 fill-current" />
                    </button>
                    <div className="h-1 flex-1 bg-[#2F6F68]/30 rounded-full mx-2" />
                    <span className="text-[10px] font-mono text-[#576B66] dark:text-[#99ADA8]">
                      {msg.audioDuration || '0:14'}
                    </span>
                  </div>
                )}

                <p className="whitespace-pre-line">{msg.text}</p>

                {/* Structured Multi-Task Plan or Single Task Card */}
                {msg.proposals && msg.proposals.length > 0 ? (
                  <div className="mt-3.5 space-y-2.5">
                    {/* Header banner */}
                    <div className="flex items-center justify-between flex-wrap gap-2 p-2.5 rounded-2xl bg-[#EAF5F1] dark:bg-[#1A332C] border border-[#D5E8DF] dark:border-[#28493F]">
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs font-bold text-[#205A53] dark:text-[#8AE2D2]">
                          خطة مقسمة ({msg.proposals.length} مهام)
                        </span>
                      </div>

                      {!msg.isConfirmed && (
                        <button
                          onClick={() => confirmProposal(msg.id)}
                          className="px-3 py-1 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white text-[11px] font-bold flex items-center gap-1 shadow-2xs cursor-pointer active:scale-95 transition-all"
                        >
                          <Check className="w-3 h-3 stroke-[3]" />
                          <span>تثبيت كل المهام ({msg.proposals.length})</span>
                        </button>
                      )}
                    </div>

                    {/* Cards list */}
                    <div className="space-y-2">
                      {msg.proposals.map((prop, idx) => {
                        const propBadge = getPriorityBadge(prop.priority);
                        return (
                          <div
                            key={prop.id || idx}
                            className="p-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#152320] border border-[#DFEDE7] dark:border-[#233B35] space-y-2.5"
                          >
                            <div className="flex items-center justify-between flex-wrap gap-1">
                              <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-[#2F6F68]/10 dark:bg-[#2F6F68]/30 text-[#2F6F68] dark:text-[#78C2B5]">
                                المهمة {idx + 1}
                              </span>

                              <div className="flex items-center gap-2 text-[10px]">
                                <span className={`px-1.5 py-0.5 rounded font-bold ${propBadge.bg}`}>
                                  {propBadge.label}
                                </span>
                                {prop.duration && (
                                  <span className="flex items-center gap-1 text-[#697E7A] dark:text-[#9CB0AC] font-medium">
                                    <Clock className="w-3 h-3 text-[#2F6F68] dark:text-[#88C6B9]" />
                                    {prop.duration}
                                  </span>
                                )}
                              </div>
                            </div>

                            <h4 className="text-sm font-bold text-[#1E2D2B] dark:text-white leading-snug">
                              {prop.title}
                            </h4>

                            {(prop.timeSlot || prop.dueAt) && (
                              <div className="flex items-center gap-1.5 text-xs font-semibold text-[#8A5A1B] dark:text-[#E8BD7C] bg-[#FDF5E6] dark:bg-[#322818] px-2.5 py-1.5 rounded-xl border border-[#F4E3C1] dark:border-[#4B3B22]">
                                <Calendar className="w-3.5 h-3.5 shrink-0" />
                                <span>الميعاد: {prop.timeSlot || 'محدد بدقة'}</span>
                              </div>
                            )}

                            <div className="pt-1 flex items-center justify-between">
                              {prop.isConfirmed ? (
                                <div className="flex items-center justify-between w-full">
                                  <span className="text-xs font-bold text-emerald-700 dark:text-emerald-400 flex items-center gap-1">
                                    <CheckCircle2 className="w-3.5 h-3.5" />
                                    متثبتة في جدولك
                                  </span>
                                  <div className="flex items-center gap-1.5">
                                    <button
                                      onClick={() => {
                                        setActiveFocusTask(prop.title);
                                        navigate('/focus-session');
                                      }}
                                      className="px-2 py-0.5 rounded-lg bg-[#EAF5F2] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9] text-[10px] font-bold flex items-center gap-1 cursor-pointer"
                                    >
                                      <Play className="w-2.5 h-2.5 fill-current" />
                                      <span>تركيز</span>
                                    </button>
                                    <button
                                      onClick={() => navigate('/tasks')}
                                      className="px-2 py-0.5 rounded-lg bg-[#2F6F68] text-white text-[10px] font-bold flex items-center gap-1 cursor-pointer"
                                    >
                                      <span>المهام</span>
                                      <ArrowUpRight className="w-2.5 h-2.5" />
                                    </button>
                                  </div>
                                </div>
                              ) : (
                                <button
                                  onClick={() => confirmProposal(msg.id, prop.id)}
                                  className="px-3 py-1.5 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold flex items-center gap-1 cursor-pointer active:scale-95 transition-all shadow-2xs"
                                >
                                  <Check className="w-3 h-3 stroke-[3]" />
                                  <span>تثبيت هذه المهمة</span>
                                </button>
                              )}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ) : hasProposal ? (
                  <div className="mt-3.5 p-3.5 rounded-2xl bg-[#F6FAF8] dark:bg-[#152320] border border-[#DFEDE7] dark:border-[#233B35] space-y-3">
                    <div className="flex items-center justify-between flex-wrap gap-1.5">
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md ${
                        msg.isDirectCreatedTask
                          ? 'bg-emerald-100 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300'
                          : 'bg-[#2F6F68]/10 dark:bg-[#2F6F68]/30 text-[#2F6F68] dark:text-[#78C2B5]'
                      }`}>
                        {msg.isDirectCreatedTask ? 'تمت جدولتها في مهامك تلقائياً' : 'مقترح مهمة'}
                      </span>

                      <div className="flex items-center gap-2 text-[10px] text-[#697E7A] dark:text-[#9CB0AC]">
                        {msg.proposalPriority && (
                          <span className={`px-1.5 py-0.5 rounded font-bold ${priorityBadge.bg}`}>
                            {priorityBadge.label}
                          </span>
                        )}
                        {msg.proposalDuration && (
                          <span className="flex items-center gap-1 font-medium">
                            <Clock className="w-3 h-3 text-[#2F6F68] dark:text-[#88C6B9]" />
                            {msg.proposalDuration}
                          </span>
                        )}
                      </div>
                    </div>

                    <h4 className="text-sm font-bold text-[#1E2D2B] dark:text-white leading-snug">
                      {proposalTitle}
                    </h4>

                    {/* Deadline chip if available */}
                    {(msg.proposalTimeSlot || msg.proposalDueAt) && (
                      <div className="flex items-center gap-1.5 text-xs font-semibold text-[#8A5A1B] dark:text-[#E8BD7C] bg-[#FDF5E6] dark:bg-[#322818] px-2.5 py-1.5 rounded-xl border border-[#F4E3C1] dark:border-[#4B3B22]">
                        <Calendar className="w-3.5 h-3.5 shrink-0" />
                        <span>الميعاد: {msg.proposalTimeSlot || 'محدد بدقة'}</span>
                      </div>
                    )}

                    {/* Action buttons */}
                    <div className="pt-1 flex items-center justify-between flex-wrap gap-2">
                      {isConfirmed ? (
                        <div className="flex items-center justify-between w-full">
                          <span className="text-xs font-bold text-emerald-700 dark:text-emerald-400 flex items-center gap-1">
                            <CheckCircle2 className="w-4 h-4" />
                            تم التثبيت في جدولك بنجاح
                          </span>

                          <div className="flex items-center gap-1.5">
                            <button
                              onClick={() => {
                                if (proposalTitle) setActiveFocusTask(proposalTitle);
                                navigate('/focus-session');
                              }}
                              className="px-2.5 py-1 rounded-lg bg-[#EAF5F2] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9] hover:bg-[#D9ECE8] text-[11px] font-bold flex items-center gap-1 cursor-pointer transition-colors"
                              title="بدء جلسة تركيز"
                            >
                              <Play className="w-3 h-3 fill-current" />
                              <span>تركيز</span>
                            </button>

                            <button
                              onClick={() => navigate('/tasks')}
                              className="px-2.5 py-1 rounded-lg bg-[#2F6F68] hover:bg-[#245650] text-white text-[11px] font-bold flex items-center gap-1 cursor-pointer transition-colors"
                            >
                              <span>المهام</span>
                              <ArrowUpRight className="w-3 h-3" />
                            </button>
                          </div>
                        </div>
                      ) : (
                        <button
                          onClick={() => confirmProposal(msg.id)}
                          className="w-full sm:w-auto px-4 py-2 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white text-xs font-bold flex items-center justify-center gap-1.5 shadow-2xs transition-all cursor-pointer active:scale-95"
                        >
                          <Check className="w-3.5 h-3.5 stroke-[3]" />
                          تثبيت في مهامي
                        </button>
                      )}
                    </div>
                  </div>
                ) : null}
              </div>

              {/* Timestamp */}
              <span className="text-[10px] text-[#7A8E89] dark:text-[#8D9F9B] px-2">
                {msg.time || msg.timestamp || 'الآن'}
              </span>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>

      {/* Input bar */}
      <div className="p-4 bg-white/90 dark:bg-[#1A2825]/90 border-t border-[#DFE7E2] dark:border-[#273B36] backdrop-blur-md shrink-0">
        <form onSubmit={handleSend} className="flex items-center gap-2">
          <button
            type="button"
            onClick={handleSimulateVoice}
            disabled={isRecording}
            className={`p-3 rounded-2xl transition-all cursor-pointer ${
              isRecording
                ? 'bg-[#C64545] text-white animate-pulse'
                : 'bg-[#EEF5F2] dark:bg-[#203732] text-[#2F6F68] dark:text-[#88C6B9] hover:bg-[#E0EFEA]'
            }`}
            title="تسجيل صوتي"
          >
            <Mic className="w-5 h-5" />
          </button>

          <input
            type="text"
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            placeholder={isRecording ? 'جاري التسجيل...' : 'اكتب فكرة، أو احكيلي اللي شاغلك وهنهندلها سوا...'}
            disabled={isRecording}
            className="flex-1 px-4 py-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#152320] border border-[#DEE7E2] dark:border-[#283C37] text-sm text-[#1E2D2B] dark:text-white placeholder-[#869A95] dark:placeholder-[#6C817D] focus:outline-hidden focus:border-[#2F6F68]"
          />

          <button
            type="submit"
            disabled={!inputText.trim() || isRecording}
            className="p-3 rounded-2xl bg-[#2F6F68] hover:bg-[#245650] text-white disabled:opacity-40 transition-all cursor-pointer shadow-xs active:scale-95"
            title="إرسال"
          >
            <Send className="w-5 h-5 -rotate-90" />
          </button>
        </form>
      </div>
    </div>
  );
};
