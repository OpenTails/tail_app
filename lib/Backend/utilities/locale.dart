import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:universal_io/io.dart';

import '../../constants.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/messages_all_locales.dart';
import '../logging_wrappers.dart';

class UserLocale with ChangeNotifier {
  static final UserLocale instance = UserLocale._internal();
  final Logger _logger = Logger("Locale");

  UserLocale._internal() {
    Hive.box(settings).listenable(keys: [selectedLocale, uwuTextEnabled])
      ..removeListener(_notify)
      ..addListener(_notify);
  }

  void _notify() {
    get();
    notifyListeners();
  }

  Future<String> get() async {
    final String defaultLocale =
        Platform.localeName; // Returns locale string in the form 'en_US'

    String userSelectedLocale = HiveProxy.getOrDefault(
      settings,
      selectedLocale,
      defaultValue: "",
    );
    if (userSelectedLocale.isEmpty) {
      _logger.info("Using system locale: $defaultLocale");
      await setLocale(defaultLocale);
      return defaultLocale;
    }
    String? locale = AppLocalizations.supportedLocales
        .where((element) => element.toLanguageTag() == userSelectedLocale)
        .map((e) => e.toLanguageTag())
        .firstOrNull;
    if (locale == null || locale.isEmpty) {
      locale = defaultLocale;

      //log to sentry
      _logger.severe(
        "Using system locale: $defaultLocale. User set locale "
        "$userSelectedLocale is not available",
      );
    } else {
      _logger.info("Using user locale: $locale");
    }
    await setLocale(locale);
    return locale;
  }

  Future<void> setLocale(String locale) async {
    bool success = await initializeMessages(locale);
    if (!success) {
      _logger.warning("Unable to set locale $locale");
    }
    Intl.defaultLocale = locale;
  }
}
