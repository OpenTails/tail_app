import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logarte/logarte.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Frontend/pages/developer/bulk_ota.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';

import '../Backend/Definitions/Action/base_action.dart';
import '../Backend/Definitions/Device/device_definition.dart';
import '../Backend/logging_wrappers.dart';
import '../Backend/move_lists.dart';
import '../Backend/plausible_dio.dart';
import '../constants.dart';
import 'Widgets/color_picker_dialog.dart';
import 'Widgets/manage_gear.dart';
import 'Widgets/scan_for_new_device.dart';
import 'pages/action_selector.dart';
import 'pages/actions.dart';
import 'pages/custom_audio.dart';
import 'pages/developer/bluetooth_console.dart';
import 'pages/developer/developer_menu.dart';
import 'pages/developer/developer_pincode.dart';
import 'pages/direct_gear_control.dart';
import 'pages/html_page.dart';
import 'pages/intro.dart';
import 'pages/markdown_viewer.dart';
import 'pages/more.dart';
import 'pages/move_list.dart';
import 'pages/ota_update.dart';
import 'pages/settings.dart';
import 'pages/shell.dart';
import 'pages/triggers.dart';

part 'go_router_config.g.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();
String _previousPageName = "";
// GoRouter configuration
final GoRouter router = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: rootNavigatorKey,
  observers: [
    SentryNavigatorObserver(),
    //CustomNavObserver(plausible),
    LogarteNavigatorObserver(logarte),
  ],
  redirect: (context, state) {
    String name = state.uri.path;
    if (name.isNotEmpty) {
      unawaited(plausible.event(page: name.toString(), referrer: _previousPageName));
      _previousPageName = name;
    }
    return null;
  },
  routes: $appRoutes,
);

class TriggersRoute extends GoRouteData {
  const TriggersRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => NoTransitionPage(key: state.pageKey, name: state.name, child: const Triggers());
}

@TypedGoRoute<TriggersEditRoute>(
  path: '/triggers/edit',
  name: 'Triggers/Edit',
)
class TriggersEditRoute extends GoRouteData {
  const TriggersEditRoute({required this.uuid});

  final String uuid;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => ModalPage(key: state.pageKey, name: state.name, child: TriggerEdit(uuid: uuid));
}

@TypedGoRoute<ManageGearRoute>(
  path: '/manageGear',
  name: 'Manage Gear',
)
class ManageGearRoute extends GoRouteData {
  const ManageGearRoute({required this.btMac});

  final String btMac;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => ModalPage(
        key: state.pageKey,
        name: state.name,
        child: ManageGear(
          btMac: btMac,
        ),
      );
}

@TypedGoRoute<ColorPickerRoute>(
  path: '/color',
  name: 'Color Picker',
)
class ColorPickerRoute extends GoRouteData {
  const ColorPickerRoute({required this.defaultColor});

  final int defaultColor;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => DialogPage(
        key: state.pageKey,
        name: state.name,
        child: ColorPickerDialog(
          defaultColor: defaultColor,
        ),
      );
}

@TypedGoRoute<ScanForGearRoute>(
  path: '/scan',
  name: 'Scan for new devices',
)
class ScanForGearRoute extends GoRouteData {
  const ScanForGearRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => ModalPage(
        key: state.pageKey,
        name: state.name,
        child: const ScanForNewDevice(),
      );
}

@TypedShellRoute<NavigationDrawerExampleRoute>(
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<ActionPageRoute>(
      path: '/',
      name: 'Actions',
    ),
    TypedGoRoute<TriggersRoute>(
      path: '/triggers',
      name: 'Triggers',
      routes: <TypedGoRoute<GoRouteData>>[
        TypedGoRoute<ActionSelectorRoute>(
          path: 'select',
          name: 'Triggers/Select Action',
        ),
      ],
    ),
    TypedGoRoute<MoreRoute>(
      path: '/more',
      name: 'More',
    ),
  ],
)
class NavigationDrawerExampleRoute extends ShellRouteData {
  const NavigationDrawerExampleRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) {
    return NavigationDrawerExample(navigator, state.matchedLocation);
  }
}

@TypedGoRoute<OnBoardingPageRoute>(
  path: '/onboarding',
  name: 'Onboarding',
)
class OnBoardingPageRoute extends GoRouteData {
  const OnBoardingPageRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) == hasCompletedOnboardingVersionToAgree) {
      return const ActionPageRoute().location;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, GoRouterState state) => const OnBoardingPage();
}

@TypedGoRoute<HtmlPageRoute>(
  path: '/viewHTML',
  name: 'viewHTML',
)
class HtmlPageRoute extends GoRouteData {
  const HtmlPageRoute({required this.$extra});

  final HtmlPageInfo $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => HtmlPage(
        htmlPageInfo: $extra,
      );
}

@TypedGoRoute<PDFPageRoute>(
  path: '/viewPDF',
  name: 'viewPDF',
)
class PDFPageRoute extends GoRouteData {
  const PDFPageRoute({required this.$extra});

  final PDFInfo $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => ViewPDF(
        pdfInfo: $extra,
      );
}

