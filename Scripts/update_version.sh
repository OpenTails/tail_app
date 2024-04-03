#!/usr/bin/env bash
set -e
set -x
VERSION=$(cat ../VERSION)
BUILD_NUMBER=$(git rev-list HEAD --count)
cd .. && dart pub global run pubspec_version_cli:pubspec_version change --version "$VERSION"+"$BUILD_NUMBER"
