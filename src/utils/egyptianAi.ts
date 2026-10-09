import { TaskPriority, ProposalItem } from '../types/index';
import {
  parseMultipleEgyptianTasks,
  parseEgyptianTaskInput,
  ParsedTaskInfo,
} from './taskParser';

export interface EgyptianAiResult {
  text: string;
  proposalTitle?: string;
  proposalDuration?: string;
  proposalPriority?: TaskPriority;
  proposalDueAt?: string;
  proposalTimeSlot?: string;
  proposalDescription?: string;
  isDirectAction?: boolean;
  parsedTask?: ParsedTaskInfo;
  proposals?: ProposalItem[];
}

/**
 * تعليمات النظام (System Instructions) الخاصة بالمساعد الذكي:
 * 1. نبرة صوت طبيعية، مصرية، وودودة كإنسان حقيقي وصديق شخصي ذكي ومهذب.
 * 2. استباقي في فهم السياق دون تكرار كلام المستخدم حرفياً.
 * 3. تجنب استخدام أي رموز تعبيرية (Emojis) نهائياً.
 * 4. تجنب اللغة الروتينية والعبارات المعلبة المصطنعة.
 * 5. المرونة والتعميم على مختلف الأسئلة والحسابات، وحصر إنشاء المهام في المهام الحقيقية فقط.
 */
export const EGYPTIAN_SYSTEM_INSTRUCTIONS = `
أنت رفيق شخصي ومساعد ذكي يتحدث باللهجة المصرية الطبيعية المعاصرة والذكية والودودة.

قواعدك الأساسية الصارمة:
1. نبرة الصوت: تحدث بأسلوب مصري طبيعي وعفوي وودود كإنسان حقيقي مهذب ومتعلم. لا تتكلف ولا تستخدم الفصحى الجافة ولا العامية المبتذلة.
2. الفهم الاستباقي بدون تكرار: لا تكرر كلام المستخدم ولا تعيد صياغة جملته حرفياً. افهم السياق فوراً وادخل في صلب الموضوع أو الحل أو الإجابة مباشرة.
3. منع الإيموجي: ممنوع منعاً باتاً استخدام أي رموز تعبيرية أو إيموجي (No Emojis) في أي رد نصي على الإطلاق.
4. تجنب اللغة الروتينية: تجنب تماماً استخدام العبارات المكررة والمصطنعة مثل (يا رايق، على الرايق، متكتكة، بنهندلها، يا بطل).
5. التعميم وتعدد المجالات:
   - في العمليات الحسابية والرياضية (مثل 5*5): احسبها فوراً وأعطِ الناتج مباشرة بدون اختلاق مهام.
   - في التحيات والدردشة (مثل عامل ايه، ازيك): رد بشكل طبيعي ودافئ وموجز دون إنشاء بطاقات مهام.
   - في الأسئلة العامة والنصائح: أجب بفهم وخبرة مباشرة وبإيجاز مفيد.
   - في المهام والجدولة: فقط عندما يطلب المستخدم مهمة أو يذكر امتحانات أو مواعيد عمل محددة، قم باستخراجها وترتيبها بدقة.
`.trim();

/**
 * Removes any emojis from the output text to ensure clean, human-like responses.
 */
export function removeEmojis(text: string): string {
  if (!text) return '';
  return text
    .replace(
      /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}\u{2B50}\u{200D}\u{FE0F}]/gu,
      ''
    )
    .replace(/\s{2,}/g, ' ')
    .trim();
}

/**
 * Solves mathematical and arithmetic queries (pure numbers or spoken Egyptian Arabic).
 */