@TypedGoRoute<DirectGearControlRoute>(
  path: '/joystick',
  name: 'Direct Gear Control',
)
class DirectGearControlRoute extends GoRouteData {
  const DirectGearControlRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => const DirectGearControl();
}

@TypedGoRoute<CustomAudioRoute>(
  path: '/customAudio',
  name: 'CustomAudio',
)
class CustomAudioRoute extends GoRouteData {
  const CustomAudioRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => const CustomAudio();
}

class ActionPageRoute extends GoRouteData {
  const ActionPageRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => NoTransitionPage(child: const ActionPage(), name: state.name, key: state.pageKey);

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) < hasCompletedOnboardingVersionToAgree) {
      return const OnBoardingPageRoute().location;
    }
    return null;
  }
}

class BluetoothConsoleRoute extends GoRouteData {
  const BluetoothConsoleRoute({required this.$extra});

  final BaseStatefulDevice $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => BluetoothConsole(
        device: $extra,
      );
}

class ActionSelectorRoute extends GoRouteData {
  const ActionSelectorRoute({required this.$extra});

  final ActionSelectorInfo $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => ActionSelector(
        actionSelectorInfo: $extra,
      );
}

class DeveloperMenuRoute extends GoRouteData {
  const DeveloperMenuRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => const DeveloperMenu();
}

class DeveloperPincodeRoute extends GoRouteData {
  const DeveloperPincodeRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => const DeveloperPincode();
}

@TypedGoRoute<MarkdownViewerRoute>(
  path: '/viewMarkdown',
  name: 'viewMarkdown',
)
class MarkdownViewerRoute extends GoRouteData {
  const MarkdownViewerRoute({required this.$extra});

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  final MarkdownInfo $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => MarkdownViewer(
        markdownInfo: $extra,
      );
}

class MoreRoute extends GoRouteData {
  const MoreRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => NoTransitionPage(child: const More(), key: state.pageKey, name: state.name);
}

@TypedGoRoute<MoveListRoute>(
  path: '/moveLists',
  name: 'Sequences',
  routes: [
    TypedGoRoute<EditMoveListRoute>(
      path: 'editList',
      name: 'Sequences/Edit Sequence',
    ),
  ],
)
class MoveListRoute extends GoRouteData {
  const MoveListRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => const MoveListView();
}

class EditMoveListRoute extends GoRouteData {
  const EditMoveListRoute({required this.$extra});

  final MoveList $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => EditMoveList(moveList: $extra);
}

@TypedGoRoute<EditMoveListMoveRoute>(
  path: '/moveLists/editList/editMove',
  name: 'Sequences/Edit Sequence/Edit Move',
)
class EditMoveListMoveRoute extends GoRouteData {
  const EditMoveListMoveRoute({required this.$extra});

  final Move $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => ModalPage(
        key: state.pageKey,
        name: state.name,
        child: EditMove(
          move: $extra,
        ),
      );
}

@TypedGoRoute<OtaUpdateRoute>(
  path: '/ota',
  name: 'OTA',
)
class OtaUpdateRoute extends GoRouteData {
  const OtaUpdateRoute({required this.device});

  final String device;

  @override
  Widget build(BuildContext context, GoRouterState state) => OtaUpdate(
        device: device,
      );
}

class BulkOtaUpdateRoute extends GoRouteData {
  const BulkOtaUpdateRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const BulkOTA();
}

@TypedGoRoute<SettingsRoute>(
  path: '/settings',
  name: 'Settings',
  routes: [
    TypedGoRoute<DeveloperMenuRoute>(
      path: 'developer',
      name: 'Settings/Developer Menu',
      routes: [
        TypedGoRoute<BluetoothConsoleRoute>(
          path: 'console',
          name: 'Settings/Developer Menu/Console',
        ),
        TypedGoRoute<DeveloperPincodeRoute>(
          path: 'pin',
          name: 'Settings/Developer Menu/Pin',
        ),
        TypedGoRoute<LogsRoute>(
          path: 'log',
          name: 'Settings/Developer Menu/Logs',
        ),
        TypedGoRoute<BulkOtaUpdateRoute>(
          path: 'bulkOta',
          name: 'Settings/Developer Menu/bulkOta',
        ),
      ],
    ),
  ],
)
class SettingsRoute extends GoRouteData {
  const SettingsRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => const Settings();
}

class LogsRoute extends GoRouteData {
  const LogsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => LogarteDashboardScreen(
        logarte,
        showBackButton: true,
      );
}

class ModalPage<T> extends Page<T> {
  const ModalPage({required this.child, required super.key, required super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);

    return ModalBottomSheetRoute<T>(
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      settings: this,
      builder: (context) => child,
      isScrollControlled: true,
      isDismissible: true,
      showDragHandle: true,
      enableDrag: true,
    );
  }
}

class DialogPage<T> extends Page<T> {
  const DialogPage({required this.child, required super.key, required super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return DialogRoute(
      useSafeArea: true,
      barrierDismissible: true,
      settings: this,
      context: context,
      builder: (context) {
        return child;
      },
    );
  }
}
