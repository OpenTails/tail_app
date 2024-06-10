import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logarte/logarte.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';
import 'package:tail_app/Frontend/pages/action_selector.dart';
import 'package:tail_app/Frontend/pages/custom_audio.dart';
import 'package:tail_app/Frontend/pages/developer/bluetooth_console.dart';
import 'package:tail_app/Frontend/pages/developer/developer_menu.dart';
import 'package:tail_app/Frontend/pages/developer/developer_pincode.dart';
import 'package:tail_app/Frontend/pages/direct_gear_control.dart';
import 'package:tail_app/Frontend/pages/intro.dart';
import 'package:tail_app/Frontend/pages/markdown_viewer.dart';
import 'package:tail_app/Frontend/pages/more.dart';
import 'package:tail_app/Frontend/pages/move_list.dart';
import 'package:tail_app/Frontend/pages/ota_update.dart';
import 'package:tail_app/Frontend/pages/settings.dart';
import 'package:tail_app/Frontend/pages/shell.dart';
import 'package:tail_app/Frontend/pages/triggers.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';
import 'package:tail_app/constants.dart';

import '../Backend/LoggingWrappers.dart';
import '../Backend/NavigationObserver/custom_go_router_navigation_observer.dart';
import '../main.dart';
import 'pages/actions.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();
// GoRouter configuration
final GoRouter router = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: _rootNavigatorKey,
  observers: [
    SentryNavigatorObserver(),
    CustomNavObserver(plausible),
    LogarteNavigatorObserver(logarte),
  ],
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      parentNavigatorKey: _rootNavigatorKey,
      observers: [SentryNavigatorObserver(), CustomNavObserver(plausible)],
      routes: [
        GoRoute(
            name: 'Actions',
            path: '/',
            parentNavigatorKey: _shellNavigatorKey,
            pageBuilder: (BuildContext context, GoRouterState state) => NoTransitionPage(
                  child: const ActionPage(),
                  key: state.pageKey,
                  name: 'Actions',
                ),
            redirect: (context, state) {
              if (HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) < hasCompletedOnboardingVersionToAgree) {
                return '/onboarding';
              }
              return null;
            }),
        GoRoute(
            name: 'Triggers',
            path: '/triggers',
            parentNavigatorKey: _shellNavigatorKey,
            pageBuilder: (BuildContext context, GoRouterState state) => NoTransitionPage(
                  child: const Triggers(),
                  key: state.pageKey,
                  name: 'Triggers',
                ),
            routes: [
              GoRoute(
                name: 'Triggers/Select Action',
                path: 'select',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (BuildContext context, GoRouterState state) => MaterialPage(
                  child: ActionSelector(
                    actionSelectorInfo: state.extra! as ActionSelectorInfo,
                  ),
                  key: state.pageKey,
                  name: 'Triggers/Select Action',
                ),
              ),
            ]),
        GoRoute(
          name: 'More',
          path: '/more',
          parentNavigatorKey: _shellNavigatorKey,
          routes: [
            GoRoute(
              name: 'More/viewPDF',
              path: 'viewPDF',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) => ViewPDF(asset: state.extra! as Uint8List),
            ),
            GoRoute(
              name: 'More/viewMarkdown',
              path: 'viewMarkdown',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) {
                return MarkdownViewer(markdownInfo: state.extra! as MarkdownInfo);
              },
            ),
          ],
          pageBuilder: (context, state) {
            return NoTransitionPage(
              key: state.pageKey,
              name: 'More',
              child: const More(),
            );
          },
        ),
      ],
      pageBuilder: (BuildContext context, GoRouterState state, Widget child) => NoTransitionPage(
        child: NavigationDrawerExample(child, state.matchedLocation),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      name: 'Direct Gear Control',
      path: '/joystick',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        return MaterialPage(
          key: state.pageKey,
          name: 'Direct Gear Control',
          child: const DirectGearControl(),
        );
      },
    ),
    GoRoute(
      name: 'OTA',
      path: '/ota',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (BuildContext context, GoRouterState state) {
        String device = state.extra! as String;
        return MaterialPage(
          child: OtaUpdate(device: device),
          key: state.pageKey,
          name: 'OTA',
        );
      },
      redirect: (context, state) {
        if (state.extra == null) {
          return '/';
        }
        return null;
      },
    ),
    GoRoute(
      name: 'Onboarding',
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (BuildContext context, GoRouterState state) {
        return MaterialPage(
          child: const OnBoardingPage(),
          key: state.pageKey,
          name: 'Onboarding',
        );
      },
      redirect: (context, state) {
        if (HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) == hasCompletedOnboardingVersionToAgree) {
          return '/';
        }
        return null;
      },
    ),
    GoRoute(
      name: 'CustomAudio',
      path: '/customAudio',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (BuildContext context, GoRouterState state) => MaterialPage(
        key: state.pageKey,
        name: 'CustomAudio',
        child: const CustomAudio(),
      ),
    ),
    GoRoute(
      name: 'Sequences',
      path: '/moveLists',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (BuildContext context, GoRouterState state) => MaterialPage(
        key: state.pageKey,
        name: 'Sequences',
        child: const MoveListView(),
      ),
      routes: [
        GoRoute(
          name: 'Sequences/Edit Sequence',
          path: 'editMoveList',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            return MaterialPage(
              key: state.pageKey,
              name: 'Sequences/Edit Sequence',
              child: const EditMoveList(),
            );
          },
        ),
      ],
    ),
    GoRoute(
      name: 'Settings',
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        return MaterialPage(
          key: state.pageKey,
          name: 'Settings',
          child: const Settings(),
        );
      },
      routes: [
        GoRoute(
          name: 'Settings/Developer Menu',
          path: 'developer',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (BuildContext context, GoRouterState state) => const DeveloperMenu(),
          routes: [
            GoRoute(
              name: 'Settings/Developer Menu/Console',
              path: 'console',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) => BluetoothConsole(device: state.extra! as BaseStatefulDevice),
            ),
            GoRoute(
              name: 'Settings/Developer Menu/Logs',
              path: 'logs',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) => LogarteDashboardScreen(
                logarte,
                showBackButton: true,
              ),
            ),
            GoRoute(
              name: 'Settings/Developer Menu/Pin',
              path: 'pin',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) => const DeveloperPincode(),
            )
          ],
        ),
      ],
    ),
  ],
);
