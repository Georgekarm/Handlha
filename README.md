<div align="center">

  <img src="assets/images/logo.png" alt="Handelha Logo" width="110" />

  <h1>هندلها | Handelha</h1>
  <p><b>رفيقك اليومي لتنظيم مهامك، دراستك، ومشروعاتك بهدوء ومن غير ضغط</b></p>
  <p><i>Your Calm Local-First Daily Companion for Tasks, Study & Personal Productivity on Android</i></p>

  <p>
    <img src="https://img.shields.io/badge/Platform-Android-2E6F5E?style=for-the-badge&logo=android&logoColor=white" alt="Android" />
    <img src="https://img.shields.io/badge/Storage-Local--First-1E2D2B?style=for-the-badge" alt="Local-First" />
    <img src="https://img.shields.io/badge/Language-العربية%20(المصرية)%20%7C%20English-D97757?style=for-the-badge" alt="Languages" />
  </p>

</div>

---

## 🌿 عن تطبيق «هندلها» | About Handelha

**هندلها (Handelha)** تطبيق موبايل Android مخصّص للإنتاجية الشخصية والمذاكرة اليومية؛ يساعدك تحوّل زحمة اليوم والالتزامات المكتوبة أو المنطوقة باللهجة المصرية إلى مهام وخطوات واضحة قابلة للتنفيذ.

> **نطاق التطبيق:** هندلها مصمّم للمهام الشخصية والدراسة والمشروعات الفردية (وليس لإدارة اللجان أو محاضر الاجتماعات الرسمية). راجع مصفوفة التحقق الصريحة لكل ميزة في [`docs/feature_verification_matrix.md`](docs/feature_verification_matrix.md).

---

## ✨ ماذا يقدّم التطبيق فعليًا؟ | Verified Capabilities

### 1. 🗓️ يومك في نظرة واحدة (Energy-Aware Daily Flow)
* لوحة يومية تعرض مهامك ونسبة إنجازك بدون تشتيت.
* اختيار «خطوتك الجاية» بناءً على الأولوية والموعد وتفضيلات طاقتك (`صباحي / بعد الظهر / مسائي` وأسلوب البدء) مع عرض سبب الاختيار بوضوح.
* دعم المهام المتكررة (**يوميًا، أيام العمل، أسبوعيًا، شهريًا**) مع حساب تقويمي آمن لنهايات الشهور.

### 2. 💬 المساعد الشخصي باللهجة المصرية والإنجليزية (On-Device Text Assistant & Confirm-Before-Write)
* **معالجة النص محليًا بالكامل:** الرسائل المكتوبة للمساعد تُحلّل على الجهاز باستخدام مصنّف NLU محلي ومنسّق تخطيط حتمي (بدون إرسال نص مهامك إلى LLM خارجي).
* **مراجعة واعتماد قبل أي حفظ أو حذف:** يعرض المساعد بطاقة مسودة تفاعلية (العنوان، التاريخ/الوقت، التكرار، ونوع التنبيه) تتيح **اعتماد وحفظ** أو **تعديل سريع** أو **إلغاء** قبل أي تعديل فعلي في قاعدة البيانات، تليها نقرة مباشرة لبدء خطوة تركيز.
* **الإدخال الصوتي اختياري وبإفصاح صريح عند أول استخدام:** يستخدم محرك `SpeechRecognizer` الخاص بنظام Android عند ضغطك على زر الميكروفون فقط، مع نافذة إفصاح صريحة عند أول نقرة توضّح أن محرك النظام قد يعتمد على الشبكة وتوفّر التحويل الفوري للكتابة المحلية.
* مسودات تخطيط تفاعلية بأسئلة توضيحية وتأكيد صريح قبل تطبيق تعديلات الجدول.

### 3. 📂 مساحات عمل للمشروعات والأهداف (Project Workspaces)
* تنظيم المهام المرتبطة بهدف واحد داخل مشروع مستقل بمراحل وتتبع لنسبة الإنجاز.

### 4. 🎯 جلسات التركيز والأصوات الهادئة (Calm Focus & Soundscapes)
* مؤقّت تركيز مدمج مع أصوات طبيعية مولّدة محليًا وسجل لجلسات التركيز.

### 5. 🎓 وضع الطالب وتتبع الدراسة (Student Mode)
* واجهة مخصّصة للطلاب لتنظيم المواد والمراجعات وسجل لتقديرات الامتحانات.

