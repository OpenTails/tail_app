import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/ActionRegistry.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';

class ActionPage extends ConsumerWidget {
  const ActionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Devices'),
        ),
        body: ListView(
          children: getActions(ref),
        ));
  }

  getActions(WidgetRef ref) {
    List<Card> results = [];
    for (MapEntry<ActionCategory, Set<BaseAction>> entry in ActionRegistry.getSortedActions().entries) {
      List<Widget> actionsTiles = [];
      for (BaseAction action in entry.value) {
        actionsTiles.add(Card(
          elevation: 2,
          child: SizedBox(
            height: 50,
            width: 50,
            child: Center(
              child: Text(action.name),
            ),
          ),
        ));
      }

      Card card = Card(
        child: Column(
          children: [
            Center(
              child: Text(
                entry.key.friendly,
                textScaleFactor: 1.5,
              ),
            ),
            GridView(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 125),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: actionsTiles,
            )
          ],
        ),
      );
      results.add(card);
    }
    return results;
  }
}
