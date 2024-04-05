import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as log;
import 'package:permission_handler/permission_handler.dart';
import 'package:pod_player/pod_player.dart';
import 'package:tail_app/constants.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../intn_defs.dart';

final log.Logger homeLogger = log.Logger('Home');

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  late final PodPlayerController controller;

  @override
  void initState() {
    controller = PodPlayerController(
      playVideoFrom: PlayVideoFrom.vimeo(
        '913642606',
      ),
      podPlayerConfig: const PodPlayerConfig(
        autoPlay: false,
        isLooping: false,
        videoQualityPriority: [720, 360],
        wakelockEnabled: false,
        forcedVideoFocus: false,
      ),
    )..initialise();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<BleStatus> btStatus = ref.watch(btStatusProvider);
    return ListView(
      shrinkWrap: true,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.waving_hand),
                    title: Text(subTitle()),
                    subtitle: const Text('This is a fan made app to control The Tail Company tails, ears, and wings'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () async {
                          await launchUrl(Uri.parse('https://thetailcompany.com?utm_source=Tail_App'));
                        },
                        child: const Text('Tail Company Store'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
            firstChild: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const ListTile(
                        leading: Icon(Icons.bluetooth_disabled),
                        title: Text('Bluetooth is Unavailable'),
                        subtitle: Text('Bluetooth is required to connect to Gear'),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () async {
                              AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                            },
                            child: const Text('Open Settings'),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            secondChild: Container(),
            crossFadeState: btStatus.valueOrNull == BleStatus.poweredOff || btStatus.valueOrNull == BleStatus.unsupported ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: animationTransitionDuration),
        AnimatedCrossFade(
            firstChild: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const ListTile(
                        leading: Icon(Icons.bluetooth_disabled),
                        title: Text('Permission required'),
                        subtitle: Text('Permission is required to connect to nearby Gear.'),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () async {
                              homeLogger.info("Permission BluetoothScan: ${await Permission.bluetoothScan.request()}");
                              homeLogger.info("Permission BluetoothConnect: ${await Permission.bluetoothConnect.request()}");
                            },
                            child: const Text('Grant Permissions'),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            secondChild: Container(),
            crossFadeState: btStatus.valueOrNull == BleStatus.unauthorized ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: animationTransitionDuration),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (controller.isVideoPlaying) {
                  controller.pause();
                } else {
                  controller.videoSeekTo(Duration.zero);
                  controller.play();
                }
              },
              child: PodVideoPlayer(
                controller: controller,
                matchFrameAspectRatioToVideo: true,
                alwaysShowProgressBar: true,
                overlayBuilder: (options) => Container(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
