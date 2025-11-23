/// 게임 상수 정의
class GameConstants {
  // 게임 설정 - 카드 개수 기준
  static const int level1CardCount = 6; // 3쌍 (아기 단계)
  static const int level2CardCount = 12; // 6쌍 (어린이 단계)
  static const int level3CardCount = 16; // 8쌍 (청소년 단계)
  static const int level4CardCount = 24; // 12쌍 (어른 단계)
  static const int level5CardCount = 40; // 20쌍 (신의 경지)

  // 그리드 크기 계산 (카드 개수에 따라)
  static int getGridSize(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.level1:
        return 3; // 2x3 또는 3x2
      case GameDifficulty.level2:
        return 4; // 3x4 또는 4x3
      case GameDifficulty.level3:
        return 4; // 4x4
      case GameDifficulty.level4:
        return 6; // 4x6 또는 6x4
      case GameDifficulty.level5:
        return 8; // 5x8 또는 8x5
    }
  }

  // 카드 설정
  static const double cardWidth = 80.0;
  static const double cardHeight = 80.0;
  static const double cardSpacing = 10.0;

  // 게임 시간
  static const int level1TimeLimit = 15; // 15초
  static const int level2TimeLimit = 30; // 30초
  static const int level3TimeLimit = 45; // 45초
  static const int level4TimeLimit = 70; // 70초
  static const int level5TimeLimit = 120; // 2분

  // 점수 계산
  static const int baseScore = 100;
  static const int comboMultiplier = 50;
  static const int timeBonus = 10;

  // 애니메이션
  static const Duration cardFlipDuration = Duration(milliseconds: 300);
  static const Duration cardMatchDuration = Duration(milliseconds: 500);

  // 사운드 파일 경로
  static const String cardFlipSound = 'audio/card_flip.mp3';
  static const String cardMatchSound = 'audio/card_match.mp3';
  static const String gameWinSound = 'audio/game_win.mp3';
  static const String gameLoseSound = 'audio/game_lose.mp3';
  static const String backgroundMusic = 'audio/background_music.mp3';

  // 이미지 파일 경로
  static const String cardBackImage = 'images/card-back.jpg';
  static const String mainBackgroundImage = 'images/main.jpg';

  // AdMob 설정 (테스트용)
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
}

/// 게임 난이도 열거형
enum GameDifficulty {
  level1, // 아기 단계 - 6장
  level2, // 어린이 단계 - 12장
  level3, // 청소년 단계 - 16장
  level4, // 어른 단계 - 24장
  level5, // 신의 경지 - 40장
}

/// 게임 상태 열거형
enum GameState {
  menu,
  playing,
  paused,
  gameOver,
  settings,
}

/// 카드 상태 열거형
enum CardState {
  hidden,
  revealed,
  matched,
}
