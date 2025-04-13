# get the Build Number & version from git and store it in github outputs

VERSION="$(head -1 VERSION | egrep -o '[0-9.]+')"
BUILD_NUMBER="$(git rev-list HEAD --count)"
# Gets the release tag from github if it exists (Github Actions)
# Assumes tags start with V
if [[ -v RELEASE_TAG ]] && [[ -n $RELEASE_TAG ]]; then
  TAG="${RELEASE_TAG,,}"
  VERSION="${TAG//"v"}"
fi
echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
echo "VERSION=$VERSION" >> "$GITHUB_OUTPUT"