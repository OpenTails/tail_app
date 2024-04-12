import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:cross_platform/cross_platform.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_service/flutter_foreground_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logging/logging.dart' as log;
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/sensors.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../Frontend/utils.dart';
import '../../constants.dart';
import '../Definitions/Device/device_definition.dart';
import '../auto_move.dart';
import '../device_registry.dart';
import '../firmware_update.dart';
import 'bluetooth_message.dart';

part 'bluetooth_manager.g.dart';

final log.Logger bluetoothLog = log.Logger('Bluetooth');

@riverpod
Stream<DiscoveredDevice> scanForDevices(ScanForDevicesRef ref) {
  ref.onDispose(() {
    bluetoothLog.fine("Stopping scan");
  });
  bluetoothLog.fine("Starting scan");
  final FlutterReactiveBle bluetoothManagerRef = ref.watch(reactiveBLEProvider);
  Stream<DiscoveredDevice> scanStream = bluetoothManagerRef.scanForDevices(withServices: DeviceRegistry.getAllIds(), requireLocationServicesEnabled: false, scanMode: ScanMode.lowPower).asBroadcastStream();
  // Checks if pair devices are nearby and tries to connect
  scanStream.listen(
    (DiscoveredDevice event) {
      if (ref.read(knownDevicesProvider).containsKey(event.id) && ref.read(knownDevicesProvider)[event.id]?.deviceConnectionState.value == DeviceConnectionState.disconnected && !ref.read(knownDevicesProvider)[event.id]!.disableAutoConnect) {
        ref.read(knownDevicesProvider.notifier).connect(event);
      }
    },
  ).onError(
    (e, s) {
      bluetoothLog.warning('Error while scanning for gear:$e', e, s);
    },
  );
  // returns all gear that are not paired
  return scanStream.skipWhile((DiscoveredDevice element) => ref.read(knownDevicesProvider).containsKey(element.id));
}

@Riverpod(keepAlive: true)
class KnownDevices extends _$KnownDevices {
  @override
  Map<String, BaseStatefulDevice> build() {
    List<BaseStoredDevice> storedDevices = SentryHive.box<BaseStoredDevice>('devices').values.toList();
    Map<String, BaseStatefulDevice> results = {};
    try {
      if (storedDevices.isNotEmpty) {
        for (BaseStoredDevice e in storedDevices) {
          BaseDeviceDefinition baseDeviceDefinition = DeviceRegistry.getByUUID(e.deviceDefinitionUUID);
          BaseStatefulDevice baseStatefulDevice = BaseStatefulDevice(baseDeviceDefinition, e, ref);
          results[e.btMACAddress] = baseStatefulDevice;
        }
      }
    } catch (e, s) {
      bluetoothLog.shout("Unable to load stored devices due to $e", e, s);
    }

    return results;
  }

  void add(BaseStatefulDevice baseStatefulDevice) {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2[baseStatefulDevice.baseStoredDevice.btMACAddress] = baseStatefulDevice;
    state = state2;
    store();
  }

  void remove(String id) {
    Map<String, BaseStatefulDevice> state2 = Map.from(state);
    state2.remove(id);
    state = state2;
    store();
  }

  Future<void> store() async {
    SentryHive.box<BaseStoredDevice>('devices')
      ..clear()
      ..addAll(state.values.map((e) => e.baseStoredDevice));
  }

