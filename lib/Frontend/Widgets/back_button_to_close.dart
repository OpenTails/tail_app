import 'dart:async';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';

class BackButtonToClose extends StatefulWidget {
  const BackButtonToClose({required this.child, super.key});

  final Widget child;

  @override
  _BackButtonToCloseState createState() => _BackButtonToCloseState();
}

class _BackButtonToCloseState extends State<BackButtonToClose> {
  Timer timer = Timer(Duration.zero, () {});

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(myInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    super.dispose();
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (info.currentRoute(context)!.isFirst && info.currentRoute(context)!.isCurrent) {
      if (timer.isActive) {
        return false;
      }
      timer = Timer(const Duration(seconds: 1), () {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press again to exit 🎉'),
        ),
      );
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
