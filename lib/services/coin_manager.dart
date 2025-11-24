import 'package:shared_preferences/shared_preferences.dart';

/// 코인 관리 서비스
class CoinManager {
  static const String _coinKey = 'user_coins';
  static const int _initialCoins = 0; // 초기 코인

  /// 현재 코인 가져오기
  static Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    final coins = prefs.getInt(_coinKey);
    
    // 첫 실행시 초기 코인 지급
    if (coins == null) {
      await _setCoins(_initialCoins);
      return _initialCoins;
    }
    
    return coins;
  }

  /// 코인 추가
  static Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    
    final currentCoins = await getCoins();
    await _setCoins(currentCoins + amount);
  }

  /// 코인 사용
  static Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return false;
    
    final currentCoins = await getCoins();
    if (currentCoins < amount) {
      return false; // 코인 부족
    }
    
    await _setCoins(currentCoins - amount);
    return true;
  }

  /// 코인 설정 (내부 사용)
  static Future<void> _setCoins(int coins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coinKey, coins);
  }

  /// 코인 리셋 (테스트용)
  static Future<void> resetCoins() async {
    await _setCoins(_initialCoins);
  }
}

