# The Tail Company App

![Translation](https://img.shields.io/weblate/progress/tail_app?server=https%3A%2F%2Fweblate.codel1417.xyz&style=for-the-badge)
![Sponsor](https://img.shields.io/github/sponsors/codel1417?style=for-the-badge)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/codel1417/tail_app/build.yml?style=for-the-badge)
![Codecov](https://img.shields.io/codecov/c/github/OpenTails/tail_app)

A Cross Platform Tail Company gear control App

## Features

- Supports Android and IOS
- Firmware Updates
- The same actions/moves from Crumpet
- Triggers for walking, shaking and other gestures
- Custom Actions
- Custom Sound Effects
- Joystick for manually moving gear
- Dark Mode (Based on system settings)
- Color Themes
- Background mode on IOS
- Tail Blog
- Tablet support

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

### Updating EN Localizations

To update EN localization strings, the file [`translation_string_definitions.dart`](lib/Frontend/translation_string_definitions.dart) needs to be updated.

```dart
String message() => Intl.message('Displayed Message', name: 'message', desc: 'A description of the string and where it is used');
```

The `Displayed Message` is the string that appears in the UI.
The `name` is the variable name. This must match the variable name used such as `message()` but without the `()`.
The `desc` is a description of the string for use by translators.

When [`translation_string_definitions.dart`](lib/Frontend/translation_string_definitions.dart) is updated, the job [`localization_strings_update.yml`](.github/workflows/localization_strings_update.yml) updates the generated localization file [`messages_en.arb`](lib/l10n/messages_en.arb) which makes the strings available to [Weblate](https://weblate.codel1417.xyz/projects/tail_app/tail_app/).
New Strings are auto translated by Google Translate but will not overwrite manually translated strings.

When non EN translations are updated in [Weblate](https://weblate.codel1417.xyz/projects/tail_app/tail_app/), A pull request will automatically open with the changes. This may take a few minutes.

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
> dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/translation_string_definitions.dart lib/l10n/*.arb
> flutter pub run build_runner build --delete-conflicting-outputs  # Generates .g files
> ```

> [!NOTE]
> To generate base EN localalization file, run
>
> ```shell
> dart pub global activate intl_translation
> dart run intl_translation:extract_to_arb --locale=en --output-file='./lib/l10n/messages_en.arb' ./lib/Frontend/translation_string_definitions.dart
> ```
>
> To build localization files, run
>
> ```shell
> dart pub global activate intl_translation
> dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/translation_string_definitions.dart lib/l10n/*.arb
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
> if you get an error similar to `Error: Couldn't resolve the package 'flutter_gen' in 'package:flutter_gen/gen_l10n/app_localizations.dart'` run
>
> ```
> flutter pub get
> ```
>
> if you get an error during riverpod generator such as `RangeError (index): Invalid value: Not in inclusive range 0..20491: 77535` try
>
> ```shell
> flutter clean
> flutter pub get
> flutter pub run build_runner build --delete-conflicting-outputs
> flutter pub get # fixes app_localizations error
> ```

#### Building for each platform

##### For IOS

The xcode project is configured to to use automatic code signing for develop builds. make sure to open xcode and sign in with your developer account. Check the Signing and Capabilities page of Runner to verify the signing configuration is correct. Release builds are set up to rely on Fastlane to provide the signing certificate.

```shell
cd ios
rm Podfile.lock # Handles a CocoaPods error about version management
cd ..
flutter build ipa --debug
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
>
> If Permissions are not working, revert any changes you may have done to [`ios/Podfile`](ios/Podfile)

##### For Android

Android looks for a [key.properties](android/key.example.properties) file.
If this file is missing the apk is not signed.
A keystore jks is also expected at the location specified in the keystore.properties file.
The Sentry plugin will run on release builds and expects the sentry env variables to be set

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

> [!TIP]
> Once this command is run, you need to add the following to [styles.xml](android/app/src/main/res/values/styles.xml) to have transparent status and navigation bars on the splash screen on android.
>
> ```xml
> <item name="android:windowTranslucentNavigation">true</item>
> <item name="android:statusBarColor">@android:color/transparent</item>
> ```

### Fastlane

[Fastlane](https://docs.fastlane.tools/) is a tool to automatically upload apps to the Apple App Store and Google Play Store. Inside the [IOS](ios/) and [Android](android/) folders is a fastlane folder. Inside is the FastFile which contains the upload config. Secrets are JSON files passed through repository secrets. The script [fastlane.sh](Scripts/fastlane.sh) selects the fastlane folder to use and begins the upload.

### Repository Secrets

Some of these values aren't actually secret and can be shared. Specifically the sentry ones

| Name                    | Example Value                                                                                                                                                            | How to get                                                                                                    | Uses                                            |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| SENTRY_AUTH_TOKEN       | sntrys_eyJpYXQiOjE3MTYyNTky...                                                                                                                                           | Go to Sentry -> Settings -> Auth Token                                                                        | Authenticate with sentry to upload symbols      |
| SENTRY_ORG              | Sentry                                                                                                                                                                   | Listed at the top left of sentry when logged in                                                               | Which org to upload symbols to                  |
| SENTRY_PROJECT          | tail_app                                                                                                                                                                 | Whatever the project is named in sentry                                                                       | Which project to upload symbols to              |
| SENTRY_URL              | https://sentry.codel1417.xyz/                                                                                                                                            | The url to the sentry instance                                                                                | Which instance to upload symbols to             |
| FASTLANE_GITHUB         | JeqGFIV1yb7emBFLkBk/dA==                                                                                                                                                 | echo -n your_github_username:your_personal_access_token \| base64 -w 0                                        | Store certificates for fastlane match           |
| APPLE                   | {"key_id": "D383SF739", "issuer_id": "6053b7fe-68a8-4acb-89be-165aa6465141", "key": "-----BEGIN PRIVATE KEY-----MIGTAgEAMB----END PRIVATE KEY-----", "in_house": false } | Json file of apple credentials https://docs.fastlane.tools/app-store-connect-api/                             | Authenticate with Apple to upload to TestFlight |
| FASTLANE_PATCH_PASSWORD | hunter2                                                                                                                                                                  | Make a password                                                                                               | Encrypt match certificates                      |
| ANDROID_KEY_PROPERTIES  | storePassword=hunter2 <br> keyPassword=hunter2 <br> keyAlias=upload <br> storeFile=key.jks                                                                               | generate an android signing certificate and fill out [key.example.properties](android/key.example.properties) | sign apks                                       |
| ANDROID_KEY_JKS         | sdfsfasdFSDgjklsgklsjdfASGHSDLGHJFSD=                                                                                                                                    | cat AndroidKeystoreCodel1417.jks \| base64 -w 0                                                               | base64 form of the jks file                     |
| GOOGLE_SECRETS          | {"type": "service_account",                                                                                                                                              | Json file of google credentials https://docs.fastlane.tools/actions/upload_to_play_store/                     | Authenticate to google to upload builds         |

### Repository Integrations

#### Sentry

A github app which allows [Sentry](https://sentry.codel1417.xyz/organizations/sentry/projects/tail_app/?project=2) to authenticate with Github and this repo. It allows Source Code stack trace linking and Creating issues from the [Sentry](https://sentry.codel1417.xyz/organizations/sentry/projects/tail_app/?project=2) UI.

#### Weblate

A Webhook to notify [Weblate](https://weblate.codel1417.xyz/projects/tail_app/tail_app/) that code was pushed to this repo.

A SSH key is installed in my account which allows [Weblate](https://weblate.codel1417.xyz/projects/tail_app/tail_app/) to push translation changes to the repo.

### Developer Mode Features

- Gear console
- Manual OTA Updates
- Advanced state control for gear
- Access to app logs
- ~~Crime~~

<details>

<summary>Secret</summary>

To enter the in-app Developer Mode, follow these instructions

1. Go to `More`
2. Long press `Source Code` button, enter the following code
3. `🦊🐉🦦🦖`

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

#### Infrastructure notes

Services are hosted in a [Proxmox](https://www.proxmox.com/en/) based machine using unprivileged LXC containers.
These containers are based on [Ubuntu Server] (https://ubuntu.com/download/server) and have unattended upgrades enabled.
This machine doesn't use port forwarding, but instead uses [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/).
Services go down daily at 6:00 AM UTC for offline backups. This Can take up to an hour.

#### Other URLS

[Apple App Store connect](https://appstoreconnect.apple.com/apps)
[Codecov Code Coverage](https://app.codecov.io/gh/OpenTails/tail_app)
### Misc

UUIDs were generated using https://www.uuidgenerator.net/version4
