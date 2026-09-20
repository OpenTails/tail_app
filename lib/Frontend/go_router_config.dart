import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logarte/logarte.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Frontend/pages/actions/reorder_actions.dart';
import 'package:tail_app/Frontend/pages/triggers/add_trigger.dart';
import 'package:tail_app/Frontend/pages/triggers/trigger_edit.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';

import '../Backend/Action/base_action.dart';
import '../Backend/Device/stateful/connected_gear.dart';
import '../Backend/logging_wrappers.dart';
import '../Backend/move_lists_backend.dart';
import '../Backend/analytics.dart';
import '../constants.dart';
import 'Widgets/color_picker_dialog.dart';
import 'Widgets/manage_gear.dart';
import 'Widgets/pincode_dialog.dart';
import 'Widgets/scan_for_new_device.dart';
import 'pages/action_selector.dart';
import 'pages/actions/actions.dart';
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
import 'pages/triggers/triggers.dart';

part 'go_router_config.g.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();
// GoRouter configuration
final GoRouter router = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: rootNavigatorKey,
  observers: [SentryNavigatorObserver(), LogarteNavigatorObserver(logarte)],
  redirect: (context, state) async {
    String name = state.uri.path;
    if (name.isNotEmpty) {
      analyticsEvent(name: "Pageview", props: {"Page": name.toString()});
    }
    return null;
  },
  routes: $appRoutes,
);

class TriggersRoute extends GoRouteData with $TriggersRoute {
  const TriggersRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      NoTransitionPage(
        key: state.pageKey,
        name: state.name,
        child: const Triggers(),
      );
}

@TypedGoRoute<AddTriggerDialogRoute>(path: '/triggers/add', name: 'Add Trigger')
class AddTriggerDialogRoute extends GoRouteData with $AddTriggerDialogRoute {
  const AddTriggerDialogRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      DialogPage(key: state.pageKey, name: state.name, child: AddTrigger());
}

@TypedGoRoute<TriggersEditRoute>(path: '/triggers/edit', name: 'Triggers/Edit')
class TriggersEditRoute extends GoRouteData with $TriggersEditRoute {
  const TriggersEditRoute({required this.uuid});

  final String uuid;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => ModalPage(
    key: state.pageKey,
    name: state.name,
    child: TriggerEdit(uuid: uuid),
  );
}

@TypedGoRoute<ManageGearRoute>(path: '/manageGear', name: 'Manage Gear')
class ManageGearRoute extends GoRouteData with $ManageGearRoute {
  const ManageGearRoute({required this.btMac});

  final String btMac;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => ModalPage(
    key: state.pageKey,
    name: state.name,
    child: ManageGear(btMac: btMac),
  );
}

@TypedGoRoute<ColorPickerRoute>(path: '/color', name: 'Color Picker')
class ColorPickerRoute extends GoRouteData with $ColorPickerRoute {
  const ColorPickerRoute({required this.defaultColor});

  final int defaultColor;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => DialogPage(
    key: state.pageKey,
    name: state.name,
    child: ColorPickerDialog(defaultColor: defaultColor),
  );
}

@TypedGoRoute<PinCodeRoute>(path: '/pincode', name: 'Pin Code')
class PinCodeRoute extends GoRouteData with $PinCodeRoute {
  const PinCodeRoute({required this.pin});

  final String pin;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => DialogPage(
    key: state.pageKey,
    name: state.name,
    child: PincodeDialog(pin: pin),
  );
}

@TypedGoRoute<ScanForGearRoute>(path: '/scan', name: 'Scan for new devices')
class ScanForGearRoute extends GoRouteData with $ScanForGearRoute {
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
    TypedGoRoute<ActionPageRoute>(path: '/', name: 'Actions'),
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
    TypedGoRoute<MoreRoute>(path: '/more', name: 'More'),
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

@TypedGoRoute<OnBoardingPageRoute>(path: '/onboarding', name: 'Onboarding')
class OnBoardingPageRoute extends GoRouteData with $OnBoardingPageRoute {
  const OnBoardingPageRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (HiveProxy.getOrDefault(
          settings,
          hasCompletedOnboarding,
          defaultValue: hasCompletedOnboardingDefault,
        ) ==
        hasCompletedOnboardingVersionToAgree) {
      return const ActionPageRoute().location;
    }
    return null;
  }

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: const OnBoardingPage(),
        name: state.name,
        key: state.pageKey,
      );
}

@TypedGoRoute<HtmlPageRoute>(path: '/viewHTML', name: 'viewHTML')
class HtmlPageRoute extends GoRouteData with $HtmlPageRoute {
  const HtmlPageRoute({required this.$extra});

  final HtmlPageInfo $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: HtmlPage(htmlPageInfo: $extra),
        name: state.name,
        key: state.pageKey,
      );
}

@TypedGoRoute<PDFPageRoute>(path: '/viewPDF', name: 'viewPDF')
class PDFPageRoute extends GoRouteData with $PDFPageRoute {
  const PDFPageRoute({required this.$extra});

