package com.handelha.app.ui.screens

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.R
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters
import kotlinx.coroutines.launch

@Composable
fun SplashScreen(isEnglish: Boolean) {
    val c = HandelhaTheme.colors
    val infinite = rememberInfiniteTransition(label = "splash")
    val progress by infinite.animateFloat(
        initialValue = 0.25f,
        targetValue = 0.92f,
        animationSpec = infiniteRepeatable(tween(1500, easing = LinearEasing), RepeatMode.Reverse),
        label = "progress",
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.statusBars)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(horizontal = 24.dp, vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))

        // Concentric circles + floating chips matching lib/shared/widgets/splash_screen.dart
        Box(
            modifier = Modifier.size(274.dp),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(256.dp)
                    .clip(CircleShape)
                    .border(1.dp, c.primary.copy(alpha = 0.14f), CircleShape),
            )
            Box(
                modifier = Modifier
                    .size(206.dp)
                    .clip(CircleShape)
                    .border(1.dp, c.primary.copy(alpha = 0.24f), CircleShape),
            )
            Box(
                modifier = Modifier
                    .size(158.dp)
                    .clip(CircleShape)
                    .background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    painter = painterResource(id = R.drawable.logo),
                    contentDescription = if (isEnglish) "Handelha Logo" else "شعار هندلها",
                    modifier = Modifier.size(108.dp),
                    contentScale = ContentScale.Fit,
                )
            }

            // Top-End Chip ("فكرة")
            SplashFloatingChip(
                label = if (isEnglish) "Idea" else "فكرة",
                textColor = c.primary,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = (-10).dp, y = 26.dp),
            )

            // Center-Start Chip ("خطوة")
            SplashFloatingChip(
                label = if (isEnglish) "Step" else "خطوة",
                textColor = c.secondary,
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .offset(x = 6.dp, y = (-4).dp),
            )

            // Bottom-End Chip ("إنجاز")
            SplashFloatingChip(
                label = if (isEnglish) "Done" else "إنجاز",
                textColor = c.accent,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = (-22).dp, y = (-26).dp),
            )
        }

        Spacer(Modifier.height(14.dp))
        Text(
            text = if (isEnglish) "Handelha" else "هندلها",
            fontSize = 40.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.primary,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = if (isEnglish) "Your day made simpler, step by step." else "يومك أبسط، خطوة بخطوة.",
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = c.textSecondary,
        )

        Spacer(Modifier.weight(1f))

        // Bottom loading card matching splash_screen.dart
        val bottomShape = RoundedCornerShape(24.dp)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!c.isDark) Modifier.shadow(10.dp, bottomShape, ambientColor = Color.Black.copy(alpha = 0.05f))
                    else Modifier,
                )
                .clip(bottomShape)
                .background(c.surface, bottomShape)
                .border(1.dp, c.border, bottomShape)
                .padding(horizontal = 20.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = if (isEnglish) "Preparing your space..." else "بنجهّز مساحتك...",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (isEnglish) "Your tasks, ideas, and time for yourself." else "مهامك، أفكارك، ووقت لنفسك.",
                fontSize = 12.5.sp,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(14.dp))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(5.dp)
                    .clip(RoundedCornerShape(999.dp)),
                color = c.primary,
                trackColor = c.primarySoft,
            )
        }
    }
}

@Composable
private fun SplashFloatingChip(
    label: String,
    textColor: Color,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(999.dp)
    Box(
        modifier = modifier
            .shadow(10.dp, shape, ambientColor = Color.Black.copy(alpha = 0.06f))
            .clip(shape)
            .background(c.surface, shape)
            .border(1.dp, c.border, shape)
            .padding(horizontal = 16.dp, vertical = 7.dp),
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = textColor,
        )
    }
}

