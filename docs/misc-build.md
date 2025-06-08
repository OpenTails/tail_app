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
