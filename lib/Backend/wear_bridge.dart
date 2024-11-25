import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/sensors.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

import 'Definitions/Action/base_action.dart';
import 'action_registry.dart';
import 'favorite_actions.dart';

part 'wear_bridge.freezed.dart';
part 'wear_bridge.g.dart';

final Logger _wearLogger = Logger('Wear');
StreamSubscription<Map<String, dynamic>>? _messageStreamSubscription;
StreamSubscription<Map<String, dynamic>>? _contextStreamSubscription;
final _watch = WatchConnectivity();

@Riverpod(keepAlive: true)
Future<void> initWear(InitWearRef ref) async {
  await Future.delayed(const Duration(seconds: 5));
  try {
    // Get the state of device connectivity
    _messageStreamSubscription = _watch.messageStream.listen(
      (event) => _wearLogger.info("Watch Message: $event"),
    );
    _contextStreamSubscription = _watch.contextStream.listen(
      (event) => _wearLogger.info("Watch Context: $event"),
    );

    ref.read(updateWearActionsProvider);
  } catch (e, s) {
    _wearLogger.severe("exception setting up Wear $e", e, s);
  }
}

Future<bool> isReachable() {
  return _watch.isReachable.catchError((e) => false).onError(
        (error, stackTrace) => false,
      );
  ;
}

Future<bool> isSupported() {
  return _watch.isSupported.catchError((e) => false).onError(
        (error, stackTrace) => false,
      );
}

Future<bool> isPaired() {
  return _watch.isPaired.catchError((e) => false).onError(
        (error, stackTrace) => false,
      );
  ;
}

Future<Map<String, dynamic>> applicationContext() {
  return _watch.applicationContext.catchError((e) => <String, dynamic>{}).onError(
        (error, stackTrace) => {},
      );
}

@Riverpod()
Future<void> updateWearActions(UpdateWearActionsRef ref) async {
  try {
    Iterable<BaseAction> allActions = ref
        .read(favoriteActionsProvider)
        .map(
          (e) => ref.read(getActionFromUUIDProvider(e.actionUUID)),
        )
        .nonNulls;
    //TODO: refresh when trigger toggled state changes
    BuiltList<Trigger> triggers = ref.read(triggerListProvider);
    final List<WearActionData> favoriteMap = allActions.map((e) => WearActionData(uuid: e.uuid, name: e.name)).toList();
    final List<WearTriggerData> triggersMap = triggers.map((e) => WearTriggerData(uuid: e.uuid, name: e.triggerDefinition!.name, enabled: e.enabled)).toList();

    final WearData wearData = WearData(favoriteActions: favoriteMap, configuredTriggers: triggersMap);
    if (await _watch.isReachable) {
      await _watch.updateApplicationContext(wearData.toJson());
    }
  } catch (e, s) {
    _wearLogger.severe("Unable to send favorite actions to watch", e, s);
  }
}

@freezed
class WearData with _$WearData {
  const factory WearData({
    required List<WearActionData> favoriteActions,
    required List<WearTriggerData> configuredTriggers,
  }) = _WearData;

  factory WearData.fromJson(Map<String, dynamic> json) => _$WearDataFromJson(json);
}

@freezed
class WearTriggerData with _$WearTriggerData {
  const factory WearTriggerData({
    required String name,
    required String uuid,
    required bool enabled,
  }) = _WearTriggerData;

  factory WearTriggerData.fromJson(Map<String, dynamic> json) => _$WearTriggerDataFromJson(json);
}

@freezed
class WearActionData with _$WearActionData {
  const factory WearActionData({
    required String name,
    required String uuid,
  }) = _WearActionData;

  factory WearActionData.fromJson(Map<String, dynamic> json) => _$WearActionDataFromJson(json);
}

@freezed
class WearCommand with _$WearCommand {
  const factory WearCommand({
    required WearCommandType commandType,
    required String uuid,
    @Default(false) bool boolean,
  }) = _WearCommand;

  factory WearCommand.fromJson(Map<String, dynamic> json) => _$WearCommandFromJson(json);
}

enum WearCommandType {
  runAction,
  toggleTrigger,
}
