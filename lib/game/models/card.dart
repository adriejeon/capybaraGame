import '../../utils/constants.dart';

/// 카드 모델 클래스
class GameCard {
  final int id;
  final String imagePath;
  final int pairId;
  CardState state;
  bool isFlipped;
  bool isMatched;
  bool isRemoving; // 카드가 사라지는 애니메이션 중인지

  GameCard({
    required this.id,
    required this.imagePath,
    required this.pairId,
    this.state = CardState.hidden,
    this.isFlipped = false,
    this.isMatched = false,
    this.isRemoving = false,
  });

  /// 카드 뒤집기
  void flip() {
    if (!isMatched) {
      isFlipped = !isFlipped;
      state = isFlipped ? CardState.revealed : CardState.hidden;
    }
  }

  /// 카드 매칭 완료
  void markAsMatched() {
    isMatched = true;
    state = CardState.matched;
  }

  /// 카드 제거 시작
  void startRemoving() {
    isRemoving = true;
  }

  /// 카드 리셋
  void reset() {
    isFlipped = false;
    isMatched = false;
    isRemoving = false;
    state = CardState.hidden;
  }

  /// 카드 복사
  GameCard copyWith({
    int? id,
    String? imagePath,
    int? pairId,
    CardState? state,
    bool? isFlipped,
    bool? isMatched,
    bool? isRemoving,
  }) {
    return GameCard(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      pairId: pairId ?? this.pairId,
      state: state ?? this.state,
      isFlipped: isFlipped ?? this.isFlipped,
      isMatched: isMatched ?? this.isMatched,
      isRemoving: isRemoving ?? this.isRemoving,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameCard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'GameCard(id: $id, pairId: $pairId, state: $state, isFlipped: $isFlipped, isMatched: $isMatched, isRemoving: $isRemoving)';
  }
}

/// 게임 보드 모델
class GameBoard {
  final List<GameCard> cards;
  final int gridWidth;
  final int gridHeight;
  final GameDifficulty difficulty;

  GameBoard({
    required this.cards,
    required this.gridWidth,
    required this.gridHeight,
    required this.difficulty,
  });

  /// 카드 찾기
  GameCard? findCard(int id) {
    try {
      return cards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 뒤집힌 카드들 찾기
  List<GameCard> getRevealedCards() {
    return cards.where((card) => card.isFlipped && !card.isMatched).toList();
  }

  /// 매칭된 카드들 찾기
  List<GameCard> getMatchedCards() {
    return cards.where((card) => card.isMatched).toList();
  }

  /// 게임 완료 여부 확인
  bool isGameComplete() {
    return cards.every((card) => card.isMatched);
  }

  /// 모든 카드 리셋
  void resetAllCards() {
    for (final card in cards) {
      card.reset();
    }
  }

  /// 게임 보드 복사
  GameBoard copyWith({
    List<GameCard>? cards,
    int? gridWidth,
    int? gridHeight,
    GameDifficulty? difficulty,
  }) {
    return GameBoard(
      cards: cards ?? this.cards,
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
