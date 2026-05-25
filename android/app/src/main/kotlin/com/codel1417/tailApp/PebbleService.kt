package com.codel1417.tailApp

import io.rebble.pebblekit2.client.BasePebbleListenerService
import io.rebble.pebblekit2.common.model.PebbleDictionary
import io.rebble.pebblekit2.common.model.ReceiveResult
import io.rebble.pebblekit2.common.model.WatchIdentifier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID
import java.util.logging.Logger

class PebbleListenerService : BasePebbleListenerService() {
    val logger = Logger.getLogger("Pebble")

    override suspend fun onMessageReceived(
        watchappUUID: UUID,
        data: PebbleDictionary,
        watch: WatchIdentifier
    ): ReceiveResult {
        logger.info("Received data from watch: $data")
        CoroutineScope(Dispatchers.Main).launch(Dispatchers.Main) {
            if (eventSink != null && watchappUUID == companionAppUUID) {
                val dataMap = HashMap<Int, Any>()
                for (dataItem in data.iterator()) {
                    dataMap[dataItem.key.toInt()] = dataItem.value
                }
                eventSink!!.success(dataMap)
            } else if (eventSink == null) {
                throw Exception("Pebble data received but eventsSink is null")
            } else if (watchappUUID != companionAppUUID) {
                throw Exception("Pebble watch UUID \"$watchappUUID\" does not match stored UUID \"$companionAppUUID\"")
            }
        }


        return ReceiveResult.Ack
    }

    override fun onAppOpened(watchappUUID: UUID, watch: WatchIdentifier) {
        // ...
    }

    override fun onAppClosed(watchappUUID: UUID, watch: WatchIdentifier) {
        // ...
    }


}