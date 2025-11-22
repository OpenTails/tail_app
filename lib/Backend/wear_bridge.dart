import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/known_devices.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Backend/command_runner.dart';
import 'package:tail_app/Backend/device_registry.dart';
import 'package:tail_app/Backend/sensors.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/translation_string_definitions.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

import 'Definitions/Action/base_action.dart';
import 'action_registry.dart';
import 'favorite_actions.dart';

part 'wear_bridge.freezed.dart';

part 'wear_bridge.g.dart';

final Logger _wearLogger = Logger('Wear');
final _watch = WatchConnectivity();
WearThemeData? wearThemeData;

@Riverpod(keepAlive: true)
class MessageStreamSubscription extends _$MessageStreamSubscription {
  StreamSubscription<Map<String, dynamic>>? _messageStreamSubscription;

  @override
  void build() {
    // Get the state of device connectivity
    _messageStreamSubscription = _watch.messageStream.listen(listener);
    ref.onDispose(() => _messageStreamSubscription?.cancel());
  }

  void listener(Map<String, dynamic> event) {
    _wearLogger.info("Watch Message: $event");
    WearCommand wearCommand = WearCommand.fromJson(event);
    switch (wearCommand.capability) {
      case "run_action":
        BaseAction? action = ref.read(getActionFromUUIDProvider(wearCommand.uuid));
        if (action != null) {
          Iterable<BaseStatefulDevice> knownDevices = KnownDevices.instance.connectedIdleGear;
          for (BaseStatefulDevice device in knownDevices) {
            ref.read(runActionProvider(device).notifier).runAction(action, triggeredBy: "Watch");
          }
        }
        break;
      case "toggle_trigger":
        Trigger? trigger = ref.read(triggerListProvider).where((p0) => p0.uuid == wearCommand.uuid).firstOrNull;
        if (trigger != null) {
          trigger.enabled = wearCommand.enabled;
        }
        break;
      case "refresh":
        // ignore: unused_result
        ref.refresh(updateWearDataProvider);
        break;
    }
  }
}

@Riverpod(keepAlive: true)
class KnownGearBatteryListener extends _$KnownGearBatteryListener {
  @override
  void build() {
    KnownDevices.instance
      ..removeListener(listener)
      ..addListener(listener)
      ..state.values
          .map((e) => e.batteryLevel)
          .forEach(
            (element) => element
              ..removeListener(listener)
              ..addListener(listener),
          );
  }

  void listener() {
    // ignore: unused_result
    ref.refresh(updateWearDataProvider);
  }
}

@Riverpod(keepAlive: true)
Future<void> initWear(Ref ref) async {
  await Future.delayed(const Duration(seconds: 5));
  try {
    ref.watch(messageStreamSubscriptionProvider);
    ref.watch(knownGearBatteryListenerProvider);
  } catch (e, s) {
    _wearLogger.severe("exception setting up Wear $e", e, s);
  }
}

Future<bool> isReachable() {
  return _watch.isReachable.catchError((e) => false).onError((error, stackTrace) => false);
}

Future<bool> isSupported() {
  return _watch.isSupported.catchError((e) => false).onError((error, stackTrace) => false);
}

Future<bool> isPaired() {
  return _watch.isPaired.catchError((e) => false).onError((error, stackTrace) => false);
}

Future<Map<String, dynamic>> applicationContext() {
  return _watch.applicationContext.catchError((e) => <String, dynamic>{}).onError((error, stackTrace) => {});
}

