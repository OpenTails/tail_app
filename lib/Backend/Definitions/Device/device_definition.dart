import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tail_app/Backend/Definitions/Device/stored_device.dart';
import 'package:tail_app/Backend/command_queue.dart';
import 'package:tail_app/Backend/dynamic_config.dart';

import '../../../Frontend/utils.dart';
import '../../../constants.dart';
import '../../Bluetooth/bluetooth_message.dart';
import '../../Bluetooth/known_devices.dart';
import '../../analytics.dart';
import '../../command_history.dart';
import '../../firmware_update.dart';
import '../../logging_wrappers.dart';
import '../../version.dart';
import 'bluetooth_uart_services_list.dart';
import 'common_device_stuffs.dart';
import 'device_type_enum.dart';

part 'device_definition.freezed.dart';

/// When adding new gear make sure to update `getNameFromBTName()`

enum ConnectivityState { connected, disconnected, connecting }

enum DeviceMoveState { standby, runAction, busy }

enum TailControlStatus { tailControl, legacy, unknown }

@freezed
abstract class DeviceDefinition with _$DeviceDefinition {
  const DeviceDefinition._();

  const factory DeviceDefinition({
    required String uuid,
    required String btName,
    required DeviceType deviceType,
    Version? minVersion,
    @Default(false) bool unsupported,
  }) = _DeviceDefinition;

  Future<String> getFwURL() async {
    DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
    return dynamicConfigInfo.updateURLs[btName] ?? "";
  }
}

// data that represents the current state of a device
//TODO: Split firmware & battery into subclasses for organization
class StatefulDevice {
  final DeviceDefinition deviceDefinition;
  final StoredDevice storedDevice;
  final ValueNotifier<BluetoothUartService?> bluetoothUartService =
      ValueNotifier(null);
  late final CommandQueue commandQueue;

  final ValueNotifier<double> batteryLevel = ValueNotifier(-1);
  final ValueNotifier<bool> batteryCharging = ValueNotifier(false);
  final ValueNotifier<bool> batteryLow = ValueNotifier(false);
  final ValueNotifier<bool> gearReturnedError = ValueNotifier(false);
  final ValueNotifier<Version> fwVersion = ValueNotifier(const Version());
  final ValueNotifier<String> hwVersion = ValueNotifier("");
  final ValueNotifier<GlowtipStatus> hasGlowtip = ValueNotifier(
    GlowtipStatus.unknown,
  );
  final ValueNotifier<RGBStatus> hasRGB = ValueNotifier(RGBStatus.unknown);

  final ValueNotifier<DeviceMoveState> deviceState = ValueNotifier(
    DeviceMoveState.standby,
  );
  final ValueNotifier<ConnectivityState> deviceConnectionState = ValueNotifier(
    ConnectivityState.disconnected,
  );
  final ValueNotifier<int> rssi = ValueNotifier(-1);
  final ValueNotifier<int> mtu = ValueNotifier(-1);
  final ValueNotifier<GearConfigInfo> gearConfigInfo = ValueNotifier(
    GearConfigInfo(),
  );
  final ValueNotifier<FWInfo?> fwInfo = ValueNotifier(null);
  final ValueNotifier<bool> hasUpdate = ValueNotifier(false);
  final ValueNotifier<TailControlStatus> isTailCoNTROL = ValueNotifier(
    TailControlStatus.unknown,
  );
  late final Stream<String> rxCharacteristicStream;
  List<FlSpot> batlevels = [];
  Stopwatch stopWatch = Stopwatch();

  StreamSubscription? _periodicTimerStream;

  bool disableAutoConnect = false;
  bool forgetOnDisconnect = false;
  ValueNotifier<bool> mandatoryOtaRequired = ValueNotifier(false);
  Timer? deviceStateWatchdogTimer;

