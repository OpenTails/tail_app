import 'package:choice/choice.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../../l10n/app_localizations.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  ConsumerState<Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  final ScrollController _controller = ScrollController();
  late Color appColorValue;

  @override
  void initState() {
    super.initState();
    appColorValue = Color(HiveProxy.getOrDefault(settings, appColor, defaultValue: appColorDefault));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(settingsPage()),
      ),
      body: ListView(
        controller: _controller,
        children: [
          LanguagePicker(),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text(
              settingsAppColor(),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (HiveProxy.getOrDefault(settings, appColor, defaultValue: appColorDefault) != appColorDefault) ...[
                  IconButton(
                      onPressed: () {
                        setState(() {
                          HiveProxy.put(settings, appColor, appColorDefault);
                          appColorValue = Color(appColorDefault);
                        });
                      },
                      icon: Icon(Icons.clear)),
                ],
                ColorIndicator(
                  width: 44,
                  height: 44,
                  borderRadius: 22,
                  color: appColorValue,
                )
              ],
            ),
            onTap: () async {
              ColorPickerRoute(defaultColor: appColorValue.value).push(context).then(
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
            title: Text(settingsBatteryPercentageToggleTitle()),
            leading: const Icon(Icons.battery_unknown),
            subtitle: Text(settingsBatteryPercentageToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, showAccurateBattery, defaultValue: showAccurateBatteryDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, showAccurateBattery, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: Text(settingsLargerCardsToggleTitle()),
            leading: const Icon(Icons.format_size),
            subtitle: Text(settingsLargerCardsToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, largerActionCardSize, defaultValue: largerActionCardSizeDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, largerActionCardSize, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: Text(settingsTutorialCardToggleTitle()),
            leading: const Icon(Icons.help),
            subtitle: Text(settingsTutorialCardToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, hideTutorialCards, defaultValue: hideTutorialCardsDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, hideTutorialCards, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: Text(settingsTailBlogWifiOnlyTitle()),
            leading: const Icon(Icons.wifi),
            subtitle: Text(settingsTailBlogWifiOnlyDescription()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, tailBlogWifiOnly, defaultValue: tailBlogWifiOnlyDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, tailBlogWifiOnly, value);
                  },
                );
              },
            ),
          ),
          const ListTile(
            title: Divider(),
          ),
          ListTile(
            title: Text(settingsAlwaysScanningToggleTitle()),
            leading: const Icon(Icons.bluetooth_searching),
            subtitle: Text(settingsAlwaysScanningToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, alwaysScanning, defaultValue: alwaysScanningDefault),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, alwaysScanning, value);
                });
              },
            ),
          ),
          ListTile(
            title: Text(settingsHapticsToggleTitle()),
            leading: const Icon(Icons.vibration),
            subtitle: Text(settingsHapticsToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, haptics, value);
                });
              },
            ),
          ),
          ListTile(
            title: Text(settingsKeepScreenOnToggleTitle()),
            leading: const Icon(Icons.phone_android),
            subtitle: Text(settingsKeepScreenOnToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, keepAwake, defaultValue: keepAwakeDefault),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, keepAwake, value);
                  if (ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == ConnectivityState.connected).isNotEmpty) {
                    if (value) {
                      WakelockPlus.enable();
                    } else {
                      WakelockPlus.disable();
                    }
                  }
                });
              },
            ),
          ),
          ListTile(
            title: Text(settingsKitsuneToggleTitle()),
            leading: const Icon(Icons.more_time),
            subtitle: Text(settingsKitsuneToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, kitsuneModeToggle, defaultValue: kitsuneModeDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, kitsuneModeToggle, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: Text(scanDemoGear()),
            leading: const Icon(Icons.explore),
            subtitle: Text(scanDemoGearTip()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, showDemoGear, defaultValue: showDemoGearDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, showDemoGear, value);
                  },
                );
              },
            ),
          ),
          const ListTile(
            title: Divider(),
          ),
          ListTile(
            title: Text(settingsAnalyticsToggleTitle()),
            leading: const Icon(Icons.analytics),
            subtitle: Text(settingsAnalyticsToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, allowAnalytics, defaultValue: allowAnalyticsDefault),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, allowAnalytics, value);
                });
              },
            ),
          ),
          ListTile(
            //This is handled separately as I was storing settings in a provider, which is unavailable during sentry init
            title: Text(settingsErrorReportingToggleTitle()),
            leading: const Icon(Icons.error),
            subtitle: Text(settingsErrorReportingToggleSubTitle()),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, allowErrorReporting, defaultValue: allowErrorReportingDefault),
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

