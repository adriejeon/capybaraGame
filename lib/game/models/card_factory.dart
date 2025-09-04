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
    'capybara/blue1-1.jpg',
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
      case GameDifficulty.easy:
        return GameConstants.easyCardCount;
      case GameDifficulty.medium:
        return GameConstants.mediumCardCount;
      case GameDifficulty.hard:
        return GameConstants.hardCardCount;
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
    final gridSize = _calculateGridSize(cardCount);

    return GameBoard(
      cards: shuffledCards,
      gridWidth: gridSize.width,
      gridHeight: gridSize.height,
      difficulty: difficulty,
    );
  }

  /// 카드 개수에 따른 최적의 그리드 크기 계산
  static GridSize _calculateGridSize(int cardCount) {
    // 가능한 조합들 중에서 가장 정사각형에 가까운 형태 선택
    final List<GridSize> possibleSizes = [];

    for (int width = 2; width <= cardCount; width++) {
      if (cardCount % width == 0) {
        final height = cardCount ~/ width;
        possibleSizes.add(GridSize(width, height));
      }
    }

    // 가장 정사각형에 가까운 크기 선택
    possibleSizes.sort((a, b) {
      final ratioA = (a.width / a.height - 1).abs();
      final ratioB = (b.width / b.height - 1).abs();
      return ratioA.compareTo(ratioB);
    });

    return possibleSizes.first;
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
