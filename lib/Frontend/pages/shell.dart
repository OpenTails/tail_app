import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/Widgets/wear_helper.dart';

import '../Widgets/known_gear.dart';
import '../Widgets/known_gear_scan_controller.dart';
import '../translation_string_definitions.dart';

part 'shell.freezed.dart';

@freezed
abstract class NavDestination with _$NavDestination {
  const factory NavDestination({
    required String label,
    required Widget icon,
    required String path,
  }) = _NavDestination;
}

List<NavDestination> destinations = <NavDestination>[
  NavDestination(
    label: convertToUwU(homePage()),
    icon: Icon(Symbols.home),
    path: '/',
  ),
  NavDestination(
    label: convertToUwU(triggersPage()),
    icon: Icon(Symbols.directions_walk),
    path: '/triggers',
  ),
  NavDestination(
    label: convertToUwU(moreTitle()),
    icon: Icon(Symbols.menu),
    path: "/more",
  ),
];

class NavigationDrawerExample extends StatefulWidget {
  final Widget child;
  final String location;

  const NavigationDrawerExample(this.child, this.location, {super.key});

  @override
  State<NavigationDrawerExample> createState() =>
      _NavigationDrawerExampleState();
}

class _NavigationDrawerExampleState extends State<NavigationDrawerExample> {
  int screenIndex = 0;
  @override
  Widget build(BuildContext context) {
    bool isTablet = MediaQuery.sizeOf(context).shortestSide > 600;
    return PopScope(
      canPop: false,
      child: WearHelper(
        child: Scaffold(
          bottomNavigationBar: isTablet
              ? null
              : NavigationBar(
                  selectedIndex: screenIndex,
                  destinations: destinations.map((NavDestination destination) {
                    return NavigationDestination(
                      label: destination.label,
                      icon: destination.icon,
                      tooltip: destination.label,
                    );
                  }).toList(),
                  onDestinationSelected: (value) => setState(() {
                    screenIndex = value;
                    return GoRouter.of(context).go(destinations[value].path);
                  }),
                ),
          body: Builder(
            builder: (context) {
              if (isTablet) {
                return Row(
                  children: [
                    NavigationRail(
                      selectedIndex: screenIndex,
                      destinations: destinations.map((
                        NavDestination destination,
                      ) {
                        return NavigationRailDestination(
                          label: Text(destination.label),
                          icon: destination.icon,
                        );
                      }).toList(),
                      onDestinationSelected: (value) => setState(() {
                        screenIndex = value;
                        return GoRouter.of(
                          context,
                        ).go(destinations[value].path);
                      }),
                    ),
                    Expanded(child: widget.child),
                  ],
                );
              }
              return SafeArea(bottom: false, top: false, child: widget.child);
            },
          ),
          appBar: AppBar(
            title: const DeviceStatusWidget(),
            centerTitle: true,
            clipBehavior: Clip.none,
            leadingWidth: 0,
            titleSpacing: 0,
            toolbarHeight: 100 * MediaQuery.textScalerOf(context).scale(1),
          ),
        ),
      ),
    );
  }
}

class DeviceStatusWidget extends StatefulWidget {
  const DeviceStatusWidget({super.key});

  @override
  State<DeviceStatusWidget> createState() => _DeviceStatusWidgetState();
}

class _DeviceStatusWidgetState extends State<DeviceStatusWidget> {
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return KnownGearScanController(
      child: FadingEdgeScrollView.fromSingleChildScrollView(
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          padding: EdgeInsets.symmetric(horizontal: 8),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: KnownGear(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController?.dispose();
  }
}
