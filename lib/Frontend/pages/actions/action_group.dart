import 'package:flutter/material.dart';

import '../../../Backend/Action/action_list_category.dart';
import 'actions.dart';

class ActionGroup extends StatelessWidget {
  const ActionGroup({
    super.key,
    required this.actionListCategory,
    required this.largerCards,
  });

  final ActionListCategory actionListCategory;
  final bool largerCards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        Center(
          child: Text(
            actionListCategory.translated(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: largerCards ? 250 : 125,
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: actionListCategory.actions.length,
          itemBuilder: (BuildContext context, int actionIndex) {
            return ActionCard(
              action: actionListCategory.actions.toList()[actionIndex],
              largerCards: largerCards,
            );
          },
        ),
      ],
    );
  }
}
