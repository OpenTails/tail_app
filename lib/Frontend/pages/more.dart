import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/Device/device_type_enum.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';

import '../../Backend/utilities/developer_options_helpers.dart';
import '../../assets.dart';
import '../Widgets/group_card.dart';
import '../Widgets/section_label.dart';
import '../go_router_config.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';
import 'html_page.dart';
import 'markdown_viewer.dart';

class More extends StatefulWidget {
  const More({super.key});

  static bool _pendingScrollToManuals = false;

  static void requestScrollToManuals() => _pendingScrollToManuals = true;

  @override
  State<More> createState() => _MoreState();
}

class _MoreState extends State<More> {
  final ScrollController _controller = ScrollController();
  final GlobalKey _manualsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (More._pendingScrollToManuals) {
      More._pendingScrollToManuals = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _manualsKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const String couponCode = "APPCOV25";

    return ListView(
      controller: _controller,
      padding: sectionedListViewPadding,
      children: [
        // ── Promos ────────────────────────────────────────────────────────────
        _PromoCard(
          icon: Symbols.store,
          title: convertToUwU(morePageCoverPromoTitle()),
          subtitle: convertToUwU(
            morePageCoverPromoDescription(couponCode: couponCode),
          ),
          badge: couponCode,
          onTap: () => launchExternalUrl(
            url:
                "https://thetailcompany.com/product/tail-and-ear-covers/${getOutboundUtm()}&wdr_coupon=$couponCode",
            analyticsLabel: "Coupon",
            addTrackingUtm: false,
          ),
        ),
        const SizedBox(height: 10),
        _PromoCard(
          customLeading: Image.asset(Assets.cosHubBT, width: 28, height: 28),
          title: convertToUwU(moreCoshubPromoTitle()),
          subtitle: convertToUwU(moreCoshubPromoDescription()),
          onTap: () async {
            final info = await getDynamicConfigInfo();
            await launchExternalUrl(
              url: info.urls.coshubUrl,
              analyticsLabel: "CosHub",
            );
          },
        ),
        const SizedBox(height: 24),

        // ── Feature shortcuts ─────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Expanded(
                child: _FeatureTile(
                  icon: Symbols.settings,
                  label: convertToUwU(settingsPage()),
                  onTap: () => const SettingsRoute().push(context),
                ),
              ),
              Expanded(
                child: _FeatureTile(
                  icon: Symbols.list,
                  label: convertToUwU(sequencesPage()),
                  onTap: () => const MoveListRoute().push(context),
                ),
              ),
              Expanded(
                child: _FeatureTile(
                  icon: Symbols.audio_file,
                  label: convertToUwU(audioPage()),
                  onTap: () => const CustomAudioRoute().push(context),
                ),
              ),
            ],
          ),
        ),
        if (isDeveloperEnabled) ...[
          const SizedBox(height: 12),
          GroupCard(
            children: [
              ListTile(
                leading: const Icon(Symbols.bug_report),
                title: Text(convertToUwU("Development Menu")),
                subtitle: Text(
                  convertToUwU("It is illegal to read this message"),
                ),
                trailing: const Icon(Symbols.chevron_right),
                onTap: () => const DeveloperMenuRoute().push(context),
              ),
              ListTile(
                leading: const Icon(Symbols.gamepad),
                title: Text(convertToUwU(joyStickPage())),
                subtitle: Text(convertToUwU(joyStickPageDescription())),
                trailing: const Icon(Symbols.chevron_right),
                onTap: () => const DirectGearControlRoute().push(context),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        // ── Manuals ───────────────────────────────────────────────────────────
        SizedBox(
          key: _manualsKey,
          child: SectionLabel("${moreManualTitle()} (${moreManualSubTitle()})"),
        ),
        const SizedBox(height: 8),
        GroupCard(
          children: [
            ListTile(
              title: Text(convertToUwU(moreManualMiTailTitle())),
              leading: DeviceType.tail.icon(
                IconTheme.of(context).size ?? 24,
                Theme.of(context).colorScheme.onSurface,
              ),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => PDFPageRoute(
                $extra: PDFInfo(
                  url: "https://thetailcompany.com/mitail.pdf",
                  title: moreManualMiTailTitle(),
                  analyticsLabel: "MiTail Manual",
                ),
              ).push(context),
            ),
            ListTile(
              title: Text(convertToUwU(moreManualEargearTitle())),
              leading: DeviceType.ears.icon(
                IconTheme.of(context).size ?? 24,
                Theme.of(context).colorScheme.onSurface,
              ),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => PDFPageRoute(
                $extra: PDFInfo(
                  url: "https://thetailcompany.com/eargear.pdf",
                  title: moreManualEargearTitle(),
                  analyticsLabel: "EarGear Manual",
                ),
              ).push(context),
            ),
            ListTile(
              title: Text(convertToUwU(moreManualFlutterWingsTitle())),
              leading: DeviceType.wings.icon(
                IconTheme.of(context).size ?? 24,
                Theme.of(context).colorScheme.onSurface,
              ),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => PDFPageRoute(
                $extra: PDFInfo(
                  url: "https://thetailcompany.com/flutterwings.pdf",
                  title: moreManualFlutterWingsTitle(),
                  analyticsLabel: "FlutterWings Manual",
                ),
              ).push(context),
            ),
            ListTile(
              title: Text(convertToUwU(moreManualResponsibleWaggingTitle())),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => HtmlPageRoute(
                $extra: HtmlPageInfo(
                  url:
                      "https://docs.thetailcompany.com/doku.php?id=en:safety&do=export_xhtmlbody",
                  title: moreManualResponsibleWaggingTitle(),
                  analyticsLabel: "Responsible Wagging",
                ),
              ).push(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Useful links ──────────────────────────────────────────────────────
        SectionLabel(moreUsefulLinksTitle()),
        const SizedBox(height: 8),
        GroupCard(
          children: [
            ListTile(
              leading: const Icon(Symbols.store),
              title: Text(convertToUwU("Store")),
              trailing: const Icon(Symbols.open_in_new, size: 18),
              onTap: () => launchExternalUrl(
                url: "https://thetailcompany.com",
                analyticsLabel: "Store",
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.menu_book),
              title: Text(convertToUwU("Technical Wiki")),
              trailing: const Icon(Symbols.open_in_new, size: 18),
              onTap: () => launchExternalUrl(
                url: "https://docs.thetailcompany.com",
                analyticsLabel: "Wiki",
              ),
            ),
            ListTile(
              leading: const Icon(Icons.telegram),
              title: Text(convertToUwU("Telegram")),
              trailing: const Icon(Symbols.open_in_new, size: 18),
              onTap: () => launchExternalUrl(
                url: "https://t.me/joinchat/VCdXxqKgRv2yrDNC",
                analyticsLabel: "Telegram",
                addTrackingUtm: false,
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.language),
              title: Text(convertToUwU(morePageTranslateTitle())),
              subtitle: Text(convertToUwU(morePageTranslateDescription())),
              trailing: const Icon(Symbols.open_in_new, size: 18),
              onTap: () => launchExternalUrl(
                url: "https://weblate.stargazer.at",
                analyticsLabel: "Weblate",
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.message),
              title: Text(convertToUwU(supportTitle())),
              subtitle: Text(convertToUwU(supportDescription())),
              trailing: const Icon(Symbols.open_in_new, size: 18),
              onTap: () => launchExternalUrl(
                url: "https://thetailcompany.com",
                analyticsLabel: "Support",
              ),
            ),
            ListTile(
              leading: const Icon(Symbols.code),
              title: Text(convertToUwU(moreSourceCode())),
              trailing: const Icon(Symbols.open_in_new, size: 18),
              onTap: () => launchExternalUrl(
                url: "https://github.com/Codel1417/tail_app",
                analyticsLabel: "Source Code",
                addTrackingUtm: false,
              ),
              onLongPress: isDeveloperEnabled
                  ? null
                  : () => const DeveloperPincodeRoute().push(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Legal / About ─────────────────────────────────────────────────────
        GroupCard(
          children: [
            ListTile(
              leading: const Icon(Symbols.privacy_tip),
              title: Text(convertToUwU(morePrivacyPolicyLinkTitle())),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () async {
                final content = await rootBundle.loadString(Assets.privacy);
                if (context.mounted) {
                  MarkdownViewerRoute(
                    $extra: MarkdownInfo(
                      content: content,
                      title: morePrivacyPolicyLinkTitle(),
                      analyticsLabel: "Privacy Policy",
                    ),
                  ).push(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Symbols.info),
              title: Text(convertToUwU(aboutPage())),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => PackageInfo.fromPlatform().then((value) {
                if (context.mounted) {
                  showLicensePage(
                    context: context,
                    useRootNavigator: true,
                    applicationVersion:
                        "${value.version} (${value.buildNumber})",
                    applicationLegalese:
                        "Developed by Code-Floof for the community. Open Source GPL 3.0 Licensed",
                    applicationIcon: Image.asset(
                      Assets.tCLogoTransparentNoText,
                      width: 150,
                      height: 150,
                    ),
                  );
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final IconData? icon;
  final Widget? customLeading;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _PromoCard({
    this.icon,
    this.customLeading,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final leading =
        customLeading ?? Icon(icon!, color: colorScheme.primary, size: 28);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
                child: leading,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tcBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Symbols.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
