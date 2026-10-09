import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  ArrowRight,
  Bell,
  Moon,
  Heart,
  Sparkles,
  AlertCircle,
  CheckCheck,
  Check,
} from 'lucide-react';
import { NotificationCategory, NotificationItem } from '../types';

export const NotificationsScreen: React.FC = () => {
  const {
    notifications,
    quietHoursEnabled,
    setQuietHoursEnabled,
    markNotificationRead,
    markAllNotificationsRead,
    navigate,
  } = useApp();

  const [activeCategory, setActiveCategory] = useState<'all' | NotificationCategory>('all');

  const unreadCount = notifications.filter(n => !n.isRead).length;

  const filtered = notifications.filter(n => {
    if (activeCategory === 'all') return true;
    return n.category === activeCategory;
  });

  const getCategoryMeta = (cat: NotificationCategory) => {
    switch (cat) {
      case 'reminder':
        return {
          icon: Bell,
          label: 'تذكير هادئ',
          bg: 'bg-[#EEF5F2] dark:bg-[#1E3731] text-[#2F6F68] dark:text-[#88C6B9]',
        };
      case 'encouragement':
        return {
          icon: Sparkles,
          label: 'تشجيع',
          bg: 'bg-[#FDF2E8] dark:bg-[#3A2D1F] text-[#B77322] dark:text-[#E9BE88]',
        };
      case 'focus':
        return {
          icon: Moon,
          label: 'جلسة تركيز',
          bg: 'bg-[#EAF1F8] dark:bg-[#1E2E3A] text-[#3E7092] dark:text-[#8CBEDC]',
        };
      case 'summary':
      default:
        return {
          icon: CheckCheck,
          label: 'ملخص اليوم',
          bg: 'bg-[#F0EEF8] dark:bg-[#2B233D] text-[#6E5FB3] dark:text-[#B6A9EA]',
        };
    }
  };

  return (
    <div className="pb-28 pt-4 px-4 sm:px-6 space-y-5">
      {/* Header */}
      <header className="flex items-center justify-between pt-2">
        <div className="flex items-center gap-2">
          <button
            onClick={() => navigate('/home')}
            className="p-2 rounded-xl text-[#576F6A] dark:text-[#9FB3AE] hover:text-[#1E2D2B] dark:hover:text-white hover:bg-[#EEF5F2] dark:hover:bg-[#1E332E] transition-colors cursor-pointer"
          >
            <ArrowRight className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-xl font-bold text-[#1E2D2B] dark:text-white flex items-center gap-2">
              تنبيهاتك
              {unreadCount > 0 && (
                <span className="text-xs px-2 py-0.5 rounded-full bg-[#D25C54] text-white font-bold">
                  {unreadCount}
                </span>
              )}
            </h1>
          </div>
        </div>

        {unreadCount > 0 && (
          <button
            onClick={markAllNotificationsRead}
            className="text-xs font-bold text-[#2F6F68] dark:text-[#76BCAF] hover:underline flex items-center gap-1 cursor-pointer"
          >
            <CheckCheck className="w-4 h-4" />
            تعليم الكل كمقروء
          </button>
        )}
      </header>

      {/* Quiet Hours Mode Card */}
      <div className="p-4 rounded-3xl bg-[#EEF5F2] dark:bg-[#182A26] border border-[#D5E3DD] dark:border-[#263D37] flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-[#2F6F68] text-white flex items-center justify-center shrink-0">
            <Moon className="w-5 h-5" />
          </div>
          <div className="space-y-0.5">
            <h3 className="text-xs font-bold text-[#1E2D2B] dark:text-white">
              وضع ساعات الهدوء
            </h3>
            <p className="text-[11px] text-[#5A716C] dark:text-[#9FB3AE]">
              تنبيهات لطيفة بدون رنات مفاجئة أثناء ساعات التركيز
            </p>
          </div>
        </div>

        <button
          onClick={() => setQuietHoursEnabled(!quietHoursEnabled)}
          className={`w-12 h-6.5 rounded-full transition-colors relative cursor-pointer ${
            quietHoursEnabled ? 'bg-[#2F6F68]' : 'bg-[#C2D1CC] dark:bg-[#3D524C]'
          }`}
        >
          <div
            className={`w-5 h-5 rounded-full bg-white transition-transform absolute top-0.75 ${
              quietHoursEnabled ? 'right-6.5' : 'right-0.75'
            }`}
          />
        </button>
      </div>

      {/* Filter Tabs */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
        {[
          { key: 'all', label: 'الكل' },
          { key: 'reminder', label: 'تذكير' },
          { key: 'encouragement', label: 'تشجيع' },
          { key: 'focus', label: 'جلسات تركيز' },
        ].map((tab) => {
          const isActive = activeCategory === tab.key;
          return (
            <button
              key={tab.key}
              onClick={() => setActiveCategory(tab.key as any)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all cursor-pointer ${
                isActive
                  ? 'bg-[#2F6F68] text-white shadow-xs'
                  : 'bg-white dark:bg-[#1A2825] text-[#5B6F6B] dark:text-[#99AFA9] border border-[#DEE7E2] dark:border-[#283C37] hover:bg-[#F2F7F5]'
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Notifications List */}
      <div className="space-y-2.5">
        {filtered.length === 0 ? (
          <div className="p-8 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#E1ECE7] dark:border-[#263A35] text-center space-y-2">
            <Bell className="w-8 h-8 text-[#A0B4AE] mx-auto stroke-[1.5]" />
            <p className="text-xs text-[#6A7E7A] dark:text-[#9FB3AE]">
              لا توجد تنبيهات جديدة في هذا القسم
            </p>
          </div>
        ) : (
          filtered.map((item) => {
            const meta = getCategoryMeta(item.category);
            const Icon = meta.icon;

            return (
              <div
                key={item.id}
                onClick={() => markNotificationRead(item.id)}
                className={`p-4 rounded-3xl border transition-all cursor-pointer ${
                  item.isRead
                    ? 'bg-white dark:bg-[#1A2825] border-[#E1ECE7] dark:border-[#263C37] opacity-80'
                    : 'bg-[#F9FCFA] dark:bg-[#1E302C] border-[#2F6F68]/30 dark:border-[#76BCAF]/40 shadow-2xs'
                }`}
              >
                <div className="flex items-start gap-3">
                  <div className={`w-9 h-9 rounded-2xl flex items-center justify-center shrink-0 ${meta.bg}`}>
                    <Icon className="w-4 h-4" />
                  </div>

                  <div className="flex-1 space-y-1">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold text-[#6B807B] dark:text-[#98ADA7]">
                        {meta.label}
                      </span>
                      <span className="text-[10px] text-[#788E89] dark:text-[#8D9F9B]">
                        {item.time}
                      </span>
                    </div>

                    <h4 className="text-sm font-bold text-[#1E2D2B] dark:text-white">
                      {item.title}
                    </h4>

                    <p className="text-xs text-[#5D726D] dark:text-[#A1B5B0] leading-relaxed">
                      {item.body}
                    </p>
                  </div>

                  {!item.isRead && (
                    <div className="w-2 h-2 rounded-full bg-[#2F6F68] dark:bg-[#78C3B5] shrink-0 mt-2" />
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
