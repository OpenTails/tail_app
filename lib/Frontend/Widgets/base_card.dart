import 'package:flutter/material.dart';

class BaseCard extends StatelessWidget {
  const BaseCard({super.key, required this.child, this.elevation = 1, this.color});

  final double elevation;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          color: color,
          elevation: elevation,
          child: child,
        ),
      ),
    );
  }
}
