import 'dart:math';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'card.dart';

/// 카피바라 카드 팩토리
class CapybaraCardFactory {
  // 사용 가능한 카피바라 이미지들
  static const List<String> _capybaraImages = [
    'capybara/black1.webp',
    'capybara/black2.webp',
    'capybara/black3.webp',
    'capybara/blue1.webp',
    'capybara/blue2.webp',
    'capybara/blue3.webp',
    'capybara/blue4.webp',
    'capybara/blue5.webp',
    'capybara/brown1.webp',
    'capybara/brown2.webp',
    'capybara/brown3.webp',
    'capybara/cook1.webp',
    'capybara/cook2.webp',
    'capybara/darkBrown1.webp',
    'capybara/darkBrown2.webp',
    'capybara/darkBrown3.webp',
    'capybara/darkBrown4.webp',
    'capybara/darkBrown5.webp',
    'capybara/darkGrey1.webp',
    'capybara/darkGrey2.webp',
    'capybara/docter1.webp',
    'capybara/docter2.webp',
    'capybara/docter3.webp',
    'capybara/green1.webp',
    'capybara/green2.webp',
    'capybara/grey1.webp',
    'capybara/grey2-1.webp',
    'capybara/grey2.webp',
    'capybara/navy1.webp',
    'capybara/navy2.webp',
    'capybara/pink1.webp',
    'capybara/pink2.webp',
    'capybara/pink3.webp',
    'capybara/pink4.webp',
    'capybara/pink5.webp',
    'capybara/pirate1.webp',
    'capybara/pirate2.webp',
    'capybara/pirate3.webp',
    'capybara/pirate4.webp',
    'capybara/pupple.webp',
    'capybara/white1.webp',
    'capybara/white2.webp',
    'capybara/yellow1.webp',
    'capybara/yellow2.webp',
    'capybara/yellow3.webp',
    'capybara/yellow4.webp',
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
