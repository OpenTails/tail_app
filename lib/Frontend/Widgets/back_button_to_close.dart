import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Backend/device_registry.dart';
import '../translation_string_definitions.dart';

class BackButtonToClose extends ConsumerStatefulWidget {
  const BackButtonToClose({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BackButtonToClose> createState() => _BackButtonToCloseState();
}

class _BackButtonToCloseState extends ConsumerState<BackButtonToClose> {
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

  // ignore: avoid_positional_boolean_parameters
  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (info.currentRoute(context)!.isFirst && info.currentRoute(context)!.isCurrent) {
      if (ref.read(getAvailableGearProvider).isNotEmpty) {
        return true;
      }
      if (timer.isActive) {
        return false;
      }
      timer = Timer(const Duration(seconds: 1), () {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          /// need to set following properties for best effect of awesome_snackbar_content
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: doubleBackToClose(),
            message: '',

            /// change contentType to ContentType.success, ContentType.warning or ContentType.help for variants
            contentType: ContentType.help,
          ),
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
