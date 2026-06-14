# Ramblings from the developer

## Push notifications

Ripping out remote push notification support.
I originally thought it would be cool to have notifications when a new blog post was published but over the holidays ive decided an app shouldn't try to beg for attention. Its annoying.

## Riverpod

While riverpod is fine for CRUD apps, it is not that useful for constantly changing background state from multiple linked classes.
I was constantly encountering edge cases that really shouldn't throw an error.Because of the issues I was encountering through my abuse of Riverpod I decided to remove it and instead rely on Singletons and ChangeNotifiers.
I am probably violating most "Best Practices" but it works.

## Bluetooth

Multiple bluetooth libraries have been used throughout development.

### flutter_reactive_ble

The first library we used.
While it worked there were issues using this with the display off, even with a foreground service.

### flutter_blue_plus

The library we used since launch to app version `1.5.0`.
This library was reliable but version `2.0.0` changed to a new license that restricted commercial use.
Each subsequent update changed the terms of what is considered commercial use
We received a legal threat after dependabot tried to update FBP to `2.3.8` https://github.com/OpenTails/tail_app/pull/520, since the library now phones home during build.
Due to this we decided to change the library to avoid associations with a developer which changes the license in an attempt to extort users.
Also tracked in this issue https://github.com/OpenTails/tail_app/issues/438.

### universal_ble

The replacement for flutter_blue_plus, releasing in app version `1.5.0` So far it has been easy to work with, though I needed to wrap the valueChanged callback into a stream.
I am glad the efforts of universal_ble and flutter_blue_plus weren't combined. https://github.com/Navideck/universal_ble/issues/132