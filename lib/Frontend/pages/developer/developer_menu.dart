import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data_saver/data_saver.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:go_router/go_router.dart';
import 'package:json_visualizer/widgets/json_visualizer.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Device/device_type_enum.dart';
import 'package:tail_app/Frontend/Widgets/base_card.dart';
import 'package:tail_app/Frontend/theme_helpers.dart';
import 'package:theme_inspector/theme_inspector.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_io/io.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../Backend/dynamic_config.dart';
import '../../../Backend/logging_wrappers.dart';
import '../../../Backend/utilities/sentry.dart';
import '../../../Backend/utilities/settings.dart';
import '../../../Backend/wear_bridge.dart';
import '../../../assets.dart';
import '../../../constants.dart';
import '../../Widgets/signal_icon.dart';
import '../../go_router_config.dart';

class DeveloperMenu extends StatefulWidget {
  const DeveloperMenu({super.key});

  @override
  State<DeveloperMenu> createState() => _DeveloperMenuState();
}

class _DeveloperMenuState extends State<DeveloperMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Menu')),
      body: ListView(
        primary: true,
        children: [
          ListTile(
            title: const Text("Logs"),
            leading: const Icon(Symbols.list),
            subtitle: const Text("Application Logs"),
            onTap: () async {
              const LogsRoute().push(context);
            },
          ),
          ListTile(
            title: const Text("Bulk Update"),
            leading: const Icon(Symbols.system_update),
            subtitle: const Text("Update multiple gear"),
            onTap: () async {
              const BulkOtaUpdateRoute().push(context);
            },
          ),
          ListTile(
            title: const Text("Throw an error"),
            leading: const Icon(Symbols.bug_report),
            subtitle: const Text("Sends an error to sentry"),
            onTap: () {
              throw Exception('Sentry Test');
            },
          ),
          ListTile(
            title: const Text("Send all sentry events"),
            trailing: Switch(
              value: HiveProxy.getOrDefault(
                settings,
                sendAllSentryEvents,
                defaultValue: false,
              ),
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, sendAllSentryEvents, value);
                });
              },
            ),
          ),
          const ListTile(title: Divider()),
          ListTile(
            title: const Text("Theme Inspector"),
            leading: const Icon(Symbols.color_lens),
            subtitle: const Text("Visualize the current theme"),
            onTap: () => ThemeInspector.open(context),
          ),
          ListTile(
            title: const Text("Text Luminance Threshold"),
            trailing: Text(luminanceThreshold.value.toStringAsFixed(2)),
            subtitle: Slider(
              min: 0,
              max: 1,
              value: luminanceThreshold.value,
              onChanged: (double value) {
                setState(() {
                  luminanceThreshold.value = value;
                });
              },
            ),
          ),
          GridView.extent(
            shrinkWrap: true,
            maxCrossAxisExtent: 150,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(0),
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            children: DeviceType.values
                .map(
                  (e) => SizedBox.square(
                    dimension: 200,
                    child: BaseCard(
                      color: e.color(),
                      child: Center(
                        child: Text(
                          e.name,
                          style: TextTheme.of(context).labelLarge?.copyWith(
                            color: getTextColor(
                              color: e.color(),
                              context: context,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          ListTile(
            title: const Text("Color Scheme variant"),
            trailing: DropdownMenu<DynamicSchemeVariant>(
              initialSelection: dynamicSchemeVariant.value,
              onSelected: (DynamicSchemeVariant? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  dynamicSchemeVariant.value = value;
                });
              },
              dropdownMenuEntries: DynamicSchemeVariant.values
                  .map((e) => DropdownMenuEntry(value: e, label: e.name))
                  .toList(),
            ),
          ),

          Builder(
            builder: (context) {
              ColorScheme colorScheme = ColorScheme.of(context);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text("Primary"),
                    subtitle: Wrap(
                      children: [
                        ColorIndicator(color: colorScheme.primary),
                        ColorIndicator(color: colorScheme.onPrimary),
                        ColorIndicator(color: colorScheme.primaryContainer),
                        ColorIndicator(color: colorScheme.onPrimaryContainer),
                        ColorIndicator(color: colorScheme.primaryFixed),
                        ColorIndicator(color: colorScheme.onPrimaryFixed),
                        ColorIndicator(color: colorScheme.primaryFixedDim),
                        ColorIndicator(
                          color: colorScheme.onPrimaryFixedVariant,
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text("Secondary"),
                    subtitle: Wrap(
                      children: [
                        ColorIndicator(color: colorScheme.secondary),
                        ColorIndicator(color: colorScheme.onSecondary),
                        ColorIndicator(color: colorScheme.secondaryContainer),
                        ColorIndicator(color: colorScheme.onSecondaryContainer),
                        ColorIndicator(color: colorScheme.secondaryFixed),
                        ColorIndicator(color: colorScheme.onSecondaryFixed),
                        ColorIndicator(color: colorScheme.secondaryFixedDim),
                        ColorIndicator(
                          color: colorScheme.onSecondaryFixedVariant,
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text("Tertiary"),
                    subtitle: Wrap(
                      children: [
                        ColorIndicator(color: colorScheme.tertiary),
                        ColorIndicator(color: colorScheme.onTertiary),
                        ColorIndicator(color: colorScheme.tertiaryContainer),
                        ColorIndicator(color: colorScheme.onTertiaryContainer),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text("Surface"),
                    subtitle: Wrap(
                      children: [
                        ColorIndicator(color: colorScheme.surface),
                        ColorIndicator(color: colorScheme.onSurface),
                        ColorIndicator(color: colorScheme.surfaceContainer),
                        ColorIndicator(color: colorScheme.surfaceBright),
                        ColorIndicator(color: colorScheme.surfaceContainerHigh),
                        ColorIndicator(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        ColorIndicator(color: colorScheme.surfaceContainerLow),
                        ColorIndicator(
                          color: colorScheme.surfaceContainerLowest,
                        ),
                        ColorIndicator(color: colorScheme.surfaceDim),
                        ColorIndicator(color: colorScheme.surfaceTint),
                        ColorIndicator(color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text("Error"),
                    subtitle: Wrap(
                      children: [
                        ColorIndicator(color: colorScheme.error),
                        ColorIndicator(color: colorScheme.onError),
                        ColorIndicator(color: colorScheme.errorContainer),
                        ColorIndicator(color: colorScheme.onErrorContainer),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const ListTile(title: Divider()),
          ListTile(
            title: const Text(hasCompletedOnboarding),
            trailing: Switch(
              value:
                  HiveProxy.getOrDefault(
                    settings,
                    hasCompletedOnboarding,
                    defaultValue: hasCompletedOnboardingDefault,
                  ) ==
                  hasCompletedOnboardingVersionToAgree,
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(
                    settings,
                    hasCompletedOnboarding,
                    value
                        ? hasCompletedOnboardingVersionToAgree
                        : hasCompletedOnboardingDefault,
                  );
                  if (!value) {
                    OnBoardingPageRoute().go(context);
                  }
                });
              },
            ),
          ),
          ListTile(
            title: const Text(triggerActionCooldown),
            subtitle: Slider(
              divisions: 30,
              max: 30,
              min: 0,
              label: HiveProxy.getOrDefault(
                settings,
                triggerActionCooldown,
                defaultValue: triggerActionCooldownDefault,
              ).toString(),
              value: HiveProxy.getOrDefault(
                settings,
                triggerActionCooldown,
                defaultValue: triggerActionCooldownDefault,
              ).toDouble(),
              onChanged: (double value) async {
                setState(() {
                  HiveProxy.put(settings, triggerActionCooldown, value.toInt());
                });
              },
            ),
            trailing: Text(
              HiveProxy.getOrDefault(
                settings,
                triggerActionCooldown,
                defaultValue: triggerActionCooldownDefault,
              ).toString(),
            ),
          ),
          ListTile(
            title: const Text(showDebugging),
            trailing: Switch(
              value: isDeveloperEnabled,
              onChanged: (bool value) async {
                setState(() {
                  HiveProxy.put(settings, showDebugging, value);
                  context.pop();
                });
              },
            ),
          ),
          const ListTile(title: Divider()),
          ListenableBuilder(
            listenable: Scan.instance,
            builder: (context, child) => ListTile(
              title: const Text("ScanState"),
              subtitle: Text(Scan.instance.state.toString()),
            ),
          ),
          ListTile(
            title: const Text("BLE Availability"),
            subtitle: FutureBuilder(
              future: UniversalBle.getBluetoothAvailabilityState(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<AvailabilityState> snapshot,
                  ) {
                    var value = snapshot.data;
                    String text = value != null ? value.toString() : "unknown";
                    return Text(text);
                  },
            ),
          ),
          ListTile(
            title: const Text("System Devices"),
            subtitle: StreamBuilder(
              stream: Stream.periodic(Duration(seconds: 1)).asBroadcastStream(),
              builder: (context, asyncSnapshot) {
                return FutureBuilder(
                  future: UniversalBle.getSystemDevices(),
                  builder: (context, snapshot) {
                    String value = "";
                    if (snapshot.hasData) {
                      return ListView(
                        shrinkWrap: true,
                        primary: false,
                        children: snapshot.data!
                            .map(
                              (e) => ListTile(
                                dense: true,
                                title: Text(e.name ?? "unknown"),
                                subtitle: Text(e.deviceId),
                                leading: SignalIcon(rssi: e.rssi ?? -1),
                                trailing: Text(e.isSystemDevice.toString()),
                              ),
                            )
                            .toList(),
                      );
                    }
                    return Text(value);
                  },
                );
              },
            ),
          ),
          const ListTile(title: Divider()),
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
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<ConnectivityResult>> snapshot,
                  ) {
                    var value = snapshot.data;
                    String text = value != null ? value.toString() : "unknown";
                    return Text(text);
                  },
            ),
          ),
          ListTile(
            title: const Text("DataSaver"),
            subtitle: FutureBuilder(
              future: DataSaver().checkMode(),
              builder: (context, snapshot) {
                String dataSaverMode = "";
                if (snapshot.hasData) {
                  dataSaverMode = snapshot.data!.name;
                }
                return Text(dataSaverMode);
              },
            ),
          ),
          ListTile(
            title: const Text("Foreground Service"),
            subtitle: FutureBuilder(
              future: FlutterForegroundTask.isRunningService,
              builder: (context, snapshot) {
                String foregroundRunning = "";
                if (snapshot.hasData) {
                  foregroundRunning = snapshot.data!.toString();
                }
                return Text(foregroundRunning);
              },
            ),
          ),
          ListTile(
            title: const Text("Wakelock"),
            subtitle: FutureBuilder(
              future: WakelockPlus.enabled,
              builder: (context, snapshot) {
                String wakelockStatus = "";
                if (snapshot.hasData) {
                  wakelockStatus = snapshot.data!.toString();
                }
                return Text(wakelockStatus);
              },
            ),
          ),
          const ListTile(title: Divider()),
          ListTile(
            title: const Text("DynamicConfig"),
            subtitle: FutureBuilder(
              future: rootBundle.loadString(Assets.dynamicConfig),
              builder: (context, snapshot) {
                String dynamicConfigJsonDefault = "";
                if (snapshot.hasData) {
                  dynamicConfigJsonDefault = snapshot.data!;
                }
                return JsonVisualizer(
                  expandDepth: 3,
                  data: HiveProxy.getOrDefault(
                    settings,
                    dynamicConfigJsonString,
                    defaultValue: dynamicConfigJsonDefault,
                  ),
                );
              },
            ),
          ),
          ListTile(
            subtitle: OverflowBar(
              children: [
                FilledButton(
                  onPressed: () {
                    clearDynamicConfigCache();
                    if (context.mounted) {
                      setState(() {});
                    }
                  },
                  child: Text("Clear Config"),
                ),
                FilledButton(
                  onPressed: () {
                    getDynamicConfigInfo();
                    if (context.mounted) {
                      setState(() {});
                    }
                  },
                  child: Text("Refresh Config"),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text("PlatformLocale"),
            subtitle: Text(Platform.localeName),
          ),
          const ListTile(title: Divider()),
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
                Map<String, dynamic> value =
                    snapshot.data ?? <String, dynamic>{};
                return JsonVisualizer(
                  expandDepth: 3,
                  data: JsonEncoder().convert(value),
                );
              },
            ),
          ),
          ListTile(
            subtitle: OverflowBar(
              children: [
                FilledButton(
                  onPressed: () async {
                    await clearContext();
                    if (context.mounted) {
                      setState(() {});
                    }
                  },
                  child: Text("Clear Context"),
                ),
                FilledButton(
                  onPressed: () async {
                    await updateWearData(reason: "Manual Refresh");
                    if (context.mounted) {
                      setState(() {});
                    }
                  },
                  child: Text("Refresh Context"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
