package com.handelha.app

import android.animation.ValueAnimator
import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsetsController
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

class AlarmActivity : Activity() {
    companion object {
        const val ACTION_START_FOCUS_FROM_ALARM = "com.handelha.app.ACTION_START_FOCUS"
    }

    private val typefaceCache = HashMap<String, Typeface>()

    private fun brandTypeface(
        weightFile: String,
        fallbackFamily: String,
        fallbackStyle: Int,
    ): Typeface {
        return typefaceCache.getOrPut(weightFile) {
            try {
                Typeface.createFromAsset(
                    assets,
                    "flutter_assets/assets/fonts/IBMPlexSansArabic-$weightFile.ttf",
                )
            } catch (_: Throwable) {
                Typeface.create(fallbackFamily, fallbackStyle)
            }
        }
    }

    private fun loadBrandLogoBitmap(): Bitmap? {
        return try {
            val opts = BitmapFactory.Options().apply {
                inSampleSize = 16
            }
            assets.open("flutter_assets/assets/images/logo.png").use { stream ->
                BitmapFactory.decodeStream(stream, null, opts)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private val clockHandler = Handler(Looper.getMainLooper())
    private var alarmId: String = ""
    private var alarmTitle: String = ""
    private var taskId: String? = null
    private var isEn: Boolean = false
    private var isPreview: Boolean = false

    private lateinit var timeView: TextView
    private lateinit var periodView: TextView
    private lateinit var dateView: TextView
    private lateinit var taskTitleView: TextView
    private lateinit var dialView: HorologicalDialView

    private val clockTick = object : Runnable {
        override fun run() {
            updateClockText()
            clockHandler.postDelayed(this, 1_000L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenWindow()
        readExtras(intent)
        buildContentView()

        // Start native chime + vibration immediately if not already playing (e.g. direct preview launch)
        AlarmAudioController.start(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readExtras(intent)
        if (::taskTitleView.isInitialized) {
            taskTitleView.text = alarmTitle
        }
        AlarmAudioController.start(this)
    }

    override fun onResume() {
        super.onResume()
        updateClockText()
        clockHandler.removeCallbacks(clockTick)
        clockHandler.postDelayed(clockTick, 1_000L)
        if (::dialView.isInitialized) {
            dialView.startAnimations()
        }
    }

    override fun onPause() {
        clockHandler.removeCallbacks(clockTick)
        if (::dialView.isInitialized) {
            dialView.stopAnimations()
        }
        super.onPause()
    }

    override fun onDestroy() {
        clockHandler.removeCallbacks(clockTick)
        if (isFinishing) {
            AlarmAudioController.stop(this)
        }
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        handleDismiss()
    }

    private fun configureLockScreenWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Color.parseColor("#091C17")
        window.navigationBarColor = Color.parseColor("#071612")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.setSystemBarsAppearance(
                0,
                WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
            )
        }
    }

    private fun readExtras(intent: Intent?) {
        val localeEn = Locale.getDefault().language.lowercase(Locale.ROOT) == "en"
        isEn = intent?.getBooleanExtra(NativeAlarmScheduler.EXTRA_IS_EN, localeEn) ?: localeEn
        isPreview = intent?.getBooleanExtra(NativeAlarmScheduler.EXTRA_IS_PREVIEW, false) ?: false
        alarmId = intent?.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_ID)
            ?.takeIf { it.isNotBlank() }
            ?: "alarm_${System.currentTimeMillis()}"
        alarmTitle = intent?.getStringExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE)
            ?.takeIf { it.isNotBlank() }
            ?: (if (isEn) "Scheduled Task" else "مراجعة المهمة")
        taskId = intent?.getStringExtra(NativeAlarmScheduler.EXTRA_TASK_ID)
            ?.takeIf { it.isNotBlank() }
    }

    private fun dp(value: Float): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value,
        resources.displayMetrics,
    ).toInt()

    private fun buildContentView() {
        val root = FrameLayout(this).apply {
            layoutDirection = if (isEn) View.LAYOUT_DIRECTION_LTR else View.LAYOUT_DIRECTION_RTL
        }

        // Handelha atmospheric dark emerald + subtle lavender + dot-matrix backdrop
        val backdrop = BrandBackdropView(this)
        root.addView(
            backdrop,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            overScrollMode = View.OVER_SCROLL_NEVER
            isVerticalScrollBarEnabled = false
        }

        val mainColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(22f), dp(26f), dp(22f), dp(24f))
            alpha = 0f
            translationY = dp(16f).toFloat()
        }