class LanguagePicker extends StatelessWidget {
  final ChoicePromptBuilder<Locale>? anchorBuilder;

  const LanguagePicker({
    super.key,
    this.anchorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return PromptedChoice<Locale>.single(
      title: appLanguageSelectorTitle(),
      promptDelegate: ChoicePrompt.delegateBottomSheet(useRootNavigator: true, enableDrag: true, maxHeightFactor: 0.8),
      itemCount: AppLocalizations.supportedLocales.length,
      modalHeaderBuilder: ChoiceModal.createHeader(
        automaticallyImplyLeading: true,
        actionsBuilder: [],
      ),
      anchorBuilder: anchorBuilder,
      modalFooterBuilder: ChoiceModal.createFooter(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          (choiceController) {
            return FilledButton(
              onPressed: choiceController.value.isNotEmpty ? () => choiceController.closeModal(confirmed: true) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Text(
                    triggersDefSelectSaveLabel(),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: getTextColor(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  ),
                ],
              ),
            );
          },
        ],
      ),
      onChanged: (value) async {
        if (value != null) {
          HiveProxy.put(settings, selectedLocale, value.toLanguageTag());
          initLocale();
        }
      },
      confirmation: true,
      value: AppLocalizations.supportedLocales
          .where(
            (element) => element.toLanguageTag() == HiveProxy.getOrDefault(settings, selectedLocale, defaultValue: ""),
          )
          .firstOrNull,
      itemBuilder: (ChoiceController<Locale> state, int index) {
        Locale locale = AppLocalizations.supportedLocales[index];
        return RadioListTile(
          value: locale,
          onChanged: (Locale? value) {
            state.select(locale);
          },
          groupValue: state.single,
          title: Text(LocaleNames.of(context)!.nameOf(locale.toLanguageTag().replaceAll("-", "_")) ?? locale.toLanguageTag()),
          secondary: Builder(builder: (context) {
            if (locale.countryCode != null) {
              return CountryFlag.fromCountryCode(locale.countryCode!.replaceAll("zh", "zh-cn"));
            } else {
              return CountryFlag.fromLanguageCode(locale.languageCode.replaceAll("zh", "zh-cn"));
            }
          }),
        );
      },
    );
    return ListTile(
      title: Text("Language"),
      trailing: DropdownMenu<Locale>(
        width: MediaQuery.of(context).size.width / 3,
        onSelected: (value) {
          if (value != null) {
            HiveProxy.put(settings, selectedLocale, value.toLanguageTag());
          }
        },
        initialSelection: AppLocalizations.supportedLocales
            .where(
              (element) => element.toLanguageTag() == HiveProxy.getOrDefault(settings, selectedLocale, defaultValue: ""),
            )
            .firstOrNull,
        dropdownMenuEntries: AppLocalizations.supportedLocales
            .map(
              (e) => DropdownMenuEntry(
                label: LocaleNames.of(context)!.nameOf(e.toLanguageTag().replaceAll("-", "_")) ?? e.toLanguageTag(),
                value: e,
                leadingIcon: Builder(builder: (context) {
                  if (e.countryCode != null) {
                    return CountryFlag.fromCountryCode(e.countryCode!.replaceAll("zh", "zh-cn"));
                  } else {
                    return CountryFlag.fromLanguageCode(e.languageCode.replaceAll("zh", "zh-cn"));
                  }
                }),
              ),
            )
            .toList(),
      ),
    );
  }
}
