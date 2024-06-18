import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'html_page.dart';
import 'markdown_viewer.dart';

class More extends ConsumerStatefulWidget {
  const More({super.key});

  @override
  ConsumerState<More> createState() => _MoreState();
}

class _MoreState extends ConsumerState<More> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: Text(joyStickPage()),
          subtitle: Text(joyStickPageDescription()),
          leading: const Icon(Icons.gamepad),
          onTap: () async {
            const DirectGearControlRoute().push(context);
          },
        ),
        ListTile(
          title: Text(sequencesPage()),
          subtitle: Text(sequencesPageDescription()),
          leading: const Icon(Icons.list),
          onTap: () async {
            const MoveListRoute().push(context);
          },
        ),
        ListTile(
          title: Text(audioPage()),
          subtitle: Text(audioEditDescription()),
          leading: const Icon(Icons.audio_file),
          onTap: () async {
            const CustomAudioRoute().push(context);
          },
        ),
        ListTile(
          title: Text(settingsPage()),
          subtitle: Text(settingsDescription()),
          leading: const Icon(Icons.settings),
          onTap: () async {
            const SettingsRoute().push(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.feedback),
          title: Text(feedbackPage()),
          onTap: () {
            BetterFeedback.of(context).showAndUploadToSentry();
          },
        ),
        ListTile(
          title: Text(
            moreManualTitle(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        ListTile(
          title: Text(moreManualMiTailTitle()),
          subtitle: Text(moreManualSubTitle()),
          onTap: () async {
            HtmlPageRoute(
              $extra: HtmlPageInfo(
                url: "https://docs.thetailcompany.com/doku.php?id=en:man:mitail&do=export_xhtmlbody",
                title: moreManualMiTailTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(moreManualEargearTitle()),
          subtitle: Text(moreManualSubTitle()),
          onTap: () async {
            HtmlPageRoute(
              $extra: HtmlPageInfo(
                url: "https://docs.thetailcompany.com/doku.php?id=en:man:eg2&do=export_xhtmlbody",
                title: moreManualEargearTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(moreManualFlutterWingsTitle()),
          subtitle: Text(moreManualSubTitle()),
          onTap: () async {
            HtmlPageRoute(
              $extra: HtmlPageInfo(
                url: "https://docs.thetailcompany.com/doku.php?id=en:man:flutterwings&do=export_xhtmlbody",
                title: moreManualFlutterWingsTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(moreManualResponsibleWaggingTitle()),
          subtitle: Text(moreManualSubTitle()),
          onTap: () async {
            HtmlPageRoute(
              $extra: HtmlPageInfo(
                url: "https://docs.thetailcompany.com/doku.php?id=en:safety&do=export_xhtmlbody",
                title: moreManualResponsibleWaggingTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(
            moreUsefulLinksTitle(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        ListTile(
          title: const Text("Store"),
          leading: const Icon(Icons.store),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://thetailcompany.com/${getOutboundUtm()}'));
          },
        ),
        ListTile(
          title: const Text("Wiki"),
          leading: const Icon(Icons.menu_book),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://docs.thetailcompany.com/${getOutboundUtm()}'));
          },
        ),
        ListTile(
          title: const Text("Telegram"),
          leading: const Icon(Icons.telegram),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://t.me/joinchat/VCdXxqKgRv2yrDNC'));
          },
        ),
        ListTile(
          title: const Text("Support Email"),
          leading: const Icon(Icons.email),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('mailto:info@thetailcompany.com'));
          },
        ),
        ListTile(
          title: Text(moreSourceCode()),
          leading: const Icon(Icons.code),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://github.com/Codel1417/tail_app'));
          },
          onLongPress: () async {
            if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) {
              return;
            }
            const DeveloperPincodeRoute().push(context);
          },
        ),
        ListTile(
          title: Text(morePrivacyPolicyLinkTitle()),
          leading: const Icon(Icons.privacy_tip),
          onTap: () async {
            MarkdownViewerRoute(
              $extra: MarkdownInfo(
                content: await rootBundle.loadString(Assets.privacy),
                title: morePrivacyPolicyLinkTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(aboutPage()),
          leading: const Icon(Icons.info),
          onTap: () async {
            PackageInfo.fromPlatform().then(
              (value) => showLicensePage(
                context: context,
                useRootNavigator: true,
                applicationVersion: "${value.version} (${value.buildNumber})",
                applicationLegalese: "Developed by Code-Floof for the community. Open Source GPL 3.0 Licensed",
                applicationIcon: Image.asset(
                  Assets.tCLogoTransparentNoText.path,
                  width: 150,
                  height: 150,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