  StatefulDevice(this.deviceDefinition, this.storedDevice) {
    Stream<OnCharacteristicReceivedEvent> deviceCharacteristicStream =
        FlutterBluePlus.events.onCharacteristicReceived
            .asBroadcastStream()
            .where(
              (event) => event.device.remoteId.str == storedDevice.btMACAddress,
            );

    rxCharacteristicStream = deviceCharacteristicStream
        .where(
          (event) =>
              event.characteristic.characteristicUuid.str ==
              bluetoothUartService.value!.bleRxCharacteristic,
        )
        .map((event) {
          try {
            return const Utf8Decoder().convert(event.value);
          } catch (e) {
            bluetoothLog.warning("Unable to read values: ${event.value} $e");
          }
          return "";
        })
        .where((event) => event.isNotEmpty);
    rxCharacteristicStream.asBroadcastStream().listen(_receivedCommandListener);

    deviceCharacteristicStream
        .where(
          (event) =>
              event.characteristic.characteristicUuid.str ==
              "5073792e-4fc0-45a0-b0a5-78b6c1756c91",
        )
        .map((event) {
          try {
            return const Utf8Decoder().convert(event.value);
          } catch (e) {
            bluetoothLog.warning("Unable to read values: ${event.value} $e");
          }
          return "";
        })
        .where((event) => event.isNotEmpty)
        .listen((event) {
          batteryCharging.value = event == "CHARGE ON";
        });
    deviceCharacteristicStream
        .where((event) => event.characteristic.characteristicUuid.str == "2a19")
        .listen((event) {
          batteryLevel.value = event.value.first.toDouble();
        });
    commandQueue = CommandQueue(this);

    deviceConnectionState.addListener(() {
      if (deviceConnectionState.value == ConnectivityState.disconnected) {
        reset();
        analyticsEvent(
          name: "Disconnect Gear",
          props: {"Gear Type": deviceDefinition.btName},
        );
        if (forgetOnDisconnect) {
          KnownDevices.instance.remove(storedDevice.btMACAddress);
          analyticsEvent(
            name: "Forgetting Gear",
            props: {"Gear Type": deviceDefinition.btName},
          );
        }
      }
      if (deviceConnectionState.value == ConnectivityState.connected) {
        // The timer used for the time value on the battery level graph
        stopWatch.start();
        _periodicTimerStream = Stream.periodic(
          const Duration(seconds: 10),
        ).listen(_periodicListener);
        analyticsEvent(
          name: "Connect Gear",
          props: {"Gear Type": deviceDefinition.btName},
        );
        if (storedDevice.btMACAddress.startsWith(demoGearPrefix)) {
          bluetoothUartService.value = uartServices.firstWhere(
            (element) => element.label == "TailCoNTROL",
          );
        }
      }
    });
    batteryLevel.addListener(() {
      batlevels.add(
        FlSpot(stopWatch.elapsed.inSeconds.toDouble(), batteryLevel.value),
      );
      batteryLow.value = batteryLevel.value < 20;
    });

    bluetoothUartService.addListener(() {
      if (bluetoothUartService.value == null) {
        isTailCoNTROL.value = TailControlStatus.unknown;
        return;
      }

      isTailCoNTROL.value =
          bluetoothUartService.value ==
              uartServices.firstWhere(
                (element) =>
                    element.bleDeviceService.toLowerCase() ==
                    "19f8ade2-d0c6-4c0a-912a-30601d9b3060",
              )
          ? TailControlStatus.tailControl
          : TailControlStatus.legacy;

      //Fires off the FW/HW version and batt commands
      _periodicListener("");
    });
    // prevent gear from being stuck in a move.
    deviceState.addListener(_deviceStateWatchdog);

    // Store glowtip/rgb status
    hasGlowtip.value = storedDevice.hasGlowtip;
    hasGlowtip.addListener(() {
      if (hasGlowtip.value != GlowtipStatus.unknown) {
        storedDevice.hasGlowtip = hasGlowtip.value;
        KnownDevices.instance.store();
      }
    });
    hasRGB.value = storedDevice.hasRGB;
    hasRGB.addListener(() {
      if (hasRGB.value != RGBStatus.unknown) {
        storedDevice.hasRGB = hasRGB.value;
        KnownDevices.instance.store();
      }
    });

    // only store, do not read back on gear load
    hwVersion.addListener(_versionListener);
    fwVersion.addListener(_versionListener);
  }

  Future<void> _receivedCommandListener(String value) async {
    commandQueue.commandHistory.add(
      type: MessageHistoryType.receive,
      message: value,
    );
    // Firmware Version
    if (value.startsWith("VER")) {
      fwVersion.value = getVersionSemVer(value.substring(value.indexOf(" ")));
      if (isTailCoNTROL.value == TailControlStatus.tailControl) {
        commandQueue.addCommand(
          BluetoothMessage(message: "READNVS", timestamp: DateTime.timestamp()),
        );
      }
      // Sent after VER message
    } else if (value.startsWith("GLOWTIP")) {
      String substring = value.substring(value.indexOf(" ")).trim();
      if (substring == 'TRUE') {
        hasGlowtip.value = GlowtipStatus.glowtip;
      } else if (substring == 'FALSE') {
        hasGlowtip.value = GlowtipStatus.noGlowtip;
      }
    } else if (value.startsWith("RGB")) {
      String substring = value.substring(value.indexOf(" ")).trim();
      if (substring == 'TRUE') {
        hasRGB.value = RGBStatus.rgb;
      } else if (substring == 'FALSE') {
        hasRGB.value = RGBStatus.noRGB;
      }
    } else if (value.contains("BUSY")) {
      //statefulDevice.deviceState.value = DeviceState.busy;
      gearReturnedError.value = true;
    } else if (value.contains("LOWBATT")) {
      batteryLow.value = true;
    } else if (value.contains("ERR")) {
      gearReturnedError.value = true;
    } else if (value.contains("SHUTDOWN BEGIN")) {
      deviceConnectionState.value = ConnectivityState.disconnected;
    } else if (value.contains("HWVER") ||
        value.contains("MITAIL") ||
        value.contains("MINITAIL") ||
        value.contains("FLUTTERWINGS")) {
      // Hardware Version
      hwVersion.value = value.substring(value.indexOf(" "));
    } else if (value.contains("READNVS")) {
      try {
        gearConfigInfo.value = GearConfigInfo.fromGearString(
          value.replaceFirst("READNVS ", ""),
        );
      } on Exception {
        //_bluetoothPlusLogger.warning("Unable to parse NVS data: $e");
      }
    } else if (int.tryParse(value) != null) {
      // Battery Level
      batteryLevel.value = int.parse(value).toDouble();
    }
  }

