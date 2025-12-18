import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../game/models/spot_difference_data.dart';
import '../../utils/constants.dart';
import '../../ads/admob_handler.dart';
import '../../data/ticket_manager.dart';
import '../../services/daily_mission_service.dart';
import '../../sound_manager.dart';
import '../../l10n/app_localizations.dart';

/// 틀린그림찾기 게임 화면
class SpotDifferenceScreen extends StatefulWidget {
  final GameDifficulty difficulty;

  const SpotDifferenceScreen({
    super.key,
    required this.difficulty,
  });

  @override
  State<SpotDifferenceScreen> createState() => _SpotDifferenceScreenState();
}

class _SpotDifferenceScreenState extends State<SpotDifferenceScreen>
    with TickerProviderStateMixin {
  final AdmobHandler _adMobHandler = AdmobHandler();
  final TicketManager _ticketManager = TicketManager();
  final DailyMissionService _missionService = DailyMissionService();
  final SoundManager _soundManager = SoundManager();
  final SpotDifferenceDataManager _dataManager = SpotDifferenceDataManager();

  SpotDifferenceStage? _currentStage;
  List<bool> _foundSpots = []; // 각 스팟 찾음 여부
  int _remainingTime = 0;
  Timer? _gameTimer;
  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _hasUsedHint = false;
  bool _isShowingHint = false;
  int _wrongTaps = 0; // 틀린 터치 횟수

  // 디버그 모드 (개발 중에만 true로 설정)
  static const bool _debugMode = false;
  String _lastTapCoord = '';

  // 이미지 확대 보기 상태
  bool _isZoomed = false;
  bool _isZoomingOriginal = true; // true: 원본 이미지 확대, false: 틀린 이미지 확대

  // 이미지 비율 (동적으로 계산)
  double _imageAspectRatio = 0.56; // 기본값 (572/1024)

  // 애니메이션
  late AnimationController _wrongTapController;
  late Animation<double> _wrongTapAnimation;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _setupAnimations();
    _loadAds();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _wrongTapController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _wrongTapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _wrongTapAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wrongTapController, curve: Curves.elasticOut),
    );
  }

  void _loadAds() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _adMobHandler.loadInterstitialAd();
      await _adMobHandler.loadRewardedAd();
    });
  }

  void _initializeGame() {
    final level =
        SpotDifferenceDataManager.difficultyToLevel(widget.difficulty);
    _currentStage = _dataManager.getRandomStage(level);

    if (_currentStage == null) {
      print('[SpotDifference] 스테이지 로드 실패');
      return;
    }

    _foundSpots = List.filled(_currentStage!.spots.length, false);
    _remainingTime = _currentStage!.timeLimit;
    _isGameOver = false;
    _isGameWon = false;
    _hasUsedHint = false;
    _isShowingHint = false;
    _wrongTaps = 0;

    // 이미지 비율 계산
    _loadImageAspectRatio();

    _startTimer();
  }

  /// 이미지 비율을 동적으로 계산
  void _loadImageAspectRatio() {
    if (_currentStage == null) return;

    final image = Image.asset(_currentStage!.originalImage);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageAspectRatio = info.image.height / info.image.width;
          });
          print(
              '[SpotDifference] 이미지 비율: $_imageAspectRatio (${info.image.width}x${info.image.height})');
        }
      }),
    );
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0 && !_isGameOver) {
        setState(() {
          _remainingTime--;
        });
      } else if (_remainingTime <= 0 && !_isGameOver) {
        // 시간초과 시 광고 보고 시간 추가 옵션 제공
        _showTimeUpDialog();
      }
    });
  }

  void _pauseTimer() {
    _gameTimer?.cancel();
  }

  void _resumeTimer() {
    if (!_isGameOver) {
      _startTimer();
    }
  }

  /// 이미지 터치 처리
  void _onImageTapped(Offset tapPosition, Size imageSize, bool isOriginal) {
    if (_isGameOver || _currentStage == null) return;

    // 비율 좌표로 변환
    final relativeX = tapPosition.dx / imageSize.width;
    final relativeY = tapPosition.dy / imageSize.height;

    print('[SpotDifference] 터치: ($relativeX, $relativeY)');

    // 디버그 모드: 터치 좌표 표시
    if (_debugMode) {
      setState(() {
        _lastTapCoord =
            'x: ${relativeX.toStringAsFixed(2)}, y: ${relativeY.toStringAsFixed(2)}';
      });
    }

    // 각 스팟에 대해 터치 여부 확인
    bool foundAny = false;
    for (int i = 0; i < _currentStage!.spots.length; i++) {
      if (_foundSpots[i]) continue; // 이미 찾은 스팟

      final spot = _currentStage!.spots[i];
      final distance = _calculateDistance(relativeX, relativeY, spot.x, spot.y);

      // distance는 제곱 거리이므로, radius도 제곱해서 비교하거나 sqrt를 사용
      if (distance <= spot.radius * spot.radius) {
        // 정답!
        setState(() {
          _foundSpots[i] = true;
        });
        _soundManager.playMatchSuccessSound();
        foundAny = true;
        print(
            '[SpotDifference] 스팟 $i 발견! (터치: $relativeX, $relativeY, 스팟: ${spot.x}, ${spot.y}, 거리: ${sqrt(distance)}, 반경: ${spot.radius})');
        break;
      }
    }

    if (!foundAny) {
      // 틀림
      _wrongTaps++;
      _wrongTapController.forward(from: 0.0);
      print('[SpotDifference] 틀림! 총 $_wrongTaps회');
    }

    // 모든 스팟을 찾았는지 확인
    if (_foundSpots.every((found) => found)) {
      _endGame(true);
    }
  }

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    return ((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
  }

  void _endGame(bool isWin) {
    _gameTimer?.cancel();
    setState(() {
      _isGameOver = true;
      _isGameWon = isWin;
    });

    if (isWin) {
      _soundManager.playGameCompleteSound();
      _showWinDialog();
    } else {
      _showLoseDialog();
    }
  }

  /// 승리 다이얼로그
  void _showWinDialog() async {
    if (!mounted) return;

    // 뽑기권 획득 시도
    await _ticketManager.initialize();
    final canEarn = _ticketManager.canEarnTicketToday;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GameResultDialog(
        isWin: true,
        foundCount: _foundSpots.where((f) => f).length,
        totalCount: _currentStage?.spots.length ?? 0,
        wrongTaps: _wrongTaps,
        canEarnTicket: canEarn,
        remainingTickets: _ticketManager.remainingDailyTickets,
        onClaimTicket: () async {
          Navigator.of(context).pop();
          await _claimTicketWithAd();
        },
        onHome: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
        onReplay: () {
          Navigator.of(context).pop();
          _restartGame();
        },
      ),
    );
  }

  /// 전면 광고 보고 뽑기권 획득
  Future<void> _claimTicketWithAd() async {
    if (!mounted) return;

    // 전면 광고 표시
    await _adMobHandler.showInterstitialAd();

    if (!mounted) return;

    // 뽑기권 획득
    await _claimTicket();
  }

  /// 뽑기권 획득
  Future<void> _claimTicket() async {
    final earned = await _ticketManager.earnTicket();

    if (!mounted) return;

    if (earned) {
      // 데일리 미션 업데이트
      await _missionService.completeGame();

      _showTicketEarnedDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ko'
                ? '오늘 뽑기권을 모두 획득했습니다!'
                : 'You\'ve earned all tickets for today!',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  /// 뽑기권 획득 다이얼로그
  void _showTicketEarnedDialog() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F4F8), Color(0xFFD6EBF5)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF4A90E2), width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 뽑기권 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/gacha_coin.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[600]!, width: 2),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_number,
                                size: 40, color: Colors.white),
                            SizedBox(height: 4),
                            Text(
                              '+1',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isKorean ? '뽑기권 1개 획득!' : 'Got 1 Gacha Ticket!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90E2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isKorean
                    ? '현재 뽑기권: ${_ticketManager.ticketCount}개'
                    : 'Current Tickets: ${_ticketManager.ticketCount}',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                isKorean
                    ? '오늘 남은 획득 횟수: ${_ticketManager.remainingDailyTickets}회'
                    : 'Remaining today: ${_ticketManager.remainingDailyTickets}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A90E2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isKorean ? '홈으로' : 'Home',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _restartGame();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A90E2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isKorean ? '다시하기' : 'Play Again',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 시간초과 다이얼로그 (광고 보고 시간 추가 옵션)
  void _showTimeUpDialog() {
    _gameTimer?.cancel();
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isKorean ? '시간 초과!' : 'Time\'s Up!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              isKorean
                  ? '${_foundSpots.where((f) => f).length}/${_currentStage?.spots.length ?? 0}개 발견'
                  : 'Found ${_foundSpots.where((f) => f).length}/${_currentStage?.spots.length ?? 0}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD699)),
              ),
              child: Column(
                children: [
                  Icon(Icons.play_circle_outline,
                      size: 40, color: Colors.orange[700]),
                  const SizedBox(height: 8),
                  Text(
                    isKorean
                        ? '광고를 보고\n30초를 추가하시겠어요?'
                        : 'Watch an ad to\nadd 30 seconds?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _watchAdForExtraTime();
                  },
                  icon: const Icon(Icons.play_circle_outline, size: 24),
                  label: Text(
                    isKorean ? '광고 보고 30초 추가' : 'Watch Ad for +30s',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _endGame(false);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A90E2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isKorean ? '포기' : 'Give Up',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 패배 다이얼로그
  void _showLoseDialog() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isKorean ? '게임 오버!' : 'Game Over!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              isKorean
                  ? '${_foundSpots.where((f) => f).length}/${_currentStage?.spots.length ?? 0}개 발견'
                  : 'Found ${_foundSpots.where((f) => f).length}/${_currentStage?.spots.length ?? 0}',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isKorean ? '홈으로' : 'Home',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _restartGame();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isKorean ? '다시하기' : 'Retry',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    _gameTimer?.cancel();
    setState(() {
      _initializeGame();
    });
  }

  /// 광고 보고 30초 추가
  Future<void> _watchAdForExtraTime() async {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    // 보상형 광고 표시
    if (_adMobHandler.isRewardedAdLoaded) {
      bool rewarded = false;

      await _adMobHandler.showRewardedAd(
        onRewarded: (rewardItem) {
          rewarded = true;
        },
      );

      if (rewarded && mounted) {
        // 30초 추가
        setState(() {
          _remainingTime += 30;
        });
        _startTimer();

        // 성공 메시지
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isKorean ? '30초가 추가되었습니다!' : '30 seconds added!',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // 다음 광고 로드
        await _adMobHandler.loadRewardedAd();
      } else {
        // 광고를 끝까지 보지 않음 - 게임 종료
        if (mounted) {
          _endGame(false);
        }
      }
    } else {
      // 광고가 로드되지 않음 - 게임 종료
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKorean ? '광고를 불러올 수 없습니다' : 'Cannot load ad',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // 게임 종료
        _endGame(false);
      }
    }
  }

  /// 힌트 사용 (광고 시청 후)
  void _useHint() async {
    if (_hasUsedHint || _isGameOver) return;

    _pauseTimer();

    // 보상형 광고 표시
    if (_adMobHandler.isRewardedAdLoaded) {
      bool rewarded = false;

      await _adMobHandler.showRewardedAd(
        onRewarded: (reward) {
          rewarded = true;
        },
        onAdDismissed: () {
          if (rewarded) {
            _showHintSpots();
          }
          _resumeTimer();
        },
        onAdFailedToShow: (ad) {
          _resumeTimer();
        },
      );
    } else {
      // 광고 로드 안됨 - 바로 힌트 표시 (개발용)
      _showHintSpots();
      _resumeTimer();
    }
  }

  void _showHintSpots() {
    setState(() {
      _hasUsedHint = true;
      _isShowingHint = true;
    });

    // 2초 후 힌트 숨기기
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isShowingHint = false;
        });
      }
    });
  }

  /// 이미지 확대 보기
  void _showZoomedImage(bool isOriginal) {
    _pauseTimer();
    setState(() {
      _isZoomed = true;
      _isZoomingOriginal = isOriginal;
    });
  }

  void _closeZoomedImage() {
    setState(() {
      _isZoomed = false;
    });
    _resumeTimer();
  }

  String _getDifficultyText() {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      switch (widget.difficulty) {
        case GameDifficulty.level1:
          return '레벨 1';
        case GameDifficulty.level2:
          return '레벨 2';
        case GameDifficulty.level3:
          return '레벨 3';
        case GameDifficulty.level4:
          return '레벨 4';
        case GameDifficulty.level5:
          return '레벨 5';
      }
    }
    switch (widget.difficulty) {
      case GameDifficulty.level1:
        return localizations.level1;
      case GameDifficulty.level2:
        return localizations.level2;
      case GameDifficulty.level3:
        return localizations.level3;
      case GameDifficulty.level4:
        return localizations.level4;
      case GameDifficulty.level5:
        return localizations.level5;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStage == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('틀린그림찾기')),
        body: const Center(child: Text('스테이지를 불러올 수 없습니다.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_getDifficultyText()} - 틀린그림찾기'),
            if (_debugMode && _currentStage != null)
              Text(
                '스테이지: ${_currentStage!.level}-${_currentStage!.stage}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 게임 정보 바
              _buildInfoBar(),

              // 이미지 영역
              Expanded(
                child: _buildImageArea(),
              ),

              // 힌트 버튼
              _buildHintButton(),

              // 하단 배너 광고
              const _BannerAdContainer(),
            ],
          ),

          // 확대 보기 오버레이
          if (_isZoomed) _buildZoomOverlay(),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    final foundCount = _foundSpots.where((f) => f).length;
    final totalCount = _currentStage?.spots.length ?? 0;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _isShowingHint ? const Color(0xFFFFF8E1) : const Color(0xFFE6F3FF),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                  isKorean ? '시간' : 'Time', _formatTime(_remainingTime)),
              _buildInfoItem(
                  isKorean ? '발견' : 'Found', '$foundCount/$totalCount'),
              _buildInfoItem(isKorean ? '오답' : 'Wrong', '$_wrongTaps'),
            ],
          ),
          // 디버그 모드: 터치 좌표 표시
          if (_debugMode && _lastTapCoord.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📍 터치 좌표: $_lastTapCoord',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4A90E2),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF2C5F8B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildImageArea() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // 원본 이미지
            _buildInteractiveImage(
              imagePath: _currentStage!.originalImage,
              isOriginal: true,
              label: Localizations.localeOf(context).languageCode == 'ko'
                  ? '원본'
                  : 'Original',
            ),
            const SizedBox(height: 8),
            // 틀린그림 이미지
            _buildInteractiveImage(
              imagePath: _currentStage!.wrongImage,
              isOriginal: false,
              label: Localizations.localeOf(context).languageCode == 'ko'
                  ? '틀린그림'
                  : 'Different',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveImage({
    required String imagePath,
    required bool isOriginal,
    required String label,
  }) {
    return Column(
      children: [
        // 라벨
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
            GestureDetector(
              onTap: () => _showZoomedImage(isOriginal),
              child: const Row(
                children: [
                  Icon(Icons.zoom_in, size: 20, color: Color(0xFF4A90E2)),
                  SizedBox(width: 4),
                  Text(
                    '확대',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 이미지
        LayoutBuilder(
          builder: (context, constraints) {
            final imageHeight = constraints.maxWidth * _imageAspectRatio;
            return GestureDetector(
              onTapDown: (details) {
                if (!_isGameOver) {
                  _onImageTapped(
                    details.localPosition,
                    Size(constraints.maxWidth, imageHeight),
                    isOriginal,
                  );
                }
              },
              child: Container(
                width: constraints.maxWidth,
                height: imageHeight, // 동적 비율
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A90E2),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 이미지
                      Image.asset(
                        imagePath,
                        fit:
                            BoxFit.contain, // cover -> contain으로 변경 (이미지 전체 표시)
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  imagePath.split('/').last,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // 찾은 스팟 표시
                      ..._buildFoundSpotMarkers(constraints.maxWidth),

                      // 힌트 표시
                      if (_isShowingHint)
                        ..._buildHintMarkers(constraints.maxWidth),

                      // 디버그 모드: 모든 스팟 위치 표시
                      if (_debugMode)
                        ..._buildDebugSpotMarkers(constraints.maxWidth),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildFoundSpotMarkers(double imageWidth) {
    final markers = <Widget>[];
    final imageHeight = imageWidth * _imageAspectRatio;

    for (int i = 0; i < _foundSpots.length; i++) {
      if (_foundSpots[i]) {
        final spot = _currentStage!.spots[i];
        markers.add(
          Positioned(
            left: spot.x * imageWidth - 15,
            top: spot.y * imageHeight - 15,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 3),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.green,
                size: 20,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  List<Widget> _buildHintMarkers(double imageWidth) {
    final markers = <Widget>[];
    final imageHeight = imageWidth * _imageAspectRatio;

    for (int i = 0; i < _foundSpots.length; i++) {
      if (!_foundSpots[i]) {
        // 아직 찾지 못한 스팟만 힌트 표시
        final spot = _currentStage!.spots[i];
        markers.add(
          Positioned(
            left: spot.x * imageWidth - 20,
            top: spot.y * imageHeight - 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange, width: 3),
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  /// 디버그 모드: 모든 스팟 위치 표시
  List<Widget> _buildDebugSpotMarkers(double imageWidth) {
    final markers = <Widget>[];
    final imageHeight = imageWidth * _imageAspectRatio;

    for (int i = 0; i < _foundSpots.length; i++) {
      final spot = _currentStage!.spots[i];
      final isFound = _foundSpots[i];

      markers.add(
        Positioned(
          left: spot.x * imageWidth - 20,
          top: spot.y * imageHeight - 20,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isFound ? Colors.green : Colors.red,
                width: 2,
              ),
              color: isFound
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: isFound ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );

      // 반경 표시 (원)
      markers.add(
        Positioned(
          left: spot.x * imageWidth - spot.radius * imageWidth,
          top: spot.y * imageHeight - spot.radius * imageWidth,
          child: Container(
            width: spot.radius * imageWidth * 2,
            height: spot.radius * imageWidth * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isFound
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildHintButton() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_hasUsedHint && !_isGameOver)
            GestureDetector(
              onTap: _useHint,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isKorean ? '힌트 보기 (AD)' : 'Hint (AD)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoomOverlay() {
    return GestureDetector(
      onTap: _closeZoomedImage,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.0,
                child: Image.asset(
                  _isZoomingOriginal
                      ? _currentStage!.originalImage
                      : _currentStage!.wrongImage,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 닫기 버튼
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: _closeZoomedImage,
              ),
            ),
            // 라벨
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isZoomingOriginal
                      ? (Localizations.localeOf(context).languageCode == 'ko'
                          ? '원본'
                          : 'Original')
                      : (Localizations.localeOf(context).languageCode == 'ko'
                          ? '틀린그림'
                          : 'Different'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 게임 결과 다이얼로그
class _GameResultDialog extends StatelessWidget {
  final bool isWin;
  final int foundCount;
  final int totalCount;
  final int wrongTaps;
  final bool canEarnTicket;
  final int remainingTickets;
  final VoidCallback onClaimTicket;
  final VoidCallback onHome;
  final VoidCallback onReplay;

  const _GameResultDialog({
    required this.isWin,
    required this.foundCount,
    required this.totalCount,
    required this.wrongTaps,
    required this.canEarnTicket,
    required this.remainingTickets,
    required this.onClaimTicket,
    required this.onHome,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F4F8), Color(0xFFD6EBF5)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF4A90E2), width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 타이틀
            Text(
              isKorean ? '게임 완료!' : 'Game Complete!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 24),

            // 결과
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isKorean ? '발견한 틀린그림' : 'Found'),
                      Text(
                        '$foundCount / $totalCount',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isKorean ? '오답 횟수' : 'Wrong Taps'),
                      Text(
                        '$wrongTaps',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 뽑기권 획득 버튼
            if (canEarnTicket) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFFFD699)),
                ),
                child: Column(
                  children: [
                    // 뽑기권 이미지
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/gacha_coin.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.confirmation_number,
                              color: Colors.white,
                              size: 30,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isKorean
                          ? '뽑기권 1개를 받을 수 있어요!'
                          : 'You can get 1 Gacha Ticket!',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isKorean
                          ? '오늘 남은 횟수: $remainingTickets회'
                          : 'Remaining today: $remainingTickets',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClaimTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isKorean ? '뽑기권 받기' : 'Get Ticket',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isKorean
                      ? '오늘 뽑기권을 모두 획득했습니다'
                      : 'You\'ve earned all tickets for today',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 홈/다시하기 버튼
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onHome,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isKorean ? '홈으로' : 'Home',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: onReplay,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isKorean ? '다시하기' : 'Play Again',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 배너 광고 컨테이너
class _BannerAdContainer extends StatefulWidget {
  const _BannerAdContainer();

  @override
  State<_BannerAdContainer> createState() => _BannerAdContainerState();
}

class _BannerAdContainerState extends State<_BannerAdContainer> {
  final AdmobHandler _adMobHandler = AdmobHandler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _adMobHandler.loadBannerAd(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: _adMobHandler.getBannerAd(),
    );
  }
}
