import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../Backend/Action/action_registry.dart';
import '../../../Backend/Action/base_action.dart';
import '../../../Backend/Bluetooth/known_devices.dart';
import '../../../Backend/Device/stateful/connected_gear.dart';
import '../../../Backend/triggers/sensor_definition_action_definition.dart';
import '../../../Backend/triggers/stored_triggers.dart';
import '../../../Backend/triggers/trigger.dart';
import '../../../Backend/triggers/trigger_action.dart';
import '../../../Backend/utilities/developer_options_helpers.dart';
import '../../../constants.dart';
import '../../Widgets/uwu_text.dart';
import '../../translation_string_definitions.dart';
import '../action_selector.dart';

class TriggerActionListTile extends StatefulWidget {
  const TriggerActionListTile({
    super.key,
    required this.trigger,
    required this.triggerAction,
  });

  final Trigger trigger;
  final TriggerAction triggerAction;

  @override
  State<TriggerActionListTile> createState() => _TriggerActionListTileState();
}

class _TriggerActionListTileState extends State<TriggerActionListTile> {
  TriggerActionDef? triggerActionDef;
  AnimationController? _controller;
  int lastTriggerActionStreamValue = 0;

  @override
  void initState() {
    super.initState();
    // Will fail for existing stored data if a
    triggerActionDef = widget
        .trigger
        .triggerDefinition!
        .triggerActionDefinitions
        .where((element) => widget.triggerAction.uuid == element.uuid)
        .first;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: triggerActionDef!.icon != null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [triggerActionDef!.icon!],
            )
          : Text(convertToUwU(triggerActionDef!.translated())),
      subtitle: AnimatedCrossFade(
        duration: animationTransitionDuration,
        secondChild: StreamBuilder(
          stream: widget.triggerAction.moveTriggeredStream,
          builder: (context, asyncSnapshot) {
            if (asyncSnapshot.data != null &&
                widget.triggerAction.isActive &&
                asyncSnapshot.data != lastTriggerActionStreamValue) {
              lastTriggerActionStreamValue = asyncSnapshot.data!;
              if (_controller?.isAnimating == true) {
                _controller?.reset();
              }
              _controller?.forward().whenComplete(() {
                if (context.mounted) {
                  _controller?.reset();
                }
              });
            }
            return Flash(
              manualTrigger: true,
              controller: (controller) => _controller = controller,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                tween: Tween<double>(
                  begin: 0,
                  end: widget.triggerAction.isActiveProgress,
                ),
                builder: (context, value, _) =>
                    LinearProgressIndicator(value: value),
              ),
            );
          },
        ),
        firstChild: Builder(
          builder: (context) {
            return ListenableBuilder(
              listenable: KnownDevices.instance,
              builder: (context, child) {
                String text = "";
                Iterable<StatefulDevice> knownDevices =
                    KnownDevices.instance.state.values;
                for (String actionUUID in widget.triggerAction.actions) {
                  BaseAction? baseAction = ActionRegistry.getActionFromUUID(
                    actionUUID,
                  );
                  if (baseAction != null &&
                      (knownDevices.isEmpty ||
                          knownDevices
                              .where(
                                (element) => baseAction.deviceCategory.contains(
                                  element.deviceDefinition.deviceType,
                                ),
                              )
                              .isNotEmpty)) {
                    if (text.isNotEmpty) {
                      text += ', ';
                    }
                    text += baseAction.name;
                  }
                }
                return Text(
                  convertToUwU(text.isNotEmpty ? text : triggerActionNotSet()),
                );
              },
            );
          },
        ),
        crossFadeState: !widget.triggerAction.isActive
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
      ),
      leading: isDeveloperEnabled
          ? IconButton(
              onPressed: () {
                widget.trigger.triggerDefinition!.sendCommands(
                  triggerActionDef!.name,
                );
              },
              tooltip: "Run Action (Debug)",
              icon: Icon(Symbols.play_arrow),
            )
          : null,
      trailing: IconButton(
        tooltip: actionsSelectScreen(),
        icon: const Icon(Symbols.edit),
        onPressed: () async {
          List<BaseAction>? result = await showDialog(
            useRootNavigator: true,
            barrierDismissible: true,
            barrierColor: Theme.of(context).canvasColor,
            context: context,
            builder: (BuildContext context) {
              return Dialog.fullscreen(
                backgroundColor: Theme.of(context).canvasColor,
                child: ActionSelector(
                  actionSelectorInfo: ActionSelectorInfo(
                    selectedActions: widget.triggerAction.actions
                        .map((e) => ActionRegistry.getActionFromUUID(e))
                        .nonNulls
                        .toList(),
                  ),
                ),
              );
            },
          );
          if (result != null) {
            setState(() {
              widget.triggerAction.actions = result
                  .map((element) => element.uuid)
                  .toList();
              TriggerList.instance.store();
            });
          }
        },
      ),
    );
  }
}
