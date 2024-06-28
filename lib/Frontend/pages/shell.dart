import 'dart:async';

import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:upgrader/upgrader.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../Widgets/back_button_to_close.dart';
import '../Widgets/known_gear.dart';
import '../Widgets/known_gear_scan_controller.dart';
import '../Widgets/logging_shake.dart';
import '../Widgets/snack_bar_overlay.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

part 'shell.freezed.dart';

@freezed
class NavDestination with _$NavDestination {
  const factory NavDestination({
    required String label,
    required Widget icon,
    required Widget selectedIcon,
    required String path,
  }) = _NavDestination;
}

List<NavDestination> destinations = <NavDestination>[
  NavDestination(label: homePage(), icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), path: '/'),
  NavDestination(label: triggersPage(), icon: const Icon(Icons.sensors_outlined), selectedIcon: const Icon(Icons.sensors), path: '/triggers'),
  //NavDestination(sequencesPage(), const Icon(Icons.list_outlined), const Icon(Icons.list), "/moveLists"),
  //NavDestination(joyStickPage(), const Icon(Icons.gamepad_outlined), const Icon(Icons.gamepad), "/joystick"),
  NavDestination(label: moreTitle(), icon: const Icon(Icons.menu), selectedIcon: const Icon(Icons.menu_open), path: "/more"),
];

class NavigationDrawerExample extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const NavigationDrawerExample(this.child, this.location, {super.key});

  @override
  ConsumerState<NavigationDrawerExample> createState() => _NavigationDrawerExampleState();
}

class _NavigationDrawerExampleState extends ConsumerState<NavigationDrawerExample> {
  int screenIndex = 0;
  bool showAppBar = true;
  final InAppReview inAppReview = InAppReview.instance;

  @override
  Widget build(BuildContext context) {
    unawaited(setupSystemColor(context));
    return LoggingShake(
      child: BackButtonToClose(
        child: UpgradeAlert(
          child: ValueListenableBuilder(
            valueListenable: SentryHive.box(settings).listenable(keys: [shouldDisplayReview]),
            builder: (BuildContext context, Box<dynamic> value, Widget? child) {
              if (value.get(shouldDisplayReview, defaultValue: shouldDisplayReviewDefault) && !value.get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault)) {
                inAppReview.isAvailable().then(
                  (isAvailable) {
                    if (isAvailable && value.get(shouldDisplayReview, defaultValue: shouldDisplayReviewDefault) && !value.get(hasDisplayedReview, defaultValue: hasDisplayedReviewDefault) && mounted) {
                      inAppReview.requestReview();
                      Future(
                        // Don't refresh widget in same frame
                        () async {
                          HiveProxy
                            ..put(settings, hasDisplayedReview, true)
                            ..put(settings, shouldDisplayReview, false);
                        },
                      );
                    }
                  },
                );
              }

              return child!;
            },
            child: AdaptiveScaffold(
              // An option to override the default breakpoints used for small, medium,
              // and large.
              smallBreakpoint: const WidthPlatformBreakpoint(end: 700),
              mediumBreakpoint: const WidthPlatformBreakpoint(begin: 700, end: 1000),
              largeBreakpoint: const WidthPlatformBreakpoint(begin: 1000),
              useDrawer: false,
              internalAnimations: false,
              transitionDuration: Duration.zero,
              appBarBreakpoint: const WidthPlatformBreakpoint(begin: 0),
              selectedIndex: screenIndex,
              onSelectedIndexChange: (int index) {
                setState(
                  () {
                    screenIndex = index;
                    return GoRouter.of(context).go(destinations[index].path);
                  },
                );
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
              body: (_) => SafeArea(
                bottom: false,
                top: false,
                child: SnackBarOverlay(
                  child: widget.child,
                ),
              ),
              // smallBody: (_) => SafeArea(
              //   bottom: false,
              //   top: false,
              //   child: SnackBarOverlay(
              //     child: widget.child,
              //   ),
              // ),
              // Define a default secondaryBody.
              //secondaryBody: AdaptiveScaffold.emptyBuilder,
              // Override the default secondaryBody during the smallBreakpoint to be
              // empty. Must use AdaptiveScaffold.emptyBuilder to ensure it is properly
              // overridden.
              smallSecondaryBody: AdaptiveScaffold.emptyBuilder,
              appBar: AppBar(
                title: const DeviceStatusWidget(),
                centerTitle: true,
                leadingWidth: 0,
                titleSpacing: 0,
                toolbarHeight: 100 * MediaQuery.textScalerOf(context).scale(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeviceStatusWidget extends ConsumerStatefulWidget {
  const DeviceStatusWidget({super.key});

  @override
  ConsumerState<DeviceStatusWidget> createState() => _DeviceStatusWidgetState();
}

class _DeviceStatusWidgetState extends ConsumerState<DeviceStatusWidget> {
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
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: KnownGear(),
          ),
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
