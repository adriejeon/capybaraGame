import 'package:shared_preferences/shared_preferences.dart';

/// 홈 화면에 표시될 카피바라 캐릭터 관리
class HomeCharacterManager {
  static const String _homeCharacterKey = 'home_character_id';
  static const String _defaultCharacterId = 'easy1';

  static final HomeCharacterManager _instance =
      HomeCharacterManager._internal();
  factory HomeCharacterManager() => _instance;
  HomeCharacterManager._internal();

  /// 현재 선택된 홈 캐릭터 ID
  String _currentCharacterId = _defaultCharacterId;

  /// 홈 캐릭터 초기화 (저장된 값 로드)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentCharacterId =
        prefs.getString(_homeCharacterKey) ?? _defaultCharacterId;
  }

  /// 현재 선택된 홈 캐릭터 ID 반환
  String get currentCharacterId => _currentCharacterId;

  /// 현재 선택된 홈 캐릭터 이미지 경로 반환
  String get currentCharacterImagePath =>
      _getHomeCharacterPath(_currentCharacterId);

  /// 홈 캐릭터 변경
  Future<void> setHomeCharacter(String characterId) async {
    _currentCharacterId = characterId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeCharacterKey, characterId);
  }

  /// 컬렉션 이미지 경로를 홈 캐릭터 ID로 변환
  /// 예: 'assets/capybara/collection/easy1.jpg' -> 'easy1'
  String convertCollectionPathToCharacterId(String collectionImagePath) {
    // 파일명 추출 (예: 'easy1.jpg')
    final fileName = collectionImagePath.split('/').last;
    // 확장자 제거 (예: 'easy1')
    final nameWithoutExt = fileName.split('.').first;

    // 이미 올바른 형식이므로 그대로 반환
    // easy1, normal1, hard1 등의 형식
    return nameWithoutExt;
  }

  /// 홈 캐릭터 이미지 경로 반환
  String _getHomeCharacterPath(String characterId) {
    return 'assets/home_capybara/$characterId.png';
  }

  /// 홈 캐릭터 초기화 (디버깅용)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeCharacterKey);
    _currentCharacterId = _defaultCharacterId;
  }
}

