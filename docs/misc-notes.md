# Ramblings from the developer

## Push notifications

Ripping out remote push notification support. I originally thought it would be cool to have notifications when a new blog post was published but over the holidays ive decided an app shouldn't try to beg for attention. Its annoying.

## Riverpod

While riverpod is fine for CRUD apps, it is not that useful for constantly changing background state from multiple linked classes. 
I was constantly encountering edge cases that really shouldn't throw an error.Because of the issues I was encountering through my abuse of Riverpod I decided to remove it and instead rely on Singletons and ChangeNotifiers.
I am probably violating most "Best Practices" but it works
