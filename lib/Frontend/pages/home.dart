import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as log;
import 'package:url_launcher/url_launcher.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../Widgets/base_card.dart';
import '../Widgets/tail_blog.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import 'markdown_viewer.dart';

final log.Logger homeLogger = log.Logger('Home');

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  //late final PodPlayerController controller;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    /*controller = PodPlayerController(
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
    )..initialise();*/
    super.initState();
  }

  @override
  void dispose() {
    //controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isBluetoothEnabled,
      child: TailBlog(controller: _controller),
      builder: (BuildContext context, bool bluetoothEnabled, Widget? child) {
        return SingleChildScrollView(
          controller: _controller,
          child: Column(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ref.read(knownDevicesProvider).isNotEmpty && !HiveProxy.getOrDefault(settings, alwaysScanning, defaultValue: alwaysScanningDefault) && !HiveProxy.getOrDefault(settings, hideTutorialCards, defaultValue: hideTutorialCardsDefault)) ...[
                          ListTile(
                            leading: const Icon(Icons.info),
                            subtitle: Text(homeContinuousScanningOffDescription()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              BaseCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      title: Text(homeWelcomeMessageTitle()),
                      subtitle: Text(homeWelcomeMessage()),
                    ),
                    ButtonBar(
                      children: <Widget>[
                        TextButton(
                          onPressed: () async {
                            MarkdownViewerRoute(
                              $extra: MarkdownInfo(content: await rootBundle.loadString('CHANGELOG.md'), title: homeChangelogLinkTitle()),
                            ).push(context);
                          },
                          child: Text(homeChangelogLinkTitle()),
                        ),
                        TextButton(
                          onPressed: () async {
                            await launchUrl(Uri.parse('https://thetailcompany.com?utm_source=Tail_App'));
                          },
                          child: const Text('Tail Company Store'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: BaseCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.bluetooth_disabled),
                        title: Text(actionsNoBluetooth()),
                        subtitle: Text(actionsNoBluetoothDescription()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () async {
                              AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                            },
                            child: Text(onboardingBluetoothEnableButtonLabel()),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
                secondChild: Container(),
                crossFadeState: !bluetoothEnabled ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: animationTransitionDuration,
              ),
              ListTile(
                title: Text(
                  homeNewsTitle(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              child!,
            ],
          ),
        );
      },
    );
  }
}
