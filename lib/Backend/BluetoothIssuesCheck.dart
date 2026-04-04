import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

/// TODO: Connect together and to UI
/// Add strings for each type of action on the new card

final _permissionsLogger = Logger('Permissions');

enum BluetoothPermissionStatus { granted, denied, permanentlyDenied, unknown }

class BluetoothIssues with ChangeNotifier {
  static final BluetoothIssues instance = BluetoothIssues._internal();
  String? deniedPermission;

  BluetoothPermissionStatus get status => _bluetoothPermissionStatus;
  BluetoothPermissionStatus _bluetoothPermissionStatus =
      BluetoothPermissionStatus.unknown;

  BluetoothIssues._internal();

  Future<Map<Permission, String>> _getRequiredPermissions() async {
    Map<Permission, String> requiredPermissions = {};

    if (Platform.isAndroid &&
        (await DeviceInfoPlugin().androidInfo).version.sdkInt > 30) {
      requiredPermissions[Permission.bluetoothScan] = "bluetoothScan";
      requiredPermissions[Permission.bluetoothConnect] = "bluetoothConnect";
    } else if (Platform.isAndroid) {
      requiredPermissions[Permission.location] = "location";
      requiredPermissions[Permission.locationWhenInUse] = "locationWhenInUse";
    } else {
      requiredPermissions[Permission.bluetooth] = "bluetooth";
    }
    // For foreground service
    if (Platform.isAndroid) {
      requiredPermissions[Permission.notification] = "notification";
    }
    return requiredPermissions;
  }

  Future<void> openSettings() async {
    if (Platform.isAndroid) {
      switch (deniedPermission) {
        case "bluetoothScan":
        case "bluetoothConnect":
        case "bluetooth":
          await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
          break;
        case "location":
        case "locationWhenInUse":
          await AppSettings.openAppSettings(type: AppSettingsType.location);
          break;
        case "notifications":
          await AppSettings.openAppSettings(type: AppSettingsType.notification);
          break;
      }
    } else {
      await AppSettings.openAppSettings();
    }
  }

  void _setState(BluetoothPermissionStatus bluetoothPermissionStatus) {
    _bluetoothPermissionStatus = bluetoothPermissionStatus;
    notifyListeners();
  }

  Future<bool> hasPermissions() async {
    if (BluetoothPermissionStatus.granted == _bluetoothPermissionStatus) {
      return true;
    }

    Map<Permission, String> requiredPermissions =
        await _getRequiredPermissions();
    for (MapEntry<Permission, String> permission
        in requiredPermissions.entries) {
      if (await permission.key.isGranted) {
        continue;
      }
      bool isPermanentlyDenied = await permission.key.isPermanentlyDenied;
      if (await permission.key.isPermanentlyDenied || isPermanentlyDenied) {
        deniedPermission = permission.value;
        if (await permission.key.isPermanentlyDenied) {
          _setState(BluetoothPermissionStatus.permanentlyDenied);
          return false;
        }
        _setState(BluetoothPermissionStatus.denied);
        return false;
      } else {
        _setState(BluetoothPermissionStatus.unknown);
        return false;
      }
    }
    _setState(BluetoothPermissionStatus.granted);
    return true;
  }

  Future<void> requestPermissions() async {
    if (BluetoothPermissionStatus.granted == _bluetoothPermissionStatus) {
      return;
    }

    Map<Permission, String> requiredPermissions =
        await _getRequiredPermissions();
    for (MapEntry<Permission, String> permission
        in requiredPermissions.entries) {
      if (await permission.key.isGranted) {
        continue;
      }
      _permissionsLogger.info("Requesting permission ${permission.value}");
      PermissionStatus permissionStatus = await permission.key.request();
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        _permissionsLogger.warning(
          "Permission denied ${permission.value}. "
          "Permanent = ${permissionStatus.isPermanentlyDenied}",
        );
        deniedPermission = permission.value;
        if (permissionStatus.isPermanentlyDenied) {
          _setState(BluetoothPermissionStatus.permanentlyDenied);
          return;
        }
        _setState(BluetoothPermissionStatus.denied);
        return;
      }
    }
    _setState(BluetoothPermissionStatus.granted);
    return;
  }
}
