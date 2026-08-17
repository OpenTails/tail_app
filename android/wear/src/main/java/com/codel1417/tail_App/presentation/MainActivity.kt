/* While this template provides a good starting point for using Wear Compose, you can always
 * take a look at https://github.com/android/wear-os-samples/tree/main/ComposeStarter and
 * https://github.com/android/wear-os-samples/tree/main/ComposeAdvanced to find the most up to date
 * changes to the libraries and their usages.
 */

package com.codel1417.tail_App.presentation

import android.content.Context
import android.os.Bundle
import android.content.Intent
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
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
import androidx.wear.compose.material3.LinearProgressIndicator
import androidx.wear.compose.material3.SwitchButton
import androidx.wear.compose.material3.TimeText
import androidx.wear.remote.interactions.RemoteActivityHelper
import androidx.wear.tooling.preview.devices.WearDevices
import com.codel1417.tail_App.json.WearData
import com.codel1417.tail_App.json.WearGearData
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
import androidx.core.net.toUri
import androidx.wear.compose.material3.OpenOnPhoneDialog
import androidx.wear.compose.material3.OpenOnPhoneDialogDefaults
import androidx.wear.compose.material3.openOnPhoneDialogCurvedText

/** TODO:
 * Theme based on main app colors
 */
class MainActivity : ComponentActivity(), DataClient.OnDataChangedListener,
    CapabilityClient.OnCapabilityChangedListener {
    private var wearData: MutableLiveData<WearData> =
        MutableLiveData<WearData>(WearData())

    override fun onResume() {
        super.onResume()
        Wearable.getDataClient(this).addListener(this)
    }

    override fun onPause() {
        super.onPause()
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
            Log.e(TAG, "Failed to deserialize byte array to Map", e)
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
        dataEvents.forEach { event ->
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
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse WearData from data item", e)
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
                    val capabilityId =
                        // Find a nearby node or pick one arbitrarily.
                        result.nodes.firstOrNull { it.isNearby }?.id
                            ?: result.nodes.firstOrNull()?.id
                    if (capabilityId == null) {
                        return@addOnSuccessListener
                    }
                    val gson = Gson()
                    val messageType =
                        object : TypeToken<Map<String, Any>>() {}.type
                    val message = gson.fromJson<Map<String, Any>>(
                        gson.toJson(data),
                        messageType
                    )
                    Wearable.getMessageClient(context)
                        .sendMessage(
                            capabilityId,
                            "/${data.capability}",
                            asBytes(message)
                        )
                }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending message to phone", e)
        }
    }

    fun launchPhoneApp() {
        //TODO: Launch the main app
        val remoteActivityHelper =
            RemoteActivityHelper(this)
        remoteActivityHelper.startRemoteActivity(
            Intent(Intent.ACTION_VIEW)
                .setData(
                    ("http://play.google.com/store/apps/details?id=com" +
                            ".codel1417.tailApp").toUri()
                )
                .addCategory(Intent.CATEGORY_BROWSABLE)

        )

    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()

        super.onCreate(savedInstanceState)

        setContent {
            WearApp()
        }
    }

    //TODO: When app is visible, send a message to update application context
    @Composable
    fun WearApp() {
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

                    else -> {}
                }
            }
            // Add the observer to the lifecycle
            lifecycleOwner.lifecycle.addObserver(observer)
            onDispose {
                lifecycleOwner.lifecycle.removeObserver(observer)
            }
        }

        val data = state.value
        _androidTheme(
            primary = data?.themeData?.primary ?: 0xFFE46E26L,
            secondary = data?.themeData?.secondary ?: 0xFF21A58FL,
        ) {
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
                val expiredState = data == null || (System
                    .currentTimeMillis() - data.timestamp) > 60000;
                // 60 seconds

                if (expiredState) {
                    sendMessageToPhone(
                        data = WearSendData(
                            capability = "refresh",
                        ), context
                    )
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
                        item {
                            var showConfirmation by remember {
                                mutableStateOf(
                                    false
                                )
                            }
                            Card(
                                onClick = {
                                    showConfirmation = true
                                    launchPhoneApp()
                                }
                            ) { Text(text = data?.localization?.phonAppClosed ?: "") }

                            val text = OpenOnPhoneDialogDefaults.text
                            val style =
                                OpenOnPhoneDialogDefaults.curvedTextStyle
                            OpenOnPhoneDialog(
                                visible = showConfirmation,
                                onDismissRequest = { showConfirmation = false },
                                curvedText = {
                                    openOnPhoneDialogCurvedText(
                                        text = text,
                                        style = style,
                                    )
                                },
                            )
                        }
                    }

                } else {
                    val currentData = data
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

                        item { ListHeader { Text(text = currentData.localization.actionsPage) } }
                        if (currentData.favoriteActions.isEmpty()) {
                            item {
                                Card(
                                    onClick = {}
                                ) { Text(text = currentData.localization.favoriteActionsDescription) }
                            }
                        } else {
                            currentData.favoriteActions.map {
                                item {
                                    ActionButton(
                                        contentModifier,
                                        it.name,
                                        it.uuid,
                                    )
                                }
                            }
                        }
                        if (!currentData.configuredTriggers.isEmpty()) {
                            item { ListHeader { Text(text = currentData.localization.triggersPage) } }
                            currentData.configuredTriggers.map {
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
                        item { ListHeader { Text(text = currentData.localization.knownGear) } }
                        if (currentData.knownGear.isEmpty()) {
                            item {
                                Card(
                                    onClick = {}
                                ) { Text(text = currentData.localization.watchKnownGearNoGearPairedTip) }
                            }
                        } else {
                            currentData.knownGear.map { gear ->
                                item {
                                    GearButton(
                                        contentModifier,
                                        gear
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

    @Preview(device = WearDevices.SMALL_ROUND, showSystemUi = true)
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
        val haptics = LocalHapticFeedback.current
        val context = LocalContext.current
        val data = wearData.value
        Chip(
            modifier = modifier,
            colors = ChipDefaults.chipColors(backgroundColor = Color(data?.themeData?.primary ?: 0xFFE46E26)),
            label = { Text(text = contents, textAlign = TextAlign.Center) },
            onClick = {
                haptics.performHapticFeedback(HapticFeedbackType.ToggleOn)
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
        gear: WearGearData
    ) {
        val state by wearData.observeAsState()
        val currentGear = state?.knownGear?.firstOrNull { it.uuid == gear.uuid } ?: gear
        val hasBattery = currentGear.batteryLevel > -1

        Chip(
            modifier = modifier,
            colors = ChipDefaults.chipColors(backgroundColor = Color(currentGear.color)),
            label = { Text(text = currentGear.name, textAlign = TextAlign.Center) },
            onClick = {},
            enabled = hasBattery,
            secondaryLabel = {
                if (hasBattery) {
                    LinearProgressIndicator(
                        progress = { currentGear.batteryLevel.toFloat() / 100 },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            },
        )
    }

    override fun onCapabilityChanged(p0: CapabilityInfo) {
        sendMessageToPhone(
            data = WearSendData(
                capability = "refresh",
            ), this
        )
    }

    companion object {
        private const val TAG = "WearMainActivity"
    }
}