import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../Backend/sensors.dart';
import '../translation_string_definitions.dart';

class TriggerSelect extends ConsumerStatefulWidget {
  const TriggerSelect({super.key});

  @override
  ConsumerState<TriggerSelect> createState() => _TriggerSelectState();
}

class _TriggerSelectState extends ConsumerState<TriggerSelect> {
  TriggerDefinition? triggerDefinition;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(myInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    super.dispose();
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(triggersSelectLabel()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ref
              .watch(triggerDefinitionListProvider)
              .map((TriggerDefinition e) => ListTile(
                    title: Text(e.name),
                    leading: Radio<TriggerDefinition>(
                      value: e,
                      groupValue: triggerDefinition,
                      onChanged: (TriggerDefinition? value) {
                        setState(
                          () {
                            triggerDefinition = value;
                          },
                        );
                      },
                    ),
                    trailing: e.icon,
                    subtitle: Text(e.description),
                  ))
              .toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(cancel()),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, triggerDefinition);
          },
          child: Text(ok()),
        ),
      ],
    );
  }
}
