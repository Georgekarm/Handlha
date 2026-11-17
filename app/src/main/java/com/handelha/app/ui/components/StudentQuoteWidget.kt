package com.handelha.app.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.FormatQuote
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.domain.StudentMotivationState
import com.handelha.app.domain.StudentQuickBoost
import com.handelha.app.domain.StudentQuotesCatalog
import com.handelha.app.domain.StudentStudyMood
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters

@Composable
fun StudentQuoteWidgetCard(
    studentName: String,
    motivationState: StudentMotivationState,
    isEnglish: Boolean,
    onNextQuote: () -> Unit,
    onToggleFavorite: (String) -> Unit,
    onSelectMood: (StudentStudyMood) -> Unit,
    onOpenQuotesHub: () -> Unit,
    onStartQuickFocus: (minutes: Int, title: String) -> Unit,
    onShowToast: (String, Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val activeQuote = motivationState.activeWidgetQuote()
    val isFav = motivationState.favoriteQuoteIds.contains(activeQuote.id)
    val isPinned = motivationState.pinnedQuoteId == activeQuote.id
    val cardShape = RoundedCornerShape(20.dp)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .then(
                if (!c.isDark) {
                    Modifier.shadow(
                        elevation = 6.dp,
                        shape = cardShape,
                        ambientColor = Color.Black.copy(alpha = 0.05f),
                        spotColor = Color.Black.copy(alpha = 0.05f),
                    )
                } else {
                    Modifier
                },
            )
            .clip(cardShape)
            .background(c.surface, cardShape)
            .border(1.dp, c.border, cardShape)
            .clickable(onClick = onOpenQuotesHub)
            .testTag("student_quote_widget_card"),
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            // Clean editorial header row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(RoundedCornerShape(9.dp))
                        .background(c.primarySoft),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Rounded.FormatQuote,
                        contentDescription = null,
                        tint = c.primary,
                        modifier = Modifier.size(16.dp),
                    )
                }
                Spacer(Modifier.width(8.dp))
                Text(
                    text = if (isEnglish) "Daily Wisdom & Science" else "حكمة واقتباس اليوم",
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.textPrimary,
                )
                Spacer(Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(c.surfaceSoft)
                        .padding(horizontal = 8.dp, vertical = 2.dp),
                ) {
                    Text(
                        text = activeQuote.tag(isEnglish),
                        fontSize = 10.5.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = c.primary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (isPinned) {
                    Spacer(Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Rounded.PushPin,
                        contentDescription = null,
                        tint = c.studentIndigo,
                        modifier = Modifier.size(13.dp),
                    )
                }

                Spacer(Modifier.weight(1f))

                SmallWidgetActionButton(
                    icon = if (isFav) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
                    tint = if (isFav) c.danger else c.textSecondary,
                    contentDesc = if (isEnglish) "Favorite quote" else "إضافة للمفضلة",
                    onClick = { onToggleFavorite(activeQuote.id) },
                    testTag = "student_widget_fav_btn",
                )
                Spacer(Modifier.width(4.dp))
                SmallWidgetActionButton(
                    icon = Icons.Rounded.Refresh,
                    tint = c.primary,
                    contentDesc = if (isEnglish) "Next quote" else "اقتباس آخر",
                    onClick = onNextQuote,
                    testTag = "student_widget_next_btn",
                )
            }

            Spacer(Modifier.height(10.dp))

            // Animated Quote Body
            AnimatedContent(
                targetState = activeQuote,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "student_quote_anim",
            ) { quote ->
                Column {
                    Text(
                        text = "«${quote.text(isEnglish)}»",
                        fontSize = 14.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.textPrimary,
                        lineHeight = 23.sp,
                    )
                    val citation = quote.source(isEnglish)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Row(
                            modifier = Modifier.weight(1f),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            if (!citation.isNullOrBlank()) {
                                Icon(
                                    imageVector = Icons.Outlined.MenuBook,
                                    contentDescription = null,
                                    tint = c.textSecondary,
                                    modifier = Modifier.size(13.dp),
                                )
                                Spacer(Modifier.width(5.dp))
                                Text(
                                    text = citation,
                                    fontSize = 11.5.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = c.textSecondary,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            } else if (motivationState.personalMotto.isNotBlank()) {
                                Text(
                                    text = motivationState.personalMotto,
                                    fontSize = 11.5.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = c.textSecondary,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            } else {
                                Text(
                                    text = quote.category.label(isEnglish),
                                    fontSize = 11.5.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = c.textSecondary,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                        }

                        Spacer(Modifier.width(8.dp))

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.testTag("student_widget_open_hub_btn"),
                        ) {
                            Text(
                                text = if (isEnglish) "Quotes Library" else "مكتبة الحِكم",
                                fontSize = 11.5.sp,
                                fontWeight = FontWeight.Bold,
                                color = c.primary,
                            )
                            Spacer(Modifier.width(2.dp))
                            Icon(
                                imageVector = if (isEnglish) Icons.Rounded.ChevronRight else Icons.Rounded.ChevronLeft,
                                contentDescription = null,
                                tint = c.primary,
                                modifier = Modifier.size(15.dp),
                            )
                        }
                    }
                }
            }
        }

        // Subtle vertical accent bar on the trailing edge matching HandelhaTaskCard
        Box(
            modifier = Modifier
                .width(3.5.dp)
                .fillMaxHeight()
                .background(c.primary.copy(alpha = 0.75f)),
        )
    }
}

