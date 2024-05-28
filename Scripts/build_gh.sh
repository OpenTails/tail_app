set -e
set -x

# -v checks if a variable exists


# We want to be in the project root folder, not the scripts folder
if [[ "$(pwd)" == *"/Scripts" ]]; then
  cd ..
fi

DEBUG=""
if [[ $GITHUB_EVENT_NAME == 'pull_request'  ]]; then
  DEBUG="--debug"
else
  DEBUG="--release"
fi

if [[ ! -v SKIP_BUILD ]]; then # This is re-used for the linting job, which doesn't require a full build
  # Build
  if [[ $OS == 'macos-latest' ]]; then
    echo doing nothing Awoo
    #flutter build ipa $DEBUG --no-codesign --build-number="$BUILD_NUMBER" --build-name="$VERSION"
  else
    if [[ $GITHUB_EVENT_NAME == 'push' ]]; then
        echo "$ANDROID_KEY_PROPERTIES" > ./android/key.properties
        echo -n "$ANDROID_KEY_JKS" | base64 -d > ./android/AndroidKeystoreCodel1417.jks
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
