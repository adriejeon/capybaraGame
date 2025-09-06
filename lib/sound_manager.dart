// lib/sound_manager.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  // 싱글톤 패턴: 앱 전체에서 하나의 인스턴스만 사용하도록 설정
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  // 배경음 플레이어
  AudioPlayer? _bgmPlayer;

  // 사운드 설정 상태
  bool _isSoundEffectEnabled = true;
  bool _isBgmEnabled = true;
  bool _isInitialized = false;

  // 설정 저장 키
  static const String _soundEffectKey = 'sound_effect_enabled';
  static const String _bgmKey = 'bgm_enabled';

  // 효과음 파일 경로를 미리 정의
  static const String cardFlipSound = 'audio/card-flip.mp3';
  static const String matchSuccessSound = 'audio/card-mach.mp3';
  static const String gameCompleteSound = 'audio/success-game.mp3';
  static const String bgmSound = 'audio/bgm.mp3';

  // Getter
  bool get isSoundEffectEnabled => _isSoundEffectEnabled;
  bool get isBgmEnabled => _isBgmEnabled;
  bool get isInitialized => _isInitialized;

  // 지연 초기화 메서드
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // 초기화 메서드
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      _bgmPlayer = AudioPlayer();
      await _loadSettings();

      // 잠시 대기 후 BGM 설정 (플레이어가 완전히 초기화될 때까지)
      await Future.delayed(const Duration(milliseconds: 100));
      await _setupBgm();

      _isInitialized = true;
    } catch (e) {
      // 초기화 실패 시 조용히 처리
    }
  }

  // 설정 불러오기
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEffectEnabled = prefs.getBool(_soundEffectKey) ?? true;
    _isBgmEnabled = prefs.getBool(_bgmKey) ?? true;
  }

  // 설정 저장
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectKey, _isSoundEffectEnabled);
    await prefs.setBool(_bgmKey, _isBgmEnabled);
  }

  // 배경음 설정
  Future<void> _setupBgm() async {
    try {
      if (_bgmPlayer == null) {
        return;
      }

      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setPlayerMode(PlayerMode.lowLatency);

      if (_isBgmEnabled) {
        await _startBgmInternal();
      }
    } catch (e) {
      // BGM 설정 실패 시 조용히 처리
    }
  }

  // 배경음 시작 (내부용 - 지연 초기화 없이)
  Future<void> _startBgmInternal() async {
    if (_isBgmEnabled && _bgmPlayer != null) {
      try {
        await _bgmPlayer!.play(AssetSource(bgmSound));
      } catch (e) {
        // BGM 재생 실패 시 조용히 처리
      }
    }
  }

  // 배경음 시작 (외부용 - 지연 초기화 포함)
  Future<void> startBgm() async {
    await _ensureInitialized();
    await _startBgmInternal();
  }

  // 배경음 정지 (내부용)
  Future<void> _stopBgmInternal() async {
    if (_bgmPlayer != null) {
      try {
        await _bgmPlayer!.stop();
      } catch (e) {
        // BGM 정지 실패 시 조용히 처리
      }
    }
  }

  // 배경음 정지 (외부용)
  Future<void> stopBgm() async {
    await _ensureInitialized();
    await _stopBgmInternal();
  }

  // 배경음 일시정지 (내부용)
  Future<void> _pauseBgmInternal() async {
    if (_bgmPlayer != null) {
      try {
        await _bgmPlayer!.pause();
      } catch (e) {
        // BGM 일시정지 실패 시 조용히 처리
      }
    }
  }

  // 배경음 일시정지 (외부용)
  Future<void> pauseBgm() async {
    await _ensureInitialized();
    await _pauseBgmInternal();
  }

  // 배경음 재개 (내부용)
  Future<void> _resumeBgmInternal() async {
    if (_isBgmEnabled && _bgmPlayer != null) {
      try {
        await _bgmPlayer!.resume();
      } catch (e) {
        // BGM 재개 실패 시 조용히 처리
      }
    }
  }

  // 배경음 재개 (외부용)
  Future<void> resumeBgm() async {
    await _ensureInitialized();
    await _resumeBgmInternal();
  }

  // 효과음 설정 토글
  Future<void> toggleSoundEffect() async {
    _isSoundEffectEnabled = !_isSoundEffectEnabled;
    await _saveSettings();
  }

  // 배경음 설정 토글
  Future<void> toggleBgm() async {
    await _ensureInitialized();
    _isBgmEnabled = !_isBgmEnabled;
    await _saveSettings();

    if (_isBgmEnabled) {
      await _startBgmInternal();
    } else {
      await _stopBgmInternal();
    }
  }

  // 짧은 효과음을 재생하는 범용 메소드
  Future<void> playSound(String soundPath) async {
    if (!_isSoundEffectEnabled) return; // 효과음이 꺼져있으면 재생하지 않음

    try {
      // 매번 새로운 AudioPlayer 인스턴스 생성 (제미나이 방법)
      final player = AudioPlayer();

      // iOS 오디오 세션 설정
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);

      // 재생 완료 이벤트 리스너 추가
      player.onPlayerComplete.listen((event) {
        // 재생 완료 후 플레이어 정리
        Future.delayed(const Duration(milliseconds: 100), () {
          player.dispose();
        });
      });

      await player.play(AssetSource(soundPath));
    } catch (e) {
      // 오디오 재생 실패 시 조용히 처리
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
    _bgmPlayer?.dispose();
  }
}
