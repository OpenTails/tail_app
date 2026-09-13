import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tail_app/Backend/Action/action_list_category.dart';
import 'package:tail_app/Backend/Action/action_registry.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/constants.dart';

import '../../translation_string_definitions.dart';

class ReorderActions extends StatefulWidget {
  const ReorderActions({Key? key}) : super(key: key);

  @override
  _ReorderActionsState createState() => _ReorderActionsState();
}

class _ReorderActionsState extends State<ReorderActions> {
  List<ActionListCategory> actionListCategories = [];
  List<String> sortOrder = [];

  @override
  void initState() {
    actionListCategories = GetActions.instance
        .getActionCategories(includeEmpty: true, onlyConnected: false)
        .toList();
    sortOrder = HiveProxy.getOrDefault(
      settings,
      actionsSortOrder,
      defaultValue: actionsSortOrderDefault,
    );
    //Handle categories missing from the stored sortOrder
    sortOrder.addAll(
      actionListCategories
          .map((e) => e.name)
          .toSet()
          .difference(sortOrder.toSet()),
    );
    actionListCategories = GetActions.instance.sortActionListCategories(
      actionListCategories: actionListCategories,
      sortOrder: sortOrder,
    );
    sortOrder = sortOrder.toSet().toList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(convertToUwU(actionsReorderButtonTitle())),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
          },
          label: Text(convertToUwU(ok())),
          icon: Icon(Symbols.check),
        ),
      ],
      content: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableListView(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  onReorderItem: (oldIndex, newIndex) {
                    String oldItem = sortOrder[oldIndex];
                    setState(() {
                      sortOrder.removeAt(oldIndex);
                      sortOrder.insert(newIndex, oldItem);
                      actionListCategories = GetActions.instance
                          .sortActionListCategories(
                            actionListCategories: actionListCategories,
                            sortOrder: sortOrder,
                          );
                    });
                    HiveProxy.put(settings, actionsSortOrder, sortOrder);
                  },
                  children: actionListCategories.map((actionListCategory) {
                    return ListTile(
                      key: ValueKey(actionListCategory.name),
                      title: Text(actionListCategory.translated()),
                      trailing: Icon(Symbols.drag_handle),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
