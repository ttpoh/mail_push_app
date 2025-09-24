import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/device/alarm_setting_sync.dart';

typedef BoolSetter = void Function(bool);

Future<void> showAlarmSettingsDialogWithServerDefaults({
  required BuildContext context,
  required AlarmSettingSync sync,
  bool fallbackNormalOn = true,
  bool fallbackCriticalOn = false,
  bool fallbackCriticalUntilStopped = false,
  required BoolSetter onNormalChanged,
  required BoolSetter onCriticalChanged,
  required BoolSetter onCriticalUntilChanged,
  required VoidCallback onOpenAppNotificationSettings,
}) async {
  final server = await sync.loadFromServerAndSeedPrefs(alsoSeedPrefs: true);

  final initialNormal = server.normalOn ?? fallbackNormalOn;
  final initialCritical = server.criticalOn ?? fallbackCriticalOn;
  final initialUntil = server.criticalUntil ?? fallbackCriticalUntilStopped;

  await showAlarmSettingsDialog(
    context: context,
    sync: sync,
    normalOn: initialNormal,
    criticalOn: initialCritical,
    criticalUntilStopped: initialUntil,
    onNormalChanged: onNormalChanged,
    onCriticalChanged: onCriticalChanged,
    onCriticalUntilChanged: onCriticalUntilChanged,
    onOpenAppNotificationSettings: onOpenAppNotificationSettings,
  );
}

class _DebouncedFlagSaver {
  final AlarmSettingSync sync;
  final Duration delay;
  Timer? _timer;
  bool? _normal;
  bool? _critical;
  bool? _until;

  _DebouncedFlagSaver({required this.sync, this.delay = const Duration(milliseconds: 500)});

  void queue({bool? normal, bool? critical, bool? until}) {
    if (normal != null) _normal = normal;
    if (critical != null) _critical = critical;
    if (until != null) _until = until;

    _timer?.cancel();
    _timer = Timer(delay, () async {
      await flush();
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_normal == null && _critical == null && _until == null) return;
    await sync.patchFlags(
      normalOn: _normal,
      criticalOn: _critical,
      criticalUntilStopped: _until,
    );
    _normal = null; _critical = null; _until = null;
  }
}

Future<void> showAlarmSettingsDialog({
  required BuildContext context,
  required AlarmSettingSync sync,
  required bool normalOn,
  required bool criticalOn,
  required bool criticalUntilStopped,
  required BoolSetter onNormalChanged,
  required BoolSetter onCriticalChanged,
  required BoolSetter onCriticalUntilChanged,
  required VoidCallback onOpenAppNotificationSettings,
}) async {
  final t = AppLocalizations.of(context)!;

  await showDialog(
    context: context,
    builder: (ctx) {
      bool _normal = normalOn;
      bool _critical = criticalOn;
      bool _untilStopped = criticalUntilStopped;

      final saver = _DebouncedFlagSaver(sync: sync);

      // 초기 모순 보정: until=true인데 critical=false면 강제로 ON
      if (_untilStopped && !_critical) {
        _critical = true;
        onCriticalChanged(true);
        // ✅ 한 번에 같이 전송 (critical=1, until=1)
        saver.queue(critical: true, until: true);    
      }

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
                    // 일반 알림
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.generalAlarmLabel, style: const TextStyle(color: Colors.black)),
                      subtitle: Text(t.generalAlarmSubtitle, style: TextStyle(color: ec.eventLightSecondaryTextColor)),
                      value: _normal,
                      activeColor: ec.eventPrimaryColor,
                      onChanged: (v) {
                        setModal(() => _normal = v);
                        onNormalChanged(v);
                        saver.queue(normal: v);
                      },
                    ),
                    Divider(height: 16, color: ec.eventLightDividerColor),

                    // 크리티컬 알림
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.criticalAlarmLabel, style: const TextStyle(color: Colors.black)),
                      subtitle: Text(t.criticalAlarmSubtitle, style: TextStyle(color: ec.eventLightSecondaryTextColor)),
                      value: _critical,
                      activeColor: ec.eventPrimaryColor,
                      onChanged: (v) {
                        if (v) {
                          // ON: 기본 모드는 1회 울림으로 강제
                          setModal(() {
                            _critical = true;
                            _untilStopped = false;
                          });
                          onCriticalChanged(true);
                          onCriticalUntilChanged(false);
                          saver.queue(critical: true, until: false);
                        } else {
                          // OFF: until도 자동 OFF
                          final wasUntil = _untilStopped;
                          setModal(() {
                            _critical = false;
                            _untilStopped = false;
                          });
                          onCriticalChanged(false);
                          if (wasUntil) onCriticalUntilChanged(false);
                          // ✅ 한 번에 같이 전송 (critical=0, until=0)
                          saver.queue(critical: false, until: false);
                        }
                      },
                    ),

                    const SizedBox(height: 8),

                    // 크리티컬 모드 (1회/정지 시까지)
                    IgnorePointer(
                      ignoring: !_critical,
                      child: Opacity(
                        opacity: _critical ? 1 : 0.5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.criticalAlarmModeLabel, style: const TextStyle(color: Colors.black)),
                            const SizedBox(height: 8),
                            SegmentedButton<bool>(
                              style: ButtonStyle(
                                side: MaterialStateProperty.all(BorderSide(color: ec.eventLightBorderColor)),
                                backgroundColor: MaterialStateProperty.resolveWith((states) {
                                  if (states.contains(MaterialState.selected)) return ec.eventPrimaryColor;
                                  return Colors.white;
                                }),
                                foregroundColor: MaterialStateProperty.resolveWith((states) {
                                  if (states.contains(MaterialState.selected)) return Colors.white;
                                  return ec.eventLightPrimaryTextColor;
                                }),
                              ),
                              segments: [
                                ButtonSegment<bool>(value: false, label: Text(t.ringOnce)),
                                ButtonSegment<bool>(value: true,  label: Text(t.ringUntilStopped)),
                              ],
                              selected: {_untilStopped},
                              onSelectionChanged: (s) {
                                final v = s.first; // false=1회, true=until
                                setModal(() => _untilStopped = v);
                                onCriticalUntilChanged(v);
                                // 어떤 모드를 선택하든 critical은 항상 ON으로 보장
                                if (!_critical) {
                                  setModal(() => _critical = true);
                                  onCriticalChanged(true);
                                }
                                // ✅ 한 번에 같이 전송: (critical=1, until=v)
                                saver.queue(critical: true, until: v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
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
