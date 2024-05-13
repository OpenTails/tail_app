package com.codel1417.tail_app

import android.view.KeyEvent
import android.view.KeyEvent.KEYCODE_VOLUME_DOWN
import android.view.KeyEvent.KEYCODE_VOLUME_UP
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownPlugin.eventSink
import io.flutter.embedding.android.FlutterActivity


class MainActivity : FlutterActivity() {

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
}
