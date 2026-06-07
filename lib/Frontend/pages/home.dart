import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart' as log;
import 'package:tail_app/Backend/age_check.dart';
import 'package:tail_app/Frontend/Widgets/coshub_feed.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/logging_wrappers.dart';
import '../../assets.dart';
import '../../constants.dart';
import '../Widgets/base_card.dart';
import '../Widgets/tail_blog.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import 'html_page.dart';
import 'markdown_viewer.dart';

final log.Logger homeLogger = log.Logger('Home');

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ScrollController _controller = ScrollController();

  void _dismissWelcomeCard() {
    HiveProxy.put(settings, hideTutorialCards, true);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showWelcome = !HiveProxy.getOrDefault(
      settings,
      hideTutorialCards,
      defaultValue: hideTutorialCardsDefault,
    );

    return ListView(
      controller: _controller,
      children: [
        if (showWelcome)
          BaseCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          convertToUwU(homeWelcomeMessage()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Dismiss',
                        onPressed: _dismissWelcomeCard,
                      ),
                    ],
                  ),
                ),
                OverflowBar(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => HtmlPageRoute(
                        $extra: HtmlPageInfo(
                          url: "https://docs.thetailcompany.com/doku.php?id=en:app&do=export_xhtmlbody",
                          title: "Instructions",
                          analyticsLabel: "Instructions",
                        ),
                      ).push(context),
                      child: Text(convertToUwU('Instructions')),
                    ),
                    TextButton(
                      onPressed: () async {
                        final content = await rootBundle.loadString('CHANGELOG.md');
                        if (context.mounted) {
                          MarkdownViewerRoute(
                            $extra: MarkdownInfo(
                              content: content,
                              title: homeChangelogLinkTitle(),
                              analyticsLabel: 'Changelog',
                            ),
                          ).push(context);
                        }
                      },
                      child: Text(convertToUwU(homeChangelogLinkTitle())),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ListTile(
          title: Text(
            convertToUwU(homeNewsTitle()),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
          ),
          trailing: Icon(Icons.newspaper),
        ),
        SizedBox(height: 350, child: TailBlog()),
        FutureBuilder(
          future: shouldShowCoshub(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return Column(
                children: [
                  ListTile(
                    title: Text(
                      convertToUwU(homeCosHubTitle()),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
                    ),
                    trailing: Image.asset(
                      Assets.cosHubBT,
                      width: 24,
                      height: 24,
                    ),
                  ),
                  SizedBox(height: 350, child: CoshubFeed()),
                ],
              );
            } else {
              return Container();
            }
          },
        ),
      ],
    );
  }
}
