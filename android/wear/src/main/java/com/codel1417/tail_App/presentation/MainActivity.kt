/* While this template provides a good starting point for using Wear Compose, you can always
 * take a look at https://github.com/android/wear-os-samples/tree/main/ComposeStarter and
 * https://github.com/android/wear-os-samples/tree/main/ComposeAdvanced to find the most up to date
 * changes to the libraries and their usages.
 */

package com.codel1417.tail_App.presentation

import android.R
import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.wear.compose.foundation.lazy.AutoCenteringParams
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyColumnDefaults
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Card
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.ListHeader
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.Vignette
import androidx.wear.compose.material.VignettePosition
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.LinearProgressIndicator
import androidx.wear.compose.material3.SwitchButton
import androidx.wear.compose.material3.TimeText
import com.codel1417.tail_App.json.WearData
import com.codel1417.tail_App.json.WearSendData
import com.codel1417.tail_App.presentation.theme._androidTheme
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.CapabilityClient.FILTER_REACHABLE
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.Wearable.getCapabilityClient
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

/** TODO:
 * Show spinner when no data available / loading from app
 * Refresh UI when data updates
 * Move actions / triggers / gear to their own page with horizontal swipe
 * show all actions, not just favorites
 * Theme based on main app colors
 * Watch to App communication
 */
