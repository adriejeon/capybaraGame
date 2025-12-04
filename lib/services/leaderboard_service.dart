import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import '../utils/constants.dart';
import '../config/leaderboard_config.dart';

/// 리더보드 서비스
/// Game Center (iOS) 및 Google Play Games (Android) 연동
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  bool _isSignedIn = false;
  bool _isInitialized = false;

  /// 리더보드 ID 가져오기 (설정 파일에서)
  static Map<GameDifficulty, LeaderboardIds> get _leaderboardIds => {
    GameDifficulty.level1: LeaderboardIds(
      ios: LeaderboardConfig.iosLevel1,
      android: LeaderboardConfig.androidLevel1,
    ),
    GameDifficulty.level2: LeaderboardIds(
      ios: LeaderboardConfig.iosLevel2,
      android: LeaderboardConfig.androidLevel2,
    ),
    GameDifficulty.level3: LeaderboardIds(
      ios: LeaderboardConfig.iosLevel3,
      android: LeaderboardConfig.androidLevel3,
    ),
    GameDifficulty.level4: LeaderboardIds(
      ios: LeaderboardConfig.iosLevel4,
      android: LeaderboardConfig.androidLevel4,
    ),
    GameDifficulty.level5: LeaderboardIds(
      ios: LeaderboardConfig.iosLevel5,
      android: LeaderboardConfig.androidLevel5,
    ),
  };

  /// 게임 서비스 초기화 및 로그인
  Future<bool> initialize() async {
    // 리더보드가 비활성화되어 있으면 스킵
    if (!LeaderboardConfig.isEnabled) {
      print('게임 서비스: 리더보드가 비활성화됨');
      return false;
    }

    // 이미 초기화되었고 로그인되어 있으면 바로 반환
    if (_isInitialized && _isSignedIn) {
      print('게임 서비스: 이미 로그인됨');
      return true;
    }

    // 웹이나 지원하지 않는 플랫폼은 스킵
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      print('게임 서비스: 지원하지 않는 플랫폼');
      _isInitialized = true;
      return false;
    }

    // 디버그 정보 출력
    LeaderboardConfig.printDebugInfo();

    try {
      print('게임 서비스: 로그인 시도 중...');
      
      // 게임 서비스 로그인 시도
      final result = await GamesServices.signIn();
      _isSignedIn = result == 'success';
      _isInitialized = true;
      
      if (_isSignedIn) {
        print('게임 서비스: 로그인 성공 ✓');
      } else {
        print('게임 서비스: 로그인 실패 또는 취소 (결과: $result)');
      }
      
      return _isSignedIn;
    } catch (e) {
      print('게임 서비스: 초기화 오류 - $e');
      _isInitialized = true;
      _isSignedIn = false;
      return false;
    }
  }

  /// 로그인 상태 확인
  bool get isSignedIn => _isSignedIn;

  /// 점수 제출
  Future<bool> submitScore({
    required GameDifficulty difficulty,
    required int score,
  }) async {
    // 리더보드가 비활성화되어 있으면 스킵
    if (!LeaderboardConfig.isEnabled) {
      print('점수 제출: 리더보드가 비활성화됨');
      return false;
    }

    // 리더보드가 설정되지 않았으면 스킵 (경고 메시지 출력)
    if (!LeaderboardConfig.isConfigured) {
      print('점수 제출: 리더보드가 아직 설정되지 않음 (개발 모드)');
      return false;
    }

    // 로그인되지 않았으면 초기화 시도
    if (!_isSignedIn) {
      print('점수 제출: 로그인 필요 - 초기화 시도');
      final success = await initialize();
      if (!success) {
        print('점수 제출: 로그인 실패 - 점수 제출 중단');
        return false;
      }
    }

    try {
      final leaderboardId = _getLeaderboardId(difficulty);
      if (leaderboardId == null) {
        print('점수 제출: 리더보드 ID를 찾을 수 없음 (난이도: ${difficulty.name})');
        return false;
      }

      print('점수 제출: 시도 중... (점수: $score, 난이도: ${difficulty.name})');
      
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: leaderboardId.android,
          iOSLeaderboardID: leaderboardId.ios,
          value: score,
        ),
      );

      print('점수 제출: 성공 ✓ ($score점 - ${difficulty.name})');
      return true;
    } catch (e) {
      print('점수 제출: 오류 발생 - $e');
      return false;
    }
  }

  /// 리더보드 표시
  Future<bool> showLeaderboard({GameDifficulty? difficulty}) async {
    // 리더보드가 비활성화되어 있으면 스킵
    if (!LeaderboardConfig.isEnabled) {
      print('리더보드 표시: 리더보드가 비활성화됨');
      return false;
    }

    // 로그인되지 않았으면 초기화 시도
    if (!_isSignedIn) {
      print('리더보드 표시: 로그인 필요 - 초기화 시도');
      final success = await initialize();
      if (!success) {
        print('리더보드 표시: 로그인 실패');
        return false;
      }
    }

    try {
      print('리더보드 표시: 시도 중...');
      
      if (difficulty != null) {
        // 특정 난이도 리더보드 표시
        final leaderboardId = _getLeaderboardId(difficulty);
        if (leaderboardId == null) {
          print('리더보드 표시: 리더보드 ID를 찾을 수 없음 (난이도: ${difficulty.name})');
          return false;
        }

        print('리더보드 표시: 특정 난이도 (${difficulty.name})');
        await GamesServices.showLeaderboards(
          androidLeaderboardID: leaderboardId.android,
          iOSLeaderboardID: leaderboardId.ios,
        );
      } else {
        // 전체 리더보드 목록 표시 (플랫폼 기본 UI)
        print('리더보드 표시: 전체 목록');
        await GamesServices.showLeaderboards();
      }

      print('리더보드 표시: 성공 ✓');
      return true;
    } catch (e) {
      print('리더보드 표시: 오류 발생 - $e');
      return false;
    }
  }

  /// 업적 해제 (나중에 확장 가능)
  Future<bool> unlockAchievement(String achievementId) async {
    if (!_isSignedIn) {
      final success = await initialize();
      if (!success) return false;
    }

    try {
      await GamesServices.unlock(
        achievement: Achievement(
          androidID: achievementId,
          iOSID: achievementId,
          percentComplete: 100,
        ),
      );
      print('업적 해제 성공: $achievementId');
      return true;
    } catch (e) {
      print('업적 해제 오류: $e');
      return false;
    }
  }

  /// 업적 목록 표시
  Future<void> showAchievements() async {
    if (!_isSignedIn) {
      final success = await initialize();
      if (!success) return;
    }

    try {
      await GamesServices.showAchievements();
      print('업적 목록 표시');
    } catch (e) {
      print('업적 목록 표시 오류: $e');
    }
  }

  /// 난이도에 따른 리더보드 ID 가져오기
  LeaderboardIds? _getLeaderboardId(GameDifficulty difficulty) {
    return _leaderboardIds[difficulty];
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      // games_services 패키지는 명시적인 로그아웃을 지원하지 않음
      // 플랫폼의 설정에서 직접 로그아웃 필요
      _isSignedIn = false;
      print('게임 서비스 로그아웃');
    } catch (e) {
      print('로그아웃 오류: $e');
    }
  }
}

/// 리더보드 ID 클래스
class LeaderboardIds {
  final String ios;
  final String android;

  const LeaderboardIds({
    required this.ios,
    required this.android,
  });
}

