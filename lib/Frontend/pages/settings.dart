import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../Backend/Settings.dart';
import '../../main.dart';
import '../intnDefs.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    PreferencesStore preferencesStore = ref.watch(preferencesProvider);
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
              value: preferencesStore.haptics,
              onChanged: (bool value) {
                setState(() {
                  ref.read(preferencesProvider).haptics = value;
                  ref.read(preferencesProvider.notifier).store();
                });
              },
            ),
          ),
          ListTile(
            title: Text(settingsAutoConnectToggleTitle()),
            leading: const Icon(Icons.bluetooth_searching),
            subtitle: Text(settingsAutoConnectToggleSubTitle()),
            trailing: Switch(
              value: preferencesStore.alwaysScanning,
              onChanged: (bool value) {
                setState(() {
                  ref.read(preferencesProvider).alwaysScanning = value;
                  ref.read(preferencesProvider.notifier).store();
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
              value: prefs.getBool("AllowErrorReporting") ?? true,
              onChanged: (bool value) {
                setState(() {
                  prefs.setBool("AllowErrorReporting", value);
                });
              },
            ),
          ),
          ListTile(
            title: const Text("Development Menu"),
            leading: const Icon(Icons.bug_report),
            subtitle: const Text("It is illegal to read this message"),
            onTap: () {
              context.push('/settings/developer');
            },
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
