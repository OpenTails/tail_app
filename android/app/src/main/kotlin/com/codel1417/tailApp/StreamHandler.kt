package com.codel1417.tailApp

import io.flutter.plugin.common.EventChannel

var eventSink: EventChannel.EventSink? = null;

class StreamHandler : EventChannel.StreamHandler {
    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?
    ) {
        eventSink = events;
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null;
    }
}