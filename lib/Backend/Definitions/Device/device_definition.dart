import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:tail_app/Backend/command_queue.dart';
import 'package:tail_app/Backend/dynamic_config.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../../Frontend/utils.dart';
import '../../../constants.dart';
import '../../Bluetooth/bluetooth_message.dart';
import '../../Bluetooth/known_devices.dart';
import '../../analytics.dart';
import '../../command_history.dart';
import '../../firmware_update.dart';
import '../../logging_wrappers.dart';
import '../../version.dart';

part 'device_definition.freezed.dart';

part 'device_definition.g.dart';

/// When adding new gear make sure to update `getNameFromBTName()`

@HiveType(typeId: 6)
enum DeviceType {
  @HiveField(1)
  tail,
  @HiveField(2)
  ears,
  @HiveField(3)
  wings,
  @HiveField(4)
  miniTail,
  @HiveField(5)
  claws,
} //TODO extend with icon

@HiveType(typeId: 14)
enum EarSpeed {
  @HiveField(1)
  fast,
  @HiveField(2)
  slow,
}

extension EarSpeedExtension on EarSpeed {
  String get name {
    switch (this) {
      case EarSpeed.fast:
        return earSpeedFast();
      case EarSpeed.slow:
        return earSpeedSlow();
    }
  }

  Widget get icon {
    switch (this) {
      case EarSpeed.fast:
        return const Icon(Icons.fast_forward);
      case EarSpeed.slow:
        return const Icon(Icons.play_arrow);
    }
  }

  String get command {
    switch (this) {
      case EarSpeed.fast:
        return "SPEED FAST";
      case EarSpeed.slow:
        return "SPEED SLOW";
    }
  }
}

extension DeviceTypeExtension on DeviceType {
  String get translatedName {
    switch (this) {
      case DeviceType.tail:
        return deviceTypeTail();
      case DeviceType.ears:
        return deviceTypeEars();
      case DeviceType.wings:
        return deviceTypeWings();
      case DeviceType.miniTail:
        return deviceTypeMiniTail();
      case DeviceType.claws:
        return deviceTypeClawGear();
    }
  }

  Color color() {
    Iterable<BaseStatefulDevice> knownDevices = [];
    knownDevices = KnownDevices.instance.state.values;

    int? color = knownDevices
        .where((element) => element.baseDeviceDefinition.deviceType == this)
        .map((e) => e.baseStoredDevice.color)
        .firstOrNull;
    if (color != null) {
      return Color(color);
    }
    switch (this) {
      case DeviceType.tail:
        return Colors.orangeAccent;
      case DeviceType.miniTail:
        return Colors.redAccent;
      case DeviceType.ears:
        return Colors.blueAccent;
      case DeviceType.wings:
        return Colors.greenAccent;
      case DeviceType.claws:
        return Colors.deepPurpleAccent;
    }
  }

  //mainly used to hide claws from the custom moves pages, since usermove/dssp isnt relevent there.
  bool isHidden() {
    switch (this) {
      case DeviceType.claws:
        return true;
      default:
        return false;
    }
  }
}

enum ConnectivityState { connected, disconnected, connecting }

enum DeviceState { standby, runAction, busy }

@HiveType(typeId: 15)
enum GlowtipStatus {
  @HiveField(1)
  glowtip,
  @HiveField(2)
  noGlowtip,
  @HiveField(3)
  unknown,
}

@HiveType(typeId: 16)
enum RGBStatus {
  @HiveField(1)
  rgb,
  @HiveField(2)
  noRGB,
  @HiveField(3)
  unknown,
}

enum TailControlStatus { tailControl, legacy, unknown }

@freezed
abstract class BluetoothUartService with _$BluetoothUartService {
  const factory BluetoothUartService({
    required String bleDeviceService,
    required String bleRxCharacteristic,
    required String bleTxCharacteristic,
    required String label,
  }) = _BluetoothUartService;
}

final List<BluetoothUartService> uartServices = const [
  BluetoothUartService(
    bleDeviceService: "3af2108b-d066-42da-a7d4-55648fa0a9b6",
    bleRxCharacteristic: "c6612b64-0087-4974-939e-68968ef294b0",
    bleTxCharacteristic: "5bfd6484-ddee-4723-bfe6-b653372bbfd6",
    label: "Legacy Gear",
  ),
  BluetoothUartService(
    bleDeviceService: "0000ffe0-0000-1000-8000-00805f9b34fb",
    bleRxCharacteristic: "",
    bleTxCharacteristic: "0000ffe1-0000-1000-8000-00805f9b34fb",
    label: "DigiTail",
  ),
  BluetoothUartService(
    bleDeviceService: "927dee04-ddd4-4582-8e42-69dc9fbfae66",
    bleRxCharacteristic: "0b646a19-371e-4327-b169-9632d56c0e84",
    bleTxCharacteristic: "05e026d8-b395-4416-9f8a-c00d6c3781b9",
    label: "Legacy Ears",
  ),
  // TailCoNTROL uuids
  BluetoothUartService(
    bleDeviceService: "19f8ade2-d0c6-4c0a-912a-30601d9b3060",
    bleRxCharacteristic: "567a99d6-a442-4ac0-b676-4993bf95f805",
    bleTxCharacteristic: "5e4d86ac-ef2f-466f-a857-8776d45ffbc2",
    label: "TailCoNTROL",
  ),
];

