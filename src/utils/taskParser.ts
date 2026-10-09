import { TaskPriority, EnergyLevel } from '../types/index';

export interface ParsedTaskInfo {
  title: string;
  rawText: string;
  priority: TaskPriority;
  priorityLabel: string;
  estimatedDurationMinutes: number;
  durationLabel: string;
  dueAt?: string;
  timeSlot?: string;
  dateString?: string; // YYYY-MM-DD
  timeString?: string; // HH:mm
  energyLevel: EnergyLevel;
  isDirectAction: boolean;
  notes?: string;
  category?: 'study' | 'meeting' | 'work' | 'personal' | 'fitness' | 'general';
}

/**
 * Egyptian day name offset helper
 */
const DAY_NAME_MAP: Record<string, number> = {
  السبت: 6,
  الأحد: 0,
  الاحد: 0,
  الاثنين: 1,
  الإثنين: 1,
  التلات: 2,
  الثلاثاء: 2,
  الاربع: 3,
  الأربعاء: 3,
  الخميس: 4,
  الجمعة: 5,
};

/**
 * Formats a Date object into a friendly Arabic time/date slot
 */
export function formatEgyptianDateSlot(d: Date, hasSpecificTime: boolean = true): string {
  const now = new Date();
  const isToday =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();

  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);
  const isTomorrow =
    d.getFullYear() === tomorrow.getFullYear() &&
    d.getMonth() === tomorrow.getMonth() &&
    d.getDate() === tomorrow.getDate();

  const afterTomorrow = new Date(now);
  afterTomorrow.setDate(now.getDate() + 2);
  const isAfterTomorrow =
    d.getFullYear() === afterTomorrow.getFullYear() &&
    d.getMonth() === afterTomorrow.getMonth() &&
    d.getDate() === afterTomorrow.getDate();

  let dayLabel = '';
  if (isToday) {
    dayLabel = 'اليوم';
  } else if (isTomorrow) {
    dayLabel = 'غداً';
  } else if (isAfterTomorrow) {
    dayLabel = 'بعد بكرة';
  } else {
    dayLabel = d.toLocaleDateString('ar-EG', { weekday: 'long', day: 'numeric', month: 'short' });
  }

  if (!hasSpecificTime) {
    return dayLabel;
  }

  const timeLabel = d.toLocaleTimeString('ar-EG', {
    hour: 'numeric',
    minute: d.getMinutes() === 0 ? undefined : '2-digit',
    hour12: true,
  });

  return `${dayLabel}، ${timeLabel}`;
}

/**
 * Formats an ISO string into full readable Egyptian Arabic deadline
 */
export function formatEgyptianFullDeadline(isoString?: string): string {
  if (!isoString) return '';
  try {
    const d = new Date(isoString);
    if (isNaN(d.getTime())) return isoString;

    const slot = formatEgyptianDateSlot(d, true);
    return slot;
  } catch {
    return isoString;
  }
}

/**
 * Intelligent Title Synthesizer:
 * Takes raw spoken Egyptian text and produces clean, action-oriented, professional task titles.
 * Eliminates conversational boilerplate (e.g. "عندي", "عاوز", "عشان امتحانها", etc.).
 */
