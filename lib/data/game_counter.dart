import 'package:shared_preferences/shared_preferences.dart';

class GameCounter {
  static const String _gameCountKey = 'game_count';
  static const String _lastGameDateKey = 'last_game_date';

  // 하루에 2판까지는 광고 없이 플레이 가능
  static const int _maxFreeGames = 2;

  /// 게임 횟수 증가
  static Future<void> incrementGameCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today =
        DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD 형식
    final lastGameDate = prefs.getString(_lastGameDateKey);

    if (lastGameDate != today) {
      // 새로운 날이면 카운트 리셋
      await prefs.setInt(_gameCountKey, 1);
      await prefs.setString(_lastGameDateKey, today);
    } else {
      // 같은 날이면 카운트 증가
      final currentCount = prefs.getInt(_gameCountKey) ?? 0;
      await prefs.setInt(_gameCountKey, currentCount + 1);
    }
  }

  /// 오늘 게임 횟수 조회
  static Future<int> getTodayGameCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastGameDate = prefs.getString(_lastGameDateKey);

    if (lastGameDate != today) {
      // 새로운 날이면 0 반환
      return 0;
    } else {
      // 같은 날이면 저장된 카운트 반환
      return prefs.getInt(_gameCountKey) ?? 0;
    }
  }

  /// 광고를 보여야 하는지 확인 (3판째부터)
  static Future<bool> shouldShowAd() async {
    final gameCount = await getTodayGameCount();
    return gameCount >= _maxFreeGames;
  }

  /// 오늘 남은 무료 게임 횟수
  static Future<int> getRemainingFreeGames() async {
    final gameCount = await getTodayGameCount();
    return _maxFreeGames - gameCount;
  }

  /// 게임 횟수 리셋 (테스트용)
  static Future<void> resetGameCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gameCountKey);
    await prefs.remove(_lastGameDateKey);
  }
}
