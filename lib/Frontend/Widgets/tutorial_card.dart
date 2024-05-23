import 'package:flutter/material.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../../constants.dart';

class PageInfoCard extends StatelessWidget {
  final String text;

  const PageInfoCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    bool show = !SentryHive.box(settings).get(hideTutorialCards, defaultValue: hideTutorialCardsDefault);
    return show
        ? Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(text),
          ),
        ),
      ),
    )
        : Container();
  }
}