import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:side_sheet_material3/side_sheet_material3.dart';
import 'package:upgrader/upgrader.dart';

import '../Widgets/manage_devices.dart';

/// Flutter code sample for [NavigationDrawer].

@immutable
class NavDestination {
  const NavDestination(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final String path;
}

const List<NavDestination> destinations = <NavDestination>[
  NavDestination('Actions', Icon(Icons.widgets_outlined), Icon(Icons.widgets), "/actions"),
  NavDestination('Triggers', Icon(Icons.sensors_outlined), Icon(Icons.sensors), "/triggers"),
  NavDestination('Sequences', Icon(Icons.list_outlined), Icon(Icons.list), "/moveLists"),
];

class NavigationDrawerExample extends ConsumerStatefulWidget {
  Widget child;
  String location;

  NavigationDrawerExample(this.child, this.location, {super.key});

  @override
  ConsumerState<NavigationDrawerExample> createState() => _NavigationDrawerExampleState();
}

class _NavigationDrawerExampleState extends ConsumerState<NavigationDrawerExample> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late bool showNavigationDrawer;
  int screenIndex = 0;

  void handleScreenChanged(int selectedScreen) {
    setState(() {
      screenIndex = selectedScreen;
      return context.go(destinations[screenIndex].path);
    });
  }

  void openDrawer() {
    scaffoldKey.currentState!.openEndDrawer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    showNavigationDrawer = MediaQuery.of(context).size.width >= 450;
  }

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      child: Scaffold(
        key: scaffoldKey,
        body: DoubleBackToCloseApp(
          snackBar: const SnackBar(
            content: Text('Tap back again to leave'),
          ),
          child: SafeArea(
            bottom: false,
            top: false,
            child: widget.child,
          ),
        ),
        appBar: AppBar(
          title: const Text('Tail App'),
          actions: [
            IconButton(
                tooltip: "Manage Devices",
                onPressed: () async {
                  //List<BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
                  await showModalSideSheet(
                    context,
                    header: 'Manage Devices',
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: screenIndex,
          onDestinationSelected: (int index) {
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
        ),
        drawer: Drawer(
          child: Column(
            children: <Widget>[
              const DrawerHeader(
                child: Text(
                  'All of the Tails',
                ),
              ),
              ListTile(
                title: const Text('Joystick'),
                onTap: () {
                  context.push("/joystick");
                },
              ),
              ListTile(
                title: const Text('About'),
                onTap: () {
                  Navigator.push(
                    context,
                    DialogRoute(
                        builder: (context) => const AboutDialog(
                              applicationName: "Tail_App",
                              applicationVersion: "0.0.1",
                              applicationLegalese: "This is a fan made app to control 'The Tail Company' tails and ears",
                            ),
                        context: context),
                  );
                },
              ),
              ListTile(
                title: const Text('Logs'),
                onTap: () {
                  LogConsole.open(context);
                },
              ),
              ListTile(
                title: const Text('Settings'),
                onTap: () {
                  context.push("/settings");
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
