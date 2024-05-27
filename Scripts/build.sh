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
echo "::group::Configure tools"
flutter config --no-cli-animations --enable-analytics --color
dart pub global activate flutter_gen --color
dart pub global activate intl_translation --color
dart pub global activate build_runner --color
echo "::endgroup::"

echo "::group::Get Dependencies"
flutter pub get --color
echo "::endgroup::"
DEBUG=""
if [[ $GITHUB_EVENT_NAME == 'pull_request'  ]]; then
  DEBUG="--debug"
else
  DEBUG="--release"
fi
echo "::group::Generate Translation Files"
dart pub global run --color intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intn_defs.dart lib/l10n/*.arb
echo "::endgroup::"
echo "::group::Generate Dart .g Files"
dart pub global run --color build_runner build --delete-conflicting-outputs
echo "::endgroup::"
if [[ ! -v SKIP_BUILD ]]; then # This is re-used for the linting job, which doesn't require a full build
  # Build
  if [[ $OS == 'macos-latest' ]]; then
    echo doing nothing
    #flutter build ipa $DEBUG --no-codesign --build-number="$BUILD_NUMBER" --build-name="$VERSION"
  else
    if [[ $GITHUB_EVENT_NAME == 'push' ]]; then
        echo "ANDROID_KEY_PROPERTIES" > ./android/key.properties
        echo -n "ANDROID_KEY_JKS" | base64 -d > ./android/AndroidKeystoreCodel1417.jks
    fi
    echo "::group::Build APK"
    flutter build apk --split-debug-info=./symbols $DEBUG --build-number="$BUILD_NUMBER" --build-name="$VERSION" --color #--dart-define=cronetHttpNoPlay=true
    echo "::endgroup::"
    echo "::group::Build APK"
    flutter build appbundle --split-debug-info=./symbols --build-number="$BUILD_NUMBER" --build-name="$VERSION" --color #--dart-define=cronetHttpNoPlay=true
    echo "::endgroup::"
  fi
  if [[ -v GITHUB_OUTPUT ]]; then
    echo "SENTRY_DIST=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
    echo "SENTRY_RELEASE=$VERSION" >> "$GITHUB_OUTPUT"
  fi
fi
