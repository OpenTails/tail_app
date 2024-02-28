package com.codel1417.tail_app

import android.os.Bundle
import android.view.KeyEvent
import android.view.KeyEvent.KEYCODE_VOLUME_DOWN
import android.view.KeyEvent.KEYCODE_VOLUME_UP
import com.polidea.rxandroidble2.exceptions.BleException
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownPlugin.eventSink
import io.flutter.embedding.android.FlutterActivity
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins.setErrorHandler


class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setErrorHandler { throwable ->
            if (throwable is UndeliverableException && throwable.cause is BleException) {
                return@setErrorHandler // ignore BleExceptions since we do not have subscriber
            } else {
                throw throwable
            }
        }
    }

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
