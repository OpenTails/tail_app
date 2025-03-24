package com.codel1417.tail_App.json

data class WearActionData(val name: String, val uuid: String)
data class WearTriggerData(val name: String, val uuid: String, val enabled: Boolean)
data class WearLocalizationData(
    val triggersPage: String,
    val actionsPage: String,
    val favoriteActionsDescription: String
)

data class WearGearData(
    val name: String,
    val uuid: String,
    val connected: Boolean,
    val batteryLevel: Int,
    val color: Long
)

data class WearThemeData(val primary: Long, val secondary: Long)
data class WearData(
    val favoriteActions: List<WearActionData>,
    val configuredTriggers: List<WearTriggerData>,
    val knownGear: List<WearGearData>,
    val localization: WearLocalizationData,
    val themeData: WearThemeData
)

data class WearSendData(
    val capability: String,
    val uuid: String = "",
    val enabled: Boolean = false
)
