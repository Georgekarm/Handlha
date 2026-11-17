package com.handelha.app.domain

enum class StudentQuoteCategory(
    val id: String,
    val labelAr: String,
    val labelEn: String,
) {
    ALL("all", "الكل", "All"),
    BOOKS_SCIENCE("books_science", "كتب وأبحاث علمية", "Books & Science"),
    START_NOW("start_now", "قوة البداية", "Starting Power"),
    EXAM_DAYS("exam_days", "ليالي الامتحانات", "Exam Season"),
    LOW_ENERGY("low_energy", "لما الطاقة تقل", "Low Energy"),
    DREAM_GOAL("dream_goal", "حلمك والنتيجة", "Goals & Growth"),
    CALM_WISDOM("calm_wisdom", "روقان المذاكرة", "Calm Focus"),
    CUSTOM("custom", "كلماتك الخاصة", "My Quotes"),
    ;

    fun label(isEnglish: Boolean): String = if (isEnglish) labelEn else labelAr

    companion object {
        fun fromId(id: String?): StudentQuoteCategory =
            entries.firstOrNull { it.id == id } ?: BOOKS_SCIENCE
    }
}

enum class StudentStudyMood(
    val id: String,
    val labelAr: String,
    val labelEn: String,
    val badgeAr: String,
    val badgeEn: String,
    val recommendedCategory: StudentQuoteCategory,
) {
    STEADY_DAILY(
        id = "steady_daily",
        labelAr = "مذاكرة يومية هادية",
        labelEn = "Calm Daily Study",
        badgeAr = "تراكم بسيط ومستمر كل يوم",
        badgeEn = "Steady step-by-step daily progress",
        recommendedCategory = StudentQuoteCategory.BOOKS_SCIENCE,
    ),
    CATCHING_UP(
        id = "catching_up",
        labelAr = "لمّ المتراكم",
        labelEn = "Catching Up",
        badgeAr = "تقسيم التراكمات لخطوات صغيرة",
        badgeEn = "Breaking backlog into small steps",
        recommendedCategory = StudentQuoteCategory.START_NOW,
    ),
    EXAM_PREP(
        id = "exam_prep",
        labelAr = "مراجعة وامتحانات",
        labelEn = "Exam Revision",
        badgeAr = "تركيز هادي واسترجاع نشط للمنهج",
        badgeEn = "Calm focus and active recall",
        recommendedCategory = StudentQuoteCategory.EXAM_DAYS,
    ),
    LOW_BATTERY(
        id = "low_battery",
        labelAr = "طاقة هادية",
        labelEn = "Low Energy",
        badgeAr = "خطوات خفيفة على قد طاقتك الحالية",
        badgeEn = "Light steps matched to your energy",
        recommendedCategory = StudentQuoteCategory.LOW_ENERGY,
    ),
    BIG_PROJECT(
        id = "big_project",
        labelAr = "مشروع تخرج أو هدف كبير",
        labelEn = "Thesis & Big Goal",
        badgeAr = "إنجاز عميق خطوة ورا خطوة",
        badgeEn = "Deep work one milestone at a time",
        recommendedCategory = StudentQuoteCategory.DREAM_GOAL,
    ),
    ;

    fun label(isEnglish: Boolean): String = if (isEnglish) labelEn else labelAr
    fun badge(isEnglish: Boolean): String = if (isEnglish) badgeEn else badgeAr

    companion object {
        fun fromId(id: String?): StudentStudyMood =
            entries.firstOrNull { it.id == id } ?: STEADY_DAILY
    }
}

data class StudentQuoteItem(
    val id: String,
    val textAr: String,
    val textEn: String,
    val tagAr: String,
    val tagEn: String,
    val category: StudentQuoteCategory,
    val sourceAr: String? = null,
    val sourceEn: String? = null,
    val isCustom: Boolean = false,
) {
    fun text(isEnglish: Boolean): String = if (isEnglish) textEn else textAr
    fun tag(isEnglish: Boolean): String = if (isEnglish) tagEn else tagAr
    fun source(isEnglish: Boolean): String? = if (isEnglish) sourceEn else sourceAr
}

