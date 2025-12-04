/// 리더보드 설정
/// 
/// Apple Developer Console과 Google Play Console에서
/// 생성한 리더보드 ID를 여기에 입력하세요.
class LeaderboardConfig {
  /// iOS Game Center 리더보드 ID
  /// 
  /// Apple Developer Console > App Store Connect > Game Center에서 생성
  /// 현재는 모든 레벨이 같은 리더보드를 사용 (나중에 레벨별로 분리 가능)
  static const String iosLevel1 = 'leaderboard_capybara';
  static const String iosLevel2 = 'leaderboard_capybara';
  static const String iosLevel3 = 'leaderboard_capybara';
  static const String iosLevel4 = 'leaderboard_capybara';
  static const String iosLevel5 = 'leaderboard_capybara';

  /// Android Google Play Games 리더보드 ID
  /// 
  /// Google Play Console > Play Games Services > 리더보드에서 생성
  /// 현재는 모든 레벨이 같은 리더보드를 사용 (나중에 레벨별로 분리 가능)
  static const String androidLevel1 = 'CgkI6rHltasIEAIQAQ';
  static const String androidLevel2 = 'CgkI6rHltasIEAIQAQ';
  static const String androidLevel3 = 'CgkI6rHltasIEAIQAQ';
  static const String androidLevel4 = 'CgkI6rHltasIEAIQAQ';
  static const String androidLevel5 = 'CgkI6rHltasIEAIQAQ';

  /// 리더보드 활성화 여부
  /// 
  /// 개발 중이거나 리더보드를 아직 설정하지 않았다면 false로 설정
  /// 프로덕션에서는 true로 설정
  static const bool isEnabled = true;

  /// 리더보드 설정 완료 여부 확인
  static bool get isConfigured {
    // 실제 ID가 설정되었는지 확인
    final hasIosConfig = iosLevel1 == 'leaderboard_capybara';
    final hasAndroidConfig = androidLevel1 == 'CgkI6rHltasIEAIQAQ';
    
    return isEnabled && (hasIosConfig || hasAndroidConfig);
  }

  /// 디버그 정보 출력
  static void printDebugInfo() {
    print('=== 리더보드 설정 정보 ===');
    print('활성화: $isEnabled');
    print('설정 완료: $isConfigured');
    print('iOS Level 1: $iosLevel1');
    print('Android Level 1: $androidLevel1');
    print('========================');
  }
}

