import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../Backend/logging_wrappers.dart';
import '../../../Backend/wear_bridge.dart';
import '../../../constants.dart';
import '../../../gen/assets.gen.dart';
import '../../../main.dart';
import '../../go_router_config.dart';
import '../../utils.dart';

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
            title: const Text("Bulk Update"),
            leading: const Icon(Icons.system_update),
            subtitle: const Text("Update multiple gear"),
            onTap: () async {
              const BulkOtaUpdateRoute().push(context);
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
                    if (!value) {
                      OnBoardingPageRoute().go(context);
                    }
                  },
                );
              },
            ),
          ),
          ListTile(
            title: const Text(triggerActionCooldown),
            subtitle: Slider(
              divisions: 30,
              max: 30,
              min: 0,
              label: HiveProxy.getOrDefault(settings, triggerActionCooldown, defaultValue: triggerActionCooldownDefault).toString(),
              value: HiveProxy.getOrDefault(settings, triggerActionCooldown, defaultValue: triggerActionCooldownDefault).toDouble(),
              onChanged: (double value) async {
                setState(() {
                  HiveProxy.put(settings, triggerActionCooldown, value.toInt());
                });
              },
            ),
          ),
          ListTile(
            title: const Text(gearConnectRetryAttempts),
            subtitle: Slider(
              divisions: 29,
              max: 30,
              min: 1,
              label: HiveProxy.getOrDefault(settings, gearConnectRetryAttempts, defaultValue: gearConnectRetryAttemptsDefault).toString(),
              value: HiveProxy.getOrDefault(settings, gearConnectRetryAttempts, defaultValue: gearConnectRetryAttemptsDefault).toDouble(),
              onChanged: (double value) async {
                setState(() {
                  HiveProxy.put(settings, gearConnectRetryAttempts, value.toInt());
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
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                PackageInfo? value = snapshot.data;
                String referral = value?.installerStore ?? "unknown";
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
          ListTile(
            title: const Text("DynamicConfig"),
            subtitle: FutureBuilder(
              future: rootBundle.loadString(Assets.dynamicConfig),
              builder: (context, snapshot) {
                String dynamicConfigJsonDefault = "";
                if (snapshot.hasData) {
                  dynamicConfigJsonDefault = snapshot.data!;
                }
                return Text(HiveProxy.getOrDefault(settings, dynamicConfigJsonString, defaultValue: dynamicConfigJsonDefault));
              },
            ),
          ),
          ListTile(
            title: const Text("PlatformLocale"),
            subtitle: Text(Platform.localeName),
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