export function synthesizeCleanTaskTitle(raw: string): string {
  let s = raw.trim();

  // Strip common conversational starters
  s = s.replace(/^(?:عندي|عاوز|عايز|عاوزه|عايزه|محتاج|لازم|مطلوب مني|هعمل|هسوي|هروح|هذاكر|هشتري|هكلم|اعمل|اعملي|ضيف|حط|سجل)\s*:?\s*/i, '');

  // 1. Study and Exams Mapping
  if (/امتحان.*(?:رياضه|رياضيات)/i.test(raw) || /(?:رياضه|رياضيات).*امتحان/i.test(raw)) {
    return 'مراجعة مادة الرياضيات (استعداد للامتحان)';
  }
  if (/امتحان.*(?:انجليزي|إنجليزي)/i.test(raw) || /(?:اذاكر|أذاكر|مذاكرة).*(?:انجليزي|إنجليزي)/i.test(raw)) {
    return 'مذاكرة مادة الإنجليزي';
  }
  if (/امتحان.*(?:عربي)/i.test(raw) || /(?:اذاكر|أذاكر|مذاكرة).*(?:عربي)/i.test(raw)) {
    return 'مذاكرة مادة العربي';
  }
  if (/امتحان.*(?:فيزياء|فيزيا)/i.test(raw) || /(?:اذاكر|أذاكر|مذاكرة).*(?:فيزياء|فيزيا)/i.test(raw)) {
    return 'مراجعة مادة الفيزياء';
  }
  if (/امتحان.*(?:كيمياء|كيميا)/i.test(raw) || /(?:اذاكر|أذاكر|مذاكرة).*(?:كيمياء|كيميا)/i.test(raw)) {
    return 'مراجعة مادة الكيمياء';
  }
  if (/امتحان.*(?:أحياء|احياء)/i.test(raw) || /(?:اذاكر|أذاكر|مذاكرة).*(?:أحياء|احياء)/i.test(raw)) {
    return 'مراجعة مادة الأحياء';
  }
  if (/امتحان.*(?:تاريخ)/i.test(raw) || /(?:اذاكر|أذاكر|مذاكرة).*(?:تاريخ)/i.test(raw)) {
    return 'مراجعة مادة التاريخ';
  }
  if (/امتحان.*(?:جغرافيا)/i.test(raw) || /(?:اذاكر|أذاكر|مذاكرة).*(?:جغرافيا)/i.test(raw)) {
    return 'مراجعة مادة الجغرافيا';
  }
  if (/(?:امتحان|اختبار)\s*(?:مادة|ماده)?\s*([^\s,،\.]+)/i.test(raw)) {
    const match = raw.match(/(?:امتحان|اختبار)\s*(?:مادة|ماده)?\s*([^\s,،\.]+)/i);
    if (match && match[1] && !['بكره', 'النهاردة', 'يوم'].includes(match[1])) {
      return `مراجعة مادة ${match[1]} (استعداد للامتحان)`;
    }
  }
  if (/(?:اذاكر|أذاكر|مذاكرة)\s*(?:مادة|ماده)?\s*([^\s,،\.]+)/i.test(raw)) {
    const match = raw.match(/(?:اذاكر|أذاكر|مذاكرة)\s*(?:مادة|ماده)?\s*([^\s,،\.]+)/i);
    if (match && match[1] && !['بكره', 'النهاردة', 'يوم', 'ساعتين'].includes(match[1])) {
      return `مذاكرة مادة ${match[1]}`;
    }
  }

  // 2. Work & Meetings Mapping
  if (/(?:ميتنج|اجتماع|meeting).*(?:عميل|العميل)/i.test(raw)) {
    return 'اجتماع ومناقشة مع العميل';
  }
  if (/(?:ميتنج|اجتماع|meeting)\s*(?:مع)?\s*([^\s,،\.]+)/i.test(raw)) {
    const match = raw.match(/(?:ميتنج|اجتماع|meeting)\s*(?:مع)?\s*([^\s,،\.]+)/i);
    if (match && match[1] && !['بكره', 'النهاردة', 'الساعة'].includes(match[1])) {
      return `اجتماع مع ${match[1]}`;
    }
  }
  if (/(?:مكالمة|اكلم|أكلم)\s*(?:مع)?\s*([^\s,،\.]+)/i.test(raw)) {
    const match = raw.match(/(?:مكالمة|اكلم|أكلم)\s*(?:مع)?\s*([^\s,،\.]+)/i);
    if (match && match[1] && !['بكره', 'النهاردة', 'الساعة'].includes(match[1])) {
      return `مكالمة هاتفية مع ${match[1]}`;
    }
  }
  if (/(?:تقرير|التقرير)/i.test(raw)) {
    return 'إعداد ومراجعة التقرير';
  }
  if (/(?:كود|برمجة|كودنج|coding)/i.test(raw)) {
    return 'مراجعة وتطوير الكود البرمجي';
  }
  if (/(?:تصميم|ديزاين|design)/i.test(raw)) {
    return 'تصميم ومراجعة الواجهات';
  }
  if (/(?:بروجكت|مشروع)/i.test(raw)) {
    return 'العمل على مهام المشروع';
  }

  // 3. Personal & Fitness
  if (/(?:جيم|الجيم|تمرين|رياضة|فتنس)/i.test(raw)) {
    return 'تمرين الجيم واللياقة البدنية';
  }
  if (/(?:اشتري|أشتري|شراء|اجيب|أجيب)\s*([^\s,،\.]+)/i.test(raw)) {
    const match = raw.match(/(?:اشتري|أشتري|شراء|اجيب|أجيب)\s*([^\s,،\.]+)/i);
    if (match && match[1]) {
      return `شراء ${match[1]}`;
    }
  }

  // 4. Clean Fallback
  let cleaned = s
    .replace(/(?:عشان\s*امتحانها|عشان\s*الامتحان|عشان\s*امتحان|عشان\s*نناقش|عشان|علشان)[^,،\.]*/gi, '')
    .replace(/(?:وأولوية|واولوية|أولوية|اولوية)\s*(?:عالية|قصوى|عاجلة|ضرورية|متوسطة|هادئة|خفيفة|طحن|موت|urgent|high|medium|low)/gi, '')
    .replace(/(?:مدتها|تاخد|محتاجة|في حدود|لمدة)\s*(?:ساعة|ساعتين|ساعة ونص|نص ساعة|ربع ساعة|تلت ساعة|\d+\s*دقيقة)/gi, '')
    .replace(/(?:النهاردة|اليوم|بكرة|غداً|بعد بكرة|يوم\s*(?:السبت|الأحد|الاثنين|الثلاثاء|الأربعاء|الخميس|الجمعة))\s*(?:الجاي|القادم)?/gi, '')
    .replace(/(?:السبت|الأحد|الاثنين|الثلاثاء|الأربعاء|الخميس|الجمعة)\s*(?:الجاي|القادم)?/gi, '')
    .replace(/الساعة\s*\d{1,2}(?::\d{2})?\s*(?:صباحاً|مساءً|الصبح|الضهر|بعد الضهر|العصر|المغرب|بالليل|م|ص)?/gi, '')
    .replace(/(?:الصبح بدري|الصبح|الضهر|بعد الضهر|بعد الظهر|العصر|بعد العصر|المغرب|العشا|بالليل|مساءً|صباحاً)/gi, '')
    .replace(/(?:على الرايق|على الهادي|بدون استعجال|على مهلك|يا بطل)/gi, '')
    .replace(/\s{2,}/g, ' ')
    .trim();

  if (cleaned.length < 3) {
    return raw.trim();
  }

  return cleaned;
}

