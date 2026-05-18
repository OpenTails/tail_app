package com.codel1417.tailApp

import android.os.Handler
import android.hardware.input.InputManager
import android.view.InputDevice
import android.view.MotionEvent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.KeyEvent.KEYCODE_VOLUME_DOWN
import android.view.KeyEvent.KEYCODE_VOLUME_UP
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownPlugin.eventSink
import io.flutter.embedding.android.FlutterActivity
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity


class MainActivity : FlutterActivity(), GamepadsCompatibleActivity {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
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
