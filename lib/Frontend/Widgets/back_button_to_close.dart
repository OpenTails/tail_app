import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: BackButtonListener(
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            showSnackbar();
          },
          child: NavigatorPopHandler(
            enabled: true,
            onPop: showSnackbar,
            child: widget.child,
          ),
        ),
        onBackButtonPressed: () async {
          if (Navigator.canPop(context)) {
            return false;
          }
          showSnackbar();
          return true;
        },
      ),
      onWillPop: () => Future.value(false),
    );
  }

  void showSnackbar() {
    if (timer.isActive) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
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
  }
}
