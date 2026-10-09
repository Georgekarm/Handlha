import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  Task,
  TaskPriority,
  TaskStatus,
  Project,
  ProjectStatus,
  AppUser,
  NotificationItem,
  ChatMessageItem,
  AssistantTone,
  EnergyLevel,
  TaskSource,
} from '../types';
import {
  generateEgyptianAiResponse,
  generateEgyptianVoiceResponse,
} from '../utils/egyptianAi';
import { formatEgyptianFullDeadline } from '../utils/taskParser';

interface AppContextType {
  user: AppUser | null;
  currentRoute: string;
  navigate: (route: string, extra?: any) => void;
  routeExtra: any;
  themeMode: 'light' | 'dark' | 'system';
  isDarkMode: boolean;
  setThemeMode: (mode: 'light' | 'dark' | 'system') => void;
  
  // Auth
  login: (email: string, name?: string) => void;
  logout: () => void;
  completeOnboarding: (data: Partial<AppUser>) => void;
  updateUserProfile: (data: Partial<AppUser>) => void;

  // Tasks
  tasks: Task[];
  createTask: (params: {
    title: string;
    description?: string;
    priority?: TaskPriority;
    status?: TaskStatus;
    projectId?: string;
    estimatedDurationMinutes?: number;
    scheduledStartAt?: string;
    timeSlot?: string;
    dueAt?: string;
    energyLevel?: EnergyLevel;
    source?: TaskSource;
  }) => Task;
  toggleTaskCompletion: (taskId: string) => void;
  deleteTask: (taskId: string) => void;
  updateTask: (taskId: string, updates: Partial<Task>) => void;

  // Projects
  projects: Project[];
  createProject: (params: { title: string; description?: string; accentColor?: string }) => Project;
  updateProject: (id: string, updates: Partial<Project>) => void;

  // Notifications
  notifications: NotificationItem[];
  quietHoursEnabled: boolean;
  setQuietHoursEnabled: (enabled: boolean) => void;
  markNotificationRead: (id: string) => void;
  markAllNotificationsRead: () => void;

  // Chat
  chatMessages: ChatMessageItem[];
  sendChatMessage: (text: string) => void;
  sendVoiceMessage: (duration: string) => void;
  confirmProposal: (messageId: string, proposalId?: string) => void;

  // Sheets & Modals
  isQuickAddOpen: boolean;
  setIsQuickAddOpen: (open: boolean) => void;
  isSmartAddOpen: boolean;
  setIsSmartAddOpen: (open: boolean) => void;
  isAiBreakdownOpen: boolean;
  setIsAiBreakdownOpen: (open: boolean) => void;
  isNewProjectOpen: boolean;
  setIsNewProjectOpen: (open: boolean) => void;
  activeProjectWorkspace: Project | null;
  setActiveProjectWorkspace: (project: Project | null) => void;
  activeFocusTask: string;
  setActiveFocusTask: (taskTitle: string) => void;
}

