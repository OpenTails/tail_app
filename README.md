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
- Dark Mode (Based on system setting)
- Color Themes
- Background mode on IOS
- Tail Blog

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
- [Ruby](https://www.ruby-lang.org/en/) for FastLane
### Building

#### Preparing for build

> [!TIP]
> A pre-made build script exists at [`scripts/build,sh`](Scripts/build.sh)

> [!IMPORTANT]
> These commands must be run before building or running.
>
> ```shell
> # Install and enable required tools
> dart pub global activate build_runner
> dart pub global activate flutter_gen
> dart pub global activate intl_translation
> 
> flutter pub get # Downloads Dependencies
> dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intn_defs.dart lib/l10n/*.arb
> flutter pub run build_runner build --delete-conflicting-outputs  # Generates .g files
> ```

> [!NOTE]
> To generate base EN localalization file, run
>
> ```shell
> dart pub global activate intl_translation
> dart run intl_translation:extract_to_arb --locale=en --output-file='./lib/l10n/messages_en.arb' ./lib/Frontend/intn_defs.dart
> ```
>
> To build localization files, run
>
> ```shell
> dart pub global activate intl_translation
> dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intn_defs.dart lib/l10n/*.arb
> ```
>
> To build generated `.g` files, run
>
> ```shell
> dart pub global activate build_runner
> dart pub global activate flutter_gen
> flutter pub run build_runner build --delete-conflicting-outputs
> ```

> [!TIP]
> If you get a flutter version error, run
>
> ```shell
> flutter Upgrade
> ```
>
> if you get an error simialr to `Error: Couldn't resolve the package 'flutter_gen' in 'package:flutter_gen/gen_l10n/app_localizations.dart'` run
>
> ```
> flutter pub get
> ```

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
>
> If you receive an error that IOS is not installed in XCode during build.
> 1. Go to XCode (In Top menu bar) -> Settings
> 2. Click Platforms
> 3. Click on IOS Simulator
> 4. Click the small `-` icon near the bottom of the settings window
> 5. Click Delete
>
> If CocoaPods returns a version error, delete [`ios/Podfile.lock`](ios/Podfile.lock)

##### For Android

```shell
# Build APK
flutter build apk --debug
# build AppBundle
flutter build appbundle --debug
```

App packages can be found in [`build/app/output`](build/app/outputs/)

### Additional Commands

#### Updating app icon

Place the new icon in [Assets](assets/) then update `image_path` in the `icons_launcher` section in [pubspec.yml](pubspec.yml)

```shell
dart pub global activate icons_launcher # downloads the utility
dart pub global run icons_launcher:create
```

#### Updating splash screen

Make any changes to the 'flutter_native_splash' section in [pubspec.yml](pubspec.yml)

```shell
dart run flutter_native_splash:create
```

### Fastlane

[Fastlane](https://docs.fastlane.tools/) is a tool to automatically upload apps to the Apple App Store and Google Play Store. Inside the [IOS](ios/) and [Android](android/) folders is a fastlane folder. Inside is the FastFile which contains the upload config. Secrets are JSON files passed through repository secrets. The script [fastlane.sh](Scripts/fastlane.sh) selects the fastlane folder to use and begins the upload

### Repository Secrets

Some of these values aren't actually secret and can be shared. Specifically the sentry ones

| Name | Example Value | How to get | Uses |
|------|-------|------------|----------|
| SENTRY_AUTH_TOKEN | sntrys_eyJpYXQiOjE3MTYyNTky... | Go to Sentry -> Settings -> Auth Token | Authenticate with sentry to upload symbols |
| SENTRY_ORG | Sentry | Listed at the top left of sentry when logged in | Which org to upload symbols to |
| SENTRY_PROJECT | tail_app | Whatever the project is named in sentry | Which project to upload symbols to |
| SENTRY_URL | https://sentry.codel1417.xyz/ | The url to the sentry instance | Which instance to upload symbols to |
| FASTLANE_GITHUB | JeqGFIV1yb7emBFLkBk/dA== | echo -n your_github_username:your_personal_access_token \| base64 | Store certificates for fastlane match |
| APPLE | {"key_id": "D383SF739", "issuer_id": "6053b7fe-68a8-4acb-89be-165aa6465141", "key": "-----BEGIN PRIVATE KEY-----MIGTAgEAMB----END PRIVATE KEY-----", "in_house": false } | Json file of apple credentials https://docs.fastlane.tools/app-store-connect-api/ | Authenticate with Apple to upload to TestFlight |
| FASTLANE_PATCH_PASSWORD | hunter2 | Make a password | Encrypt match certificates |

### Developer Mode Features

- Gear console
- Manual OTA Updates
- Advanced state control for gear
- Access to app logs
- ~~Crime~~

<details>

<summary>Secret</summary>

To enter the in-app Developer Mode, follow these instructions

1. Long press Github button, enter the following code
2. `🦊🐉🦦🦖`

To Turn off Developer Mode

1. go to More -> Settings -> Developer Mode
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
