import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../intnDefs.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  final ScrollController _controller = ScrollController();
  Color pickerColor = Color(000000);

  // ValueChanged<Color> callback
  void changeColor(Color color) {
    setState(() => pickerColor = color);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
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
          title: Text(settingsAutoConnectToggleTitle()),
          leading: const Icon(Icons.bluetooth_searching),
          subtitle: Text(settingsAutoConnectToggleSubTitle()),
          trailing: Switch(
            value: SentryHive.box('settings').get('alwaysScanning', defaultValue: false),
            onChanged: (bool value) {
              setState(() {
                SentryHive.box('settings').put('alwaysScanning', value);
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
        ListTile(
          title: Text(
            "Appearance",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          title: const Text(
            "Tail Color", //TODO: Localize
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
        ListTile(
          title: Text(aboutPage()),
          onTap: () {
            PackageInfo.fromPlatform().then(
              (value) => Navigator.push(
                context,
                DialogRoute(
                    builder: (context) => AboutDialog(
                          applicationName: title(),
                          applicationVersion: value.version,
                          applicationLegalese: "This is a fan made app to control 'The Tail Company' tails and ears",
                        ),
                    context: context),
              ),
            );
          },
        ),
        ListTile(
          title: Text(feedbackPage()),
          onTap: () {
            BetterFeedback.of(context).showAndUploadToSentry();
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