  Future<void> connect(DiscoveredDevice device) async {
    final ISentrySpan transaction = Sentry.startTransaction('connectToDevice()', 'task');
    BaseDeviceDefinition? deviceDefinition = DeviceRegistry.getByName(device.name);
    if (deviceDefinition == null) {
      bluetoothLog.warning("Unknown device found: ${device.name}");
      transaction.status = const SpanStatus.notFound();
      transaction.finish();
      return;
    }
    BaseStoredDevice baseStoredDevice;
    BaseStatefulDevice statefulDevice;
    transaction.setTag('Device Name', device.name);
    try {
      //get existing entry
      if (state.containsKey(device.id)) {
        statefulDevice = state[device.id]!;
        statefulDevice.deviceConnectionState.value = DeviceConnectionState.connecting;
        baseStoredDevice = statefulDevice.baseStoredDevice;
        transaction.setTag('Known Device', 'Yes');
      } else {
        baseStoredDevice = BaseStoredDevice(deviceDefinition.uuid, device.id, deviceDefinition.deviceType.color.value);
        baseStoredDevice.name = getNameFromBTName(deviceDefinition.btName);
        statefulDevice = BaseStatefulDevice(deviceDefinition, baseStoredDevice, ref);
        transaction.setTag('Known Device', 'No');
        Future(() => add(statefulDevice));
      }
      FlutterReactiveBle reactiveBLE = ref.read(reactiveBLEProvider);
      statefulDevice.connectionStateStreamSubscription = reactiveBLE.connectToDevice(id: device.id).listen(
        (event) async {
          statefulDevice.deviceConnectionState.value = event.connectionState;
          bluetoothLog.info("Connection State updated for ${baseStoredDevice.name}: ${event.connectionState}");
          if (event.connectionState == DeviceConnectionState.connected) {
            // The timer used for the time value on the battery level graph
            statefulDevice.stopWatch.start();
            // set initial signal strength
            bluetoothLog.finer('Requesting initial signal strength for ${baseStoredDevice.name}');
            statefulDevice.rssi.value = await reactiveBLE.readRssi(device.id);
            bluetoothLog.info("Discovering services for ${baseStoredDevice.name}");
            await reactiveBLE.discoverAllServices(device.id);
            statefulDevice.rxCharacteristicStream = reactiveBLE.subscribeToCharacteristic(statefulDevice.rxCharacteristic);

            // Listen for responses outside of commands
            statefulDevice.rxCharacteristicStream?.listen((event) {
              String value = const Utf8Decoder().convert(event);
              bluetoothLog.info("Received message from ${baseStoredDevice.name}: $value");
              statefulDevice.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.receive, message: value));
              // Firmware Version
              if (value.startsWith("VER")) {
                statefulDevice.fwVersion.value = value.substring(value.indexOf(" "));
                if (statefulDevice.fwInfo.value != null) {
                  if (statefulDevice.fwInfo.value?.version.split(" ")[1] != statefulDevice.fwVersion.value) {
                    statefulDevice.hasUpdate.value = true;
                  }
                }
                // Sent after VER message
              } else if (value.startsWith("GLOWTIP")) {
                statefulDevice.glowTip.value = "TRUE" == value.substring(value.indexOf(" "));
              } else if (value.contains("BUSY")) {
                //statefulDevice.deviceState.value = DeviceState.busy;
              } else if (value.contains("LOWBATT")) {
                statefulDevice.batteryLow.value = true;
              } else if (value.contains("ERR")) {
                statefulDevice.error.value = true;
              } else if (value.contains("HWVER")) {
                // Hardware Version
                statefulDevice.hwVersion.value = value.substring(value.indexOf(" "));
              }
            });
            // Listen to battery level stream
            statefulDevice.batteryCharacteristicStreamSubscription = reactiveBLE.subscribeToCharacteristic(statefulDevice.batteryCharacteristic).listen((List<int> event) {
              bluetoothLog.fine("Received Battery message from ${baseStoredDevice.name}: $event");
              statefulDevice.battery.value = event.first.toDouble();
              statefulDevice.batlevels.add(FlSpot(statefulDevice.stopWatch.elapsed.inSeconds.toDouble(), event.first.toDouble()));
            });
            // Listen to battery charge state stream
            statefulDevice.batteryChargeCharacteristicStreamSubscription = reactiveBLE.subscribeToCharacteristic(statefulDevice.batteryChargeCharacteristic).listen((List<int> event) {
              String value = const Utf8Decoder().convert(event);
              bluetoothLog.fine("Received Battery Charge message from ${baseStoredDevice.name}: $value");
              statefulDevice.batteryCharging.value = value == "CHARGE ON";
            });
            // Send a ping every 15 seconds
            // Also gets the RSSI signal strength
            statefulDevice.keepAliveStreamSubscription = Stream.periodic(const Duration(seconds: 15)).listen((event) async {
              if (state.containsKey(device.id)) {
                statefulDevice.commandQueue.addCommand(BluetoothMessage(message: "PING", device: statefulDevice, priority: Priority.low, type: Type.system));
                statefulDevice.rssi.value = await reactiveBLE.readRssi(device.id);
              } else {
                throw Exception("Disconnected from device");
              }
            }, cancelOnError: true);
            // Try to get firmware update information from Tail Company site
            if (deviceDefinition.fwURL != "") {
              initDio().get(statefulDevice.baseDeviceDefinition.fwURL, options: Options(responseType: ResponseType.json)).then(
                (value) {
                  if (value.statusCode == 200) {
                    statefulDevice.fwInfo.value = FWInfo.fromJson(const JsonDecoder().convert(value.data.toString()));
                    if (statefulDevice.fwVersion.value != "") {
                      if (statefulDevice.fwInfo.value?.version.split(" ")[1] != statefulDevice.fwVersion.value) {
                        statefulDevice.hasUpdate.value = true;
                      }
                    }
                  }
                },
              ).onError((error, stackTrace) {
                bluetoothLog.warning("Unable to get Firmware info for ${statefulDevice.baseDeviceDefinition.fwURL} :$error", error, stackTrace);
              });
            }
            // Add initial commands to the queue
            statefulDevice.commandQueue.addCommand(BluetoothMessage(message: "VER", device: statefulDevice, priority: Priority.low, type: Type.system));
            statefulDevice.commandQueue.addCommand(BluetoothMessage(message: "HWVER", device: statefulDevice, priority: Priority.low, type: Type.system));
            if (statefulDevice.baseStoredDevice.autoMove) {
              changeAutoMove(statefulDevice);
            }
          }
        },
      );
      transaction.status = const SpanStatus.ok();
    } catch (e, s) {
      bluetoothLog.shout('Exception when connecting to device', e, s);
      Sentry.captureException(e, stackTrace: s);
      transaction.status = const SpanStatus.internalError();
    } finally {
      await transaction.finish();
    }
    return;
  }
}