@Composable
fun OnboardingScreen(
    isEnglish: Boolean,
    onToggleLanguage: () -> Unit,
    onFinishOnboarding: () -> Unit,
) {
    val c = HandelhaTheme.colors
    val pagerState = rememberPagerState(pageCount = { 2 })
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.statusBars)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(horizontal = 24.dp, vertical = 14.dp),
    ) {
        // Top Header: Brand Logo + Wordmark + Language + Step badge
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(12.dp))
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
            Text(
                text = if (isEnglish) "Handelha" else "هندلها",
                fontSize = 22.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.primary,
            )
            Spacer(Modifier.weight(1f))
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(c.surface, RoundedCornerShape(999.dp))
                    .border(1.dp, c.border, RoundedCornerShape(999.dp))
                    .clickable(onClick = onToggleLanguage)
                    .padding(horizontal = 10.dp, vertical = 5.dp)
                    .testTag("onboarding_lang_button"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Language, null, tint = c.primary, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    text = if (isEnglish) "عربي" else "EN",
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
            Spacer(Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(c.primarySoft, RoundedCornerShape(999.dp))
                    .padding(horizontal = 12.dp, vertical = 5.dp),
            ) {
                Text(
                    text = if (isEnglish) "${pagerState.currentPage + 1} of 2" else "${ArabicFormatters.toArabicDigits(pagerState.currentPage + 1)} من ٢",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
        }

        Spacer(Modifier.height(18.dp))

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f),
        ) { page ->
            if (page == 0) {
                OnboardingSlideOne(isEnglish = isEnglish)
            } else {
                OnboardingSlideTwo(isEnglish = isEnglish)
            }
        }

        // Indicator dots matching onboarding_screen.dart
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            repeat(2) { idx ->
                val active = idx == pagerState.currentPage
                Box(
                    modifier = Modifier
                        .padding(horizontal = 4.dp)
                        .width(if (active) 22.dp else 7.dp)
                        .height(7.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (active) c.primary else c.border),
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        Button(
            onClick = {
                if (pagerState.currentPage == 0) {
                    scope.launch { pagerState.animateScrollToPage(1) }
                } else {
                    onFinishOnboarding()
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp)
                .testTag("onboarding_next_button"),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = c.ctaBackground,
                contentColor = c.ctaForeground,
            ),
        ) {
            Text(
                text = if (pagerState.currentPage == 0) {
                    if (isEnglish) "Continue" else "كمّل"
                } else {
                    if (isEnglish) "Start Now" else "ابدأ دلوقتي"
                },
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
            )
        }

        Spacer(Modifier.height(6.dp))

        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            if (pagerState.currentPage == 0) {
                TextButton(onClick = onFinishOnboarding) {
                    Text(
                        text = if (isEnglish) "Skip" else "تخطّي",
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = c.textSecondary,
                    )
                }
            } else {
                TextButton(onClick = { scope.launch { pagerState.animateScrollToPage(0) } }) {
                    Text(
                        text = if (isEnglish) "Back to previous step" else "ارجع خطوة",
                        fontSize = 13.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = c.textSecondary,
                    )
                }
            }
        }
    }
}

@Composable
private fun OnboardingSlideOne(isEnglish: Boolean) {
    val c = HandelhaTheme.colors
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.Start,
    ) {
        // Soft sage container matching _SlideOne in onboarding_screen.dart with Handelha logo
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(c.primarySoft.copy(alpha = 0.72f), RoundedCornerShape(28.dp))
                .border(1.dp, c.border, RoundedCornerShape(28.dp))
                .padding(20.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(
                    painter = painterResource(id = R.drawable.logo),
                    contentDescription = null,
                    modifier = Modifier.size(22.dp),
                    contentScale = ContentScale.Fit,
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = if (isEnglish) "Built for your energy, not against it" else "على قدّك، مش فوق طاقتك",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
            Spacer(Modifier.height(14.dp))
            val innerShape = RoundedCornerShape(20.dp)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (!c.isDark) Modifier.shadow(8.dp, innerShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                        else Modifier,
                    )
                    .clip(innerShape)
                    .background(c.surface, innerShape)
                    .border(1.dp, c.border, innerShape)
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(c.primarySoft),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.logo),
                        contentDescription = null,
                        modifier = Modifier.size(28.dp),
                        contentScale = ContentScale.Fit,
                    )
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Start with the first step" else "ابدأ بأول خطوة",
                        fontSize = 15.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.textPrimary,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = if (isEnglish) "And we'll handle the rest together" else "والباقي هنهندله سوا",
                        fontSize = 12.5.sp,
                        color = c.textSecondary,
                    )
                }
            }
            Spacer(Modifier.height(14.dp))
            val pillShape = RoundedCornerShape(999.dp)
            Box(
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .then(
                        if (!c.isDark) Modifier.shadow(6.dp, pillShape, ambientColor = Color.Black.copy(alpha = 0.04f))
                        else Modifier,
                    )
                    .clip(pillShape)
                    .background(c.surface, pillShape)
                    .border(1.dp, c.border, pillShape)
                    .padding(horizontal = 18.dp, vertical = 8.dp),
            ) {
                Text(
                    text = if (isEnglish) "A small moment for yourself" else "وقت صغير لنفسك",
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = c.secondary,
                )
            }
        }

        Spacer(Modifier.height(28.dp))
        Text(
            text = if (isEnglish) "Your day needs clarity,\nnot extra pressure." else "يومك محتاج ترتيب،\nمش ضغط زيادة.",
            fontSize = 29.sp,
            lineHeight = 38.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.textPrimary,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = if (isEnglish) {
                "Instead of a long overwhelming list, Handelha helps you see what matters now and leave the rest for its time."
            } else {
                "بدل زحمة المهام اللي بتتعبك، هندلها بيساعدك تشوف المهم دلوقتي وتسيب الباقي لوقته."
            },
            fontSize = 15.sp,
            lineHeight = 24.sp,
            color = c.textSecondary,
        )
    }
}

