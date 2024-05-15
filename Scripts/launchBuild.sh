#!/bin/bash
set -e
set -x

# MacOS bash is outdated compared to the version shipped with ubuntu, and is missing some features used in the build script
# This changes the interpreter to zsh for MacOS and launches the build script

if [[ $OS == 'macos-latest' ]]; then
    interpreter=zsh
else
    interpreter=bash
fi
exec "$interpreter" "./build.sh" "$@"
