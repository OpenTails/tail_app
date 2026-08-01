import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../Widgets/language_picker.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final ScrollController _controller = ScrollController();
  late Color appColorValue;

  @override
  void initState() {
    super.initState();
    appColorValue = Color(
      HiveProxy.getOrDefault(settings, appColor, defaultValue: appColorDefault),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(convertToUwU(settingsPage()))),
      body: ListView(
        controller: _controller,
        children: [
          LanguagePicker(),
          ListTile(
            leading: const Icon(Symbols.color_lens),
            title: Text(convertToUwU(settingsAppColor())),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (HiveProxy.getOrDefault(
                      settings,
                      appColor,
                      defaultValue: appColorDefault,
                    ) !=
                    appColorDefault) ...[
                  IconButton(
                    onPressed: () {
                      setState(() {
                        HiveProxy.put(settings, appColor, appColorDefault);
                        appColorValue = Color(appColorDefault);
                      });
                    },
                    icon: Icon(Symbols.clear),
                  ),
                ],
                ColorIndicator(
                  width: 44,
                  height: 44,
                  borderRadius: 22,
                  color: appColorValue,
                ),
              ],
            ),
            onTap: () async {
              ColorPickerRoute(defaultColor: appColorValue.toARGB32())
                  .push(context)
                  .then(
                    (color) => setState(() {
                      if (color != null) {
                        HiveProxy.put(settings, appColor, color);
                        appColorValue = Color(color);
                      }
                    }),
                  );
            },
          ),
          ListTile(
            title: Text(convertToUwU(settingsLargerCardsToggleTitle())),
            leading: const Icon(Symbols.format_size),
            subtitle: Text(convertToUwU(settingsLargerCardsToggleSubTitle())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                largerActionCardSize,
                defaultValue: largerActionCardSizeDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, largerActionCardSize, value);
                });
              },
            ),
          ),
          ListTile(
            title: Text(convertToUwU(settingsTutorialCardToggleTitle())),
            leading: const Icon(Symbols.help),
            subtitle: Text(convertToUwU(settingsTutorialCardToggleSubTitle())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                hideTutorialCards,
                defaultValue: hideTutorialCardsDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, hideTutorialCards, value);
                });
              },
            ),
          ),
          ListTile(
            title: Text(convertToUwU(settingsTailBlogWifiOnlyTitle())),
            leading: const Icon(Symbols.wifi),
            subtitle: Text(convertToUwU(settingsTailBlogWifiOnlyDescription())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                tailBlogWifiOnly,
                defaultValue: tailBlogWifiOnlyDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, tailBlogWifiOnly, value);
                });
              },
            ),
          ),
          const ListTile(title: Divider()),
          ListTile(
            title: Text(convertToUwU(settingsHapticsToggleTitle())),
            leading: const Icon(Symbols.vibration),
            subtitle: Text(convertToUwU(settingsHapticsToggleSubTitle())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                haptics,
                defaultValue: hapticsDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, haptics, value);
                });
              },
            ),
          ),
          ListTile(
            title: Text(convertToUwU(settingsKeepScreenOnToggleTitle())),
            leading: const Icon(Symbols.phone_android),
            subtitle: Text(convertToUwU(settingsKeepScreenOnToggleSubTitle())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                keepAwake,
                defaultValue: keepAwakeDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, keepAwake, value);
                });
              },
            ),
          ),
          ListTile(
            title: Text(convertToUwU(settingsKitsuneToggleTitle())),
            leading: const Icon(Symbols.more_time),
            subtitle: Text(convertToUwU(settingsKitsuneToggleSubTitle())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                kitsuneModeToggle,
                defaultValue: kitsuneModeDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, kitsuneModeToggle, value);
                });
              },
            ),
          ),
          ListTile(
            title: Text(convertToUwU(settingsUwUToggleTitle())),
            leading: const Icon(Symbols.explore),
            subtitle: Text(convertToUwU(settingsUwUToggleSubTitle())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                uwuTextEnabled,
                defaultValue: uwuTextEnabledDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, uwuTextEnabled, value);
                });
              },
            ),
          ),
          const ListTile(title: Divider()),
          ListTile(
            title: Text(convertToUwU(settingsAnalyticsToggleTitle())),
            leading: const Icon(Symbols.analytics),
            subtitle: Text(convertToUwU(settingsAnalyticsToggleSubTitle())),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                allowAnalytics,
                defaultValue: allowAnalyticsDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, allowAnalytics, value);
                });
              },
            ),
          ),
          ListTile(
            //This is handled separately as I was storing settings in a provider, which is unavailable during sentry init
            title: Text(convertToUwU(settingsErrorReportingToggleTitle())),
            leading: const Icon(Icons.error),
            subtitle: Text(
              convertToUwU(settingsErrorReportingToggleSubTitle()),
            ),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                allowErrorReporting,
                defaultValue: allowErrorReportingDefault,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, allowErrorReporting, value);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
