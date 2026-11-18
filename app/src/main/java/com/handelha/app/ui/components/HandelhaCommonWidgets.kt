package com.handelha.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Policy
import androidx.compose.material.icons.rounded.VerifiedUser
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.handelha.app.R
import com.handelha.app.domain.AuthProviderType
import com.handelha.app.domain.UserEnergyPreferences
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.ui.theme.IbmPlexSansArabic
import com.handelha.app.util.ArabicFormatters

data class HandelhaSegmentOption<T>(
    val value: T,
    val label: String,
    val icon: ImageVector? = null,
    val testTag: String? = null,
)

@Composable
fun <T> HandelhaSegmentedSwitch(
    options: List<HandelhaSegmentOption<T>>,
    selected: T,
    onChanged: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val trackShape = RoundedCornerShape(16.dp)
    val trackBg = if (c.isDark) c.surfaceSoft else c.background

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(trackShape)
            .background(trackBg, trackShape)
            .border(1.dp, c.border, trackShape)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        options.forEach { option ->
            val isSelected = option.value == selected
            val tileShape = RoundedCornerShape(12.dp)
            val bg by animateColorAsState(
                targetValue = if (isSelected) {
                    if (c.isDark) c.primary.copy(alpha = 0.22f) else c.primarySoft
                } else {
                    Color.Transparent
                },
                animationSpec = tween(180),
                label = "seg_bg",
            )
            val fg = if (isSelected) c.primary else c.textSecondary
            val borderCol = c.primary.copy(alpha = if (c.isDark) 0.45f else 0.25f)

            Row(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .let { if (option.testTag != null) it.testTag(option.testTag) else it }
                    .clip(tileShape)
                    .background(bg, tileShape)
                    .then(if (isSelected) Modifier.border(1.dp, borderCol, tileShape) else Modifier)
                    .clickable(role = Role.Tab, onClick = { onChanged(option.value) })
                    .padding(horizontal = 10.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (option.icon != null) {
                    Icon(
                        imageVector = option.icon,
                        contentDescription = null,
                        tint = fg,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                }
                Text(
                    text = option.label,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 13.5.sp,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    color = fg,
                )
            }
        }
    }
}

@Composable
fun FeatureEmptyState(
    title: String,
    subtitle: String,
    primaryCtaLabel: String,
    onPrimaryCta: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector = Icons.Rounded.AutoAwesome,
    secondaryCtaLabel: String? = null,
    onSecondaryCta: (() -> Unit)? = null,
) {
    val c = HandelhaTheme.colors
    val cardShape = RoundedCornerShape(24.dp)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(c.surface, cardShape)
            .border(1.dp, c.border, cardShape)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(c.primarySoft),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = c.primary,
                modifier = Modifier.size(30.dp),
            )
        }
        Spacer(Modifier.height(16.dp))
        Text(
            text = title,
            textAlign = TextAlign.Center,
            fontSize = 19.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.textPrimary,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = subtitle,
            textAlign = TextAlign.Center,
            fontSize = 13.5.sp,
            lineHeight = 21.sp,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(20.dp))
        Button(
            onClick = onPrimaryCta,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .testTag("empty_state_primary_cta"),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = c.ctaBackground,
                contentColor = c.ctaForeground,
            ),
        ) {
            Text(
                text = primaryCtaLabel,
                fontSize = 14.5.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        if (secondaryCtaLabel != null && onSecondaryCta != null) {
            Spacer(Modifier.height(8.dp))
            TextButton(
                onClick = onSecondaryCta,
                modifier = Modifier.testTag("empty_state_secondary_cta"),
            ) {
                Text(
                    text = secondaryCtaLabel,
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
        }
    }
}

@Composable
fun AuthLabeledField(
    label: String,
    hint: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    errorText: String? = null,
    obscureText: Boolean = false,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    trailing: (@Composable () -> Unit)? = null,
    testTag: String? = null,
) {
    val c = HandelhaTheme.colors
    val fieldBg = if (c.isDark) c.surfaceSoft else Color(0xFFFAFBF9)
    val shape = RoundedCornerShape(18.dp)

    Column(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(shape)
                .background(fieldBg, shape)
                .border(
                    width = 1.dp,
                    color = if (errorText != null) c.danger else c.border,
                    shape = shape,
                )
                .padding(horizontal = 16.dp, vertical = 11.dp),
        ) {
            Text(
                text = label,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(5.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(modifier = Modifier.weight(1f)) {
                    if (value.isEmpty()) {
                        Text(
                            text = hint,
                            fontSize = 14.5.sp,
                            color = c.textSecondary.copy(alpha = 0.70f),
                        )
                    }
                    BasicTextField(
                        value = value,
                        onValueChange = onValueChange,
                        singleLine = true,
                        visualTransformation = if (obscureText) PasswordVisualTransformation() else VisualTransformation.None,
                        keyboardOptions = keyboardOptions,
                        keyboardActions = keyboardActions,
                        cursorBrush = SolidColor(c.primary),
                        textStyle = TextStyle(
                            fontFamily = IbmPlexSansArabic,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium,
                            color = c.textPrimary,
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .let { if (testTag != null) it.testTag(testTag) else it },
                    )
                }
                if (trailing != null) {
                    Spacer(Modifier.width(8.dp))
                    trailing()
                }
            }
        }
        if (errorText != null) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = errorText,
                fontSize = 11.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = c.danger,
                modifier = Modifier.padding(horizontal = 6.dp),
            )
        }
    }
}

@Composable
fun HandelhaConfirmDialog(
    icon: ImageVector,
    title: String,
    message: String,
    confirmLabel: String,
    cancelLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    isDanger: Boolean = false,
) {
    val c = HandelhaTheme.colors
    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(26.dp))
                .background(c.surface, RoundedCornerShape(26.dp))
                .border(1.dp, c.border, RoundedCornerShape(26.dp))
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(if (isDanger) c.dangerSoft else c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = if (isDanger) c.danger else c.primary,
                    modifier = Modifier.size(26.dp),
                )
            }
            Spacer(Modifier.height(14.dp))
            Text(
                text = title,
                textAlign = TextAlign.Center,
                fontSize = 18.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = message,
                textAlign = TextAlign.Center,
                fontSize = 13.5.sp,
                lineHeight = 20.sp,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(20.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                OutlinedButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("confirm_dialog_cancel"),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Text(cancelLabel, fontWeight = FontWeight.Bold, color = c.textPrimary)
                }
                Button(
                    onClick = onConfirm,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("confirm_dialog_ok"),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isDanger) c.danger else c.primary,
                        contentColor = Color.White,
                    ),
                ) {
                    Text(confirmLabel, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HandelhaBottomSheetFrame(
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    val c = HandelhaTheme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = c.surface,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(top = 12.dp, bottom = 6.dp)
                    .width(42.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(c.border),
            )
        },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding()
                .padding(start = 20.dp, end = 20.dp, bottom = 22.dp),
            content = content,
        )
    }
}

