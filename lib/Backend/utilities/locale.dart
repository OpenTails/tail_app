import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:intl/intl.dart';

import '../../Frontend/utils.dart';
import '../../constants.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages_all_locales.dart';
import '../logging_wrappers.dart';

class UserLocale with ChangeNotifier {
  static final UserLocale instance = UserLocale._internal();

  UserLocale._internal() {
    Hive.box(settings).listenable(keys: [selectedLocale, uwuTextEnabled])
      ..removeListener(_notify)
      ..addListener(_notify);
  }

  void _notify() {
    notifyListeners();
  }

  Future<String> get() async {
    final String defaultLocale =
        platform.localeName; // Returns locale string in the form 'en_US'

    String locale =
        AppLocalizations.supportedLocales
            .where(
              (element) =>
                  element.toLanguageTag() ==
                  HiveProxy.getOrDefault(
                    settings,
                    selectedLocale,
                    defaultValue: "",
                  ),
            )
            .map((e) => e.toLanguageTag())
            .firstOrNull ??
        defaultLocale;

    await initializeMessages(locale);
    Intl.defaultLocale = locale;
    return locale;
  }
}