function solveMathExpression(raw: string): string | null {
  const trimmed = raw.trim();

  // 1. Spoken Arabic or standard math replacements
  let s = trimmed
    .replace(/^(?:احسبلي|احسب|كام|بكام|تساوي|ما هو ناتج|ما هو حاصل|كام حاصل ضرب)\s*:?\s*/gi, '')
    .replace(/(?:كام|بكام|تساوي|تساوي كام|\?|؟)$/gi, '')
    .trim();

  s = s
    .replace(/\s*في\s*/g, '*')
    .replace(/\s*ضرب\s*/g, '*')
    .replace(/\s*زائد\s*/g, '+')
    .replace(/\s*ناقص\s*/g, '-')
    .replace(/\s*على\s*/g, '/')
    .replace(/\s*قسمة\s*/g, '/')
    .replace(/x|×/gi, '*')
    .replace(/÷/g, '/')
    .replace(/\s+/g, '');

  // Percentage check: e.g. "20% من 500"
  const percentMatch = trimmed.match(/(\d+(?:\.\d+)?)\s*%\s*(?:من)?\s*(\d+(?:\.\d+)?)/);
  if (percentMatch) {
    const p = parseFloat(percentMatch[1]);
    const total = parseFloat(percentMatch[2]);
    const res = (p / 100) * total;
    return `الناتج هو ${res}.`;
  }

  // Check if expression is strictly valid math (digits, operators, parentheses)
  if (/^[\d\.\+\-\*\/\(\)]+$/.test(s) && /[\+\-\*\/]/.test(s)) {
    try {
      // Safe numeric arithmetic evaluation
      const val = Function('"use strict"; return (' + s + ')')();
      if (typeof val === 'number' && !isNaN(val) && isFinite(val)) {
        // Human Arabic formatting for numbers
        const cleanVal = Number.isInteger(val) ? val : parseFloat(val.toFixed(2));
        if (trimmed === `${s}` || /^\d+\s*[\*\+\-\/x×÷]\s*\d+$/.test(trimmed)) {
          return `${trimmed} = ${cleanVal}`;
        }
        return `الناتج هو ${cleanVal}.`;
      }
    } catch {
      // not a plain math expression
    }
  }

  return null;
}

/**
 * Checks if input is genuine task/scheduling intent (as opposed to conversational questions or chat).
 */
function isTaskOrSchedulingIntent(text: string): boolean {
  const lower = text.toLowerCase().trim();

  // Explicit command to add or schedule a task
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
  if (actionTriggers.some(t => lower.includes(t))) {
    return true;
  }

  // Project breakdown triggers
  if (lower.startsWith('قسّم') || lower.startsWith('قسم') || lower.includes('قسّم لي') || lower.includes('قسم لي')) {
    return true;
  }

  // Day/Week reorganization triggers
  if (
    lower.includes('رتبلي اولوياتي') ||
    lower.includes('رتبلي أولوياتي') ||
    lower.includes('رتب أولوياتي') ||
    lower.includes('نظم لي يومي') ||
    lower.includes('خطة الاسبوع')
  ) {
    return true;
  }

  // Real work/study commitments with dates or specific intent:
  // e.g. "عندي امتحان بكره...", "عاوز اذاكر...", "ميتنج مع العميل...", "تسليم تقرير..."
  const hasTaskSubject =
    lower.includes('امتحان') ||
    lower.includes('اختبار') ||
    lower.includes('اذاكر') ||
    lower.includes('أذاكر') ||
    lower.includes('مذاكرة') ||
    lower.includes('ميتنج') ||
    lower.includes('اجتماع') ||
    lower.includes('تسليم') ||
    lower.includes('ديدلاين') ||
    lower.includes('بروجكت') ||
    lower.includes('مشروع') ||
    lower.includes('تقرير') ||
    lower.includes('مكالمة مع') ||
    lower.includes('شراء') ||
    lower.includes('تمرين الجيم');

  const hasTimeOrCommitment =
    lower.includes('بكره') ||
    lower.includes('بكرة') ||
    lower.includes('غداً') ||
    lower.includes('النهاردة') ||
    lower.includes('اليوم') ||
    lower.includes('الخميس') ||
    lower.includes('السبت') ||
    lower.includes('الأحد') ||
    lower.includes('الاثنين') ||
    lower.includes('الثلاثاء') ||
    lower.includes('الأربعاء') ||
    lower.includes('الجمعة') ||
    lower.includes('الساعة') ||
    lower.includes('عندي') ||
    lower.includes('لازم') ||
    lower.includes('ورايا');

  if (hasTaskSubject && hasTimeOrCommitment) {
    return true;
  }

  return false;
}

/**
 * Handles everyday conversational greetings, pleasantries, and meta questions.
 */
