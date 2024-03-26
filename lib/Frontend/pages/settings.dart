import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../constants.dart';
import '../../main.dart';
import '../intnDefs.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  final ScrollController _controller = ScrollController();
  late Color appColorValue;

  @override
  void initState() {
    super.initState();
    appColorValue = Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault));
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
          ListTile(
            title: Text(settingsHapticsToggleTitle()),
            leading: const Icon(Icons.vibration),
            subtitle: Text(settingsHapticsToggleSubTitle()),
            trailing: Switch(
              value: SentryHive.box(settings).get(haptics, defaultValue: hapticsDefault),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box(settings).put(haptics, value);
                });
              },
            ),
          ),
          ListTile(
            //This is handled separately as I was storing settings in a provider, which is unavailable during sentry init
            title: Text(settingsKeepScreenOnToggleTitle()),
            leading: const Icon(Icons.phone_android),
            subtitle: Text(settingsKeepScreenOnToggleSubTitle()),
            trailing: Switch(
              value: SentryHive.box(settings).get(keepAwake, defaultValue: keepAwakeDefault),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box(settings).put(keepAwake, value);
                  if (ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState.value == DeviceConnectionState.connected).isNotEmpty) {
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
            //This is handled separately as I was storing settings in a provider, which is unavailable during sentry init
            title: Text(settingsKitsuneToggleTitle()),
            leading: const Icon(Icons.more_time),
            subtitle: Text(settingsKitsuneToggleSubTitle()),
            trailing: Switch(
              value: SentryHive.box(settings).get(kitsuneModeToggle, defaultValue: kitsuneModeDefault),
              onChanged: (bool value) {
                setState(
                  () {
                    SentryHive.box(settings).put(kitsuneModeToggle, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text(
              settingsAppColor(),
            ),
            trailing: ColorIndicator(
              width: 44,
              height: 44,
              borderRadius: 22,
              color: Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault)),
            ),
            onTap: () {
              plausible.event(page: "Settings/App Color");
              showDialog<bool>(
                  context: context,
                  useRootNavigator: false,
                  useSafeArea: true,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        settingsAppColor(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            SentryHive.box(settings).put(appColor, appColorValue.value);
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            ok(),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            appColorValue = Color(SentryHive.box(settings).get(appColor, defaultValue: appColorDefault));
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            cancel(),
                          ),
                        )
                      ],
                      content: Wrap(
                        children: [
                          ColorPicker(
                            color: appColorValue,
                            padding: EdgeInsets.zero,
                            onColorChanged: (Color color) => setState(() => appColorValue = color),
                            pickersEnabled: const <ColorPickerType, bool>{
                              ColorPickerType.both: false,
                              ColorPickerType.primary: true,
                              ColorPickerType.accent: true,
                              ColorPickerType.wheel: true,
                            },
                          )
                        ],
                      ),
                    );
                  }).whenComplete(() => setState(() {}));
            },
          ),
          const ListTile(
            title: Divider(),
          ),
          ListTile(
            //This is handled separately as I was storing settings in a provider, which is unavailable during sentry init
            title: Text(settingsAnalyticsToggleTitle()),
            leading: const Icon(Icons.analytics),
            subtitle: Text(settingsAnalyticsToggleSubTitle()),
            trailing: Switch(
              value: SentryHive.box(settings).get(allowAnalytics, defaultValue: allowAnalyticsDefault),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box(settings).put(allowAnalytics, value);
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
              value: SentryHive.box(settings).get(allowErrorReporting, defaultValue: allowErrorReportingDefault),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box(settings).put(allowErrorReporting, value);
                });
              },
            ),
          ),
          if (kDebugMode) ...[
            ListTile(
              title: const Text("Development Menu"),
              leading: const Icon(Icons.bug_report),
              subtitle: const Text("It is illegal to read this message"),
              onTap: () {
                context.push('/settings/developer');
              },
            )
          ],
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