/**
 * Intelligent Egyptian Dialect Parser for single task
 */
export function parseEgyptianTaskInput(input: string, referenceDate: Date = new Date()): ParsedTaskInfo {
  const trimmed = input.trim();
  const lower = trimmed.toLowerCase();

  // 1. Detect if this is an explicit command to create/add a task
  const actionTriggers = [
    'اعمل تاسك',
    'اعملي تاسك',
    'اعمل مهمة',
    'اعملي مهمة',
    'ضيف تاسك',
    'ضيف مهمة',
    'حط تاسك',
    'حط مهمة',
    'سجل مهمة',
    'سجل تاسك',
    'سجل عندي',
    'كريت تاسك',
    'عاوزك تعمل مهمة',
    'عاوز اعمل تاسك',
    'عايز اعمل تاسك',
    'عايز اضيف مهمة',
    'عاوز اضيف مهمة',
    'اكتب عندك مهمة',
    'جدول مهمة',
  ];

  let isDirectAction = false;
  for (const trigger of actionTriggers) {
    if (lower.includes(trigger)) {
      isDirectAction = true;
      break;
    }
  }

  // 2. Parse Priority
  let priority: TaskPriority = 'medium';
  let priorityLabel = 'متوسطة';

  // If exam tomorrow -> automatically urgent
  const hasExam = lower.includes('امتحان') || lower.includes('اختبار');
  const isTomorrow = lower.includes('بكرة') || lower.includes('غداً') || lower.includes('بكره');
  const isToday = lower.includes('النهاردة') || lower.includes('اليوم');

  if (hasExam && (isTomorrow || isToday)) {
    priority = 'urgent';
    priorityLabel = 'عاجل جداً (امتحان قريب)';
  } else if (
    lower.includes('عاجل') ||
    lower.includes('ضروري') ||
    lower.includes('طحن') ||
    lower.includes('موت') ||
    lower.includes('طوارئ') ||
    lower.includes('في أسرع وقت') ||
    lower.includes('مستعجل') ||
    lower.includes('urgent')
  ) {
    priority = 'urgent';
    priorityLabel = 'عاجل جداً';
  } else if (
    hasExam ||
    lower.includes('أولوية عالية') ||
    lower.includes('اولوية عالية') ||
    lower.includes('عالي') ||
    lower.includes('مهم جدا') ||
    lower.includes('مهم') ||
    lower.includes('لازم') ||
    lower.includes('تسليم') ||
    lower.includes('high')
  ) {
    priority = 'high';
    priorityLabel = 'عالية';
  } else if (
    lower.includes('على الرايق') ||
    lower.includes('على الهادي') ||
    lower.includes('هادي') ||
    lower.includes('خفيف') ||
    lower.includes('بسيط') ||
    lower.includes('مش مستعجل') ||
    lower.includes('براحتي') ||
    lower.includes('لما أفضى') ||
    lower.includes('low')
  ) {
    priority = 'low';
    priorityLabel = 'هادئة';
  } else {
    priority = 'medium';
    priorityLabel = 'متوسطة';
  }

  // 3. Parse Duration (in minutes)
  let estimatedDurationMinutes = 25;
  let durationLabel = '25 دقيقة';

  if (hasExam) {
    estimatedDurationMinutes = 90;
    durationLabel = '90 دقيقة (جلسة مراجعة)';
  } else if (lower.includes('اذاكر') || lower.includes('أذاكر') || lower.includes('مذاكرة')) {
    estimatedDurationMinutes = 60;
    durationLabel = 'ساعة كاملة (مذاكرة)';
  } else if (lower.includes('ساعتين') || lower.includes('٢ ساعة')) {
    estimatedDurationMinutes = 120;
    durationLabel = 'ساعتين';
  } else if (lower.includes('ساعة ونص') || lower.includes('ساعه ونص')) {
    estimatedDurationMinutes = 90;
    durationLabel = 'ساعة ونصف';
  } else if (lower.includes('ساعة') || lower.includes('ساعه')) {
    if (lower.includes('نص ساعة') || lower.includes('نصف ساعة') || lower.includes('نص ساعه')) {
      estimatedDurationMinutes = 30;
      durationLabel = '30 دقيقة';
    } else if (lower.includes('ربع ساعة') || lower.includes('ربع ساعه')) {
      estimatedDurationMinutes = 15;
      durationLabel = '15 دقيقة';
    } else if (lower.includes('تلت ساعة') || lower.includes('ثلث ساعة') || lower.includes('تلت ساعه')) {
      estimatedDurationMinutes = 20;
      durationLabel = '20 دقيقة';
    } else {
      estimatedDurationMinutes = 60;
      durationLabel = 'ساعة كاملة';
    }
  } else {
    const minMatch = lower.match(/(\d+)\s*(دقيقة|دقايق|د)/);
    if (minMatch) {
      const parsedMin = parseInt(minMatch[1], 10);
      if (!isNaN(parsedMin) && parsedMin > 0) {
        estimatedDurationMinutes = parsedMin;
        durationLabel = `${parsedMin} دقيقة`;
      }
    } else if (lower.includes('نص ساعه') || lower.includes('نص ساعة')) {
      estimatedDurationMinutes = 30;
      durationLabel = '30 دقيقة';
    } else if (lower.includes('ربع ساعه') || lower.includes('ربع ساعة')) {
      estimatedDurationMinutes = 15;
      durationLabel = '15 دقيقة';
    } else if (lower.includes('تلت ساعه') || lower.includes('تلت ساعة')) {
      estimatedDurationMinutes = 20;
      durationLabel = '20 دقيقة';
    }
  }

  // 4. Parse Date & Deadline
  const targetDate = new Date(referenceDate);
  let hasDate = false;
  let hasSpecificTime = false;

  if (lower.includes('النهاردة') || lower.includes('اليوم')) {
    hasDate = true;
  } else if (lower.includes('بكرة') || lower.includes('غداً') || lower.includes('غدا') || lower.includes('بكره')) {
    targetDate.setDate(targetDate.getDate() + 1);
    hasDate = true;
  } else if (lower.includes('بعد بكرة') || lower.includes('بعد غد')) {
    targetDate.setDate(targetDate.getDate() + 2);
    hasDate = true;
  } else {
    // Check weekdays
    for (const [dayName, dayIdx] of Object.entries(DAY_NAME_MAP)) {
      if (lower.includes(dayName)) {
        const currentDay = referenceDate.getDay();
        let diff = dayIdx - currentDay;
        if (diff <= 0) diff += 7; // Next occurrence
        targetDate.setDate(referenceDate.getDate() + diff);
        hasDate = true;
        break;
      }
    }
  }

  // 5. Parse Time of Day
  let hour = hasExam ? 10 : 17; // Default 10 AM for exams, 5 PM for tasks
  let minute = 0;

  const hourMatch = lower.match(/الساعة\s*(\d{1,2})(?::(\d{2}))?/);
  const arabicHourWords: Record<string, number> = {
    واحدة: 1,
    اتنين: 2,
    تلاتة: 3,
    ثلاثة: 3,
    أربعة: 4,
    اربعه: 4,
    خمسة: 5,
    خميس: 5,
    ستة: 6,
    سبعة: 7,
    تمانية: 8,
    ثمانية: 8,
    تسعة: 9,
    عشرة: 10,
    حداشر: 11,
    إتناشر: 12,
    اتناشر: 12,
  };

  let extractedHour: number | null = null;
  if (hourMatch) {
    extractedHour = parseInt(hourMatch[1], 10);
    if (hourMatch[2]) {
      minute = parseInt(hourMatch[2], 10);
    }
    hasSpecificTime = true;
  } else {
    for (const [word, hVal] of Object.entries(arabicHourWords)) {
      if (lower.includes(`الساعة ${word}`) || lower.includes(`ساعة ${word}`)) {
        extractedHour = hVal;
        hasSpecificTime = true;
        break;
      }
    }
  }

  const isNightOrEvening =
    lower.includes('بالليل') ||
    lower.includes('مساء') ||
    lower.includes('م') ||
    lower.includes('المغرب') ||
    lower.includes('العشا') ||
    lower.includes('العصر') ||
    lower.includes('بعد الضهر') ||
    lower.includes('بعد الظهر');

  const isMorning =
    lower.includes('الصبح') ||
    lower.includes('صباحا') ||
    lower.includes('صباحاً') ||
    lower.includes('بدري');

  if (extractedHour !== null) {
    if (isNightOrEvening && extractedHour < 12) {
      extractedHour += 12;
    } else if (isMorning && extractedHour === 12) {
      extractedHour = 0;
    } else if (!isMorning && !isNightOrEvening && extractedHour <= 7) {
      extractedHour += 12;
    }
    hour = extractedHour;
  } else {
    if (lower.includes('الصبح بدري') || lower.includes('الصبح')) {
      hour = 9;
      minute = 0;
      hasSpecificTime = true;
    } else if (lower.includes('الضهر') || lower.includes('الظهر')) {
      hour = 13;
      minute = 0;
      hasSpecificTime = true;
    } else if (lower.includes('بعد الضهر') || lower.includes('بعد الظهر')) {
      hour = 14;
      minute = 30;
      hasSpecificTime = true;
    } else if (lower.includes('العصر') || lower.includes('بعد العصر')) {
      hour = 16;
      minute = 30;
      hasSpecificTime = true;
    } else if (lower.includes('المغرب')) {
      hour = 18;
      minute = 30;
      hasSpecificTime = true;
    } else if (lower.includes('بالليل') || lower.includes('العشا') || lower.includes('مساء')) {
      hour = 20;
      minute = 0;
      hasSpecificTime = true;
    }
  }

  let dueAt: string | undefined = undefined;
  let timeSlot: string | undefined = undefined;
  let dateString: string | undefined = undefined;
  let timeString: string | undefined = undefined;

  if (hasDate || hasSpecificTime) {
    targetDate.setHours(hour, minute, 0, 0);
    dueAt = targetDate.toISOString();
    timeSlot = formatEgyptianDateSlot(targetDate, hasSpecificTime);

    const y = targetDate.getFullYear();
    const m = String(targetDate.getMonth() + 1).padStart(2, '0');
    const day = String(targetDate.getDate()).padStart(2, '0');
    dateString = `${y}-${m}-${day}`;
    timeString = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
  }

  // 6. Synthesize Clean Task Title
  const cleanTitle = synthesizeCleanTaskTitle(trimmed);

  let energyLevel: EnergyLevel = 'medium';
  if (priority === 'urgent' || priority === 'high' || estimatedDurationMinutes >= 60) {
    energyLevel = 'high';
  } else if (priority === 'low' || estimatedDurationMinutes <= 15) {
    energyLevel = 'low';
  }

  return {
    title: cleanTitle,
    rawText: trimmed,
    priority,
    priorityLabel,
    estimatedDurationMinutes,
    durationLabel,
    dueAt,
    timeSlot,
    dateString,
    timeString,
    energyLevel,
    isDirectAction,
  };
}

