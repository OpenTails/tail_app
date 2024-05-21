set -e
set -x

# -v checks if a variable exists


# We want to be in the project root folder, not the scripts folder
if [[ "$(pwd)" == *"/Scripts" ]]; then
  cd ..
fi
# get the Build Bumber & version from git
VERSION="$(cat VERSION)"
BUILD_NUMBER="$(git rev-list HEAD --count)"
# Gets the release tag from github if it exists (Github Actions)
# Assumes tags start with V
if [[ -v RELEASE_TAG ]] && [[ -n $RELEASE_TAG ]]; then
  TAG="${RELEASE_TAG,,}"
  VERSION="${TAG//"v"}"
fi

# Configure flutter & pre-build tasks
flutter config --no-cli-animations
dart pub global activate flutter_gen
dart pub global activate intl_translation
dart pub global activate build_runner

flutter pub get
DEBUG=""
if [[ $GITHUB_EVENT_NAME == 'pull_request'  ]]; then
  DEBUG="--debug"
else
  DEBUG="--release"
fi
dart pub global run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intn_defs.dart lib/l10n/*.arb
dart pub global run build_runner build --delete-conflicting-outputs
if [[ ! -v SKIP_BUILD ]]; then # This is re-used for the linting job, which doesn't require a full build
  # Build
  if [[ $OS == 'macos-latest' ]]; then
    cd ios
    pod install
    cd ..
    #flutter build ipa $DEBUG --no-codesign --build-number="$BUILD_NUMBER" --build-name="$VERSION"
  else
    flutter build apk --split-debug-info=./symbols $DEBUG --build-number="$BUILD_NUMBER" --build-name="$VERSION" #--dart-define=cronetHttpNoPlay=true
    flutter build appbundle --split-debug-info=./symbols --build-number="$BUILD_NUMBER" --build-name="$VERSION" #--dart-define=cronetHttpNoPlay=true
  fi
  dart pub cache clean
  if [[ -v GITHUB_OUTPUT ]]; then
    echo "SENTRY_DIST=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
    echo "SENTRY_RELEASE=$VERSION" >> "$GITHUB_OUTPUT"
  fi
fi
