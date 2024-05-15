# Gear On The Go

![Translation](https://img.shields.io/weblate/progress/tail_app?server=https%3A%2F%2Fweblate.codel1417.xyz&style=for-the-badge)
![Sponsor](https://img.shields.io/github/sponsors/codel1417?style=for-the-badge)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/codel1417/tail_app/build.yml?style=for-the-badge)

A Cross Platform Tail Company gear control App

## Features

- Supports Android and IOS
- Firmware Updates
- The same actions/moves from Crumpet
- Triggers for walking, shaking and other gestures
- Custom Actions
- Joystick for manually moving gear
- Dark Mode
- Color Themes
- Background mode on IOS

> [!WARNING]
> Google Play Services is required for android, so non Play Store Android devices are unsupported

## Have a suggestion?

Small or large, feel free to leave suggestions for new features, or changes to existing features.

> [!NOTE]
> As long as the suggestion is not related to a specific day or event

## Special Thanks

- [@darkgrue](https://github.com/darkgrue) for helping me with gear firmware behavior & developing the firmware the Gear uses
- [@MasterTailer](https://github.com/MasterTailer) for providing useful feedback and suggestions, and creating the gear this app controls
- [@ToeiRei](https://github.com/ToeiRei) for inspiring me to use more privacy-preserving infrastructure like plausible.
- [@leinir](https://github.com/leinir) for creating the Crumpet Android app
- The Tail Company Telegram Channel for motivating me over time.

## Development

### Requirements

> [!TIP]
> Follow the instructions [here](https://docs.flutter.dev/get-started/install/windows/mobile?tab=download#software-requirements) to set up a Flutter environment

#### Hardware

- 8GB of ram
- Dual Core CPU
- 80gb of unused storage (Required for Android Studio & XCode, Sources for IOS & Android apps, etc)
- 2018 or newer Apple Mac (For IOS) Older macs with [OpenCore-Legacy Patcher](https://dortania.github.io/OpenCore-Legacy-Patcher/) may work

#### Software
- Windows 11 Or MacOS Sonoma (Have not tried developing on linux)
- [Android Studio](https://developer.android.com/studio)
  - [Flutter Plugin](https://plugins.jetbrains.com/plugin/9212-flutter)
  - [Dart Plugin](https://plugins.jetbrains.com/plugin/6351-dart)
  - [Flutter Enhancement Suite (Recommended)](https://plugins.jetbrains.com/plugin/12693-flutter-enhancement-suite)
- [Java `17` (For Android)](https://adoptium.net/temurin/releases/?package=jdk&version=17)
- [XCode `15` (For IOS)](https://developer.apple.com/xcode/) with IOS & CLI Tools installed
- [CocoaPods (For IOS)](https://cocoapods.org/)
- [Flutter SDK `3.22.0`](https://docs.flutter.dev/get-started/install)
- Bash (Windows & Linux) or ZSH (MacOS)
- [Git](https://git-scm.com/downloads)

### Building

#### Preparing for build

> [!TIP]
> A pre-made build script exists at [`scripts/build,sh`](Scripts/build.sh)

> [!IMPORTANT]
> These commands must be run before building or running.

```shell
flutter pub get # Downloads Dependencies 
flutter gen-l10n
dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intn_defs.dart lib/l10n/*.arb
flutter pub run build_runner build --delete-conflicting-outputs  # Generates .g files
```

- To generate base EN localalization file, run 

```shell
dart run intl_translation:extract_to_arb --locale=en --output-file='./lib/l10n/messages_en.arb' ./lib/Frontend/intn_defs.dart
```

- To build localization files, run 

```shell
flutter gen-l10n && dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intn_defs.dart lib/l10n/*.arb
```

- To build generated `.g` files, run 

```shell
flutter pub run build_runner build --delete-conflicting-outputs
```

- If you get a flutter version error, run 

```shell
flutter Upgrade
```

#### Building for each platform

##### For IOS

```shell
cd ios
rm Podfile.lock # Handles a CocoaPods error about version management
pod install
cd ..
flutter build ipa --debug --no-codesign
```
> [!TIP]
> MacOS may display multiple permission prompts such as File Access, KeyChain Access, Device Access (iphone) & Controlling XCode. Accept them for the build to complete. These only need to be accepted once

> [!TIP]
> If you receive an error that IOS is not installed in XCode during build.
> 1. Go to XCode (In Top menu bar) -> Settings
> 2. Click Platforms
> 3. Click on IOS Simulator
> 4. Click the small `-` icon near the bottom of the settings window
> 5. Click Delete

> [!TIP]
> If CocoaPods returns a version error, delete [`ios/Podfile.lock`](ios/Podfile.lock)

##### For Android

```shell
# Build APK
flutter build apk --debug --dart-define=cronetHttpNoPlay=true
# build AppBundle
flutter build appbundle --debug --dart-define=cronetHttpNoPlay=true
```

App packages can be found in [`build/app/output`](build/app/outputs/)

### Developer Mode Features

- Gear console
- Manual OTA Updates
- Advanced state control for gear
- Access to app logs
- ~~Crime~~

<details>

<summary>Secret</summary

To enter the in-app Developer Mode, follow these instructions

1. Long press Github button, enter the following code
2. `🦊🐉🦦🦖`

To Turn off Developer Mode
1. go to More -> Settings -> Developper Mode
2. Turn off `showDebugging`
</details>

### Internal URLS

These services are self-hosted in a mini-pc on my tv stand in my apartment

[Sentry](https://sentry.codel1417.xyz/organizations/sentry/projects/tail_app/?project=2)
[Weblate](https://weblate.codel1417.xyz/projects/tail_app/tail_app/)
[Plausible](https://plausible.codel1417.xyz/tail-app)
[Uptime](https://uptime.codel1417.xyz/status/public)

### Misc

UUIDs were generated using https://www.uuidgenerator.net/version4
