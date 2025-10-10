import 'dart:io';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppEnvironment {
  static bool? _isAppStore;
  static const MethodChannel _channel = MethodChannel('app_environment');

  /// 앱스토어 버전인지 확인
  static Future<bool> isAppStore() async {
    if (_isAppStore != null) {
      return _isAppStore!;
    }

    try {
      if (Platform.isIOS) {
        // iOS: Method Channel을 사용하여 정확한 환경 감지
        final String environment = await _channel.invokeMethod(
          'getAppEnvironment',
        );
        print('AppEnvironment: iOS environment = $environment');

        // App Store에서만 실제 광고 사용
        _isAppStore = environment == 'appstore';
      } else if (Platform.isAndroid) {
        // Android: debug/release 구분
        final packageInfo = await PackageInfo.fromPlatform();
        _isAppStore = !packageInfo.packageName.contains('debug');
        print('AppEnvironment: Android isAppStore = $_isAppStore');
      } else {
        _isAppStore = false;
      }

      print('AppEnvironment: Final isAppStore = $_isAppStore');
      return _isAppStore!;
    } catch (e) {
      print('AppEnvironment: Error checking app store status: $e');
      // 에러 발생 시 안전하게 테스트 모드로 설정
      _isAppStore = false;
      return false;
    }
  }

  /// 현재 환경 정보 가져오기 (디버깅용)
  static Future<String> getCurrentEnvironment() async {
    try {
      if (Platform.isIOS) {
        return await _channel.invokeMethod('getAppEnvironment');
      } else if (Platform.isAndroid) {
        final packageInfo = await PackageInfo.fromPlatform();
        return packageInfo.packageName.contains('debug') ? 'debug' : 'release';
      }
      return 'unknown';
    } catch (e) {
      return 'error: $e';
    }
  }

  /// 환경 정보 리셋 (테스트용)
  static void reset() {
    _isAppStore = null;
  }
}
