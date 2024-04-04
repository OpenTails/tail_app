#!/usr/bin/env bash
set -e
set -x
if [[ "$(pwd)" == *"Scripts"* ]]; then
  cd ..
fi
flutter config --no-cli-animations
flutter pub get
flutter gen-l10n
dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intnDefs.dart lib/l10n/*.arb
flutter pub run build_runner build --delete-conflicting-outputs
flutter build apk --split-per-abi --split-debug-info=./symbols --build-number="$(git rev-list HEAD --count)"
flutter build appbundle --split-debug-info=./symbols --build-number="$(git rev-list HEAD --count)"