/**
 * Compound Sentence Splitter & Multi-Task Extractor.
 * Splits Egyptian compound sentences (e.g. "عندي امتحان بكره ماده رياضه و عاوز اذاكر انجليزي عشان امتحانها يوم الخميس")
 * into distinct, individual task items with dedicated deadlines and priorities.
 */
export function parseMultipleEgyptianTasks(
  input: string,
  referenceDate: Date = new Date()
): ParsedTaskInfo[] {
  const trimmed = input.trim();
  if (!trimmed) return [];

  // Regex to split compound sentences by Egyptian conjunctions and markers
  // Splits on: "و عاوز", "وعاوز", "و عايز", "وعايز", "وكمان", "وبعدين", "وبعد كده", "وفي نفس الوقت", "،", "\n"
  // And "و" when followed by action verbs like "اذاكر", "أذاكر", "اشتري", "اكلم", "اروح", "اخلص", "عندي"
  const splitRegex = /\s*(?:و\s*(?:عاوز|عايز|عاوزه|عايزه|محتاج|لازم|عندي|هعمل|هذاكر|اذاكر|أذاكر|اشتري|أشتري|اكلم|أكلم|اروح|أروح|اخلص|أخلص|اراجع|أراجع)|وكمان|كمان|وبعدين|وبعد\s*كده|وفي\s*نفس\s*الوقت|[،,\n])\s*/i;

  const rawSegments = trimmed
    .split(splitRegex)
    .map(s => s.trim())
    .filter(s => s.length >= 3);

  // If no compound split found or only 1 segment
  if (rawSegments.length <= 1) {
    return [parseEgyptianTaskInput(trimmed, referenceDate)];
  }

  // Parse each segment independently
  const parsedList = rawSegments.map(segment => parseEgyptianTaskInput(segment, referenceDate));

  // Check if segments are genuinely distinct tasks
  // (Filter out tiny leftovers or duplicate meaningless fragments)
  const validTasks = parsedList.filter(t => t.title && t.title.length >= 3);

  if (validTasks.length === 0) {
    return [parseEgyptianTaskInput(trimmed, referenceDate)];
  }

  return validTasks;
}
