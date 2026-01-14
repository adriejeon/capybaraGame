import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/daily_mission_service.dart';

/// 슬롯 ID 범위를 나타내는 클래스
class Range {
  final int start;
  final int end;

  Range(this.start, this.end);
}

/// 컬렉션 결과 모델
class CollectionResult {
  final bool isNewCard;
  final CollectionItem? card;

  CollectionResult({
    required this.isNewCard,
    required this.card,
  });
}

/// 이야기 모델
class Story {
  final int id;
  final GameDifficulty difficulty;
  final String titleKo;
  final String titleEn;
  final String descriptionKo;
  final String descriptionEn;
  final List<int> cardIds; // 이 이야기에 속한 카드 ID들 (10개)
  final bool isUnlocked; // 이야기 잠금 해제 여부

  Story({
    required this.id,
    required this.difficulty,
    required this.titleKo,
    required this.titleEn,
    required this.descriptionKo,
    required this.descriptionEn,
    required this.cardIds,
    this.isUnlocked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'difficulty': difficulty.name,
      'titleKo': titleKo,
      'titleEn': titleEn,
      'descriptionKo': descriptionKo,
      'descriptionEn': descriptionEn,
      'cardIds': cardIds,
      'isUnlocked': isUnlocked,
    };
  }

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      difficulty: GameDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      titleKo: json['titleKo'] ?? '',
      titleEn: json['titleEn'] ?? '',
      descriptionKo: json['descriptionKo'] ?? '',
      descriptionEn: json['descriptionEn'] ?? '',
      cardIds: List<int>.from(json['cardIds'] ?? []),
      isUnlocked: json['isUnlocked'] ?? false,
    );
  }

  Story copyWith({bool? isUnlocked}) {
    return Story(
      id: id,
      difficulty: difficulty,
      titleKo: titleKo,
      titleEn: titleEn,
      descriptionKo: descriptionKo,
      descriptionEn: descriptionEn,
      cardIds: cardIds,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

/// 컬렉션 아이템 모델
class CollectionItem {
  final int id;
  final GameDifficulty difficulty;
  final String imagePath;
  final bool isUnlocked;
  final bool isNew; // NEW 태그 표시 여부
  final int storyId; // 속한 이야기 ID

  CollectionItem({
    required this.id,
    required this.difficulty,
    required this.imagePath,
    required this.isUnlocked,
    this.isNew = false,
    required this.storyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'difficulty': difficulty.name,
      'imagePath': imagePath,
      'isUnlocked': isUnlocked,
      'isNew': isNew,
      'storyId': storyId,
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
      storyId: json['storyId'] ?? 0, // 기존 데이터 호환성을 위해 기본값 0
    );
  }

  CollectionItem copyWith(
      {bool? isUnlocked,
      bool? isNew,
      int? storyId,
      GameDifficulty? difficulty}) {
    return CollectionItem(
      id: id,
      difficulty: difficulty ?? this.difficulty,
      imagePath: imagePath,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isNew: isNew ?? this.isNew,
      storyId: storyId ?? this.storyId,
    );
  }
}

/// 컬렉션 관리자
class CollectionManager {
  static const String _collectionKey = 'capybara_collection';
  static const String _storiesKey = 'capybara_stories';
  static const String _collectionVersionKey = 'collection_version';
  static const int _currentCollectionVersion =
      5; // 버전 5: basic과 normal을 20개로 확장
  static const String _defaultImagePath =
      'assets/capybara/collection/collection.webp';

  static final CollectionManager _instance = CollectionManager._internal();
  factory CollectionManager() => _instance;
  CollectionManager._internal();

  List<CollectionItem> _collection = [];
  List<Story> _stories = [];

  /// 컬렉션 초기화 (70개 아이템)
  Future<void> initializeCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionData = prefs.getString(_collectionKey);
    final storiesData = prefs.getString(_storiesKey);
    final savedVersion = prefs.getInt(_collectionVersionKey) ?? 1;

    print('[컬렉션] 저장된 버전: $savedVersion, 현재 버전: $_currentCollectionVersion');

    // 버전이 다르면 강제 마이그레이션
    if (savedVersion < _currentCollectionVersion) {
      print('[컬렉션] 버전 업그레이드 필요 - 마이그레이션 시작');

      // 컬렉션 데이터 로드 (있으면)
      if (collectionData != null) {
        try {
          final jsonList = jsonDecode(collectionData) as List;
          _collection = jsonList.map((json) {
            final Map<String, dynamic> safeJson =
                Map<String, dynamic>.from(json);
            return CollectionItem.fromJson(safeJson);
          }).toList();
          print('[컬렉션] 기존 데이터 로드 완료: ${_collection.length}개');
        } catch (e) {
          print('컬렉션 데이터 파싱 실패: $e');
          _collection = _createDefaultCollection();
        }
      } else {
        _collection = _createDefaultCollection();
      }

      // 강제 마이그레이션 실행
      await _migrateCollectionSize();

      // 버전 업데이트
      await prefs.setInt(_collectionVersionKey, _currentCollectionVersion);
      print('[컬렉션] 버전 업데이트 완료: $_currentCollectionVersion');
    } else {
      // 일반 로드
      if (collectionData != null) {
        try {
          final jsonList = jsonDecode(collectionData) as List;
          _collection = jsonList.map((json) {
            final Map<String, dynamic> safeJson =
                Map<String, dynamic>.from(json);
            return CollectionItem.fromJson(safeJson);
          }).toList();
        } catch (e) {
          print('컬렉션 데이터 파싱 실패, 기본 컬렉션 생성: $e');
          _collection = _createDefaultCollection();
          await _saveCollection();
        }
      } else {
        _collection = _createDefaultCollection();
        await _saveCollection();
        await prefs.setInt(_collectionVersionKey, _currentCollectionVersion);
      }

      // 항상 마이그레이션 실행 (혹시 모를 누락 방지)
      await _migrateCollectionSize();
    }

    // 이야기 데이터 로드
    if (storiesData != null) {
      try {
        final jsonList = jsonDecode(storiesData) as List;
        _stories = jsonList.map((json) {
          final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
          return Story.fromJson(safeJson);
        }).toList();
      } catch (e) {
        print('이야기 데이터 파싱 실패, 기본 이야기 생성: $e');
        _stories = _createDefaultStories();
        await _saveStories();
      }
    } else {
      _stories = _createDefaultStories();
      await _saveStories();
    }

    // 기존 데이터 마이그레이션: storyId가 없는 경우 자동 할당
    await _migrateCollectionToStories();

    // 누락된 스토리 추가 (새로운 에피소드 그룹)
    await _migrateStories();

    // **중요**: 스토리 난이도 검증 및 수정
    await _validateAndFixStoryDifficulties();

    // 이야기 타이틀 업데이트 (최신 타이틀로 마이그레이션)
    await _updateStoryTitles();

    // 이야기 잠금 해제 상태 업데이트
    await _updateStoryUnlockStatus();

    // 이미지 경로 마이그레이션 (.jpg -> .webp)
    await _migrateImagePaths();
  }

  /// 이미지 경로 마이그레이션 (.jpg -> .webp)
  Future<void> _migrateImagePaths() async {
    bool needsSave = false;

    for (int i = 0; i < _collection.length; i++) {
      final item = _collection[i];

      // 잠금 해제된 아이템이고, 이미지 경로가 .jpg로 끝나는 경우
      if (item.isUnlocked &&
          item.imagePath.isNotEmpty &&
          item.imagePath != _defaultImagePath &&
          item.imagePath.endsWith('.jpg')) {
        // .jpg를 .webp로 변경
        final newImagePath = item.imagePath.replaceAll('.jpg', '.webp');

        print('[마이그레이션] 이미지 경로 변경: ${item.imagePath} -> $newImagePath');

        _collection[i] = CollectionItem(
          id: item.id,
          difficulty: item.difficulty,
          imagePath: newImagePath,
          isUnlocked: item.isUnlocked,
          isNew: item.isNew,
          storyId: item.storyId,
        );

        needsSave = true;
      }
    }

    if (needsSave) {
      await _saveCollection();
      print('[마이그레이션] 이미지 경로 마이그레이션 완료');
    }
  }

  /// 기본 컬렉션 생성
  List<CollectionItem> _createDefaultCollection() {
    final List<CollectionItem> items = [];

    // Level 1 카드들 - 에피소드 1 (1-10번 슬롯) - 이야기 1
    for (int i = 1; i <= 10; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level1,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 1,
      ));
    }
    // Level 1 카드들 - 에피소드 2 (11-20번 슬롯) - 이야기 7
    for (int i = 11; i <= 20; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level1,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 7,
      ));
    }

    // Level 2 카드들 - 에피소드 1 (21-30번 슬롯) - 이야기 2
    for (int i = 21; i <= 30; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level2,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 2,
      ));
    }
    // Level 2 카드들 - 에피소드 2 (31-40번 슬롯) - 이야기 8
    for (int i = 31; i <= 40; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level2,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 8,
      ));
    }

    // Level 3 카드들 - 에피소드 1 (41-50번 슬롯) - 이야기 3
    for (int i = 41; i <= 50; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level3,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 3,
      ));
    }
    // Level 3 카드들 - 에피소드 2 (51-60번 슬롯) - 이야기 9
    for (int i = 51; i <= 60; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level3,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 9,
      ));
    }

    // Level 4 카드들 (61-70번 슬롯) - 이야기 4
    for (int i = 61; i <= 70; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level4,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 4,
      ));
    }

    // Level 5 카드들 (71-80번 슬롯) - 이야기 5
    for (int i = 71; i <= 80; i++) {
      items.add(CollectionItem(
        id: i,
        difficulty: GameDifficulty.level5,
        imagePath: _defaultImagePath,
        isUnlocked: false,
        storyId: 5,
      ));
    }

    return items;
  }

  /// 기본 이야기 생성
  List<Story> _createDefaultStories() {
    return [
      // 아기 단계 - 에피소드 1
      Story(
        id: 1,
        difficulty: GameDifficulty.level1,
        titleKo: '걸음마 연습',
        titleEn: 'First Steps',
        descriptionKo: '작은 카피바라가 세상에 첫 발을 내딛는 이야기입니다.',
        descriptionEn:
            'A story about a small capybara taking its first steps into the world.',
        cardIds: List.generate(10, (i) => i + 1),
        isUnlocked: false,
      ),
      // 아기 단계 - 에피소드 2
      Story(
        id: 7,
        difficulty: GameDifficulty.level1,
        titleKo: '엄마처럼 하고 싶어!',
        titleEn: 'I Want to Be Like Mom!',
        descriptionKo: '작은 카피바라가 세상에 첫 발을 내딛는 이야기입니다.',
        descriptionEn:
            'A story about a small capybara taking its first steps into the world.',
        cardIds: List.generate(10, (i) => i + 11),
        isUnlocked: false,
      ),
      // 어린이 단계 - 에피소드 1
      Story(
        id: 2,
        difficulty: GameDifficulty.level2,
        titleKo: '친구가 좋아',
        titleEn: 'I Love Friends',
        descriptionKo: '카피바라가 친구들과 함께 성장해가는 이야기입니다.',
        descriptionEn: 'A story about a capybara growing up with friends.',
        cardIds: List.generate(10, (i) => i + 21),
        isUnlocked: false,
      ),
      // 어린이 단계 - 에피소드 2
      Story(
        id: 8,
        difficulty: GameDifficulty.level2,
        titleKo: '첫 이별',
        titleEn: 'First Goodbye',
        descriptionKo: '카피바라가 친구들과 함께 성장해가는 이야기입니다.',
        descriptionEn: 'A story about a capybara growing up with friends.',
        cardIds: List.generate(10, (i) => i + 31),
        isUnlocked: false,
      ),
      // 청소년 단계 - 에피소드 1
      Story(
        id: 3,
        difficulty: GameDifficulty.level3,
        titleKo: '첫 사랑',
        titleEn: 'First Love',
        descriptionKo: '카피바라가 새로운 도전에 맞서는 이야기입니다.',
        descriptionEn: 'A story about a capybara facing new challenges.',
        cardIds: List.generate(10, (i) => i + 41),
        isUnlocked: false,
      ),
      // 청소년 단계 - 에피소드 2
      Story(
        id: 9,
        difficulty: GameDifficulty.level3,
        titleKo: '나만의 감성',
        titleEn: 'My Own Sensibility',
        descriptionKo: '카피바라가 새로운 도전에 맞서는 이야기입니다.',
        descriptionEn: 'A story about a capybara facing new challenges.',
        cardIds: List.generate(10, (i) => i + 51),
        isUnlocked: false,
      ),
      // 어른 단계
      Story(
        id: 4,
        difficulty: GameDifficulty.level4,
        titleKo: '어른의 맛',
        titleEn: 'Adult\'s Taste',
        descriptionKo: '카피바라가 성숙한 어른으로 성장하는 이야기입니다.',
        descriptionEn: 'A story about a capybara growing into a mature adult.',
        cardIds: List.generate(10, (i) => i + 61),
        isUnlocked: false,
      ),
      // 신의 경지
      Story(
        id: 5,
        difficulty: GameDifficulty.level5,
        titleKo: '나를 화나게 하는 것',
        titleEn: 'What Makes Me Angry',
        descriptionKo: '카피바라가 최고의 경지에 도달하는 이야기입니다.',
        descriptionEn: 'A story about a capybara reaching the highest realm.',
        cardIds: List.generate(10, (i) => i + 71),
        isUnlocked: false,
      ),
    ];
  }

  /// 컬렉션 크기 마이그레이션 (45개 -> 70개)
  Future<void> _migrateCollectionSize() async {
    final defaultCollection = _createDefaultCollection();
    final Map<int, CollectionItem> existingItems = {};

    // 기존 컬렉션 아이템을 ID로 매핑
    for (var item in _collection) {
      existingItems[item.id] = item;
    }

    bool needsSave = false;
    final int expectedCount = defaultCollection
        .length; // 80개 (Level1: 20, Level2: 20, Level3: 20, Level4: 10, Level5: 10)

    print('[마이그레이션] 현재 컬렉션 크기: ${_collection.length}, 예상 크기: $expectedCount');
    print(
        '[마이그레이션] 현재 컬렉션 ID 범위: ${_collection.isEmpty ? "비어있음" : "${_collection.first.id} ~ ${_collection.last.id}"}');

    // **중요**: 난이도별 슬롯 개수 검증 및 수정
    final level1Count = _collection
        .where((item) => item.difficulty == GameDifficulty.level1)
        .length;
    final level2Count = _collection
        .where((item) => item.difficulty == GameDifficulty.level2)
        .length;
    final level3Count = _collection
        .where((item) => item.difficulty == GameDifficulty.level3)
        .length;
    final level4Count = _collection
        .where((item) => item.difficulty == GameDifficulty.level4)
        .length;
    final level5Count = _collection
        .where((item) => item.difficulty == GameDifficulty.level5)
        .length;

    print(
        '[마이그레이션] 난이도별 슬롯: L1=$level1Count(20), L2=$level2Count(20), L3=$level3Count(20), L4=$level4Count(10), L5=$level5Count(10)');

    // **중요**: ID 범위 기반 난이도 검증 및 수정
    // 슬롯 ID 1-20번은 반드시 level1이어야 함
    final wrongLevel1Slots = _collection
        .where((item) =>
            item.id >= 1 &&
            item.id <= 20 &&
            item.difficulty != GameDifficulty.level1)
        .toList();
    if (wrongLevel1Slots.isNotEmpty) {
      print('[마이그레이션] ID 1-20번 범위에 잘못된 난이도 슬롯 발견: ${wrongLevel1Slots.length}개');
      for (var wrong in wrongLevel1Slots) {
        print(
            '  - 슬롯 ID: ${wrong.id}, 잘못된 난이도: ${wrong.difficulty.name} -> level1로 수정');
        final wrongIndex =
            _collection.indexWhere((item) => item.id == wrong.id);
        if (wrongIndex != -1) {
          _collection[wrongIndex] =
              wrong.copyWith(difficulty: GameDifficulty.level1);
          needsSave = true;
        }
      }
    }

    // 슬롯 ID 21-40번은 반드시 level2이어야 함
    final wrongLevel2Slots = _collection
        .where((item) =>
            item.id >= 21 &&
            item.id <= 40 &&
            item.difficulty != GameDifficulty.level2)
        .toList();
    if (wrongLevel2Slots.isNotEmpty) {
      print(
          '[마이그레이션] ID 21-40번 범위에 잘못된 난이도 슬롯 발견: ${wrongLevel2Slots.length}개');
      for (var wrong in wrongLevel2Slots) {
        print(
            '  - 슬롯 ID: ${wrong.id}, 잘못된 난이도: ${wrong.difficulty.name} -> level2로 수정');
        final wrongIndex =
            _collection.indexWhere((item) => item.id == wrong.id);
        if (wrongIndex != -1) {
          _collection[wrongIndex] =
              wrong.copyWith(difficulty: GameDifficulty.level2);
          needsSave = true;
        }
      }
    }

    // 슬롯 ID 41-60번은 반드시 level3이어야 함
    final wrongLevel3Slots = _collection
        .where((item) =>
            item.id >= 41 &&
            item.id <= 60 &&
            item.difficulty != GameDifficulty.level3)
        .toList();
    if (wrongLevel3Slots.isNotEmpty) {
      print(
          '[마이그레이션] ID 41-60번 범위에 잘못된 난이도 슬롯 발견: ${wrongLevel3Slots.length}개');
      for (var wrong in wrongLevel3Slots) {
        print(
            '  - 슬롯 ID: ${wrong.id}, 잘못된 난이도: ${wrong.difficulty.name} -> level3로 수정');
        final wrongIndex =
            _collection.indexWhere((item) => item.id == wrong.id);
        if (wrongIndex != -1) {
          _collection[wrongIndex] =
              wrong.copyWith(difficulty: GameDifficulty.level3);
          needsSave = true;
        }
      }
    }

    // 슬롯 ID 61-70번은 반드시 level4이어야 함
    final wrongLevel4Slots = _collection
        .where((item) =>
            item.id >= 61 &&
            item.id <= 70 &&
            item.difficulty != GameDifficulty.level4)
        .toList();
    if (wrongLevel4Slots.isNotEmpty) {
      print(
          '[마이그레이션] ID 61-70번 범위에 잘못된 난이도 슬롯 발견: ${wrongLevel4Slots.length}개');
      for (var wrong in wrongLevel4Slots) {
        print(
            '  - 슬롯 ID: ${wrong.id}, 잘못된 난이도: ${wrong.difficulty.name} -> level4로 수정');
        final wrongIndex =
            _collection.indexWhere((item) => item.id == wrong.id);
        if (wrongIndex != -1) {
          _collection[wrongIndex] =
              wrong.copyWith(difficulty: GameDifficulty.level4);
          needsSave = true;
        }
      }
    }

    // 슬롯 ID 71-80번은 반드시 level5이어야 함
    final wrongLevel5Slots = _collection
        .where((item) =>
            item.id >= 71 &&
            item.id <= 80 &&
            item.difficulty != GameDifficulty.level5)
        .toList();
    if (wrongLevel5Slots.isNotEmpty) {
      print(
          '[마이그레이션] ID 71-80번 범위에 잘못된 난이도 슬롯 발견: ${wrongLevel5Slots.length}개');
      for (var wrong in wrongLevel5Slots) {
        print(
            '  - 슬롯 ID: ${wrong.id}, 잘못된 난이도: ${wrong.difficulty.name} -> level5로 수정');
        final wrongIndex =
            _collection.indexWhere((item) => item.id == wrong.id);
        if (wrongIndex != -1) {
          _collection[wrongIndex] =
              wrong.copyWith(difficulty: GameDifficulty.level5);
          needsSave = true;
        }
      }
    }

    // 각 난이도별로 올바른 개수로 재구성
    // Level1: 1-20번 (20개)
    if (level1Count != 20) {
      print('[마이그레이션] Level1 슬롯 개수 오류 감지 - 강제 재구성');
      _collection
          .removeWhere((item) => item.difficulty == GameDifficulty.level1);

      for (int i = 1; i <= 20; i++) {
        if (existingItems.containsKey(i) &&
            existingItems[i]!.difficulty == GameDifficulty.level1) {
          final existingItem = existingItems[i]!;
          final correctStoryId = (i >= 1 && i <= 10) ? 1 : 7;
          _collection.add(existingItem.copyWith(storyId: correctStoryId));
        } else {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level1,
            imagePath: _defaultImagePath,
            isUnlocked: false,
            storyId: (i >= 1 && i <= 10) ? 1 : 7,
          ));
        }
      }
      needsSave = true;
    }

    // Level2: 21-40번 (20개) - 21-30: storyId 2, 31-40: storyId 8
    if (level2Count != 20) {
      print('[마이그레이션] Level2 슬롯 개수 오류 감지 - 강제 재구성');

      // 기존 Level2 아이템들을 storyId별로 분류
      final existingLevel2Items = _collection
          .where((item) => item.difficulty == GameDifficulty.level2)
          .toList();
      final story2Items =
          existingLevel2Items.where((item) => item.storyId == 2).toList();
      final story8Items =
          existingLevel2Items.where((item) => item.storyId == 8).toList();

      // 기존 Level2 아이템 제거
      _collection
          .removeWhere((item) => item.difficulty == GameDifficulty.level2);

      // 새로운 범위로 재배치
      int story2Index = 0;
      int story8Index = 0;

      for (int i = 21; i <= 40; i++) {
        final correctStoryId = (i >= 21 && i <= 30) ? 2 : 8;
        CollectionItem? itemToUse;

        if (correctStoryId == 2 && story2Index < story2Items.length) {
          // storyId 2 아이템 사용
          itemToUse = story2Items[story2Index];
          story2Index++;
        } else if (correctStoryId == 8 && story8Index < story8Items.length) {
          // storyId 8 아이템 사용
          itemToUse = story8Items[story8Index];
          story8Index++;
        }

        if (itemToUse != null) {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level2,
            imagePath: itemToUse.imagePath,
            isUnlocked: itemToUse.isUnlocked,
            isNew: itemToUse.isNew,
            storyId: correctStoryId,
          ));
        } else {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level2,
            imagePath: _defaultImagePath,
            isUnlocked: false,
            storyId: correctStoryId,
          ));
        }
      }
      needsSave = true;
    }

    // Level3: 41-60번 (20개) - 41-50: storyId 3, 51-60: storyId 9
    if (level3Count != 20) {
      print('[마이그레이션] Level3 슬롯 개수 오류 감지 - 강제 재구성');

      // 기존 Level3 아이템들을 storyId별로 분류
      final existingLevel3Items = _collection
          .where((item) => item.difficulty == GameDifficulty.level3)
          .toList();
      final story3Items =
          existingLevel3Items.where((item) => item.storyId == 3).toList();
      final story9Items =
          existingLevel3Items.where((item) => item.storyId == 9).toList();

      // 기존 Level3 아이템 제거
      _collection
          .removeWhere((item) => item.difficulty == GameDifficulty.level3);

      // 새로운 범위로 재배치
      int story3Index = 0;
      int story9Index = 0;

      for (int i = 41; i <= 60; i++) {
        final correctStoryId = (i >= 41 && i <= 50) ? 3 : 9;
        CollectionItem? itemToUse;

        if (correctStoryId == 3 && story3Index < story3Items.length) {
          // storyId 3 아이템 사용
          itemToUse = story3Items[story3Index];
          story3Index++;
        } else if (correctStoryId == 9 && story9Index < story9Items.length) {
          // storyId 9 아이템 사용
          itemToUse = story9Items[story9Index];
          story9Index++;
        }

        if (itemToUse != null) {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level3,
            imagePath: itemToUse.imagePath,
            isUnlocked: itemToUse.isUnlocked,
            isNew: itemToUse.isNew,
            storyId: correctStoryId,
          ));
        } else {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level3,
            imagePath: _defaultImagePath,
            isUnlocked: false,
            storyId: correctStoryId,
          ));
        }
      }
      needsSave = true;
    }

    // Level4: 61-70번 (10개) - storyId 4
    if (level4Count != 10) {
      print('[마이그레이션] Level4 슬롯 개수 오류 감지 - 강제 재구성');
      _collection
          .removeWhere((item) => item.difficulty == GameDifficulty.level4);

      for (int i = 61; i <= 70; i++) {
        if (existingItems.containsKey(i) &&
            existingItems[i]!.difficulty == GameDifficulty.level4) {
          final existingItem = existingItems[i]!;
          _collection.add(existingItem.copyWith(storyId: 4));
        } else {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level4,
            imagePath: _defaultImagePath,
            isUnlocked: false,
            storyId: 4,
          ));
        }
      }
      needsSave = true;
    }

    // Level5: 71-80번 (10개) - storyId 5
    if (level5Count != 10) {
      print('[마이그레이션] Level5 슬롯 개수 오류 감지 - 강제 재구성');
      _collection
          .removeWhere((item) => item.difficulty == GameDifficulty.level5);

      for (int i = 71; i <= 80; i++) {
        if (existingItems.containsKey(i) &&
            existingItems[i]!.difficulty == GameDifficulty.level5) {
          final existingItem = existingItems[i]!;
          _collection.add(existingItem.copyWith(storyId: 5));
        } else {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level5,
            imagePath: _defaultImagePath,
            isUnlocked: false,
            storyId: 5,
          ));
        }
      }
      needsSave = true;
    }

    // 기본 컬렉션의 모든 아이템을 확인하고 누락된 항목 추가
    int addedCount = 0;
    for (var defaultItem in defaultCollection) {
      if (!_collection.any((item) => item.id == defaultItem.id)) {
        // 기존 아이템이 없으면 기본 아이템 추가
        _collection.add(defaultItem);
        needsSave = true;
        addedCount++;
        print(
            '[마이그레이션] 슬롯 ${defaultItem.id} 추가 (difficulty: ${defaultItem.difficulty.name}, storyId: ${defaultItem.storyId})');
      }
    }

    // ID 순서대로 정렬
    _collection.sort((a, b) => a.id.compareTo(b.id));

    if (needsSave) {
      await _saveCollection();
      print(
          '[마이그레이션] ${addedCount > 0 ? "$addedCount개 슬롯 추가," : ""} 총 ${_collection.length}개 슬롯');
    } else {
      print('[마이그레이션] 변경사항 없음');
    }

    // 신의 경지 단계의 슬롯을 항상 10개로 제한 (71-80만 유지, 81 이상 모두 제거)
    final level5Items = _collection
        .where((item) => item.difficulty == GameDifficulty.level5)
        .toList();
    final level5ItemsToRemove =
        level5Items.where((item) => item.id > 80).toList();
    if (level5ItemsToRemove.isNotEmpty) {
      _collection.removeWhere((item) => level5ItemsToRemove.contains(item));
      await _saveCollection();
    }

    // 신의 경지 단계가 정확히 10개인지 확인 및 정리
    final finalLevel5Count = _collection
        .where((item) => item.difficulty == GameDifficulty.level5)
        .length;
    if (finalLevel5Count != 10) {
      // 71-80번 슬롯만 남기고 나머지 모두 제거
      final allLevel5Items = _collection
          .where((item) => item.difficulty == GameDifficulty.level5)
          .toList();
      final itemsToRemove =
          allLevel5Items.where((item) => item.id < 71 || item.id > 80).toList();

      if (itemsToRemove.isNotEmpty) {
        _collection.removeWhere((item) => itemsToRemove.contains(item));
      }

      // 71-80번 슬롯이 없으면 추가
      for (int i = 71; i <= 80; i++) {
        if (!_collection.any((item) =>
            item.id == i && item.difficulty == GameDifficulty.level5)) {
          _collection.add(CollectionItem(
            id: i,
            difficulty: GameDifficulty.level5,
            imagePath: _defaultImagePath,
            isUnlocked: false,
            storyId: 5,
          ));
        }
      }
      _collection.sort((a, b) => a.id.compareTo(b.id));
      await _saveCollection();
    }
  }

  Future<void> _migrateCollectionToStories() async {
    bool needsSave = false;
    for (int i = 0; i < _collection.length; i++) {
      final item = _collection[i];
      int storyId = item.storyId;

      // storyId가 없거나 기존 구조인 경우 새 구조로 마이그레이션
      if (storyId == 0 || storyId == 6) {
        // 새 구조에 맞게 storyId 할당
        if (item.difficulty == GameDifficulty.level1) {
          if (item.id >= 1 && item.id <= 10) {
            storyId = 1; // 아기 에피소드 1
          } else if (item.id >= 11 && item.id <= 20) {
            storyId = 7; // 아기 에피소드 2
          }
        } else if (item.difficulty == GameDifficulty.level2) {
          if (item.id >= 21 && item.id <= 30) {
            storyId = 2; // 어린이 에피소드 1
          } else if (item.id >= 31 && item.id <= 40) {
            storyId = 8; // 어린이 에피소드 2
          }
        } else if (item.difficulty == GameDifficulty.level3) {
          if (item.id >= 41 && item.id <= 50) {
            storyId = 3; // 청소년 에피소드 1
          } else if (item.id >= 51 && item.id <= 60) {
            storyId = 9; // 청소년 에피소드 2
          }
        } else if (item.difficulty == GameDifficulty.level4) {
          if (item.id >= 61 && item.id <= 70) {
            storyId = 4; // 어른 단계
          }
        } else if (item.difficulty == GameDifficulty.level5) {
          if (item.id >= 71 && item.id <= 80) {
            storyId = 5; // 신의 경지
          }
        }

        if (storyId != item.storyId) {
          _collection[i] = _collection[i].copyWith(storyId: storyId);
          needsSave = true;
        }
      }
    }
    if (needsSave) {
      await _saveCollection();
    }
  }

  /// 누락된 스토리 추가 (새로운 에피소드 그룹 마이그레이션)
  Future<void> _migrateStories() async {
    final defaultStories = _createDefaultStories();
    final Map<int, Story> existingStories = {};

    // 기존 스토리를 ID로 매핑
    for (var story in _stories) {
      existingStories[story.id] = story;
    }

    bool needsSave = false;

    // 기본 스토리의 모든 아이템을 확인하고 누락된 항목 추가
    int addedStoryCount = 0;
    for (var defaultStory in defaultStories) {
      if (!existingStories.containsKey(defaultStory.id)) {
        // 기존 스토리가 없으면 기본 스토리 추가
        _stories.add(defaultStory);
        needsSave = true;
        addedStoryCount++;
      }
    }

    if (needsSave) {
      await _saveStories();
      if (addedStoryCount > 0) {
        print('스토리 마이그레이션: ${addedStoryCount}개 스토리 추가 완료');
      }
    }
  }

  /// 이야기 타이틀 업데이트 (최신 타이틀로 마이그레이션)
  Future<void> _updateStoryTitles() async {
    final defaultStories = _createDefaultStories();
    bool needsSave = false;

    for (var defaultStory in defaultStories) {
      final index = _stories.indexWhere((s) => s.id == defaultStory.id);
      if (index != -1) {
        final currentStory = _stories[index];
        // 타이틀이나 cardIds가 다르면 업데이트
        if (currentStory.titleKo != defaultStory.titleKo ||
            currentStory.titleEn != defaultStory.titleEn ||
            currentStory.descriptionKo != defaultStory.descriptionKo ||
            currentStory.descriptionEn != defaultStory.descriptionEn ||
            currentStory.cardIds.length != defaultStory.cardIds.length ||
            !_areCardIdsEqual(currentStory.cardIds, defaultStory.cardIds)) {
          _stories[index] = Story(
            id: currentStory.id,
            difficulty: currentStory.difficulty,
            titleKo: defaultStory.titleKo,
            titleEn: defaultStory.titleEn,
            descriptionKo: defaultStory.descriptionKo,
            descriptionEn: defaultStory.descriptionEn,
            cardIds: defaultStory.cardIds, // 기본 스토리의 cardIds 사용
            isUnlocked: currentStory.isUnlocked,
          );
          needsSave = true;
        }
      }
    }

    if (needsSave) {
      await _saveStories();
    }
  }

  /// cardIds가 동일한지 확인하는 헬퍼 함수
  bool _areCardIdsEqual(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  /// 스토리 난이도 검증 및 수정
  Future<void> _validateAndFixStoryDifficulties() async {
    bool needsSave = false;

    for (int i = 0; i < _stories.length; i++) {
      final story = _stories[i];

      // 스토리 ID 기반으로 올바른 난이도 결정
      GameDifficulty correctDifficulty;
      switch (story.id) {
        case 1:
        case 7:
          correctDifficulty = GameDifficulty.level1; // 아기 단계
          break;
        case 2:
        case 8:
          correctDifficulty = GameDifficulty.level2; // 어린이 단계
          break;
        case 3:
        case 9:
          correctDifficulty = GameDifficulty.level3; // 청소년 단계
          break;
        case 4:
          correctDifficulty = GameDifficulty.level4; // 어른 단계
          break;
        case 5:
          correctDifficulty = GameDifficulty.level5; // 신의 경지
          break;
        default:
          // 알 수 없는 스토리 ID는 건너뛰기
          continue;
      }

      // 스토리의 난이도가 올바른지 확인
      if (story.difficulty != correctDifficulty) {
        print(
            '[수정] 스토리 ID ${story.id}의 난이도 수정: ${story.difficulty.name} -> ${correctDifficulty.name}');
        _stories[i] = Story(
          id: story.id,
          difficulty: correctDifficulty,
          titleKo: story.titleKo,
          titleEn: story.titleEn,
          descriptionKo: story.descriptionKo,
          descriptionEn: story.descriptionEn,
          cardIds: story.cardIds,
          isUnlocked: story.isUnlocked,
        );
        needsSave = true;
      }
    }

    if (needsSave) {
      await _saveStories();
      print('[수정] 스토리 난이도 수정 완료');
    }
  }

  /// 이야기 잠금 해제 상태 업데이트
  Future<void> _updateStoryUnlockStatus() async {
    bool needsSave = false;
    for (var story in _stories) {
      // 해당 이야기의 모든 카드가 잠금 해제되었는지 확인
      final allCardsUnlocked = story.cardIds.every((cardId) {
        final card = _collection.firstWhere(
          (item) => item.id == cardId,
          orElse: () => CollectionItem(
            id: -1,
            difficulty: story.difficulty,
            imagePath: '',
            isUnlocked: false,
            storyId: story.id,
          ),
        );
        return card.id != -1 && card.isUnlocked;
      });

      if (allCardsUnlocked && !story.isUnlocked) {
        final index = _stories.indexWhere((s) => s.id == story.id);
        if (index != -1) {
          _stories[index] = story.copyWith(isUnlocked: true);
          needsSave = true;
        }
      }
    }
    if (needsSave) {
      await _saveStories();
    }
  }

  /// 컬렉션 데이터 저장
  Future<void> _saveCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _collection.map((item) => item.toJson()).toList();
    await prefs.setString(_collectionKey, jsonEncode(jsonList));
  }

  /// 이야기 데이터 저장
  Future<void> _saveStories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _stories.map((story) => story.toJson()).toList();
    await prefs.setString(_storiesKey, jsonEncode(jsonList));
  }

  /// 랜덤 뽑기 (단계별 희귀도 적용)
  /// 1단계: 40%, 2단계: 25%, 3단계: 20%, 4단계: 10%, 5단계: 5%
  /// 동일 캐릭터 확률: 20%
  Future<CollectionResult> addRandomCard() async {
    final random = Random();

    // 단계별 확률 설정 (1단계가 가장 높고, 5단계가 가장 낮음)
    final roll = random.nextDouble() * 100;
    GameDifficulty selectedDifficulty;

    if (roll < 57.8) {
      selectedDifficulty = GameDifficulty.level1; // 57.8%
    } else if (roll < 87.8) {
      selectedDifficulty = GameDifficulty.level2; // 30%
    } else if (roll < 97.8) {
      selectedDifficulty = GameDifficulty.level3; // 10%
    } else if (roll < 99.8) {
      selectedDifficulty = GameDifficulty.level4; // 2%
    } else {
      selectedDifficulty = GameDifficulty.level5; // 0.2%
    }

    print(
        '[뽑기] 선택된 단계: ${selectedDifficulty.name} (확률 롤: ${roll.toStringAsFixed(1)}%)');

    // 컬렉션이 비어있다면 초기화
    if (_collection.isEmpty) {
      await initializeCollection();
    }

    // 해당 난이도의 모든 가능한 카드 이미지 경로 생성
    final allPossibleCards =
        _getAllPossibleCardsForDifficulty(selectedDifficulty);

    // 이미 잠금 해제된 카드들의 이미지 경로 목록
    final unlockedImagePaths = _collection
        .where((item) => item.isUnlocked && item.imagePath.isNotEmpty)
        .map((item) => item.imagePath)
        .toSet();

    // 해당 난이도에서 이미 수집한 카드
    final unlockedCardsInDifficulty = _collection
        .where(
            (item) => item.difficulty == selectedDifficulty && item.isUnlocked)
        .toList();

    // 아직 수집하지 않은 카드
    final availableNewCards = allPossibleCards
        .where((path) => !unlockedImagePaths.contains(path))
        .toList();

    // 동일 캐릭터 확률 20% 적용
    // 이미 수집한 카드가 있고, 20% 확률로 중복 카드 반환
    if (unlockedCardsInDifficulty.isNotEmpty && random.nextDouble() < 0.20) {
      final existingCard = unlockedCardsInDifficulty[
          random.nextInt(unlockedCardsInDifficulty.length)];
      print('[뽑기] 동일 캐릭터 뽑기 (20% 확률): ${existingCard.imagePath}');
      return CollectionResult(isNewCard: false, card: existingCard);
    }

    // 새 카드가 있으면 새 카드 뽑기
    if (availableNewCards.isNotEmpty) {
      return await _drawNewCard(selectedDifficulty, availableNewCards, random);
    }

    // 모든 카드를 이미 수집한 경우 - 기존 카드 중 랜덤으로 반환
    if (unlockedCardsInDifficulty.isNotEmpty) {
      final existingCard = unlockedCardsInDifficulty[
          random.nextInt(unlockedCardsInDifficulty.length)];
      return CollectionResult(isNewCard: false, card: existingCard);
    }

    // 예외 상황: 아무 카드도 없는 경우 (첫 카드 뽑기)
    return await _drawNewCard(selectedDifficulty, allPossibleCards, random);
  }

  /// IAP 상품 구매 시 보장된 새 캐릭터 뽑기
  /// 무조건 해당 난이도의 미보유 캐릭터를 지급
  Future<CollectionResult?> addGuaranteedNewCard(GameDifficulty difficulty) async {
    // 컬렉션이 비어있다면 초기화
    if (_collection.isEmpty) {
      await initializeCollection();
    }

    final random = Random();

    // 해당 난이도의 모든 가능한 카드 이미지 경로 생성
    final allPossibleCards = _getAllPossibleCardsForDifficulty(difficulty);

    // 이미 잠금 해제된 카드들의 이미지 경로 목록
    final unlockedImagePaths = _collection
        .where((item) => item.isUnlocked && item.imagePath.isNotEmpty)
        .map((item) => item.imagePath)
        .toSet();

    // 아직 수집하지 않은 카드만 필터링
    final availableNewCards = allPossibleCards
        .where((path) => !unlockedImagePaths.contains(path))
        .toList();

    print(
        '[IAP 보장 뽑기] 난이도: ${difficulty.name}, 사용 가능한 새 카드 수: ${availableNewCards.length}');

    // 미보유 카드가 없으면 null 반환
    if (availableNewCards.isEmpty) {
      print('[IAP 보장 뽑기] 해당 난이도의 모든 카드를 이미 보유 중입니다.');
      return null;
    }

    // 무조건 새 카드 뽑기
    return await _drawNewCard(difficulty, availableNewCards, random);
  }

  /// 게임 완료 시 새 카드 추가 (기존 메서드 - 호환성 유지)
  Future<CollectionResult> addNewCard(GameDifficulty difficulty) async {
    // 컬렉션이 비어있다면 초기화
    if (_collection.isEmpty) {
      await initializeCollection();
    }

    // 디버그: 현재 컬렉션 상태 출력
    final level1Items = _collection
        .where((item) => item.difficulty == GameDifficulty.level1)
        .toList();
    print('[디버그] Level1 전체 슬롯 수: ${level1Items.length}');
    print(
        '[디버그] Level1 잠금 해제된 슬롯: ${level1Items.where((item) => item.isUnlocked).length}');
    print(
        '[디버그] Level1 storyId 1 슬롯: ${level1Items.where((item) => item.storyId == 1).length}');
    print(
        '[디버그] Level1 storyId 7 슬롯: ${level1Items.where((item) => item.storyId == 7).length}');

    final random = Random();

    // 해당 난이도의 모든 가능한 카드 이미지 경로 생성
    final allPossibleCards = _getAllPossibleCardsForDifficulty(difficulty);

    // **중요**: 이미 잠금 해제된 카드들의 이미지 경로 목록 (난이도와 관계없이 전역 체크)
    // 같은 이미지가 다른 난이도 슬롯에 저장되는 것을 방지
    final unlockedImagePaths = _collection
        .where((item) => item.isUnlocked && item.imagePath.isNotEmpty)
        .map((item) => item.imagePath)
        .toSet();

    print('[디버그] 전체 잠금 해제된 이미지 경로 수: ${unlockedImagePaths.length}');

    // 해당 난이도에서 이미 수집한 카드만 필터링 (난이도별 체크)
    final unlockedCardsInDifficulty = _collection
        .where((item) => item.difficulty == difficulty && item.isUnlocked)
        .map((item) => item.imagePath)
        .toSet();

    // 아직 수집하지 않은 카드만 필터링 (전역 중복 체크)
    final availableNewCards = allPossibleCards
        .where((path) => !unlockedImagePaths.contains(path))
        .toList();

    print(
        '[디버그] 해당 난이도(${difficulty.name})에서 수집한 카드 수: ${unlockedCardsInDifficulty.length}');
    print('[디버그] 사용 가능한 새 카드 수: ${availableNewCards.length}');

    // 이미 수집한 카드 목록
    final unlockedCards = _collection
        .where((item) => item.difficulty == difficulty && item.isUnlocked)
        .toList();

    // ===== 뽑기 확률 로직 =====
    // 새 카드가 있고, 전체 수집률이 100%가 아닌 경우
    if (availableNewCards.isNotEmpty) {
      // 수집률에 따라 새 카드 확률 조정
      final collectionRate = unlockedCards.length / allPossibleCards.length;

      // 새 카드 확률: 수집률이 낮을수록 높음
      // 0% 수집: 100% 새 카드
      // 50% 수집: 70% 새 카드
      // 80% 수집: 50% 새 카드
      // 90% 수집: 40% 새 카드
      final newCardProbability = (1.0 - (collectionRate * 0.6)).clamp(0.4, 1.0);
      final shouldDrawNewCard = random.nextDouble() < newCardProbability;

      if (shouldDrawNewCard) {
        // ===== 새 카드 뽑기 =====
        return await _drawNewCard(difficulty, availableNewCards, random);
      } else if (unlockedCards.isNotEmpty) {
        // ===== 기존 카드 뽑기 =====
        final existingCard =
            unlockedCards[random.nextInt(unlockedCards.length)];
        return CollectionResult(isNewCard: false, card: existingCard);
      } else {
        // 기존 카드가 없으면 새 카드 뽑기
        return await _drawNewCard(difficulty, availableNewCards, random);
      }
    }

    // 모든 카드를 이미 수집한 경우 - 기존 카드 중 랜덤으로 반환
    if (unlockedCards.isNotEmpty) {
      final existingCard = unlockedCards[random.nextInt(unlockedCards.length)];
      return CollectionResult(isNewCard: false, card: existingCard);
    }

    // 예외 상황: 아무 카드도 없는 경우 (첫 카드 뽑기)
    return await _drawNewCard(difficulty, allPossibleCards, random);
  }

  /// 새 카드를 뽑는 내부 함수
  Future<CollectionResult> _drawNewCard(
    GameDifficulty difficulty,
    List<String> availableCards,
    Random random,
  ) async {
    if (availableCards.isEmpty) {
      throw Exception('사용 가능한 카드가 없습니다.');
    }

    // 랜덤으로 새 카드 선택
    final selectedImagePath =
        availableCards[random.nextInt(availableCards.length)];
    print('[디버그] 선택된 카드: $selectedImagePath, 난이도: ${difficulty.name}');

    // **중요**: 선택된 이미지 경로가 해당 난이도에 맞는지 검증
    if (!_isImagePathValidForDifficulty(difficulty, selectedImagePath)) {
      print(
          '[에러] 잘못된 이미지 경로: 난이도 ${difficulty.name}에 $selectedImagePath는 사용할 수 없습니다!');
      // 잘못된 카드 제거하고 다시 시도
      final validCards = availableCards
          .where((path) => _isImagePathValidForDifficulty(difficulty, path))
          .toList();
      if (validCards.isEmpty) {
        throw Exception('해당 난이도에 맞는 카드가 없습니다.');
      }
      return await _drawNewCard(difficulty, validCards, random);
    }

    // 선택된 이미지 경로에 맞는 에피소드 그룹 찾기
    final targetStoryId =
        _getStoryIdForImagePath(difficulty, selectedImagePath);
    print('[디버그] targetStoryId: $targetStoryId');

    // **중요**: 선택된 이미지에 맞는 storyId의 슬롯을 강제로 사용
    // 해당 에피소드 그룹의 잠금 해제되지 않은 슬롯 찾기
    // **추가 검증**: 난이도와 ID 범위가 정확히 일치하는 슬롯만 찾기
    final idRange = _getExpectedIdRangeForDifficulty(difficulty);
    final lockedCardsInTargetStory = _collection
        .where((item) =>
            item.difficulty == difficulty &&
            !item.isUnlocked &&
            item.storyId == targetStoryId &&
            item.id >= idRange.start &&
            item.id <= idRange.end) // **추가**: ID 범위 검증
        .toList();

    // **디버그**: 찾은 슬롯들의 난이도 확인
    if (lockedCardsInTargetStory.isNotEmpty) {
      final wrongDifficultySlots = lockedCardsInTargetStory
          .where((item) => item.difficulty != difficulty)
          .toList();
      if (wrongDifficultySlots.isNotEmpty) {
        print(
            '[경고] 잘못된 난이도 슬롯 발견: ${wrongDifficultySlots.map((s) => 'ID=${s.id}, 난이도=${s.difficulty.name}').join(', ')}');
      }
    }

    print(
        '[디버그] targetStoryId($targetStoryId)의 잠금된 슬롯 개수: ${lockedCardsInTargetStory.length} (난이도: ${difficulty.name})');

    // **수정**: 반드시 targetStoryId의 슬롯을 사용하도록 변경
    // (다른 storyId 슬롯을 사용하지 않음)
    if (lockedCardsInTargetStory.isEmpty) {
      // 해당 storyId의 슬롯이 모두 차있으면 같은 난이도의 다른 빈 슬롯 사용
      // **중요**: 난이도와 ID 범위가 정확히 일치하는 슬롯만 찾기
      final anyLockedSlots = _collection
          .where((item) =>
              item.difficulty == difficulty &&
              !item.isUnlocked &&
              item.id >= idRange.start &&
              item.id <= idRange.end) // **추가**: ID 범위 검증
          .toList();

      // **추가 검증**: 찾은 슬롯들의 난이도와 ID 범위 재확인
      final wrongSlots = anyLockedSlots
          .where((item) =>
              item.difficulty != difficulty ||
              item.id < idRange.start ||
              item.id > idRange.end)
          .toList();
      if (wrongSlots.isNotEmpty) {
        print(
            '[경고] 잘못된 슬롯 발견 (anyLockedSlots): ${wrongSlots.map((s) => 'ID=${s.id}, 난이도=${s.difficulty.name}').join(', ')}');
        // 잘못된 슬롯 제거
        anyLockedSlots.removeWhere((item) =>
            item.difficulty != difficulty ||
            item.id < idRange.start ||
            item.id > idRange.end);
      }

      print(
          '[디버그] 같은 난이도(${difficulty.name})의 빈 슬롯 개수: ${anyLockedSlots.length} (ID 범위: ${idRange.start}-${idRange.end})');

      if (anyLockedSlots.isEmpty) {
        // 모든 슬롯이 차있는 경우 - 기존 카드 반환
        final unlockedCards = _collection
            .where((item) => item.difficulty == difficulty && item.isUnlocked)
            .toList();

        if (unlockedCards.isEmpty) {
          throw Exception('사용 가능한 슬롯이 없습니다.');
        }

        final existingCard =
            unlockedCards[random.nextInt(unlockedCards.length)];
        return CollectionResult(isNewCard: false, card: existingCard);
      }

      // 다른 storyId의 빈 슬롯 사용 (폴백)
      final selectedSlot = anyLockedSlots.first;
      final index =
          _collection.indexWhere((item) => item.id == selectedSlot.id);

      // 중복 확인
      final existingCard = _collection.firstWhere(
        (item) =>
            item.difficulty == difficulty &&
            item.isUnlocked &&
            item.imagePath == selectedImagePath,
        orElse: () => CollectionItem(
            id: -1,
            difficulty: difficulty,
            imagePath: '',
            isUnlocked: false,
            storyId: 0),
      );

      if (existingCard.id != -1) {
        return CollectionResult(isNewCard: false, card: existingCard);
      }

      // **중요**: 슬롯의 난이도가 현재 게임 난이도와 일치하는지 확인
      if (selectedSlot.difficulty != difficulty) {
        print(
            '[에러] 슬롯 할당 실패: 슬롯 난이도(${selectedSlot.difficulty.name})와 게임 난이도(${difficulty.name})가 일치하지 않습니다!');
        // 같은 난이도의 다른 슬롯 찾기
        final correctSlots = _collection
            .where((item) => item.difficulty == difficulty && !item.isUnlocked)
            .toList();
        if (correctSlots.isEmpty) {
          throw Exception('해당 난이도에 사용 가능한 슬롯이 없습니다.');
        }
        final correctSlot = correctSlots.first;
        final correctIndex =
            _collection.indexWhere((item) => item.id == correctSlot.id);

        _collection[correctIndex] = CollectionItem(
          id: correctSlot.id,
          difficulty: difficulty, // 현재 게임 난이도 사용
          imagePath: selectedImagePath,
          isUnlocked: true,
          isNew: true,
          storyId: targetStoryId,
        );

        print(
            '[디버그] 슬롯 할당 완료 (수정됨): ID=${correctSlot.id}, 난이도=${difficulty.name}, 이미지=$selectedImagePath, storyId=$targetStoryId');

        await _saveCollection();
        await _updateStoryUnlockStatus();
        final missionService = DailyMissionService();
        await missionService.collectCharacter();

        return CollectionResult(
            isNewCard: true, card: _collection[correctIndex]);
      }

      // **최종 검증**: 선택된 이미지 경로가 슬롯의 난이도와 일치하는지 확인
      if (!_isImagePathValidForDifficulty(
          selectedSlot.difficulty, selectedImagePath)) {
        print(
            '[에러] 슬롯 할당 실패: 슬롯 난이도(${selectedSlot.difficulty.name})와 이미지 경로($selectedImagePath)가 일치하지 않습니다!');
        throw Exception('슬롯 할당 오류: 난이도 불일치');
      }

      _collection[index] = CollectionItem(
        id: selectedSlot.id,
        difficulty: difficulty, // **수정**: 항상 현재 게임 난이도 사용
        imagePath: selectedImagePath,
        isUnlocked: true,
        isNew: true,
        storyId: targetStoryId, // 올바른 storyId로 설정
      );

      print(
          '[디버그] 슬롯 할당 완료: ID=${selectedSlot.id}, 난이도=${difficulty.name}, 이미지=$selectedImagePath, storyId=$targetStoryId');

      // **중요**: 할당 직후 실제 저장된 데이터 확인
      final savedItem = _collection[index];
      print(
          '[디버그] 실제 저장된 데이터: ID=${savedItem.id}, 난이도=${savedItem.difficulty.name}, 이미지=${savedItem.imagePath}, storyId=${savedItem.storyId}, 잠금해제=${savedItem.isUnlocked}');

      // **중요**: 할당 후 전체 컬렉션에서 해당 이미지 경로가 몇 개나 있는지 확인
      final duplicateCheck = _collection
          .where(
              (item) => item.isUnlocked && item.imagePath == selectedImagePath)
          .toList();
      if (duplicateCheck.length > 1) {
        print(
            '[에러] 중복 감지! $selectedImagePath가 ${duplicateCheck.length}개 슬롯에 저장되어 있습니다:');
        for (var dup in duplicateCheck) {
          print(
              '  - 슬롯 ID: ${dup.id}, 난이도: ${dup.difficulty.name}, storyId: ${dup.storyId}');
        }
        // 중복 제거: 가장 최근 것만 남기고 나머지는 잠금
        for (int i = 0; i < duplicateCheck.length - 1; i++) {
          final dupItem = duplicateCheck[i];
          final dupIndex =
              _collection.indexWhere((item) => item.id == dupItem.id);
          if (dupIndex != -1 && dupItem.id != selectedSlot.id) {
            print('[수정] 중복 슬롯 ID ${dupItem.id} 잠금 처리');
            _collection[dupIndex] = CollectionItem(
              id: dupItem.id,
              difficulty: dupItem.difficulty,
              imagePath: _defaultImagePath,
              isUnlocked: false,
              isNew: false,
              storyId: dupItem.storyId,
            );
          }
        }
      }

      // **중요**: 저장 후 해당 ID 범위의 모든 슬롯 난이도 확인
      final idRangeCheck = _getExpectedIdRangeForDifficulty(difficulty);
      final wrongDifficultyInRange = _collection
          .where((item) =>
              item.id >= idRangeCheck.start &&
              item.id <= idRangeCheck.end &&
              item.difficulty != difficulty)
          .toList();
      if (wrongDifficultyInRange.isNotEmpty) {
        print(
            '[에러] ID 범위 ${idRangeCheck.start}-${idRangeCheck.end}에 잘못된 난이도 슬롯 발견:');
        for (var wrong in wrongDifficultyInRange) {
          print(
              '  - 슬롯 ID: ${wrong.id}, 잘못된 난이도: ${wrong.difficulty.name}, 올바른 난이도: ${difficulty.name}');
          // 자동 수정
          final wrongIndex =
              _collection.indexWhere((item) => item.id == wrong.id);
          if (wrongIndex != -1) {
            _collection[wrongIndex] =
                _collection[wrongIndex].copyWith(difficulty: difficulty);
            print(
                '[수정] 슬롯 ID ${wrong.id} 난이도 수정: ${wrong.difficulty.name} -> ${difficulty.name}');
          }
        }
      }

      await _saveCollection();
      await _updateStoryUnlockStatus();

      final missionService = DailyMissionService();
      await missionService.collectCharacter();

      return CollectionResult(isNewCard: true, card: _collection[index]);
    }

    // targetStoryId의 슬롯이 있으면 해당 슬롯 사용
    final selectedSlot = lockedCardsInTargetStory.first;
    final index = _collection.indexWhere((item) => item.id == selectedSlot.id);

    // **중요**: 이미 같은 이미지 경로로 잠금 해제된 카드가 있는지 전역으로 확인 (중복 방지)
    final existingCardGlobal = _collection.firstWhere(
      (item) => item.isUnlocked && item.imagePath == selectedImagePath,
      orElse: () => CollectionItem(
          id: -1,
          difficulty: difficulty,
          imagePath: '',
          isUnlocked: false,
          storyId: 0),
    );

    if (existingCardGlobal.id != -1) {
      // 이미 존재하는 카드인 경우 (중복 방지)
      print(
          '[경고] 중복 카드 발견: $selectedImagePath가 이미 슬롯 ID ${existingCardGlobal.id}에 저장되어 있습니다 (난이도: ${existingCardGlobal.difficulty.name})');
      return CollectionResult(isNewCard: false, card: existingCardGlobal);
    }

    // **추가 검증**: 슬롯 ID가 해당 난이도의 올바른 범위에 있는지 확인
    final expectedIdRange = _getExpectedIdRangeForDifficulty(difficulty);
    if (selectedSlot.id < expectedIdRange.start ||
        selectedSlot.id > expectedIdRange.end) {
      print(
          '[에러] 슬롯 ID 범위 오류: 슬롯 ID ${selectedSlot.id}는 난이도 ${difficulty.name}의 범위(${expectedIdRange.start}-${expectedIdRange.end})에 없습니다!');
      // 올바른 범위의 슬롯 찾기
      final correctSlots = lockedCardsInTargetStory
          .where((item) =>
              item.difficulty == difficulty &&
              item.id >= expectedIdRange.start &&
              item.id <= expectedIdRange.end)
          .toList();
      if (correctSlots.isEmpty) {
        throw Exception('해당 난이도와 storyId에 사용 가능한 올바른 범위의 슬롯이 없습니다.');
      }
      final correctSlot = correctSlots.first;
      final correctIndex =
          _collection.indexWhere((item) => item.id == correctSlot.id);

      _collection[correctIndex] = CollectionItem(
        id: correctSlot.id,
        difficulty: difficulty,
        imagePath: selectedImagePath,
        isUnlocked: true,
        isNew: true,
        storyId: targetStoryId,
      );

      print(
          '[디버그] 슬롯 할당 완료 (ID 범위 수정): ID=${correctSlot.id}, 난이도=${difficulty.name}, 이미지=$selectedImagePath, storyId=$targetStoryId');

      await _saveCollection();
      await _updateStoryUnlockStatus();
      final missionService = DailyMissionService();
      await missionService.collectCharacter();

      return CollectionResult(isNewCard: true, card: _collection[correctIndex]);
    }

    // **중요**: 슬롯의 난이도가 현재 게임 난이도와 일치하는지 확인
    if (selectedSlot.difficulty != difficulty) {
      print(
          '[에러] 슬롯 난이도 불일치: 슬롯 난이도(${selectedSlot.difficulty.name})와 게임 난이도(${difficulty.name})가 일치하지 않습니다!');
      // 같은 난이도의 올바른 슬롯 찾기
      final correctSlots = lockedCardsInTargetStory
          .where((item) => item.difficulty == difficulty)
          .toList();
      if (correctSlots.isEmpty) {
        throw Exception('해당 난이도와 storyId에 사용 가능한 슬롯이 없습니다.');
      }
      final correctSlot = correctSlots.first;
      final correctIndex =
          _collection.indexWhere((item) => item.id == correctSlot.id);

      _collection[correctIndex] = CollectionItem(
        id: correctSlot.id,
        difficulty: difficulty, // 현재 게임 난이도 사용
        imagePath: selectedImagePath,
        isUnlocked: true,
        isNew: true,
        storyId: targetStoryId,
      );

      print(
          '[디버그] 슬롯 할당 완료 (수정됨): ID=${correctSlot.id}, 난이도=${difficulty.name}, 이미지=$selectedImagePath, storyId=$targetStoryId');

      await _saveCollection();
      await _updateStoryUnlockStatus();
      final missionService = DailyMissionService();
      await missionService.collectCharacter();

      return CollectionResult(isNewCard: true, card: _collection[correctIndex]);
    }

    // **중요**: 이미 같은 이미지 경로로 잠금 해제된 카드가 있는지 전역으로 확인 (중복 방지)
    // 난이도와 관계없이 같은 이미지가 이미 있으면 중복으로 처리
    final existingCard = _collection.firstWhere(
      (item) => item.isUnlocked && item.imagePath == selectedImagePath,
      orElse: () => CollectionItem(
          id: -1,
          difficulty: difficulty,
          imagePath: '',
          isUnlocked: false,
          storyId: 0),
    );

    if (existingCard.id != -1) {
      // 이미 존재하는 카드인 경우 (중복 방지)
      print(
          '[경고] 중복 카드 발견: $selectedImagePath가 이미 슬롯 ID ${existingCard.id}에 저장되어 있습니다 (난이도: ${existingCard.difficulty.name})');
      return CollectionResult(isNewCard: false, card: existingCard);
    }

    // **추가 검증**: 슬롯 ID가 해당 난이도의 올바른 범위에 있는지 확인
    final slotIdRange = _getExpectedIdRangeForDifficulty(difficulty);
    if (selectedSlot.id < slotIdRange.start ||
        selectedSlot.id > slotIdRange.end) {
      print(
          '[에러] 슬롯 ID 범위 오류: 슬롯 ID ${selectedSlot.id}는 난이도 ${difficulty.name}의 범위(${slotIdRange.start}-${slotIdRange.end})에 없습니다!');
      // 올바른 범위의 슬롯 찾기
      final correctSlots = _collection
          .where((item) =>
              item.difficulty == difficulty &&
              !item.isUnlocked &&
              item.id >= slotIdRange.start &&
              item.id <= slotIdRange.end)
          .toList();
      if (correctSlots.isEmpty) {
        throw Exception('해당 난이도에 사용 가능한 올바른 범위의 슬롯이 없습니다.');
      }
      final correctSlot = correctSlots.first;
      final correctIndex =
          _collection.indexWhere((item) => item.id == correctSlot.id);

      _collection[correctIndex] = CollectionItem(
        id: correctSlot.id,
        difficulty: difficulty,
        imagePath: selectedImagePath,
        isUnlocked: true,
        isNew: true,
        storyId: targetStoryId,
      );

      print(
          '[디버그] 슬롯 할당 완료 (ID 범위 수정): ID=${correctSlot.id}, 난이도=${difficulty.name}, 이미지=$selectedImagePath, storyId=$targetStoryId');

      // **중요**: 할당 후 전체 컬렉션에서 해당 이미지 경로가 몇 개나 있는지 확인
      final duplicateCheck2 = _collection
          .where(
              (item) => item.isUnlocked && item.imagePath == selectedImagePath)
          .toList();
      if (duplicateCheck2.length > 1) {
        print(
            '[에러] 중복 감지! $selectedImagePath가 ${duplicateCheck2.length}개 슬롯에 저장되어 있습니다:');
        for (var dup in duplicateCheck2) {
          print(
              '  - 슬롯 ID: ${dup.id}, 난이도: ${dup.difficulty.name}, storyId: ${dup.storyId}');
        }
        // 중복 제거: 가장 최근 것만 남기고 나머지는 잠금
        for (int i = 0; i < duplicateCheck2.length - 1; i++) {
          final dupItem = duplicateCheck2[i];
          final dupIndex =
              _collection.indexWhere((item) => item.id == dupItem.id);
          if (dupIndex != -1 && dupItem.id != correctSlot.id) {
            print('[수정] 중복 슬롯 ID ${dupItem.id} 잠금 처리');
            _collection[dupIndex] = CollectionItem(
              id: dupItem.id,
              difficulty: dupItem.difficulty,
              imagePath: _defaultImagePath,
              isUnlocked: false,
              isNew: false,
              storyId: dupItem.storyId,
            );
          }
        }
      }

      await _saveCollection();
      await _updateStoryUnlockStatus();
      final missionService = DailyMissionService();
      await missionService.collectCharacter();

      return CollectionResult(isNewCard: true, card: _collection[correctIndex]);
    }

    // **최종 검증**: 선택된 이미지 경로가 슬롯의 난이도와 일치하는지 확인
    if (!_isImagePathValidForDifficulty(
        selectedSlot.difficulty, selectedImagePath)) {
      print(
          '[에러] 슬롯 할당 실패: 슬롯 난이도(${selectedSlot.difficulty.name})와 이미지 경로($selectedImagePath)가 일치하지 않습니다!');
      throw Exception('슬롯 할당 오류: 난이도 불일치');
    }

    _collection[index] = CollectionItem(
      id: selectedSlot.id,
      difficulty: difficulty, // **수정**: 항상 현재 게임 난이도 사용
      imagePath: selectedImagePath,
      isUnlocked: true,
      isNew: true, // 새로 획득한 카드이므로 NEW 태그 표시
      storyId: targetStoryId, // 올바른 에피소드 그룹에 할당
    );

    print(
        '[디버그] 슬롯 할당 완료: ID=${selectedSlot.id}, 난이도=${difficulty.name}, 이미지=$selectedImagePath, storyId=$targetStoryId');

    // **중요**: 할당 후 전체 컬렉션에서 해당 이미지 경로가 몇 개나 있는지 확인
    final duplicateCheck = _collection
        .where((item) => item.isUnlocked && item.imagePath == selectedImagePath)
        .toList();
    if (duplicateCheck.length > 1) {
      print(
          '[에러] 중복 감지! $selectedImagePath가 ${duplicateCheck.length}개 슬롯에 저장되어 있습니다:');
      for (var dup in duplicateCheck) {
        print(
            '  - 슬롯 ID: ${dup.id}, 난이도: ${dup.difficulty.name}, storyId: ${dup.storyId}');
      }
      // 중복 제거: 가장 최근 것(현재 할당한 것)만 남기고 나머지는 잠금
      for (int i = 0; i < duplicateCheck.length - 1; i++) {
        final dupItem = duplicateCheck[i];
        final dupIndex =
            _collection.indexWhere((item) => item.id == dupItem.id);
        if (dupIndex != -1 && dupItem.id != selectedSlot.id) {
          print('[수정] 중복 슬롯 ID ${dupItem.id} 잠금 처리');
          _collection[dupIndex] = CollectionItem(
            id: dupItem.id,
            difficulty: dupItem.difficulty,
            imagePath: _defaultImagePath,
            isUnlocked: false,
            isNew: false,
            storyId: dupItem.storyId,
          );
        }
      }
    }

    await _saveCollection();

    // 이야기 잠금 해제 상태 업데이트
    await _updateStoryUnlockStatus();

    // 데일리 미션: 새 캐릭터 수집 업데이트
    final missionService = DailyMissionService();
    await missionService.collectCharacter();

    return CollectionResult(isNewCard: true, card: _collection[index]);
  }

  /// 난이도별 예상 슬롯 ID 범위 반환
  Range _getExpectedIdRangeForDifficulty(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.level1:
        return Range(1, 20); // 아기 단계: 1-20번
      case GameDifficulty.level2:
        return Range(21, 40); // 어린이 단계: 21-40번
      case GameDifficulty.level3:
        return Range(41, 60); // 청소년 단계: 41-60번
      case GameDifficulty.level4:
        return Range(61, 70); // 어른 단계: 61-70번
      case GameDifficulty.level5:
        return Range(71, 80); // 신의 경지: 71-80번
    }
  }

  /// 이미지 경로가 해당 난이도에 맞는지 검증
  bool _isImagePathValidForDifficulty(
      GameDifficulty difficulty, String imagePath) {
    // 이미지 경로에서 접두사 추출 (.jpg 또는 .webp 지원)
    final match = RegExp(r'([a-z]+)(\d+)\.(jpg|webp)$').firstMatch(imagePath);
    if (match == null) return false;

    final prefix = match.group(1)!; // easy, basic, normal, advanced, hard

    switch (difficulty) {
      case GameDifficulty.level1:
        return prefix == 'easy';
      case GameDifficulty.level2:
        return prefix == 'basic';
      case GameDifficulty.level3:
        return prefix == 'normal';
      case GameDifficulty.level4:
        return prefix == 'advanced';
      case GameDifficulty.level5:
        return prefix == 'hard';
    }
  }

  /// 이미지 경로에 맞는 에피소드 그룹(storyId) 반환
  /// **중요**: 이미지 경로의 접두사(easy/basic/normal 등)와 난이도를 모두 검증
  int _getStoryIdForImagePath(GameDifficulty difficulty, String imagePath) {
    // 이미지 경로에서 접두사와 번호 추출
    // 예: assets/capybara/collection/easy14.webp -> easy, 14
    final match = RegExp(r'([a-z]+)(\d+)\.(jpg|webp)$').firstMatch(imagePath);
    if (match == null) {
      print('[경고] 이미지 경로 파싱 실패: $imagePath');
      return 1;
    }

    final prefix = match.group(1)!; // easy, basic, normal, advanced, hard
    final number = int.parse(match.group(2)!);

    // 난이도와 접두사 일치 여부 검증
    switch (difficulty) {
      case GameDifficulty.level1:
        if (prefix != 'easy') {
          print('[경고] Level1인데 접두사가 $prefix입니다: $imagePath');
          return 1; // 기본값 반환
        }
        // 아기 단계: easy1-10 -> storyId 1, easy11-20 -> storyId 7
        if (number >= 1 && number <= 10) return 1;
        if (number >= 11 && number <= 20) return 7;
        break;
      case GameDifficulty.level2:
        if (prefix != 'basic') {
          print('[경고] Level2인데 접두사가 $prefix입니다: $imagePath');
          return 2; // 기본값 반환
        }
        // 어린이 단계: basic1-10 -> storyId 2, basic11-20 -> storyId 8
        if (number >= 1 && number <= 10) return 2;
        if (number >= 11 && number <= 20) return 8;
        break;
      case GameDifficulty.level3:
        if (prefix != 'normal') {
          print('[경고] Level3인데 접두사가 $prefix입니다: $imagePath');
          return 3; // 기본값 반환
        }
        // 청소년 단계: normal1-10 -> storyId 3, normal11-20 -> storyId 9
        if (number >= 1 && number <= 10) return 3;
        if (number >= 11 && number <= 20) return 9;
        break;
      case GameDifficulty.level4:
        if (prefix != 'advanced') {
          print('[경고] Level4인데 접두사가 $prefix입니다: $imagePath');
          return 4; // 기본값 반환
        }
        // 어른 단계: advanced1-10 -> storyId 4
        return 4;
      case GameDifficulty.level5:
        if (prefix != 'hard') {
          print('[경고] Level5인데 접두사가 $prefix입니다: $imagePath');
          return 5; // 기본값 반환
        }
        // 신의 경지: hard1-10 -> storyId 5
        return 5;
    }

    print(
        '[경고] storyId를 찾을 수 없음: difficulty=$difficulty, imagePath=$imagePath');
    return 1; // 기본값
  }

  /// 난이도별 모든 가능한 카드 이미지 경로 반환
  List<String> _getAllPossibleCardsForDifficulty(GameDifficulty difficulty) {
    final List<String> cards = [];

    switch (difficulty) {
      case GameDifficulty.level1:
        // 아기 단계 - easy1-20 사용 (전체 20개)
        for (int i = 1; i <= 20; i++) {
          cards.add('assets/capybara/collection/easy$i.webp');
        }
        break;
      case GameDifficulty.level2:
        // 어린이 단계 - basic1-20 사용 (전체 20개)
        for (int i = 1; i <= 20; i++) {
          cards.add('assets/capybara/collection/basic$i.webp');
        }
        break;
      case GameDifficulty.level3:
        // 청소년 단계 - normal1-20 사용 (전체 20개)
        for (int i = 1; i <= 20; i++) {
          cards.add('assets/capybara/collection/normal$i.webp');
        }
        break;
      case GameDifficulty.level4:
        // 어른 단계 - advanced1-10 사용 (전체 10개)
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/advanced$i.webp');
        }
        break;
      case GameDifficulty.level5:
        // 신의 경지 - hard1-10만 사용 (10개)
        for (int i = 1; i <= 10; i++) {
          cards.add('assets/capybara/collection/hard$i.webp');
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
        storyId: _collection[index].storyId,
      );
      await _saveCollection();
      // 이야기 잠금 해제 상태 업데이트
      await _updateStoryUnlockStatus();
    }
  }

  /// 전체 이야기 목록 반환
  List<Story> get stories => List.unmodifiable(_stories);

  /// 난이도별 이야기 목록 반환
  List<Story> getStoriesByDifficulty(GameDifficulty difficulty) {
    return _stories.where((story) => story.difficulty == difficulty).toList();
  }

  /// 특정 이야기 반환
  Story? getStoryById(int storyId) {
    try {
      return _stories.firstWhere((story) => story.id == storyId);
    } catch (e) {
      return null;
    }
  }

  /// 이야기의 카드 목록 반환
  List<CollectionItem> getCardsByStoryId(int storyId) {
    final story = getStoryById(storyId);
    if (story == null) return [];

    // 스토리의 cardIds에 해당하는 카드만 반환 (정확히 10개 또는 지정된 개수)
    // **중요**: 난이도도 함께 검증하여 잘못된 난이도의 슬롯이 반환되지 않도록 함
    bool needsSave = false;
    final List<CollectionItem> cards = [];

    for (final cardId in story.cardIds) {
      final itemIndex = _collection.indexWhere((item) => item.id == cardId);
      if (itemIndex == -1) {
        // 슬롯이 없으면 기본 슬롯 생성
        cards.add(CollectionItem(
          id: cardId,
          difficulty: story.difficulty,
          imagePath: _defaultImagePath,
          isUnlocked: false,
          storyId: storyId,
        ));
        continue;
      }

      final item = _collection[itemIndex];

      // **검증**: 찾은 슬롯의 난이도가 스토리의 난이도와 일치하는지 확인
      if (item.difficulty != story.difficulty) {
        print(
            '[수정] getCardsByStoryId: 슬롯 ID $cardId의 난이도 수정: ${item.difficulty.name} -> ${story.difficulty.name}');
        // 실제 컬렉션 데이터 수정
        _collection[itemIndex] = item.copyWith(difficulty: story.difficulty);
        needsSave = true;
        cards.add(_collection[itemIndex]);
      } else {
        cards.add(item);
      }
    }

    if (needsSave) {
      // 비동기로 저장 (Future.microtask 사용)
      Future.microtask(() => _saveCollection());
    }

    return cards;
  }

  /// 이야기의 잠금 해제된 카드 수 반환
  int getUnlockedCardCountByStoryId(int storyId) {
    final cards = getCardsByStoryId(storyId);
    return cards.where((card) => card.isUnlocked).length;
  }

  /// 컬렉션 초기화 (디버깅/테스트용)
  Future<void> resetCollection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collectionKey);
    await prefs.remove(_storiesKey);
    await initializeCollection();
  }
}
