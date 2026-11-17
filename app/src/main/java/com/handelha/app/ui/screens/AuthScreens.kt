package com.handelha.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.CheckCircleOutline
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.LockReset
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.R
import com.handelha.app.domain.AuthProviderType
import com.handelha.app.ui.components.AuthLabeledField
import com.handelha.app.ui.components.HandelhaPrivacyPolicySheet
import com.handelha.app.ui.components.HandelhaSegmentOption
import com.handelha.app.ui.components.HandelhaSegmentedSwitch
import com.handelha.app.ui.components.HandelhaSocialAuthSheet
import com.handelha.app.ui.theme.HandelhaTheme

@Composable
fun AuthFlowScreen(
    isEnglish: Boolean,
    isLoading: Boolean,
    onToggleLanguage: () -> Unit,
    onSignInEmail: (email: String, password: String, onDone: (Boolean, String?) -> Unit) -> Unit,
    onSignUpEmail: (email: String, password: String, name: String?, onDone: (Boolean, String?) -> Unit) -> Unit,
    onSocialSignIn: (provider: AuthProviderType, email: String, name: String, onDone: (Boolean, String?) -> Unit) -> Unit,
    onResetPassword: (email: String, newPassword: String, onDone: (Boolean, String?) -> Unit) -> Unit,
    onShowToast: (String, Boolean) -> Unit,
    onBackToOnboarding: () -> Unit = {},
) {
    var isSignUpMode by remember { mutableStateOf(false) }
    var showForgotPassword by remember { mutableStateOf(false) }
    var showPrivacySheet by remember { mutableStateOf(false) }
    var pendingSocialProvider by remember { mutableStateOf<AuthProviderType?>(null) }

    if (showForgotPassword) {
        ForgotPasswordView(
            isEnglish = isEnglish,
            isLoading = isLoading,
            onBack = { showForgotPassword = false },
            onReset = { email, newPw, cb ->
                onResetPassword(email, newPw) { ok, err ->
                    cb(ok, err)
                }
            },
            onShowToast = onShowToast,
        )
        return
    }

    val c = HandelhaTheme.colors
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var obscurePassword by remember { mutableStateOf(true) }

    var emailErr by remember { mutableStateOf<String?>(null) }
    var pwErr by remember { mutableStateOf<String?>(null) }
    var serverErr by remember { mutableStateOf<String?>(null) }

    fun validateAndSubmit() {
        val cleanEmail = email.trim()
        val emailOk = Regex("""^[\w.\-+]+@[\w\-]+\.\w{2,}$""").matches(cleanEmail)
        emailErr = if (!emailOk) {
            if (isEnglish) "Enter a valid email address" else "أدخل بريدًا إلكترونيًا صالحًا"
        } else {
            null
        }
        pwErr = when {
            password.length < 8 -> if (isEnglish) "At least 8 characters" else "٨ أحرف على الأقل"
            isSignUpMode && (!Regex("[A-Za-z]").containsMatchIn(password) || !Regex("\\d").containsMatchIn(password)) ->
                if (isEnglish) "Include letters and numbers" else "استخدم حروفًا وأرقامًا معًا"
            else -> null
        }
        if (emailErr != null || pwErr != null) return

        serverErr = null
        if (isSignUpMode) {
            onSignUpEmail(cleanEmail, password, name.trim().ifBlank { null }) { ok, err ->
                if (!ok) serverErr = err
            }
        } else {
            onSignInEmail(cleanEmail, password) { ok, err ->
                if (!ok) serverErr = err
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.statusBars)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, top = 8.dp, end = 20.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Top navigation strip matching Flutter login_screen.dart / signup_screen.dart
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(
                onClick = {
                    if (isSignUpMode) {
                        isSignUpMode = false
                    } else {
                        onBackToOnboarding()
                    }
                },
                modifier = Modifier.testTag("auth_back_button"),
            ) {
                Icon(
                    imageVector = if (isEnglish) Icons.Rounded.ChevronLeft else Icons.Rounded.ChevronRight,
                    contentDescription = if (isEnglish) "Back" else "رجوع",
                    tint = c.primary,
                    modifier = Modifier.size(28.dp),
                )
            }

            Spacer(Modifier.weight(1f))

            TextButton(
                onClick = onToggleLanguage,
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                modifier = Modifier.testTag("auth_lang_button"),
            ) {
                Icon(
                    imageVector = Icons.Rounded.Language,
                    contentDescription = null,
                    tint = c.primary,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(5.dp))
                Text(
                    text = if (isEnglish) "عربي" else "EN",
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }

            Spacer(Modifier.width(4.dp))

            Text(
                text = if (isSignUpMode) {
                    if (isEnglish) "New Account" else "حساب جديد"
                } else {
                    if (isEnglish) "Sign In" else "تسجيل الدخول"
                },
                fontSize = 13.5.sp,
                fontWeight = FontWeight.Medium,
                color = c.textSecondary,
            )
        }

        Spacer(Modifier.height(10.dp))

        // Brand Hero: 72dp logo + "هندلها" + headline + subtitle
        Image(
            painter = painterResource(id = R.drawable.logo),
            contentDescription = if (isEnglish) "Handelha" else "هندلها",
            modifier = Modifier.size(72.dp),
            contentScale = ContentScale.Fit,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = if (isEnglish) "Handelha" else "هندلها",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = c.primary,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = if (isSignUpMode) {
                if (isEnglish) "Let's get to know you" else "خلّينا نتعرف عليك"
            } else {
                if (isEnglish) "Welcome back! Ready to continue?" else "وحشتنا! نكمّل منين؟"
            },
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = c.textPrimary,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = if (isSignUpMode) {
                if (isEnglish) "One simple step, and your day starts organizing itself."
                else "خطوة بسيطة، ويومك يبدأ يرتّب نفسه."
            } else {
                if (isEnglish) "Sign in to your account — your next step is waiting."
                else "ادخل لحسابك، وخطوتك الجاية مستنياك."
            },
            fontSize = 13.sp,
            color = c.textSecondary,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(18.dp))

        // Main Card (28.dp radius, 18.dp padding, c.surface, border c.border)
        val cardShape = RoundedCornerShape(28.dp)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (c.isDark) Modifier
                    else Modifier.shadow(
                        elevation = 16.dp,
                        shape = cardShape,
                        ambientColor = Color.Black.copy(alpha = 0.05f),
                        spotColor = Color.Black.copy(alpha = 0.05f),
                    ),
                )
                .clip(cardShape)
                .background(c.surface, cardShape)
                .border(1.dp, c.border, cardShape)
                .padding(18.dp),
        ) {
            HandelhaSegmentedSwitch(
                options = listOf(
                    HandelhaSegmentOption(
                        value = false,
                        label = if (isEnglish) "Sign In" else "تسجيل الدخول",
                        testTag = "auth_tab_login",
                    ),
                    HandelhaSegmentOption(
                        value = true,
                        label = if (isEnglish) "Create Account" else "إنشاء حساب",
                        testTag = "auth_tab_signup",
                    ),
                ),
                selected = isSignUpMode,
                onChanged = {
                    isSignUpMode = it
                    serverErr = null
                    emailErr = null
                    pwErr = null
                },
            )

            Spacer(Modifier.height(16.dp))

            // Social buttons row (Google + Facebook) matching _SocialButton in login_screen.dart / signup_screen.dart
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                SocialAuthButton(
                    label = if (isEnglish) "Google" else "جوجل",
                    isFacebook = false,
                    onClick = { pendingSocialProvider = AuthProviderType.google },
                    modifier = Modifier.weight(1f).testTag("auth_google_btn"),
                )
                SocialAuthButton(
                    label = if (isEnglish) "Facebook" else "فيسبوك",
                    isFacebook = true,
                    onClick = { pendingSocialProvider = AuthProviderType.facebook },
                    modifier = Modifier.weight(1f).testTag("auth_facebook_btn"),
                )
            }

            Spacer(Modifier.height(16.dp))

            // Divider with "أو بالبريد الإلكتروني"
            Row(verticalAlignment = Alignment.CenterVertically) {
                HorizontalDivider(modifier = Modifier.weight(1f), color = c.border)
                Text(
                    text = if (isEnglish) "Or with email" else "أو بالبريد الإلكتروني",
                    fontSize = 12.sp,
                    color = c.textSecondary,
                    modifier = Modifier.padding(horizontal = 10.dp),
                )
                HorizontalDivider(modifier = Modifier.weight(1f), color = c.border)
            }

            Spacer(Modifier.height(14.dp))

            if (isSignUpMode) {
                AuthLabeledField(
                    label = if (isEnglish) "Your Name" else "اسمك",
                    hint = if (isEnglish) "What should we call you?" else "تحب نناديك بإيه؟",
                    value = name,
                    onValueChange = { name = it },
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                    testTag = "auth_name_input",
                )
                Spacer(Modifier.height(12.dp))
            }

            AuthLabeledField(
                label = if (isEnglish) "Email Address" else "البريد الإلكتروني",
                hint = "name@example.com",
                value = email,
                onValueChange = { email = it; emailErr = null; serverErr = null },
                errorText = emailErr,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                testTag = "auth_email_input",
            )
            Spacer(Modifier.height(12.dp))

            AuthLabeledField(
                label = if (isEnglish) "Password" else "كلمة السر",
                hint = "••••••••••",
                value = password,
                onValueChange = { password = it; pwErr = null; serverErr = null },
                errorText = pwErr,
                obscureText = obscurePassword,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                trailing = {
                    Icon(
                        imageVector = if (obscurePassword) Icons.Rounded.Visibility else Icons.Rounded.VisibilityOff,
                        contentDescription = if (isEnglish) "Toggle password" else "إظهار كلمة السر",
                        tint = c.textSecondary,
                        modifier = Modifier
                            .size(20.dp)
                            .clickable { obscurePassword = !obscurePassword },
                    )
                },
                testTag = "auth_password_input",
            )

            if (!isSignUpMode) {
                Spacer(Modifier.height(8.dp))
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterStart) {
                    TextButton(
                        onClick = { showForgotPassword = true },
                        contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp),
                        modifier = Modifier.testTag("auth_forgot_password"),
                    ) {
                        Text(
                            text = if (isEnglish) "Forgot password?" else "نسيت كلمة السر؟",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = c.primary,
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
            } else {
                Spacer(Modifier.height(16.dp))
            }

            if (serverErr != null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(c.dangerSoft)
                        .padding(10.dp),
                ) {
                    Text(
                        text = serverErr!!,
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.danger,
                    )
                }
                Spacer(Modifier.height(10.dp))
            }

            Button(
                onClick = ::validateAndSubmit,
                enabled = !isLoading,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .testTag("auth_submit_button"),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = c.primary,
                    contentColor = c.textOnPrimary,
                ),
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(22.dp),
                        color = c.textOnPrimary,
                        strokeWidth = 2.2.dp,
                    )
                } else {
                    Row(
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = if (isSignUpMode) {
                                if (isEnglish) "Create Account" else "إنشاء حساب"
                            } else {
                                if (isEnglish) "Sign In" else "تسجيل الدخول"
                            },
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                        )
                        Spacer(Modifier.width(8.dp))
                        Icon(
                            imageVector = Icons.AutoMirrored.Rounded.ArrowForward,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                TextButton(
                    onClick = {
                        isSignUpMode = !isSignUpMode
                        serverErr = null
                        emailErr = null
                        pwErr = null
                    },
                    modifier = Modifier.testTag("auth_switch_mode_btn"),
                ) {
                    Text(
                        text = if (isSignUpMode) {
                            if (isEnglish) "Already have an account? Sign in" else "عندك حساب؟ سجّل دخول"
                        } else {
                            if (isEnglish) "First time here? Create an account" else "أول مرة هنا؟ اعمل حساب"
                        },
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.primary,
                    )
                }
            }

            Spacer(Modifier.height(4.dp))

            Text(
                text = if (isEnglish) {
                    "By continuing, you agree to the Terms of Use & Privacy Policy."
                } else {
                    "بالمتابعة، إنت موافق على شروط الاستخدام والخصوصية."
                },
                fontSize = 11.5.sp,
                color = c.textSecondary,
                textAlign = TextAlign.Center,
                textDecoration = TextDecoration.Underline,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .clickable { showPrivacySheet = true }
                    .padding(vertical = 4.dp)
                    .testTag("auth_privacy_link"),
            )
        }
    }

    if (pendingSocialProvider != null) {
        val prov = pendingSocialProvider!!
        HandelhaSocialAuthSheet(
            provider = prov,
            isEnglish = isEnglish,
            onDismiss = { pendingSocialProvider = null },
            onConfirm = { sEmail, sName ->
                pendingSocialProvider = null
                onSocialSignIn(prov, sEmail, sName) { ok, err ->
                    if (!ok && err != null) onShowToast(err, true)
                }
            },
        )
    }

    if (showPrivacySheet) {
        HandelhaPrivacyPolicySheet(
            isEnglish = isEnglish,
            onDismiss = { showPrivacySheet = false },
        )
    }
}

