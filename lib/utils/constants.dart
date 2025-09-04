/// 게임 상수 정의
class GameConstants {
  // 게임 설정 - 카드 개수 기준
  static const int easyCardCount = 8; // 4쌍
  static const int mediumCardCount = 24; // 12쌍
  static const int hardCardCount = 32; // 16쌍

  // 그리드 크기 계산 (카드 개수에 따라)
  static int getGridSize(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return 4; // 2x4 또는 4x2
      case GameDifficulty.medium:
        return 6; // 4x6 또는 6x4
      case GameDifficulty.hard:
        return 8; // 4x8 또는 8x4
    }
  }

  // 카드 설정
  static const double cardWidth = 80.0;
  static const double cardHeight = 80.0;
  static const double cardSpacing = 10.0;

  // 게임 시간
  static const int easyTimeLimit = 120; // 2분
  static const int mediumTimeLimit = 300; // 5분
  static const int hardTimeLimit = 480; // 8분

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
  easy,
  medium,
  hard,
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
