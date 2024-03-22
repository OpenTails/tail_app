import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../main.dart';
import '../intnDefs.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  final ScrollController _controller = ScrollController();
  Color appColor = Color(SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(settingsPage()),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        controller: _controller,
        children: [
          ListTile(
            title: Text(settingsHapticsToggleTitle()),
            leading: const Icon(Icons.vibration),
            subtitle: Text(settingsHapticsToggleSubTitle()),
            trailing: Switch(
              value: SentryHive.box('settings').get('haptics', defaultValue: true),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box('settings').put('haptics', value);
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
              value: SentryHive.box('settings').get('keepAwake', defaultValue: false),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box('settings').put('keepAwake', value);
                  if (ref.read(knownDevicesProvider).values.where((element) => element.deviceConnectionState == DeviceConnectionState.connected).isNotEmpty) {
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
            leading: const Icon(Icons.color_lens),
            title: Text(
              settingsAppColor(),
            ),
            trailing: ColorIndicator(
              width: 44,
              height: 44,
              borderRadius: 22,
              color: Color(SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value)),
            ),
            onTap: () {
              plausible.event(page: "Settings/App Color");
              ColorPicker(
                title: Text(
                  settingsAppColor(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                color: appColor,
                onColorChanged: (Color color) => setState(() => appColor = color),
                pickersEnabled: const <ColorPickerType, bool>{
                  ColorPickerType.both: false,
                  ColorPickerType.primary: true,
                  ColorPickerType.accent: true,
                  ColorPickerType.wheel: true,
                },
              ).showPickerDialog(context).then(
                (value) {
                  if (value) {
                    SentryHive.box('settings').put('appColor', appColor.value);
                  } else {
                    appColor = Color(SentryHive.box('settings').get('appColor', defaultValue: Colors.orange.value));
                  }
                },
              );
            },
          ),
          ListTile(
            //This is handled separately as I was storing settings in a provider, which is unavailable during sentry init
            title: Text(settingsAnalyticsToggleTitle()),
            leading: const Icon(Icons.analytics),
            subtitle: Text(settingsAnalyticsToggleSubTitle()),
            trailing: Switch(
              value: SentryHive.box('settings').get('allowAnalytics', defaultValue: true),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box('settings').put('allowAnalytics', value);
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
              value: SentryHive.box('settings').get('allowErrorReporting', defaultValue: true),
              onChanged: (bool value) {
                setState(() {
                  SentryHive.box('settings').put('allowErrorReporting', value);
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
