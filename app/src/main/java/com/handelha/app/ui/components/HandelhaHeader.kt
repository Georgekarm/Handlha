package com.handelha.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.ui.theme.HandelhaTheme

@Composable
fun HandelhaHeader(
    title: String,
    isEnglish: Boolean,
    modifier: Modifier = Modifier,
    subtitle: String = "خدها خطوة خطوة",
    showBack: Boolean = true,
    onBack: (() -> Unit)? = null,
    padding: PaddingValues = PaddingValues(start = 20.dp, top = 12.dp, end = 20.dp, bottom = 8.dp),
    actions: @Composable RowScope.() -> Unit = {},
) {
    val c = HandelhaTheme.colors
    val displaySubtitle = if (isEnglish && subtitle == "خدها خطوة خطوة") "Step by step" else subtitle

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(padding),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (showBack && onBack != null) {
            Box(
                modifier = Modifier
                    .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .clickable(role = Role.Button, onClick = onBack)
                    .testTag("header_back_button"),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (isEnglish) Icons.Rounded.ChevronLeft else Icons.Rounded.ChevronRight,
                    contentDescription = if (isEnglish) "Back" else "رجوع",
                    tint = c.textPrimary,
                    modifier = Modifier.size(28.dp),
                )
            }
            Spacer(Modifier.width(4.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                fontSize = 25.sp,
                fontWeight = FontWeight.ExtraBold,
                color = c.textPrimary,
                lineHeight = 30.sp,
            )
            if (displaySubtitle.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = displaySubtitle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = c.textSecondary,
                )
            }
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = actions,
        )
    }
}

@Composable
fun HandelhaHeaderIconButton(
    icon: ImageVector,
    tooltip: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    showBadge: Boolean = false,
    badgeColor: Color? = null,
    iconColor: Color? = null,
    backgroundColor: Color? = null,
    testTag: String? = null,
) {
    val c = HandelhaTheme.colors
    val bg = backgroundColor ?: c.surface
    val shape = RoundedCornerShape(15.dp)

    Box(
        modifier = modifier
            .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
            .let { if (testTag != null) it.testTag(testTag) else it }
            .clip(shape)
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(42.dp)
                .clip(shape)
                .background(bg, shape)
                .then(
                    if (bg == Color.Transparent) Modifier
                    else Modifier.border(1.dp, c.border, shape),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = tooltip,
                tint = iconColor ?: c.textPrimary,
                modifier = Modifier.size(21.dp),
            )
            if (showBadge) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 9.dp, end = 9.dp)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(badgeColor ?: c.danger),
                )
            }
        }
    }
}
