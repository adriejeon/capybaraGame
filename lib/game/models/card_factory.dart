import 'dart:math';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'card.dart';

/// 카피바라 카드 팩토리
class CapybaraCardFactory {
  // 사용 가능한 카피바라 이미지들
  static const List<String> _capybaraImages = [
    'capybara/black1.jpg',
    'capybara/black2.jpg',
    'capybara/black3.jpg',
    'capybara/blue1.jpg',
    'capybara/blue2.jpg',
    'capybara/blue3.jpg',
    'capybara/blue4.jpg',
    'capybara/blue5.jpg',
    'capybara/brown1.jpg',
    'capybara/brown2.jpg',
    'capybara/brown3.jpg',
    'capybara/cook1.jpg',
    'capybara/cook2.jpg',
    'capybara/darkBrown1.jpg',
    'capybara/darkBrown2.jpg',
    'capybara/darkBrown3.jpg',
    'capybara/darkBrown4.jpg',
    'capybara/darkBrown5.jpg',
    'capybara/darkGrey1.jpg',
    'capybara/darkGrey2.jpg',
    'capybara/docter1.jpg',
    'capybara/docter2.jpg',
    'capybara/docter3.jpg',
    'capybara/green1.jpg',
    'capybara/green2.jpg',
    'capybara/grey1.jpg',
    'capybara/grey2-1.jpg',
    'capybara/grey2.jpg',
    'capybara/navy1.jpg',
    'capybara/navy2.jpg',
    'capybara/pink1.jpg',
    'capybara/pink2.jpg',
    'capybara/pink3.jpg',
    'capybara/pink4.jpg',
    'capybara/pink5.jpg',
    'capybara/pirate1.jpg',
    'capybara/pirate2.jpg',
    'capybara/pirate3.jpg',
    'capybara/pirate4.jpg',
    'capybara/pupple.jpg',
    'capybara/white1.jpg',
    'capybara/white2.jpg',
    'capybara/yellow1.jpg',
    'capybara/yellow2.jpg',
    'capybara/yellow3.jpg',
    'capybara/yellow4.jpg',
  ];

  /// 난이도에 따른 카드 개수 반환
  static int getCardCount(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.level1:
        return GameConstants.level1CardCount;
      case GameDifficulty.level2:
        return GameConstants.level2CardCount;
      case GameDifficulty.level3:
        return GameConstants.level3CardCount;
      case GameDifficulty.level4:
        return GameConstants.level4CardCount;
      case GameDifficulty.level5:
        return GameConstants.level5CardCount;
    }
  }

  /// 난이도에 따른 게임 보드 생성
  static GameBoard createGameBoard(GameDifficulty difficulty) {
    final cardCount = getCardCount(difficulty);
    final pairCount = cardCount ~/ 2;

    // 사용할 이미지들을 랜덤하게 선택
    final shuffledImages = List<String>.from(_capybaraImages);
    shuffledImages.shuffle(Random());
    final selectedImages = shuffledImages.take(pairCount).toList();

    // 카드 생성 (각 이미지마다 2장씩)
    final List<GameCard> cards = [];
    int cardId = 0;

    for (int i = 0; i < selectedImages.length; i++) {
      final imagePath = selectedImages[i];

      // 첫 번째 카드
      cards.add(GameCard(
        id: cardId++,
        imagePath: imagePath,
        pairId: i,
      ));

      // 두 번째 카드 (쌍)
      cards.add(GameCard(
        id: cardId++,
        imagePath: imagePath,
        pairId: i,
      ));
    }

    // 카드들을 섞기
    final shuffledCards = GameHelpers.shuffleList(cards);

    // 그리드 크기 계산
    GridSize gridSize;
    switch (difficulty) {
      case GameDifficulty.level1:
        gridSize = GridSize(2, 3); // 레벨 1: 2x3 (6개 카드)
        break;
      case GameDifficulty.level2:
        gridSize = GridSize(3, 4); // 레벨 2: 3x4 (12개 카드)
        break;
      case GameDifficulty.level3:
        gridSize = GridSize(4, 4); // 레벨 3: 4x4 (16개 카드)
        break;
      case GameDifficulty.level4:
        gridSize = GridSize(4, 6); // 레벨 4: 4x6 (24개 카드)
        break;
      case GameDifficulty.level5:
        gridSize = GridSize(5, 8); // 레벨 5: 5x8 (40개 카드)
        break;
    }

    return GameBoard(
      cards: shuffledCards,
      gridWidth: gridSize.width,
      gridHeight: gridSize.height,
      difficulty: difficulty,
    );
  }


  /// 사용 가능한 이미지 개수 반환
  static int get availableImageCount => _capybaraImages.length;

  /// 모든 카피바라 이미지 경로 반환
  static List<String> get allCapybaraImages =>
      List.unmodifiable(_capybaraImages);
}

/// 그리드 크기를 나타내는 클래스
class GridSize {
  final int width;
  final int height;

  GridSize(this.width, this.height);

  @override
  String toString() => '${width}x$height';
}
