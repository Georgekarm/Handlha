package com.handelha.app.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.Folder
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handelha.app.ui.theme.HandelhaTheme

data class HandelhaNavTab(
    val index: Int,
    val route: String,
    val labelAr: String,
    val labelEn: String,
    val icon: ImageVector,
    val activeIcon: ImageVector,
)

val handelhaNavTabs = listOf(
    HandelhaNavTab(0, "home", "الرئيسية", "Home", Icons.Outlined.Home, Icons.Rounded.Home),
    HandelhaNavTab(1, "tasks", "المهام", "Tasks", Icons.Rounded.Checklist, Icons.Rounded.Checklist),
    HandelhaNavTab(2, "projects", "مشروعات", "Projects", Icons.Outlined.Folder, Icons.Rounded.Folder),
    HandelhaNavTab(3, "chat", "المساعد", "Assistant", Icons.Outlined.ChatBubbleOutline, Icons.Rounded.ChatBubble),
    HandelhaNavTab(4, "tracking", "إنجازك", "Insights", Icons.Rounded.BarChart, Icons.Rounded.BarChart),
)

@Composable
fun HandelhaBottomNav(
    currentIndex: Int,
    isEnglish: Boolean,
    onTabSelected: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = HandelhaTheme.colors
    val capsuleShape = RoundedCornerShape(28.dp)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(start = 16.dp, top = 4.dp, end = 16.dp, bottom = 10.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(68.dp)
                .shadow(
                    elevation = if (c.isDark) 16.dp else 12.dp,
                    shape = capsuleShape,
                    ambientColor = Color.Black.copy(alpha = if (c.isDark) 0.40f else 0.12f),
                    spotColor = Color.Black.copy(alpha = if (c.isDark) 0.40f else 0.12f),
                )
                .clip(capsuleShape)
                .background(c.surface, capsuleShape)
                .border(
                    width = 1.dp,
                    color = if (c.isDark) c.border else c.border.copy(alpha = 0.70f),
                    shape = capsuleShape,
                )
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            handelhaNavTabs.forEach { tab ->
                val isSelected = tab.index == currentIndex
                val pillBg by animateColorAsState(
                    targetValue = if (isSelected) c.primarySoft else Color.Transparent,
                    animationSpec = tween(180),
                    label = "nav_pill_bg",
                )
                val fg = if (isSelected) c.primary else c.textSecondary
                val label = if (isEnglish) tab.labelEn else tab.labelAr

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(20.dp))
                        .semantics { selected = isSelected }
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = ripple(bounded = true),
                            role = Role.Tab,
                            onClick = { onTabSelected(tab.index) },
                        )
                        .testTag("nav_tab_${tab.index}"),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .width(48.dp)
                            .height(30.dp)
                            .clip(RoundedCornerShape(13.dp))
                            .background(pillBg),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = if (isSelected) tab.activeIcon else tab.icon,
                            contentDescription = label,
                            tint = fg,
                            modifier = Modifier.size(21.dp),
                        )
                    }
                    Spacer(Modifier.height(3.dp))
                    Text(
                        text = label,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontSize = 11.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        color = fg,
                        lineHeight = 12.5.sp,
                    )
                }
            }
        }
    }
}
