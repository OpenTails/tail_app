#!/bin/bash
set -e
set -x
if [[ $OS == 'macos-latest' ]]; then
    interpreter=zsh
else
    interpreter=bash
fi
exec "$interpreter" "./build.sh" "$@"
