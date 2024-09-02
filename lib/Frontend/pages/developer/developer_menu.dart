import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:install_referrer/install_referrer.dart';

import '../../../Backend/logging_wrappers.dart';
import '../../../Backend/wear_bridge.dart';
import '../../../constants.dart';
import '../../../main.dart';
import '../../go_router_config.dart';

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
              const LogsRoute().push(context);
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
            title: const Text("InstallReferrer"),
            subtitle: FutureBuilder(
              future: InstallReferrer.referrer,
              builder: (context, snapshot) {
                InstallationAppReferrer? value = snapshot.data;
                String referral = value != null ? value.name : "unknown";
                return Text(referral);
              },
            ),
          ),
          ListTile(
            title: const Text("ConnectivityType"),
            subtitle: StreamBuilder(
              stream: Connectivity().onConnectivityChanged,
              builder: (BuildContext context, AsyncSnapshot<List<ConnectivityResult>> snapshot) {
                var value = snapshot.data;
                String text = value != null ? value.toString() : "unknown";
                return Text(text);
              },
            ),
          ),
          const ListTile(
            title: Divider(),
          ),
          ListTile(
            title: const Text("WatchIsReachable"),
            subtitle: FutureBuilder(
              future: isReachable(),
              builder: (context, snapshot) {
                bool value = snapshot.data ?? false;
                return Text(value.toString());
              },
            ),
          ),
          ListTile(
            title: const Text("WatchIsSupported"),
            subtitle: FutureBuilder(
              future: isSupported(),
              builder: (context, snapshot) {
                bool value = snapshot.data ?? false;
                return Text(value.toString());
              },
            ),
          ),
          ListTile(
            title: const Text("WatchIsPaired"),
            subtitle: FutureBuilder(
              future: isPaired(),
              builder: (context, snapshot) {
                bool value = snapshot.data ?? false;
                return Text(value.toString());
              },
            ),
          ),
          ListTile(
            title: const Text("WatchApplicationContext"),
            subtitle: FutureBuilder(
              future: applicationContext(),
              builder: (context, snapshot) {
                Map<String, dynamic> value = snapshot.data ?? {};
                return Text(value.toString());
              },
            ),
          ),
        ],
      ),
    );
  }
}