### 6. 🔔 تذكيرات ومنبّهات بشفافية كاملة للأذونات (Transparent Reminders & Quiet Hours)
* دعم تذكيرات هادئة ومنبّهات Android أصلية مع **ساعات الهدوء (Quiet Hours)** ومستقبلات إعادة الإقلاع وتغيير المنطقة الزمنية.
* **لا نجاح وهمي:** يعرض التطبيق صراحة حالة كل منبّه (**مجدول بدقة** / **منبه تقريبي عند غياب إذن المنبه الدقيق** / **لم يُجدول عند رفض إذن الإشعارات**). *(الاعتمادية الكاملة عبر مصنّعي Android المختلفين تتطلب اختبارًا ميدانيًا مستمرًا على أجهزة فعلية.)*

---

## 🔒 الحسابات، التخزين (SQLite)، والمزامنة السحابية | Accounts, SQLite & Cloud Sync

* **ابدأ فورًا بدون حساب (Offline-First SQLite):** يمكنك بدء استخدام التطبيق فورًا بنقرة واحدة (`ابدأ فورًا بدون إنشاء حساب`) مع حفظ كل المهام والمشاريع وجلسات التركيز في قاعدة بيانات **SQLite منظّمة (WAL mode)** على جهازك (مع ترحيل ذري تلقائي لأي بيانات JSON قديمة ونسخة أمان مشفّرة قبل الترحيل).
* **ترقية سلسة لحساب وتشفير قوي:** عند إنشاء حساب لاحقًا، تنتقل كل مهامك ومشاريعك تلقائيًا إلى حسابك بدون فقدان عنصر واحد. كلمات المرور المحلية تُشتق بـ **PBKDF2-HMAC-SHA256 (`100,000` تكرار)** داخل Isolate خلفي. أزرار Google / Facebook مخفية ومعطّلة افتراضيًا ما لم يُفعّل مسار OAuth متحقق من الرمز (`ENABLE_VERIFIED_SOCIAL_OAUTH=true`).
* **مزامنة سحابية تزايدية اختيارية (Per-Entity Delta Sync):** عند تمرير مفاتيح Firebase عبر `--dart-define`، تعمل المزامنة عبر طابور `sync_outbox` دائم مع إعادة محاولة متدرجة (`30s..3600s`) ومجموعات فرعية منفصلة لكل عنصر (`users/{uid}/tasks`, `projects`, `focus_sessions`) مع حل تعارضات على مستوى العنصر (UTC `updated_at`)، قواعد أمان صارمة [`firebase/firestore.rules`](firebase/firestore.rules)، ودليل امتثال Google Play في [`docs/play_store_storage_compliance.md`](docs/play_store_storage_compliance.md).
* **نسخ احتياطي واستعادة كاملة (Full Round-Trip JSON):** يمكنك من الإعدادات تصدير واستعادة المهام، المشاريع (بمراحلها)، جلسات التركيز، درجات الامتحانات، تفضيلات الطاقة، تفضيلات الإشعارات، والمنبهات — مع التحقق المسبق، مقاومة تكرار الاستيراد (Idempotent)، والتراجع الذري الكامل عند أي خطأ.
* **الفوترة اختيارية عبر إعدادات البناء:** لا يتم تفعيل RevenueCat إلا عند تمرير مفاتيحه عبر `--dart-define`، وتُخفى شاشة الباقات تلقائيًا في النسخ غير المهيّأة للفوترة.
* **مقاييس جودة اختيارية ومغلقة افتراضيًا (Opt-In Anonymous Counters):** من الإعدادات ← الخصوصية، يمكنك تفعيل أو إيقاف عدّادات مجهولة محليًا لقياس معدلات التأكيد والتعديل والإلغاء بدون حفظ أي نصوص مهام أو بيانات شخصية، مع استبعاد تلقائي لحساب المعاينة ومسح كامل عند إيقاف الموافقة أو حذف الحساب.
* **حساب المعاينة (QA Preview):** معطّل افتراضيًا وممنوع برمجيًا في إصدارات `release` وبوابة CI.

---

## 🛠️ التحقق والبناء (Developer & CI Verification)

```bash
# 1) Static analysis (root app + local ai_assistant package)
flutter analyze
cd packages/ai_assistant && flutter analyze && cd ../..

# 2) Automated unit, widget & NLU tests
flutter test
cd packages/ai_assistant && flutter test && cd ../..

# 3) Debug APK build (release builds require signing keys in android/key.properties or env vars)
flutter build apk --debug

# 4) Pilot cohort & unit-economics evaluation CLIs (Phases 4 & 5)
dart run tool/evaluate_pilot_cohorts.dart <pilot_exports_dir> --as-of=YYYY-MM-DD
dart run tool/evaluate_unit_economics.dart <channel_experiment.json>
```

أدلة التحقق الميداني وقوالب المقابلات والتشغيل للمراحل 3–5 موجودة في [`docs/validation/`](docs/validation/phase3_discovery_interview_kit.md).

---

<div align="center">
  <p><b>هندلها — يومك أبسط، خطوة بخطوة.</b></p>
  <p>© Handelha. All rights reserved.</p>
</div>
