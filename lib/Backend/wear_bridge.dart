import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

import 'Definitions/Action/base_action.dart';
import 'action_registry.dart';
import 'favorite_actions.dart';

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

    updateWearActions(ref.read(favoriteActionsProvider), ref);
  } catch (e, s) {
    _wearLogger.severe("exception setting up Wear $e", e, s);
  }
}

Future<bool> isReachable() {
  return _watch.isReachable;
}

Future<bool> isSupported() {
  return _watch.isSupported;
}

Future<bool> isPaired() {
  return _watch.isPaired;
}

Future<Map<String, dynamic>> applicationContext() {
  return _watch.applicationContext;
}

Future<void> updateWearActions(BuiltList<FavoriteAction> favoriteActions, Ref ref) async {
  try {
    Iterable<BaseAction> allActions = favoriteActions
        .map(
          (e) => ref.read(getActionFromUUIDProvider(e.actionUUID)),
        )
        .whereNotNull();
    final Map<String, String> favoriteMap = Map.fromEntries(allActions.map((e) => MapEntry(e.uuid, e.name)));
    final Map<String, String> map = Map.fromEntries(
      [
        MapEntry("actions", favoriteMap.values.join("_")),
        MapEntry("uuid", favoriteMap.keys.join("_")),
      ],
    );
    if (await _watch.isReachable) {
      await _watch.sendMessage(map);
    }
  } catch (e, s) {
    _wearLogger.severe("Unable to send favorite actions to watch", e, s);
  }
}
