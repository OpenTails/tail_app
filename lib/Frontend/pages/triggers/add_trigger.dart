import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/triggers/sensor_definition_list.dart';
import 'package:tail_app/constants.dart';
import 'package:uuid/uuid.dart';

import '../../../Backend/analytics.dart';
import '../../../Backend/triggers/stored_triggers.dart';
import '../../../Backend/triggers/trigger.dart';
import '../../Widgets/fix_dialog_listview_scrolling.dart';
import '../../Widgets/uwu_text.dart';
import '../../translation_string_definitions.dart';

class AddTrigger extends StatelessWidget {
  const AddTrigger({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
          },
          label: Text(convertToUwU(cancel())),
          icon: Icon(Symbols.cancel),
        ),
      ],
      title: Text(convertToUwU(triggersSelectLabel())),
      content: FixDialogListviewScrolling(
        child: FutureBuilder(
          future: TriggerDefinitionList.getSupported(),
          builder: (context, snapshot) {
            // required to hide pop-in from futurebuilder
            return AnimatedCrossFade(
              duration: animationTransitionDuration,
              crossFadeState: snapshot.hasData
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Center(child: CircularProgressIndicator()),
              secondChild: snapshot.hasData
                  ? ListView(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: snapshot.data!
                          .map(
                            (e) => ListTile(
                              title: Text(convertToUwU(e.name())),
                              leading: e.icon,
                              subtitle: Text(convertToUwU(e.description())),
                              onTap: () {
                                Trigger trigger = Trigger.trigDef(
                                  e,
                                  const Uuid().v4(),
                                );
                                TriggerList.instance.add(trigger);
                                analyticsEvent(
                                  name: "Add Trigger",
                                  props: {
                                    "Trigger Type": Intl.withLocale(
                                      'en',
                                      () => e.name(),
                                    ),
                                  },
                                );
                                Navigator.of(context).pop();
                              },
                            ),
                          )
                          .toList(),
                    )
                  : Container(),
            );
          },
        ),
      ),
    );
  }
}
