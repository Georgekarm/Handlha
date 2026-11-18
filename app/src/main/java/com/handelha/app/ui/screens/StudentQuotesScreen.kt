package com.handelha.app.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FormatQuote
import androidx.compose.material.icons.rounded.PushPin
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.R
import com.handelha.app.domain.StudentMotivationState
import com.handelha.app.domain.StudentQuickBoost
import com.handelha.app.domain.StudentQuoteCategory
import com.handelha.app.domain.StudentQuoteItem
import com.handelha.app.domain.StudentQuotesCatalog
import com.handelha.app.domain.StudentStudyMood
import com.handelha.app.ui.components.HandelhaBottomSheetFrame
import com.handelha.app.ui.components.HandelhaHeader
import com.handelha.app.ui.components.StudentQuickBoostSheet
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.ui.theme.IbmPlexSansArabic
import com.handelha.app.util.ArabicFormatters

private enum class QuotesFilterTab {
    ALL,
    BOOKS_SCIENCE,
    FAVORITES,
    CUSTOM,
    START_NOW,
    EXAM_NIGHTS,
    LOW_ENERGY,
    DREAM_BIG,
    CALM_MIND,
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun StudentQuotesScreen(
    motivationState: StudentMotivationState,
    isEnglish: Boolean,
    onBack: () -> Unit,
    onNextQuote: () -> Unit,
    onToggleFavorite: (String) -> Unit,
    onPinQuote: (String) -> Unit,
    onSelectMood: (StudentStudyMood) -> Unit,
    onSavePersonalMotto: (String) -> Unit,
    onAddCustomQuote: (text: String, tag: String) -> Unit,
    onDeleteCustomQuote: (String) -> Unit,
    onStartQuickFocus: (minutes: Int, title: String) -> Unit,
    onCreateTaskAndStartFocus: (minutes: Int, title: String, stepDescription: String) -> Unit = { mins, title, _ ->
        onStartQuickFocus(mins, title)
    },
    onShowToast: (String, Boolean) -> Unit,
) {
    BackHandler(onBack = onBack)

    val c = HandelhaTheme.colors
    val context = LocalContext.current

    val allQuotes = remember(motivationState.customQuotes) {
        motivationState.allQuotes()
    }
    val currentMood = motivationState.selectedMood
    val spotlightQuote = remember(motivationState) {
        motivationState.activeWidgetQuote()
    }

    var selectedFilter by remember { mutableStateOf(QuotesFilterTab.ALL) }
    var searchQuery by remember { mutableStateOf("") }
    var activeQuickBoost by remember { mutableStateOf<StudentQuickBoost?>(null) }
    var showAddQuoteSheet by remember { mutableStateOf(false) }
    var showMottoEditorSheet by remember { mutableStateOf(false) }

    val filteredQuotes = remember(allQuotes, selectedFilter, searchQuery, motivationState.favoriteQuoteIds) {
        val byCategory = when (selectedFilter) {
            QuotesFilterTab.ALL -> allQuotes
            QuotesFilterTab.BOOKS_SCIENCE -> allQuotes.filter { it.category == StudentQuoteCategory.BOOKS_SCIENCE }
            QuotesFilterTab.FAVORITES -> allQuotes.filter { motivationState.favoriteQuoteIds.contains(it.id) }
            QuotesFilterTab.CUSTOM -> allQuotes.filter { it.isCustom }
            QuotesFilterTab.START_NOW -> allQuotes.filter { it.category == StudentQuoteCategory.START_NOW }
            QuotesFilterTab.EXAM_NIGHTS -> allQuotes.filter { it.category == StudentQuoteCategory.EXAM_DAYS }
            QuotesFilterTab.LOW_ENERGY -> allQuotes.filter { it.category == StudentQuoteCategory.LOW_ENERGY }
            QuotesFilterTab.DREAM_BIG -> allQuotes.filter { it.category == StudentQuoteCategory.DREAM_GOAL }
            QuotesFilterTab.CALM_MIND -> allQuotes.filter { it.category == StudentQuoteCategory.CALM_WISDOM }
        }
        val q = searchQuery.trim().lowercase()
        if (q.isEmpty()) {
            byCategory
        } else {
            byCategory.filter { item ->
                item.textAr.lowercase().contains(q) ||
                    item.textEn.lowercase().contains(q) ||
                    item.tagAr.lowercase().contains(q) ||
                    item.tagEn.lowercase().contains(q) ||
                    (item.sourceAr?.lowercase()?.contains(q) == true) ||
                    (item.sourceEn?.lowercase()?.contains(q) == true)
            }
        }
    }

    fun copyQuote(item: StudentQuoteItem) {
        val text = buildString {
            append(if (isEnglish) item.textEn else item.textAr)
            item.source(isEnglish)?.let { src ->
                append("\n— ")
                append(src)
            }
        }
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        cm?.setPrimaryClip(ClipData.newPlainText("Handelha Quote", text))
        onShowToast(
            if (isEnglish) "Quote copied to clipboard" else "تم نسخ الاقتباس إلى الحافظة",
            false,
        )
    }

    fun shareQuote(item: StudentQuoteItem) {
        val shareBody = buildString {
            append("«")
            append(if (isEnglish) item.textEn else item.textAr)
            append("»")
            item.source(isEnglish)?.let { src ->
                append("\n— ")
                append(src)
            }
            append("\n\n")
            append(if (isEnglish) "Shared from Handelha • Your Desk" else "من تطبيق هندلها • مكتبك")
        }
        runCatching {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, shareBody)
            }
            val chooser = Intent.createChooser(sendIntent, if (isEnglish) "Share Quote" else "مشاركة الاقتباس")
            context.startActivity(chooser)
        }
    }

    val cardShadow = if (c.isDark) 0.dp else 6.dp

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(start = 20.dp, end = 20.dp, bottom = 40.dp),
    ) {
        HandelhaHeader(
            title = if (isEnglish) "Your Desk" else "مكتبك",
            subtitle = if (isEnglish) "Wisdom, books & daily study boost"
            else "حِكم وكتب وتشجيع على قد خطوتك",
            isEnglish = isEnglish,
            showBack = true,
            onBack = onBack,
            padding = PaddingValues(top = 12.dp, bottom = 14.dp),
            actions = {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(c.primarySoft)
                        .border(1.dp, c.primary.copy(alpha = 0.28f), RoundedCornerShape(999.dp))
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.logo),
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        contentScale = ContentScale.Fit,
                    )
                    Spacer(Modifier.width(5.dp))
                    Text(
                        text = if (isEnglish) "Student Mode" else "وضع الطالب",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.primary,
                    )
                }
            },
        )

        // 1. Hero Spotlight Quote Card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(14.dp, RoundedCornerShape(24.dp), ambientColor = c.heroTeal.copy(alpha = 0.22f))
                .clip(RoundedCornerShape(24.dp))
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            c.heroTeal,
                            c.studentTeal,
                        ),
                    ),
                )
                .padding(20.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(Color.White.copy(alpha = 0.16f))
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Outlined.MenuBook,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(14.dp),
                    )
                    Spacer(Modifier.width(5.dp))
                    Text(
                        text = spotlightQuote.category.label(isEnglish),
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                }

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(c.limeAccent)
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text(
                        text = if (motivationState.pinnedQuoteId == spotlightQuote.id) {
                            if (isEnglish) "Pinned on Home" else "مثبّت في الرئيسية"
                        } else {
                            spotlightQuote.tag(isEnglish)
                        },
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = c.limeAccentInk,
                    )
                }
            }

            Spacer(Modifier.height(14.dp))

            AnimatedContent(
                targetState = spotlightQuote,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "hub_spotlight_quote",
            ) { q ->
                Column {
                    Text(
                        text = "«${q.text(isEnglish)}»",
                        fontSize = 17.sp,
                        lineHeight = 27.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White,
                    )
                    q.source(isEnglish)?.let { citation ->
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = "— $citation",
                            fontSize = 12.5.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White.copy(alpha = 0.85f),
                        )
                    }
                }
            }

            if (motivationState.personalMotto.isNotBlank()) {
                Spacer(Modifier.height(12.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(Color.White.copy(alpha = 0.13f))
                        .clickable { showMottoEditorSheet = true }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Flag,
                        contentDescription = null,
                        tint = c.limeAccent,
                        modifier = Modifier.size(15.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = if (isEnglish) "Your Goal: ${motivationState.personalMotto}"
                        else "هدفك وشعارك: ${motivationState.personalMotto}",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.limeAccent,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    Icon(Icons.Outlined.Edit, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(15.dp))
                }
            }

            Spacer(Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Button(
                    onClick = onNextQuote,
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = c.heroTeal,
                    ),
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    modifier = Modifier
                        .weight(1f)
                        .height(42.dp)
                        .testTag("quotes_hub_next_btn"),
                ) {
                    Icon(Icons.Rounded.Refresh, null, modifier = Modifier.size(17.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = if (isEnglish) "Next Quote" else "اقتباس آخر",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.ExtraBold,
                    )
                }

                val isFav = motivationState.favoriteQuoteIds.contains(spotlightQuote.id)
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(Color.White.copy(alpha = if (isFav) 0.28f else 0.15f))
                        .clickable { onToggleFavorite(spotlightQuote.id) }
                        .testTag("quotes_hub_fav_btn"),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = if (isFav) Icons.Rounded.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = null,
                        tint = if (isFav) Color(0xFFFF8A80) else Color.White,
                        modifier = Modifier.size(20.dp),
                    )
                }

                val isPinned = motivationState.pinnedQuoteId == spotlightQuote.id
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(if (isPinned) c.limeAccent else Color.White.copy(alpha = 0.15f))
                        .clickable { onPinQuote(spotlightQuote.id) }
                        .testTag("quotes_hub_pin_btn"),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = if (isPinned) Icons.Rounded.PushPin else Icons.Outlined.PushPin,
                        contentDescription = null,
                        tint = if (isPinned) c.limeAccentInk else Color.White,
                        modifier = Modifier.size(19.dp),
                    )
                }

                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(Color.White.copy(alpha = 0.15f))
                        .clickable { copyQuote(spotlightQuote) },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Outlined.ContentCopy,
                        contentDescription = if (isEnglish) "Copy" else "نسخ",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp),
                    )
                }

                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(Color.White.copy(alpha = 0.15f))
                        .clickable { shareQuote(spotlightQuote) }
                        .testTag("quotes_hub_share_btn"),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Share,
                        contentDescription = if (isEnglish) "Share" else "مشاركة",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
        }

        Spacer(Modifier.height(18.dp))

        // 2. Custom Student Personalization Card (Study Mood + Personal Dream/Motto)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(cardShadow, RoundedCornerShape(20.dp), ambientColor = Color.Black.copy(alpha = 0.05f))
                .clip(RoundedCornerShape(20.dp))
                .background(c.surface, RoundedCornerShape(20.dp))
                .border(1.dp, c.border, RoundedCornerShape(20.dp))
                .padding(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(11.dp))
                            .background(c.primarySoft),
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
                    Column {
                        Text(
                            text = if (isEnglish) "Study Stage & Personal Goal" else "حالتك الدراسية وشعارك الشخصي",
                            fontSize = 14.5.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = c.textPrimary,
                        )
                        Text(
                            text = if (isEnglish) "Select your current mode to tailor your daily quote"
                            else "اختار مرحلتك الحالية لتخصيص اقتباس الرئيسية تلقائيًا",
                            fontSize = 11.5.sp,
                            color = c.textSecondary,
                        )
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StudentStudyMood.entries.forEach { mood ->
                    val sel = mood == currentMood
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(13.dp))
                            .background(if (sel) c.primary else c.surfaceSoft)
                            .border(
                                width = 1.dp,
                                color = if (sel) c.primary else c.border,
                                shape = RoundedCornerShape(13.dp),
                            )
                            .clickable { onSelectMood(mood) }
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = mood.label(isEnglish),
                            fontSize = 12.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (sel) c.textOnPrimary else c.textPrimary,
                        )
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            // Personal Motto Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(15.dp))
                    .background(c.surfaceSoft)
                    .border(1.dp, c.border, RoundedCornerShape(15.dp))
                    .clickable { showMottoEditorSheet = true }
                    .padding(horizontal = 14.dp, vertical = 11.dp)
                    .testTag("student_motto_card"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Flag,
                    contentDescription = null,
                    tint = c.primary,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isEnglish) "Personal Study Motto / Semester Goal" else "شعارك أو هدفك الدراسي الشخصي",
                        fontSize = 11.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = c.primary,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = motivationState.personalMotto.ifBlank {
                            if (isEnglish) "Tap to write your semester goal..."
                            else "اضغط لكتابة حلمك أو هدف الترم ليظهر معك..."
                        },
                        fontSize = 13.sp,
                        fontWeight = if (motivationState.personalMotto.isNotBlank()) FontWeight.Bold else FontWeight.Medium,
                        color = if (motivationState.personalMotto.isNotBlank()) c.textPrimary else c.textMuted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Spacer(Modifier.width(8.dp))
                Icon(Icons.Outlined.Edit, null, tint = c.textSecondary, modifier = Modifier.size(17.dp))
            }
        }

        Spacer(Modifier.height(18.dp))

        // 3. Instant Practical Study Reset ("دفعة عملية سريعة")
        Text(
            text = if (isEnglish) "Overcome Study Blocks" else "التغلب على عوائق المذاكرة",
            fontSize = 17.sp,
            fontWeight = FontWeight.ExtraBold,
            color = c.textPrimary,
        )
        Text(
            text = if (isEnglish) "Select what is slowing you down for a practical 25-minute action step"
            else "اختار اللي معطّلك دلوقتي وخُد خطوة عملية سريعة تفك العقدة",
            fontSize = 12.sp,
            color = c.textSecondary,
        )

        Spacer(Modifier.height(10.dp))

        StudentQuotesCatalog.quickBoosts.chunked(2).forEach { pair ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                pair.forEach { boost ->
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .shadow(cardShadow, RoundedCornerShape(18.dp), ambientColor = Color.Black.copy(alpha = 0.04f))
                            .clip(RoundedCornerShape(18.dp))
                            .background(c.surface, RoundedCornerShape(18.dp))
                            .border(1.dp, c.border, RoundedCornerShape(18.dp))
                            .clickable { activeQuickBoost = boost }
                            .padding(14.dp)
                            .testTag("quick_boost_${boost.id}"),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(30.dp)
                                .clip(RoundedCornerShape(9.dp))
                                .background(c.primarySoft),
                            contentAlignment = Alignment.Center,
                        ) {
                            Image(
                                painter = painterResource(id = R.drawable.logo),
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                contentScale = ContentScale.Fit,
                            )
                        }
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = boost.feelingTitle(isEnglish),
                            fontSize = 13.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = c.textPrimary,
                            lineHeight = 19.sp,
                            minLines = 2,
                            maxLines = 2,
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(
                            text = if (isEnglish) "View practical step" else "عرض الخطوة العملية",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = c.primary,
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(12.dp))

        // 4. Quotes Library Section Header + "+ أضف جملتك الخاصة"
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (isEnglish) "Quotes & Wisdom Library (${allQuotes.size})"
                    else "مكتبة الحِكم والاقتباسات (${ArabicFormatters.toArabicDigits(allQuotes.size)})",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Text(
                    text = if (isEnglish) "Books, scientific research, classic wisdom & Egyptian study quotes"
                    else "مقتطفات من الكتب والأبحاث العلمية والحِكم العالمية وتشجيع المذاكرة",
                    fontSize = 12.sp,
                    color = c.textSecondary,
                )
            }
            Spacer(Modifier.width(8.dp))
            Button(
                onClick = { showAddQuoteSheet = true },
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = c.primary,
                    contentColor = c.textOnPrimary,
                ),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                modifier = Modifier.testTag("add_custom_quote_btn"),
            ) {
                Icon(Icons.Rounded.Add, null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    text = if (isEnglish) "Add Quote" else "أضف اقتباس",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.ExtraBold,
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        // Search Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(cardShadow, RoundedCornerShape(16.dp), ambientColor = Color.Black.copy(alpha = 0.04f))
                .clip(RoundedCornerShape(16.dp))
                .background(c.surface, RoundedCornerShape(16.dp))
                .border(1.dp, c.border, RoundedCornerShape(16.dp))
                .padding(horizontal = 14.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Rounded.Search, null, tint = c.textMuted, modifier = Modifier.size(19.dp))
            Spacer(Modifier.width(8.dp))
            Box(modifier = Modifier.weight(1f)) {
                if (searchQuery.isEmpty()) {
                    Text(
                        text = if (isEnglish) "Search by book, author, science topic, or keyword..."
                        else "ابحث باسم الكتاب أو البحث العلمي أو الكلمة المفتاحية...",
                        fontSize = 13.5.sp,
                        color = c.textMuted,
                    )
                }
                BasicTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    singleLine = true,
                    textStyle = TextStyle(
                        fontFamily = IbmPlexSansArabic,
                        fontSize = 14.sp,
                        color = c.textPrimary,
                    ),
                    cursorBrush = SolidColor(c.primary),
                    modifier = Modifier.fillMaxWidth().testTag("quotes_search_input"),
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        // Filter Chips Strip (clean labels without emojis)
        val booksScienceCount = remember(allQuotes) {
            allQuotes.count { it.category == StudentQuoteCategory.BOOKS_SCIENCE }
        }
        val filterOptions = listOf(
            QuotesFilterTab.ALL to (if (isEnglish) "All (${allQuotes.size})" else "الكل (${ArabicFormatters.toArabicDigits(allQuotes.size)})"),
            QuotesFilterTab.BOOKS_SCIENCE to (if (isEnglish) "Books & Science ($booksScienceCount)" else "كتب وأبحاث علمية (${ArabicFormatters.toArabicDigits(booksScienceCount)})"),
            QuotesFilterTab.FAVORITES to (if (isEnglish) "Favorites (${motivationState.favoriteQuoteIds.size})" else "المفضلة (${ArabicFormatters.toArabicDigits(motivationState.favoriteQuoteIds.size)})"),
            QuotesFilterTab.CUSTOM to (if (isEnglish) "My Quotes (${motivationState.customQuotes.size})" else "كلماتي (${ArabicFormatters.toArabicDigits(motivationState.customQuotes.size)})"),
            QuotesFilterTab.START_NOW to (if (isEnglish) "Start & Action" else "قوة البداية"),
            QuotesFilterTab.EXAM_NIGHTS to (if (isEnglish) "Exam Nights" else "ليالي الامتحانات"),
            QuotesFilterTab.LOW_ENERGY to (if (isEnglish) "Low Energy" else "لما الطاقة تقل"),
            QuotesFilterTab.DREAM_BIG to (if (isEnglish) "Goals & Ambition" else "حلمك والنتيجة"),
            QuotesFilterTab.CALM_MIND to (if (isEnglish) "Calm Focus" else "روقان المذاكرة"),
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            filterOptions.forEach { (tab, label) ->
                val sel = selectedFilter == tab
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (sel) c.primary else c.surface)
                        .border(1.dp, if (sel) c.primary else c.border, RoundedCornerShape(999.dp))
                        .clickable { selectedFilter = tab }
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                ) {
                    Text(
                        text = label,
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (sel) c.textOnPrimary else c.textPrimary,
                    )
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        // Quotes Cards List
        if (filteredQuotes.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(c.surface, RoundedCornerShape(20.dp))
                    .border(1.dp, c.border, RoundedCornerShape(20.dp))
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Rounded.FormatQuote, null, tint = c.primary, modifier = Modifier.size(34.dp))
                Spacer(Modifier.height(8.dp))
                Text(
                    text = if (selectedFilter == QuotesFilterTab.CUSTOM) {
                        if (isEnglish) "You haven't added custom quotes yet" else "لم تضف اقتباسات خاصة بعد"
                    } else if (selectedFilter == QuotesFilterTab.FAVORITES) {
                        if (isEnglish) "No favorite quotes saved yet" else "لا توجد اقتباسات محفوظة في المفضلة بعد"
                    } else {
                        if (isEnglish) "No matching quotes found" else "لا توجد نتائج مطابقة للبحث"
                    },
                    fontSize = 15.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = if (isEnglish) "Write a personal reminder or tap the heart icon on any quote."
                    else "اكتب جملة بتشجعك بنفسك أو اضغط على علامة القلب بجانب أي اقتباس يعجبك.",
                    fontSize = 12.5.sp,
                    color = c.textSecondary,
                )
                if (selectedFilter == QuotesFilterTab.CUSTOM) {
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = { showAddQuoteSheet = true },
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
                    ) {
                        Icon(Icons.Rounded.Add, null, modifier = Modifier.size(17.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(if (isEnglish) "Write My First Quote" else "أضف أول اقتباس خاص", fontWeight = FontWeight.Bold)
                    }
                }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                filteredQuotes.forEach { item ->
                    val isFav = motivationState.favoriteQuoteIds.contains(item.id)
                    val isPinned = motivationState.pinnedQuoteId == item.id
                    val citation = item.source(isEnglish)

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .shadow(cardShadow, RoundedCornerShape(20.dp), ambientColor = Color.Black.copy(alpha = 0.04f))
                            .clip(RoundedCornerShape(20.dp))
                            .background(c.surface, RoundedCornerShape(20.dp))
                            .border(
                                width = if (isPinned) 1.5.dp else 1.dp,
                                color = if (isPinned) c.primary else c.border,
                                shape = RoundedCornerShape(20.dp),
                            )
                            .padding(16.dp),
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(999.dp))
                                        .background(c.surfaceSoft)
                                        .padding(horizontal = 10.dp, vertical = 4.dp),
                                ) {
                                    Text(
                                        text = item.category.label(isEnglish),
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = c.textSecondary,
                                    )
                                }
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(999.dp))
                                        .background(c.primarySoft)
                                        .padding(horizontal = 9.dp, vertical = 4.dp),
                                ) {
                                    Text(
                                        text = item.tag(isEnglish),
                                        fontSize = 10.5.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = c.primary,
                                    )
                                }
                            }

                            if (isPinned) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(999.dp))
                                        .background(c.primarySoft)
                                        .padding(horizontal = 8.dp, vertical = 3.dp),
                                ) {
                                    Text(
                                        text = if (isEnglish) "Pinned" else "مثبّت",
                                        fontSize = 10.5.sp,
                                        fontWeight = FontWeight.ExtraBold,
                                        color = c.primary,
                                    )
                                }
                            }
                        }

                        Spacer(Modifier.height(10.dp))

                        Text(
                            text = "«${item.text(isEnglish)}»",
                            fontSize = 14.5.sp,
                            lineHeight = 23.5.sp,
                            fontWeight = FontWeight.Bold,
                            color = c.textPrimary,
                        )

                        if (!citation.isNullOrBlank()) {
                            Spacer(Modifier.height(8.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Outlined.MenuBook,
                                    contentDescription = null,
                                    tint = c.primary,
                                    modifier = Modifier.size(13.5.dp),
                                )
                                Spacer(Modifier.width(5.dp))
                                Text(
                                    text = citation,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = c.textSecondary,
                                )
                            }
                        }

                        Spacer(Modifier.height(10.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.End,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Row(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (isPinned) c.primarySoft else c.surfaceSoft)
                                    .clickable {
                                        onPinQuote(item.id)
                                        onShowToast(
                                            if (isPinned) {
                                                if (isEnglish) "Unpinned from Home widget" else "تم إلغاء التثبيت من الويدجت"
                                            } else {
                                                if (isEnglish) "Pinned to your Home widget" else "تم تثبيت الاقتباس في الرئيسية"
                                            },
                                            false,
                                        )
                                    }
                                    .padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(
                                    imageVector = if (isPinned) Icons.Rounded.PushPin else Icons.Outlined.PushPin,
                                    contentDescription = null,
                                    tint = if (isPinned) c.primary else c.textSecondary,
                                    modifier = Modifier.size(14.dp),
                                )
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    text = if (isPinned) (if (isEnglish) "Pinned" else "مثبّتة") else (if (isEnglish) "Pin to Home" else "تثبيت بالرئيسية"),
                                    fontSize = 11.5.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isPinned) c.primary else c.textSecondary,
                                )
                            }

                            Spacer(Modifier.width(6.dp))

                            IconButton(
                                onClick = { onToggleFavorite(item.id) },
                                modifier = Modifier.size(34.dp),
                            ) {
                                Icon(
                                    imageVector = if (isFav) Icons.Rounded.Favorite else Icons.Outlined.FavoriteBorder,
                                    contentDescription = if (isEnglish) "Favorite" else "مفضلة",
                                    tint = if (isFav) c.danger else c.textSecondary,
                                    modifier = Modifier.size(18.dp),
                                )
                            }

                            IconButton(
                                onClick = { copyQuote(item) },
                                modifier = Modifier.size(34.dp),
                            ) {
                                Icon(
                                    imageVector = Icons.Outlined.ContentCopy,
                                    contentDescription = if (isEnglish) "Copy" else "نسخ",
                                    tint = c.textSecondary,
                                    modifier = Modifier.size(17.dp),
                                )
                            }

                            IconButton(
                                onClick = { shareQuote(item) },
                                modifier = Modifier.size(34.dp),
                            ) {
                                Icon(
                                    imageVector = Icons.Outlined.Share,
                                    contentDescription = if (isEnglish) "Share" else "مشاركة",
                                    tint = c.textSecondary,
                                    modifier = Modifier.size(17.dp),
                                )
                            }

                            if (item.isCustom) {
                                IconButton(
                                    onClick = { onDeleteCustomQuote(item.id) },
                                    modifier = Modifier.size(34.dp),
                                ) {
                                    Icon(
                                        imageVector = Icons.Outlined.DeleteOutline,
                                        contentDescription = if (isEnglish) "Delete" else "حذف",
                                        tint = c.danger,
                                        modifier = Modifier.size(18.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (activeQuickBoost != null) {
        StudentQuickBoostSheet(
            isEnglish = isEnglish,
            initialBoost = activeQuickBoost,
            onDismiss = { activeQuickBoost = null },
            onStartQuickFocus = { mins, title ->
                activeQuickBoost = null
                onStartQuickFocus(mins, title)
            },
            onCreateTaskAndStartFocus = { mins, title, microStep ->
                activeQuickBoost = null
                onCreateTaskAndStartFocus(mins, title, microStep)
            },
        )
    }

    if (showMottoEditorSheet) {
        var draftMotto by remember { mutableStateOf(motivationState.personalMotto) }
        val presets = if (isEnglish) {
            listOf(
                "Honours grade this semester, God willing",
                "One calm step every day beats cramming",
                "Making my family and myself proud",
                "Deep focus, calm mind, strong finish",
            )
        } else {
            listOf(
                "امتياز السنادي بإذن الله",
                "خطوة هادية كل يوم تغلب أي تراكم",
                "هفرّح أهلي ونفسي بالنتيجة",
                "مذاكرة بروقان وتركيز من غير توتر",
            )
        }

        HandelhaBottomSheetFrame(onDismiss = { showMottoEditorSheet = false }) {
            Text(
                text = if (isEnglish) "Your Personal Study Motto" else "حلمك وشعارك الدراسي",
                fontSize = 18.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (isEnglish) "Appears inside your Student Quote card to remind you why you started"
                else "بيظهر جوه كارت الاقتباسات في الرئيسية عشان يفكّرك دايمًا بهدفك",
                fontSize = 12.5.sp,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(12.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(c.surfaceSoft)
                    .border(1.2.dp, c.primary, RoundedCornerShape(16.dp))
                    .padding(14.dp),
            ) {
                Box {
                    if (draftMotto.isEmpty()) {
                        Text(
                            text = if (isEnglish) "e.g. Faculty of Engineering • Class of 2026"
                            else "مثال: هندسة بتقدير امتياز • دفعة ٢٠٢٦",
                            fontSize = 14.sp,
                            color = c.textMuted,
                        )
                    }
                    BasicTextField(
                        value = draftMotto,
                        onValueChange = { draftMotto = it },
                        textStyle = TextStyle(
                            fontFamily = IbmPlexSansArabic,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                            color = c.textPrimary,
                        ),
                        cursorBrush = SolidColor(c.primary),
                        modifier = Modifier.fillMaxWidth().testTag("motto_text_input"),
                    )
                }
            }

            Spacer(Modifier.height(10.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                presets.forEach { p ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(999.dp))
                            .background(c.primarySoft)
                            .clickable { draftMotto = p }
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    ) {
                        Text(p, fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = c.primary)
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    onSavePersonalMotto(draftMotto)
                    showMottoEditorSheet = false
                    onShowToast(
                        if (isEnglish) "Study motto saved" else "تم حفظ شعارك الدراسي بنجاح",
                        false,
                    )
                },
                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("save_motto_btn"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Icon(Icons.Rounded.Check, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (isEnglish) "Save Motto" else "حفظ الشعار الدراسي", fontWeight = FontWeight.ExtraBold)
            }
        }
    }

    if (showAddQuoteSheet) {
        var customText by remember { mutableStateOf("") }
        var selectedTagIndex by remember { mutableIntStateOf(0) }
        val tags = if (isEnglish) {
            listOf("Note to Self", "Book Insight", "My Goal", "Daily Wisdom")
        } else {
            listOf("رسالة لنفسي", "فكرة من كتاب", "حلمي", "حكمة خاصة")
        }

        HandelhaBottomSheetFrame(onDismiss = { showAddQuoteSheet = false }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.AutoAwesome, null, tint = c.primary)
                Spacer(Modifier.width(8.dp))
                Text(
                    text = if (isEnglish) "Add Your Own Quote or Book Note" else "أضف اقتباسك أو ملاحظتك الخاصة",
                    fontSize = 17.5.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = c.textPrimary,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = if (isEnglish) "Save a quote from a book you're reading or a personal reminder"
                else "احفظ اقتباسًا من كتاب تقرأه أو جملة تشجعك لتظهر في كارت الرئيسية",
                fontSize = 12.5.sp,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(12.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(c.surfaceSoft)
                    .border(1.2.dp, c.border, RoundedCornerShape(16.dp))
                    .padding(14.dp),
            ) {
                Box(modifier = Modifier.height(84.dp)) {
                    if (customText.isEmpty()) {
                        Text(
                            text = if (isEnglish) "e.g. Every page I finish today makes exam night calmer..."
                            else "مثال: كل صفحة بخلصها النهارده بتشتري راحتي وروقاني ليلة الامتحان...",
                            fontSize = 14.sp,
                            color = c.textMuted,
                        )
                    }
                    BasicTextField(
                        value = customText,
                        onValueChange = { customText = it },
                        textStyle = TextStyle(
                            fontFamily = IbmPlexSansArabic,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = c.textPrimary,
                            lineHeight = 22.sp,
                        ),
                        cursorBrush = SolidColor(c.primary),
                        modifier = Modifier.fillMaxSize().testTag("custom_quote_input"),
                    )
                }
            }

            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                tags.forEachIndexed { idx, t ->
                    val sel = selectedTagIndex == idx
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (sel) c.primary else c.surfaceSoft)
                            .clickable { selectedTagIndex = idx }
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                    ) {
                        Text(
                            text = t,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (sel) c.textOnPrimary else c.textPrimary,
                        )
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            Button(
                onClick = {
                    val clean = customText.trim()
                    if (clean.length < 3) {
                        onShowToast(
                            if (isEnglish) "Write a quote first" else "اكتب الجملة أولًا",
                            true,
                        )
                    } else {
                        onAddCustomQuote(clean, tags[selectedTagIndex])
                        showAddQuoteSheet = false
                        selectedFilter = QuotesFilterTab.CUSTOM
                        onShowToast(
                            if (isEnglish) "Your custom quote was added & pinned"
                            else "تمت إضافة اقتباسك الخاص وتثبيته في الرئيسية",
                            false,
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("save_custom_quote_btn"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = c.primary, contentColor = c.textOnPrimary),
            ) {
                Icon(Icons.Rounded.Add, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (isEnglish) "Save & Pin to Widget" else "حفظ وتثبيت في الويدجت", fontWeight = FontWeight.ExtraBold)
            }
        }
    }
}