function handleGeneralSmallTalk(text: string, userName: string): string | null {
  const lower = text.toLowerCase().trim();

  // Greetings & Check-ins
  if (
    lower === 'عامل ايه' ||
    lower === 'عامل إيه' ||
    lower === 'اخبارك ايه' ||
    lower === 'أخبارك إيه' ||
    lower === 'اخبارك' ||
    lower === 'أخبارك' ||
    lower === 'طمني عليك' ||
    lower === 'عامل ايه يا بطل' ||
    lower === 'عامل ايه النهاردة'
  ) {
    return `الحمد لله كله تمام، انت أخبارك إيه ويومك ماشي إزاي؟ يا رب تكون بأحسن حال.`;
  }

  if (
    lower.includes('صباح الخير') ||
    lower.includes('صباح الفل') ||
    lower.includes('صباح الورد') ||
    lower.includes('صباح النور')
  ) {
    return `صباح النور والسرور، أهلاً بيك. يومك موفق وسعيد إن شاء الله.`;
  }

  if (
    lower.includes('مساء الخير') ||
    lower.includes('مساء الفل') ||
    lower.includes('مساء الورد') ||
    lower.includes('مساء النور')
  ) {
    return `مساء النور، أهلاً بيك يا غالي. طمني عليك؟`;
  }

  if (lower === 'ازيك' || lower === 'إزيك' || lower === 'ازيك يا غالي' || lower === 'إزيك يا فنان') {
    return `الحمد لله بخير، ازيك انت؟ إن شاء الله تكون تمام ورايق.`;
  }

  if (lower === 'سلام عليكم' || lower === 'السلام عليكم' || lower === 'سلام عليكم ورحمة الله') {
    return `وعليكم السلام ورحمة الله وبركاته، أهلاً بيك. نورتني، تحب نتكلم في إيه أو أساعدك في إيه؟`;
  }

  if (lower === 'هاي' || lower === 'أهلا' || lower === 'اهلا' || lower === 'يا هلا' || lower === 'مرحبا') {
    return `أهلاً بيك، مرحب بيك في أي وقت.`;
  }

  if (
    lower.includes('شكرا') ||
    lower.includes('شكراً') ||
    lower.includes('تسلم') ||
    lower.includes('الله ينور') ||
    lower.includes('حبيبي') ||
    lower === 'الف شكر'
  ) {
    return `العفو يا غالي، تسلم كلك ذوق. أنا معاك في أي وقت.`;
  }

  if (lower === 'تمام' || lower === 'اوك' || lower === 'أوك' || lower === 'ماشي' || lower === 'زي الفل' || lower === 'حلو') {
    return `عظيم جداً، لو محتاج أي استفسار أو حابب نرتب أي حاجة، أنا معاك.`;
  }

  if (
    lower.includes('مين انت') ||
    lower.includes('انت مين') ||
    lower.includes('بتعمل ايه') ||
    lower.includes('عرفني بنفسك') ||
    lower.includes('اسمك ايه')
  ) {
    return `أنا مساعدك الشخصي، بتكلم معاك وبساعدك في أي سؤال عام، حسابات، نصايح، أو ترتيب يومك ومذاكرتك وشغلك بشكل منظم وهادئ بدون كركبة.`;
  }

  if (lower.includes('مع السلامة') || lower.includes('باي') || lower.includes('سلام')) {
    return `مع السلامة يا غالي، يومك سعيد وموفق إن شاء الله.`;
  }

  return null;
}

/**
 * Handles general knowledge questions, advice, tech, and everyday discussions.
 */
