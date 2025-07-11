import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as log;
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
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
  final ScrollController _controller = ScrollController();

  @override
  void initState() {

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isBluetoothEnabled,
      child: TailBlog(controller: _controller),
      builder: (BuildContext context, bool bluetoothEnabled, Widget? child) {
        return ListView(
          controller: _controller,
          children: [
            BaseCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    title: Text(convertToUwU(homeWelcomeMessageTitle())),
                    subtitle: Text(convertToUwU(homeWelcomeMessage())),
                  ),
                  OverflowBar(
                    children: <Widget>[
                      TextButton(
                        onPressed: () async {
                          MarkdownViewerRoute(
                            $extra: MarkdownInfo(content: await rootBundle.loadString('CHANGELOG.md'), title: homeChangelogLinkTitle()),
                          ).push(context);
                        },
                        child: Text(convertToUwU(homeChangelogLinkTitle())),
                      ),
                      TextButton(
                        onPressed: () async {
                          await launchUrl(Uri.parse('https://thetailcompany.com?utm_source=Tail_App'));
                        },
                        child: Text(convertToUwU('Tail Company Store')),
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
                      title: Text(convertToUwU(actionsNoBluetooth())),
                      subtitle: Text(convertToUwU(actionsNoBluetoothDescription())),
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
                convertToUwU(homeNewsTitle()),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            child!,
          ],
        );
      },
    );
  }
}