  Future<void> _versionListener() async {
    if (hwVersion.value != "" &&
        storedDevice.hardwareVersion != hwVersion.value) {
      storedDevice.hardwareVersion = hwVersion.value;
      KnownDevices.instance.store();
    }
    if (fwVersion.value != Version() &&
        storedDevice.firmwareVersion != fwVersion.value) {
      storedDevice.firmwareVersion = fwVersion.value;
      KnownDevices.instance.store();
    }
    if (hwVersion.value.isNotEmpty && fwVersion.value != Version()) {
      await hasOtaUpdate(this).catchError((error, stackTrace) => true);
    }
  }

  void _periodicListener(dynamic ignored) {
    if (deviceConnectionState.value != ConnectivityState.connected) {
      return;
    }

    // Demo gear
    if (storedDevice.btMACAddress.startsWith(demoGearPrefix)) {
      batteryLevel.value = Random().nextInt(100).toDouble();
      rssi.value = (Random().nextInt(100) * -1);
    }
    // required to keep the connection open on IOS, otherwise the app will suspend and walk mode will stop working
    // also required to keep eargear awake
    commandQueue.addCommand(
      BluetoothMessage(
        message: "PING",
        priority: Priority.low,
        type: CommandType.system,
        timestamp: DateTime.now(),
      ),
    );
    // Battery characteristic works fine for tailcontrol, so we don't need to manually request the battery level
    if (isTailCoNTROL.value != TailControlStatus.tailControl) {
      commandQueue.addCommand(
        BluetoothMessage(
          message: "BATT",
          priority: Priority.low,
          type: CommandType.system,
          timestamp: DateTime.now(),
        ),
      );
    }

    if (fwVersion.value == Version()) {
      commandQueue.addCommand(
        BluetoothMessage(
          message: "VER",
          priority: Priority.low,
          type: CommandType.system,
          timestamp: DateTime.now(),
        ),
      );
    }
    if (hwVersion.value.isEmpty) {
      commandQueue.addCommand(
        BluetoothMessage(
          message: "HWVER",
          priority: Priority.low,
          type: CommandType.system,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void _deviceStateWatchdog() {
    if (deviceState.value == DeviceMoveState.runAction &&
        deviceStateWatchdogTimer == null) {
      deviceStateWatchdogTimer = Timer(
        Duration(
          seconds: HiveProxy.getOrDefault(
            settings,
            triggerActionCooldown,
            defaultValue: triggerActionCooldownDefault,
          ),
        ),
        () {
          deviceState.value = DeviceMoveState.standby;
        },
      );
    } else if (deviceState.value != DeviceMoveState.runAction &&
        deviceStateWatchdogTimer != null) {
      deviceStateWatchdogTimer?.cancel();
      deviceStateWatchdogTimer = null;
    }
  }

  @override
  String toString() {
    return 'statefulDevice{deviceDefinition: $deviceDefinition, storedDevice: $storedDevice, battery: $batteryLevel}';
  }

  void reset() {
    batteryLevel.value = -1;
    batteryCharging.value = false;
    batteryLow.value = false;
    gearReturnedError.value = false;
    deviceState.value = DeviceMoveState.standby;
    rssi.value = -1;
    hasUpdate.value = false;
    fwVersion.value = const Version();
    batlevels = [];
    stopWatch.reset();
    mtu.value = -1;
    mandatoryOtaRequired.value = false;
    isTailCoNTROL.value = TailControlStatus.unknown;
    bluetoothUartService.value = null;
    _periodicTimerStream?.cancel();
    _periodicTimerStream = null;
  }
}
