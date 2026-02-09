import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import 'html_page.dart';
import 'markdown_viewer.dart';

class More extends StatefulWidget {
  const More({super.key});

  @override
  State<More> createState() => _MoreState();
}

class _MoreState extends State<More> {
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
            onTap: () async {
              await launchExternalUrl(url: "https://thetailcompany.com/product/tail-and-ear-covers/${getOutboundUtm()}&wdr_coupon=$couponCode", analyticsLabel: "Coupon", addTrackingUtm: false);
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
          onTap: () async {
            await launchExternalUrl(url: (await getDynamicConfigInfo()).urls.coshubUrl, analyticsLabel: "CosHub");
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
                analyticsLabel: "MiTail Manual",
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
                analyticsLabel: "EarGear Manual",
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
                analyticsLabel: "FlutterWings Manual",
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
                analyticsLabel: "Responsible Wagging",
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
          onTap: () async {
            await launchExternalUrl(url: "https://thetailcompany.com", analyticsLabel: "Store");
          },
        ),
        ListTile(
          title: Text(convertToUwU("Technical Wiki")),
          leading: const Icon(Icons.menu_book),
          onTap: () async {
            await launchExternalUrl(url: "https://docs.thetailcompany.com", analyticsLabel: "Wiki");
          },
        ),
        ListTile(
          title: Text(convertToUwU("Telegram")),
          leading: const Icon(Icons.telegram),
          onTap: () async {
            await launchExternalUrl(url: "https://t.me/joinchat/VCdXxqKgRv2yrDNC", analyticsLabel: "Telegram", addTrackingUtm: false);
          },
        ),
        ListTile(
          title: Text(convertToUwU(morePageTranslateTitle())),
          subtitle: Text(convertToUwU(morePageTranslateDescription())),
          leading: const Icon(Icons.language),
          onTap: () async {
            await launchExternalUrl(url: "https://weblate.stargazer.at", analyticsLabel: "Weblate");
          },
        ),
        ListTile(
          title: Text(convertToUwU(supportTitle())),
          leading: const Icon(Icons.message),
          subtitle: Text(convertToUwU(supportDescription())),
          onTap: () async {
            await launchExternalUrl(url: "https://thetailcompany.com", analyticsLabel: "Support");
          },
        ),
        ListTile(
          title: Text(convertToUwU(moreSourceCode())),
          leading: const Icon(Icons.code),
          onTap: () async {
            await launchExternalUrl(url: "https://github.com/Codel1417/tail_app", analyticsLabel: "Source Code", addTrackingUtm: false);
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
                analyticsLabel: "Privacy Policy",
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
