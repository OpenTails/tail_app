import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Device/stateful/battery_status.dart';
import 'package:tail_app/Backend/Device/stateful/firmware_status.dart';
import 'package:tail_app/Backend/utilities/demo_gear_helpers.dart';

import '../../Bluetooth/bluetooth_message.dart';
import '../../Bluetooth/bluetooth_stream_helpers.dart';
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

class StatefulDevice extends ChangeNotifier {
  final Logger _logger = Logger("StatefulDevice");
  final DeviceDefinition deviceDefinition;
  final StoredDevice storedDevice;
  late final CommandQueue commandQueue;
  final BatteryStatus battery = BatteryStatus();
  final FirmwareStatus firmwareStatus = FirmwareStatus();

  //State
  bool get isConnected =>
      deviceConnectionState.value == ConnectivityState.connected;

  bool get isReady => isConnected && bluetoothUartService != null;
  bool gearReturnedError = false;
  final ValueNotifier<DeviceMoveState> deviceState = ValueNotifier(
    DeviceMoveState.standby,
  );
  final ValueNotifier<int> rssi = ValueNotifier(-1);
  int mtu = -1;
  final ValueNotifier<ConnectivityState> deviceConnectionState = ValueNotifier(
    ConnectivityState.disconnected,
  );
  BluetoothUartService? _bluetoothUartService;

  BluetoothUartService? get bluetoothUartService => _bluetoothUartService;

  set bluetoothUartService(BluetoothUartService? value) {
    if (_bluetoothUartService != value) {
      //prevent UART service from being set if gear is considered disconnected, as this is an invalid state
      _bluetoothUartService = isConnected ? value : null;
      notifyListeners();
    }
    if (bluetoothUartService != null) {
      _registerCharacteristicStreams();
      //unlock the device and command queue;
      deviceState.value = DeviceMoveState.standby;

      // Fires off the FW/HW version and batt commands
      // Wrapped in a future to fix issue with (isReady) being checked before the setter completes
      Future(() => _periodicListener(""));
    } else {
      _unRegisterCharacteristicStreams();
    }
  }

  /// Prevents this gear from automatically reconnecting during the next BLE scan
  bool disableAutoConnect = false;
  bool forgetOnDisconnect = false;

  // Gear Features
  GlowtipStatus _hasGlowtip = GlowtipStatus.unknown;

  GlowtipStatus get hasGlowtip => _hasGlowtip;

  set hasGlowtip(GlowtipStatus value) {
    if (_hasGlowtip != value) {
      _hasGlowtip = value;
      _onGearSupportedFeatureChanged();
    }
  }

  RGBStatus _hasRGB = RGBStatus.unknown;

  RGBStatus get hasRGB => _hasRGB;

  set hasRGB(RGBStatus value) {
    if (_hasRGB != value) {
      _hasRGB = value;
      _onGearSupportedFeatureChanged();
    }
  }

  final ValueNotifier<GearConfigInfo> gearConfigInfo = ValueNotifier(
    GearConfigInfo(),
  );

  Stream<String>? rxCharacteristicStream;
  StreamSubscription? _periodicTimerStream;
  StreamSubscription<String>? _rxCharacteristicStreamSubscription;
  StreamSubscription<bool>? _batteryChargingStreamSubscription;
  Timer? _connectBleServiceWatchdog;

  StatefulDevice(this.deviceDefinition, this.storedDevice) {
    commandQueue = CommandQueue(this);
    deviceConnectionState.addListener(_onConnectionStateChanged);

    // Load glowtip/rgb status
    hasGlowtip = storedDevice.hasGlowtip;
    hasRGB = storedDevice.hasRGB;
    // only store, do not read back on gear load
    firmwareStatus.addListener(_versionListener);
  }

  void _onGearSupportedFeatureChanged() {
    if (hasRGB != RGBStatus.unknown && storedDevice.hasRGB != hasRGB) {
      storedDevice.hasRGB = hasRGB;
      KnownDevices.instance.store();
    }
    if (hasGlowtip != GlowtipStatus.unknown &&
        storedDevice.hasGlowtip != hasGlowtip) {
      storedDevice.hasGlowtip = hasGlowtip;
      KnownDevices.instance.store();
    }
    notifyListeners();
  }

  void _onConnectionStateChanged() {
    if (!isReady) {
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
      _connectBleServiceWatchdog = Timer(
        Duration(seconds: 10),
        _onConnectBleServiceWatchdogTimeout,
      );
    }
    if (isConnected) {
      _periodicTimerStream = Stream.periodic(
        const Duration(seconds: 10),
      ).listen(_periodicListener);
      analyticsEvent(
        name: "Connect Gear",
        props: {"Gear Type": deviceDefinition.btName},
      );
    }
    notifyListeners();
  }

