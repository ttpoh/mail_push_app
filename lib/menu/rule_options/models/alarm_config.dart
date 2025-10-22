// lib/menu/rule_options/models/alarm_config.dart
class AlarmConfig {
  String? sound; // 예: 'default', 'siren', ...
  String? tts;   // 예: '긴급 메일 도착'

  AlarmConfig({this.sound, this.tts});

  AlarmConfig copyWith({String? sound, String? tts}) =>
      AlarmConfig(sound: sound ?? this.sound, tts: tts ?? this.tts);

  bool get isEmpty =>
      (sound == null || sound!.isEmpty) && (tts == null || tts!.isEmpty);

  @override
  String toString() => 'sound=$sound, tts=${tts ?? ""}';
}
