import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Device/stateful/battery_status.dart';
import 'package:tail_app/Backend/Device/stateful/firmware_status.dart';
import 'package:tail_app/Backend/utilities/demo_gear_helpers.dart';

import '../../Bluetooth/bluetooth_message.dart';
import '../../Bluetooth/known_devices.dart';
import '../../analytics.dart';
import '../../utilities/version.dart';
import '../bluetooth_uart_services_list.dart';
import '../command/command_history.dart';
import '../command/command_queue.dart';
import '../common_device_stuffs.dart';
import '../device_definition.dart';
import '../ota/firmware_update.dart';
import '../stored_device.dart';

enum ConnectivityState { connected, disconnected, connecting }

enum DeviceMoveState { standby, runAction, busy }

class StatefulDevice {
  final Logger _logger = Logger("StatefulDevice");
  final DeviceDefinition deviceDefinition;
  final StoredDevice storedDevice;
  final ValueNotifier<BluetoothUartService?> bluetoothUartService =
      ValueNotifier(null);
  late final CommandQueue commandQueue;

  final BatteryStatus battery = BatteryStatus();
  final FirmwareStatus firmwareStatus = FirmwareStatus();

  final ValueNotifier<bool> gearReturnedError = ValueNotifier(false);
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
  Stream<String>? rxCharacteristicStream;
  StreamSubscription? _periodicTimerStream;

  bool disableAutoConnect = false;
  bool forgetOnDisconnect = false;
  Timer? _connectBleServiceWatchdog;

  StatefulDevice(this.deviceDefinition, this.storedDevice) {
    commandQueue = CommandQueue(this);

    deviceConnectionState.addListener(() {
      if (deviceConnectionState.value == ConnectivityState.disconnected) {
        reset();
        analyticsEvent(
          name: "Disconnect Gear",
          props: {"Gear Type": deviceDefinition.btName},
        );
        if (forgetOnDisconnect) {
          _logger.info("Forgetting device");
          KnownDevices.instance.remove(storedDevice.btMACAddress);
          analyticsEvent(
            name: "Forgetting Gear",
            props: {"Gear Type": deviceDefinition.btName},
          );
        }
      } else {
        _connectBleServiceWatchdog = Timer(Duration(seconds: 10), () {
          if (bluetoothUartService.value != null ||
              deviceConnectionState.value != ConnectivityState.connected) {
            _connectBleServiceWatchdog = null;
            return;
          }
          _logger.severe(
            "Failed to connect or locate BLE UART service in time for device ${deviceDefinition.btName}.",
          );
          disconnect(storedDevice.btMACAddress);
        });
      }
      if (deviceConnectionState.value == ConnectivityState.connected) {
        _periodicTimerStream = Stream.periodic(
          const Duration(seconds: 10),
        ).listen(_periodicListener);
        analyticsEvent(
          name: "Connect Gear",
          props: {"Gear Type": deviceDefinition.btName},
        );
      }
    });

    bluetoothUartService.addListener(() {
      if (bluetoothUartService.value == null) {
        return;
      }
      _registerCharacteristicStreams();

      //Fires off the FW/HW version and batt commands
      _periodicListener("");
    });

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
    firmwareStatus.addListener(_versionListener);
  }

  StreamSubscription<String>? _rxCharacteristicStreamSubscription;
  StreamSubscription<bool>? _batteryChargingStreamSubscription;
  StreamSubscription<double>? _batteryStreamSubscription;

  void _registerCharacteristicStreams() {
    if (bluetoothUartService.value == null) {
      return;
    }
    rxCharacteristicStream = getRxStream(
      storedDevice.btMACAddress,
      bluetoothUartService.value!.bleRxCharacteristic,
    );
    _rxCharacteristicStreamSubscription = rxCharacteristicStream!.listen(
      _receivedCommandListener,
    );

    _batteryChargingStreamSubscription =
        getIsChargingStream(storedDevice.btMACAddress).listen((event) {
          battery.isCharging = event;
        });
    _batteryStreamSubscription =
        getBatteryLevelStream(storedDevice.btMACAddress).listen((event) {
          if (deviceState.value == DeviceMoveState.standby) {
            battery.level = event;
          }
        });
  }

