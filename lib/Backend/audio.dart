

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
final Logger _audioLogger = Logger('Audio');

Future<void> setUpAudio() async {
  _audioLogger.info("Setting up audio session");
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.ambient,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.unknown,
      flags: AndroidAudioFlags.none,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: true,
  ));
}
Future<void> playSound(String file) async {
  _audioLogger.info("Playing sound file $file");
  final AudioPlayer player = AudioPlayer();
  await player.setAsset(file);
  await player.play();
  await player.processingStateStream.where((event) => event == ProcessingState.completed).first;
  _audioLogger.info("Finished playing sound file $file");
  await player.dispose();
}