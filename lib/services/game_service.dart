import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// 게임 서비스 (리더보드)
///
/// static 메서드로 구현하여 간편하게 사용
class GameService {
  // Android 리더보드 ID
  static const String _androidLeaderboardId = 'CgkI6rHltasIEAIQAQ';

  // iOS 리더보드 ID
  static const String _iosLeaderboardId = 'leaderboard_capybara';

  // 로그인 상태 추적
  static bool _isSignedIn = false;
  static bool get isSignedIn => _isSignedIn;

  /// 게임 서비스 로그인
  ///
  /// 앱 시작 시 호출하여 자동 로그인 시도
  /// 반환값: true = 로그인 성공, false = 실패
  static Future<bool> signIn() async {
    // 웹이나 지원하지 않는 플랫폼은 스킵
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      print('[GameService] 지원하지 않는 플랫폼');
      return false;
    }

    try {
      print('[GameService] 로그인 시도 중...');

      final result = await GamesServices.signIn();
      _isSignedIn = result == 'success';

      if (_isSignedIn) {
        print('[GameService] 로그인 성공 ✓');
      } else {
        print('[GameService] 로그인 실패 또는 취소: $result');
      }

      return _isSignedIn;
    } catch (e) {
      print('[GameService] 로그인 오류: $e');
      _isSignedIn = false;
      return false;
    }
  }

  /// 점수 제출
  ///
  /// 게임 완료 시 호출하여 리더보드에 점수 등록
  /// [score]: 제출할 점수
  static Future<void> submitScore(int score) async {
    // 웹이나 지원하지 않는 플랫폼은 스킵
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      print('[GameService] 점수 제출: 지원하지 않는 플랫폼');
      return;
    }

    // 로그인 안 되어 있으면 조용히 스킵 (게임 플레이에 영향 없음)
    if (!_isSignedIn) {
      print('[GameService] 점수 제출: 로그인 안 됨 - 스킵');
      return;
    }

    try {
      print('[GameService] 점수 제출 시도: $score');

      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: _androidLeaderboardId,
          iOSLeaderboardID: _iosLeaderboardId,
          value: score,
        ),
      );

      print('[GameService] 점수 제출 성공 ✓ ($score점)');
    } catch (e) {
      print('[GameService] 점수 제출 오류: $e');
      // 오류 발생 시에도 게임 진행에 영향 없도록 조용히 처리
    }
  }

  /// 리더보드 표시
  ///
  /// 리더보드 버튼 클릭 시 호출하여 순위 UI 표시
  /// iOS/Android 모두 동일한 로직: 일단 리더보드 표시 시도 → 실패 시 로그인 후 재시도
  static Future<void> showLeaderboard() async {
    // 웹이나 지원하지 않는 플랫폼은 스킵
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      print('[GameService] 리더보드 표시: 지원하지 않는 플랫폼');
      throw Exception('지원하지 않는 플랫폼입니다.');
    }

    try {
      // 1차: 바로 리더보드 표시 시도 (로그인 여부 체크 없이)
      print('[GameService] 리더보드 표시 시도 (1차)...');

      await GamesServices.showLeaderboards(
        androidLeaderboardID: _androidLeaderboardId,
        iOSLeaderboardID: _iosLeaderboardId,
      );

      print('[GameService] 리더보드 표시 성공 ✓');
    } catch (e) {
      // 2차: 리더보드 표시 실패 시 로그인 시도
      print('[GameService] 리더보드 표시 실패 - 로그인 시도: $e');

      try {
        print('[GameService] 로그인 시도 중...');
        // 로그인 결과 체크 없이 await만 수행
        await GamesServices.signIn();
        print('[GameService] 로그인 완료');

        // 3차: 로그인 후 다시 리더보드 표시 시도
        print('[GameService] 리더보드 표시 시도 (2차)...');

        await GamesServices.showLeaderboards(
          androidLeaderboardID: _androidLeaderboardId,
          iOSLeaderboardID: _iosLeaderboardId,
        );

        print('[GameService] 리더보드 표시 성공 ✓ (로그인 후)');
      } catch (signInError) {
        print('[GameService] 로그인 또는 리더보드 표시 오류: $signInError');
        // 최종 실패 시 예외 전달
        rethrow;
      }
    }
  }
}
