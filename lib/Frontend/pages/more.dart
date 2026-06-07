import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';

import '../../Backend/utilities/settings.dart';
import '../../assets.dart';
import '../go_router_config.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';
import 'html_page.dart';
import 'markdown_viewer.dart';

class More extends StatelessWidget {
  const More({super.key});

  @override
  Widget build(BuildContext context) {
    const String couponCode = "APPCOV25";

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── Promos ────────────────────────────────────────────────────────────
        _PromoCard(
          icon: Icons.store,
          title: convertToUwU(morePageCoverPromoTitle()),
          subtitle: convertToUwU(morePageCoverPromoDescription(couponCode: couponCode)),
          badge: couponCode,
          onTap: () => launchExternalUrl(
            url: "https://thetailcompany.com/product/tail-and-ear-covers/${getOutboundUtm()}&wdr_coupon=$couponCode",
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
            await launchExternalUrl(url: info.urls.coshubUrl, analyticsLabel: "CosHub");
          },
        ),
        const SizedBox(height: 24),

        // ── Feature shortcuts ─────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FeatureTile(icon: Icons.settings, label: convertToUwU(settingsPage()), onTap: () => const SettingsRoute().push(context))),
            const SizedBox(width: 8),
            Expanded(child: _FeatureTile(icon: Icons.list, label: convertToUwU(sequencesPage()), onTap: () => const MoveListRoute().push(context))),
            const SizedBox(width: 8),
            Expanded(child: _FeatureTile(icon: Icons.audio_file, label: convertToUwU(audioPage()), onTap: () => const CustomAudioRoute().push(context))),
          ],
        ),
        if (isDeveloperEnabled) ...[
          const SizedBox(height: 12),
          _GroupCard(children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: Text(convertToUwU("Development Menu")),
              subtitle: Text(convertToUwU("It is illegal to read this message")),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const DeveloperMenuRoute().push(context),
            ),
            ListTile(
              leading: const Icon(Icons.gamepad),
              title: Text(convertToUwU(joyStickPage())),
              subtitle: Text(convertToUwU(joyStickPageDescription())),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const DirectGearControlRoute().push(context),
            ),
          ]),
        ],
        const SizedBox(height: 24),

        // ── Manuals ───────────────────────────────────────────────────────────
        _SectionLabel("${moreManualTitle()} (${moreManualSubTitle()})"),
        const SizedBox(height: 8),
        _GroupCard(children: [
          ListTile(
            title: Text(convertToUwU(moreManualMiTailTitle())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PDFPageRoute(
              $extra: PDFInfo(url: "https://thetailcompany.com/mitail.pdf", title: moreManualMiTailTitle(), analyticsLabel: "MiTail Manual"),
            ).push(context),
          ),
          ListTile(
            title: Text(convertToUwU(moreManualEargearTitle())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PDFPageRoute(
              $extra: PDFInfo(url: "https://thetailcompany.com/eargear.pdf", title: moreManualEargearTitle(), analyticsLabel: "EarGear Manual"),
            ).push(context),
          ),
          ListTile(
            title: Text(convertToUwU(moreManualFlutterWingsTitle())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PDFPageRoute(
              $extra: PDFInfo(url: "https://thetailcompany.com/flutterwings.pdf", title: moreManualFlutterWingsTitle(), analyticsLabel: "FlutterWings Manual"),
            ).push(context),
          ),
          ListTile(
            title: Text(convertToUwU(moreManualResponsibleWaggingTitle())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => HtmlPageRoute(
              $extra: HtmlPageInfo(
                url: "https://docs.thetailcompany.com/doku.php?id=en:safety&do=export_xhtmlbody",
                title: moreManualResponsibleWaggingTitle(),
                analyticsLabel: "Responsible Wagging",
              ),
            ).push(context),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Useful links ──────────────────────────────────────────────────────
        _SectionLabel(moreUsefulLinksTitle()),
        const SizedBox(height: 8),
        _GroupCard(children: [
          ListTile(
            leading: const Icon(Icons.store),
            title: Text(convertToUwU("Store")),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchExternalUrl(url: "https://thetailcompany.com", analyticsLabel: "Store"),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(convertToUwU("Technical Wiki")),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchExternalUrl(url: "https://docs.thetailcompany.com", analyticsLabel: "Wiki"),
          ),
          ListTile(
            leading: const Icon(Icons.telegram),
            title: Text(convertToUwU("Telegram")),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchExternalUrl(url: "https://t.me/joinchat/VCdXxqKgRv2yrDNC", analyticsLabel: "Telegram", addTrackingUtm: false),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(convertToUwU(morePageTranslateTitle())),
            subtitle: Text(convertToUwU(morePageTranslateDescription())),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchExternalUrl(url: "https://weblate.stargazer.at", analyticsLabel: "Weblate"),
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: Text(convertToUwU(supportTitle())),
            subtitle: Text(convertToUwU(supportDescription())),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchExternalUrl(url: "https://thetailcompany.com", analyticsLabel: "Support"),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(convertToUwU(moreSourceCode())),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchExternalUrl(url: "https://github.com/Codel1417/tail_app", analyticsLabel: "Source Code", addTrackingUtm: false),
            onLongPress: isDeveloperEnabled ? null : () => const DeveloperPincodeRoute().push(context),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Legal / About ─────────────────────────────────────────────────────
        _GroupCard(children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(convertToUwU(morePrivacyPolicyLinkTitle())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final content = await rootBundle.loadString(Assets.privacy);
              if (context.mounted) {
                MarkdownViewerRoute(
                  $extra: MarkdownInfo(content: content, title: morePrivacyPolicyLinkTitle(), analyticsLabel: "Privacy Policy"),
                ).push(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(convertToUwU(aboutPage())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PackageInfo.fromPlatform().then((value) {
              if (context.mounted) {
                showLicensePage(
                  context: context,
                  useRootNavigator: true,
                  applicationVersion: "${value.version} (${value.buildNumber})",
                  applicationLegalese: "Developed by Code-Floof for the community. Open Source GPL 3.0 Licensed",
                  applicationIcon: Image.asset(Assets.tCLogoTransparentNoText, width: 150, height: 150),
                );
              }
            }),
          ),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
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
    final leading = customLeading ?? Icon(icon!, color: colorScheme.primary, size: 28);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
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
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    if (badge != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: tcBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            color: Color(0xFFFFFFFF),
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
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
