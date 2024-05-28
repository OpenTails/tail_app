set -e
#set -x

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
