

flutter pub get --no-example --enforce-lockfile
dart pub global activate intl_translation
dart pub global run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/translation_string_definitions.dart lib/l10n/*.arb
dart pub run build_runner build