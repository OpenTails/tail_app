#!/usr/bin/env bash
set -e
set -x
# We want to be in the project root folder, not the scripts folder
if [[ "$(pwd)" == *"/Scripts" ]]; then
  cd ..
fi
VERSION="$(cat VERSION)"
BUILD_NUMBER="$(git rev-list HEAD --count)"
# Gets the release tag from github if it exists (Github Actions)
# Assumes tags start with V
if [[ -v RELEASE_TAG ]] && [[ -n $RELEASE_TAG ]]; then
  TAG="${RELEASE_TAG,,}"
  VERSION="${TAG//"v"}"
fi
flutter config --no-cli-animations
flutter pub get
flutter gen-l10n
DEBUG=""
if [[ 'pull_request' == GITHUB_EVENT_NAME ]]; then
  DEBUG="--debug"
fi
dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intn_defs.dart lib/l10n/*.arb
flutter pub run build_runner build --delete-conflicting-outputs
if [[ ! -v SKIP_BUILD ]]; then
  flutter build apk --split-debug-info=./symbols $DEBUG --build-number="$BUILD_NUMBER" --build-name="$VERSION"
  flutter build appbundle --split-debug-info=./symbols --build-number="$BUILD_NUMBER" --build-name="$VERSION"
  if [[ -v GITHUB_OUTPUT ]]; then
    echo "SENTRY_DIST=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
    echo "SENTRY_RELEASE=$VERSION" >> "$GITHUB_OUTPUT"
  fi
fi
