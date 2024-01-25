import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Frontend/pages/DirectGearControl.dart';
import 'package:tail_app/Frontend/pages/Home.dart';
import 'package:tail_app/Frontend/pages/Shell.dart';
import 'package:tail_app/Frontend/pages/developer/developer_menu.dart';
import 'package:tail_app/Frontend/pages/developer/json_preview.dart';
import 'package:tail_app/Frontend/pages/move_list.dart';
import 'package:tail_app/Frontend/pages/settings.dart';
import 'package:tail_app/Frontend/pages/triggers.dart';

import 'pages/Actions.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

// GoRouter configuration
final GoRouter router = GoRouter(
  debugLogDiagnostics: true,
  navigatorKey: _rootNavigatorKey,
  observers: [SentryNavigatorObserver()],
  routes: [
    GoRoute(
      name: 'Settings',
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (BuildContext context, GoRouterState state) => const Settings(),
      routes: [
        GoRoute(
          name: 'Developer Menu',
          path: 'developer',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (BuildContext context, GoRouterState state) => const DeveloperMenu(),
          routes: [
            GoRoute(
              name: 'JSON Viewer',
              path: 'json',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (BuildContext context, GoRouterState state) => const JsonPreview(),
            )
          ],
        )
      ],
    ),
    GoRoute(
      name: 'Direct Gear Control',
      path: '/joystick',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (BuildContext context, GoRouterState state) => const DirectGearControl(),
    ),
    ShellRoute(
        navigatorKey: _shellNavigatorKey,
        routes: [
          GoRoute(
            name: 'Home',
            path: '/',
            parentNavigatorKey: _shellNavigatorKey,
            builder: (BuildContext context, GoRouterState state) => const Home(title: "Home"),
          ),
          GoRoute(
            name: 'Actions',
            path: '/actions',
            parentNavigatorKey: _shellNavigatorKey,
            builder: (BuildContext context, GoRouterState state) => const ActionPage(),
          ),
          GoRoute(
            name: 'Triggers',
            path: '/triggers',
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, GoRouterState state) => const Triggers(),
          ),
          GoRoute(
            name: 'Sequences',
            path: '/moveLists',
            parentNavigatorKey: _shellNavigatorKey,
            builder: (BuildContext context, GoRouterState state) => const MoveListView(),
            routes: [
              GoRoute(
                name: 'Edit Sequence',
                path: 'editMoveList',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const EditMoveList(),
              ),
            ],
          ),
        ],
        pageBuilder: (BuildContext context, GoRouterState state, Widget child) => NoTransitionPage(child: NavigationDrawerExample(child, state.matchedLocation))),
  ],
);
