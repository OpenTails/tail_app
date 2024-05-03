#!/bin/bash
if [[ $OS == 'macos-latest' ]]; then
    interpreter=zsh
else
    interpreter=bash
fi
exec "$interpreter" "./build.sh" "$@"
