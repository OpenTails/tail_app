import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tail_app/Backend/utilities/version.dart';

import '../../Frontend/utils.dart';
import '../../constants.dart';
import '../../vendor/aptabase/storage_manager_hive.dart';
import '../Action/action_category.dart';
import '../Action/base_action.dart';
import '../Device/common_device_stuffs.dart';
import '../Device/device_type_enum.dart';
import '../Device/ear_speed_enum.dart';
import '../Device/stored_device.dart';
import '../favorite_actions.dart';
import '../move_lists_backend.dart';
import '../triggers/trigger.dart';
import '../triggers/trigger_action.dart';

Logger _logger = Logger("Hive");
bool _didInitHive = false;

bool get isHiveReady => _didInitHive;

void _registerHiveTypes() {
  //Hive Type ID 1
  if (!Hive.isAdapterRegistered(StoredDeviceAdapter().typeId)) {
    Hive.registerAdapter(StoredDeviceAdapter());
  }
  //Hive Type ID 2
  if (!Hive.isAdapterRegistered(TriggerAdapter().typeId)) {
    Hive.registerAdapter(TriggerAdapter());
  }
  //Hive Type ID 3
  if (!Hive.isAdapterRegistered(MoveListAdapter().typeId)) {
    Hive.registerAdapter(MoveListAdapter());
  }
  //Hive Type ID 5
  if (!Hive.isAdapterRegistered(MoveAdapter().typeId)) {
    Hive.registerAdapter(MoveAdapter());
  }
  //Hive Type ID 6
  if (!Hive.isAdapterRegistered(DeviceTypeAdapter().typeId)) {
    Hive.registerAdapter(DeviceTypeAdapter());
  }
  //Hive Type ID 7
  if (!Hive.isAdapterRegistered(ActionCategoryAdapter().typeId)) {
    Hive.registerAdapter(ActionCategoryAdapter());
  }
  //Hive Type ID 8
  if (!Hive.isAdapterRegistered(TriggerActionAdapter().typeId)) {
    Hive.registerAdapter(TriggerActionAdapter());
  }
  //Hive Type ID 10
  if (!Hive.isAdapterRegistered(EasingTypeAdapter().typeId)) {
    Hive.registerAdapter(EasingTypeAdapter());
  }
  //Hive Type ID 11
  if (!Hive.isAdapterRegistered(MoveTypeAdapter().typeId)) {
    Hive.registerAdapter(MoveTypeAdapter());
  }
  //Hive Type ID 12
  if (!Hive.isAdapterRegistered(AudioActionAdapter().typeId)) {
    Hive.registerAdapter(AudioActionAdapter());
  }
  //Hive Type ID 13
  if (!Hive.isAdapterRegistered(FavoriteActionAdapter().typeId)) {
    Hive.registerAdapter(FavoriteActionAdapter());
  }
  //Hive Type ID 14
  if (!Hive.isAdapterRegistered(EarSpeedAdapter().typeId)) {
    Hive.registerAdapter(EarSpeedAdapter());
  }
  //Hive Type ID 15
  if (!Hive.isAdapterRegistered(GlowtipStatusAdapter().typeId)) {
    Hive.registerAdapter(GlowtipStatusAdapter());
  }
  //Hive Type ID 16
  if (!Hive.isAdapterRegistered(RGBStatusAdapter().typeId)) {
    Hive.registerAdapter(RGBStatusAdapter());
  }
  //Hive Type ID 17
  if (!Hive.isAdapterRegistered(VersionAdapter().typeId)) {
    Hive.registerAdapter(VersionAdapter());
  }
}

Future<void> initHive() async {
  if (_didInitHive) {
    return;
  }
  _logger.fine("Init Hive");
  if (isMobile) {
    final Directory appDir = await getApplicationSupportDirectory();
    Hive.init(appDir.path);
  } else if (kIsWeb) {
    Hive.init("");
  } else {
    Hive.init(Directory(".HiveTest").path);
  }
  _registerHiveTypes();
  try {
    await openBoxes();
  } catch (e, s) {
    _logger.severe("Failed to open hive box: ", e, s);
    await deleteAllBoxes();
    await openBoxes();
  }

  _didInitHive = true;
}

Future<void> openBoxes() async {
  await Hive.openBox(settings); // Do not set type here
}

@visibleForTesting
Future<void> deleteAllBoxes() async {
  _logger.warning("Deleting stored hive data");
  await Hive.deleteBoxFromDisk(settings);
  await Hive.deleteBoxFromDisk(triggerBox);
  await Hive.deleteBoxFromDisk(favoriteActionsBox);
  await Hive.deleteBoxFromDisk(audioActionsBox);
  await Hive.deleteBoxFromDisk(sequencesBox);
  await Hive.deleteBoxFromDisk(devicesBox);
  await Hive.deleteBoxFromDisk(aptabaseEventBoxName);
}
