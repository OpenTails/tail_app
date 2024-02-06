import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:side_sheet_material3/side_sheet_material3.dart';
import 'package:tail_app/Frontend/Widgets/snack_bar_overlay.dart';
import 'package:upgrader/upgrader.dart';

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
        internalAnimations: true,
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
        secondaryBody: (_) => Container(
          //TODO: add widget here
          color: const Color.fromARGB(255, 234, 158, 192),
        ),
        // Override the default secondaryBody during the smallBreakpoint to be
        // empty. Must use AdaptiveScaffold.emptyBuilder to ensure it is properly
        // overridden.
        smallSecondaryBody: AdaptiveScaffold.emptyBuilder,

        appBar: AppBar(
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
