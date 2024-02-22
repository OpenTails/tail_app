import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import '../../Backend/FirmwareUpdate.dart';

class OtaUpdate extends ConsumerStatefulWidget {
  OtaUpdate({super.key, required this.device});

  String device;

  @override
  _OtaUpdateState createState() => _OtaUpdateState();
}

class _OtaUpdateState extends ConsumerState<OtaUpdate> {
  double downloadProgress = 0;
  double uploadProgress = 0;
  FWInfo? updateURL;
  Dio dio = Dio();
  List<int>? firmwareFile;

  @override
  Widget build(BuildContext context) {
    updateURL ??= ref.read(knownDevicesProvider)[widget.device]?.fwInfo.value;
    downloadFirmware();
    if (downloadProgress == 1) {
      uploadFirmware();
    }
    return Scaffold(
      appBar: AppBar(title: Text("Update in progress")),
      body: Center(
        child: Column(
          children: [
            Text("Updating gear"),
            ListTile(
              title: Text("Downloading"),
              leading: const Icon(Icons.download),
              subtitle: LinearProgressIndicator(value: downloadProgress),
            ),
            ListTile(
              title: Text("Uploading"),
              leading: const Icon(Icons.upload),
              subtitle: LinearProgressIndicator(value: uploadProgress),
            )
          ],
        ),
      ),
    );
  }

  Future<void> downloadFirmware() async {
    final Response<List<int>> rs = await Dio().get<List<int>>(updateURL!.url, options: Options(responseType: ResponseType.bytes), onReceiveProgress: (current, total) {
      setState(() {
        downloadProgress = current / total;
      });
    });
    if (rs.statusCode == 200) {
      downloadProgress = 1;
      Digest digest = md5.convert(rs.data!);
      if (digest.toString() == updateURL!.md5sum) {
        firmwareFile = rs.data;
      }
    }
  }

  Future<void> uploadFirmware() async {
    BaseStatefulDevice? baseStatefulDevice = ref.read(knownDevicesProvider)[widget.device];
    if (firmwareFile != null && baseStatefulDevice != null) {
      int mtu = await ref.read(reactiveBLEProvider).requestMtu(deviceId: baseStatefulDevice.baseStoredDevice.btMACAddress, mtu: 512) - 10;
      int total = firmwareFile!.length;
      int current = 0;
      while (uploadProgress < 1) {
        baseStatefulDevice.deviceState.value = DeviceState.busy; // hold the command queue
        int nextEnd = current + mtu;
        if (nextEnd > total) {
          nextEnd = total;
        }
        List<int> chunk = firmwareFile!.sublist(current, nextEnd);
        if (current == 0) {
          List<int> beginOTA = const Utf8Encoder().convert("OTA ");
          beginOTA.addAll(chunk);
          chunk = beginOTA;
        }
        await ref.read(reactiveBLEProvider).writeCharacteristicWithResponse(baseStatefulDevice.txCharacteristic, value: chunk);
        current = current + chunk.length;
        setState(() {
          uploadProgress = current / total;
        });
      }
      baseStatefulDevice.deviceState.value = DeviceState.standby; // hold the command queue
    }
  }
}
