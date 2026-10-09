import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  Plus,
  Search,
  FolderOpen,
  Play,
  CheckCircle2,
  Sparkles,
  Layers,
  ChevronLeft,
  X,
  Clock,
  ArrowUpRight,
} from 'lucide-react';
import { Project, ProjectStatus } from '../types';

export const ProjectsScreen: React.FC = () => {
  const {
    projects,
    setIsNewProjectOpen,
    setIsAiBreakdownOpen,
    setActiveProjectWorkspace,
    setActiveFocusTask,
    navigate,
  } = useApp();

  const [activeFilter, setActiveFilter] = useState<'all' | 'active' | 'completed' | 'paused'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const filterTabs = [
    { key: 'all', label: 'الكل' },
    { key: 'active', label: 'النشطة' },
    { key: 'completed', label: 'المكتملة' },
    { key: 'paused', label: 'المؤجلة' },
  ] as const;

  const filteredProjects = projects.filter((p) => {
    if (searchQuery.trim()) {
      const matchTitle = p.title.toLowerCase().includes(searchQuery.toLowerCase());
      const matchDesc = p.description?.toLowerCase().includes(searchQuery.toLowerCase());
      if (!matchTitle && !matchDesc) return false;
    }

    if (activeFilter !== 'all' && p.status !== activeFilter) {
      return false;
    }
    return true;
  });

  const openProjectWorkspace = (proj: Project) => {
    setActiveProjectWorkspace(proj);
    navigate('/project-workspace');
  };

  const getStatusBadge = (status: ProjectStatus) => {
    switch (status) {
      case 'active':
        return { label: 'نشط', bg: 'bg-[#EEF5F2] text-[#2F6F68] dark:bg-[#1E3731] dark:text-[#88C6B9]' };
      case 'completed':
        return { label: 'مكتمل', bg: 'bg-[#EAF3FA] text-[#36688B] dark:bg-[#1C2C39] dark:text-[#81B4D8]' };
      case 'paused':
      default:
        return { label: 'مؤجل', bg: 'bg-[#FBF1E6] text-[#A66E28] dark:bg-[#3B2C1C] dark:text-[#E2B77B]' };
    }
  };

  return (
    <div className="pb-28 pt-4 px-4 sm:px-6 space-y-5">
      {/* Header */}
      <header className="flex items-center justify-between pt-2">
        <div>
          <h1 className="text-2xl font-bold text-[#1E2D2B] dark:text-white">مشاريعك</h1>
          <p className="text-xs text-[#627773] dark:text-[#97AEA8]">
            حوّل الأهداف الكبيرة إلى مراحل واضحة وهادية
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsAiBreakdownOpen(true)}
            className="p-2.5 rounded-2xl bg-[#EAF5F2] dark:bg-[#203D37] text-[#2F6F68] dark:text-[#8AD3C4] border border-[#CCE2DC] dark:border-[#2C524A] hover:bg-[#D9ECE8] transition-colors cursor-pointer flex items-center gap-1.5 text-xs font-bold"
            title="تقسيم مشروع ذكي"
          >
            <Sparkles className="w-4 h-4" />
            <span>تقسيم ذكي</span>
          </button>

          <button
            onClick={() => setIsNewProjectOpen(true)}
            className="p-2.5 rounded-2xl bg-[#2F6F68] text-white hover:bg-[#245650] shadow-sm transition-all cursor-pointer flex items-center gap-1.5 text-xs font-bold active:scale-95"
          >
            <Plus className="w-4 h-4" />
            <span>مشروع جديد</span>
          </button>
        </div>
      </header>

      {/* Search Input */}
      <div className="relative">
        <div className="absolute inset-y-0 right-0 pr-3.5 flex items-center pointer-events-none text-[#758B86] dark:text-[#8FA5A0]">
          <Search className="w-4 h-4" />
        </div>
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="ابحث في مشاريعك..."
          className="w-full pr-10 pl-9 py-2.5 rounded-2xl bg-white dark:bg-[#1A2825] border border-[#DEE7E2] dark:border-[#283C37] text-sm text-[#1E2D2B] dark:text-white placeholder-[#8B9F9A] dark:placeholder-[#6C817D] focus:outline-hidden focus:border-[#2F6F68] dark:focus:border-[#76BCAF] transition-all"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery('')}
            className="absolute inset-y-0 left-0 pl-3 flex items-center text-[#758B86] hover:text-[#1E2D2B] dark:hover:text-white cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Filter Tabs */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
        {filterTabs.map((tab) => {
          const isActive = activeFilter === tab.key;
          return (
            <button
              key={tab.key}
              onClick={() => setActiveFilter(tab.key)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all cursor-pointer ${
                isActive
                  ? 'bg-[#2F6F68] text-white shadow-xs'
                  : 'bg-white dark:bg-[#1A2825] text-[#5B6F6B] dark:text-[#99AFA9] border border-[#DEE7E2] dark:border-[#283C37] hover:bg-[#F2F7F5] dark:hover:bg-[#223631]'
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Projects List */}
      <div className="space-y-4">
        {filteredProjects.length === 0 ? (
          <div className="p-10 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#E1ECE7] dark:border-[#263A35] text-center space-y-3">
            <div className="w-14 h-14 mx-auto rounded-2xl bg-[#EEF5F2] dark:bg-[#203631] text-[#2F6F68] dark:text-[#86C9BD] flex items-center justify-center">
              <FolderOpen className="w-7 h-7 stroke-[1.5]" />
            </div>
            <div className="space-y-1">
              <h3 className="text-base font-bold text-[#1E2D2B] dark:text-white">
                مفيش مشاريع مطابقة للبحث
              </h3>
              <p className="text-xs text-[#6A7E7A] dark:text-[#9CB0AC] max-w-xs mx-auto">
                ابدأ مشروعاً جديداً أو استخدم الذكاء الاصطناعي لتقسيم هدفك إلى خطوات هادئة ومدروسة.
              </p>
            </div>
            <button
              onClick={() => setIsNewProjectOpen(true)}
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-[#2F6F68] text-white text-xs font-bold hover:bg-[#245650] transition-colors cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              أضف مشروعاً
            </button>
          </div>
        ) : (
          filteredProjects.map((project) => {
            const pct = Math.round(project.progressPercent * 100);
            const badge = getStatusBadge(project.status);

            return (
              <div
                key={project.id}
                onClick={() => openProjectWorkspace(project)}
                className="p-5 rounded-3xl bg-white dark:bg-[#1A2825] border border-[#DFE9E4] dark:border-[#283C37] hover:border-[#2F6F68]/40 shadow-xs hover:shadow-md transition-all cursor-pointer group space-y-4"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <div
                      className="w-11 h-11 rounded-2xl flex items-center justify-center text-white shrink-0 shadow-xs"
                      style={{ backgroundColor: project.accentColor || '#2F6F68' }}
                    >
                      <FolderOpen className="w-5 h-5" />
                    </div>

                    <div className="min-w-0 flex-1 space-y-1">
                      <div className="flex items-center gap-2">
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md ${badge.bg}`}>
                          {badge.label}
                        </span>
                        {project.targetDate && (
                          <span className="text-[11px] text-[#718681] dark:text-[#97ACA7] flex items-center gap-1">
                            <Clock className="w-3 h-3" />
                            حتى {project.targetDate}
                          </span>
                        )}
                      </div>

                      <h3 className="text-base font-bold text-[#1E2D2B] dark:text-white group-hover:text-[#2F6F68] dark:group-hover:text-[#76BCAF] transition-colors">
                        {project.title}
                      </h3>

                      {project.description && (
                        <p className="text-xs text-[#6A7E7A] dark:text-[#98ADA7] leading-relaxed line-clamp-2">
                          {project.description}
                        </p>
                      )}
                    </div>
                  </div>

                  <div className="text-left shrink-0">
                    <span className="text-base font-black text-[#2F6F68] dark:text-[#79C1B4]">
                      %{pct}
                    </span>
                  </div>
                </div>

                {/* Progress bar */}
                <div className="w-full h-2 bg-[#EDF3F0] dark:bg-[#253935] rounded-full overflow-hidden p-0.5">
                  <div
                    className="h-full rounded-full transition-all duration-300"
                    style={{
                      width: `${pct}%`,
                      backgroundColor: project.accentColor || '#2F6F68',
                    }}
                  />
                </div>

                {/* Next Step Highlight Card */}
                {project.nextStepTitle && (
                  <div className="p-3 rounded-2xl bg-[#F6FAF8] dark:bg-[#1E302C] border border-[#DEECE5] dark:border-[#2B453E] flex items-center justify-between gap-3 text-xs">
                    <div className="flex items-center gap-2 min-w-0">
                      <span className="w-2 h-2 rounded-full bg-[#2F6F68] dark:bg-[#78BFB2] shrink-0" />
                      <span className="text-[#647974] dark:text-[#99ADA8] shrink-0 font-medium">الخطوة القادمة:</span>
                      <span className="font-bold text-[#1E2D2B] dark:text-white truncate">
                        {project.nextStepTitle}
                      </span>
                    </div>

                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setActiveFocusTask(project.nextStepTitle!);
                        navigate('/focus-session');
                      }}
                      className="shrink-0 px-2.5 py-1 rounded-xl bg-[#2F6F68] hover:bg-[#245650] text-white text-[11px] font-bold flex items-center gap-1 cursor-pointer transition-colors"
                      title="جلسة تركيز لهذه الخطوة"
                    >
                      <Play className="w-3 h-3 fill-current" />
                      تركيز
                    </button>
                  </div>
                )}

                {/* Footer details */}
                <div className="flex items-center justify-between pt-1 text-[11px] text-[#768C87] dark:text-[#99ACA8] border-t border-[#EEF4F1] dark:border-[#223531]">
                  <span>
                    {project.subtasks?.length || 0} مهام فرعية
                  </span>
                  <span className="flex items-center gap-1 text-[#2F6F68] dark:text-[#78C0B3] font-bold group-hover:underline">
                    فتح مساحة المشروع
                    <ArrowUpRight className="w-3.5 h-3.5" />
                  </span>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
