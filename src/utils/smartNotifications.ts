import { Task, Project, NotificationItem, NotificationCategory, NotificationType } from '../types';

/**
 * محرك الإشعارات الذكية باللهجة المصرية
 * مصمم لتقديم تنبيهات وتوجيهات وتشجيعات سياقية ذكية تحاكي رفيق إنتاجية إنساني حقيقي.
 */

export function createDeadlineApproachingNotification(task: Task): NotificationItem {
  const timeDescription = task.timeSlot ? `الميعاد: ${task.timeSlot}` : 'ميعادها قرب';
  return {
    id: `notif-deadline-${task.id}-${Date.now()}`,
    title: 'ديدلاين مهمة بيقرّب',
    body: `يا بطل، ديدلاين مهمة "${task.title}" بيقرّب خلاص (${timeDescription}).. يلا تكة ونخلّصها سوا ونشيل همّها!`,
    category: 'reminder',
    type: 'deadline',
    time: 'الآن',
    isRead: false,
    taskId: task.id,
    projectId: task.projectId,
    actionLabel: 'ابدأ الشغل عليها دلوقتي',
    actionUrl: '/focus-session',
    createdAt: new Date().toISOString(),
  };
}

export function createTaskCompletedNotification(task: Task, isFast: boolean = true): NotificationItem {
  const isHighPriority = task.priority === 'urgent' || task.priority === 'high';
  
  let title = 'الله ينور عليك يا فنان';
  let body = `عاش والله! قفلت مهمة "${task.title}".. خطوة ممتازة بتقربك من هدفك اليومي!`;

  if (isHighPriority) {
    title = 'عاش يا وحش.. تسلم إيدك!';
    body = `قفلت مهمة تقيلة ومهمة جداً "${task.title}" ${isFast ? 'في وقت قياسي ومظبوط' : 'بإتقان عالي'}.. مجهود يستاهل التحية والله! خدلك بوق ماية أو فنجان قهوة وروّق.`;
  }

  return {
    id: `notif-complete-${task.id}-${Date.now()}`,
    title,
    body,
    category: 'encouragement',
    type: 'achievement',
    time: 'الآن',
    isRead: false,
    taskId: task.id,
    projectId: task.projectId,
    actionLabel: 'شوف تقدمك في التحليلات',
    actionUrl: '/analytics',
    createdAt: new Date().toISOString(),
  };
}

export function createOverdueNotification(task: Task): NotificationItem {
  return {
    id: `notif-overdue-${task.id}-${Date.now()}`,
    title: 'ولا تشيل هم خالص.. هنظبطها سوا',
    body: `مهمة "${task.title}" معادها فات من شوية.. متقلقش كلنا بنسهى وبنتلخم، خد نَفَس ويلا نحددلها ميعاد مناسب أو ننجزها سوا دلوقتي!`,
    category: 'important',
    type: 'overdue',
    time: 'الآن',
    isRead: false,
    taskId: task.id,
    projectId: task.projectId,
    actionLabel: 'هندل المهمة دي دلوقتي',
    actionUrl: '/tasks',
    createdAt: new Date().toISOString(),
  };
}

export function createFocusSessionStartNotification(taskTitle: string): NotificationItem {
  return {
    id: `notif-focus-start-${Date.now()}`,
    title: 'بدأنا جلسة التركيز',
    body: `اقفل أي دوشة أو مشتتات حواليك.. 25 دقيقة تركيز صافي على "${taskTitle}". خليك حاضر وماتستعجلش.`,
    category: 'focus',
    type: 'focus_start',
    time: 'الآن',
    isRead: false,
    actionLabel: 'متابعة المؤقت',
    actionUrl: '/focus-session',
    createdAt: new Date().toISOString(),
  };
}

export function createFocusSessionFinishNotification(taskTitle: string, minutes: number = 25): NotificationItem {
  return {
    id: `notif-focus-finish-${Date.now()}`,
    title: 'عاش يا بطل.. الجلسة خلصت!',
    body: `أنجزت ${minutes} دقيقة تركيز كاملة على "${taskTitle}" بمستوى تركيز ممتاز.. خد بريك 5 دقايق، اشرب مية وريّح عينك شوية.`,
    category: 'focus',
    type: 'focus_finish',
    time: 'الآن',
    isRead: false,
    actionLabel: 'بدء استراحة 5 دقائق',
    actionUrl: '/focus-session',
    createdAt: new Date().toISOString(),
  };
}

export function createBreakFinishNotification(): NotificationItem {
  return {
    id: `notif-break-finish-${Date.now()}`,
    title: 'الاستراحة خلصت.. جاهز؟',
    body: `شحنت طاقتك وروّقت؟ يلا نرجع نكمل اللي بدأناه بنفس الحماس والتركيز الرايق!`,
    category: 'focus',
    type: 'break',
    time: 'الآن',
    isRead: false,
    actionLabel: 'بدء الجلسة التالية',
    actionUrl: '/focus-session',
    createdAt: new Date().toISOString(),
  };
}

/**
 * يقوم بفحص المهام الحالية وتوليد تنبيهات ذكية مبنية على المواعيد الفعلية وحالة المهام
 */
export function evaluateSmartNotifications(tasks: Task[], existingNotifications: NotificationItem[]): NotificationItem[] {
  const newNotifs: NotificationItem[] = [];
  const existingIds = new Set(existingNotifications.map(n => `${n.type || ''}-${n.taskId || ''}`));

  for (const task of tasks) {
    if (task.status === 'completed') continue;

    // فحص المهام العاجلة التي لم يتم إنجازها
    if (task.priority === 'urgent' && !existingIds.has(`deadline-${task.id}`)) {
      newNotifs.push(createDeadlineApproachingNotification(task));
      existingIds.add(`deadline-${task.id}`);
      continue;
    }

    // فحص المهام المتبقية التي فات ميعادها المذكور
    if (task.timeSlot && (task.timeSlot.includes('البارحة') || task.timeSlot.includes('أمس') || task.timeSlot.includes('فات')) && !existingIds.has(`overdue-${task.id}`)) {
      newNotifs.push(createOverdueNotification(task));
      existingIds.add(`overdue-${task.id}`);
    }
  }

  return newNotifs;
}
