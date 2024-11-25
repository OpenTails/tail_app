import 'package:flutter/material.dart';

import '../translation_string_definitions.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        FilledButton(onPressed: () {}, child: Text("Favorite Actions")),
        FilledButton(onPressed: () {}, child: Text(homePage())),
        FilledButton(onPressed: () {}, child: Text(triggersPage())),
        FilledButton(onPressed: () {}, child: Text("Gear")),
      ],
    );
  }
}