@Composable
private fun OnboardingSlideTwo(isEnglish: Boolean) {
    val c = HandelhaTheme.colors
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.Start,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(c.primarySoft.copy(alpha = 0.72f), RoundedCornerShape(28.dp))
                .border(1.dp, c.border, RoundedCornerShape(28.dp))
                .padding(20.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(c.surface),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.logo),
                        contentDescription = null,
                        modifier = Modifier.size(24.dp),
                        contentScale = ContentScale.Fit,
                    )
                }
                Spacer(Modifier.width(10.dp))
                Text(
                    text = if (isEnglish) "Big idea? Let's break it down together." else "فكرة كبيرة؟ نصغّرها سوا.",
                    fontSize = 13.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                )
            }
            Spacer(Modifier.height(14.dp))
            OnboardingStepPill(
                number = if (isEnglish) "1" else "١",
                label = if (isEnglish) "Pick your priority" else "حدّد أولويتك",
                active = true,
            )
            Spacer(Modifier.height(10.dp))
            OnboardingStepPill(
                number = if (isEnglish) "2" else "٢",
                label = if (isEnglish) "Start with 25 minutes" else "ابدأ بـ ٢٥ دقيقة",
                active = false,
            )
            Spacer(Modifier.height(10.dp))
            OnboardingStepPill(
                number = if (isEnglish) "3" else "٣",
                label = if (isEnglish) "Feel the difference" else "شوف الفرق",
                active = false,
            )
        }

        Spacer(Modifier.height(28.dp))
        Text(
            text = if (isEnglish) "Every small step\nmakes a real difference." else "كل خطوة صغيرة\nبتفرق معاك.",
            fontSize = 29.sp,
            lineHeight = 38.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.textPrimary,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = if (isEnglish) {
                "Break your project into clear tasks, start a calm focus session, and let the assistant help whenever you feel stuck."
            } else {
                "قسّم مشروعك لمهام واضحة، وابدأ جلسة تركيز هادية، وخلّي المساعد يرتّب معاك لما تحس إن الدنيا ملخبطة."
            },
            fontSize = 15.sp,
            lineHeight = 24.sp,
            color = c.textSecondary,
        )
    }
}

@Composable
private fun OnboardingStepPill(
    number: String,
    label: String,
    active: Boolean,
) {
    val c = HandelhaTheme.colors
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (!c.isDark && !active) Modifier.shadow(4.dp, shape, ambientColor = Color.Black.copy(alpha = 0.04f))
                else Modifier,
            )
            .clip(shape)
            .background(if (active) c.heroTeal else c.surface, shape)
            .then(if (active) Modifier else Modifier.border(1.dp, c.border, shape))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(26.dp)
                .clip(CircleShape)
                .background(if (active) Color.White.copy(alpha = 0.18f) else c.primarySoft),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = number,
                fontSize = 12.5.sp,
                fontWeight = FontWeight.Bold,
                color = if (active) Color.White else c.primary,
            )
        }
        Spacer(Modifier.width(12.dp))
        Text(
            text = label,
            fontSize = 14.5.sp,
            fontWeight = FontWeight.Bold,
            color = if (active) Color.White else c.textPrimary,
        )
    }
}
