import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

import '../../constants.dart';
import '../../main.dart';
import '../intn_defs.dart';
import 'lottie_lazy_load.dart';

class ScanForNewDevice extends ConsumerStatefulWidget {
  const ScanForNewDevice({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ScanForNewDevice();
}

class _ScanForNewDevice extends ConsumerState<ScanForNewDevice> {
  @override
  void initState() {
    beginScan();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    if (!SentryHive.box(settings).get(alwaysScanning, defaultValue: alwaysScanningDefault)) {
      stopScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isBluetoothEnabled,
      builder: (BuildContext context, bool value, Widget? child) {
        if (value) {
          return ListView(
            controller: widget.scrollController,
            children: [
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                builder: (BuildContext context, AsyncSnapshot<List<ScanResult>> snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int index) {
                        ScanResult e = snapshot.data![index];
                        return FadeIn(
                          delay: const Duration(milliseconds: 100),
                          child: ListTile(
                            title: Text(getNameFromBTName(e.device.advName)),
                            trailing: Text(e.device.remoteId.str),
                            onTap: () async {
                              await e.device.connect();
                              plausible.event(name: "Connect New Gear", props: {"Gear Type": e.device.advName});
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        );
                      },
                    );
                  } else {
                    return Container();
                  }
                },
              ),
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Spin(
                          infinite: true,
                          duration: const Duration(seconds: 1, milliseconds: 500),
                          child: Transform.flip(
                            flipX: true,
                            child: const LottieLazyLoad(
                              asset: 'assets/tailcostickers/tgs/TailCoStickers_file_144834340.tgs',
                              renderCache: false,
                              width: 200,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(scanDevicesScanMessage()),
                        )
                      ],
                    ),
                  )),
            ],
          );
        } else {
          return Center(
            child: Text(actionsNoBluetooth()), //TODO: More detail
          );
        }
      },
    );
  }
}
