package com.codel1417.tail_app

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import HomeWidgetGlanceWidgetReceiver
import android.content.Context
import android.net.Uri
import android.os.Build
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.Button
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.GridCells
import androidx.glance.appwidget.lazy.LazyVerticalGrid
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.material3.ColorProviders
import androidx.glance.text.Text
import es.antonborri.home_widget.HomeWidgetBackgroundIntent


class HomeWidgetReceiver : HomeWidgetGlanceWidgetReceiver<HomeWidgetGlanceAppWidget>() {
    override val glanceAppWidget = HomeWidgetGlanceAppWidget()
}

class InteractiveAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("homeWidgetExample://titleClicked")
        )
        backgroundIntent.send()
    }
}

class HomeWidgetGlanceAppWidget : GlanceAppWidget() {

    /**
     * Needed for Updating
     */
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    companion object {
        private val SMALL_SQUARE = DpSize(100.dp, 100.dp)
        private val HORIZONTAL_RECTANGLE = DpSize(250.dp, 100.dp)
        private val BIG_SQUARE = DpSize(250.dp, 250.dp)
    }

    override val sizeMode = SizeMode.Responsive(
        setOf(
            SMALL_SQUARE,
            HORIZONTAL_RECTANGLE,
            BIG_SQUARE
        )
    )

    object MyAppWidgetGlanceColorScheme {
        private val colorScheme = lightColorScheme(
            primary = Color(alpha = 255, red = 228, green = 110, blue = 38),
            //onPrimary = md_theme_dark_onPrimary,
            //primaryContainer = md_theme_dark_primaryContainer,
            // ..
        )
        val colors = ColorProviders(
            dark = colorScheme,
            light = colorScheme,
        )
    }

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            //GlanceContent(context, currentState())
            val gridCells =
                if (Build.VERSION.SDK_INT >= 31) {
                    GridCells.Adaptive(100.dp)
                } else {
                    GridCells.Fixed(3)
                }
            GlanceTheme(colors = MyAppWidgetGlanceColorScheme.colors) {
                SampleGrid(
                    cells = gridCells,
                    modifier =
                    GlanceModifier
                        .fillMaxSize().padding(0)
                        .cornerRadius(15.dp)
                        .background(Color.White)
                )
            }
        }

    }


    @Composable
    fun SampleGrid(cells: GridCells, modifier: GlanceModifier = GlanceModifier.fillMaxSize()) {
        val localSize = LocalSize.current
        val buttonModifier = GlanceModifier
            .size(100.dp, 100.dp)
            .appWidgetBackground()
        LazyVerticalGrid(
            modifier = modifier,
            gridCells = cells,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item {
                Box(GlanceModifier.padding(10.dp).cornerRadius(15.dp), content = {
                    Button(
                        "Slow 1",
                        onClick = actionRunCallback<InteractiveAction>(),
                        modifier = buttonModifier,
                    )
                }, contentAlignment = Alignment.Center)

            }
            item {
                Box(GlanceModifier.padding(10.dp).cornerRadius(15.dp), content = {
                    Button(
                        "Slow 2",
                        onClick = actionRunCallback<InteractiveAction>(),
                        modifier = buttonModifier,
                    )
                }, contentAlignment = Alignment.Center)

            }
            item {
                Box(GlanceModifier.padding(10.dp).cornerRadius(15.dp), content = {
                    Button(
                        "Slow 3",
                        onClick = actionRunCallback<InteractiveAction>(),
                        modifier = buttonModifier,
                    )
                }, contentAlignment = Alignment.Center)
            }
            item {
                Box(GlanceModifier.padding(10.dp).cornerRadius(15.dp), content = {
                    Button(
                        "Happy Wag",
                        onClick = actionRunCallback<InteractiveAction>(),
                        modifier = buttonModifier,
                    )
                }, contentAlignment = Alignment.Center)
            }
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        // Use data to access the data you save with
        val data = currentState.preferences

        // Size will be one of the sizes defined above.
        val size = LocalSize.current
        Column {
            if (size.height >= BIG_SQUARE.height) {
                Text(text = "Where to?", modifier = GlanceModifier.padding(12.dp))
            }
            Row(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = GlanceModifier.fillMaxWidth().padding(16.dp)
            ) {
                val modifier = GlanceModifier.defaultWeight()
                Button(
                    "Slow 1",
                    onClick = actionRunCallback<InteractiveAction>(),
                    modifier = modifier
                )
                Button(
                    "Fast 1",
                    onClick = actionRunCallback<InteractiveAction>(),
                    modifier = modifier
                )
                Button(
                    "Happy Wag",
                    onClick = actionRunCallback<InteractiveAction>(),
                    modifier = modifier
                )

            }
            if (size.height >= BIG_SQUARE.height) {
                Text(text = "provided by X")
            }
        }
    }
}