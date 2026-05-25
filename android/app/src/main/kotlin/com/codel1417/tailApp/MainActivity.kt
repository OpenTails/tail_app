package com.codel1417.tailApp

import android.hardware.input.InputManager
import android.os.Bundle
import android.os.Handler
import android.view.KeyEvent
import android.view.KeyEvent.KEYCODE_VOLUME_DOWN
import android.view.KeyEvent.KEYCODE_VOLUME_UP
import android.view.MotionEvent
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownPlugin.eventSink
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.rebble.pebblekit2.client.DefaultPebbleInfoRetriever
import io.rebble.pebblekit2.client.DefaultPebbleSender
import io.rebble.pebblekit2.common.model.PebbleDictionaryItem
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity
import java.util.UUID
import java.util.logging.Logger

var companionAppUUID: UUID? = null

class MainActivity() : FlutterActivity(),
    GamepadsCompatibleActivity {
    val logger = Logger.getLogger("Pebble")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pebble_streanm",
        ).setStreamHandler(StreamHandler())
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pebble"
        ).setMethodCallHandler { call, result ->
            try {
                logger.info("Method ${call.method} called with args ${call.arguments}")
                when (call.method) {
                    "init" -> {
                        logger.info("Setting uuid ${call.arguments}")
                        if (call.arguments is String) {
                            companionAppUUID =
                                UUID.fromString(call.arguments as String)
                            result.success(null)
                        } else {
                            logger.severe(
                                "Invalid UUID. Companion app UUID must be String. Received ${call.arguments}"
                            )
                            result.error(
                                "Invalid UUID",
                                "Companion app UUID must be String",
                                " received ${call.arguments}"
                            )
                        }
                    }
                    //Data must be in the form of a map, where the key is the int id of the field and the value is a string or int
                    "sendData" -> {
                        logger.info("Sending data ${call.arguments}")
                        if (call.arguments is HashMap<*, *>) {
                            val sender = DefaultPebbleSender(context)
                            val dict = HashMap<UInt, PebbleDictionaryItem>()

                            for (val entry in call.arguments) {
                                if (entry.key !is Int) {
                                    logger.severe(
                                        "Invalid Type. Keys must be INTs that correspond to a type specified in the pebble apps package.json. Type sent: ${entry.key::class.simpleName}"
                                    )
                                    result.error(
                                        "Invalid Type",
                                        "Keys must be INTs that correspond to a type specified in the pebble apps package.json",
                                        "Type sent: ${entry.key::class.simpleName}"
                                    )
                                    break
                                }
                                val key = entry.key as UInt
                                if (entry.value is String) {
                                    dict[key] =
                                        PebbleDictionaryItem.Text(entry.value as String)
                                } else if (entry.value is Int) {
                                    dict[key] =
                                        PebbleDictionaryItem.Int32(entry.value as Int)
                                } else {
                                    logger.severe(
                                        "Invalid Type. Values must be INTs or Strings. Value type sent for key ${entry.key}: ${entry.value::class.simpleName}"
                                    )
                                    result.error(
                                        "Invalid Type",
                                        "Values must be INTs or Strings",
                                        "Value type sent for key ${entry.key}: ${entry.value::class.simpleName}"
                                    )
                                    break
                                }
                            }
                            if (dict.isNotEmpty()) {
                                CoroutineScope(Dispatchers.Main).launch(Dispatchers.Main) {
                                    sender.sendDataToPebble(
                                        companionAppUUID!!,
                                        dict
                                    )
                                }
                                result.success(null)
                            }
                        } else {
                            logger.severe("Missing data. Data must be sent as a map of ints and strings")
                            result.error(
                                "Missing data",
                                "Data must be sent as a map of ints and strings",
                                null
                            )
                        }
                    }

                    "isConnected" -> {
                        logger.info("Checking if watch is connected")
                        val infoRetriever = DefaultPebbleInfoRetriever(context)

                        CoroutineScope(Dispatchers.Main).launch(Dispatchers.Main) {
                            val connectedDevices =
                                infoRetriever.getConnectedWatches().first()
                                    .isNotEmpty()
                            result.success(connectedDevices)
                        }
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                logger.severe("Failed to call method ${call.method} $e")
                result.error(
                    "Failed to run method ${call.method}",
                    e.message,
                    e.stackTrace
                )
            }

        }
    }

    /// BEGIN ANDROID VOLUME BUTTON
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KEYCODE_VOLUME_DOWN && eventSink != null) {
            eventSink.success(true)
            return true
        }
        if (keyCode == KEYCODE_VOLUME_UP && eventSink != null) {
            eventSink.success(false)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
    /// END ANDROID VOLUME BUTTON

    /// BEGIN GAMEPADS
    var keyListener: ((KeyEvent) -> Boolean)? = null
    var motionListener: ((MotionEvent) -> Boolean)? = null

    override fun dispatchGenericMotionEvent(motionEvent: MotionEvent): Boolean {
        return motionListener?.invoke(motionEvent) ?: false
    }

    override fun dispatchKeyEvent(keyEvent: KeyEvent): Boolean {
        if (keyListener?.invoke(keyEvent) == true) {
            return true
        }
        return super.dispatchKeyEvent(keyEvent)
    }

    override fun registerInputDeviceListener(
        listener: InputManager.InputDeviceListener, handler: Handler?
    ) {
        val inputManager = getSystemService(INPUT_SERVICE) as InputManager
        inputManager.registerInputDeviceListener(listener, null)
    }

    override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
        keyListener = handler
    }

    override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
        motionListener = handler
    }
    /// END GAMEPADS
}
