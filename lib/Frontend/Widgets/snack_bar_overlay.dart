import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'snack_bar_overlay.g.dart';

@Riverpod()
class SnackbarStream extends _$SnackbarStream {
  StreamController<AwesomeSnackbarContent> streamController = StreamController();

  @override
  Stream<AwesomeSnackbarContent> build() => streamController.stream;

  void add(AwesomeSnackbarContent content) => streamController.add(content);
}

class SnackBarOverlay extends ConsumerWidget {
  const SnackBarOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<AwesomeSnackbarContent> value = ref.watch(snackbarStreamProvider);
    if (value.hasValue) {
      Future(
        () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.transparent,
                content: value.value!,
              ),
            );
        },
      );
    }
    return child;
  }
}
