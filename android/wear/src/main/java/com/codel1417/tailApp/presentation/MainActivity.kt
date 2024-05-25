/* While this template provides a good starting point for using Wear Compose, you can always
 * take a look at https://github.com/android/wear-os-samples/tree/main/ComposeStarter and
 * https://github.com/android/wear-os-samples/tree/main/ComposeAdvanced to find the most up to date
 * changes to the libraries and their usages.
 */

package com.codel1417.tailApp.presentation

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat.startActivity
import androidx.wear.compose.foundation.lazy.AutoCenteringParams
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyColumnDefaults
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.Text
import com.codel1417.tailApp.presentation.theme._androidTheme
import com.google.android.gms.tasks.Task
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable


class MainActivity : ComponentActivity(), DataClient.OnDataChangedListener {

    private lateinit var dataClient: DataClient
    var actionsMap: MutableMap<String, String> = mutableMapOf();
    override fun onResume() {
        super.onResume()
        Wearable.getDataClient(this).addListener(this)
    }

    override fun onPause() {
        super.onPause()
        Wearable.getDataClient(this).removeListener(this)
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            // DataItem changed
            if (event.type == DataEvent.TYPE_CHANGED) {
                event.dataItem.also { item ->
                    if (item.uri.path!!.compareTo("/actions") == 0) {
                        DataMapItem.fromDataItem(item).dataMap.apply {
                            println(this)
                            val actions: Array<String> = this.getStringArray("actions")!!
                            val uuids: Array<String> = this.getStringArray("uuid")!!
                            for (nums in 0..actions.size) {
                                actionsMap[uuids[nums]] = actions[nums]
                            }
                            recreate()
                        }
                    }
                }
            } else if (event.type == DataEvent.TYPE_DELETED) {
                // DataItem deleted
            }
        }
    }

    // Create a data map and put data in it
    private fun increaseCounter(uuid: String) {
        val putDataReq: PutDataRequest = PutDataMapRequest.create("/triggerMove").run {
            dataMap.putString("uuid", uuid)
            asPutDataRequest()
        }
        val putDataTask: Task<DataItem> = dataClient.putDataItem(putDataReq)
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()

        super.onCreate(savedInstanceState)

        setTheme(android.R.style.Theme_DeviceDefault)

        setContent {
            WearApp("Android")
        }
    }

    @Composable
    fun WearApp(greetingName: String) {
        val dataClient: DataClient = Wearable.getDataClient(LocalContext.current)

        _androidTheme {
            // Hoist the list state to remember scroll position across compositions.
            val listState = rememberScalingLazyListState()

            ScalingLazyColumn(
                modifier = Modifier.fillMaxSize(),
                autoCentering = AutoCenteringParams(itemIndex = 0),
                state = listState,
                flingBehavior = ScalingLazyColumnDefaults.snapFlingBehavior(
                    state = listState,
                    snapOffset = 0.dp
                    // Exponential decay by default. You can also explicitly define a
                    // DecayAnimationSpec.
                )
            ) {
                item {Text(text = "Favorite Actionsf")}
                item { TextItem(contentModifier, "Slow 1","") }
                item { TextItem(contentModifier, "Slow 2","") }
                actionsMap.map {
                    item { TextItem(contentModifier, it.key, it.value) }
                }
            }
        }
    }

    val contentModifier = Modifier
        .fillMaxWidth()
        .padding(bottom = 8.dp)

    @Preview(device = Devices.WEAR_OS_SMALL_ROUND, showSystemUi = true)
    @Composable
    fun DefaultPreview() {
        WearApp("Preview Android Awoo")
    }

    @Composable
    fun TextItem(modifier: Modifier = Modifier, contents: String, uuid: String) {
        Chip(
            modifier = modifier,
            label = { Text(text = contents, textAlign = TextAlign.Center) },
            onClick = { increaseCounter(uuid) },
        )
    }
}





