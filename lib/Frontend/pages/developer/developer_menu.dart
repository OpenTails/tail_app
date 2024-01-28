import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging_flutter/logging_flutter.dart';

import '../../../main.dart';

class DeveloperMenu extends StatelessWidget {
  const DeveloperMenu({super.key});

  //TODO: Add mock devices
  //TODO: Show hidden device state/values
  //TODO: Steal Snacks
  //TODO: Backup/Restore json
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Menu'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        primary: true,
        children: [
          ListTile(
            title: const Text("Logs"),
            leading: const Icon(Icons.list),
            subtitle: const Text("Application Logs"),
            onTap: () {
              LogConsole.open(context);
            },
          ),
          ListTile(
            title: const Text("Crash"),
            leading: const Icon(Icons.bug_report),
            subtitle: const Text("Test crash reporting"),
            onTap: () {
              throw Exception('Sentry Test');
            },
          ),
          ListTile(
            title: Text(
              "Stored JSON",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text("Triggers"),
            onTap: () {
              context.push('/settings/developer/json', extra: const JsonEncoder.withIndent("    ").convert(prefs.getStringList("triggers")));
            },
          ),
          ListTile(
            title: const Text("Sequences"),
            onTap: () {
              context.push('/settings/developer/json', extra: const JsonEncoder.withIndent("    ").convert(prefs.getStringList("sequences")));
            },
          ),
          ListTile(
            title: const Text("Devices"),
            onTap: () {
              context.push('/settings/developer/json', extra: const JsonEncoder.withIndent("    ").convert(prefs.getStringList("devices")));
            },
          ),
          ListTile(
            title: const Text("Settings"),
            onTap: () {
              context.push('/settings/developer/json', extra: prefs.getString("settings"));
            },
          )
        ],
      ),
    );
  }
}
