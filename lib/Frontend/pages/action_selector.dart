import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../Backend/Definitions/Action/base_action.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/action_registry.dart';
import '../intn_defs.dart';

class ActionSelector extends ConsumerStatefulWidget {
  const ActionSelector({super.key, required this.deviceType});

  final Set<DeviceType> deviceType;

  @override
  ConsumerState<ActionSelector> createState() => _ActionSelectorState();
}

class _ActionSelectorState extends ConsumerState<ActionSelector> {
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
    Navigator.of(context).pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Map<ActionCategory, Set<BaseAction>> actionsCatMap = ref.read(getAllActionsProvider(widget.deviceType));
    List<ActionCategory> catList = actionsCatMap.keys.toList();
    return Scaffold(
      primary: true,
      appBar: AppBar(
        title: Text(actionsSelectScreen()),
        actions: [
          IconButton(
            onPressed: () => context.pop(true),
            icon: const Icon(Icons.clear),
            tooltip: triggersSelectClearLabel(),
          )
        ],
      ),
      body: ListView.builder(
        primary: true,
        itemCount: catList.length,
        itemBuilder: (BuildContext context, int categoryIndex) {
          List<BaseAction> actionsForCat = actionsCatMap.values.toList()[categoryIndex].toList();
          return Column(
            children: [
              Center(
                child: Text(
                  catList[categoryIndex].friendly,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 125),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: actionsForCat.length,
                itemBuilder: (BuildContext context, int actionIndex) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, actionsForCat[actionIndex]),
                      child: SizedBox(
                        height: 50,
                        width: 50,
                        child: Center(
                          child: Text(actionsForCat[actionIndex].name, semanticsLabel: actionsForCat[actionIndex].name, overflow: TextOverflow.fade, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  );
                },
              )
            ],
          );
        },
      ),
    );
  }
}