  void _onConnectBleServiceWatchdogTimeout() {
    if (isReady || !isConnected) {
      _connectBleServiceWatchdog = null;
      return;
    }
    _logger.severe(
      "Failed to connect or locate BLE UART service in time for device ${deviceDefinition.btName}.",
    );
    disconnect(storedDevice.btMACAddress);
  }

  void _unRegisterCharacteristicStreams() {
    rxCharacteristicStream = null;
    _rxCharacteristicStreamSubscription?.cancel();
    _rxCharacteristicStreamSubscription = null;
    _batteryChargingStreamSubscription?.cancel();
    _batteryChargingStreamSubscription = null;
  }

  void _registerCharacteristicStreams() {
    if (!isReady) {
      return;
    }
    if (rxCharacteristicStream != null) {
      _unRegisterCharacteristicStreams();
    }
    rxCharacteristicStream = getRxStream(
      storedDevice.btMACAddress,
      bluetoothUartService!.bleRxCharacteristic,
    );
    _rxCharacteristicStreamSubscription = rxCharacteristicStream!.listen(
      _receivedCommandListener,
    );

    _batteryChargingStreamSubscription =
        (getIsChargingStream(storedDevice.btMACAddress)).listen((event) {
          battery.isCharging = event;
        });
  }

  void _receivedCommandListener(String value) {
    commandQueue.commandHistory.add(
      type: MessageHistoryType.receive,
      message: value,
      bluetoothMessage: commandQueue.currentMessage?.responseMSG != null
          ? commandQueue.currentMessage!
          : null,
    );
    commandQueue.bluetoothResponseListener(value);
    // Firmware Version
    if (value.startsWith("VER")) {
      firmwareStatus.firmwareVersion = Version.getFromSemVer(
        value.substring(value.indexOf(" ")),
      );
      if (bluetoothUartService != null && bluetoothUartService!.isTailcontrol) {
        commandQueue.addCommand(BluetoothMessage(message: "READNVS"));
      }
      // Sent after VER message
    } else if (value.startsWith("GLOWTIP")) {
      String substring = value.substring(value.indexOf(" ")).trim();
      hasGlowtip = substring == 'TRUE'
          ? GlowtipStatus.glowtip
          : GlowtipStatus.noGlowtip;
    } else if (value.startsWith("RGB")) {
      String substring = value.substring(value.indexOf(" ")).trim();
      hasRGB = substring == 'TRUE' ? RGBStatus.rgb : RGBStatus.noRGB;
    } else if (value.contains("MYCOLOR")) {
      String substring = value.substring(value.indexOf(" ")).trim();
      // ignore pure black as unset
      if (substring == "000000") {
        return;
      }
      Color gearColor = Color(int.parse(substring, radix: 16)).withAlpha(255);
      storedDevice.color = gearColor.toARGB32();
      KnownDevices.instance.store();
    } else if (value.contains("BUSY") || value.contains("ERR")) {
      gearReturnedError = true;
    } else if (value.contains("LOWBATT")) {
      battery.isLow = true;
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
      await KnownDevices.instance.store();
    }
    if (firmwareStatus.firmwareVersion != Version() &&
        storedDevice.firmwareVersion != firmwareStatus.firmwareVersion) {
      storedDevice.firmwareVersion = firmwareStatus.firmwareVersion;
      await KnownDevices.instance.store();
    }
    if (firmwareStatus.hardwareVersion.isNotEmpty &&
        firmwareStatus.firmwareVersion != Version()) {
      await hasOtaUpdate(this).catchError((error, stackTrace) => true);
    }
  }

  void _periodicListener(dynamic ignored) {
    if (!isReady) {
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

    commandQueue.addCommand(
      BluetoothMessage(message: "BATT", priority: Priority.low),
    );

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

  /// Inject an incoming message into the [StatefulDevice] state machines.
  void mockReceivedMessage(String message) {
    if (!isReady) {
      return;
    }
    onBluetoothCharacteristicValueUpdate(
      storedDevice.btMACAddress,
      bluetoothUartService!.bleRxCharacteristic,
      const Utf8Encoder().convert(message),
      0,
    );
  }

  @override
  String toString() {
    return 'statefulDevice{deviceDefinition: $deviceDefinition, storedDevice:'
        ' $storedDevice, battery: ${battery.level}}';
  }

  /// Returns [StatefulDevice] to a default state after gear disconnects
  void reset() {
    battery.reset();
    gearReturnedError = false;
    deviceState.value = DeviceMoveState.standby;
    rssi.value = -1;
    firmwareStatus.reset();
    mtu = -1;
    bluetoothUartService = null;
    _periodicTimerStream?.cancel();
    _periodicTimerStream = null;
    _connectBleServiceWatchdog?.cancel();
    _connectBleServiceWatchdog = null;
  }
}
