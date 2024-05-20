  set -e
  set -x

  # -v checks if a variable exists


  # We want to be in the project root folder, not the scripts folder
  if [[ "$(pwd)" == *"/Scripts" ]]; then
    cd ..
  fi

if [[ $GITHUB_EVENT_NAME == 'pull_request'  ]]; then
  exit 1
fi

  if [[ $OS == 'macos-latest' ]]; then
    cd ios
    echo "$APPLE_SECRETS" > APPLE_SECRETS.json
    fastlane beta
    rm APPLE_SECRETS.json
  else
    cd android
    fastlane beta
  fi