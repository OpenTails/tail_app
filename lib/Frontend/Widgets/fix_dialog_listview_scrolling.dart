import 'package:flutter/material.dart';

class FixDialogListviewScrolling extends StatelessWidget {
  const FixDialogListviewScrolling({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,

      child: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
        ),
      ),
    );
  }
}
