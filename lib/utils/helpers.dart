import 'dart:math';
import 'package:flutter/material.dart';
import 'constants.dart';

/// 게임 헬퍼 함수들
class GameHelpers {
  /// 리스트를 섞는 함수
  static List<T> shuffleList<T>(List<T> list) {
    final shuffledList = List<T>.from(list);
    shuffledList.shuffle(Random());
    return shuffledList;
  }

  /// 카드 쌍을 생성하는 함수
  static List<int> generateCardPairs(int pairCount) {
    final List<int> cards = [];
    for (int i = 0; i < pairCount; i++) {
      cards.addAll([i, i]); // 각 카드를 2개씩 추가
    }
    return shuffleList(cards);
  }

  /// 난이도에 따른 카드 쌍 수 계산
  static int getPairCount(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return GameConstants.easyCardCount ~/ 2;
      case GameDifficulty.medium:
        return GameConstants.mediumCardCount ~/ 2;
      case GameDifficulty.hard:
        return GameConstants.hardCardCount ~/ 2;
    }
  }

  /// 난이도에 따른 시간 제한 반환
  static int getTimeLimit(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return GameConstants.easyTimeLimit;
      case GameDifficulty.medium:
        return GameConstants.mediumTimeLimit;
      case GameDifficulty.hard:
        return GameConstants.hardTimeLimit;
    }
  }

  /// 점수 계산
  static int calculateScore(
      int matchedPairs, int comboCount, int remainingTime) {
    final baseScore = matchedPairs * GameConstants.baseScore;
    final comboBonus = comboCount * GameConstants.comboMultiplier;
    final timeBonus = remainingTime * GameConstants.timeBonus;
    return baseScore + comboBonus + timeBonus;
  }

  /// 시간을 MM:SS 형식으로 포맷
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// 화면 크기에 따른 카드 크기 계산
  static Size calculateCardSize(Size screenSize, int gridSize) {
    final availableWidth =
        screenSize.width - (gridSize + 1) * GameConstants.cardSpacing;
    final availableHeight =
        screenSize.height - (gridSize + 1) * GameConstants.cardSpacing;

    final cardWidth = availableWidth / gridSize;
    final cardHeight = availableHeight / gridSize;

    // 최소/최대 크기 제한
    final minSize = 60.0;
    final maxSize = 120.0;

    final finalWidth = cardWidth.clamp(minSize, maxSize);
    final finalHeight = cardHeight.clamp(minSize, maxSize);

    return Size(finalWidth, finalHeight);
  }

  /// 색상을 밝게/어둡게 조정
  static Color adjustColorBrightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final adjusted =
        hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return adjusted.toColor();
  }

  /// 랜덤 색상 생성
  static Color generateRandomColor() {
    final random = Random();
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1.0,
    );
  }
}
