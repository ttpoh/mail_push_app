import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:mail_push_app/models/rule_model.dart' as rm;
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import '../models/alarm_config.dart';

class AlarmSelector extends StatelessWidget {
  const AlarmSelector({
    super.key,
    required this.selected,
    required this.configs,
    required this.onSelected,
    required this.onConfigSaved,
    this.showInlineSummary = true, // ✅ 요약 표시 토글
  });

  final rm.AlarmLevel selected;
  final Map<rm.AlarmLevel, AlarmConfig> configs;
  final ValueChanged<rm.AlarmLevel> onSelected;
  final void Function(rm.AlarmLevel, AlarmConfig) onConfigSaved;

  /// 옵션 아래 sound/tts 요약 칩을 보여줄지 여부
  final bool showInlineSummary;

  static const List<String> _soundOptions = <String>[
    'default', 'bugle', 'siren', 'cuckoo', 'gun', 'horn', 'melting', 'orchestra', 'right',
  ];

  String _assetForSound(String? name) {
    final key = (name ?? 'default').trim().toLowerCase();
    return 'assets/sounds/$key.mp3';
  }

  Future<bool> _openConfigDialog(BuildContext context, rm.AlarmLevel level) async {
    final existing = configs[level] ?? AlarmConfig(sound: 'default');
    final sound = ValueNotifier<String?>(existing.sound ?? 'default');
    final ttsCtrl = TextEditingController(text: existing.tts ?? '');

    final player = AudioPlayer();
    final isPlaying = ValueNotifier<bool>(false);

    Future<void> initSession() async {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    }

    Future<void> preview() async {
      try {
        await initSession();
        await player.stop();
        await player.setAsset(_assetForSound(sound.value));
        await player.play();
        isPlaying.value = true;
        player.playerStateStream
            .firstWhere((s) => s.processingState == ProcessingState.completed || s.playing == false)
            .then((_) => isPlaying.value = false);
      } catch (e) {
        isPlaying.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('미리듣기 실패: $e')),
          );
        }
      }
    }

    Future<void> stopPreview() async {
      try {
        await player.stop();
      } finally {
        isPlaying.value = false;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(level == rm.AlarmLevel.critical ? '1회 울림' : '정지 시까지'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('사운드', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<String?>(
                valueListenable: sound,
                builder: (_, value, __) {
                  return DropdownButtonFormField<String>(
                    value: value ?? 'default',
                    isExpanded: true,
                    items: _soundOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) async {
                      sound.value = v ?? 'default';
                      if (isPlaying.value) {
                        await preview();
                      }
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ec.eventLightBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ec.eventPrimaryColor),
                      ),
                      hintText: '사운드를 선택하세요',
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: isPlaying,
                    builder: (_, playing, __) {
                      return ElevatedButton.icon(
                        onPressed: playing ? null : preview,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('미리 듣기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ec.eventPrimaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: stopPreview,
                    icon: const Icon(Icons.stop),
                    label: const Text('정지'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('TTS 메시지', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: ttsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '예: 긴급 메일이 도착했습니다',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: ec.eventLightBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: ec.eventPrimaryColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ec.eventPrimaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    try { await player.stop(); } catch (_) {}
    await player.dispose();

    if (ok == true) {
      onConfigSaved(
        level,
        AlarmConfig(
          sound: sound.value ?? 'default',
          tts: ttsCtrl.text.trim(),
        ),
      );
      return true;
    }
    return false;
  }

  Widget _chip(String text, Color color, {IconData? icon}) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      avatar: icon != null ? Icon(icon, size: 14) : null,
      backgroundColor: Colors.white,
      side: BorderSide(color: ec.eventLightBorderColor),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _wrapShadow(Widget child, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _colorButton({
    required Color color,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    const minSize = Size(0, 28);
    const visual = VisualDensity.compact;

    if (selected) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: shape,
          padding: padding,
          minimumSize: minSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: visual,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: ec.eventLightBorderColor),
        backgroundColor: Colors.white,
        shape: shape,
        padding: EdgeInsets.zero,
        minimumSize: minSize,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: visual,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: color)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final critCfg = configs[rm.AlarmLevel.critical];
    final untilCfg = configs[rm.AlarmLevel.until];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text('알람', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _colorButton(
                    color: Colors.green,
                    selected: selected == rm.AlarmLevel.normal,
                    label: '일반 알람',
                    onTap: () => onSelected(rm.AlarmLevel.normal),
                  ),
                  _colorButton(
                    color: Colors.orange,
                    selected: selected == rm.AlarmLevel.critical,
                    label: '1회 울림',
                    onTap: () async {
                      final ok = await _openConfigDialog(context, rm.AlarmLevel.critical);
                      if (ok) onSelected(rm.AlarmLevel.critical);
                    },
                  ),
                  _colorButton(
                    color: Colors.red,
                    selected: selected == rm.AlarmLevel.until,
                    label: '정지 시까지',
                    onTap: () async {
                      final ok = await _openConfigDialog(context, rm.AlarmLevel.until);
                      if (ok) onSelected(rm.AlarmLevel.until);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        // ▼▼▼ 요약 칩은 showInlineSummary가 true일 때만 표시
        if (showInlineSummary && critCfg != null && !critCfg.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((critCfg.sound?.isNotEmpty ?? false))
                  _wrapShadow(_chip(critCfg.sound!, Colors.orange, icon: Icons.music_note), Colors.orange),
                if ((critCfg.tts?.isNotEmpty ?? false))
                  _wrapShadow(_chip(critCfg.tts!, Colors.orange, icon: Icons.record_voice_over), Colors.orange),
              ],
            ),
          ),

        if (showInlineSummary && untilCfg != null && !untilCfg.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((untilCfg.sound?.isNotEmpty ?? false))
                  _wrapShadow(_chip(untilCfg.sound!, Colors.red, icon: Icons.music_note), Colors.red),
                if ((untilCfg.tts?.isNotEmpty ?? false))
                  _wrapShadow(_chip(untilCfg.tts!, Colors.red, icon: Icons.record_voice_over), Colors.red),
              ],
            ),
          ),
      ],
    );
  }
}
