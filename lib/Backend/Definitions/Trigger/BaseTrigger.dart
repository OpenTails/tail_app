import 'package:flutter/material.dart';

import '../Action/BaseAction.dart';


// Used internally to check if hardware/permission exists
enum TriggerCategory {
  accelerometor,
  phone_state,
  microphone,
  other
}

class BaseTrigger {
  final String name;
  final String description;
  final Icon icon;
  final TriggerCategory category;
  BaseAction? action;

  BaseTrigger(this.name, this.description, this.icon, this.category);


}