import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/Backend/Settings.dart';

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
        title: const Text('Settings'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(controller: _controller, children: [
        ListTile(
          title: const Text("Haptic Feedback"),
          leading: const Icon(Icons.vibration),
          subtitle: const Text("Enable vibration when an action or sequence is tapped"),
          trailing: Switch(
            value: preferencesStore.haptics,
            onChanged: (bool value) {
              setState(() {
                ref.read(preferencesProvider).haptics = value;
                ref.read(preferencesProvider.notifier).store();
              });
            },
          ),
        )
      ]),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
