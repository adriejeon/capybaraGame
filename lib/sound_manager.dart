// lib/sound_manager.dart

import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  // 싱글톤 패턴: 앱 전체에서 하나의 인스턴스만 사용하도록 설정
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  // 효과음 파일 경로를 미리 정의
  static const String cardFlipSound = 'audio/card-flip.mp3';
  static const String matchSuccessSound = 'audio/card-mach.mp3';
  static const String gameCompleteSound = 'audio/success-game.mp3';

  // 짧은 효과음을 재생하는 범용 메소드
  Future<void> playSound(String soundPath) async {
    try {
      // 매번 새로운 AudioPlayer 인스턴스 생성 (제미나이 방법)
      final player = AudioPlayer();

      // iOS 오디오 세션 설정
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);

      // 재생 완료 이벤트 리스너 추가
      player.onPlayerComplete.listen((event) {
        print('🔊 오디오 재생 완료: $soundPath');
        // 재생 완료 후 플레이어 정리
        Future.delayed(const Duration(milliseconds: 100), () {
          player.dispose();
        });
      });

      await player.play(AssetSource(soundPath));
      print('🔊 오디오 재생 시작: $soundPath');
    } catch (e) {
      // 오디오 재생 실패 시 디버깅을 위해 로그 출력
      print('🔊 오디오 재생 실패: $e');
      print('🔊 시도한 파일 경로: $soundPath');
    }
  }

  // 카드 뒤집기 효과음
  Future<void> playCardFlipSound() async {
    await playSound(cardFlipSound);
  }

  // 카드 짝 맞추기 성공 효과음
  Future<void> playMatchSuccessSound() async {
    await playSound(matchSuccessSound);
  }

  // 게임 완료 효과음
  Future<void> playGameCompleteSound() async {
    await playSound(gameCompleteSound);
  }

  // 리소스 정리
  void dispose() {
    // 더 이상 글로벌 플레이어를 사용하지 않으므로 정리할 것이 없음
  }
}