@Riverpod(
  keepAlive: true,
)
Stream<BleStatus> btStatus(BtStatusRef ref) {
  return ref.read(reactiveBLEProvider).statusStream;
}

ValueNotifier<bool> isAnyGearConnected = ValueNotifier(false);

@Riverpod(keepAlive: true)
StreamSubscription<ConnectionStateUpdate> btConnectStateHandler(BtConnectStateHandlerRef ref) {
  return ref.read(reactiveBLEProvider).connectedDeviceStream.listen((ConnectionStateUpdate event) async {
    bluetoothLog.info("ConnectedDevice::$event");
    Map<String, BaseStatefulDevice> knownDevices = ref.read(knownDevicesProvider);
    if (knownDevices.containsKey(event.deviceId) && [DeviceConnectionState.disconnected, DeviceConnectionState.connected].contains(event.connectionState)) {
      BaseStatefulDevice baseStatefulDevice = knownDevices[event.deviceId]!;
      baseStatefulDevice.deviceConnectionState.value = event.connectionState;
      Fluttertoast.showToast(
        msg: "${baseStatefulDevice.baseStoredDevice.name} has ${event.connectionState.name}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
      );
      if (event.connectionState == DeviceConnectionState.connected) {
        isAnyGearConnected.value = true;
        if (SentryHive.box(settings).get(keepAwake, defaultValue: keepAwakeDefault)) {
          bluetoothLog.fine('Enabling wakelock');
          WakelockPlus.enable();
        }
        if (Platform.isAndroid) {
          //start foreground service on device connected. Library handles duplicate start calls
          bluetoothLog.fine('Requesting notification permission');
          bluetoothLog.finer('Requesting notification permission result${await Permission.notification.request()}'); // Used only for Foreground service
          ForegroundServiceHandler.notification.setPriority(AndroidNotificationPriority.LOW);
          ForegroundServiceHandler.notification.setTitle("Gear Connected");
          bluetoothLog.fine('Starting foreground service');
          ForegroundService().start();
        }
      } else {
        bluetoothLog.info("Disconnected from device: ${event.deviceId}");
        // We don't want to display the app review screen right away. We keep track of gear disconnects and after 5 we try to display the review dialog.
        int count = SentryHive.box(settings).get(gearDisconnectCount, defaultValue: gearDisconnectCountDefault) + 1;
        if (count > 5 && SentryHive.box(settings).get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault)) {
          SentryHive.box(settings).put(shouldDisplayReview, true);
          bluetoothLog.finer('Setting shouldDisplayReview to true');
        } else {
          SentryHive.box(settings).put(gearDisconnectCount, count);
          bluetoothLog.finer('Setting gearDisconnectCount to $count');
        }
        // Resets most of the runtime values without recreating the whole object
        bluetoothLog.finer('Resetting gear stateful properties');
        baseStatefulDevice.reset();
        //ref.read(snackbarStreamProvider.notifier).add(SnackBar(content: Text("Disconnected from ${baseStatefulDevice.baseStoredDevice.name}")));

        // remove foreground service if no devices connected
        int deviceCount = knownDevices.values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected).length;
        bool lastDevice = deviceCount == 0;
        if (lastDevice) {
          bluetoothLog.fine('Last gear detected');
          // Disable all triggers on last device
          ref.read(triggerListProvider).where((element) => element.enabled).forEach(
            (element) {
              element.enabled = false;
            },
          );
          isAnyGearConnected.value = false;
          bluetoothLog.finer('Disabling wakelock');
          // stop wakelock if its started
          WakelockPlus.disable();
          // Close foreground service
          if (Platform.isAndroid) {
            bluetoothLog.finer('Stopping foreground service');
            ForegroundService().stop();
          }
        }
        // if the forget button was used, remove the device
        if (knownDevices[event.deviceId]!.forgetOnDisconnect) {
          bluetoothLog.finer('forgetting about gear');
          ref.read(knownDevicesProvider.notifier).remove(event.deviceId);
        }
      }
    }
  });
}