@freezed
abstract class BaseDeviceDefinition with _$BaseDeviceDefinition {
  const BaseDeviceDefinition._();

  const factory BaseDeviceDefinition({
    required String uuid,
    required String btName,
    required DeviceType deviceType,
    Version? minVersion,
    @Default(false) bool unsupported,
  }) = _BaseDeviceDefinition;

  Future<String> getFwURL() async {
    DynamicConfigInfo dynamicConfigInfo = await getDynamicConfigInfo();
    return dynamicConfigInfo.updateURLs[btName] ?? "";
  }
}

// data that represents the current state of a device
class BaseStatefulDevice {
  final BaseDeviceDefinition baseDeviceDefinition;
  final BaseStoredDevice baseStoredDevice;
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

  final ValueNotifier<DeviceState> deviceState = ValueNotifier(
    DeviceState.standby,
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

  BaseStatefulDevice(this.baseDeviceDefinition, this.baseStoredDevice) {
    Stream<OnCharacteristicReceivedEvent> deviceCharacteristicStream =
        FlutterBluePlus.events.onCharacteristicReceived
            .asBroadcastStream()
            .where(
              (event) =>
                  event.device.remoteId.str == baseStoredDevice.btMACAddress,
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
          props: {"Gear Type": baseDeviceDefinition.btName},
        );
        if (forgetOnDisconnect) {
          KnownDevices.instance.remove(baseStoredDevice.btMACAddress);
          analyticsEvent(
            name: "Forgetting Gear",
            props: {"Gear Type": baseDeviceDefinition.btName},
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
          props: {"Gear Type": baseDeviceDefinition.btName},
        );
        if (baseStoredDevice.btMACAddress.startsWith(demoGearPrefix)) {
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
    });
    // prevent gear from being stuck in a move.
    deviceState.addListener(_deviceStateWatchdog);

    // Store glowtip/rgb status
    hasGlowtip.value = baseStoredDevice.hasGlowtip;
    hasGlowtip.addListener(() {
      if (hasGlowtip.value != GlowtipStatus.unknown) {
        baseStoredDevice.hasGlowtip = hasGlowtip.value;
        KnownDevices.instance.store();
      }
    });
    hasRGB.value = baseStoredDevice.hasRGB;
    hasRGB.addListener(() {
      if (hasRGB.value != RGBStatus.unknown) {
        baseStoredDevice.hasRGB = hasRGB.value;
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
        baseStoredDevice.hardwareVersion != hwVersion.value) {
      baseStoredDevice.hardwareVersion = hwVersion.value;
      KnownDevices.instance.store();
    }
    if (fwVersion.value != Version() &&
        baseStoredDevice.firmwareVersion != fwVersion.value) {
      baseStoredDevice.firmwareVersion = fwVersion.value;
      KnownDevices.instance.store();
    }
    if (hwVersion.value.isNotEmpty && fwVersion.value != Version()) {
      await hasOtaUpdate(this).catchError((error, stackTrace) => true);
    }
  }

  void _periodicListener(dynamic event) {
    if (deviceConnectionState.value != ConnectivityState.connected) {
      return;
    }

    // Demo gear
    if (baseStoredDevice.btMACAddress.startsWith(demoGearPrefix)) {
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
    if (deviceState.value == DeviceState.runAction &&
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
          deviceState.value = DeviceState.standby;
        },
      );
    } else if (deviceState.value != DeviceState.runAction &&
        deviceStateWatchdogTimer != null) {
      deviceStateWatchdogTimer?.cancel();
      deviceStateWatchdogTimer = null;
    }
  }

  @override
  String toString() {
    return 'BaseStatefulDevice{baseDeviceDefinition: $baseDeviceDefinition, baseStoredDevice: $baseStoredDevice, battery: $batteryLevel}';
  }

  void reset() {
    batteryLevel.value = -1;
    batteryCharging.value = false;
    batteryLow.value = false;
    gearReturnedError.value = false;
    deviceState.value = DeviceState.standby;
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

@freezed
// TailControl only
abstract class GearConfigInfo with _$GearConfigInfo {
  const GearConfigInfo._();

  const factory GearConfigInfo({
    @Default("") String ver,
    @Default("") String minsToSleep,
    @Default("") String minsToNPM,
    @Default("") String minNPMPauseSec,
    @Default("") String maxNPMPauseSec,
    @Default("") String groupsNPM,
    @Default("") String servo1home,
    @Default("") String servo2home,
    @Default("") String listenModeNPMEnabled,
    @Default("") String listenModeResponseOnly,
    @Default("") String groupsLM,
    @Default("") String tiltModeNPMEnabled,
    @Default("") String tiltModeResponseOnly,
    @Default("") String disconnectedCountdownEnabled,
    @Default("") String homeOnAppPoweroff,
    @Default("") String conferenceModeEnabled,
    @Default("") String securityPasskey,
  }) = _GearConfigInfo;

  factory GearConfigInfo.fromGearString(String fwInput) {
    List<String> values = fwInput.split(" ");
    String ver = values[0];
    String minsToSleep = values[1];
    String minsToNPM = values[2];
    String minNPMPauseSec = values[3];
    String maxNPMPauseSec = values[4];
    String groupsNPM = values[5];
    String servo1home = values[6];
    String servo2home = values[7];
    String listenModeNPMEnabled = values[8];
    String listenModeResponseOnly = values[9];
    String groupsLM = values[10];
    String tiltModeNPMEnabled = values[11];
    String tiltModeResponseOnly = values[12];
    String disconnectedCountdownEnabled = values[13];
    String homeOnAppPoweroff = values[14];
    String conferenceModeEnabled = values[15];
    String securityPasskey = values[16];

    return GearConfigInfo(
      ver: ver,
      minsToSleep: minsToSleep,
      minsToNPM: minsToNPM,
      minNPMPauseSec: minNPMPauseSec,
      maxNPMPauseSec: maxNPMPauseSec,
      groupsNPM: groupsNPM,
      servo1home: servo1home,
      servo2home: servo2home,
      listenModeNPMEnabled: listenModeNPMEnabled,
      listenModeResponseOnly: listenModeResponseOnly,
      groupsLM: groupsLM,
      tiltModeNPMEnabled: tiltModeNPMEnabled,
      tiltModeResponseOnly: tiltModeResponseOnly,
      disconnectedCountdownEnabled: disconnectedCountdownEnabled,
      homeOnAppPoweroff: homeOnAppPoweroff,
      conferenceModeEnabled: conferenceModeEnabled,
      securityPasskey: securityPasskey,
    );
  }

  String toGearString() {
    return "$ver $minsToSleep $minsToNPM $minNPMPauseSec $maxNPMPauseSec $groupsNPM $servo1home $servo2home $listenModeNPMEnabled $listenModeResponseOnly $groupsLM $tiltModeNPMEnabled $tiltModeResponseOnly $disconnectedCountdownEnabled $homeOnAppPoweroff $conferenceModeEnabled $securityPasskey";
  }
}

// All serialized/stored data
@HiveType(typeId: 1)
class BaseStoredDevice extends ChangeNotifier {
  @HiveField(0)
  String name = "New Gear";
  @HiveField(7)
  final String btMACAddress;
  @HiveField(8)
  final String deviceDefinitionUUID;
  @HiveField(9)
  int _color;

  @HiveField(10, defaultValue: 1)
  int leftHomePosition = 1;
  @HiveField(11, defaultValue: 1)
  int rightHomePosition = 1;
  @HiveField(12, defaultValue: "")
  String conModePin = "";
  @HiveField(13, defaultValue: false)
  bool conModeEnabled = false;

  @HiveField(14, defaultValue: GlowtipStatus.unknown)
  GlowtipStatus hasGlowtip = GlowtipStatus.unknown;
  @HiveField(15, defaultValue: RGBStatus.unknown)
  RGBStatus hasRGB = RGBStatus.unknown;

  @HiveField(16, defaultValue: Version())
  Version firmwareVersion = Version();
  @HiveField(17, defaultValue: "")
  String hardwareVersion = "";

  int get color => _color;

  set color(int value) {
    _color = value;
    notifyListeners();
  }

  BaseStoredDevice(this.deviceDefinitionUUID, this.btMACAddress, this._color) {
    // Set convention mode pin to a random 6 digit number
    if (conModePin.isEmpty) {
      int code = Random().nextInt(899999) + 100000;
      conModePin = code.toString();
    }
  }

  @override
  String toString() {
    return 'BaseStoredDevice{name: $name, btMACAddress: $btMACAddress, deviceDefinitionUUID: $deviceDefinitionUUID}';
  }
}

String getNameFromBTName(String bluetoothDeviceName) {
  switch (bluetoothDeviceName) {
    case 'EarGear':
      return 'EarGear';
    case 'EG2':
      return 'EarGear 2';
    case 'mitail':
      return 'MiTail';
    case 'minitail':
      return 'Mini';
    case 'flutter':
      return 'FlutterWings';
    case '(!)Tail1':
      return 'DigiTail';
    case 'clawgear':
      return 'Claws';
  }
  return bluetoothDeviceName;
}
