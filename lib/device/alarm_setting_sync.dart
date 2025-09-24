import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_push_app/api/api_client.dart';

/// 어떤 메일 서비스든 공통으로 사용하는 "알람/디바이스 업서트" 유틸
class AlarmSettingSync {
  final ApiClient api;
  final FirebaseMessaging fcm;
  final FlutterSecureStorage secureStorage;

  bool _syncing = false;

  AlarmSettingSync({
    required this.api,
    FirebaseMessaging? fcmInstance,
    FlutterSecureStorage? storage,
  })  : fcm = fcmInstance ?? FirebaseMessaging.instance,
        secureStorage = storage ?? const FlutterSecureStorage();

  /// ✅ 앱 실행 시: device_id + platform + fcm_token + "알람 기본값"을 서버에 업서트
  ///   - 기본값: normalOn=true, criticalOn=false, criticalUntilStopped=false
  ///   - overwrite=false: 기존 사용자 설정이 있으면 덮어쓰지 않음(권장)
  Future<void> upsertInitialDeviceWithDefaults({
    bool defaultNormalOn = true,
    bool defaultCriticalOn = false,
    bool defaultCriticalUntil = false,
    bool overwrite = false,
  }) async {
    try {
      final deviceId = await secureStorage.read(key: 'app_device_id');
      if (deviceId == null || deviceId.isEmpty) {
        debugPrint('⚠️ upsertInitialDeviceWithDefaults: device_id 없음');
        return;
      }

      final fcmToken = await fcm.getToken();

      final ok = await api.upsertAlarmSetting(
        deviceId: deviceId,
        platform: Platform.isIOS ? 'ios' : 'android',
        fcmToken: fcmToken,
        normalOn: defaultNormalOn,
        criticalOn: defaultCriticalOn,
        criticalUntilStopped: defaultCriticalUntil,
        // 서버 라우트가 overwrite 파라미터를 쓰지 않는다면 무시됨
        overwrite: overwrite,
      );

      debugPrint(ok
          ? '✅ upsertInitialDeviceWithDefaults ok'
          : '⚠️ upsertInitialDeviceWithDefaults failed');
    } catch (e) {
      debugPrint('⚠️ upsertInitialDeviceWithDefaults error: $e');
    }
  }

  /// 최초 앱 실행/로그인 전에도 호출 가능:
  /// device_id + platform + fcm_token 만 서버에 올림 (email은 생략)
  Future<void> upsertInitialDevice() async {
    try {
      final deviceId = await secureStorage.read(key: 'app_device_id');
      if (deviceId == null || deviceId.isEmpty) return;

      final fcmToken = await fcm.getToken();
      await api.upsertAlarmSetting(
        deviceId: deviceId,
        platform: Platform.isIOS ? 'ios' : 'android',
        fcmToken: fcmToken,
      );
      debugPrint('✅ upsertInitialDevice ok');
    } catch (e) {
      debugPrint('⚠️ upsertInitialDevice error: $e');
    }
  }

  /// 로그인 직후(이메일 확보 직후) 또는 알람 설정 변경 시 호출:
  /// email + (옵션)fcm + (옵션)알람 플래그를 서버에 업서트
  /// ✅ 기본 동작을 "서버값 유지"로 바꿔 사용자 설정을 덮지 않도록 함.
  Future<void> upsertAfterLogin({
    required String email,
    bool pushFlagsFromPrefs = false, // 기본 false(서버값 존중)
    bool alsoSendFcmToken = true,
  }) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final deviceId = await secureStorage.read(key: 'app_device_id');
      debugPrint('🔎 upsertAfterLogin deviceId: $deviceId');

      if (deviceId == null || deviceId.isEmpty) {
        _syncing = false;
        return;
      }

      String? fcmToken;
      if (alsoSendFcmToken) {
        fcmToken = await fcm.getToken();
      }

      bool? normalOn;
      bool? criticalOn;
      bool? criticalUntil;

