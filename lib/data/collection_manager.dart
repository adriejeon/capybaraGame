import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// 컬렉션 결과 모델
class CollectionResult {
  final bool isNewCard;
  final CollectionItem? card;

  CollectionResult({
    required this.isNewCard,
    required this.card,
  });
}

/// 컬렉션 아이템 모델
class CollectionItem {
  final int id;
  final GameDifficulty difficulty;
  final String imagePath;
  final bool isUnlocked;
  final bool isNew; // NEW 태그 표시 여부

  CollectionItem({
    required this.id,
    required this.difficulty,
    required this.imagePath,
    required this.isUnlocked,
    this.isNew = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'difficulty': difficulty.name,
      'imagePath': imagePath,
      'isUnlocked': isUnlocked,
      'isNew': isNew,
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'],
      difficulty: GameDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      imagePath: json['imagePath'],
      isUnlocked: json['isUnlocked'] ?? false,
      isNew: json['isNew'] ?? false, // 기존 데이터 호환성을 위해 기본값 false
    );
  }

  CollectionItem copyWith({bool? isUnlocked, bool? isNew}) {
    return CollectionItem(
      id: id,
      difficulty: difficulty,
      imagePath: imagePath,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isNew: isNew ?? this.isNew,
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
      try {
        // 저장된 데이터가 있으면 로드
        final jsonList = jsonDecode(collectionData) as List;
        _collection = jsonList.map((json) {
          // 안전하게 JSON 파싱
          final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
          return CollectionItem.fromJson(safeJson);
        }).toList();
      } catch (e) {
        // 데이터 파싱 실패 시 기본 컬렉션 생성
        print('컬렉션 데이터 파싱 실패, 기본 컬렉션 생성: $e');
        _collection = _createDefaultCollection();
        await _saveCollection();
      }
    } else {
      // 처음 실행 시 기본 컬렉션 생성
      _collection = _createDefaultCollection();
      await _saveCollection();
    }
  }

  /// 기본 컬렉션 생성 (45개 슬롯)
  List<CollectionItem> _createDefaultCollection() {
    final List<CollectionItem> items = [];

    // Level 1 카드들 (1-10번 슬롯)
    for (int i = 1; i <= 10; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level1,
        imagePath: _defaultImagePath,
        isUnlocked: false,
      ));
    }

    // Level 2 카드들 (11-20번 슬롯)
    for (int i = 11; i <= 20; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level2,
        imagePath: _defaultImagePath,
        isUnlocked: false,
      ));
    }

    // Level 3 카드들 (21-30번 슬롯)
    for (int i = 21; i <= 30; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level3,
        imagePath: _defaultImagePath,
        isUnlocked: false,
      ));
    }

    // Level 4 카드들 (31-40번 슬롯)
    for (int i = 31; i <= 40; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level4,
        imagePath: _defaultImagePath,
        isUnlocked: false,
      ));
    }

    // Level 5 카드들 (41-55번 슬롯)
    for (int i = 41; i <= 55; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level5,
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
          isNewCard: false, card: existingCard);
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
          card: existingRandomCard);
    }

    // 첫 번째 잠금된 슬롯에 새 카드 추가
    final selectedSlot = lockedCards.first;
    final index = _collection.indexWhere((item) => item.id == selectedSlot.id);

    _collection[index] = CollectionItem(
      id: selectedSlot.id,
      difficulty: selectedSlot.difficulty,
      imagePath: selectedImagePath,
      isUnlocked: true,
      isNew: true, // 새로 획득한 카드이므로 NEW 태그 표시
    );

    await _saveCollection();
    return CollectionResult(
        isNewCard: true,
        card: _collection[index]);
  }

  /// 난이도별 모든 가능한 카드 이미지 경로 반환
  List<String> _getAllPossibleCardsForDifficulty(GameDifficulty difficulty) {
    final List<String> cards = [];

    switch (difficulty) {
      case GameDifficulty.level1:
        // 아기 단계 - easy1-10 사용
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/easy$i.jpg');
        }
        break;
      case GameDifficulty.level2:
        // 어린이 단계 - basic1-10 사용
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/basic$i.jpg');
        }
        break;
      case GameDifficulty.level3:
        // 청소년 단계 - normal1-10 사용
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/normal$i.jpg');
        }
        break;
      case GameDifficulty.level4:
        // 어른 단계 - advanced1-10 사용
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/advanced$i.jpg');
        }
        break;
      case GameDifficulty.level5:
        // 신의 경지 - hard1-10 사용 + 추가 5개
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/hard$i.jpg');
        }
        // 추가 5개는 easy의 일부 사용
        for (int i = 11; i <= 15; i++) {
          cards.add('assets/capybara/collection/easy$i.jpg');
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

  /// NEW 태그 제거 (카드 클릭 시 호출)
  Future<void> removeNewTag(int cardId) async {
    final index = _collection.indexWhere((item) => item.id == cardId);
    if (index != -1 && _collection[index].isNew) {
      _collection[index] = _collection[index].copyWith(isNew: false);
      await _saveCollection();
    }
  }

  /// 특정 카드를 잠금 상태로 되돌리기 (다시 뽑기 기능용)
  Future<void> lockCard(int cardId) async {
    final index = _collection.indexWhere((item) => item.id == cardId);
    if (index != -1 && _collection[index].isUnlocked) {
      _collection[index] = CollectionItem(
        id: _collection[index].id,
        difficulty: _collection[index].difficulty,
        imagePath: '', // 이미지 경로 제거
        isUnlocked: false, // 잠금 상태로 변경
        isNew: false,
      );
      await _saveCollection();
    }
  }

  /// 컬렉션 초기화 (디버깅/테스트용)
  Future<void> resetCollection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collectionKey);
    await initializeCollection();
  }
}