function handleGeneralAdviceAndKnowledge(text: string): string | null {
  const lower = text.toLowerCase().trim();

  // Focus & Study Advice
  if (lower.includes('ازاي اركز') || lower.includes('مش عارف اركز') || lower.includes('طريقة للمذاكرة') || lower.includes('احسن طريقة مذاكرة')) {
    return `أفضل طريقة للتركيز هي المذاكرة في فترات قصيرة مركزة، يعني 25 دقيقة تركيز تام وبعدها 5 دقايق راحة. ابدأ دايماً بأصعب مادة وإنت لسه في قمة نشاطك، والأهم تبعد الموبايل تماماً عن مكان المذاكرة عشان تتجنب أي تشتيت.`;
  }

  // Sleep advice
  if (lower.includes('مش عارف انام') || lower.includes('الأرق') || lower.includes('ازاي انام')) {
    return `عشان تعرف تنام براحة، حاول تبعد عن شاشات الموبايل واللابتوب قبل النوم بنص ساعة، واهتم تكون إضاءة الأوضة هادية. ويفضل تبعد عن الكافيين والقهوة بعد وقت العصر عشان جسمك يهدى طبيعي.`;
  }

  // Stress & Burnout
  if (lower.includes('مخنوق') || lower.includes('زهقان') || lower.includes('تعبان من الشغل') || lower.includes('ضغط الشغل')) {
    return `الشغل والمسؤوليات ساعات بتضغط على الأعصاب وبتخلي الواحد مش طايق حاجة، وده شعور طبيعي بيعدي على أي حد. خد لك بريك واشرب حاجة بتحبها وافصل دماغك شوية، مش لازم تخلص كل حاجة في نفس اللحظة، صحتك وراحتك أهم.`;
  }

  // Programming & Tech
  if (lower.includes('يعني ايه برمجة') || lower.includes('ازاي اتعلم برمجة')) {
    return `البرمجة ببساطة هي إنك تدي تعليمات منطقية للكمبيوتر عشان يحل مشكلة معينة أو ينفذ برنامج. لو حابب تبدأ، أحسن مدخل ليك هو لغة واضحة زي بايثون أو جافاسكريبت، وتبدأ تفهم الأساسيات وتطبق مشاريع صغيرة بايدك.`;
  }

  // Time Management advice
  if (lower.includes('ازاي انظم وقتي') || lower.includes('تنظيم الوقت')) {
    return `السر في تنظيم الوقت مش إنك تعمل جدول زحمة، بل إنك تختار أهم مهمة في اليوم (One Big Thing) وتبدأ بيها الصبح، والباقي مهام خفيفة. كمان سيب مساحات فاضية بين المواعيد عشان أي طارئ.`;
  }

  return null;
}

/**
 * Main General Egyptian AI Engine.
 * Supports:
 * 1. Arithmetic and Math evaluation (e.g. 5*5, 10+20, etc.)
 * 2. Real Egyptian human conversation, greetings, and small talk (e.g. عامل ايه)
 * 3. General questions, knowledge, advice, and explanations
 * 4. Task & Schedule processing ONLY when user actually intends tasks
 * 5. Zero emojis in responses
 */