const initialTasks: Task[] = [
  {
    id: 't-1',
    userId: 'u-1',
    title: 'مراجعة تدفق المهام وتجربة المستخدم',
    description: 'التأكد من سلاسة الإدخال السريع بدون لود ذهني',
    status: 'planned',
    priority: 'urgent',
    estimatedDurationMinutes: 20,
    timeSlot: '11:00 ص - 12:00 م',
    energyLevel: 'high',
    source: 'manual',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 't-2',
    userId: 'u-1',
    title: 'إعداد جلسة التركيز التفاعلية',
    description: 'ضبط مؤقت الـ 25 دقيقة وحلقات الإنجاز',
    status: 'planned',
    priority: 'high',
    estimatedDurationMinutes: 30,
    timeSlot: '12:30 م - 1:00 م',
    energyLevel: 'medium',
    source: 'manual',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 't-3',
    userId: 'u-1',
    title: 'تحديث نظام الألوان الهادئ لمساحة العمل',
    description: 'اعتماد لوحة Calm Intelligent Productivity',
    status: 'completed',
    priority: 'low',
    estimatedDurationMinutes: 15,
    timeSlot: '9:30 ص - 10:00 ص',
    energyLevel: 'low',
    source: 'manual',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 't-4',
    userId: 'u-1',
    title: 'ضبط تدفق الشات والمقترحات المنظمة',
    description: 'تحويل الأفكار إلى خطوات تنفيذية جاهزة للتثبيت',
    status: 'completed',
    priority: 'medium',
    estimatedDurationMinutes: 45,
    timeSlot: '10:00 ص - 10:45 ص',
    energyLevel: 'medium',
    source: 'chat',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 't-5',
    userId: 'u-1',
    title: 'تجهيز قائمة مشتريات للمكتب',
    description: 'دفاتر ملاحظات وستاند شاشة',
    status: 'inbox',
    priority: 'medium',
    estimatedDurationMinutes: 25,
    energyLevel: 'low',
    source: 'manual',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

const initialProjects: Project[] = [
  {
    id: '1',
    userId: 'u-1',
    title: 'إطلاق نسخة هندلها',
    description: 'نشر نسخة تجريبية قابلة للاستخدام لتنظيم المهام والمشاريع بهدوء.',
    status: 'active',
    progressPercent: 0.65,
    nextStepTitle: 'مراجعة تدفق المهام',
    targetDate: '2026-10-31',
    taskIds: ['t-1', 't-2', 't-3', 't-4'],
    subtasks: [
      'تحديث نظام الألوان الهادئ (منجز)',
      'ضبط تدفق الشات والمقترحات (منجز)',
      'إعداد جلسة التركيز التفاعلية',
    ],
    accentColor: '#2F6F68',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '2',
    userId: 'u-1',
    title: 'تنظيم مساحة العمل',
    description: 'تهيئة مكان مريح للتركيز والإنجاز والتخلص من المشتتات.',
    status: 'active',
    progressPercent: 0.40,
    nextStepTitle: 'ترتيب أوراق المشاريع المؤجلة',
    targetDate: '2026-10-25',
    taskIds: [],
    subtasks: [
      'فرز الملاحظات الورقية',
      'تنظيم الملفات الرقمية في مجلدات هادئة',
      'إعداد إضاءة مريحة للقراءة',
    ],
    accentColor: '#5683A5',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '3',
    userId: 'u-1',
    title: 'قراءة كتاب التركيز العميق',
    description: 'قراءة هادئة على مهل، فصلًا بعد فصل، واستخلاص الدروس.',
    status: 'paused',
    progressPercent: 0.25,
    nextStepTitle: 'العودة للفصل الثالث',
    taskIds: [],
    subtasks: [
      'قراءة المقدمة والفصل 1 (منجز)',
      'قراءة الفصل 2 (منجز)',
      'تلخيص النقاط الذهبية',
    ],
    accentColor: '#B7863C',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '4',
    userId: 'u-1',
    title: 'تطوير موقع البورتفوليو الشخصي',
    description: 'عرض الأعمال والمشاريع بأسلوب Minimal عصري وبسيط.',
    status: 'completed',
    progressPercent: 1.0,
    nextStepTitle: undefined,
    taskIds: [],
    subtasks: [
      'اختيار التصميم والخطوط (منجز)',
      'كتابة نبذة عن الخبرات (منجز)',
      'نشر الموقع على الدومين (منجز)',
    ],
    accentColor: '#7773A1',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

const initialNotifications: NotificationItem[] = [
  {
    id: '1',
    title: 'خطوة صغيرة جاية في السكة',
    body: 'فاضل نص ساعة على ميعاد مراجعة المهام.. جاهز تهندلها على مهلك وبكل روقان؟',
    category: 'reminder',
    time: 'منذ 20 دقيقة',
    isRead: false,
  },
  {
    id: '2',
    title: 'الله ينور عليك يا فنان ✨',
    body: 'عاش والله! خلّصت مهمتين أساسيتين في أول النهار.. اشربلك شاي ولا قهوة وروّق 5 دقايق تستاهلهم!',
    category: 'encouragement',
    time: 'منذ ساعتين',
    isRead: true,
  },
  {
    id: '3',
    title: 'جلسة تركيز على الرايق',
    body: 'دلوقتي وقت رايق جداً تاخدلك جلسة بومودورو 25 دقيقة وتنجز اللي وراك بهدوء.',
    category: 'focus',
    time: 'منذ 4 ساعات',
    isRead: true,
  },
  {
    id: '4',
    title: 'مهمة محتاجة إعادة تظبيط',
    body: 'ولا تشيل هم خالص، هنظبط ميعاد مهمة "مكالمة المهندس" على قد وقتك ومزاجك.',
    category: 'important',
    time: 'البارحة',
    isRead: true,
  },
];

const initialMessages: ChatMessageItem[] = [
  {
    id: '1',
    text: 'صباح الفل والروقان 🌿\nقول أو احكيلي في ريكورد إيه اللي شاغل بالك، وهنهندله سوا خطوة خطوة بدون أي كروكة أو ضغط أعصاب.',
    isFromUser: false,
    time: '09:00 ص',
    type: 'text',
  },
  {
    id: '2',
    text: 'عندي اجتماع بكرة الصبح بدري ولازم أراجع العرض التقديمي قبل ما أنام.',
    isFromUser: true,
    time: '09:02 ص',
    type: 'text',
  },
  {
    id: '3',
    text: 'تمام يا سيدي وزي الفل! رتبتهالك على الرايق وعلى قد طاقتك، عشان تخلّص وتنام مرتاح ومفيش حاجة تقلقك:',
    isFromUser: false,
    time: '09:03 ص',
    type: 'proposal',
    proposalTitle: 'مراجعة خفيفة للعرض التقديمي (بريزنتيشن)',
    proposalDuration: '40 دقيقة',
    proposalPriority: 'high',
    isConfirmed: false,
  },
];

const AppContext = createContext<AppContextType | null>(null);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<AppUser | null>({
    id: 'u-1',
    email: 'ahmed@handelha.app',
    displayName: 'أحمد',
    avatarUrl: '',
    isOnboardingCompleted: true,
    preferredTone: 'friendly',
    activityTime: 'morning',
    notificationPreference: 'gentle',
    themeMode: 'light',
  });

  const [currentRoute, setCurrentRoute] = useState<string>('/home');
  const [routeExtra, setRouteExtra] = useState<any>(null);
  const [themeMode, setThemeModeState] = useState<'light' | 'dark' | 'system'>(() => {
    try {
      const saved = localStorage.getItem('handelha_theme_mode');
      if (saved === 'dark' || saved === 'light' || saved === 'system') {
        return saved;
      }
    } catch {
      // ignore
    }
    return 'light';
  });

  const [systemPrefersDark, setSystemPrefersDark] = useState<boolean>(() => {
    try {
      return typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches;
    } catch {
      return false;
    }
  });

  // Listen to OS prefers-color-scheme changes
  useEffect(() => {
    try {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const handler = (e: MediaQueryListEvent) => {
        setSystemPrefersDark(e.matches);
      };
      mediaQuery.addEventListener('change', handler);
      return () => mediaQuery.removeEventListener('change', handler);
    } catch {
      // ignore
    }
  }, []);
  
  const [tasks, setTasks] = useState<Task[]>(initialTasks);
  const [projects, setProjects] = useState<Project[]>(initialProjects);
  const [notifications, setNotifications] = useState<NotificationItem[]>(initialNotifications);
  const [quietHoursEnabled, setQuietHoursEnabled] = useState<boolean>(true);
  const [chatMessages, setChatMessages] = useState<ChatMessageItem[]>(initialMessages);

  // Modals
  const [isQuickAddOpen, setIsQuickAddOpen] = useState(false);
  const [isSmartAddOpen, setIsSmartAddOpen] = useState(false);
  const [isAiBreakdownOpen, setIsAiBreakdownOpen] = useState(false);
  const [isNewProjectOpen, setIsNewProjectOpen] = useState(false);
  const [activeProjectWorkspace, setActiveProjectWorkspace] = useState<Project | null>(initialProjects[0]);
  const [activeFocusTask, setActiveFocusTask] = useState<string>('مراجعة تدفق المهام');

  const isDarkMode =
    themeMode === 'dark' || (themeMode === 'system' && systemPrefersDark);

  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
      document.body.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
      document.body.classList.remove('dark');
    }
  }, [isDarkMode]);

  const setThemeMode = (mode: 'light' | 'dark' | 'system') => {
    setThemeModeState(mode);
    try {
      localStorage.setItem('handelha_theme_mode', mode);
    } catch {
      // ignore
    }
    if (user) {
      setUser({ ...user, themeMode: mode });
    }
  };

  const navigate = (route: string, extra?: any) => {
    setCurrentRoute(route);
    setRouteExtra(extra || null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const login = (email: string, name?: string) => {
    const newUser: AppUser = {
      id: `u-${Date.now()}`,
      email,
      displayName: name || email.split('@')[0] || 'صديقي',
      avatarUrl: '',
      isOnboardingCompleted: true,
      preferredTone: 'friendly',
      activityTime: 'morning',
      notificationPreference: 'gentle',
      themeMode: 'light',
    };
    setUser(newUser);
    navigate('/home');
  };

  const logout = () => {
    setUser(null);
    navigate('/login');
  };

  const completeOnboarding = (data: Partial<AppUser>) => {
    if (user) {
      setUser({ ...user, ...data, isOnboardingCompleted: true });
    }
    navigate('/home');
  };

  const updateUserProfile = (data: Partial<AppUser>) => {
    if (user) {
      setUser({ ...user, ...data });
    }
  };

  const createTask = ({
    title,
    description,
    priority = 'medium',
    status = 'planned',
    projectId,
    estimatedDurationMinutes = 25,
    scheduledStartAt,
    timeSlot,
    dueAt,
    energyLevel = 'medium',
    source = 'manual',
  }: {
    title: string;
    description?: string;
    priority?: TaskPriority;
    status?: TaskStatus;
    projectId?: string;
    estimatedDurationMinutes?: number;
    scheduledStartAt?: string;
    timeSlot?: string;
    dueAt?: string;
    energyLevel?: EnergyLevel;
    source?: TaskSource;
  }): Task => {
    let computedTimeSlot = timeSlot;
    if (!computedTimeSlot && dueAt) {
      computedTimeSlot = formatEgyptianFullDeadline(dueAt);
    }

    const newTask: Task = {
      id: `t-${Date.now()}`,
      userId: user?.id || 'u-1',
      title: title.trim(),
      description: description?.trim() || undefined,
      priority,
      status,
      projectId,
      estimatedDurationMinutes,
      timeSlot: computedTimeSlot || undefined,
      dueAt: dueAt || undefined,
      scheduledStartAt: scheduledStartAt || undefined,
      energyLevel,
      source,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    setTasks(prev => [newTask, ...prev]);
    return newTask;
  };

  const toggleTaskCompletion = (taskId: string) => {
    setTasks(prev =>
      prev.map(t => {
        if (t.id === taskId) {
          const isDone = t.status === 'completed';
          return {
            ...t,
            status: isDone ? 'planned' : 'completed',
            updatedAt: new Date().toISOString(),
          };
        }
        return t;
      })
    );
  };

  const deleteTask = (taskId: string) => {
    setTasks(prev => prev.filter(t => t.id !== taskId));
  };

  const updateTask = (taskId: string, updates: Partial<Task>) => {
    setTasks(prev =>
      prev.map(t => {
        if (t.id === taskId) {
          return {
            ...t,
            ...updates,
            updatedAt: new Date().toISOString(),
          };
        }
        return t;
      })
    );
  };

  const createProject = ({
    title,
    description,
    accentColor = '#2F6F68',
  }: {
    title: string;
    description?: string;
    accentColor?: string;
  }): Project => {
    const newProj: Project = {
      id: `p-${Date.now()}`,
      userId: user?.id || 'u-1',
      title,
      description,
      status: 'active',
      progressPercent: 0,
      nextStepTitle: undefined,
      taskIds: [],
      subtasks: [],
      accentColor,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    setProjects(prev => [newProj, ...prev]);
    return newProj;
  };

  const updateProject = (id: string, updates: Partial<Project>) => {
    setProjects(prev =>
      prev.map(p => (p.id === id ? { ...p, ...updates, updatedAt: new Date().toISOString() } : p))
    );
    if (activeProjectWorkspace?.id === id) {
      setActiveProjectWorkspace(prev => (prev ? { ...prev, ...updates } : null));
    }
  };

  const markNotificationRead = (id: string) => {
    setNotifications(prev =>
      prev.map(n => (n.id === id ? { ...n, isRead: true } : n))
    );
  };

  const markAllNotificationsRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
  };

  const sendChatMessage = (text: string) => {
    const userMsg: ChatMessageItem = {
      id: `msg-${Date.now()}`,
      text,
      isFromUser: true,
      time: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
      type: 'text',
    };
    setChatMessages(prev => [...prev, userMsg]);

    setTimeout(async () => {
      try {
        const history = chatMessages.map(m => ({
          text: m.text,
          isFromUser: Boolean(m.isFromUser || m.sender === 'user'),
        }));

        const result = await generateEgyptianAiResponse(text, history, user?.displayName || 'يا غالي');

        let createdTaskId: string | undefined = undefined;
        let finalProposals = result.proposals;

        // If direct task creation was detected (e.g. "اعمل تاسك...", "ضيف مهمة...")
        if (result.isDirectAction) {
          if (finalProposals && finalProposals.length > 0) {
            finalProposals = finalProposals.map(p => {
              let durMin = 25;
              if (p.duration) {
                const match = p.duration.match(/\d+/);
                if (match) durMin = parseInt(match[0], 10);
                else if (p.duration.includes('ساعة')) durMin = 60;
              }
              const created = createTask({
                title: p.title,
                priority: p.priority,
                status: 'planned',
                estimatedDurationMinutes: durMin,
                dueAt: p.dueAt,
                timeSlot: p.timeSlot,
                description: p.description,
                source: 'chat',
              });
              return { ...p, isConfirmed: true, createdTaskId: created.id };
            });
            createdTaskId = finalProposals[0]?.createdTaskId;
          } else if (result.proposalTitle) {
            const newTask = createTask({
              title: result.proposalTitle,
              priority: result.proposalPriority || 'medium',
              status: 'planned',
              estimatedDurationMinutes: result.parsedTask?.estimatedDurationMinutes || 25,
              dueAt: result.proposalDueAt,
              timeSlot: result.proposalTimeSlot,
              description: result.proposalDescription,
              source: 'chat',
            });
            createdTaskId = newTask.id;
          }
        }

        const hasAnyProposals = (finalProposals && finalProposals.length > 0) || Boolean(result.proposalTitle);

        const aiReply: ChatMessageItem = {
          id: `msg-${Date.now() + 1}`,
          text: result.text,
          isFromUser: false,
          time: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
          type: hasAnyProposals ? 'proposal' : 'text',
          proposalTitle: result.proposalTitle,
          proposalDuration: result.proposalDuration,
          proposalPriority: result.proposalPriority,
          proposalDueAt: result.proposalDueAt,
          proposalTimeSlot: result.proposalTimeSlot,
          proposalDescription: result.proposalDescription,
          proposals: finalProposals,
          isConfirmed: Boolean(result.isDirectAction),
          isDirectCreatedTask: Boolean(result.isDirectAction),
          createdTaskId,
        };
        setChatMessages(prev => [...prev, aiReply]);
      } catch {
        const fallbackReply: ChatMessageItem = {
          id: `msg-${Date.now() + 1}`,
          text: `ولا تشيل هم خالص يا سيدي! فهمت قصدك وعينيا ليك، هنهندلها سوا خطوة خطوة على الرايق ✨`,
          isFromUser: false,
          time: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
          type: 'proposal',
          proposalTitle: text,
          proposalDuration: '25 دقيقة',
          proposalPriority: 'medium',
          isConfirmed: false,
        };
        setChatMessages(prev => [...prev, fallbackReply]);
      }
    }, 600);
  };

  const sendVoiceMessage = (duration: string) => {
    const voiceMsg: ChatMessageItem = {
      id: `msg-${Date.now()}`,
      text: `تسجيل صوتي (${duration}) 🎙️`,
      isFromUser: true,
      time: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
      type: 'voiceNote',
      audioDuration: duration,
    };
    setChatMessages(prev => [...prev, voiceMsg]);

    setTimeout(() => {
      const voiceResult = generateEgyptianVoiceResponse(duration, user?.displayName || 'يا غالي');
      const aiReply: ChatMessageItem = {
        id: `msg-${Date.now() + 1}`,
        text: voiceResult.text,
        isFromUser: false,
        time: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
        type: 'proposal',
        proposalTitle: voiceResult.proposalTitle,
        proposalDuration: voiceResult.proposalDuration,
        proposalPriority: voiceResult.proposalPriority,
        proposalDueAt: voiceResult.proposalDueAt,
        proposalTimeSlot: voiceResult.proposalTimeSlot,
        proposalDescription: voiceResult.proposalDescription,
        isConfirmed: false,
      };
      setChatMessages(prev => [...prev, aiReply]);
    }, 800);
  };

  const confirmProposal = (messageId: string, proposalId?: string) => {
    const msg = chatMessages.find(m => m.id === messageId);
    if (!msg) return;

    // Handle multiple proposals case
    if (msg.proposals && msg.proposals.length > 0) {
      if (proposalId) {
        // Confirm single proposal item
        const target = msg.proposals.find(p => p.id === proposalId);
        if (!target || target.isConfirmed) return;

        let durMin = 25;
        if (target.duration) {
          const numMatch = target.duration.match(/\d+/);
          if (numMatch) durMin = parseInt(numMatch[0], 10);
          else if (target.duration.includes('ساعة')) durMin = 60;
        }

        const created = createTask({
          title: target.title,
          priority: target.priority || 'medium',
          status: 'planned',
          estimatedDurationMinutes: durMin,
          dueAt: target.dueAt,
          timeSlot: target.timeSlot,
          description: target.description,
          source: 'chat',
        });

        setChatMessages(prev =>
          prev.map(m => {
            if (m.id !== messageId) return m;
            const updated = (m.proposals || []).map(p =>
              p.id === proposalId ? { ...p, isConfirmed: true, createdTaskId: created.id } : p
            );
            return {
              ...m,
              proposals: updated,
              isConfirmed: updated.every(p => p.isConfirmed),
            };
          })
        );
      } else {
        // Confirm ALL proposals at once
        const updated = (msg.proposals || []).map(p => {
          if (p.isConfirmed) return p;

          let durMin = 25;
          if (p.duration) {
            const numMatch = p.duration.match(/\d+/);
            if (numMatch) durMin = parseInt(numMatch[0], 10);
            else if (p.duration.includes('ساعة')) durMin = 60;
          }

          const created = createTask({
            title: p.title,
            priority: p.priority || 'medium',
            status: 'planned',
            estimatedDurationMinutes: durMin,
            dueAt: p.dueAt,
            timeSlot: p.timeSlot,
            description: p.description,
            source: 'chat',
          });

          return { ...p, isConfirmed: true, createdTaskId: created.id };
        });

        setChatMessages(prev =>
          prev.map(m => (m.id === messageId ? { ...m, proposals: updated, isConfirmed: true } : m))
        );
      }
      return;
    }

    // Single proposal fallback
    if (!msg.proposalTitle) return;

    let durMin = 25;
    if (msg.proposalDuration) {
      const numMatch = msg.proposalDuration.match(/\d+/);
      if (numMatch) {
        durMin = parseInt(numMatch[0], 10);
      } else if (msg.proposalDuration.includes('ساعة')) {
        durMin = 60;
      }
    }

    const created = createTask({
      title: msg.proposalTitle,
      priority: msg.proposalPriority || 'medium',
      status: 'planned',
      estimatedDurationMinutes: durMin,
      dueAt: msg.proposalDueAt,
      timeSlot: msg.proposalTimeSlot,
      description: msg.proposalDescription,
      source: 'chat',
    });

    setChatMessages(prev =>
      prev.map(m =>
        m.id === messageId
          ? {
              ...m,
              isConfirmed: true,
              createdTaskId: created.id,
            }
          : m
      )
    );
  };

  return (
    <AppContext.Provider
      value={{
        user,
        currentRoute,
        navigate,
        routeExtra,
        themeMode,
        isDarkMode,
        setThemeMode,
        login,
        logout,
        completeOnboarding,
        updateUserProfile,
        tasks,
        createTask,
        toggleTaskCompletion,
        deleteTask,
        updateTask,
        projects,
        createProject,
        updateProject,
        notifications,
        quietHoursEnabled,
        setQuietHoursEnabled,
        markNotificationRead,
        markAllNotificationsRead,
        chatMessages,
        sendChatMessage,
        sendVoiceMessage,
        confirmProposal,
        isQuickAddOpen,
        setIsQuickAddOpen,
        isSmartAddOpen,
        setIsSmartAddOpen,
        isAiBreakdownOpen,
        setIsAiBreakdownOpen,
        isNewProjectOpen,
        setIsNewProjectOpen,
        activeProjectWorkspace,
        setActiveProjectWorkspace,
        activeFocusTask,
        setActiveFocusTask,
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp must be used within AppProvider');
  return ctx;
};
