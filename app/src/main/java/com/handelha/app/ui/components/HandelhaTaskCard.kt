package com.handelha.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.domain.TaskItem
import com.handelha.app.domain.TaskPriority
import com.handelha.app.ui.theme.HandelhaTheme
import com.handelha.app.util.ArabicFormatters

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HandelhaTaskCard(
    task: TaskItem,
    isEnglish: Boolean,
    onToggleComplete: () -> Unit,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
    projectName: String? = null,
    stripeColor: Color? = null,
    onLongPress: (() -> Unit)? = null,
    onMorePressed: (() -> Unit)? = null,
    showEndStripe: Boolean = true,
    compactTag: Boolean = false,
    subtitleOverride: String? = null,
) {
    val c = HandelhaTheme.colors
    val isDark = c.isDark
    val done = task.isCompleted
    val displayTitle = ArabicFormatters.trData(task.title)

    val resolvedStripe = stripeColor ?: when (task.priority) {
        TaskPriority.urgent, TaskPriority.high -> c.primary
        TaskPriority.medium -> c.lavenderAccent
        TaskPriority.low -> c.danger
    }

    val subtitleText = subtitleOverride ?: buildList {
        if (!projectName.isNullOrBlank()) {
            add(ArabicFormatters.trData(projectName.trim()))
        } else if (task.priority == TaskPriority.high || task.priority == TaskPriority.urgent) {
            add(if (isEnglish) "Work" else "شغل")
        } else {
            add(if (isEnglish) "Personal" else "شخصي")
        }
        val whenMs = task.scheduledStartAtMs ?: task.dueAtMs
        if (done) {
            add(if (whenMs != null) ArabicFormatters.timeOfDayAr(whenMs) else if (isEnglish) "Done" else "خلصت")
        } else if (whenMs != null) {
            add(ArabicFormatters.timeOfDayAr(whenMs))
        }
        val mins = task.estimatedDurationMinutes ?: 0
        if (!done && mins > 0) {
            add(ArabicFormatters.durationMinutesFull(mins))
        }
    }.joinToString(" • ")

    val (tagLabel, tagBg, tagFg, tagBorder) = when {
        done -> Quadruple(
            if (isEnglish) "Completed" else "مكتملة",
            if (isDark) Color(0xFF15342C) else Color(0xFFE7F2EE),
            if (isDark) Color(0xFF9ED5C6) else c.primary,
            (if (isDark) Color(0xFF2B5C4E) else c.primary).copy(alpha = 0.35f),
        )
        task.priority == TaskPriority.urgent || task.priority == TaskPriority.high -> Quadruple(
            if (compactTag) {
                if (isEnglish) "High" else "عالية"
            } else {
                if (isEnglish) "High priority" else "أولوية عالية"
            },
            if (isDark) Color(0xFF272645) else Color(0xFFECEAF8),
            if (isDark) Color(0xFFC8C4F3) else c.secondary,
            null,
        )
        !projectName.isNullOrBlank() -> Quadruple(
            ArabicFormatters.trData(projectName.trim()),
            if (isDark) Color(0xFF1B342D) else Color(0xFFE7EFEC),
            if (isDark) Color(0xFFBED8D0) else c.textSecondary,
            null,
        )
        else -> Quadruple(
            if (task.priority == TaskPriority.medium) {
                if (isEnglish) "Work" else "شغل"
            } else {
                if (isEnglish) "Personal" else "شخصي"
            },
            if (isDark) Color(0xFF1A312B) else Color(0xFFE8F0ED),
            if (isDark) Color(0xFFBED8D0) else c.textSecondary,
            null,
        )
    }

    val checkBg by animateColorAsState(
        targetValue = if (done) c.ctaBackground else Color.Transparent,
        animationSpec = tween(180),
        label = "task_check_bg",
    )

    val cardShape = RoundedCornerShape(18.dp)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .then(
                if (!isDark) {
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
            .combinedClickable(
                onClick = onTap,
                onLongClick = onLongPress,
            )
            .padding(horizontal = 14.dp, vertical = 13.dp)
            .testTag("task_card_${task.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .defaultMinSize(minWidth = 40.dp, minHeight = 40.dp)
                .clip(RoundedCornerShape(10.dp))
                .clickable(
                    role = Role.Checkbox,
                    onClick = onToggleComplete,
                )
                .testTag("task_toggle_${task.id}"),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(checkBg, RoundedCornerShape(8.dp))
                    .border(
                        width = 1.5.dp,
                        color = if (done) c.ctaBackground else c.border,
                        shape = RoundedCornerShape(8.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                if (done) {
                    Icon(
                        imageVector = Icons.Rounded.Check,
                        contentDescription = if (isEnglish) "Reopen $displayTitle" else "إعادة فتح $displayTitle",
                        tint = c.ctaForeground,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }

        Spacer(Modifier.width(6.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = displayTitle,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = if (done) c.textSecondary else c.textPrimary,
                textDecoration = if (done) TextDecoration.LineThrough else null,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                text = subtitleText,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                fontSize = 12.sp,
                color = c.textSecondary,
            )
            Spacer(Modifier.height(7.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(tagBg, RoundedCornerShape(999.dp))
                    .then(
                        if (tagBorder != null) Modifier.border(1.dp, tagBorder, RoundedCornerShape(999.dp))
                        else Modifier,
                    )
                    .padding(horizontal = 10.dp, vertical = 3.5.dp),
            ) {
                Text(
                    text = tagLabel,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = tagFg,
                )
            }
        }

        if (onMorePressed != null) {
            Spacer(Modifier.width(4.dp))
            Box(
                modifier = Modifier
                    .defaultMinSize(minWidth = 36.dp, minHeight = 36.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .clickable(role = Role.Button, onClick = onMorePressed)
                    .testTag("task_more_${task.id}"),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Rounded.MoreHoriz,
                    contentDescription = if (isEnglish) "Task options" else "خيارات المهمة",
                    tint = c.textMuted,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        if (showEndStripe) {
            Spacer(Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .width(3.5.dp)
                    .height(34.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(resolvedStripe),
            )
        }
    }
}

private data class Quadruple<A, B, C, D>(val a: A, val b: B, val c: C, val d: D)
