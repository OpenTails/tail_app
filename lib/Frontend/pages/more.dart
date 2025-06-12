import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';
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
        Builder(builder: (context) {
          String couponCode = "APPCOV25";
          return ListTile(
            title: Text(convertToUwU(morePageCoverPromoTitle())),
            subtitle: Text(convertToUwU(morePageCoverPromoDescription(couponCode: couponCode))),
            leading: const Icon(Icons.store),
            trailing: const Icon(Icons.open_in_browser),
            onTap: () async {
              await launchUrl(Uri.parse('https://thetailcompany.com/product/tail-and-ear-covers/${getOutboundUtm()}&wdr_coupon=$couponCode'));
            },
          );
        }),
        ListTile(
          title: Text(convertToUwU(moreCoshubPromoTitle())),
          subtitle: Text(convertToUwU(moreCoshubPromoDescription())),
          leading: Image.asset(
            Assets.cosHubBT.path,
            width: 24,
            height: 24,
          ),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://coshub.com/${getOutboundUtm()}'));
          },
        ),
        ListTile(
          title: Text(convertToUwU(settingsPage())),
          subtitle: Text(convertToUwU(settingsDescription())),
          leading: const Icon(Icons.settings),
          onTap: () async {
            const SettingsRoute().push(context);
          },
        ),
        if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
          ListTile(
            title: Text(convertToUwU("Development Menu")),
            leading: const Icon(Icons.bug_report),
            subtitle: Text(convertToUwU("It is illegal to read this message")),
            onTap: () async {
              const DeveloperMenuRoute().push(context);
            },
          ),
        ],
        ListTile(
          title: Text(
            convertToUwU(moreExperimentalTitle()),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) ...[
          ListTile(
            title: Text(convertToUwU(joyStickPage())),
            subtitle: Text(convertToUwU(joyStickPageDescription())),
            leading: const Icon(Icons.gamepad),
            trailing: const Icon(Icons.bug_report),
            onTap: () async {
              const DirectGearControlRoute().push(context);
            },
          ),
        ],
        ListTile(
          title: Text(convertToUwU(sequencesPage())),
          subtitle: Text(convertToUwU(sequencesPageDescription())),
          leading: const Icon(Icons.list),
          onTap: () async {
            const MoveListRoute().push(context);
          },
        ),
        ListTile(
          title: Text(convertToUwU(audioPage())),
          subtitle: Text(convertToUwU(audioEditDescription())),
          leading: const Icon(Icons.audio_file),
          onTap: () async {
            const CustomAudioRoute().push(context);
          },
        ),
        ListTile(
            title: Text(
          convertToUwU("${moreManualTitle()} (${moreManualSubTitle()})"),
          style: Theme.of(context).textTheme.headlineLarge,
        )),
        ListTile(
          title: Text(convertToUwU(moreManualMiTailTitle())),
          onTap: () async {
            PDFPageRoute(
              $extra: PDFInfo(
                url: "https://thetailcompany.com/mitail.pdf",
                title: moreManualMiTailTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(convertToUwU(moreManualEargearTitle())),
          onTap: () async {
            PDFPageRoute(
              $extra: PDFInfo(
                url: "https://thetailcompany.com/eargear.pdf",
                title: moreManualEargearTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(convertToUwU(moreManualFlutterWingsTitle())),
          onTap: () async {
            PDFPageRoute(
              $extra: PDFInfo(
                url: "https://thetailcompany.com/flutterwings.pdf",
                title: moreManualFlutterWingsTitle(),
              ),
            ).push(context);
          },
        ),
        ListTile(
          title: Text(convertToUwU(moreManualResponsibleWaggingTitle())),
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
          convertToUwU(moreUsefulLinksTitle()),
          style: Theme.of(context).textTheme.headlineLarge,
        )),
        ListTile(
          title: Text(convertToUwU("Store")),
          leading: const Icon(Icons.store),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://thetailcompany.com/${getOutboundUtm()}'));
          },
        ),
        ListTile(
          title: Text(convertToUwU("Technical Wiki")),
          leading: const Icon(Icons.menu_book),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://docs.thetailcompany.com/${getOutboundUtm()}'));
          },
        ),
        ListTile(
          title: Text(convertToUwU("Telegram")),
          leading: const Icon(Icons.telegram),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://t.me/joinchat/VCdXxqKgRv2yrDNC'));
          },
        ),
        ListTile(
          title: Text(convertToUwU(morePageTranslateTitle())),
          subtitle: Text(convertToUwU(morePageTranslateDescription())),
          leading: const Icon(Icons.language),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://weblate.stargazer.at'));
          },
        ),
        ListTile(
          title: Text(convertToUwU(supportTitle())),
          leading: const Icon(Icons.message),
          subtitle: Text(convertToUwU(supportDescription())),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://thetailcompany.com/${getOutboundUtm()}'));
          },
        ),
        ListTile(
          title: Text(convertToUwU(moreSourceCode())),
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
          title: Text(convertToUwU(morePrivacyPolicyLinkTitle())),
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
          title: Text(convertToUwU(aboutPage())),
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
