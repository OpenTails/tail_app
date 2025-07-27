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
- [XCode `16` (For IOS)](https://developer.apple.com/xcode/) with IOS & CLI Tools installed
- [CocoaPods (For IOS)](https://cocoapods.org/)
- [Flutter SDK `3.26.0`](https://docs.flutter.dev/get-started/install)
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

When [`translation_string_definitions.dart`](lib/Frontend/translation_string_definitions.dart) is updated, the job [`localization_strings_update.yml`](.github/workflows/localization_strings_update.yml) updates the generated localization file [`messages_en.arb`](lib/l10n/messages_en.arb) which makes the strings available to [Weblate](https://weblate.stargazer.at/projects/the-tailcompany-app/tailapp/).

When non EN translations are updated in [Weblate](https://weblate.stargazer.at/projects/the-tailcompany-app/tailapp/), A pull request will automatically open with the changes. This may take a few minutes.

### Fastlane

[Fastlane](https://docs.fastlane.tools/) is a tool to automatically upload apps to the Apple App Store and Google Play Store. Inside the [IOS](ios/) and [Android](android/) folders is a fastlane folder. Inside is the FastFile which contains the upload config. Secrets are JSON files passed through repository secrets. The script [fastlane.sh](Scripts/fastlane.sh) selects the fastlane folder to use and begins the upload.

### Firebase

This project uses 2 seperate Firebase projects. One for notifications and one for CosHub posts.

Notifications use `DefaultFirebaseOptions` in [`/lib/firebase_options.dart`](../lib/firebase_options.dart) while CosHub uses `CosHubFirebaseOptions`. This combined file was created by running `flutterfire configure` for CosHub, renaming the file, running the command again for tailApp, and then copying `DefaultFirebaseOptions` from coshub into the final [`/lib/firebase_options.dart`](../lib/firebase_options.dart) file.

This file is supplied in build via secrets.

### Repository Integrations

#### Sentry

A github app which allows [Sentry](https://sentry.io) to authenticate with Github and this repo. It allows Source Code stack trace linking and Creating issues from the [Sentry](https://sentry.codel1417.xyz/organizations/sentry/projects/tail_app/?project=2) UI.

#### Weblate

A Webhook to notify [Weblate](https://weblate.stargazer.at/projects/the-tailcompany-app/tailapp/) that code was pushed to this repo.

A SSH key is installed in my account which allows [Weblate](https://weblate.stargazer.at/projects/the-tailcompany-app/tailapp/) to push translation changes to the repo.

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

[Plausible](https://plausible.codel1417.xyz/tail-app)
[Aptabase](https://aptabase.codel1417.xyz/)
[Sentry](https://sentry.codel1417.xyz/)
[Uptime](https://uptime.codel1417.xyz/status/public)

#### Infrastructure notes

Services are hosted in a [Proxmox](https://www.proxmox.com/en/) based machine using unprivileged LXC containers.
These containers are based on [Ubuntu Server](https://ubuntu.com/download/server) and have unattended upgrades enabled.
This machine doesn't use port forwarding, but instead uses [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/).
Services go down daily at 6:00 AM UTC for offline backups. This Can take up to an hour.

### Dynamic Configuration

This app supports updating some config values remotely.
These values are located in [`dynamic_config.json`](assets/dynamic_config.json).
The file is included in builds and updated after app launch, so changes may not appear immediately.

#### Other URLS

[Apple App Store connect](https://appstoreconnect.apple.com/apps)
[Codecov Code Coverage](https://app.codecov.io/gh/OpenTails/tail_app)

### Misc

UUIDs were generated using <https://www.uuidgenerator.net/version4>
