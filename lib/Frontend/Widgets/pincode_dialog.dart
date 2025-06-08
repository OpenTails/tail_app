import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../translation_string_definitions.dart';

class PincodeDialog extends StatelessWidget {
  const PincodeDialog({super.key, required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () async => await Clipboard.setData(ClipboardData(text: pin)),
          child: Text(convertToUwU(manageGearConModePincodeCopy())),
        ),
        TextButton(
          onPressed: () => context.pop(),
          child: Text(convertToUwU(ok())),
        ),
      ],
      title: Text(convertToUwU(manageGearConModePincodeTitle())),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Text(
              pin,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}