      if (pushFlagsFromPrefs) {
        final prefs = await SharedPreferences.getInstance();
        normalOn = prefs.getBool('alarm_normal_on');
        criticalOn = prefs.getBool('alarm_critical_on');
        criticalUntil = prefs.getBool('alarm_critical_until_stopped');
      }

      final ok = await api.upsertAlarmSetting(
        deviceId: deviceId,
        platform: '', // 빈 문자열이면 서버에서 기존값 유지(백엔드 로직)
        emailAddress: email,
        fcmToken: fcmToken,
        normalOn: normalOn,                 // null이면 서버 미변경
        criticalOn: criticalOn,             // null이면 서버 미변경
        criticalUntilStopped: criticalUntil,// null이면 서버 미변경
        overwrite: false,
      );
      debugPrint(ok ? '✅ upsertAfterLogin ok' : '⚠️ upsertAfterLogin failed');
    } catch (e) {
      debugPrint('⚠️ upsertAfterLogin error: $e');
    } finally {
      _syncing = false;
    }
  }

  /// ✅ 서버 → 로컬 Prefs 동기화 (UI 초기값에 사용)
  Future<({bool? normalOn, bool? criticalOn, bool? criticalUntil})>
      loadFromServerAndSeedPrefs({bool alsoSeedPrefs = true}) async {
    try {
      final deviceId = await secureStorage.read(key: 'app_device_id');
      if (deviceId == null || deviceId.isEmpty) {
        debugPrint('⚠️ loadFromServer: deviceId missing');
        return (normalOn: null, criticalOn: null, criticalUntil: null);
      }

      final res = await api.getAlarmSetting(deviceId: deviceId);
      if (res == null || res['found'] != true) {
        debugPrint('ℹ️ loadFromServer: no row found for deviceId');
        return (normalOn: null, criticalOn: null, criticalUntil: null);
      }

      final bool? n = res['normal_on'] is bool ? res['normal_on'] as bool : (res['normal_on'] == 1);
      final bool? c = res['critical_on'] is bool ? res['critical_on'] as bool : (res['critical_on'] == 1);
      final bool? u = res['critical_until_stopped'] is bool
          ? res['critical_until_stopped'] as bool
          : (res['critical_until_stopped'] == 1);

      if (alsoSeedPrefs) {
        final prefs = await SharedPreferences.getInstance();
        if (n != null) await prefs.setBool('alarm_normal_on', n);
        if (c != null) await prefs.setBool('alarm_critical_on', c);
        if (u != null) await prefs.setBool('alarm_critical_until_stopped', u);
      }

      return (normalOn: n, criticalOn: c, criticalUntil: u);
    } catch (e) {
      debugPrint('⚠️ loadFromServerAndSeedPrefs error: $e');
      return (normalOn: null, criticalOn: null, criticalUntil: null);
    }
  }

  /// ✅ 부분 플래그 패치(디바운스 저장용): 전달된 값만 서버가 갱신, null은 미변경
  Future<bool> patchFlags({
    bool? normalOn,
    bool? criticalOn,
    bool? criticalUntilStopped,
  }) async {
    try {
      final deviceId = await secureStorage.read(key: 'app_device_id');
      if (deviceId == null || deviceId.isEmpty) return false;

      // 아무 값도 없으면 호출 불필요
      if (normalOn == null && criticalOn == null && criticalUntilStopped == null) {
        return true;
      }

      final ok = await api.upsertAlarmSetting(
        deviceId: deviceId,
        platform: '', // 미변경
        normalOn: normalOn,
        criticalOn: criticalOn,
        criticalUntilStopped: criticalUntilStopped,
      );

      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        if (normalOn != null) await prefs.setBool('alarm_normal_on', normalOn);
        if (criticalOn != null) await prefs.setBool('alarm_critical_on', criticalOn);
        if (criticalUntilStopped != null) {
          await prefs.setBool('alarm_critical_until_stopped', criticalUntilStopped);
        }
      }
      return ok;
    } catch (e) {
      debugPrint('⚠️ patchFlags error: $e');
      return false;
    }
  }
}
