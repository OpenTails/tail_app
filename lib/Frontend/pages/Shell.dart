import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:side_sheet_material3/side_sheet_material3.dart';
import 'package:tail_app/Frontend/Widgets/snack_bar_overlay.dart';
import 'package:upgrader/upgrader.dart';

import '../../l10n/messages_all_locales.dart';
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
];

class NavigationDrawerExample extends ConsumerStatefulWidget {
  Widget child;
  String location;

  NavigationDrawerExample(this.child, this.location, {super.key}) {
    initializeMessages('ace');
  }

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
              DrawerHeader(
                child: Text(
                  subTitle(),
                ),
              ),
              ListTile(
                title: Text(joyStickPage()),
                onTap: () {
                  context.push("/joystick");
                },
              ),
              ListTile(
                title: Text(feedbackPage()),
                onTap: () {
                  BetterFeedback.of(context).showAndUploadToSentry();
                },
              ),
              ListTile(
                title: Text(aboutPage()),
                onTap: () {
                  PackageInfo.fromPlatform().then(
                    (value) => Navigator.push(
                      context,
                      DialogRoute(
                          builder: (context) => AboutDialog(
                                applicationName: title(),
                                applicationVersion: value.version,
                                applicationLegalese: "This is a fan made app to control 'The Tail Company' tails and ears",
                              ),
                          context: context),
                    ),
                  );
                },
              ),
              ListTile(
                title: Text(settingsPage()),
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
