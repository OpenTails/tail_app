//https://stackoverflow.com/questions/68682573/flutter-dart-format-duration-to-show-just-minutes-seconds-and-milliseconds
String prettyDuration(Duration duration) {
  var seconds = (duration.inMilliseconds % (60 * 1000)) / 1000;
  return '${duration.inMinutes}m${seconds.toStringAsFixed(2)}s';
}
