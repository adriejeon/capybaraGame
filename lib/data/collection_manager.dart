import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// 컬렉션 결과 모델
class CollectionResult {
  final bool isNewCard;
  final CollectionItem? card;
  final String message;

  CollectionResult({
    required this.isNewCard,
    required this.card,
    required this.message,
  });
}

/// 컬렉션 아이템 모델
class CollectionItem {
  final int id;
  final GameDifficulty difficulty;
  final String imagePath;
  final bool isUnlocked;

  CollectionItem({
    required this.id,
    required this.difficulty,
    required this.imagePath,
    required this.isUnlocked,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'difficulty': difficulty.name,
      'imagePath': imagePath,
      'isUnlocked': isUnlocked,
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'],
      difficulty: GameDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      imagePath: json['imagePath'],
      isUnlocked: json['isUnlocked'],
    );
  }

  CollectionItem copyWith({bool? isUnlocked}) {
    return CollectionItem(
      id: id,
      difficulty: difficulty,
      imagePath: imagePath,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

/// 컬렉션 관리자
class CollectionManager {
  static const String _collectionKey = 'capybara_collection';
  static const String _defaultImagePath =
      'assets/capybara/collection/collection.jpg';

  static final CollectionManager _instance = CollectionManager._internal();
  factory CollectionManager() => _instance;
  CollectionManager._internal();

  List<CollectionItem> _collection = [];

  /// 컬렉션 초기화 (45개 아이템)
  Future<void> initializeCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionData = prefs.getString(_collectionKey);

    if (collectionData != null) {
      // 저장된 데이터가 있으면 로드
      final jsonList = jsonDecode(collectionData) as List;
      _collection =
          jsonList.map((json) => CollectionItem.fromJson(json)).toList();
    } else {
      // 처음 실행 시 기본 컬렉션 생성
      _collection = _createDefaultCollection();
      await _saveCollection();
    }
  }

  /// 기본 컬렉션 생성 (45개 슬롯)
  List<CollectionItem> _createDefaultCollection() {
    final List<CollectionItem> items = [];

    // Easy 카드들 (1-20번 슬롯)
    for (int i = 1; i <= 20; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.easy,
        imagePath: _defaultImagePath,
        isUnlocked: false,
      ));
    }

    // Normal 카드들 (21-35번 슬롯)
    for (int i = 21; i <= 35; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.medium,
        imagePath: _defaultImagePath,
        isUnlocked: false,
      ));
    }

    // Hard 카드들 (36-45번 슬롯)
    for (int i = 36; i <= 45; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.hard,
        imagePath: _defaultImagePath,
        isUnlocked: false,
      ));
    }

    return items;
  }

  /// 컬렉션 데이터 저장
  Future<void> _saveCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _collection.map((item) => item.toJson()).toList();
    await prefs.setString(_collectionKey, jsonEncode(jsonList));
  }

  /// 게임 완료 시 새 카드 추가
  Future<CollectionResult> addNewCard(GameDifficulty difficulty) async {
    // 컬렉션이 비어있다면 초기화
    if (_collection.isEmpty) {
      await initializeCollection();
    }

    final random = Random();

    // 해당 난이도의 모든 가능한 카드 이미지 경로 생성
    final allPossibleCards = _getAllPossibleCardsForDifficulty(difficulty);

    // 랜덤으로 카드 선택
    final selectedImagePath =
        allPossibleCards[random.nextInt(allPossibleCards.length)];

    // 이미 같은 이미지로 잠금 해제된 카드가 있는지 확인
    final existingCard = _collection.firstWhere(
      (item) =>
          item.difficulty == difficulty &&
          item.isUnlocked &&
          item.imagePath == selectedImagePath,
      orElse: () => CollectionItem(
          id: -1, difficulty: difficulty, imagePath: '', isUnlocked: false),
    );

    if (existingCard.id != -1) {
      // 이미 존재하는 카드인 경우
      return CollectionResult(
          isNewCard: false, card: existingCard, message: "이미 수집한 카피바라입니다!");
    }

    // 새로운 카드인 경우, 잠금 해제되지 않은 슬롯 중 첫 번째에 추가
    final lockedCards = _collection
        .where((item) => item.difficulty == difficulty && !item.isUnlocked)
        .toList();

    if (lockedCards.isEmpty) {
      // 모든 슬롯이 차있는 경우 (이론적으로는 위에서 걸러져야 함)
      final unlockedCards = _collection
          .where((item) => item.difficulty == difficulty && item.isUnlocked)
          .toList();

      final existingRandomCard =
          unlockedCards[random.nextInt(unlockedCards.length)];
      return CollectionResult(
          isNewCard: false,
          card: existingRandomCard,
          message: "이미 수집한 카피바라입니다!");
    }

    // 첫 번째 잠금된 슬롯에 새 카드 추가
    final selectedSlot = lockedCards.first;
    final index = _collection.indexWhere((item) => item.id == selectedSlot.id);

    _collection[index] = CollectionItem(
      id: selectedSlot.id,
      difficulty: selectedSlot.difficulty,
      imagePath: selectedImagePath,
      isUnlocked: true,
    );

    await _saveCollection();
    return CollectionResult(
        isNewCard: true,
        card: _collection[index],
        message: "새로운 카피바라를 발견했습니다!");
  }

  /// 난이도별 모든 가능한 카드 이미지 경로 반환
  List<String> _getAllPossibleCardsForDifficulty(GameDifficulty difficulty) {
    final List<String> cards = [];

    switch (difficulty) {
      case GameDifficulty.easy:
        for (int i = 1; i <= 20; i++) {
          cards.add('assets/capybara/collection/easy$i.jpg');
        }
        break;
      case GameDifficulty.medium:
        for (int i = 1; i <= 15; i++) {
          cards.add('assets/capybara/collection/normal$i.jpg');
        }
        break;
      case GameDifficulty.hard:
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/hard$i.jpg');
        }
        break;
    }

    return cards;
  }

  /// 전체 컬렉션 반환
  List<CollectionItem> get collection => List.unmodifiable(_collection);

  /// 잠금 해제된 카드 수 반환
  int get unlockedCount => _collection.where((item) => item.isUnlocked).length;

  /// 전체 카드 수 반환
  int get totalCount => _collection.length;

  /// 난이도별 잠금 해제된 카드 수 반환
  int getUnlockedCountByDifficulty(GameDifficulty difficulty) {
    return _collection
        .where((item) => item.difficulty == difficulty && item.isUnlocked)
        .length;
  }

  /// 난이도별 전체 카드 수 반환
  int getTotalCountByDifficulty(GameDifficulty difficulty) {
    return _collection.where((item) => item.difficulty == difficulty).length;
  }

  /// 컬렉션 초기화 (디버깅/테스트용)
  Future<void> resetCollection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collectionKey);
    await initializeCollection();
  }
}