data class StudentQuickBoost(
    val id: String,
    val feelingTitleAr: String,
    val feelingTitleEn: String,
    val responseTitleAr: String,
    val responseTitleEn: String,
    val responseBodyAr: String,
    val responseBodyEn: String,
    val microStepAr: String,
    val microStepEn: String,
    val suggestedFocusMinutes: Int,
) {
    fun feelingTitle(isEnglish: Boolean): String = if (isEnglish) feelingTitleEn else feelingTitleAr
    fun responseTitle(isEnglish: Boolean): String = if (isEnglish) responseTitleEn else responseTitleAr
    fun responseBody(isEnglish: Boolean): String = if (isEnglish) responseBodyEn else responseBodyAr
    fun microStep(isEnglish: Boolean): String = if (isEnglish) microStepEn else microStepAr
}

data class StudentMotivationState(
    val currentQuoteId: String = "sci_1",
    val selectedMood: StudentStudyMood = StudentStudyMood.STEADY_DAILY,
    val personalMotto: String = "",
    val pinnedQuoteId: String? = null,
    val favoriteQuoteIds: Set<String> = emptySet(),
    val customQuotes: List<StudentQuoteItem> = emptyList(),
) {
    fun allQuotes(): List<StudentQuoteItem> = customQuotes + StudentQuotesCatalog.builtInQuotes

    fun activeWidgetQuote(): StudentQuoteItem {
        val all = allQuotes()
        if (pinnedQuoteId != null) {
            all.firstOrNull { it.id == pinnedQuoteId }?.let { return it }
        }
        return all.firstOrNull { it.id == currentQuoteId } ?: all.first()
    }
}

object StudentQuotesCatalog {

    val quickBoosts: List<StudentQuickBoost> = listOf(
        StudentQuickBoost(
            id = "boost_backlog",
            feelingTitleAr = "الكمية كبيرة ومتراكمة عليا",
            feelingTitleEn = "Overwhelmed by a large study backlog",
            responseTitleAr = "المتراكم بيتفك بجزء واحد صغير دلوقتي، مش بالمنهج كله",
            responseTitleEn = "Backlog is cleared one small unit at a time, not all at once",
            responseBodyAr = "علم النفس المعرفي بيسمي الشعور ده «الحمل المعرفي الزائد». لما بتبص على المنهج كله مرة واحدة، المخ بيتجمد. الحل العلمي البسيط هو عزل محاضرة واحدة أو ١٠ صفحات فقط والبدء فيها فورًا.",
            responseBodyEn = "Cognitive psychology calls this 'Cognitive Overload'. Viewing the entire syllabus at once triggers mental freeze. Isolate a single lecture or 10 pages and start only there.",
            microStepAr = "افتح أصغر درس متراكم وابدأ جلسة تركيز ١٥ دقيقة بدون التفكير في الباقي.",
            microStepEn = "Open the smallest pending lesson and start a 15-minute focus block.",
            suggestedFocusMinutes = 15,
        ),
        StudentQuickBoost(
            id = "boost_exam_fear",
            feelingTitleAr = "متوتر وقلقان من الامتحان",
            feelingTitleEn = "Anxious about an upcoming exam",
            responseTitleAr = "الفعل الهادي والاسترجاع النشط هما أسرع علاج للتوتر",
            responseTitleEn = "Calm action and active recall are the fastest antidotes to anxiety",
            responseBodyAr = "وفقًا لقانون «يركس-دودسون» في علم النفس، التوتر البسيط طبيعي، لكن القلق الزائد بيقلل كفاءة الذاكرة العاملة. تحويل انتباهك من التفكير في النتيجة إلى حل سؤال واحد عملي بيهدّي الجهاز العصبي فورًا.",
            responseBodyEn = "According to the Yerkes-Dodson law, shifting your attention from worrying about outcomes to solving a single concrete problem immediately calms the nervous system.",
            microStepAr = "حلّ ٥ أسئلة سابقة أو راجع ملخص فصل واحد في جلسة ٢٥ دقيقة.",
            microStepEn = "Solve 5 past-paper questions or review one chapter summary in 25 minutes.",
            suggestedFocusMinutes = 25,
        ),
        StudentQuickBoost(
            id = "boost_procrastination",
            feelingTitleAr = "مكسّل ومش قادر أبدأ مذاكرة",
            feelingTitleEn = "Procrastinating and struggling to start",
            responseTitleAr = "الحافز بييجي بعد البداية بـ ٥ دقايق، مش قبلها",
            responseTitleEn = "Motivation arrives 5 minutes after you start, not before",
            responseBodyAr = "دراسات التصوير العصبي للدماغ أثبتت إن التفكير في مهمة تقيلة بينشّط مركز الضيق في المخ، لكن أول ما تبدأ فعليًا لمدة ٥ دقائق، الشعور ده بيختفي وبيشتغل «تأثير زيجارنيك» اللي بيخليك تحب تكمّل.",
            responseBodyEn = "Neuroimaging studies show that anticipating a hard task activates the brain's discomfort center, but within 5 minutes of starting, the discomfort fades and momentum takes over.",
            microStepAr = "طبّق قاعدة الدقيقتين: افتح الكتاب واقرأ أول فقرتين في جلسة ١٥ دقيقة.",
            microStepEn = "Apply the 2-Minute Rule: open your material and read the first two paragraphs in a 15m block.",
            suggestedFocusMinutes = 15,
        ),
        StudentQuickBoost(
            id = "boost_forgetting",
            feelingTitleAr = "ذاكرت كتير وحاسس إني ناسي",
            feelingTitleEn = "Studied hard but feel like I forgot everything",
            responseTitleAr = "المعلومة متخزنة في دماغك، ومحتاجة استرجاع مش قراءة سلبية",
            responseTitleEn = "The knowledge is stored — it needs retrieval practice, not passive rereading",
            responseBodyAr = "في كتاب «Make It Stick»، الباحثون أثبتوا إن إحساس الصعوبة وقت استدعاء المعلومة هو نفسه اللي بيثبتها في الذاكرة طويلة المدى. أول ما تبدأ تكتب النقاط الرئيسية من ذاكرتك، الخيوط كلها هترجع تتربط.",
            responseBodyEn = "Research in 'Make It Stick' proves that the mental effort of retrieving knowledge is what cements it into long-term memory. Prompting yourself with key headings restores recall.",
            microStepAr = "اقفل الكتاب واكتب في ورقة ٣ أفكار أساسية فاكرهم في جلسة ٢٠ دقيقة.",
            microStepEn = "Close the book and write down 3 core ideas from memory in a 20-minute session.",
            suggestedFocusMinutes = 20,
        ),
    )