@Composable
fun HandelhaPrivacyPolicySheet(
    isEnglish: Boolean,
    onDismiss: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val clauses = if (isEnglish) {
        listOf(
            "1. Local-First Data Storage" to "Your tasks, projects, focus sessions, notes, exam grades, and assistant conversations are stored locally on your device inside encrypted/sandboxed app storage and are not uploaded or sold to external servers.",
            "2. Optional Device Permissions" to "Notifications (Android 13+) are only used for reminders you schedule. Microphone access is strictly used when you tap the voice input button in the Assistant.",
            "3. Account Deletion & Backup" to "You can export a complete JSON backup anytime or permanently erase your account and all associated local records from Settings > Privacy & Data.",
            "4. Subscriptions & Auto-Renewal" to "Student and Pro plans are processed through Google Play Billing. Plans renew automatically unless canceled at least 24 hours before the renewal date in Google Play > Subscriptions.",
            "5. Calm Productivity Disclaimer" to "Handelha is a planning and focus companion and does not provide medical, legal, or psychological diagnosis.",
        )
    } else {
        listOf(
            "١. تخزين البيانات محليًا أولًا" to "يتم حفظ مهامك ومشروعاتك وجلسات التركيز وتقديرات الامتحانات ومحادثات المساعد محليًا على جهازك فقط، ولا يتم رفعها أو بيعها لأي طرف ثالث.",
            "٢. الأذونات الاختيارية" to "إذن الإشعارات يُستخدم فقط لتذكيراتك ومواعيدك المجدولة، وإذن الميكروفون لا يُستخدم إلا عند ضغطك على زر الصوت داخل المساعد.",
            "٣. حذف الحساب والنسخ الاحتياطي" to "يمكنك تصدير نسخة احتياطية كاملة بصيغة JSON أو حذف حسابك وكافة بياناته نهائيًا من الإعدادات > الخصوصية والبيانات في أي وقت.",
            "٤. الاشتراكات والتجديد التلقائي" to "تتم معالجة باقات الطلاب و Pro عبر Google Play Billing وتُجدد تلقائيًا ما لم يتم الإلغاء قبل ٢٤ ساعة من انتهاء الدورة من Google Play > الاشتراكات.",
            "٥. حدود الاستخدام والدعم" to "هندلها أداة تنظيم وتركيز يومية ولا يغني عن الاستشارة الطبية أو المتخصصة.",
        )
    }

    HandelhaBottomSheetFrame(onDismiss = onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.Policy, null, tint = c.primary)
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) "Privacy Policy & Terms of Use" else "سياسة الخصوصية وشروط الاستخدام",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Text(
                    text = if (isEnglish) "Handelha App • Transparent & Local-First" else "تطبيق هندلها • شفافية كاملة وبياناتك على جهازك",
                    fontSize = 12.sp,
                    color = c.textSecondary,
                )
            }
            IconButton(onClick = onDismiss) {
                Icon(Icons.Rounded.Close, if (isEnglish) "Close" else "إغلاق", tint = c.textMuted)
            }
        }
        Spacer(Modifier.height(14.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .height(340.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            clauses.forEach { (title, body) ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(c.surfaceSoft, RoundedCornerShape(16.dp))
                        .border(1.dp, c.border, RoundedCornerShape(16.dp))
                        .padding(14.dp),
                ) {
                    Text(
                        text = title,
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.primary,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = body,
                        fontSize = 12.5.sp,
                        lineHeight = 19.sp,
                        color = c.textSecondary,
                    )
                }
            }
        }
        Spacer(Modifier.height(14.dp))
        Button(
            onClick = onDismiss,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .testTag("privacy_sheet_close"),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
        ) {
            Text(if (isEnglish) "Got it" else "فهمت", fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun HandelhaSocialAuthSheet(
    provider: AuthProviderType,
    isEnglish: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (email: String, displayName: String) -> Unit,
) {
    val c = HandelhaTheme.colors
    val isGoogle = provider == AuthProviderType.google
    val providerNameAr = if (isGoogle) "جوجل" else "فيسبوك"
    val providerNameEn = if (isGoogle) "Google" else "Facebook"
    val brandColor = if (isGoogle) Color(0xFF4285F4) else Color(0xFF1877F2)

    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var errorMsg by remember { mutableStateOf<String?>(null) }

    HandelhaBottomSheetFrame(onDismiss = onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(42.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(brandColor.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (isGoogle) "G" else "f",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Black,
                    color = brandColor,
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) "Continue with $providerNameEn" else "المتابعة باستخدام $providerNameAr",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Text(
                    text = if (isEnglish) "Sign in quickly to organize your day" else "سجّل دخولك بسرعة وابدأ تنظيم يومك",
                    fontSize = 12.5.sp,
                    color = c.textSecondary,
                )
            }
            IconButton(onClick = onDismiss) {
                Icon(Icons.Rounded.Close, if (isEnglish) "Close" else "إغلاق", tint = c.textMuted)
            }
        }
        Spacer(Modifier.height(16.dp))
        AuthLabeledField(
            label = if (isEnglish) "Name" else "الاسم",
            hint = if (isEnglish) "Your display name" else "اسمك في التطبيق",
            value = name,
            onValueChange = { name = it },
            testTag = "social_name_input",
        )
        Spacer(Modifier.height(10.dp))
        AuthLabeledField(
            label = if (isEnglish) "$providerNameEn Email" else "البريد الإلكتروني لحساب $providerNameAr",
            hint = if (isGoogle) "name@gmail.com" else "name@example.com",
            value = email,
            onValueChange = { email = it; errorMsg = null },
            errorText = errorMsg,
            testTag = "social_email_input",
        )
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = {
                val trimmedEmail = email.trim().ifEmpty {
                    if (isGoogle) "user@gmail.com" else "user@facebook.com"
                }
                if (!Regex("""^[\w.\-+]+@[\w\-]+\.\w{2,}$""").matches(trimmedEmail)) {
                    errorMsg = if (isEnglish) "Enter a valid email address." else "أدخل بريدًا إلكترونيًا صالحًا."
                    return@Button
                }
                val cleanName = name.trim().ifEmpty { if (isEnglish) "Handelha User" else "مستخدم هندلها" }
                onConfirm(trimmedEmail, cleanName)
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp)
                .testTag("social_confirm_button"),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = brandColor, contentColor = Color.White),
        ) {
            Text(
                text = if (isEnglish) "Continue with $providerNameEn" else "المتابعة باستخدام $providerNameAr",
                fontSize = 15.sp,
                fontWeight = FontWeight.ExtraBold,
            )
        }
    }
}

