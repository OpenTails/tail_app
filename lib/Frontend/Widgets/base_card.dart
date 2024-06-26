import 'package:flutter/material.dart';

class BaseCard extends StatelessWidget {
  const BaseCard({required this.child, super.key, this.elevation = 1, this.color});

  final double elevation;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: color,
          elevation: elevation,
          child: child,
        ),
      ),
    );
  }
}