class MainActivity : ComponentActivity(), DataClient.OnDataChangedListener,
    CapabilityClient.OnCapabilityChangedListener {
    private var wearData: MutableLiveData<WearData> = MutableLiveData<WearData>(WearData())

    override fun onResume() {
        super.onResume()
        println("onResume()")
        Wearable.getDataClient(this).addListener(this)
    }

    override fun onPause() {
        super.onPause()
        println("onPause()")
        Wearable.getDataClient(this).removeListener(this)
    }

    /**
     * Interprets the byteArray as a Map<String, Any>.
     * If that's not possible, returns null.
     */
    fun ByteArray.asMap(): Map<String, Any>? {
        val byteArrayInputStream = ByteArrayInputStream(this)
        val objectInputStream = ObjectInputStream(byteArrayInputStream)

        return try {
            val obj = objectInputStream.readObject()

            if (obj !is Map<*, *>) throw Exception()
            @Suppress("UNCHECKED_CAST")
            obj as Map<String, Any>
        } catch (e: Exception) {
            e.printStackTrace()
            null
        } finally {
            objectInputStream.close()
        }
    }

    /**
     * Interprets the byteArray as a Map<String, Any>.
     * If that's not possible, returns null.
     */
    fun asBytes(`object`: Any): ByteArray {
        val byteArrayOutputStream = ByteArrayOutputStream()
        val objectOutputStream = ObjectOutputStream(byteArrayOutputStream)
        objectOutputStream.writeObject(`object`)
        return byteArrayOutputStream.toByteArray()
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        println("onDataChanged()")
        dataEvents.forEach { event ->
            println("onDataChanged() ${event.type}")
            // DataItem changed
            if (event.type == DataEvent.TYPE_CHANGED) {
                event.dataItem.also { item ->
                    getWearDataItem(item)
                }
            }
        }
    }

    private fun getWearDataItem(item: DataItem) {
        try {
            println("Loading Actions")
            val gson = Gson()
            // asMap converts the bytes to the java object
            // The flutter library watch_connectivity was built for flutter to flutter, not flutter to compose
            val rawData = item.data!!.asMap()

            // cursed way to convert from map to WearData
            val data: WearData = gson.fromJson<WearData>(
                gson.toJson(rawData),
                WearData::class.java
            )
            wearData.postValue(data)
        } catch (_: Exception) {
        }

    }


    // Create a data map and put data in it
    private fun sendMessageToPhone(data: WearSendData, context: Context) {
        try {
            getCapabilityClient(context)
                .getCapability(
                    data.capability,
                    FILTER_REACHABLE
                ).addOnSuccessListener { result ->
                    val capabilityId =         // Find a nearby node or pick one arbitrarily.
                        result.nodes.firstOrNull { it.isNearby }?.id
                            ?: result.nodes.firstOrNull()?.id
                    if (capabilityId == null) {
                        return@addOnSuccessListener
                    }
                    val gson = Gson()
                    val messageType = object : TypeToken<Map<String, Any>>() {}.type
                    val message = gson.fromJson<Map<String, Any>>(
                        gson.toJson(data),
                        messageType
                    )
                    Wearable.getMessageClient(context)
                        .sendMessage(capabilityId, "/${data.capability}", asBytes(message))
                }
        } catch (e: Exception) {
            println("Error triggering action $e")
        }
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        println("onCreate()")
        installSplashScreen()

        super.onCreate(savedInstanceState)

        setTheme(R.style.Theme_DeviceDefault)

        setContent {
            WearApp()
        }
    }

    //TODO: When app is visible, send a message to update application context
    @Composable
    fun WearApp() {
        println("WearApp()")
        val context = LocalContext.current
        val state: State<WearData?> = wearData.observeAsState()

        // Safely update the current lambdas when a new one is provided
        val lifecycleOwner: LifecycleOwner = LocalLifecycleOwner.current

        // If `lifecycleOwner` changes, dispose and reset the effect
        DisposableEffect(lifecycleOwner) {
            // Create an observer that triggers our remembered callbacks
            // for lifecycle events
            val observer = LifecycleEventObserver { _, event ->
                when (event) {
                    Lifecycle.Event.ON_CREATE -> {
                        sendMessageToPhone(
                            data = WearSendData(
                                capability = "refresh",
                            ), context
                        )
                        Wearable.getDataClient(context).dataItems
                            .addOnSuccessListener { result ->
                                result.forEach { item ->
                                    getWearDataItem(
                                        item
                                    )
                                }
                            }
                    }

                    Lifecycle.Event.ON_START -> {
                        sendMessageToPhone(
                            data = WearSendData(
                                capability = "refresh",
                            ), context
                        )
                        Wearable.getDataClient(context).dataItems
                            .addOnSuccessListener { result ->
                                result.forEach { item ->
                                    getWearDataItem(
                                        item
                                    )
                                }
                            }
                    }

                    Lifecycle.Event.ON_RESUME -> {
                        sendMessageToPhone(
                            data = WearSendData(
                                capability = "refresh",
                            ), context
                        )
                        Wearable.getDataClient(context).dataItems
                            .addOnSuccessListener { result ->
                                result.forEach { item ->
                                    getWearDataItem(
                                        item
                                    )
                                }
                            }
                    }

                    Lifecycle.Event.ON_PAUSE -> {

                    }

                    Lifecycle.Event.ON_STOP -> {

                    }

                    Lifecycle.Event.ON_DESTROY -> {

                    }

                    else -> {}
                }
            }
            // Add the observer to the lifecycle
            lifecycleOwner.lifecycle.addObserver(observer)
            onDispose {
                lifecycleOwner.lifecycle.removeObserver(observer)
            }
        }




        _androidTheme {
            // Hoist the list state to remember scroll position across compositions.
            val listState = rememberScalingLazyListState()
            Scaffold(
                timeText = {
                    TimeText()
                },
                positionIndicator = {
                    PositionIndicator(scalingLazyListState = listState)
                },
                vignette = {
                    Vignette(vignettePosition = VignettePosition.TopAndBottom)
                }) {

                if (state.value == null) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier
                                .align(alignment = Alignment.Center)
                                .fillMaxSize(0.6f)
                        )
                    }
                } else {
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
                        item { ListHeader { Text(text = state.value!!.localization.actionsPage) } }
                        if (state.value!!.favoriteActions.isEmpty()) {
                            item {
                                Card(
                                    onClick = {}
                                ) { Text(text = state.value!!.localization.favoriteActionsDescription) }
                            }
                        } else {
                            state.value!!.favoriteActions.map {
                                item {
                                    ActionButton(
                                        contentModifier,
                                        it.name,
                                        it.uuid,
                                    )
                                }
                            }
                        }
                        if (!state.value!!.configuredTriggers.isEmpty()) {
                            item { ListHeader { Text(text = state.value!!.localization.triggersPage) } }
                            state.value!!.configuredTriggers.map {
                                item {
                                    TriggerButton(
                                        contentModifier,
                                        it.name,
                                        it.uuid,
                                        it.enabled,
                                    )
                                }
                            }
                        }
                        item { ListHeader { Text(text = state.value!!.localization.knownGear) } }
                        if (state.value!!.knownGear.isEmpty()) {
                            item {
                                Card(
                                    onClick = {}
                                ) { Text(text = state.value!!.localization.watchKnownGearNoGearPairedTip) }
                            }
                        } else {
                            state.value!!.knownGear.map {
                                item {
                                    GearButton(
                                        contentModifier,
                                        it.name,
                                        it.batteryLevel.toInt(),
                                        it.color
                                    )
                                }
                            }
                        }
                    }
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
        WearApp()
    }

    @Composable
    fun ActionButton(
        modifier: Modifier = Modifier,
        contents: String,
        uuid: String,
    ) {
        val context = LocalContext.current
        Chip(
            modifier = modifier,
            colors = ChipDefaults.chipColors(backgroundColor = Color(wearData.value!!.themeData.primary)),
            label = { Text(text = contents, textAlign = TextAlign.Center) },
            onClick = {
                sendMessageToPhone(
                    data = WearSendData(
                        capability = "run_action",
                        uuid = uuid,
                    ), context
                )
            },
        )
    }

    @Composable
    fun TriggerButton(
        modifier: Modifier = Modifier,
        contents: String,
        uuid: String,
        enabled: Boolean,
    ) {
        val context = LocalContext.current
        SwitchButton(
            modifier = modifier,
            label = { Text(text = contents, textAlign = TextAlign.Center) },
            checked = enabled,
            onCheckedChange = { result ->
                sendMessageToPhone(
                    data = WearSendData(
                        capability = "toggle_trigger",
                        uuid = uuid,
                        enabled = result,
                    ), context
                )
            },
        )
    }

    @Composable
    fun GearButton(
        modifier: Modifier = Modifier,
        name: String,
        battery: Int,
        color: Long
    ) {
        Chip(
            modifier = modifier,
            colors = ChipDefaults.chipColors(backgroundColor = Color(color)),
            label = { Text(text = name, textAlign = TextAlign.Center) },
            onClick = {},
            enabled = battery > -1,
            secondaryLabel = {
                if (battery > -1) {
                    LinearProgressIndicator(
                        progress = { battery.toFloat() / 100 },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            },
        )
    }

    override fun onCapabilityChanged(p0: CapabilityInfo) {
        println("onCapabilityChanged() ${p0.name} ${p0.nodes}")
        sendMessageToPhone(
            data = WearSendData(
                capability = "refresh",
            ), this
        )
    }
}





