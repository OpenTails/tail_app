#!/bin/bash
set -e

# Configure flutter & pre-build tasks
echo "::group::Configure tools"
flutter config --no-cli-animations --disable-analytics
flutter pub global activate intl_translation
flutter pub global activate build_runner
echo "::endgroup::"