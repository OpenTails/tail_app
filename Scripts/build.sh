set -e
#set -x

# -v checks if a variable exists

getVersion() {
  # get the Build Number & version from git
  VERSION="$(cat VERSION)"
  # Gets the release tag from github if it exists (Github Actions)
  # Assumes tags start with V
  if [[ -v RELEASE_TAG ]] && [[ -n $RELEASE_TAG ]]; then
    TAG="${RELEASE_TAG,,}"
    # Remove the V prefix
    VERSION="${TAG//"v"}"
  fi

  if [[ -v GITHUB_OUTPUT ]]; then
      echo "VERSION=$VERSION" >> "$GITHUB_OUTPUT"
  fi

  echo "VERSION $VERSION"
}
getBuildNumber() {
  # get the Build Number & version from git
  BUILD_NUMBER="$(git rev-list HEAD --count)"

  if [[ -v GITHUB_OUTPUT ]]; then
      echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
  fi

  echo "BUILD_NUMBER $BUILD_NUMBER"
}
setUpTools() {
  # Configure flutter & pre-build tasks
  echo "::group::Configure tools"
  flutter config --no-cli-animations --enable-analytics
  dart pub global activate flutter_gen
  dart pub global activate intl_translation
  dart pub global activate build_runner
  dart pub global activate icons_launcher
  echo "::endgroup::"
}
preBuildTasks() {
  echo "::group::Generate Translation Files"
  dart pub global run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/translation_string_definitions.dart lib/l10n/*.arb
  echo "::endgroup::"

  echo "::group:: Run FlutterGen"
  fluttergen -c pubspec.yaml
  echo "::endgroup::"

  echo "::group::Generate Dart .g Files"
  dart pub run build_runner build --delete-conflicting-outputs
  echo "::endgroup::"

  echo "::group::Generate App assets"
  dart run flutter_native_splash:create
  dart pub global run icons_launcher:create
  echo "::endgroup::"
}

# We want to be in the project root folder, not the scripts folder
if [[ "$(pwd)" == *"/Scripts" ]]; then
  cd ..
fi

getVersion
getBuildNumber
setUpTools


echo "::group::Get Dependencies"
dart pub get
echo "::endgroup::"

DEBUG=""
if [[ $GITHUB_EVENT_NAME == 'pull_request'  ]]; then
  DEBUG="--debug"
else
  DEBUG="--release"
fi


if [[ ! -v SKIP_BUILD ]]; then # This is re-used for the linting job, which doesn't require a full build
  # Build
  if [[ $RUNNER_OS == 'macOS' ]]; then
    echo "doing nothing Awoo"
    #flutter build ipa $DEBUG --no-codesign --build-number="$BUILD_NUMBER" --build-name="$VERSION"
  else
    if [[ $GITHUB_EVENT_NAME == 'push' ]]; then
        echo "$ANDROID_KEY_PROPERTIES" > ./android/key.properties
        echo -n "$ANDROID_KEY_JKS" | base64 -d > ./android/AndroidKeystoreCodel1417.jks
    fi
    echo "::group::Build APK"
    flutter build apk --split-debug-info=./symbols $DEBUG --build-number="$BUILD_NUMBER" --build-name="$VERSION"
    echo "::endgroup::"
    echo "::group::Build APK"
    flutter build appbundle --split-debug-info=./symbols --build-number="$BUILD_NUMBER" --build-name="$VERSION"
    echo "::endgroup::"
  fi
  if [[ -v GITHUB_OUTPUT ]]; then
    echo "SENTRY_DIST=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
    echo "SENTRY_RELEASE=$VERSION" >> "$GITHUB_OUTPUT"
  fi
fi