@Composable
fun EnergyPreferencesWizardSheet(
    initial: UserEnergyPreferences,
    isEnglish: Boolean,
    onDismiss: () -> Unit,
    onSave: (UserEnergyPreferences) -> Unit,
) {
    val c = HandelhaTheme.colors
    var step by remember { mutableIntStateOf(0) }
    var prefs by remember { mutableStateOf(initial) }

    HandelhaBottomSheetFrame(onDismiss = onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(13.dp))
                    .background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    painter = painterResource(id = R.drawable.logo),
                    contentDescription = if (isEnglish) "Handelha Logo" else "شعار هندلها",
                    modifier = Modifier.size(28.dp),
                    contentScale = ContentScale.Fit,
                )
            }
            Spacer(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) "Your Energy & Focus Profile" else "بصمة طاقتك وأسلوب تركيزك",
                    fontSize = 16.5.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Text(
                    text = if (isEnglish) "Step ${step + 1} of 3" else "خطوة ${ArabicFormatters.toArabicDigits(step + 1)} من ٣",
                    fontSize = 12.sp,
                    color = c.primary,
                    fontWeight = FontWeight.Bold,
                )
            }
            IconButton(onClick = onDismiss) {
                Icon(Icons.Rounded.Close, if (isEnglish) "Close" else "إغلاق", tint = c.textMuted)
            }
        }
        Spacer(Modifier.height(14.dp))
        when (step) {
            0 -> {
                Text(
                    text = if (isEnglish) "When do you feel most mentally sharp?" else "إمتى بتكون في أعلى تركيز وطاقة في يومك؟",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textPrimary,
                )
                Spacer(Modifier.height(12.dp))
                val choices = listOf(
                    Triple("morning", if (isEnglish) "Morning (8 AM – 3 PM)" else "صباحي (٨ ص – ٣ م)", if (isEnglish) "Best for early heavy focus" else "أنسب للشغل التقيل بدري"),
                    Triple("afternoon", if (isEnglish) "Afternoon (12 PM – 7 PM)" else "بعد الظهر (١٢ م – ٧ م)", if (isEnglish) "Balanced midday rhythm" else "إيقاع متوازن في نص اليوم"),
                    Triple("evening", if (isEnglish) "Evening (5 PM – 11 PM)" else "مسائي (٥ م – ١١ م)", if (isEnglish) "Quiet night owl deep work" else "هدوء الليل والتركيز العميق"),
                )
                choices.forEach { (key, title, sub) ->
                    val sel = prefs.peakEnergyPeriod == key
                    WizardOptionTile(
                        title = title,
                        subtitle = sub,
                        selected = sel,
                        onClick = { prefs = prefs.copy(peakEnergyPeriod = key) },
                    )
                    Spacer(Modifier.height(8.dp))
                }
            }
            1 -> {
                Text(
                    text = if (isEnglish) "Preferred focus block length?" else "مدة جلسة التركيز المفضلة ليك إيه؟",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textPrimary,
                )
                Spacer(Modifier.height(12.dp))
                listOf(
                    25 to (if (isEnglish) "25 minutes — Quick calm sprint" else "٢٥ دقيقة — سبرنت هادئ وسريع"),
                    45 to (if (isEnglish) "45 minutes — Balanced deep block" else "٤٥ دقيقة — توازن مثالي للإنجاز"),
                    60 to (if (isEnglish) "60 minutes — Extended immersion" else "٦٠ دقيقة — غوص عميق بدون مقاطعة"),
                ).forEach { (mins, label) ->
                    WizardOptionTile(
                        title = label,
                        subtitle = if (isEnglish) "Tasks & projects split into ~${mins}m steps" else "المهام تتقسم تلقائيًا لخطوات ~${ArabicFormatters.toArabicDigits(mins)} دقيقة",
                        selected = prefs.preferredSessionMinutes == mins,
                        onClick = { prefs = prefs.copy(preferredSessionMinutes = mins) },
                    )
                    Spacer(Modifier.height(8.dp))
                }
            }
            else -> {
                Text(
                    text = if (isEnglish) "How do you like starting heavy work?" else "بتحب تبدأ إزاي في المهام الكبيرة؟",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textPrimary,
                )
                Spacer(Modifier.height(12.dp))
                WizardOptionTile(
                    title = if (isEnglish) "Hardest at Peak Energy" else "الأصعب في قمة طاقتي",
                    subtitle = if (isEnglish) "Tackle priority items when sharp" else "نحط أهم وأصعب خطوة في ذروة يومك",
                    selected = prefs.hardTaskStrategy == "peak_first",
                    onClick = { prefs = prefs.copy(hardTaskStrategy = "peak_first") },
                )
                Spacer(Modifier.height(8.dp))
                WizardOptionTile(
                    title = if (isEnglish) "Easy Warm-up First" else "تسخين بمهمة خفيفة أولًا",
                    subtitle = if (isEnglish) "Build gentle momentum before deep work" else "تبدأ بحاجة خفيفة تفتح نفسك للشغل",
                    selected = prefs.hardTaskStrategy == "warmup_first",
                    onClick = { prefs = prefs.copy(hardTaskStrategy = "warmup_first") },
                )
            }
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (step > 0) {
                OutlinedButton(
                    onClick = { step-- },
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Text(if (isEnglish) "Back" else "السابق", fontWeight = FontWeight.Bold)
                }
            }
            Button(
                onClick = {
                    if (step < 2) step++ else onSave(prefs.copy(completedWizard = true))
                },
                modifier = Modifier.weight(1f).height(48.dp).testTag("energy_wizard_next"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Text(
                    text = if (step < 2) (if (isEnglish) "Next" else "التالي") else (if (isEnglish) "Save Profile" else "حفظ بصمة الطاقة"),
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun WizardOptionTile(
    title: String,
    subtitle: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(if (selected) c.primarySoft else c.surfaceSoft, shape)
            .border(1.2.dp, if (selected) c.primary else c.border, shape)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold, color = c.textPrimary)
            Spacer(Modifier.height(2.dp))
            Text(subtitle, fontSize = 12.sp, color = c.textSecondary)
        }
        if (selected) {
            Box(
                modifier = Modifier.size(24.dp).clip(CircleShape).background(c.primary),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.Check, null, tint = c.textOnPrimary, modifier = Modifier.size(15.dp))
            }
        }
    }
}
