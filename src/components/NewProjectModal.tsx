import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { X, FolderPlus } from 'lucide-react';

export const NewProjectModal: React.FC = () => {
  const { isNewProjectOpen, setIsNewProjectOpen, createProject, isDarkMode } = useApp();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [accentColor, setAccentColor] = useState('#2F6F68');

  if (!isNewProjectOpen) return null;

  const colorOptions = [
    { color: '#2F6F68', name: 'Sage (هادئ)' },
    { color: '#5683A5', name: 'Sky (سماوي)' },
    { color: '#B7863C', name: 'Sand (رملي)' },
    { color: '#7773A1', name: 'Lavender (بنفسجي)' },
    { color: '#C9826C', name: 'Terracotta (دافئ)' },
  ];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    createProject({
      title: title.trim(),
      description: description.trim() || undefined,
      accentColor,
    });

    setTitle('');
    setDescription('');
    setIsNewProjectOpen(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-xs p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-lg rounded-t-3xl sm:rounded-3xl p-6 shadow-2xl transition-all bg-white dark:bg-[#182724] border border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-[#EFF6F2]">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-[#D9ECE8] dark:bg-[#244F48] text-[#245650] dark:text-[#9DD2C5]">
              <FolderPlus className="w-5 h-5" />
            </div>
            <h3 className="text-xl font-bold">مشروع جديد</h3>
          </div>
          <button
            onClick={() => setIsNewProjectOpen(false)}
            className="p-1 rounded-full hover:bg-black/5 dark:hover:bg-white/10 text-[#99A6A2]"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-bold mb-1.5 text-[#647370] dark:text-[#B7C9C2]">
              اسم المشروع
            </label>
            <input
              type="text"
              autoFocus
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="مثال: إطلاق التطبيق، تنظيم المكتب..."
              className="w-full px-4 py-3 rounded-2xl text-sm border focus:outline-hidden bg-[#F7F8F6] dark:bg-[#203530] border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-white placeholder-[#99A6A2] dark:placeholder-[#81948E] focus:border-[#2F6F68] dark:focus:border-[#76BCAF]"
            />
          </div>

          <div>
            <label className="block text-xs font-bold mb-1.5 text-[#647370] dark:text-[#B7C9C2]">
              الهدف الأساسي من المشروع
            </label>
            <textarea
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="وصف بسيط يوضح ماذا تريد إنجازه..."
              className="w-full px-4 py-3 rounded-2xl text-sm border focus:outline-hidden resize-none bg-[#F7F8F6] dark:bg-[#203530] border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-white placeholder-[#99A6A2] dark:placeholder-[#81948E] focus:border-[#2F6F68] dark:focus:border-[#76BCAF]"
            />
          </div>

          <div>
            <label className="block text-xs font-bold mb-1.5 text-[#647370] dark:text-[#B7C9C2]">
              لون الهوية الهادئ
            </label>
            <div className="flex gap-2.5">
              {colorOptions.map((c) => (
                <button
                  type="button"
                  key={c.color}
                  onClick={() => setAccentColor(c.color)}
                  className={`w-8 h-8 rounded-full cursor-pointer transition-transform ${
                    accentColor === c.color ? 'scale-115 ring-2 ring-offset-2 ring-[#2F6F68]' : 'opacity-80 hover:opacity-100'
                  }`}
                  style={{ backgroundColor: c.color }}
                  title={c.name}
                />
              ))}
            </div>
          </div>

          <div className="pt-2 flex gap-3">
            <button
              type="submit"
              disabled={!title.trim()}
              className="flex-1 py-3 rounded-2xl font-bold text-sm bg-[#245650] text-white dark:bg-[#9DD2C5] dark:text-[#101A18] hover:opacity-90 disabled:opacity-50 transition-opacity cursor-pointer"
            >
              إضافة المشروع
            </button>
            <button
              type="button"
              onClick={() => setIsNewProjectOpen(false)}
              className="px-5 py-3 rounded-2xl font-bold text-sm border border-[#DDE7E2] dark:border-[#354D46] text-[#647370] dark:text-[#B7C9C2] hover:bg-black/5 cursor-pointer"
            >
              إلغاء
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
