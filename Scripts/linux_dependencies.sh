set -e
sudo apt-get update -y && sudo apt-get upgrade -y

# Flutter
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev

# Audiostreamer_linux
sudo apt-get install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev

# Sentry-native
sudo apt-get install libcurl4-openssl-dev
