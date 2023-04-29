import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:wakelock/wakelock.dart';

import 'Frontend/Home.dart';

Future<void> main() async {
  Flogger.init(config: const FloggerConfig(showDebugLogs: true, printClassName: true, printMethodName: true, showDateTime: false));

  Flogger.registerListener(
    (record) {
      LogConsole.add(OutputEvent(record.level, [record.message]), bufferSize: 100000);
      log(record.message, stackTrace: record.stackTrace);
    },
  );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Flogger.e(details.exceptionAsString(), stackTrace: details.stack);
    if (kReleaseMode) exit(1);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Flogger.e(error.toString(), stackTrace: stack);
    return true;
  };
  PlatformDispatcher.instance.onPlatformMessage = (String name, ByteData? data, PlatformMessageResponseCallback? callback) {
    String message = data != null ? String.fromCharCodes(data.buffer.asUint8List()) : '';
    //Flogger.d("PlatformMessage::$name::$message");
  };
  runApp(const ProviderScope(
    child: TailApp(),
  ));
}

final Provider<BluetoothManager> bluetoothProvider = Provider<BluetoothManager>((_) => BluetoothManager());

class TailApp extends ConsumerWidget {
  const TailApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Flogger.i('Starting app');
    ref.read(bluetoothProvider).scan();
    setupAsyncPermissions();
    return MaterialApp(
      title: 'All of the Tails',
      darkTheme: ThemeData(useMaterial3: true, primarySwatch: Colors.orange),
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.orange),
      home: const Home(title: 'All of the Tails'),
    );
  }

  //Todo: make a screen to display required permissions
  Future<void> setupAsyncPermissions() async {
    await Wakelock.enable();
    if (Platform.isAndroid) {
      if (false == await DisableBatteryOptimization.isAllBatteryOptimizationDisabled) {
        await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
      }
    }
    Flogger.i("Permission BluetoothScan: ${await Permission.bluetoothScan.request()}");
    Flogger.i("Permission BluetoothConnect: ${await Permission.bluetoothConnect.request()}");
  }
}