        mainColumn.setOnApplyWindowInsetsListener { view, insets ->
            val topInset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insets.getInsets(android.view.WindowInsets.Type.systemBars()).top
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetTop
            }
            val bottomInset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insets.getInsets(android.view.WindowInsets.Type.systemBars()).bottom
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetBottom
            }
            view.setPadding(
                dp(22f),
                dp(18f) + topInset,
                dp(22f),
                dp(20f) + bottomInset,
            )
            insets
        }

        // 1. Frosted Handelha Brand Capsule with logo mark
        val brandPill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12f), dp(7f), dp(14f), dp(7f))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(999f).toFloat()
                setColor(Color.parseColor("#E613312A"))
                setStroke(dp(1f), Color.parseColor("#245549"))
            }
        }

        val logoBitmap = loadBrandLogoBitmap()
        if (logoBitmap != null) {
            val logoBadge = FrameLayout(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#E4F3EF"))
                }
            }
            val logoImg = ImageView(this).apply {
                setImageBitmap(logoBitmap)
                scaleType = ImageView.ScaleType.FIT_CENTER
            }
            logoBadge.addView(
                logoImg,
                FrameLayout.LayoutParams(dp(18f), dp(18f), Gravity.CENTER),
            )
            brandPill.addView(
                logoBadge,
                LinearLayout.LayoutParams(dp(26f), dp(26f)),
            )
            brandPill.addView(View(this), LinearLayout.LayoutParams(dp(8f), 1))
        }

        val brandText = TextView(this).apply {
            text = if (isEn) "Handelha  •  Scheduled Alarm" else "هندلها  •  منبه المواعيد"
            setTextColor(Color.parseColor("#E6F4F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            if (isEn) letterSpacing = 0.02f
            typeface = brandTypeface("SemiBold", "sans-serif-medium", Typeface.BOLD)
            includeFontPadding = false
        }
        brandPill.addView(brandText)
        brandPill.addView(View(this), LinearLayout.LayoutParams(dp(8f), 1))

        val liveDot = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#C8F383"))
            }
        }
        brandPill.addView(liveDot, LinearLayout.LayoutParams(dp(7f), dp(7f)))

        mainColumn.addView(
            brandPill,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        // Top flexible spacer
        mainColumn.addView(View(this), LinearLayout.LayoutParams(1, 0, 0.7f))

        // 2. Centered Modern Horological Dial (Clock + Date framed cleanly inside)
        val screenMin = min(
            resources.displayMetrics.widthPixels,
            resources.displayMetrics.heightPixels,
        )
        val dialSizePx = min(dp(236f), (screenMin * 0.62f).toInt())

        val dialContainer = FrameLayout(this)
        dialView = HorologicalDialView(this)
        dialContainer.addView(
            dialView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        val dialInner = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(22f), dp(18f), dp(22f), dp(18f))
        }

        val dialStatus = TextView(this).apply {
            text = if (isEn) "ALARM ACTIVE" else "حان الموعد"
            setTextColor(Color.parseColor("#6CD6C6"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
            if (isEn) letterSpacing = 0.08f
            typeface = brandTypeface("SemiBold", "sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            includeFontPadding = false
        }
        dialInner.addView(dialStatus)

        val clockRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM
            layoutDirection = View.LAYOUT_DIRECTION_LTR
            setPadding(0, dp(6f), 0, dp(2f))
        }

        timeView = TextView(this).apply {
            setTextColor(Color.parseColor("#F5FAF8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 52f)
            typeface = brandTypeface("Bold", "sans-serif-medium", Typeface.BOLD)
            fontFeatureSettings = "tnum"
            includeFontPadding = false
            if (isEn) letterSpacing = -0.02f
        }

        periodView = TextView(this).apply {
            setTextColor(Color.parseColor("#C8F383"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            typeface = brandTypeface("Bold", "sans-serif-medium", Typeface.BOLD)
            includeFontPadding = false
            setPadding(dp(8f), dp(3f), dp(8f), dp(3f))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(999f).toFloat()
                setColor(Color.parseColor("#1D483D"))
                setStroke(dp(1f), Color.parseColor("#2B6858"))
            }
        }
        val periodLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            marginStart = dp(7f)
            bottomMargin = dp(8f)
        }

        clockRow.addView(timeView)
        clockRow.addView(periodView, periodLp)
        dialInner.addView(clockRow)

        dateView = TextView(this).apply {
            setTextColor(Color.parseColor("#9EC2B7"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = brandTypeface("Medium", "sans-serif", Typeface.NORMAL)
            gravity = Gravity.CENTER
            includeFontPadding = false
            setPadding(0, dp(6f), 0, 0)
        }
        dialInner.addView(dateView)

        dialContainer.addView(
            dialInner,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            ),
        )

        val dialLp = LinearLayout.LayoutParams(dialSizePx, dialSizePx).apply {
            topMargin = dp(12f)
            bottomMargin = dp(16f)
        }
        mainColumn.addView(dialContainer, dialLp)

        // 3. Modern Frosted Handelha Task Spotlight Card
        val taskCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(20f), dp(18f), dp(20f), dp(18f))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24f).toFloat()
                setColor(Color.parseColor("#EB132D26"))
                setStroke(dp(1.2f), Color.parseColor("#235246"))
            }
        }

        val badgePill = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10f), dp(4f), dp(10f), dp(4f))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(999f).toFloat()
                setColor(Color.parseColor("#1B3E35"))
            }
        }
        val coralDot = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E2856E"))
            }
        }
        badgePill.addView(coralDot, LinearLayout.LayoutParams(dp(6.5f), dp(6.5f)))
        badgePill.addView(View(this), LinearLayout.LayoutParams(dp(6f), 1))
        val badgeText = TextView(this).apply {
            text = if (isEn) "Scheduled Task" else "مهمة مجدولة"
            setTextColor(Color.parseColor("#D7ECE6"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
            typeface = brandTypeface("SemiBold", "sans-serif-medium", Typeface.BOLD)
            includeFontPadding = false
        }
        badgePill.addView(badgeText)
        taskCard.addView(
            badgePill,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        taskTitleView = TextView(this).apply {
            text = alarmTitle
            setTextColor(Color.parseColor("#FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 21.5f)
            typeface = brandTypeface("Bold", "sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            maxLines = 3
            ellipsize = TextUtils.TruncateAt.END
            setLineSpacing(dp(4f).toFloat(), 1.0f)
            setPadding(0, dp(10f), 0, 0)
        }
        taskCard.addView(
            taskTitleView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        val subtitleHint = TextView(this).apply {
            text = if (isEn) "It is time for your scheduled task" else "جه ميعاد مهمتك دلوقتي"
            setTextColor(Color.parseColor("#9EBDB4"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
            typeface = brandTypeface("Medium", "sans-serif", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(0, dp(6f), 0, 0)
        }
        taskCard.addView(subtitleHint)

        mainColumn.addView(
            taskCard,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        // Bottom flexible spacer
        mainColumn.addView(View(this), LinearLayout.LayoutParams(1, 0, 0.9f))

        // 4. Primary Handelha Lime Accent Dismiss CTA
        val dismissBtn = createPillButton(
            label = if (isEn) "Dismiss Alarm" else "إيقاف المنبه",
            fillColor = Color.parseColor("#C8F383"),
            strokeColor = Color.TRANSPARENT,
            textColor = Color.parseColor("#0C211C"),
            rippleColor = Color.parseColor("#240C211C"),
            textSp = 16.5f,
            bold = true,
            heightDp = 58f,
            radiusDp = 24f,
        ).apply {
            setOnClickListener { handleDismiss() }
        }
        val dismissLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(58f),
        ).apply {
            topMargin = dp(18f)
        }
        mainColumn.addView(dismissBtn, dismissLp)

        // Two-column Emerald Glass Snooze Row
        val snoozeRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        val snoozeRowLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(50f),
        ).apply {
            topMargin = dp(12f)
        }

        val snooze5 = createPillButton(
            label = if (isEn) "Snooze 5 min" else "غفوة ٥ د",
            fillColor = Color.parseColor("#143029"),
            strokeColor = Color.parseColor("#26574A"),
            textColor = Color.parseColor("#E8F5F1"),
            rippleColor = Color.parseColor("#22FFFFFF"),
            textSp = 14f,
            bold = false,
            heightDp = 50f,
            radiusDp = 20f,
        ).apply {
            setOnClickListener { handleSnooze(5) }
        }

        val snooze10 = createPillButton(
            label = if (isEn) "Snooze 10 min" else "غفوة ١٠ د",
            fillColor = Color.parseColor("#143029"),
            strokeColor = Color.parseColor("#26574A"),
            textColor = Color.parseColor("#E8F5F1"),
            rippleColor = Color.parseColor("#22FFFFFF"),
            textSp = 14f,
            bold = false,
            heightDp = 50f,
            radiusDp = 20f,
        ).apply {
            setOnClickListener { handleSnooze(10) }
        }

        snoozeRow.addView(snooze5, LinearLayout.LayoutParams(0, dp(50f), 1f))
        snoozeRow.addView(View(this), LinearLayout.LayoutParams(dp(10f), 1))
        snoozeRow.addView(snooze10, LinearLayout.LayoutParams(0, dp(50f), 1f))
        mainColumn.addView(snoozeRow, snoozeRowLp)

        // Focus Session Action Pill
        val focusBtn = createPillButton(
            label = if (isEn) "Open Task & Start Focus Now" else "فتح المهمة وبدء التركيز الآن",
            fillColor = Color.parseColor("#102B24"),
            strokeColor = Color.parseColor("#255E50"),
            textColor = Color.parseColor("#6CD6C6"),
            rippleColor = Color.parseColor("#2251C7B5"),
            textSp = 14f,
            bold = false,
            heightDp = 48f,
            radiusDp = 20f,
        ).apply {
            setOnClickListener { handleStartFocus() }
        }
        val focusLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(48f),
        ).apply {
            topMargin = dp(12f)
        }
        mainColumn.addView(focusBtn, focusLp)

        scrollView.addView(
            mainColumn,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        root.addView(
            scrollView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        setContentView(root)

        mainColumn.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(320L)
            .setInterpolator(DecelerateInterpolator())
            .start()
    }

    private fun createPillButton(
        label: String,
        fillColor: Int,
        strokeColor: Int,
        textColor: Int,
        rippleColor: Int,
        textSp: Float,
        bold: Boolean,
        heightDp: Float,
        radiusDp: Float,
    ): TextView {
        val shape = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radiusDp).toFloat()
            setColor(fillColor)
            if (strokeColor != Color.TRANSPARENT) {
                setStroke(dp(1.2f), strokeColor)
            }
        }
        val ripple = RippleDrawable(
            ColorStateList.valueOf(rippleColor),
            shape,
            null,
        )
        return TextView(this).apply {
            text = label
            setTextColor(textColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, textSp)
            typeface = if (bold) {
                brandTypeface("Bold", "sans-serif-medium", Typeface.BOLD)
            } else {
                brandTypeface("SemiBold", "sans-serif-medium", Typeface.BOLD)
            }
            gravity = Gravity.CENTER
            minHeight = dp(heightDp)
            background = ripple
            isClickable = true
            isFocusable = true
            setOnTouchListener { v, ev ->
                when (ev.action) {
                    MotionEvent.ACTION_DOWN ->
                        v.animate().scaleX(0.97f).scaleY(0.97f).setDuration(90L).start()
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL ->
                        v.animate().scaleX(1f).scaleY(1f).setDuration(130L).start()
                }
                false
            }
        }
    }

    private fun updateClockText() {
        val now = Date()
        val rawHourMin = SimpleDateFormat("h:mm", Locale.US).format(now)
        val cal = java.util.Calendar.getInstance()
        val isAm = cal.get(java.util.Calendar.AM_PM) == java.util.Calendar.AM

        if (isEn) {
            timeView.text = rawHourMin
            periodView.text = if (isAm) "AM" else "PM"
            dateView.text = SimpleDateFormat("EEE, MMM d", Locale.US).format(now)
        } else {
            timeView.text = toArabicDigits(rawHourMin)
            periodView.text = if (isAm) "ص" else "م"
            val arDate = SimpleDateFormat("EEEE، d MMMM", Locale.forLanguageTag("ar-EG")).format(now)
            dateView.text = toArabicDigits(arDate)
        }
    }

    private fun toArabicDigits(input: String): String {
        val map = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        val out = StringBuilder(input.length)
        for (ch in input) {
            if (ch in '0'..'9') {
                out.append(map[ch - '0'])
            } else {
                out.append(ch)
            }
        }
        return out.toString()
    }

    private fun handleDismiss() {
        AlarmAudioController.stop(this)
        NativeAlarmScheduler.cancelAlarm(this, alarmId)
        if (!isPreview) {
            NativeAlarmStore.enqueuePendingAction(
                context = this,
                action = "dismiss",
                id = alarmId,
                title = alarmTitle,
                taskId = taskId,
            )
        }
        finishSafely()
    }

    private fun handleSnooze(minutes: Int) {
        AlarmAudioController.stop(this)
        NativeAlarmScheduler.cancelAlarm(this, alarmId)
        val nextAt = System.currentTimeMillis() + minutes * 60_000L
        NativeAlarmScheduler.scheduleAlarm(
            context = this,
            id = alarmId,
            title = alarmTitle,
            triggerAtMs = nextAt,
            alertMode = "alarm",
            taskId = taskId,
            saveRecord = !isPreview,
        )
        NativeAlarmStore.enqueuePendingAction(
            context = this,
            action = "snooze",
            id = alarmId,
            title = alarmTitle,
            taskId = taskId,
            snoozeAtMs = nextAt,
        )
        val msg = if (isEn) {
            "Snoozed for $minutes minutes"
        } else {
            "تم تأجيل المنبه ${toArabicDigits(minutes.toString())} دقائق"
        }
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        finishSafely()
    }

    private fun handleStartFocus() {
        AlarmAudioController.stop(this)
        NativeAlarmScheduler.cancelAlarm(this, alarmId)
        NativeAlarmStore.enqueuePendingAction(
            context = this,
            action = "start_focus",
            id = alarmId,
            title = alarmTitle,
            taskId = taskId,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            if (km?.isKeyguardLocked == true) {
                km.requestDismissKeyguard(this, null)
            }
        }

        val launchApp = Intent(this, MainActivity::class.java).apply {
            action = ACTION_START_FOCUS_FROM_ALARM
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_ID, alarmId)
            putExtra(NativeAlarmScheduler.EXTRA_ALARM_TITLE, alarmTitle)
            if (!taskId.isNullOrBlank()) {
                putExtra(NativeAlarmScheduler.EXTRA_TASK_ID, taskId)
            }
        }
        try {
            startActivity(launchApp)
        } catch (_: Exception) {
        }
        finishSafely()
    }

    private fun finishSafely() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            finishAndRemoveTask()
        } else {
            finish()
        }
    }

    private class BrandBackdropView(context: Context) : View(context) {
        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val topGlowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val bottomGlowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.argb(26, 81, 199, 181)
        }
        private val density = context.resources.displayMetrics.density

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            if (w <= 0 || h <= 0) return
            bgPaint.shader = android.graphics.LinearGradient(
                0f,
                0f,
                0f,
                h.toFloat(),
                intArrayOf(
                    Color.parseColor("#091C17"),
                    Color.parseColor("#0E2922"),
                    Color.parseColor("#071612"),
                ),
                floatArrayOf(0f, 0.48f, 1f),
                Shader.TileMode.CLAMP,
            )
            topGlowPaint.shader = RadialGradient(
                w * 0.92f,
                h * 0.08f,
                w * 0.85f,
                intArrayOf(
                    Color.argb(95, 0, 112, 103),
                    Color.argb(38, 81, 199, 181),
                    Color.TRANSPARENT,
                ),
                floatArrayOf(0f, 0.42f, 1f),
                Shader.TileMode.CLAMP,
            )
            bottomGlowPaint.shader = RadialGradient(
                w * 0.06f,
                h * 0.90f,
                w * 0.82f,
                intArrayOf(
                    Color.argb(90, 39, 38, 68),
                    Color.argb(32, 111, 107, 148),
                    Color.TRANSPARENT,
                ),
                floatArrayOf(0f, 0.45f, 1f),
                Shader.TileMode.CLAMP,
            )
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            canvas.drawRect(0f, 0f, w, h, bgPaint)
            canvas.drawCircle(w * 0.92f, h * 0.08f, w * 0.85f, topGlowPaint)
            canvas.drawCircle(w * 0.06f, h * 0.90f, w * 0.82f, bottomGlowPaint)

            val startX = 22f * density
            val startY = 84f * density
            val step = 12f * density
            val dotR = 1.3f * density
            for (row in 0 until 5) {
                for (col in 0 until 5) {
                    canvas.drawCircle(
                        startX + col * step,
                        startY + row * step,
                        dotR,
                        dotPaint,
                    )
                }
            }
        }
    }

    private class HorologicalDialView(context: Context) : View(context) {
        private val density = context.resources.displayMetrics.density
        private var sweepAngle = 0f
        private var breathPhase = 0f

        private val sweepAnimator = ValueAnimator.ofFloat(0f, 360f).apply {
            duration = 6500L
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = LinearInterpolator()
            addUpdateListener {
                sweepAngle = it.animatedValue as Float
                invalidate()
            }
        }

        private val breathAnimator = ValueAnimator.ofFloat(0f, (PI * 2.0).toFloat()).apply {
            duration = 3200L
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            addUpdateListener {
                breathPhase = it.animatedValue as Float
            }
        }

        private val discPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.argb(232, 16, 40, 34)
        }
        private val discBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 1.3f * density
            color = Color.parseColor("#245649")
        }
        private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 4.5f * density
            color = Color.argb(46, 81, 199, 181)
        }
        private val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 5f * density
            strokeCap = Paint.Cap.ROUND
        }
        private val auraPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }
        private val majorTickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = 1.6f * density
            color = Color.argb(120, 81, 199, 181)
        }
        private val minorTickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = 1f * density
            color = Color.argb(72, 38, 86, 73)
        }
        private val tipGlowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.argb(120, 200, 243, 131)
        }
        private val tipCorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#C8F383")
        }

        private val arcRect = RectF()
        private var sweepShader: SweepGradient? = null
        private val shaderMatrix = Matrix()

        fun startAnimations() {
            if (!sweepAnimator.isRunning) sweepAnimator.start()
            if (!breathAnimator.isRunning) breathAnimator.start()
        }

        fun stopAnimations() {
            if (sweepAnimator.isRunning) sweepAnimator.cancel()
            if (breathAnimator.isRunning) breathAnimator.cancel()
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            if (w <= 0 || h <= 0) return
            val cx = w / 2f
            val cy = h / 2f
            val outerR = min(w, h) / 2f - 8f * density
            val ringR = outerR - 4f * density
            arcRect.set(cx - ringR, cy - ringR, cx + ringR, cy + ringR)

            auraPaint.shader = RadialGradient(
                cx,
                cy,
                outerR + 12f * density,
                intArrayOf(
                    Color.argb(45, 81, 199, 181),
                    Color.argb(14, 200, 243, 131),
                    Color.TRANSPARENT,
                ),
                floatArrayOf(0.45f, 0.78f, 1f),
                Shader.TileMode.CLAMP,
            )

            sweepShader = SweepGradient(
                cx,
                cy,
                intArrayOf(
                    Color.argb(45, 81, 199, 181),
                    Color.parseColor("#51C7B5"),
                    Color.parseColor("#C8F383"),
                    Color.argb(45, 81, 199, 181),
                ),
                floatArrayOf(0f, 0.24f, 0.375f, 1f),
            )
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            if (w <= 0f || h <= 0f) return

            val cx = w / 2f
            val cy = h / 2f
            val outerR = min(w, h) / 2f - 8f * density
            val discR = outerR - 6f * density
            val ringR = outerR - 4f * density
            val breath = ((cos(breathPhase.toDouble()) * -0.5) + 0.5).toFloat()

            auraPaint.alpha = (165 + breath * 90).toInt()
            canvas.drawCircle(cx, cy, outerR + (4f + breath * 7f) * density, auraPaint)

            canvas.drawCircle(cx, cy, discR, discPaint)
            canvas.drawCircle(cx, cy, discR, discBorderPaint)

            val tickOuter = discR - 9f * density
            for (i in 0 until 60) {
                val isMajor = i % 5 == 0
                val angle = -PI / 2.0 + (i / 60.0) * 2.0 * PI
                val len = (if (isMajor) 5.5f else 2.8f) * density
                val cosA = cos(angle).toFloat()
                val sinA = sin(angle).toFloat()
                canvas.drawLine(
                    cx + cosA * tickOuter,
                    cy + sinA * tickOuter,
                    cx + cosA * (tickOuter - len),
                    cy + sinA * (tickOuter - len),
                    if (isMajor) majorTickPaint else minorTickPaint,
                )
            }

            canvas.drawCircle(cx, cy, ringR, trackPaint)

            val startDeg = -90f + sweepAngle
            val sweepLen = 135f
            val shader = sweepShader
            if (shader != null) {
                shaderMatrix.setRotate(startDeg, cx, cy)
                shader.setLocalMatrix(shaderMatrix)
                arcPaint.shader = shader
            }
            canvas.drawArc(arcRect, startDeg, sweepLen, false, arcPaint)

            val tipRad = Math.toRadians((startDeg + sweepLen).toDouble())
            val tipX = cx + cos(tipRad).toFloat() * ringR
            val tipY = cy + sin(tipRad).toFloat() * ringR
            canvas.drawCircle(tipX, tipY, (6.5f + breath * 2f) * density, tipGlowPaint)
            canvas.drawCircle(tipX, tipY, 3.6f * density, tipCorePaint)
        }
    }
}