  final PDFInfo $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: ViewPDF(pdfInfo: $extra),
        name: state.name,
        key: state.pageKey,
      );
}

@TypedGoRoute<DirectGearControlRoute>(
  path: '/joystick',
  name: 'Direct Gear Control',
)
class DirectGearControlRoute extends GoRouteData with $DirectGearControlRoute {
  const DirectGearControlRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: const DirectGearControl(),
        name: state.name,
        key: state.pageKey,
      );
}

@TypedGoRoute<CustomAudioRoute>(path: '/customAudio', name: 'CustomAudio')
class CustomAudioRoute extends GoRouteData with $CustomAudioRoute {
  const CustomAudioRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: const CustomAudio(),
        name: state.name,
        key: state.pageKey,
      );
}

class ActionPageRoute extends GoRouteData with $ActionPageRoute {
  const ActionPageRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      NoTransitionPage(
        child: const ActionPage(),
        name: state.name,
        key: state.pageKey,
      );

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    if (HiveProxy.getOrDefault(
          settings,
          hasCompletedOnboarding,
          defaultValue: hasCompletedOnboardingDefault,
        ) <
        hasCompletedOnboardingVersionToAgree) {
      return const OnBoardingPageRoute().location;
    }
    return null;
  }
}

@TypedGoRoute<ActionsReorderDialogRoute>(
  path: '/actions/reorder',
  name: 'Reorder Actions',
)
class ActionsReorderDialogRoute extends GoRouteData
    with $ActionsReorderDialogRoute {
  const ActionsReorderDialogRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      DialogPage(key: state.pageKey, name: state.name, child: ReorderActions());
}

class BluetoothConsoleRoute extends GoRouteData with $BluetoothConsoleRoute {
  const BluetoothConsoleRoute({required this.$extra});

  final StatefulDevice $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: BluetoothConsole(device: $extra),
        name: state.name,
        key: state.pageKey,
      );
}

class ActionSelectorRoute extends GoRouteData with $ActionSelectorRoute {
  const ActionSelectorRoute({required this.$extra});

  final ActionSelectorInfo $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: ActionSelector(actionSelectorInfo: $extra),
        name: state.name,
        key: state.pageKey,
      );
}

class DeveloperMenuRoute extends GoRouteData with $DeveloperMenuRoute {
  const DeveloperMenuRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: const DeveloperMenu(),
        name: state.name,
        key: state.pageKey,
      );
}

class DeveloperPincodeRoute extends GoRouteData with $DeveloperPincodeRoute {
  const DeveloperPincodeRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: const DeveloperPincode(),
        name: state.name,
        key: state.pageKey,
      );
}

@TypedGoRoute<MarkdownViewerRoute>(path: '/viewMarkdown', name: 'viewMarkdown')
class MarkdownViewerRoute extends GoRouteData with $MarkdownViewerRoute {
  const MarkdownViewerRoute({required this.$extra});

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  final MarkdownInfo $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: MarkdownViewer(markdownInfo: $extra),
        name: state.name,
        key: state.pageKey,
      );
}

class MoreRoute extends GoRouteData with $MoreRoute {
  const MoreRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      NoTransitionPage(
        child: const More(),
        key: state.pageKey,
        name: state.name,
      );
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
class MoveListRoute extends GoRouteData with $MoveListRoute {
  const MoveListRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: const MoveListView(),
        name: state.name,
        key: state.pageKey,
      );
}

class EditMoveListRoute extends GoRouteData with $EditMoveListRoute {
  const EditMoveListRoute({required this.$extra});

  final MoveList $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: EditMoveList(moveList: $extra),
        name: state.name,
        key: state.pageKey,
      );
}

@TypedGoRoute<EditMoveListMoveRoute>(
  path: '/moveLists/editList/editMove',
  name: 'Sequences/Edit Sequence/Edit Move',
)
class EditMoveListMoveRoute extends GoRouteData with $EditMoveListMoveRoute {
  const EditMoveListMoveRoute({required this.$extra});

  final Move $extra;
  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => ModalPage(
    key: state.pageKey,
    name: state.name,
    child: EditMove(move: $extra),
  );
}

@TypedGoRoute<OtaUpdateRoute>(path: '/ota', name: 'OTA')
class OtaUpdateRoute extends GoRouteData with $OtaUpdateRoute {
  const OtaUpdateRoute({required this.device});

  final String device;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: OtaUpdate(deviceMac: device),
        name: state.name,
        key: state.pageKey,
      );
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
      ],
    ),
  ],
)
class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: const Settings(),
        name: state.name,
        key: state.pageKey,
      );
}

class LogsRoute extends GoRouteData with $LogsRoute {
  const LogsRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      MaterialPage(
        child: LogarteDashboardScreen(logarte),
        name: state.name,
        key: state.pageKey,
      );
}

class ModalPage<T> extends Page<T> {
  const ModalPage({
    required this.child,
    required super.key,
    required super.name,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );

    return ModalBottomSheetRoute<T>(
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
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
  const DialogPage({
    required this.child,
    required super.key,
    required super.name,
  });

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
