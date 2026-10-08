<div align="center">
 
  
  <h1>هندلها | Handelha </h1>
  <p><b>إنتاجية هادئة وذكية (Calm Intelligent Productivity)</b></p>

  <p>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
    <a href="https://riverpod.dev"><img src="https://img.shields.io/badge/Riverpod-blue?style=for-the-badge&logo=flutter" alt="Riverpod" /></a>
  </p>
</div>

<br/>

## 📖 عن التطبيق (Overview)
**هندلها (Handelha)** ليس مجرد تطبيق تقليدي لإدارة المهام، بل هو بيئة متكاملة مصممة بفلسفة **"الإنتاجية الهادئة الذكية"**. يهدف التطبيق إلى مساعدة المستخدمين على تنظيم يومهم، إدارة مشاريعهم، وتقليل التشتت من خلال واجهة مستخدم مريحة للعين، مدعومة بمساعد شخصي ذكي يسهل عليك تحويل الأفكار إلى خطوات عمل قابلة للتنفيذ.

يتميز التطبيق بتصميم عصري (Premium UI/UX) مع اهتمام فائق بأدق التفاصيل، ويدعم **الوضع الداكن (Dark Mode)** بشكل احترافي، بالإضافة إلى تخصيص ألوان المشاريع بشكل ديناميكي (Dynamic Theming).

---

## ✨ المميزات الرئيسية (Key Features)

* 📅 **لوحة القيادة الذكية (Smart Dashboard):** نظرة عامة على أولويات يومك، المهام العاجلة، ومستوى التقدم مع إمكانية إضافة المهام السريعة.
* 📂 **مساحات عمل المشاريع (Project Workspaces):** إدارة متكاملة لكل مشروع على حدة مع تبويبات مخصصة لـ (المهام، الأفكار، الملاحظات، التحليلات).
* 📊 **التحليلات الذكية (Advanced Analytics):** رسوم بيانية توضح توزيع وقتك، أدائك، وساعات العمل المنجزة داخل كل مشروع.
* 🤖 **المساعد الشخصي (AI Assistant):** دردشة تفاعلية لمساعدتك في التخطيط، اقتراح مهام جديدة، وتحويل أفكارك الكبيرة إلى خطوات صغيرة.
* 🎯 **جلسات التركيز (Focus Sessions):** أداة مدمجة تشبه تقنية بومودورو (Pomodoro) لمساعدتك على الإنجاز العميق بدون تشتت.
* 🎨 **تصميم مريح وتجاوبي (Calm & Adaptive UI):** 
  * تصميم يعتمد على ألوان هادئة وطبيعية (أخضر زمردي، درجات بنفسجية، طيني).
  * دعم كامل ومثالي للوضع الليلي (Semantic Dark Mode) يحمي العين ويوفر تجربة استخدام فاخرة.
  * ألوان ديناميكية متغيرة بناءً على لون كل مشروع.

---

## 🛠 البنية التقنية (Tech Stack)

تم بناء التطبيق باستخدام أحدث التقنيات وأفضل الممارسات (Best Practices) في عالم تطوير تطبيقات Flutter:

* **إطار العمل:** [Flutter](https://flutter.dev) (SDK > 3.13)
* **إدارة الحالة (State Management):** `flutter_riverpod` & `riverpod_annotation`
* **التوجيه والتنقل (Routing):** `go_router`
* **تخزين البيانات المحلي:** `shared_preferences` & `flutter_secure_storage`
* **توليد الكود (Code Generation):** `build_runner`, `freezed`, `json_serializable`

---

## 📁 هيكلة المشروع (Project Structure)

يعتمد التطبيق على معمارية **Feature-First** المنظمة لضمان قابلية التوسع وسهولة الصيانة:

```text
lib/
 ┣ app/                  # إعدادات التطبيق الأساسية (الراوتر، الثيم، الألوان)
 ┣ core/                 # الملفات الأساسية (إدارة الأخطاء، الثوابت، النماذج المشتركة)
 ┣ features/             # الميزات الأساسية للتطبيق
 ┃ ┣ assistant/          # المساعد الذكي
 ┃ ┣ authentication/     # المصادقة وتسجيل الدخول
 ┃ ┣ home/               # الشاشة الرئيسية ولوحة القيادة
 ┃ ┣ notifications/      # الإشعارات
 ┃ ┣ onboarding/         # شاشات الترحيب
 ┃ ┣ projects/           # إدارة المشاريع ومساحات العمل
 ┃ ┣ settings/           # الإعدادات
 ┃ ┗ tasks/              # إدارة المهام
 ┗ shared/               # المكونات المشتركة (Widgets)
```

---

## 🚀 كيفية التشغيل (Getting Started)

للبدء في تطوير أو تشغيل التطبيق على بيئتك المحلية، اتبع الخطوات التالية:

### 1. المتطلبات المسبقة (Prerequisites)
تأكد من تنصيب [Flutter SDK](https://docs.flutter.dev/get-started/install) بإصدار لا يقل عن `3.13.5`.

### 2. تثبيت الحزم (Install Dependencies)
```bash
flutter pub get
```

### 3. توليد الكود (Code Generation)
نظراً لاستخدام `Riverpod` و `Freezed`، قم بتشغيل أمر توليد الكود:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. تشغيل التطبيق (Run the App)
```bash
flutter run
```

---


---

<div align="center">
  <b>تم البناء بكل ❤️ من أجل إنتاجية أفضل.</b>
</div>
