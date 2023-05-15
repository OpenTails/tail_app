import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:wakelock/wakelock.dart';

import 'Frontend/Home.dart';

BluetoothManager bluetoothManager = BluetoothManager();

Future<void> main() async {
  Flogger.init(config: const FloggerConfig(showDebugLogs: true, printClassName: true, printMethodName: true, showDateTime: false));

  Flogger.registerListener(
    (record) {
      //LogConsole.add(OutputEvent(record.level, [record.message]), bufferSize: 100000);
      log(record.message, stackTrace: record.stackTrace);
    },
  );
  runApp(const ProviderScope(
    child: TailApp(),
  ));
}

class TailApp extends ConsumerWidget {
  const TailApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Flogger.i('Starting app');
    setupAsyncPermissions();
    bluetoothManager.scan();
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
    Flogger.i("Permission Location: ${await Permission.locationWhenInUse.request()}");
  }
}
