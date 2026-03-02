import 'package:audioplayers/audioplayers.dart';

class AlarmPlayer {
  static final AlarmPlayer _instance = AlarmPlayer._internal();
  factory AlarmPlayer() => _instance;
  AlarmPlayer._internal();

  final AudioPlayer _alarmPlayer = AudioPlayer();
  final AudioPlayer _milestonePlayer = AudioPlayer();

  // Looping alarm for when the timer reaches zero
  Future<void> play() async {
    await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
    await _alarmPlayer.play(AssetSource('sounds/alarm.wav'));
  }

  // One-shot sound for 40min / 20min milestones
  Future<void> playOnce(String assetPath) async {
    await _milestonePlayer.setReleaseMode(ReleaseMode.release);
    await _milestonePlayer.play(AssetSource(assetPath));
  }

  Future<void> stop() async {
    await _alarmPlayer.stop();
    await _milestonePlayer.stop();
  }

  void dispose() {
    _alarmPlayer.dispose();
    _milestonePlayer.dispose();
  }
}
