export type TaskStatus = 'inbox' | 'planned' | 'inProgress' | 'completed' | 'cancelled';

export type TaskPriority = 'low' | 'medium' | 'high' | 'urgent';

export type EnergyLevel = 'low' | 'medium' | 'high';

export type TaskSource = 'manual' | 'chat' | 'voice' | 'ai' | 'import';

export interface Task {
  id: string;
  userId: string;
  projectId?: string;
  parentTaskId?: string;
  title: string;
  description?: string;
  status: TaskStatus;
  priority: TaskPriority;
  dueAt?: string;
  scheduledStartAt?: string;
  estimatedDurationMinutes?: number;
  actualDurationMinutes?: number;
  energyLevel: EnergyLevel;
  source: TaskSource;
  aiConfidence?: number;
  createdAt: string;
  updatedAt: string;
  timeSlot?: string;
}

export type ProjectStatus = 'active' | 'paused' | 'completed' | 'archived';

export interface Project {
  id: string;
  userId: string;
  title: string;
  description?: string;
  status: ProjectStatus;
  progressPercent: number;
  nextStepTitle?: string;
  targetDate?: string;
  taskIds: string[];
  subtasks: string[];
  accentColor: string;
  createdAt: string;
  updatedAt: string;
}

export type AssistantTone = 'friendly' | 'formal' | 'brief' | 'concise';

export interface AppUser {
  id: string;
  email: string;
  displayName: string;
  avatarUrl?: string;
  isOnboardingCompleted: boolean;
  preferredTone: AssistantTone;
  activityTime: 'morning' | 'afternoon' | 'night' | 'flexible';
  notificationPreference: 'gentle' | 'summaryOnly' | 'silent';
  themeMode: 'light' | 'dark' | 'system';
}

export type NotificationCategory = 'reminder' | 'encouragement' | 'focus' | 'important' | 'summary';

export type NotificationType = 'deadline' | 'achievement' | 'overdue' | 'focus_start' | 'focus_finish' | 'break' | 'general';

export interface NotificationItem {
  id: string;
  title: string;
  body: string;
  category: NotificationCategory;
  time: string;
  isRead: boolean;
  taskId?: string;
  projectId?: string;
  actionUrl?: string;
  actionLabel?: string;
  type?: NotificationType;
  createdAt?: string;
}

export interface ProposalCard {
  title: string;
  type: 'task' | 'breakdown';
  timeSlot?: string;
  details?: string[];
  isConfirmed?: boolean;
}

export type MessageType = 'text' | 'voiceNote' | 'proposal' | 'clarification';

export interface ProposalItem {
  id: string;
  title: string;
  duration?: string;
  priority: TaskPriority;
  dueAt?: string;
  timeSlot?: string;
  description?: string;
  isConfirmed?: boolean;
  createdTaskId?: string;
}

export interface ChatMessageItem {
  id: string;
  text: string;
  sender?: 'user' | 'assistant';
  isFromUser?: boolean;
  time?: string;
  timestamp?: string;
  type?: MessageType;
  isAudio?: boolean;
  audioDuration?: string;
  proposal?: ProposalCard;
  proposalTitle?: string;
  proposalDuration?: string;
  proposalPriority?: TaskPriority;
  proposalDueAt?: string;
  proposalTimeSlot?: string;
  proposalDescription?: string;
  isConfirmed?: boolean;
  createdTaskId?: string;
  isDirectCreatedTask?: boolean;
  proposals?: ProposalItem[];
}

export interface ProposedTaskItem {
  title: string;
  duration: string;
  priority: string;
  priorityColor: string;
  dependency?: string;
}

export interface ProposedPhaseItem {
  title: string;
  duration: string;
  tasks: ProposedTaskItem[];
}

export interface CustomMilestone {
  id: string;
  title: string;
  completed: boolean;
  category?: 'focus' | 'task' | 'wellness' | 'learning';
}

export interface DailyGoalSettings {
  targetTasksCount: number;
  targetFocusMinutes: number;
  highlightGoal: string;
  highlightCompleted: boolean;
  loggedFocusMinutes: number;
  customMilestones: CustomMilestone[];
  lastActiveDate: string;
}