@Composable
private fun SmallWidgetActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    contentDesc: String,
    onClick: () -> Unit,
    testTag: String,
) {
    val c = HandelhaTheme.colors
    Box(
        modifier = Modifier
            .size(30.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(c.surfaceSoft)
            .clickable(onClick = onClick)
            .testTag(testTag),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDesc,
            tint = tint,
            modifier = Modifier.size(15.dp),
        )
    }
}

@Composable
fun StudentMoodPickerSheet(
    selectedMood: StudentStudyMood,
    isEnglish: Boolean,
    onDismiss: () -> Unit,
    onSelectMood: (StudentStudyMood) -> Unit,
) {
    val c = HandelhaTheme.colors
    HandelhaBottomSheetFrame(onDismiss = onDismiss) {
        Text(
            text = if (isEnglish) "Your Current Study State" else "إيه حالتك الدراسية دلوقتي؟",
            fontSize = 18.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.textPrimary,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = if (isEnglish) "Handelha tailors your quotes and wisdom to match your current phase."
            else "هندلها بيظبط الاقتباسات والحِكم على حسب مرحلتك وطاقتك الحالية.",
            fontSize = 12.5.sp,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(14.dp))

        StudentStudyMood.entries.forEach { mood ->
            val active = mood == selectedMood
            val shape = RoundedCornerShape(16.dp)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp)
                    .clip(shape)
                    .background(if (active) c.primarySoft else c.surfaceSoft, shape)
                    .border(if (active) 1.4.dp else 1.dp, if (active) c.primary else c.border, shape)
                    .clickable { onSelectMood(mood) }
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = mood.label(isEnglish),
                        fontSize = 14.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (active) c.primary else c.textPrimary,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = mood.badge(isEnglish),
                        fontSize = 12.sp,
                        color = c.textSecondary,
                    )
                }
                if (active) {
                    Icon(Icons.Rounded.Check, null, tint = c.primary, modifier = Modifier.size(20.dp))
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun StudentQuickBoostSheet(
    isEnglish: Boolean,
    initialBoost: StudentQuickBoost? = null,
    onDismiss: () -> Unit,
    onStartQuickFocus: (minutes: Int, title: String) -> Unit,
) {
    val c = HandelhaTheme.colors
    var selectedBoost by remember(initialBoost) {
        mutableStateOf(initialBoost ?: StudentQuotesCatalog.quickBoosts.first())
    }

    HandelhaBottomSheetFrame(onDismiss = onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(c.primarySoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.Bolt, null, tint = c.primary, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) "Practical Study Reset" else "دفعة عملية سريعة",
                    fontSize = 17.5.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Text(
                    text = if (isEnglish) "Pick what is blocking you right now" else "اختار اللي معطّلك دلوقتي وخُد خطوة عملية هادية",
                    fontSize = 12.sp,
                    color = c.textSecondary,
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            StudentQuotesCatalog.quickBoosts.forEach { boost ->
                val active = boost.id == selectedBoost.id
                val shape = RoundedCornerShape(13.dp)
                Box(
                    modifier = Modifier
                        .clip(shape)
                        .background(if (active) c.primary else c.surfaceSoft, shape)
                        .border(1.dp, if (active) c.primary else c.border, shape)
                        .clickable { selectedBoost = boost }
                        .padding(horizontal = 12.dp, vertical = 9.dp),
                ) {
                    Text(
                        text = boost.feelingTitle(isEnglish),
                        fontSize = 12.5.sp,
                        fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
                        color = if (active) c.textOnPrimary else c.textPrimary,
                    )
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(c.surfaceSoft, RoundedCornerShape(18.dp))
                .border(1.dp, c.border, RoundedCornerShape(18.dp))
                .padding(16.dp),
        ) {
            Text(
                text = selectedBoost.responseTitle(isEnglish),
                fontSize = 15.5.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.primary,
                lineHeight = 23.sp,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = selectedBoost.responseBody(isEnglish),
                fontSize = 13.5.sp,
                color = c.textPrimary,
                lineHeight = 22.sp,
            )
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(c.primarySoft)
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Lightbulb,
                    contentDescription = null,
                    tint = c.primary,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = selectedBoost.microStep(isEnglish),
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.Bold,
                    color = c.primary,
                    lineHeight = 19.sp,
                )
            }
        }

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = {
                onStartQuickFocus(
                    selectedBoost.suggestedFocusMinutes,
                    selectedBoost.feelingTitle(isEnglish),
                )
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = c.ctaBackground,
                contentColor = c.ctaForeground,
            ),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            Icon(Icons.Rounded.PlayArrow, null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(6.dp))
            Text(
                text = if (isEnglish) "Start ${selectedBoost.suggestedFocusMinutes}m Calm Focus Now"
                else "ابدأ ${ArabicFormatters.toArabicDigits(selectedBoost.suggestedFocusMinutes)} دقيقة تركيز هادي دلوقتي",
                fontSize = 14.5.sp,
                fontWeight = FontWeight.ExtraBold,
            )
        }
    }
}