@Riverpod()
Future<void> updateWearData(Ref ref) async {
  try {
    if (!await isPaired()) {
      return; // Don't update wear actions if wear is not supported / no watch is paired
    }
    Iterable<BaseAction> allActions = ref.read(favoriteActionsProvider).map((e) => ref.read(getActionFromUUIDProvider(e.actionUUID))).nonNulls;
    BuiltList<Trigger> triggers = ref.watch(triggerListProvider);
    final List<WearActionData> favoriteMap = allActions.map((e) => WearActionData(uuid: e.uuid, name: e.name)).toList();
    final List<WearTriggerData> triggersMap = triggers.map((e) => WearTriggerData(uuid: e.uuid, name: e.triggerDefinition!.name(), enabled: e.enabled)).toList();
    final List<WearGearData> knownGear = KnownDevices.instance.state.values
        .map(
          (e) => WearGearData(
            name: e.baseStoredDevice.name,
            uuid: e.baseStoredDevice.btMACAddress,
            batteryLevel: e.batteryLevel.value.toInt(),
            connected: e.deviceConnectionState.value == ConnectivityState.connected,
            color: e.baseStoredDevice.color,
          ),
        )
        .toList();
    // Listen for gear connect/disconnect events
    //TODO: rework entire gear handler without riverpod
    //ref.watch(getAvailableGearProvider);

    final WearLocalizationData localizationData = WearLocalizationData(
      triggersPage: convertToUwU(triggersPage()),
      actionsPage: convertToUwU(watchFavoriteActionsTitle()),
      favoriteActionsDescription: convertToUwU(watchFavoriteActionsNoFavoritesTip()),
      knownGear: convertToUwU(watchKnownGearTitle()),
      watchKnownGearNoGearPairedTip: convertToUwU(watchKnownGearNoGearPairedTip()),
    );
    final WearData wearData = WearData(favoriteActions: favoriteMap, configuredTriggers: triggersMap, themeData: wearThemeData!, knownGear: knownGear, localization: localizationData);
    if (await isReachable()) {
      await _watch.updateApplicationContext(wearData.toJson());
    }
  } catch (e, s) {
    _wearLogger.severe("Unable to send favorite actions to watch", e, s);
  }
}

@freezed
abstract class WearData with _$WearData {
  const factory WearData({
    required List<WearActionData> favoriteActions,
    required List<WearTriggerData> configuredTriggers,
    required List<WearGearData> knownGear,
    required WearLocalizationData localization,
    required WearThemeData themeData,
  }) = _WearData;

  factory WearData.fromJson(Map<String, dynamic> json) => _$WearDataFromJson(json);
}

@freezed
abstract class WearThemeData with _$WearThemeData {
  const factory WearThemeData({required int primary, required int secondary}) = _WearThemeData;

  factory WearThemeData.fromJson(Map<String, dynamic> json) => _$WearThemeDataFromJson(json);
}

@freezed
abstract class WearTriggerData with _$WearTriggerData {
  const factory WearTriggerData({required String name, required String uuid, required bool enabled}) = _WearTriggerData;

  factory WearTriggerData.fromJson(Map<String, dynamic> json) => _$WearTriggerDataFromJson(json);
}

@freezed
abstract class WearLocalizationData with _$WearLocalizationData {
  const factory WearLocalizationData({
    required String triggersPage,
    required String actionsPage,
    required String knownGear,
    required String favoriteActionsDescription,
    required String watchKnownGearNoGearPairedTip,
  }) = _WearLocalizationData;

  factory WearLocalizationData.fromJson(Map<String, dynamic> json) => _$WearLocalizationDataFromJson(json);
}

@freezed
abstract class WearGearData with _$WearGearData {
  const factory WearGearData({required String name, required String uuid, required bool connected, required int batteryLevel, required int color}) = _WearGearData;

  factory WearGearData.fromJson(Map<String, dynamic> json) => _$WearGearDataFromJson(json);
}

@freezed
abstract class WearActionData with _$WearActionData {
  const factory WearActionData({required String name, required String uuid}) = _WearActionData;

  factory WearActionData.fromJson(Map<String, dynamic> json) => _$WearActionDataFromJson(json);
}

@freezed
abstract class WearCommand with _$WearCommand {
  const factory WearCommand({required String capability, @Default("") String uuid, @Default(false) bool enabled}) = _WearCommand;

  factory WearCommand.fromJson(Map<String, dynamic> json) => _$WearCommandFromJson(json);
}

enum WearCommandType { runAction, toggleTrigger }
