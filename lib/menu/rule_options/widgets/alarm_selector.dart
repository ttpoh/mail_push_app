// lib/menu/rule_options/widgets/alarm_selector.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';
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
    this.showInlineSummary = true,
  });

  final rm.AlarmLevel selected;
  final Map<rm.AlarmLevel, AlarmConfig> configs;
  final ValueChanged<rm.AlarmLevel> onSelected;
  final void Function(rm.AlarmLevel, AlarmConfig) onConfigSaved;
  final bool showInlineSummary;

  static const List<String> _soundOptions = <String>[
    'default', 'bugle', 'siren', 'cuckoo', 'gun', 'horn', 'melting', 'orchestra', 'right',
  ];

  String _assetForSound(String? name) {
    final key = (name ?? 'default').trim().toLowerCase();
    return 'assets/sounds/$key.mp3';
  }

  Future<bool> _openConfigDialog(BuildContext context, rm.AlarmLevel level) async {
    final t = AppLocalizations.of(context)!;

    final existing = configs[level] ?? AlarmConfig(sound: 'default');
    final sound = ValueNotifier<String?>(existing.sound ?? 'default');
    final ttsCtrl = TextEditingController(text: existing.tts ?? '');

    final player = AudioPlayer();
    bool saved = false;

    Future<void> _preview() async {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
        await player.stop();
        await player.setAsset(_assetForSound(sound.value));
        await player.play();
      } catch (_) {}
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        level == rm.AlarmLevel.critical
                            ? t.oneTimeAlarm
                            : t.untilStoppedAlarm,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.soundLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<String?>(
                  valueListenable: sound,
                  builder: (_, value, __) {
                    return DropdownButtonFormField<String>(
                      value: value ?? 'default',
                      isExpanded: true,
                      items: _soundOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) async {
                        sound.value = v ?? 'default';
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
                        hintText: t.selectSoundHint,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.previewSound, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(t.previewSound),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ec.eventPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),

                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(t.ttsMessageLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ttsCtrl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.ttsMessageHint,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventLightBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: ec.eventPrimaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(t.cancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ec.eventPrimaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      onPressed: () {
                        saved = true;
                        Navigator.of(ctx).pop();
                      },
                      child: Text(t.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    try { await player.stop(); } catch (_) {}
    await player.dispose();

    if (saved) {
      onConfigSaved(
        level,
        AlarmConfig(sound: sound.value ?? 'default', tts: ttsCtrl.text.trim()),
      );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final critCfg = configs[rm.AlarmLevel.critical];
    final untilCfg = configs[rm.AlarmLevel.until];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(t.alarmSoundLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _alarmBtn(context, Colors.green, selected == rm.AlarmLevel.normal, t.generalAlarmLabel, () {
                    onSelected(rm.AlarmLevel.normal);
                  }),
                  _alarmBtn(context, Colors.orange, selected == rm.AlarmLevel.critical, t.oneTimeAlarm, () async {
                    final ok = await _openConfigDialog(context, rm.AlarmLevel.critical);
                    if (ok) onSelected(rm.AlarmLevel.critical);
                  }),
                  _alarmBtn(context, Colors.red, selected == rm.AlarmLevel.until, t.untilStoppedAlarm, () async {
                    final ok = await _openConfigDialog(context, rm.AlarmLevel.until);
                    if (ok) onSelected(rm.AlarmLevel.until);
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _alarmBtn(BuildContext context, Color color, bool selected, String label, VoidCallback onTap) {
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
}
