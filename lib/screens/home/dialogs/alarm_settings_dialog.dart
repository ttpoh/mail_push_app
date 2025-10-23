import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/device/alarm_setting_sync.dart';
import 'package:mail_push_app/fcm/fcm_service.dart'; // ⬅︎ loopRunning 구독용

typedef VoidAsync = FutureOr<void> Function();
typedef BoolSetter = void Function(bool);

// ===== 상단 import/typedef 동일 =====

Future<void> showAlarmSettingsDialogWithServerDefaults({
  required BuildContext context,
  required AlarmSettingSync sync,
  bool fallbackNormalOn = true,
  required BoolSetter onNormalChanged,
  required VoidCallback onOpenAppNotificationSettings,
  required VoidAsync onStopAlarm,
}) async {
  final server = await sync.loadFromServerAndSeedPrefs(alsoSeedPrefs: true);
  final initialNormal = server.normalOn ?? fallbackNormalOn;

  await showAlarmSettingsDialog(
    context: context,
    sync: sync,
    normalOn: initialNormal,
    onNormalChanged: onNormalChanged,
    onOpenAppNotificationSettings: onOpenAppNotificationSettings,
    onStopAlarm: onStopAlarm,
  );
}

class _DebouncedFlagSaver {
  final AlarmSettingSync sync;
  final Duration delay;
  Timer? _timer;
  bool? _normal;

  _DebouncedFlagSaver({required this.sync, this.delay = const Duration(milliseconds: 500)});

  void queue({bool? normal}) {
    if (normal != null) _normal = normal;
    _timer?.cancel();
    _timer = Timer(delay, () async { await flush(); });
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_normal == null) return;
    await sync.patchFlags(normalOn: _normal); // ✅ normalOn만 패치
    _normal = null;
  }
}

Future<void> showAlarmSettingsDialog({
  required BuildContext context,
  required AlarmSettingSync sync,
  required bool normalOn,
  required BoolSetter onNormalChanged,
  required VoidCallback onOpenAppNotificationSettings,
  required VoidCallback onStopAlarm,
}) async {
  final t = AppLocalizations.of(context)!;

  await showDialog(
    context: context,
    builder: (ctx) {
      bool _normal = normalOn;
      final saver = _DebouncedFlagSaver(sync: sync);

      return StatefulBuilder(
        builder: (ctx, setModal) => Theme(
          data: Theme.of(ctx).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: ec.eventPrimaryColor,
              surface: Colors.white,
              onSurface: ec.eventLightPrimaryTextColor,
            ),
          ),
          child: WillPopScope(
            onWillPop: () async { await saver.flush(); return true; },
            child: AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: ec.eventLightBorderColor),
              ),
              titleTextStyle: Theme.of(ctx).textTheme.titleLarge?.copyWith(color: ec.eventLightPrimaryTextColor),
              title: Text(t.alarmSettingsTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ 일반 알림 스위치만 남김
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.generalAlarmLabel, style: const TextStyle(color: Colors.black)),
                      // subtitle: Text(t.generalAlarmSubtitle, style: TextStyle(color: ec.eventLightSecondaryTextColor)),
                      value: _normal,
                      activeColor: ec.eventPrimaryColor,
                      onChanged: (v) {
                        setModal(() => _normal = v);
                        onNormalChanged(v);
                        saver.queue(normal: v);
                      },
                    ),
                    Divider(height: 16, color: ec.eventLightDividerColor),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.app_settings_alt, color: Colors.black54),
                      title: Text(t.openAppNotificationSettings, style: const TextStyle(color: Colors.black)),
                      onTap: onOpenAppNotificationSettings,
                    ),
                  ],
                ),
              ),
              actions: [
                // 반복 긴급 울리는 중일 때만 '알람 중지' 노출(유지)
                ValueListenableBuilder<bool>(
                  valueListenable: FcmService.loopRunning,
                  builder: (context, running, _) {
                    if (!running) return const SizedBox.shrink();
                    return TextButton.icon(
                      icon: const Icon(Icons.alarm_off_rounded),
                      label: Text(t.stopEmergencyAlarm),
                      onPressed: () async {
                        await saver.flush();
                        await Future.sync(onStopAlarm);
                      },
                    );
                  },
                ),
                TextButton(
                  onPressed: () async { await saver.flush(); Navigator.pop(ctx); },
                  child: Text(t.close, style: const TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
