package com.codel1417.tail_App.presentation.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme

@Composable
fun _androidTheme(
    primary: Long = 0xFFE46E26L,
    secondary: Long = 0xFF21A58FL,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = ColorScheme(
            primary = Color(primary),
            secondary = Color(secondary)
        ),
        content = content
    )
}