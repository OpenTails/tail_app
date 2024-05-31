import 'package:flutter/material.dart';

import '../../Backend/LoggingWrappers.dart';
import '../../constants.dart';

class PageInfoCard extends StatelessWidget {
  final String text;

  const PageInfoCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    bool show = !HiveProxy.getOrDefault(settings, hideTutorialCards, defaultValue: hideTutorialCardsDefault);
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