@Composable
private fun SocialAuthButton(
    label: String,
    isFacebook: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = modifier
            .height(48.dp)
            .clip(shape)
            .background(c.surface, shape)
            .border(1.dp, c.border, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isFacebook) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF1877F2)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "f",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
            }
        } else {
            Text(
                text = "G",
                fontSize = 18.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color(0xFF4285F4),
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(
            text = label,
            fontSize = 13.5.sp,
            fontWeight = FontWeight.SemiBold,
            color = c.textPrimary,
        )
    }
}

@Composable
private fun ForgotPasswordView(
    isEnglish: Boolean,
    isLoading: Boolean,
    onBack: () -> Unit,
    onReset: (email: String, newPassword: String, cb: (Boolean, String?) -> Unit) -> Unit,
    onShowToast: (String, Boolean) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    var email by remember { mutableStateOf("") }
    var newPw by remember { mutableStateOf("") }
    var sent by remember { mutableStateOf(false) }
    var err by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.statusBars)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, top = 8.dp, end = 20.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = if (isEnglish) Icons.Rounded.ChevronLeft else Icons.Rounded.ChevronRight,
                    contentDescription = if (isEnglish) "Back" else "رجوع",
                    tint = c.primary,
                    modifier = Modifier.size(28.dp),
                )
            }
            Spacer(Modifier.weight(1f))
            Text(
                text = if (isEnglish) "Forgot Password" else "نسيت كلمة السر",
                fontSize = 13.5.sp,
                fontWeight = FontWeight.Medium,
                color = c.textSecondary,
            )
        }

        Spacer(Modifier.height(24.dp))

        Box(
            modifier = Modifier
                .size(88.dp)
                .clip(CircleShape)
                .background(if (c.isDark) c.surfaceSoft else c.primarySoft),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Rounded.LockReset,
                contentDescription = null,
                tint = c.primary,
                modifier = Modifier.size(40.dp),
            )
        }

        Spacer(Modifier.height(16.dp))

        Text(
            text = if (isEnglish) "No worries, it happens" else "ولا يهمك، بتحصل",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = c.textPrimary,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = if (isEnglish) "Enter your email and choose a new password to recover your account."
            else "اكتب إيميلك وهنبعتلك رابط ترجّع بيه حسابك.",
            fontSize = 13.5.sp,
            color = c.textSecondary,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(24.dp))

        val cardShape = RoundedCornerShape(28.dp)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(cardShape)
                .background(c.surface, cardShape)
                .border(1.dp, c.border, cardShape)
                .padding(20.dp),
        ) {
            AuthLabeledField(
                label = if (isEnglish) "Email Address" else "البريد الإلكتروني",
                hint = "name@example.com",
                value = email,
                onValueChange = { email = it; err = null; sent = false },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                testTag = "forgot_email_input",
            )
            Spacer(Modifier.height(12.dp))
            AuthLabeledField(
                label = if (isEnglish) "New Password (optional for instant local reset)" else "كلمة السر الجديدة (للاستعادة الفورية على الجهاز)",
                hint = "••••••••••",
                value = newPw,
                onValueChange = { newPw = it; err = null },
                obscureText = true,
                errorText = err,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                testTag = "forgot_password_input",
            )

            Spacer(Modifier.height(18.dp))

            Button(
                onClick = {
                    val clean = email.trim()
                    if (!clean.contains("@")) {
                        err = if (isEnglish) "Please enter a valid email address" else "من فضلك اكتب بريد إلكتروني صحيح"
                        return@Button
                    }
                    if (newPw.isNotEmpty() && newPw.length >= 8) {
                        onReset(clean, newPw) { ok, message ->
                            if (ok) {
                                sent = true
                                onShowToast(if (isEnglish) "Password updated!" else "تم تحديث كلمة السر بنجاح!", false)
                                onBack()
                            } else {
                                err = message
                            }
                        }
                    } else {
                        sent = true
                        onShowToast(
                            if (isEnglish) "Recovery link sent if the email is registered."
                            else "لو البريد مسجل عندنا، هيوصلك رابط الاستعادة خلال لحظات.",
                            false,
                        )
                    }
                },
                enabled = !isLoading,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .testTag("forgot_submit_button"),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = c.primary,
                    contentColor = c.textOnPrimary,
                ),
            ) {
                Row(
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = if (isEnglish) "Send Recovery Link" else "ابعت رابط الاستعادة",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Spacer(Modifier.width(8.dp))
                    Icon(
                        imageVector = Icons.AutoMirrored.Rounded.ArrowForward,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            if (sent) {
                Spacer(Modifier.height(14.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(c.primarySoft)
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Rounded.CheckCircleOutline,
                        contentDescription = null,
                        tint = c.primary,
                        modifier = Modifier.size(20.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = if (isEnglish) "If this email is registered, you will receive a recovery link shortly."
                        else "لو البريد مسجل عندنا، هيوصلك رابط الاستعادة خلال لحظات.",
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.primary,
                    )
                }
            }

            Spacer(Modifier.height(10.dp))

            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                TextButton(onClick = onBack) {
                    Text(
                        text = if (isEnglish) "Back to Sign In" else "رجوع لتسجيل الدخول",
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.primary,
                    )
                }
            }
        }
    }
}
