import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

/// 디바이스/앱 고유 ID + 플랫폼 이름을 보유하는 VO
class DeviceIdentity {
  final String deviceId;   // 안정적 앱 고유 ID (Keychain/Keystore에 저장)
  final String platform;   // 'ios' | 'android'
  const DeviceIdentity({required this.deviceId, required this.platform});
}

/// 플랫폼별 고유 Device ID를 우선 시도하고,
/// 실패 시 앱 전용 UUID를 생성하여 보관/재사용.
/// - iOS: IDFV(identifierForVendor) 우선 → 실패 시 UUID
/// - Android: ANDROID_ID(Settings.Secure.ANDROID_ID) 우선 → 실패 시 UUID
/// - 최종 값은 FlutterSecureStorage(Keychain/Keystore)에 저장되어 재실행 시 동일
class DeviceIdService {
  static const _storage = FlutterSecureStorage();
  static const _appDeviceIdKey = 'app_device_id';
  static const _channel = MethodChannel('com.secure.mail_push_app/device_id'); // (옵션) 네이티브 폴백 채널

  /// 앱에서 사용할 "안정적 고유 ID"를 반환 (저장된 값 우선)
  static Future<String> getStableAppDeviceId() async {
    // 1) 캐시(보안 저장소)에 있으면 그 값 사용
    final cached = await _storage.read(key: _appDeviceIdKey);
    if (cached != null && cached.isNotEmpty) return cached;

    String? candidate;

    // 2) device_info_plus로 OS 고유식별자 시도
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;             // identifierForVendor (IDFV)
        candidate = ios.identifierForVendor;
      } else if (Platform.isAndroid) {
        final and = await info.androidInfo;         // ANDROID_ID (SSAID)
        candidate = and.id;                         // device_info_plus에서 제공
      }
    } catch (_) {
      // ignore
    }

    // 3) (옵션) 네이티브 채널 폴백 (필요할 때만)
    if (candidate == null || candidate.isEmpty) {
      try {
        if (Platform.isIOS) {
          candidate = await _channel.invokeMethod<String>('getIdfv');
        } else if (Platform.isAndroid) {
          candidate = await _channel.invokeMethod<String>('getAndroidId');
        }
      } catch (_) {
        // ignore
      }
    }

    // 4) 그래도 없으면 UUID 생성
    candidate ??= const Uuid().v4();

    // 5) Keychain/Keystore 에 저장 → 다음 실행부터 동일값 사용
    await _storage.write(key: _appDeviceIdKey, value: candidate);
    return candidate;
  }

  /// 플랫폼명 반환 ('ios' | 'android')
  static String get platformName => Platform.isIOS ? 'ios' : 'android';

  /// 편의 메서드: DeviceIdentity 한 번에 얻기
  static Future<DeviceIdentity> getIdentity() async {
    final id = await getStableAppDeviceId();
    return DeviceIdentity(deviceId: id, platform: platformName);
  }

  /// (디버그용) 앱 고유 ID 초기화
  static Future<void> resetStoredId() async {
    await _storage.delete(key: _appDeviceIdKey);
  }

  
}