    val builtInQuotes: List<StudentQuoteItem> = listOf(
        // ==================== BOOKS & SCIENTIFIC ARTICLES (كتب وأبحاث علمية) ====================
        StudentQuoteItem(
            id = "sci_1",
            textAr = "إنت مش بترتقي لمستوى أهدافك، إنت بتنزل لمستوى عاداتك ونظامك اليومي. ركّز على جلسة مذاكرتك النهارده والنتيجة هتيجي لوحدها.",
            textEn = "You do not rise to the level of your goals. You fall to the level of your systems. Focus on today's study block and the grade will take care of itself.",
            tagAr = "بناء العادات",
            tagEn = "Habit Systems",
            sourceAr = "كتاب العادات الذرية — جيمس كلير",
            sourceEn = "Atomic Habits — James Clear",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_2",
            textAr = "جودة مذاكرتك وإنتاجك بتساوي: (الوقت اللي بتقضيه) × (شدة تركيزك من غير تشتيت). ساعة واحدة بتركيز عميق أفضل من ٤ ساعات جنب الموبايل.",
            textEn = "High-Quality Work Produced = (Time Spent) × (Intensity of Focus). One hour of deep, uninterrupted study beats four hours of distracted reading.",
            tagAr = "التركيز العميق",
            tagEn = "Deep Work",
            sourceAr = "كتاب العمل العميق — د. كال نيوبورت",
            sourceEn = "Deep Work — Cal Newport",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_3",
            textAr = "اختبار نفسك في اللي ذاكرته (الاسترجاع النشط) بيثبّت المعلومة في الذاكرة بنسبة ٥٠٪ أكتر من إعادة قراءة الدرس ٤ مرات ورا بعض.",
            textEn = "Testing yourself through active retrieval cements knowledge 50% more effectively after a week than rereading the same chapter four times.",
            tagAr = "علم الذاكرة",
            tagEn = "Memory Science",
            sourceAr = "دراسة روديجر وكاربيك — مجلة Psychological Science",
            sourceEn = "Roediger & Karpicke (2006) — Psychological Science",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_4",
            textAr = "لما بتفكر في مذاكرة مادة تقيلة، مركز الألم في الدماغ بيشتغل، لكن الأبحاث أثبتت إن الشعور ده بيختفي بعد ٣ لـ ٥ دقايق بس من البداية الفعلية.",
            textEn = "Merely anticipating a hard study task activates the brain's insular cortex (pain center), yet neuroimaging shows this discomfort vanishes within 3 to 5 minutes of starting.",
            tagAr = "علم الأعصاب",
            tagEn = "Neuroscience",
            sourceAr = "كتاب عقل للأرقام — د. باربارا أوكلي",
            sourceEn = "A Mind for Numbers — Dr. Barbara Oakley",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_5",
            textAr = "تأثير زيجارنيك في علم النفس بيقول إن الدماغ البشري بيفضل مشغول بالمهمة اللي بدأها لحد ما يخلصها؛ عشان كده مجرد فتح الكتاب هو نص الإنجاز.",
            textEn = "The Zeigarnik Effect shows that the human brain naturally stays engaged with a task once initiated; simply opening the book is half the battle.",
            tagAr = "علم النفس المعرفي",
            tagEn = "Cognitive Psychology",
            sourceAr = "أبحاث بلوما زيجارنيك — علم النفس المعرفي",
            sourceEn = "Bluma Zeigarnik — Cognitive Psychology Research",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_6",
            textAr = "التعلم اللي تحس إنه محتاج مجهود ذهني بسيط (استدعاء، حل أسئلة، تلخيص غيبي) هو اللي بيبني روابط عصبية قوية وبيعيش معاك لليلة الامتحان.",
            textEn = "Learning that feels slightly effortful—self-quizzing, summarizing from memory, solving problems—builds stronger neural pathways that last through exam day.",
            tagAr = "التعلم الفعّال",
            tagEn = "Effective Learning",
            sourceAr = "كتاب اجعلها تثبت (Make It Stick) — براون وروديجر",
            sourceEn = "Make It Stick: The Science of Successful Learning",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_7",
            textAr = "أي عادة كبيرة أو فصل طويل، صغّره لحد ما يبقى مستغرق دقيقتين بس في بدايته: «افتح الكشكول واكتب العنوان». البداية الصغيرة بتغلب أي مقاومة.",
            textEn = "Scale any big study session down to a Two-Minute gateway: 'Open the notebook and write the heading.' Small starts bypass mental resistance.",
            tagAr = "قاعدة الدقيقتين",
            tagEn = "Two-Minute Rule",
            sourceAr = "كتاب العادات الذرية — جيمس كلير",
            sourceEn = "Atomic Habits — James Clear",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_8",
            textAr = "دماغك بيشتغل بنمطين: «التركيز المباشر» وقت المذاكرة، و«النمط المنتشر» وقت الراحة؛ عشان كده البريك الهادي جزء علمي من فهم المسائل الصعبة.",
            textEn = "Your brain alternates between Focused Mode and Diffused Mode; taking a calm break after a study block lets your subconscious connect complex ideas.",
            tagAr = "أنماط التفكير",
            tagEn = "Thinking Modes",
            sourceAr = "كتاب تعلم كيف تتعلم — د. باربارا أوكلي وتيرينس سيجنوفسكي",
            sourceEn = "Learning How to Learn — Oakley & Sejnowski",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_9",
            textAr = "النوم الكافي بعد المذاكرة مش رفاهية؛ أثناء النوم العميق يقوم الدماغ بنقل المعلومات من الذاكرة المؤقتة (الحُصين) إلى القشرة الدماغية الدائمة.",
            textEn = "Sleep after studying is not a luxury; during deep sleep, the brain consolidates new knowledge from temporary hippocampal storage into permanent cortex memory.",
            tagAr = "النوم والذاكرة",
            tagEn = "Sleep & Memory",
            sourceAr = "كتاب لماذا ننام — د. ماثيو ووكر (جامعة بيركلي)",
            sourceEn = "Why We Sleep — Dr. Matthew Walker (Nature Reviews Neuroscience)",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_10",
            textAr = "عقلية النمو معناها إنك لما تغلط في سؤال أو تلاقي فصل صعب، تقول «لسه بتعلمه» بدل «أنا مش شاطر فيه». المخ بيتطور بالتدريب زي العضلة.",
            textEn = "A Growth Mindset means replacing 'I'm not good at this subject' with 'I haven't mastered it yet.' Neural circuits strengthen through deliberate effort.",
            tagAr = "عقلية النمو",
            tagEn = "Growth Mindset",
            sourceAr = "كتاب عقلية النمو (Mindset) — د. كارول دويك (جامعة ستانفورد)",
            sourceEn = "Mindset: The New Psychology of Success — Dr. Carol Dweck",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_11",
            textAr = "الاستمرارية الهادية على مدار الأسابيع بتغلب الموهبة والحماس المؤقت. الناجحون بيتميزوا بالمثابرة اليومية البسيطة مش بالسهر العشوائي.",
            textEn = "Consistency of effort over time outperforms short bursts of intensity. True grit is showing up calmly for your daily step.",
            tagAr = "قوة المثابرة",
            tagEn = "Power of Grit",
            sourceAr = "كتاب المثابرة (Grit) — د. أنجيلا داكورث",
            sourceEn = "Grit: The Power of Passion and Perseverance — Angela Duckworth",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_12",
            textAr = "التكرار المتباعد (مراجعة الدرس بعد يوم، ثم ٣ أيام، ثم أسبوع) بيكسر «منحنى النسيان» وبيخليك تدخل الامتحان والمعلومة حاضرة من غير سهر.",
            textEn = "Spaced repetition—reviewing material after 1 day, 3 days, and 7 days—flattens Ebbinghaus's Forgetting Curve and eliminates last-minute cramming.",
            tagAr = "التكرار المتباعد",
            tagEn = "Spaced Repetition",
            sourceAr = "أبحاث هيرمان إبنغهاوس ومجلة Psychological Bulletin",
            sourceEn = "Ebbinghaus Forgetting Curve — Psychological Bulletin",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_13",
            textAr = "كل مرة بتبص فيها في الموبايل وسط المذاكرة، جزء من انتباهك بيفضل عالق هناك لمدة ١٥ دقيقة. وهو ما تسميه الأبحاث «بقايا الانتباه».",
            textEn = "Every quick glance at your phone leaves 'Attention Residue' that reduces cognitive performance for up to 15 minutes afterward.",
            tagAr = "حماية الانتباه",
            tagEn = "Attention Hygiene",
            sourceAr = "ورقة بحثية — د. صوفي ليروي (جامعة مينيسوتا)",
            sourceEn = "Dr. Sophie Leroy — Attention Residue Research",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_14",
            textAr = "اسأل نفسك قبل كل جلسة: «إيه هي المهمة الواحدة اللي لو خلصتها النهارده هتخلي باقي مهامي أسهل أو غير ضرورية؟» وابدأ بيها.",
            textEn = "Ask yourself before each study block: 'What is the ONE thing I can complete right now such that by doing it, everything else becomes easier?'",
            tagAr = "فقه الأولويات",
            tagEn = "Priority Focus",
            sourceAr = "كتاب الشيء الوحيد (The One Thing) — غاري كيلر",
            sourceEn = "The One Thing — Gary Keller",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_15",
            textAr = "حالة «التدفق الذهني» بتحصل لما تقسم هدفك لخطوة واضحة قدامك وتحددلها وقت محدد، فيندمج تركيزك تمامًا ويختفي الملل والقلق.",
            textEn = "Mental 'Flow' occurs when you pair a clear, bite-sized objective with a bounded timer—boredom and anxiety give way to effortless immersion.",
            tagAr = "التدفق الذهني",
            tagEn = "Flow State",
            sourceAr = "كتاب التدفق (Flow) — د. ميهالي تشيكسنتميهالي",
            sourceEn = "Flow: The Psychology of Optimal Experience — Mihaly Csikszentmihalyi",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),
        StudentQuoteItem(
            id = "sci_16",
            textAr = "أبحاث «التدريب المتعمد» أثبتت إن أقصى قدرة للدماغ على التحصيل المركّز بتكون في جلسات من ٢٥ إلى ٥٠ دقيقة يتبعها فاصل قصير لتجديد الطاقة.",
            textEn = "Deliberate practice studies show that the human brain sustains peak analytical learning in 25–50 minute blocks followed by brief restorative pauses.",
            tagAr = "التدريب المتعمد",
            tagEn = "Deliberate Practice",
            sourceAr = "كتاب القمة (Peak) — د. أندرس إريكسون",
            sourceEn = "Peak: Secrets from the New Science of Expertise — Anders Ericsson",
            category = StudentQuoteCategory.BOOKS_SCIENCE,
        ),

        // ==================== START_NOW (قوة البداية وكسر التسويف) ====================
        StudentQuoteItem(
            id = "sq_1",
            textAr = "أصعب صفحة في المنهج كله هي أول صفحة.. افتحها بس وسيب الباقي يمشي خطوة خطوة.",
            textEn = "The hardest page in the entire syllabus is the very first one. Just open it and let the rest flow step by step.",
            tagAr = "قاعدة البداية",
            tagEn = "Starting Rule",
            category = StudentQuoteCategory.START_NOW,
        ),
        StudentQuoteItem(
            id = "sq_2",
            textAr = "مش لازم تستنى المزاج يظبط عشان تذاكر؛ ابدأ بـ ١٥ دقيقة والمزاج هييجي وراك لوحده.",
            textEn = "Don't wait for the perfect mood to study; start with 15 minutes and momentum will follow naturally.",
            tagAr = "كسر التسويف",
            tagEn = "Beat Procrastination",
            category = StudentQuoteCategory.START_NOW,
        ),
        StudentQuoteItem(
            id = "sq_3",
            textAr = "المتراكم مش وحش كبير، ده شوية دروس صغيرة محتاجة تتقسم على أيامك بهدوء.",
            textEn = "Your backlog isn't a monster; it's just small lessons waiting to be distributed calmly across your days.",
            tagAr = "فك التراكمات",
            tagEn = "Clear Backlog",
            category = StudentQuoteCategory.START_NOW,
        ),
        StudentQuoteItem(
            id = "sq_4",
            textAr = "ساعة تركيز واحدة النهارده أحسن من خطة مثالية لبكره لسه مبدأتش فيها.",
            textEn = "One focused hour today is worth more than a perfect plan for tomorrow that hasn't started yet.",
            tagAr = "خطوة عملية",
            tagEn = "Action First",
            category = StudentQuoteCategory.START_NOW,
        ),
        StudentQuoteItem(
            id = "sq_5",
            textAr = "قانون الـ ٥ دقايق: اتفق مع نفسك تذاكر ٥ دقايق بس، وأول ما تبدأ عقلك هيكمّل لوحده.",
            textEn = "The 5-Minute Rule: promise yourself just five minutes of study—once you cross the starting line, your mind will want to continue.",
            tagAr = "حيلة ذكية",
            tagEn = "Smart Habit",
            category = StudentQuoteCategory.START_NOW,
        ),
        StudentQuoteItem(
            id = "sq_6",
            textAr = "متبصش على السلم كله فتتعب، بص على أول درجة بس واطلعها دلوقتي.",
            textEn = "Don't stare at the entire staircase; focus only on the very first step in front of you.",
            tagAr = "خطوة بخطوة",
            tagEn = "Step by Step",
            sourceAr = "مارتن لوثر كينغ",
            sourceEn = "Martin Luther King Jr.",
            category = StudentQuoteCategory.START_NOW,
        ),
        StudentQuoteItem(
            id = "sq_7",
            textAr = "اللي جاي أسهل أول ما تكسر رهبة البداية.. سمِّ الله وافتح أول عنوان.",
            textEn = "Everything gets easier the moment you break the fear of starting. Take a breath and open the first heading.",
            tagAr = "توكل وابدأ",
            tagEn = "Begin Calmly",
            category = StudentQuoteCategory.START_NOW,
        ),
        StudentQuoteItem(
            id = "sq_8",
            textAr = "سر التقدم هو إنك تبدأ، وسر البداية هو تقسيم المهام الكبيرة المعقدة لمهام صغيرة تقدر تنجزها فورًا.",
            textEn = "The secret of getting ahead is getting started. The secret of getting started is breaking complex tasks into small manageable ones.",
            tagAr = "حكمة عالمية",
            tagEn = "Classic Wisdom",
            sourceAr = "مارك توين",
            sourceEn = "Mark Twain",
            category = StudentQuoteCategory.START_NOW,
        ),

        // ==================== EXAM_DAYS (ليالي الامتحانات والمراجعة) ====================
        StudentQuoteItem(
            id = "sq_13",
            textAr = "ليلة الامتحان محتاجة هدوء أكتر ما محتاجة توتر.. اللي تراجعه بتركيز هيدخل معاك اللجنة ثابت.",
            textEn = "Exam night needs calm clarity more than panic. What you review with a steady mind stays with you in the exam hall.",
            tagAr = "ليلة الامتحان",
            tagEn = "Exam Night",
            category = StudentQuoteCategory.EXAM_DAYS,
        ),
        StudentQuoteItem(
            id = "sq_14",
            textAr = "كل سؤال بتحله في المراجعة دلوقتي بيشتريلك راحة وثقة جوه اللجنة بكره.",
            textEn = "Every practice question you solve right now buys you confidence and peace of mind in tomorrow's exam.",
            tagAr = "ثقة اللجنة",
            tagEn = "Exam Confidence",
            category = StudentQuoteCategory.EXAM_DAYS,
        ),
        StudentQuoteItem(
            id = "sq_15",
            textAr = "راجع العناوين الكبيرة والأسئلة المهمة الأول؛ الذكاء في الامتحانات إنك تضمن الأساسيات في جيبك.",
            textEn = "Secure the core concepts and high-yield questions first; smart exam prep is locking in the fundamentals.",
            tagAr = "مراجعة ذكية",
            tagEn = "Smart Revision",
            category = StudentQuoteCategory.EXAM_DAYS,
        ),
        StudentQuoteItem(
            id = "sq_16",
            textAr = "النجاح مش صدفة، ده مجموع الساعات الهادية اللي قضيتها وإنت بتحاول تفهم وتحل.",
            textEn = "Success is no accident; it is the sum of quiet hours spent understanding, practicing, and persevering.",
            tagAr = "حصاد المراجعة",
            tagEn = "Revision Harvest",
            sourceAr = "بيليه",
            sourceEn = "Pelé",
            category = StudentQuoteCategory.EXAM_DAYS,
        ),
        StudentQuoteItem(
            id = "sq_17",
            textAr = "تعب أسبوعين امتحانات ولا ندم ترم بحاله.. شد حيلك يا بطل خلاص هانت.",
            textEn = "Two weeks of focused exam effort is far lighter than a semester of regret. Stay steady—you're almost there.",
            tagAr = "معسكر الامتحانات",
            tagEn = "Finals Sprint",
            category = StudentQuoteCategory.EXAM_DAYS,
        ),
        StudentQuoteItem(
            id = "sq_18",
            textAr = "أفضل طريقة للتغلب على قلق الامتحان هي التحضير العملي: ورقة وقلم وحل بإيدك.",
            textEn = "Action is the foundational key to all success—the best cure for exam anxiety is pen, paper, and practice.",
            tagAr = "حل عملي",
            tagEn = "Active Practice",
            sourceAr = "بابلو بيكاسو",
            sourceEn = "Pablo Picasso",
            category = StudentQuoteCategory.EXAM_DAYS,
        ),

        // ==================== LOW_ENERGY (لما الطاقة تقل) ====================
        StudentQuoteItem(
            id = "sq_25",
            textAr = "لو طاقتك ٢٠٪ النهارده وذاكرت بيها، فإنت كده جبت ١٠٠٪ من اللي في إيدك.. عاش جدًا وماتقسيش على نفسك.",
            textEn = "If you only have 20% energy today and you give that 20%, you have given 100% of what you had. Be kind to yourself.",
            tagAr = "رفق بالنفس",
            tagEn = "Self-Compassion",
            category = StudentQuoteCategory.LOW_ENERGY,
        ),
        StudentQuoteItem(
            id = "sq_26",
            textAr = "عادي تحس إنك فصلت.. خد بريك هادي ١٠ دقايق، اشرب مية، وارجع لجزء صغير ومحدد.",
            textEn = "It's completely normal to feel drained. Take a 10-minute breather, hydrate, and return to just one small section.",
            tagAr = "تجديد الطاقة",
            tagEn = "Recharge",
            category = StudentQuoteCategory.LOW_ENERGY,
        ),
        StudentQuoteItem(
            id = "sq_27",
            textAr = "نص ساعة مذاكرة في يوم تقيل أحسن بكتير من يوم صفر.. الاستمرارية بتكسب حتى بأقل مجهود.",
            textEn = "Thirty minutes of study on a tough day beats a zero-day every time. Consistency wins even on low battery.",
            tagAr = "قوة الاستمرارية",
            tagEn = "Consistency Wins",
            category = StudentQuoteCategory.LOW_ENERGY,
        ),
        StudentQuoteItem(
            id = "sq_28",
            textAr = "لا يهم كم تسير ببطء طالما أنك لا تتوقف تمامًا.",
            textEn = "It does not matter how slowly you go as long as you do not stop.",
            tagAr = "استمر بهدوء",
            tagEn = "Steady Pace",
            sourceAr = "كونفوشيوس",
            sourceEn = "Confucius",
            category = StudentQuoteCategory.LOW_ENERGY,
        ),
        StudentQuoteItem(
            id = "sq_29",
            textAr = "لما تتعب، اتعلم ترتاح مش تستسلم.. الراحة جزء من الشغل الشاطر.",
            textEn = "If you get tired, learn to rest, not to quit. Intentional rest is part of smart studying.",
            tagAr = "راحة ذكية",
            tagEn = "Smart Rest",
            sourceAr = "بانكسي",
            sourceEn = "Banksy",
            category = StudentQuoteCategory.LOW_ENERGY,
        ),

        // ==================== DREAM_GOAL (حلمك والنتيجة) ====================
        StudentQuoteItem(
            id = "sq_36",
            textAr = "المستقبل بيتكون من اللي بتعمله النهارده، مش اللي بتأجله لبكره.",
            textEn = "The future depends on what you do today, not what you postpone for tomorrow.",
            tagAr = "صناعة المستقبل",
            tagEn = "Future Building",
            sourceAr = "المهاتما غاندي",
            sourceEn = "Mahatma Gandhi",
            category = StudentQuoteCategory.DREAM_GOAL,
        ),
        StudentQuoteItem(
            id = "sq_37",
            textAr = "النسخة منك اللي هتتخرج وتفرح بتقديرها فخورة بيك دلوقتي وإنت قاعد بتعافر في الدرس ده.",
            textEn = "Your future graduating self is proud of you right now for sitting down and working through this chapter.",
            tagAr = "نسختك الجاية",
            tagEn = "Future Self",
            category = StudentQuoteCategory.DREAM_GOAL,
        ),
        StudentQuoteItem(
            id = "sq_38",
            textAr = "التعليم والمهارة هما أقوى سلاح تقدر تغيّر بيه مستقبلك ومكانتك.",
            textEn = "Education is the most powerful weapon which you can use to change your future and the world.",
            tagAr = "قيمة العلم",
            tagEn = "Power of Knowledge",
            sourceAr = "نيلسون مانديلا",
            sourceEn = "Nelson Mandela",
            category = StudentQuoteCategory.DREAM_GOAL,
        ),
        StudentQuoteItem(
            id = "sq_39",
            textAr = "ربنا مبيضيّعش تعب حد سهِر وذاكر وعمل اللي عليه.. اطمّن، مجهودك متشال ليوم النتيجة.",
            textEn = "Sincere effort is never wasted. Trust the process—every hour of hard work is saved for results day.",
            tagAr = "يقين واطمئنان",
            tagEn = "Trust the Effort",
            category = StudentQuoteCategory.DREAM_GOAL,
        ),
        StudentQuoteItem(
            id = "sq_40",
            textAr = "نحن ما نفعله باستمرار؛ لذلك فإن التفوق ليس فعلًا عابرًا بل هو عادة يومية.",
            textEn = "We are what we repeatedly do. Excellence, then, is not an act, but a daily habit.",
            tagAr = "عادة التفوق",
            tagEn = "Habit of Excellence",
            sourceAr = "ويل ديورانت / أرسطو",
            sourceEn = "Will Durant / Aristotle",
            category = StudentQuoteCategory.DREAM_GOAL,
        ),

        // ==================== CALM_WISDOM (روقان المذاكرة) ====================
        StudentQuoteItem(
            id = "sq_47",
            textAr = "المذاكرة الهادية في ٢٥ دقيقة بتركيز كامل أحسن من ٤ ساعات قدام الكتاب وبالك مشغول.",
            textEn = "Twenty-five minutes of calm, undivided focus beats four hours of sitting in front of a book with a scattered mind.",
            tagAr = "تركيز صافي",
            tagEn = "Pure Focus",
            category = StudentQuoteCategory.CALM_WISDOM,
        ),
        StudentQuoteItem(
            id = "sq_48",
            textAr = "قارن نفسك بمبارح مش بزميلك.. كل طالب ليه سرعته وطريقته اللي بينجح بيها.",
            textEn = "Compare yourself to who you were yesterday, not to someone else today. Every student has their own winning pace.",
            tagAr = "رحلتك الخاصة",
            tagEn = "Your Own Pace",
            category = StudentQuoteCategory.CALM_WISDOM,
        ),
        StudentQuoteItem(
            id = "sq_49",
            textAr = "رتّب مكتبك، ابعد الموبايل، وخلي قدامك كتاب واحد بس.. البساطة بتجيب تركيز.",
            textEn = "Clear your desk, put the phone out of reach, and keep only one subject in front of you. Simplicity breeds focus.",
            tagAr = "بيئة المذاكرة",
            tagEn = "Study Environment",
            category = StudentQuoteCategory.CALM_WISDOM,
        ),
        StudentQuoteItem(
            id = "sq_50",
            textAr = "الهدوء قوة.. الطالب الهادي بيفتكر المعلومة أسرع وبيحل بذكاء أعلى.",
            textEn = "Calmness is a superpower. A quiet mind recalls faster and solves problems with far greater clarity.",
            tagAr = "قوة الهدوء",
            tagEn = "Calm Clarity",
            category = StudentQuoteCategory.CALM_WISDOM,
        ),
    )
}
