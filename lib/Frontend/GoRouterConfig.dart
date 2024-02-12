import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:plausible_analytics/navigator_observer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Frontend/pages/DirectGearControl.dart';
import 'package:tail_app/Frontend/pages/Shell.dart';
import 'package:tail_app/Frontend/pages/developer/developer_menu.dart';
import 'package:tail_app/Frontend/pages/move_list.dart';
import 'package:tail_app/Frontend/pages/settings.dart';
import 'package:tail_app/Frontend/pages/triggers.dart';

import '../main.dart';
import 'pages/Actions.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

// GoRouter configuration
final GoRouter router = GoRouter(
  debugLogDiagnostics: kDebugMode,
  navigatorKey: _rootNavigatorKey,
  observers: [
    SentryNavigatorObserver(),
    PlausibleNavigatorObserver(plausible),
  ],
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      routes: [
        GoRoute(
          name: 'Actions',
          path: '/',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
            child: const ActionPage(),
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
          name: 'Triggers',
          path: '/triggers',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
            child: const Triggers(),
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
          name: 'Sequences',
          path: '/moveLists',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (BuildContext context, GoRouterState state) => CustomTransitionPage(
            key: state.pageKey,
            child: const MoveListView(),
            transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
          routes: [
            GoRoute(
              name: 'Edit Sequence',
              path: 'editMoveList',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) {
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: const EditMoveList(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    // Change the opacity of the screen using a Curve based on the the animation's
                    // value
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                );
              },
            ),
          ],
        ),
        GoRoute(
          name: 'Direct Gear Control',
          path: '/joystick',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const DirectGearControl(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Change the opacity of the screen using a Curve based on the the animation's
                // value
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          name: 'Settings',
          path: '/settings',
          parentNavigatorKey: _shellNavigatorKey,
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const Settings(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // Change the opacity of the screen using a Curve based on the the animation's
                // value
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
          routes: [
            if (kDebugMode) ...[
              GoRoute(
                name: 'Developer Menu',
                path: 'developer',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (BuildContext context, GoRouterState state) => const DeveloperMenu(),
              )
            ]
          ],
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
  ],
);
