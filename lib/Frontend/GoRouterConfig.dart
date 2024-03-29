import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Frontend/pages/DirectGearControl.dart';
import 'package:tail_app/Frontend/pages/Shell.dart';
import 'package:tail_app/Frontend/pages/developer/bluetooth_console.dart';
import 'package:tail_app/Frontend/pages/developer/developer_menu.dart';
import 'package:tail_app/Frontend/pages/intro.dart';
import 'package:tail_app/Frontend/pages/more.dart';
import 'package:tail_app/Frontend/pages/move_list.dart';
import 'package:tail_app/Frontend/pages/ota_update.dart';
import 'package:tail_app/Frontend/pages/settings.dart';
import 'package:tail_app/Frontend/pages/triggers.dart';
import 'package:tail_app/Frontend/pages/view_pdf.dart';
import 'package:tail_app/constants.dart';

import '../Backend/NavigationObserver/CustomNavObserver.dart';
import '../main.dart';
import 'pages/Actions.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();
// GoRouter configuration
final GoRouter router = GoRouter(
  debugLogDiagnostics: kDebugMode,
  navigatorKey: _rootNavigatorKey,
  observers: [SentryNavigatorObserver(), CustomNavObserver(plausible)],
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
            pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
                  child: const ActionPage(),
                  key: state.pageKey,
                  name: 'Actions',
                  transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                    return FadeTransition(
                      opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
                      child: child,
                    );
                  },
                ),
            redirect: (context, state) {
              if (!SentryHive.box(settings).get(hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault)) {
                return '/onboarding';
              }
              return null;
            }),
        GoRoute(
          name: 'Triggers',
          path: '/triggers',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
            child: const Triggers(),
            key: state.pageKey,
            name: 'Triggers',
            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
              return FadeTransition(
                opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          name: 'Direct Gear Control',
          path: '/joystick',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              name: 'Direct Gear Control',
              child: const DirectGearControl(),
              transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          name: 'More',
          path: '/more',
          parentNavigatorKey: _shellNavigatorKey,
          routes: [
            GoRoute(
              name: 'More/viewPDF',
              path: 'viewPDF',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) => ViewPDF(assetPath: state.extra! as String),
            ),
          ],
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              name: 'More',
              child: More(),
              transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
                return FadeTransition(
                  opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
                  child: child,
                );
              },
            );
          },
        ),
      ],
      pageBuilder: (BuildContext context, GoRouterState state, Widget child) => CustomTransitionPage(
        child: NavigationDrawerExample(child, state.matchedLocation),
        key: state.pageKey,
        transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
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
        if (SentryHive.box(settings).get(hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault)) {
          return '/';
        }
        return null;
      },
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
        if (kDebugMode) ...[
          GoRoute(name: 'Settings/Developer Menu', path: 'developer', parentNavigatorKey: _rootNavigatorKey, builder: (BuildContext context, GoRouterState state) => const DeveloperMenu(), routes: [
            GoRoute(
              name: 'Settings/Developer Menu/Console',
              path: 'console',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) => BluetoothConsole(device: state.extra! as BaseStatefulDevice),
            ),
          ]),
        ]
      ],
    ),
  ],
);
