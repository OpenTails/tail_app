import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart' as log;
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Frontend/Widgets/coshub_feed.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/gen/assets.gen.dart';

import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
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
                        $extra: MarkdownInfo(content: await rootBundle.loadString('CHANGELOG.md'), title: homeChangelogLinkTitle(), analyticsLabel: 'Changelog'),
                      ).push(context);
                    },
                    child: Text(convertToUwU(homeChangelogLinkTitle())),
                  ),
                  TextButton(
                    onPressed: () async {
                      await launchExternalUrl(url: "https://thetailcompany.com", analyticsLabel: "Store");
                    },
                    child: Text(convertToUwU('Tail Company Store')),
                  ),
                ],
              ),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: isBluetoothEnabled,
          builder: (context, bluetoothEnabled, child) => AnimatedCrossFade(
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
        ),
        ListTile(
          title: Text(
            convertToUwU(homeCosHubTitle()),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          trailing: Image.asset(
            Assets.cosHubBT.path,
            width: 24,
            height: 24,
          ),
        ),
        SizedBox(
          height: 350,
          child: CoshubFeed(),
        ),
        ListTile(
          title: Text(
            convertToUwU(homeNewsTitle()),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 350,
          child: TailBlog(),
        ),
      ],
    );
  }
}