@Riverpod(keepAlive: true)
FlutterReactiveBle reactiveBLE(ReactiveBLERef ref) {
  bluetoothLog.info("Initializing BluetoothManager");
  FlutterReactiveBle flutterReactiveBle = FlutterReactiveBle();
  flutterReactiveBle.logLevel = LogLevel.none;
  flutterReactiveBle.initialize();
  return FlutterReactiveBle();
}

class CommandQueue {
  Ref? ref;
  PriorityQueue<BluetoothMessage> state = PriorityQueue();
  BaseStatefulDevice device;

  CommandQueue(this.ref, this.device);

  Stream<BluetoothMessage> messageQueueStream() async* {
    while (true) {
      // Limit the speed commands are processed
      await Future.delayed(const Duration(milliseconds: 100));
      // wait for
      if (state.isNotEmpty && device.deviceState.value == DeviceState.standby) {
        device.deviceState.value = DeviceState.runAction;
        yield state.removeFirst();
      }
    }
  }

  StreamSubscription<BluetoothMessage>? messageQueueStreamSubscription;

  void addCommand(BluetoothMessage bluetoothMessage) {
    messageQueueStreamSubscription ??= messageQueueStream().listen((message) async {
      //Check if the device is still known and connected;
      if (device.deviceConnectionState.value != DeviceConnectionState.connected) {
        device.deviceState.value = DeviceState.standby;
        return;
      }
      //TODO: Resend on busy
      if (bluetoothMessage.delay == null) {
        try {
          bluetoothLog.fine("Sending command to ${device.baseStoredDevice.name}:${message.message}");
          await ref?.read(reactiveBLEProvider).writeCharacteristicWithResponse(message.device.txCharacteristic, value: const Utf8Encoder().convert(message.message));
          device.messageHistory.add(MessageHistoryEntry(type: MessageHistoryType.send, message: message.message));
          if (message.onCommandSent != null) {
            // Callback when the specific command is run
            message.onCommandSent!();
          }
          try {
            if (message.responseMSG != null) {
              Duration timeoutDuration = const Duration(seconds: 10);
              bluetoothLog.fine("Waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
              Timer timer = Timer(timeoutDuration, () {});

              // We use a timeout as sometimes a response isn't sent by the gear
              Future<List<int>> response = message.device.rxCharacteristicStream!.timeout(timeoutDuration, onTimeout: (sink) => sink.close()).where((event) {
                bluetoothLog.info('Response:${const Utf8Decoder().convert(event)}');
                return const Utf8Decoder().convert(event) == message.responseMSG!;
              }).first;
              // Handles response value
              response.then((value) {
                timer.cancel();
                if (message.onResponseReceived != null) {
                  //callback when the command response is received
                  message.onResponseReceived!(const Utf8Decoder().convert(value));
                }
              });
              response.timeout(
                timeoutDuration,
                onTimeout: () {
                  bluetoothLog.warning("Timed out waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
                  return [];
                },
              );
              while (timer.isActive) {
                //allow higher priority commands to interrupt waiting for a response
                if (state.isNotEmpty && state.first.priority.index > bluetoothMessage.priority.index) {
                  timer.cancel();
                }
                await Future.delayed(const Duration(milliseconds: 50)); // Prevent the loop from consuming too many resources
              }
              bluetoothLog.fine("Finished waiting for response from ${device.baseStoredDevice.name}:${message.responseMSG}");
            }
          } catch (e, s) {
            bluetoothLog.warning('Command timed out or threw error: $e', e, s);
          }
        } catch (e, s) {
          Sentry.captureException(e, stackTrace: s);
        }
      } else {
        bluetoothLog.fine("Pausing queue for ${device.baseStoredDevice.name}");
        Timer timer = Timer(Duration(milliseconds: bluetoothMessage.delay!.toInt() * 20), () {});
        while (timer.isActive) {
          //allow higher priority commands to interrupt the delay
          if (state.isNotEmpty && state.first.priority.index > bluetoothMessage.priority.index) {
            timer.cancel();
          }
          await Future.delayed(const Duration(milliseconds: 50)); // Prevent the loop from consuming too many resources
        }
        bluetoothLog.fine("Resuming queue for ${device.baseStoredDevice.name}");
      }
      device.deviceState.value = DeviceState.standby; //Without setting state to standby, another command can not run
    });
    // preempt queue
    if (bluetoothMessage.type == Type.direct) {
      state.toUnorderedList().where((element) => [Type.move, Type.direct].contains(element.type)).forEach((element) => state.remove(element));
    }
    state.add(bluetoothMessage);
  }
}
