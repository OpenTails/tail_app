/* While this template provides a good starting point for using Wear Compose, you can always
 * take a look at https://github.com/android/wear-os-samples/tree/main/ComposeStarter and
 * https://github.com/android/wear-os-samples/tree/main/ComposeAdvanced to find the most up to date
 * changes to the libraries and their usages.
 */

package com.codel1417.tail_App.presentation

import android.R
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
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
import androidx.lifecycle.MutableLiveData
import androidx.wear.compose.foundation.lazy.AutoCenteringParams
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyColumnDefaults
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.Card
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.Vignette
import androidx.wear.compose.material.VignettePosition
import androidx.wear.compose.material3.Card
import androidx.wear.compose.material3.CircularProgressIndicator
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
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.NodeClient
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
    MessageClient.OnMessageReceivedListener, CapabilityClient.OnCapabilityChangedListener {
    private var wearData: MutableLiveData<WearData> = MutableLiveData<WearData>();

    private lateinit var dataClient: DataClient
    private lateinit var messageClient: MessageClient
    private lateinit var nodeClient: NodeClient
    private lateinit var capabilityClient: CapabilityClient
    override fun onResume() {
        super.onResume()
        println("onResume()")
        Wearable.getDataClient(this).addListener(this)
        Wearable.getMessageClient(this).addListener(this)

    }

    override fun onPause() {
        super.onPause()
        println("onPause()")
        Wearable.getDataClient(this).removeListener(this)
        Wearable.getCapabilityClient(this).removeListener(this)
        Wearable.getMessageClient(this).removeListener(this)

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
            obj as Map<String, Any>;
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
            } else if (event.type == DataEvent.TYPE_DELETED) {
                // DataItem deleted
            }
        }
    }

    private fun getWearDataItem(item: DataItem) {
        try {
            println("Loading Actions")
            val gson: Gson = Gson()
            // asMap converts the bytes to the java object
            // The flutter library watch_connectivity was built for flutter to flutter, not flutter to compose
            val rawData = item.data!!.asMap();

            // cursed way to convert from map to WearData
            val data: WearData = gson.fromJson<WearData>(
                gson.toJson(rawData),
                WearData::class.java
            );
            wearData.postValue(data)
        } catch (e: Exception) {
        }

    }

    private var nodeIDs: HashMap<String, String> = HashMap<String, String>()

    // Create a data map and put data in it
    private fun sendMessageToPhone(data: WearSendData) {
        try {
            capabilityClient
                .getCapability(
                    data.capability,
                    FILTER_REACHABLE
                ).addOnSuccessListener { result ->
                    val capabilityId =         // Find a nearby node or pick one arbitrarily.
                        result.nodes.firstOrNull { it.isNearby }?.id
                            ?: result.nodes.firstOrNull()?.id
                    if (capabilityId == null) {
                        return@addOnSuccessListener;
                    }
                    val gson = Gson()
                    val messageType = object : TypeToken<Map<String, Any>>() {}.type
                    val message = gson.fromJson<Map<String, Any>>(
                        gson.toJson(data),
                        messageType
                    )
                    messageClient.sendMessage(capabilityId, "/${data.capability}", asBytes(message))
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
            WearApp("Android")
        }
    }

    //TODO: When app is visible, send a message to update application context
    @Composable
    fun WearApp(greetingName: String) {
        println("WearApp()")
        dataClient = Wearable.getDataClient(LocalContext.current)
        messageClient = Wearable.getMessageClient(LocalContext.current)
        nodeClient = Wearable.getNodeClient(LocalContext.current)
        capabilityClient = getCapabilityClient(LocalContext.current)
        dataClient.dataItems
            .addOnSuccessListener { result -> result.forEach { item -> getWearDataItem(item) } }
        val state: State<WearData?> = wearData.observeAsState()
        sendMessageToPhone(
            data = WearSendData(
                capability = "refresh",
            )
        )
        _androidTheme {
            // Hoist the list state to remember scroll position across compositions.
            val listState = rememberScalingLazyListState()
            Scaffold(
                timeText = {
                    if (!listState.isScrollInProgress) TimeText()
                },
                positionIndicator = {
                    PositionIndicator(scalingLazyListState = listState)
                },
                vignette = {
                    Vignette(vignettePosition = VignettePosition.TopAndBottom)
                }) {

                if (state.value == null) {
                    Box(                        modifier = Modifier.fillMaxSize(),
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
                        item { Text(text = state.value!!.localization.actionsPage) }
                        state.value!!.favoriteActions.map {
                            item {
                                ActionButton(
                                    contentModifier,
                                    it.name,
                                    it.uuid,
                                )
                            }
                        }
                        item { Text(text = state.value!!.localization.triggersPage) }
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
                        item { Text(text = state.value!!.localization.triggersPage) }
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

    val contentModifier = Modifier
        .fillMaxWidth()
        .padding(bottom = 8.dp)

    @Preview(device = Devices.WEAR_OS_SMALL_ROUND, showSystemUi = true)
    @Composable
    fun DefaultPreview() {
        WearApp("Preview Android Awoo")
    }

    @Composable
    fun ActionButton(
        modifier: Modifier = Modifier,
        contents: String,
        uuid: String,
    ) {
        Chip(
            modifier = modifier,
            colors = ChipDefaults.chipColors(backgroundColor = Color(wearData.value!!.themeData.primary)),
            label = { Text(text = contents, textAlign = TextAlign.Center) },
            onClick = {
                sendMessageToPhone(
                    data = WearSendData(
                        capability = "run_action",
                        uuid = uuid,
                    )
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
                    )
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
            secondaryLabel = { Text(text = "$battery%", textAlign = TextAlign.Center) },
        )
    }
    override fun onMessageReceived(p0: MessageEvent) {
        println("onMessageReceived() ${p0.path} ${p0.data}")
    }

    override fun onCapabilityChanged(p0: CapabilityInfo) {
        println("onCapabilityChanged() ${p0.name} ${p0.nodes}")
        sendMessageToPhone(
            data = WearSendData(
                capability = "refresh",
            )
        )
    }
}





