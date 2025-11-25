import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 테마 아이템 모델
class ThemeItem {
  final String id;
  final String name;
  final String nameEn;
  final String imagePath;
  final int price;
  final bool isPurchased;
  final bool isDefault;

  ThemeItem({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.imagePath,
    required this.price,
    required this.isPurchased,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'imagePath': imagePath,
      'price': price,
      'isPurchased': isPurchased,
      'isDefault': isDefault,
    };
  }

  factory ThemeItem.fromJson(Map<String, dynamic> json) {
    return ThemeItem(
      id: json['id'],
      name: json['name'],
      nameEn: json['nameEn'],
      imagePath: json['imagePath'],
      price: json['price'],
      isPurchased: json['isPurchased'] ?? false,
      isDefault: json['isDefault'] ?? false,
    );
  }

  ThemeItem copyWith({bool? isPurchased}) {
    return ThemeItem(
      id: id,
      name: name,
      nameEn: nameEn,
      imagePath: imagePath,
      price: price,
      isPurchased: isPurchased ?? this.isPurchased,
      isDefault: isDefault,
    );
  }
}

/// 테마 관리자
class ThemeManager {
  static const String _themesKey = 'purchased_themes';
  static const String _currentThemeKey = 'current_theme';
  
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  List<ThemeItem> _themes = [];
  String _currentThemeId = 'default';

  /// 기본 테마 목록 생성
  List<ThemeItem> _createDefaultThemes() {
    return [
      ThemeItem(
        id: 'default',
        name: '기본 테마',
        nameEn: 'Default Theme',
        imagePath: '', // 기본 테마는 이미지 없음 (단색 배경)
        price: 0,
        isPurchased: true,
        isDefault: true,
      ),
      ThemeItem(
        id: 'beach',
        name: '해변 테마',
        nameEn: 'Beach Theme',
        imagePath: 'assets/theme/beach.jpg',
        price: 100,
        isPurchased: false,
      ),
      ThemeItem(
        id: 'city',
        name: '도시 테마',
        nameEn: 'City Theme',
        imagePath: 'assets/theme/city.jpg',
        price: 100,
        isPurchased: false,
      ),
      ThemeItem(
        id: 'onsen',
        name: '온천 테마',
        nameEn: 'Onsen Theme',
        imagePath: 'assets/theme/onsen.jpg',
        price: 100,
        isPurchased: false,
      ),
    ];
  }

  /// 테마 목록 초기화
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final themesData = prefs.getString(_themesKey);

    if (themesData != null) {
      try {
        final jsonList = jsonDecode(themesData) as List;
        _themes = jsonList.map((json) {
          final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
          return ThemeItem.fromJson(safeJson);
        }).toList();
      } catch (e) {
        print('테마 데이터 파싱 실패, 기본 테마 생성: $e');
        _themes = _createDefaultThemes();
        await _saveThemes();
      }
    } else {
      _themes = _createDefaultThemes();
      await _saveThemes();
    }

    // 현재 테마 로드
    _currentThemeId = prefs.getString(_currentThemeKey) ?? 'default';
  }

  /// 테마 목록 저장
  Future<void> _saveThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _themes.map((theme) => theme.toJson()).toList();
    await prefs.setString(_themesKey, jsonEncode(jsonList));
  }

  /// 현재 테마 저장
  Future<void> _saveCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentThemeKey, _currentThemeId);
  }

  /// 테마 구매
  Future<bool> purchaseTheme(String themeId) async {
    final index = _themes.indexWhere((theme) => theme.id == themeId);
    if (index == -1 || _themes[index].isPurchased) {
      return false;
    }

    _themes[index] = _themes[index].copyWith(isPurchased: true);
    await _saveThemes();
    return true;
  }

  /// 테마 선택
  Future<void> selectTheme(String themeId) async {
    final theme = _themes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => _themes[0],
    );

    if (!theme.isPurchased) {
      return;
    }

    _currentThemeId = themeId;
    await _saveCurrentTheme();
  }

  /// 전체 테마 목록 반환
  List<ThemeItem> get themes => List.unmodifiable(_themes);

  /// 현재 선택된 테마 ID 반환
  String get currentThemeId => _currentThemeId;

  /// 현재 선택된 테마 반환
  ThemeItem get currentTheme {
    return _themes.firstWhere(
      (theme) => theme.id == _currentThemeId,
      orElse: () => _themes[0],
    );
  }

  /// 구매한 테마 수 반환
  int get purchasedCount => _themes.where((theme) => theme.isPurchased).length;

  /// 전체 테마 수 반환
  int get totalCount => _themes.length;

  /// 테마 초기화 (테스트용)
  Future<void> resetThemes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themesKey);
    await prefs.remove(_currentThemeKey);
    await initialize();
  }
}

