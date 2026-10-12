import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { X, FolderPlus, Plus, Trash2, CheckCircle2, ListPlus, ArrowLeft } from 'lucide-react';

export const NewProjectModal: React.FC = () => {
  const { isNewProjectOpen, setIsNewProjectOpen, setIsQuickAddOpen, createProject, createTask } = useApp();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [accentColor, setAccentColor] = useState('#2F6F68');
  
  // Interactive tasks to add directly inside this section
  const [taskInput, setTaskInput] = useState('');
  const [tasksList, setTasksList] = useState<string[]>([]);

  if (!isNewProjectOpen) return null;

  const colorOptions = [
    { color: '#2F6F68', name: 'Sage (هادئ)' },
    { color: '#5683A5', name: 'Sky (سماوي)' },
    { color: '#B7863C', name: 'Sand (رملي)' },
    { color: '#7773A1', name: 'Lavender (بنفسجي)' },
    { color: '#C9826C', name: 'Terracotta (دافئ)' },
  ];

  const handleAddTaskToList = () => {
    if (!taskInput.trim()) return;
    setTasksList([...tasksList, taskInput.trim()]);
    setTaskInput('');
  };

  const handleRemoveTaskFromList = (index: number) => {
    setTasksList(tasksList.filter((_, i) => i !== index));
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleAddTaskToList();
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    // 1. Create the Section / Project
    const newProj = createProject({
      title: title.trim(),
      description: description.trim() || undefined,
      accentColor,
      subtasks: tasksList,
    });

    // 2. Create all the tasks that were added inside this section
    tasksList.forEach((tTitle) => {
      if (tTitle.trim()) {
        createTask({
          title: tTitle.trim(),
          projectId: newProj.id,
          priority: 'medium',
          estimatedDurationMinutes: 25,
        });
      }
    });

    // Reset and close
    setTitle('');
    setDescription('');
    setTasksList([]);
    setTaskInput('');
    setIsNewProjectOpen(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-xs p-0 sm:p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-t-3xl sm:rounded-3xl p-6 shadow-2xl transition-all bg-white dark:bg-[#182724] border border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-[#EFF6F2]">
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2.5">
            <div className="p-2.5 rounded-2xl bg-[#D9ECE8] dark:bg-[#244F48] text-[#245650] dark:text-[#9DD2C5]">
              <FolderPlus className="w-5 h-5 stroke-[2.2]" />
            </div>
            <div>
              <h3 className="text-lg font-bold">إضافة سكشن جديد</h3>
              <p className="text-xs text-[#647370] dark:text-[#9FB3AE]">
                أنشئ السكشن وحدد المهام التابعة له مباشرة
              </p>
            </div>
          </div>
          <button
            onClick={() => setIsNewProjectOpen(false)}
            className="p-1.5 rounded-xl hover:bg-black/5 dark:hover:bg-white/10 text-[#99A6A2] cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Switcher Option to single task */}
        <div className="mb-4 p-3 rounded-2xl bg-[#EEF5F2] dark:bg-[#1D322D] border border-[#D5E5DE] dark:border-[#2C4841] flex items-center justify-between text-xs">
          <span className="text-[#4E6460] dark:text-[#A1B8B2] font-medium">
            عاوز تضيف مهمة واحدة وتحدد سكشن موجود؟
          </span>
          <button
            type="button"
            onClick={() => {
              setIsNewProjectOpen(false);
              setIsQuickAddOpen(true);
            }}
            className="font-bold text-[#235D55] dark:text-[#76C6B7] hover:underline flex items-center gap-1 cursor-pointer shrink-0"
          >
            <span>إضافة مهمة وسكشن</span>
            <ArrowLeft className="w-3.5 h-3.5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Section Title */}
          <div>
            <label className="block text-xs font-bold mb-1.5 text-[#3E504C] dark:text-[#B7C9C2]">
              اسم السكشن / المشروع *
            </label>
            <input
              type="text"
              autoFocus
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="مثال: المذاكرة والامتحانات، مشروع التخرج، شغل العميل..."
              className="w-full px-4 py-2.5 rounded-2xl text-sm border focus:outline-hidden bg-[#F7F8F6] dark:bg-[#203530] border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-white placeholder-[#99A6A2] dark:placeholder-[#81948E] focus:border-[#2F6F68] dark:focus:border-[#76BCAF] transition-colors"
            />
          </div>

          {/* Section Description */}
          <div>
            <label className="block text-xs font-bold mb-1.5 text-[#3E504C] dark:text-[#B7C9C2]">
              وصف أو هدف السكشن (اختياري)
            </label>
            <textarea
              rows={2}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="هدف بسيط أو ملاحظات للسكشن..."
              className="w-full px-4 py-2 rounded-2xl text-sm border focus:outline-hidden resize-none bg-[#F7F8F6] dark:bg-[#203530] border-[#DDE7E2] dark:border-[#354D46] text-[#1E2D2B] dark:text-white placeholder-[#99A6A2] dark:placeholder-[#81948E] focus:border-[#2F6F68] dark:focus:border-[#76BCAF] transition-colors"
            />
          </div>

          {/* Tasks Inside This Section */}
          <div className="p-4 rounded-2xl bg-[#F7FBF9] dark:bg-[#14211E] border border-[#DEEAE5] dark:border-[#253B36] space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-xs font-bold text-[#235D55] dark:text-[#88C6B9] flex items-center gap-1.5">
                <ListPlus className="w-4 h-4" />
                <span>إضافة مهام داخل هذا السكشن</span>
              </label>
              {tasksList.length > 0 && (
                <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-[#235D55]/10 text-[#235D55] dark:bg-[#76C6B7]/20 dark:text-[#76C6B7]">
                  {tasksList.length} مهام مضافة
                </span>
              )}
            </div>

            {/* Input row */}
            <div className="flex gap-2">
              <input
                type="text"
                value={taskInput}
                onChange={(e) => setTaskInput(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="اكتب اسم المهمة واضغط إضافة أو Enter..."
                className="flex-1 px-3.5 py-2 rounded-xl text-xs border focus:outline-hidden bg-white dark:bg-[#1D2F2A] border-[#D7E4DF] dark:border-[#2E4841] text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] focus:border-[#235D55] dark:focus:border-[#76C6B7]"
              />
              <button
                type="button"
                onClick={handleAddTaskToList}
                disabled={!taskInput.trim()}
                className="px-3.5 py-2 rounded-xl bg-[#235D55] hover:bg-[#1C4B45] text-white text-xs font-bold flex items-center gap-1 cursor-pointer disabled:opacity-40 transition-all active:scale-95"
              >
                <Plus className="w-4 h-4" />
                <span>إضافة</span>
              </button>
            </div>

            {/* List of Tasks Added */}
            {tasksList.length > 0 ? (
              <div className="space-y-1.5 max-h-40 overflow-y-auto pr-1">
                {tasksList.map((t, idx) => (
                  <div
                    key={idx}
                    className="flex items-center justify-between p-2 rounded-xl bg-white dark:bg-[#182724] border border-[#E1ECE7] dark:border-[#2A3E39] text-xs"
                  >
                    <div className="flex items-center gap-2 overflow-hidden">
                      <CheckCircle2 className="w-3.5 h-3.5 text-[#235D55] dark:text-[#76C6B7] shrink-0" />
                      <span className="font-medium text-[#1E2D2B] dark:text-white truncate">
                        {t}
                      </span>
                    </div>
                    <button
                      type="button"
                      onClick={() => handleRemoveTaskFromList(idx)}
                      className="p-1 rounded-lg text-[#9AAEA9] hover:text-[#C55A43] hover:bg-black/5 dark:hover:bg-white/5 transition-colors cursor-pointer shrink-0"
                      title="حذف المهمة"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-[11px] text-[#718782] dark:text-[#8FA5A0]">
                تقدر تضيف مهام السكشن الآن، أو تضيفها لاحقاً في أي وقت.
              </p>
            )}
          </div>

          {/* Accent Color */}
          <div>
            <label className="block text-xs font-bold mb-1.5 text-[#3E504C] dark:text-[#B7C9C2]">
              لون الهوية المميز
            </label>
            <div className="flex gap-2.5">
              {colorOptions.map((c) => (
                <button
                  type="button"
                  key={c.color}
                  onClick={() => setAccentColor(c.color)}
                  className={`w-7 h-7 rounded-full cursor-pointer transition-transform ${
                    accentColor === c.color ? 'scale-115 ring-2 ring-offset-2 ring-[#235D55]' : 'opacity-80 hover:opacity-100'
                  }`}
                  style={{ backgroundColor: c.color }}
                  title={c.name}
                />
              ))}
            </div>
          </div>

          {/* Action buttons */}
          <div className="pt-2 flex gap-3">
            <button
              type="submit"
              disabled={!title.trim()}
              className="flex-1 py-3 rounded-2xl font-bold text-xs bg-[#235D55] text-white hover:bg-[#1C4B45] disabled:opacity-50 transition-all cursor-pointer shadow-sm active:scale-98 flex items-center justify-center gap-1.5"
            >
              <span>إنشاء السكشن</span>
              {tasksList.length > 0 && <span>(مع {tasksList.length} مهام)</span>}
            </button>
            <button
              type="button"
              onClick={() => setIsNewProjectOpen(false)}
              className="px-5 py-3 rounded-2xl font-bold text-xs border border-[#DDE7E2] dark:border-[#354D46] text-[#647370] dark:text-[#B7C9C2] hover:bg-black/5 dark:hover:bg-white/5 cursor-pointer"
            >
              إلغاء
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