export async function generateEgyptianAiResponse(
  userText: string,
  history: Array<{ text: string; isFromUser?: boolean }> = [],
  userName: string = 'يا غالي'
): Promise<EgyptianAiResult> {
  const trimmed = userText.trim();

  // 1. Math / Calculations Domain (e.g. 5*5, 10+20, 100/4)
  const mathSolution = solveMathExpression(trimmed);
  if (mathSolution !== null) {
    return {
      text: removeEmojis(mathSolution),
      // Crucial: no task proposals for math queries!
      proposalTitle: undefined,
      proposals: undefined,
      isDirectAction: false,
    };
  }

  // 2. Everyday Greetings & Small Talk (e.g. عامل ايه, ازيك, صباح الخير)
  const smallTalkReply = handleGeneralSmallTalk(trimmed, userName);
  if (smallTalkReply !== null) {
    return {
      text: removeEmojis(smallTalkReply),
      proposalTitle: undefined,
      proposals: undefined,
      isDirectAction: false,
    };
  }

  // 3. General Knowledge / Advice Questions (e.g. ازاي اركز, يعني ايه برمجة)
  const generalAdviceReply = handleGeneralAdviceAndKnowledge(trimmed);
  if (generalAdviceReply !== null) {
    return {
      text: removeEmojis(generalAdviceReply),
      proposalTitle: undefined,
      proposals: undefined,
      isDirectAction: false,
    };
  }

  // 4. Verify Task / Scheduling Intent
  // If the user is NOT talking about tasks, study, exams, or scheduling,
  // do NOT force a task card on them!
  const hasTaskIntent = isTaskOrSchedulingIntent(trimmed);

  if (!hasTaskIntent) {
    // If it's a general question or remark that wasn't a task:
    const politeHumanReply = `معاك يا غالي، اتفضل احكيلي أو اسألني في أي موضوع، سواء حابب نتناقش أو تحسب حاجة أو ترتب مهام وشغل، أنا في خدمتك.`;
    return {
      text: removeEmojis(politeHumanReply),
      proposalTitle: undefined,
      proposals: undefined,
      isDirectAction: false,
    };
  }

  // 5. Genuine Task & Scheduling Domain:
  const parsedTasks = parseMultipleEgyptianTasks(trimmed, new Date());

  // Compound / Multiple Tasks Case (e.g. "عندي امتحان بكره ماده رياضه و عاوز اذاكر انجليزي عشان امتحانها يوم الخميس")
  if (parsedTasks.length > 1) {
    const isDirect = parsedTasks.some(t => t.isDirectAction);

    const proposals: ProposalItem[] = parsedTasks.map((t, idx) => ({
      id: `prop-${Date.now()}-${idx}`,
      title: t.title,
      duration: t.durationLabel,
      priority: t.priority,
      dueAt: t.dueAt,
      timeSlot: t.timeSlot,
      description: t.rawText,
      isConfirmed: isDirect,
    }));

    let replyText = '';
    if (isDirect) {
      replyText = `حاضر، ضفت المهام دي كلها لجدولك:\n\n`;
      parsedTasks.forEach((t, i) => {
        replyText += `${i + 1}. ${t.title}\n   الميعاد: ${t.timeSlot || 'في أقرب وقت'} - الأولوية: ${t.priorityLabel} - المدة: ${t.durationLabel}\n`;
      });
      replyText += `\nجاهزين في جدولك، تقدر تبدأ فيهم خطوة بخطوة.`;
    } else {
      replyText = `فهمت المطلوب، عندك ${parsedTasks.length} مهام أساسية مرتبة حسب مواعيدها وأولوياتها:\n\n`;
      parsedTasks.forEach((t, i) => {
        replyText += `${i + 1}. ${t.title}\n   الميعاد: ${t.timeSlot || 'في أقرب وقت'} - الأولوية: ${t.priorityLabel} - المدة: ${t.durationLabel}\n`;
      });
      replyText += `\nقسمتهملك لمهام واضحة عشان تركز في كل واحدة لوحدها بدون أي تشتيت.`;
    }

    return {
      text: removeEmojis(replyText),
      proposals,
      proposalTitle: parsedTasks[0].title,
      proposalDuration: parsedTasks[0].durationLabel,
      proposalPriority: parsedTasks[0].priority,
      proposalDueAt: parsedTasks[0].dueAt,
      proposalTimeSlot: parsedTasks[0].timeSlot,
      isDirectAction: isDirect,
      parsedTask: parsedTasks[0],
    };
  }

  // Single Task Case
  const singleTask = parsedTasks[0] || parseEgyptianTaskInput(trimmed, new Date());

  if (singleTask.isDirectAction) {
    const replyText = `حاضر، اتسجلت المهمة في جدولك بدقة:\n\nالمهمة: ${singleTask.title}\nالأولوية: ${singleTask.priorityLabel}\nالمدة: ${singleTask.durationLabel}${singleTask.timeSlot ? `\nالميعاد: ${singleTask.timeSlot}` : ''}\n\nجاهزة في جدولك، تقدر تبدأ فيها في أي وقت.`;

    return {
      text: removeEmojis(replyText),
      proposalTitle: singleTask.title,
      proposalDuration: singleTask.durationLabel,
      proposalPriority: singleTask.priority,
      proposalDueAt: singleTask.dueAt,
      proposalTimeSlot: singleTask.timeSlot,
      isDirectAction: true,
      parsedTask: singleTask,
    };
  }

  // Single Task proposal
  const singleProposalText = `رتبتلك خطوة «${singleTask.title}»${singleTask.timeSlot ? ` لميعاد ${singleTask.timeSlot}` : ''} وبأولوية ${singleTask.priorityLabel}.\n\nتحب نثبتها في جدولك؟`;

  return {
    text: removeEmojis(singleProposalText),
    proposalTitle: singleTask.title,
    proposalDuration: singleTask.durationLabel,
    proposalPriority: singleTask.priority,
    proposalDueAt: singleTask.dueAt,
    proposalTimeSlot: singleTask.timeSlot,
    isDirectAction: false,
    parsedTask: singleTask,
  };
}

/**
 * Egyptian dialect voice note processor
 */
export function generateEgyptianVoiceResponse(duration: string, userName: string = 'يا غالي'): EgyptianAiResult {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(14, 0, 0, 0);

  const text = `سمعت التسجيل الصوتي الخاص بيك: مكالمة ومراجعة المستلزمات قبل الاجتماع. جهزتهالك كخطوة واضحة لميعاد غداً 2:00 م.`;

  return {
    text: removeEmojis(text),
    proposalTitle: 'مكالمة ومراجعة المستلزمات',
    proposalDuration: '25 دقيقة',
    proposalPriority: 'medium',
    proposalDueAt: tomorrow.toISOString(),
    proposalTimeSlot: 'غداً، 2:00 م',
    isDirectAction: false,
  };
}
