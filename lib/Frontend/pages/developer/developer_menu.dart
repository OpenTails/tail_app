import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../../Backend/logging_wrappers.dart';
import '../../../constants.dart';
import '../../../main.dart';

class DeveloperMenu extends ConsumerStatefulWidget {
  const DeveloperMenu({super.key});

  @override
  ConsumerState<DeveloperMenu> createState() => _DeveloperMenuState();
}

class _DeveloperMenuState extends ConsumerState<DeveloperMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Menu'),
      ),
      body: ListView(
        primary: true,
        children: [
          ListTile(
            title: const Text("Logs"),
            leading: const Icon(Icons.list),
            subtitle: const Text("Application Logs"),
            onTap: () async {
              context.push("/settings/developer/logs");
            },
          ),
          ListTile(
            title: const Text("Throw an error"),
            leading: const Icon(Icons.bug_report),
            subtitle: const Text("Sends an error to sentry"),
            onTap: () {
              throw Exception('Sentry Test');
            },
          ),
          ListTile(
            title: const Text(hasCompletedOnboarding),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) == hasCompletedOnboardingVersionToAgree,
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, hasCompletedOnboarding, value ? hasCompletedOnboardingVersionToAgree : hasCompletedOnboardingDefault);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(shouldDisplayReview),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, shouldDisplayReview, defaultValue: shouldDisplayReviewDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, shouldDisplayReview, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(hasDisplayedReview),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, hasDisplayedReview, defaultValue: hasDisplayedReviewDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, hasDisplayedReview, value);
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(gearDisconnectCount),
            subtitle: Slider(
              divisions: 6,
              max: 6,
              min: 0,
              value: HiveProxy.getOrDefault(settings, gearDisconnectCount, defaultValue: gearDisconnectCountDefault).toDouble(),
              onChanged: (double value) async {
                setState(() {
                  HiveProxy.put(settings, gearDisconnectCount, value.toInt());
                });
              },
            ),
          ),
          ListTile(
            title: const Text(showDebugging),
            trailing: Switch(
              value: HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault),
              onChanged: (bool value) async {
                setState(
                  () {
                    HiveProxy.put(settings, showDebugging, value);
                    context.pop();
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text("isAnyGearConnected"),
            trailing: Switch(
              value: isAnyGearConnected.value,
              onChanged: (bool value) {
                setState(
                  () {
                    isAnyGearConnected.value = value;
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text("SentryEnvironment"),
            subtitle: FutureBuilder(
              future: getSentryEnvironment(),
              builder: (context, snapshot) {
                String value = snapshot.data ?? '';
                return Text(value);
              },
            ),
          ),
          ListTile(
            title: const Text("LatestPostId"),
            subtitle: Text('${HiveProxy.getOrDefault(notificationBox, latestPost, defaultValue: defaultPostId)}'),
          ),
        ],
      ),
    );
  }
}
