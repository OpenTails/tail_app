import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:side_sheet_material3/side_sheet_material3.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/Widgets/snack_bar_overlay.dart';
import 'package:upgrader/upgrader.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../Widgets/manage_devices.dart';
import '../intnDefs.dart';

/// Flutter code sample for [NavigationDrawer].

@immutable
class NavDestination {
  const NavDestination(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final String path;
}

List<NavDestination> destinations = <NavDestination>[
  NavDestination(actionsPage(), const Icon(Icons.widgets_outlined), const Icon(Icons.widgets), "/"),
  NavDestination(triggersPage(), const Icon(Icons.sensors_outlined), const Icon(Icons.sensors), "/triggers"),
  NavDestination(sequencesPage(), const Icon(Icons.list_outlined), const Icon(Icons.list), "/moveLists"),
  NavDestination(joyStickPage(), const Icon(Icons.gamepad_outlined), const Icon(Icons.gamepad), "/joystick"),
  NavDestination(settingsPage(), const Icon(Icons.settings_outlined), const Icon(Icons.settings), "/settings"),
];

class NavigationDrawerExample extends ConsumerStatefulWidget {
  Widget child;
  String location;

  NavigationDrawerExample(this.child, this.location, {super.key});

  @override
  ConsumerState<NavigationDrawerExample> createState() => _NavigationDrawerExampleState();
}

class _NavigationDrawerExampleState extends ConsumerState<NavigationDrawerExample> {
  int screenIndex = 0;
  var controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000))
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          // Update loading bar.
        },
        onPageStarted: (String url) {},
        onPageFinished: (String url) {},
      ),
    )
    ..loadRequest(Uri.parse('https://thetailcompany.com/'));

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      child: AdaptiveScaffold(
        // An option to override the default breakpoints used for small, medium,
        // and large.
        smallBreakpoint: const WidthPlatformBreakpoint(end: 700),
        mediumBreakpoint: const WidthPlatformBreakpoint(begin: 700, end: 1000),
        largeBreakpoint: const WidthPlatformBreakpoint(begin: 1000),
        useDrawer: false,
        appBarBreakpoint: const WidthPlatformBreakpoint(begin: 0),
        selectedIndex: screenIndex,
        onSelectedIndexChange: (int index) {
          setState(() {
            screenIndex = index;
            return GoRouter.of(context).go(destinations[index].path);
          });
        },
        destinations: destinations.map(
          (NavDestination destination) {
            return NavigationDestination(
              label: destination.label,
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              tooltip: destination.label,
            );
          },
        ).toList(),
        body: (_) => DoubleBackToCloseApp(
          snackBar: SnackBar(
            content: Text(doubleBack()),
          ),
          child: SafeArea(
            bottom: false,
            top: false,
            child: SnackBarOverlay(
              child: widget.child,
            ),
          ),
        ),
        smallBody: (_) => DoubleBackToCloseApp(
          snackBar: SnackBar(
            content: Text(doubleBack()),
          ),
          child: SafeArea(
            bottom: false,
            top: false,
            child: SnackBarOverlay(
              child: widget.child,
            ),
          ),
        ),
        // Define a default secondaryBody.
        secondaryBody: (_) => WebViewWidget(controller: controller),
        // Override the default secondaryBody during the smallBreakpoint to be
        // empty. Must use AdaptiveScaffold.emptyBuilder to ensure it is properly
        // overridden.
        smallSecondaryBody: AdaptiveScaffold.emptyBuilder,
        appBar: AppBar(
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ref
                      .watch(knownDevicesProvider)
                      .values
                      .map(
                        (e) => Card(
                          color: e.baseDeviceDefinition.deviceType.color,
                          child: InkWell(
                            //TODO: on tap open device window
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                height: 50,
                                width: 100,
                                child: Stack(
                                  children: [
                                    Text(e.baseStoredDevice.name),
                                    Align(
                                      alignment: Alignment.bottomLeft,
                                      child: MultiValueListenableBuilder(
                                        builder: (BuildContext context, List<dynamic> values, Widget? child) {
                                          if (e.deviceConnectionState.value == DeviceConnectionState.connected) {
                                            return Text("${e.battery.value.round()}%"); //TODO: Replace with dynamic icon
                                          } else {
                                            return Text(e.deviceConnectionState.value.name);
                                          }
                                        },
                                        valueListenables: [e.battery, e.deviceConnectionState],
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: MultiValueListenableBuilder(
                                        builder: (BuildContext context, List<dynamic> values, Widget? child) {
                                          if (e.deviceConnectionState.value == DeviceConnectionState.connected) {
                                            return Text("${e.rssi.value.round()} db"); //TODO: Replace with dynamic icon
                                          }
                                          return Container();
                                        },
                                        valueListenables: [e.rssi, e.deviceConnectionState],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          title: Text(title()),
          actions: [
            IconButton(
                //TODO: Migrate to new widget
                tooltip: manageDevices(),
                onPressed: () async {
                  await showModalSideSheet(
                    context,
                    header: manageDevices(),
                    body: const ManageDevices(),
                    // Put your content widget here
                    addBackIconButton: true,
                    addActions: false,
                    addDivider: true,
                  );
                },
                icon: const Icon(Icons.bluetooth))
          ],
        ),
      ),
    );
  }
}
/*
)*/
