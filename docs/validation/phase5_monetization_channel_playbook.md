# دليل الجاهزية التجارية، فوترة Google Play، وقناة الاكتساب — المرحلة الخامسة (Phase 5)

> **شرط إلزامي من مجلس التقييم:** لا يُفعّل الدفع ولا تُطلق حملة اكتساب مدفوعة قبل اجتياز **بوابة المرحلة 4ب (`D28 >= 25%` وتحسن إتمام الالتزامات `>= +20%`)**. يقوم المقيّم الآلي (`tool/evaluate_unit_economics.dart`) بإغلاق قرار التوسع تلقائيًا (`blockedByPhase4bRetention`) إذا كانت `phase4bD28GatePassed == false`.

---

## 1. إعداد Google Play Billing + RevenueCat للإنتاج والـ Sandbox

### أ. المنتجات والاستحقاقات المطلوبة (Product & Entitlement Mapping)
| المفتاح في الكود (`SubscriptionConfig`) | القيمة الافتراضية | الوصف في Play Console / RevenueCat |
|---|---|---|
| `REVENUECAT_ANDROID_API_KEY` | *(فارغ افتراضيًا — يجب تمريره في البناء)* | مفتاح Android Public SDK Key من RevenueCat |
| `REVENUECAT_ENTITLEMENT_ID` | `handelha_pro` | الاستحقاق النشط لباقات Handelha Pro |
| `REVENUECAT_MONTHLY_PRODUCT_ID` | `handelha_pro_monthly` | اشتراك شهري متجدد عبر Google Play |
| `REVENUECAT_YEARLY_PRODUCT_ID` | `handelha_pro_yearly` | اشتراك سنوي متجدد عبر Google Play |
| `ENABLE_STUDENT_VERIFICATION` | `false` *(معلّق افتراضيًا)* | يبقى `false` حتى بناء تحقق فعلي من البريد الجامعي بعد ثبوت الاستعداد للدفع |

### ب. أمر بناء Release الموقّع مع الفوترة الحقيقية
```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=prod \
  --dart-define=ENABLE_QA_PREVIEW=false \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_YOUR_REAL_KEY \
  --dart-define=REVENUECAT_ENTITLEMENT_ID=handelha_pro
```
*(يتطلب ملف `android/key.properties` أو متغيرات التوقيع البيئية — يفشل البناء تلقائيًا في `android/app/build.gradle.kts` إذا لم تتوفر مفاتيح التوقيع.)*

### ج. قائمة تحقق Google Play License Tester (Sandbox — على جهاز Android فعلي)
قبل فتح الشراء للمستخدمين، يجب تنفيذ وتوثيق الحالات الست التالية على حساب License Tester حقيقي في Play Console:
1. **البناء بدون مفتاح:** شاشة الإعدادات ونافذة التوكنز تخفي أزرار الشراء، ولا يحدث أي تفعيل محلي.
2. **شراء ناجح (`handelha_pro_monthly` / `handelha_pro_yearly`):** انتقال فوري إلى `SubscriptionStatus.active` مع `isLocalActivation == false` وتاريخ انتهاء حقيقي من Google Play.
3. **إلغاء المستخدم أثناء نافذة الدفع:** عودة فورية لـ `free` مع رسالة واضحة بدون خصم.
4. **استعادة المشتريات (`Restore Purchases`)** بعد مسح بيانات التطبيق أو على جهاز ثانٍ: استعادة الاشتراك النشط بنجاح + رسالة صريحة عند غياب مشتريات سابقة.
5. **انتهاء الاشتراك / إلغاء التجديد التلقائي (Test subscription 5-min renewal cycle):** انتقال تلقائي إلى `SubscriptionStatus.expired` وسحب صلاحيات `PremiumFeature` وعرض شريط انتهاء الصلاحية.
6. **مسار الطلاب (`Student Track`):** يبقى مغلقًا برسالة صريحة حتى تفعيل التحقق الأكاديمي الحقيقي.

---

## 2. اختبار قناة اكتساب واحدة وحساب اقتصاديات الوحدة (Unit Economics)

### المنهج المنضبط
* اختبر **قناة واحدة فقط** في كل دورة (مثلًا: مجتمع طلاب جامعيين محدد أو محتوى قصير عضوي/مميز بميزانية سقفها محدود).
* سجّل أرقام الدورة الحقيقية في ملف JSON (مثال: `channel_exp_01.json`):
  ```json
  {
    "channelName": "egyptian_students_organic_telegram",
    "currency": "EGP",
    "phase4bD28GatePassed": true,
    "channelSpend": 2500,
    "installedUsers": 250,
    "activatedUsers": 140,
    "retainedD28Users": 42,
    "paidSubscribers": 14,
    "refundedSubscribers": 1,
    "grossPricePerPeriod": 89,
    "isAnnualPlan": false,
    "googlePlayFeeRate": 0.15,
    "monthlySupportCostPerPaidUser": 5.0,
    "expectedPaidLifetimeMonths": 4.0
  }
  ```
* شغّل محرك القرار:
  ```bash
  dart run tool/evaluate_unit_economics.dart channel_exp_01.json
  ```

### معايير القرار الآلي (`UnitEconomicsCalculator`)
* **`blockedByPhase4bRetention`:** إذا لم تجتز المرحلة 4ب — **إيقاف فوري لأي إنفاق استحواذ**.
* **`stopDoNotScale`:** صفر مشترين صافين أو هامش المساهمة بعد رسوم Google Play (`15%`/`30%`) وتكلفة الدعم لا يغطي `CAC`.
* **`iteratePricingOrChannel`:** هامش إيجابي لكن نسبة الاسترداد `> 15%` أو العينة `< 5` مشترين أو `LTV:CAC < 2.0x` أو فترة الاسترداد `> 6` أشهر.
* **`goScaleChannel`:** معاملات حقيقية متكررة (`>= 5` صافي)، `LTV:CAC >= 2.0x` (أو عضوي)، وفترة استرداد `<= 6` أشهر مع اجتياز بوابة 4ب.
