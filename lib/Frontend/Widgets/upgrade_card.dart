import 'package:flutter/material.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:upgrader/upgrader.dart';

import '../translation_string_definitions.dart';
import 'base_card.dart';

class CustomUpgradeCard extends UpgradeCard {
  CustomUpgradeCard({super.key});

  @override
  UpgradeCardState createState() => CustomUpgradeCardState();
}

class CustomUpgradeCardState extends UpgradeCardState {
  @override
  Widget buildUpgradeCard(BuildContext context, Key? key) {
    return BaseCard(
      color: ColorScheme.of(context).secondary,
      child: ListTile(
        onTap: () => onUserUpdated(),
        title: Center(
          child: Text(
            convertToUwU(homeUpdateAvailable()),
            textAlign: TextAlign.center,
            style: TextTheme.of(
              context,
            ).titleMedium!.copyWith(color: ColorScheme.of(context).onSecondary),
          ),
        ),
      ),
    );
  }
}
