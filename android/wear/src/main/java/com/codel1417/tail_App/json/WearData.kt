package com.codel1417.tail_App.json

data class WearActionData(val name: String, val uuid: String)
data class WearTriggerData(val name: String, val uuid: String, val enabled: Boolean)
data class WearLocalizationData(
    val triggersPage: String = "Triggers",
    val actionsPage: String = "Favorite Actions",
    val favoriteActionsDescription: String = "On your phone, Long press an action to favorite",
    val knownGear: String = "Your Gear",
    val watchKnownGearNoGearPairedTip: String = "On your phone, Use the `Scan For New Gear` button to pair your gear"
)

data class WearGearData(
    val name: String,
    val uuid: String,
    val connected: Boolean,
    val batteryLevel: Int,
    val color: Long
)

data class WearThemeData(val primary: Long = 4293160486, val secondary: Long = 4285945929)
data class WearData(
    val favoriteActions: List<WearActionData> = ArrayList<WearActionData>(),
    val configuredTriggers: List<WearTriggerData> = ArrayList<WearTriggerData>(),
    val knownGear: List<WearGearData> = ArrayList<WearGearData>(),
    val localization: WearLocalizationData = WearLocalizationData(),
    val themeData: WearThemeData = WearThemeData()
)

data class WearSendData(
    val capability: String,
    val uuid: String = "",
    val enabled: Boolean = false
)