  Future<void> _receivedCommandListener(String value) async {
    commandQueue.commandHistory.add(
      type: MessageHistoryType.receive,
      message: value,
    );
    commandQueue.bluetoothResponseListener(value);
    // Firmware Version
    if (value.startsWith("VER")) {
      firmwareStatus.firmwareVersion = Version.getFromSemVer(
        value.substring(value.indexOf(" ")),
      );
      if (bluetoothUartService.value!.isTailcontrol) {
        commandQueue.addCommand(BluetoothMessage(message: "READNVS"));
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
      battery.isLow = true;
    } else if (value.contains("ERR")) {
      gearReturnedError.value = true;
    } else if (value.contains("SHUTDOWN BEGIN")) {
      deviceConnectionState.value = ConnectivityState.disconnected;
    } else if (value.contains("HWVER") ||
        value.contains("MITAIL") ||
        value.contains("MINITAIL") ||
        value.contains("FLUTTERWINGS")) {
      // Hardware Version
      firmwareStatus.hardwareVersion = value.substring(value.indexOf(" "));
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
      battery.level = int.parse(value).toDouble();
    }
  }

  Future<void> _versionListener() async {
    if (firmwareStatus.hardwareVersion != "" &&
        storedDevice.hardwareVersion != firmwareStatus.hardwareVersion) {
      storedDevice.hardwareVersion = firmwareStatus.hardwareVersion;
      KnownDevices.instance.store();
    }
    if (firmwareStatus.firmwareVersion != Version() &&
        storedDevice.firmwareVersion != firmwareStatus.firmwareVersion) {
      storedDevice.firmwareVersion = firmwareStatus.firmwareVersion;
      KnownDevices.instance.store();
    }
    if (firmwareStatus.hardwareVersion.isNotEmpty &&
        firmwareStatus.firmwareVersion != Version()) {
      await hasOtaUpdate(this).catchError((error, stackTrace) => true);
    }
  }

  void _periodicListener(dynamic ignored) {
    if (deviceConnectionState.value != ConnectivityState.connected) {
      return;
    }

    // Demo gear
    if (isDemoGear(this)) {
      battery.level = Random().nextInt(100).toDouble();
      rssi.value = (Random().nextInt(100) * -1);
    }
    // required to keep the connection open on IOS, otherwise the app will suspend and walk mode will stop working
    // also required to keep eargear awake
    commandQueue.addCommand(
      BluetoothMessage(message: "PING", priority: Priority.low),
    );
    // Battery characteristic works fine for tailcontrol, so we don't need to manually request the battery level
    if (!bluetoothUartService.value!.isTailcontrol) {
      commandQueue.addCommand(
        BluetoothMessage(message: "BATT", priority: Priority.low),
      );
    }

    if (firmwareStatus.firmwareVersion == Version()) {
      commandQueue.addCommand(
        BluetoothMessage(message: "VER", priority: Priority.low),
      );
    }
    if (firmwareStatus.hardwareVersion.isEmpty) {
      commandQueue.addCommand(
        BluetoothMessage(message: "HWVER", priority: Priority.low),
      );
    }
  }

  @override
  String toString() {
    return 'statefulDevice{deviceDefinition: $deviceDefinition, storedDevice:'
        ' $storedDevice, battery: ${battery.level}}';
  }

  void reset() {
    battery.reset();
    gearReturnedError.value = false;
    deviceState.value = DeviceMoveState.standby;
    rssi.value = -1;
    firmwareStatus.reset();
    mtu.value = -1;
    bluetoothUartService.value = null;
    _periodicTimerStream?.cancel();
    _periodicTimerStream = null;
    rxCharacteristicStream = null;
    _rxCharacteristicStreamSubscription?.cancel();
    _rxCharacteristicStreamSubscription = null;
    _batteryChargingStreamSubscription?.cancel();
    _batteryChargingStreamSubscription = null;
    _batteryStreamSubscription?.cancel();
    _batteryStreamSubscription = null;
    _connectBleServiceWatchdog?.cancel();
    _connectBleServiceWatchdog = null;
  }
}
