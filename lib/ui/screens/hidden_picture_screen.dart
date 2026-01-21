import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../../game/models/hidden_picture_data.dart';
import '../../utils/constants.dart';
import '../../ads/admob_handler.dart';
import '../../data/ticket_manager.dart';
import '../../data/hidden_progress_manager.dart';
import '../../services/daily_mission_service.dart';
import '../../sound_manager.dart';
import '../../l10n/app_localizations.dart';

/// 숨은그림찾기 게임 화면
class HiddenPictureScreen extends StatefulWidget {
  final int? stageId; // 특정 스테이지 ID (1~10)
  final bool isSequentialMode; // 순차 진행 모드 여부

  const HiddenPictureScreen({
    super.key,
    this.stageId,
    this.isSequentialMode = false,
  });

  @override
  State<HiddenPictureScreen> createState() => _HiddenPictureScreenState();
}

class _HiddenPictureScreenState extends State<HiddenPictureScreen>
    with TickerProviderStateMixin {
  final AdmobHandler _adMobHandler = AdmobHandler();
  final TicketManager _ticketManager = TicketManager();
  final DailyMissionService _missionService = DailyMissionService();
  final SoundManager _soundManager = SoundManager();
  final HiddenPictureDataManager _dataManager = HiddenPictureDataManager();

  HiddenPictureStage? _currentStage;
  List<bool> _foundSpots = []; // 각 스팟 찾음 여부
  int _foundCount = 0; // 찾은 개수
  int _remainingTime = 0;
  Timer? _gameTimer;
  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _hasUsedHint = false;
  bool _isShowingHint = false;

  // 디버그 모드 (개발 중에만 true로 설정)
  static const bool _debugMode = false;
  String _lastTapCoord = '';

  // 이미지 비율 (동적으로 계산)
  double _imageAspectRatio = 0.56; // 기본값

  // 전역 터치 반경 설정
  static const double kDefaultTouchRadius = 0.04;
  
  // 정답 원 시각적 표시 크기 (고정값)
  static const double kSpotCircleSize = 33.0;

  // 동기화된 확대/축소를 위한 TransformationController
  final TransformationController _transformationController =
      TransformationController();

  // 현재 줌 레벨 표시용
  double _currentScale = 1.0;

  // 연한 초록색 (라임 그린)
  static const Color _spotCircleColor = Color(0xFF7ED321);

  // 애니메이션 컨트롤러들
  late AnimationController _wrongTapController;
  late Animation<double> _wrongTapAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // 오답 X 표시 상태
  Offset? _wrongTapPosition;
  bool _showWrongTapX = false;

  // 정답 표시 애니메이션 상태 (스팟 인덱스별)
  final Map<int, AnimationController> _spotAnimationControllers = {};
  final Map<int, Animation<double>> _spotAnimations = {};

  // 체크박스 애니메이션 컨트롤러들 (인덱스별)
  final Map<int, AnimationController> _checkboxAnimationControllers = {};
  final Map<int, Animation<double>> _checkboxAnimations = {};

  // 입자 애니메이션 상태
  final List<_ParticleData> _particles = [];
  Timer? _particleTimer;

  // 상단 체크박스들의 GlobalKey (입자 도착 위치 계산용)
  final List<GlobalKey> _checkboxKeys = [];

  // 이미지 영역 GlobalKey (입자 시작 위치 계산용)
  final GlobalKey _imageKey = GlobalKey();
  
  // 실제 Image 위젯의 GlobalKey (정확한 렌더링 영역 계산용)
  final GlobalKey _imageWidgetKey = GlobalKey();

  // 최근에 찾은 스팟 인덱스 (체크박스 애니메이션용)
  int? _lastFoundSpotIndex;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _setupAnimations();
    _loadAds();

    // Transform 변경 리스너
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _particleTimer?.cancel();
    _wrongTapController.dispose();
    _shakeController.dispose();
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    for (final controller in _spotAnimationControllers.values) {
      controller.dispose();
    }
    for (final controller in _checkboxAnimationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTransformChanged() {
    if (!mounted) return;
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (_currentScale != scale) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _setupAnimations() {
    // 오답 애니메이션 (X 표시)
    _wrongTapController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _wrongTapAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wrongTapController, curve: Curves.elasticOut),
    );
    _wrongTapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showWrongTapX = false;
            });
          }
        });
      }
    });

    // 화면 흔들림 애니메이션
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  /// 스팟별 애니메이션 컨트롤러 생성
  void _createSpotAnimationController(int index) {
    if (_spotAnimationControllers.containsKey(index)) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );

    _spotAnimationControllers[index] = controller;
    _spotAnimations[index] = animation;
  }

  /// 체크박스 애니메이션 컨트롤러 생성
  void _createCheckboxAnimationController(int index) {
    if (_checkboxAnimationControllers.containsKey(index)) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );

    _checkboxAnimationControllers[index] = controller;
    _checkboxAnimations[index] = animation;
  }

  void _loadAds() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _adMobHandler.loadInterstitialAd();
      await _adMobHandler.loadRewardedAd();
    });
  }

  Future<void> _initializeGame() async {
    // 순차 모드이고 stageId가 지정된 경우 해당 스테이지 로드
    if (widget.isSequentialMode && widget.stageId != null) {
      _currentStage = await _dataManager.getStage(widget.stageId!);
      
      // 스테이지가 존재하지 않는 경우, 첫 번째 스테이지로 리다이렉트
      if (_currentStage == null && mounted) {
        const validStageId = 1;
        await HiddenProgressManager.saveCurrentStage(validStageId);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HiddenPictureScreen(
                stageId: validStageId,
                isSequentialMode: true,
              ),
            ),
          );
        }
        return;
      }
    } else {
      // 기존 랜덤 스테이지 로드 (첫 번째 스테이지)
      _currentStage = await _dataManager.getStage(1);
    }

    if (_currentStage == null) {
      return;
    }

    _foundSpots = List.filled(_currentStage!.spots.length, false);
    _foundCount = 0;
    _remainingTime = _currentStage!.timeLimit;
    _isGameOver = false;
    _isGameWon = false;
    _hasUsedHint = false;
    _isShowingHint = false;
    _particles.clear();
    _currentScale = 1.0;
    _lastFoundSpotIndex = null;

    // Transform 초기화
    _transformationController.value = Matrix4.identity();

    // 이전 애니메이션 컨트롤러 정리
    for (final controller in _spotAnimationControllers.values) {
      controller.dispose();
    }
    _spotAnimationControllers.clear();
    _spotAnimations.clear();

    for (final controller in _checkboxAnimationControllers.values) {
      controller.dispose();
    }
    _checkboxAnimationControllers.clear();
    _checkboxAnimations.clear();

    // 체크박스 GlobalKey 초기화
    _checkboxKeys.clear();
    for (int i = 0; i < _currentStage!.spots.length; i++) {
      _checkboxKeys.add(GlobalKey());
    }

    // 이미지 비율 계산
    _loadImageAspectRatio();

    _startTimer();
  }

  /// 이미지 비율을 동적으로 계산
  void _loadImageAspectRatio() {
    if (_currentStage == null) return;

    final image = Image.asset(_currentStage!.image);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageAspectRatio = info.image.height / info.image.width;
          });
          print(
              '[HiddenPicture] 이미지 비율: $_imageAspectRatio (${info.image.width}x${info.image.height})');
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
        // 시간초과 시 타이머 중지 후 광고 보고 시간 추가 옵션 제공
        _gameTimer?.cancel();
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

  /// 줌 리셋
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
    });
  }

  /// BoxFit.fitWidth로 렌더링될 때 실제 이미지 영역 계산
  ({double width, double height, double offsetX, double offsetY}) _calculateActualImageRect(Size containerSize) {
    final actualWidth = containerSize.width;
    final actualHeight = containerSize.width * _imageAspectRatio;
    
    return (
      width: actualWidth,
      height: actualHeight,
      offsetX: 0.0,
      offsetY: 0.0,
    );
  }

  /// 이미지 터치 처리
  void _onImageTapped(Offset tapPosition, Size containerSize, Offset globalTapPosition) {
    if (_isGameOver || _currentStage == null) return;

    // BoxFit.fitWidth로 인한 실제 이미지 렌더링 영역 계산
    final actualImageRect = _calculateActualImageRect(containerSize);
    
    // 터치 위치에서 이미지 영역의 오프셋을 빼서 순수 이미지 내 좌표로 변환
    final touchInImageX = tapPosition.dx - actualImageRect.offsetX;
    final touchInImageY = tapPosition.dy - actualImageRect.offsetY;
    
    // 이미지 영역 밖이면 무시
    if (touchInImageX < 0 || touchInImageX > actualImageRect.width ||
        touchInImageY < 0 || touchInImageY > actualImageRect.height) {
      return;
    }

    // 비율 좌표로 변환 (0.0 ~ 1.0)
    final relativeX = touchInImageX / actualImageRect.width;
    final relativeY = touchInImageY / actualImageRect.height;

    _processTouchWithRelativeCoords(relativeX, relativeY, tapPosition, containerSize, globalTapPosition);
  }

  /// 비율 좌표를 사용하여 스팟 판정 처리
  void _processTouchWithRelativeCoords(double relativeX, double relativeY, Offset tapPosition,
      Size containerSize, Offset globalTapPosition) {
    if (_isGameOver || _currentStage == null) return;

    // 디버그 모드: 터치 좌표 표시
    if (_debugMode) {
      setState(() {
        _lastTapCoord =
            'x: ${relativeX.toStringAsFixed(3)}, y: ${relativeY.toStringAsFixed(3)}';
      });
    }

    // 터치 포인트 (비율 좌표, 0.0 ~ 1.0)
    final touchPoint = Offset(relativeX, relativeY);

    // 터치 영역에 포함되는 스팟들을 찾기
    final List<({int index, double area})> overlappingSpots = [];

    for (int i = 0; i < _currentStage!.spots.length; i++) {
      if (_foundSpots[i]) continue; // 이미 찾은 스팟은 제외

      final spot = _currentStage!.spots[i];
      
      // 스팟의 실제 크기 (비율 좌표, 0.0 ~ 1.0)
      final spotWidth = spot.actualWidth;
      final spotHeight = spot.actualHeight;

      // Padding 추가 (50% 여유 공간)
      const double paddingFactor = 0.50;
      final paddedWidth = spotWidth * (1.0 + paddingFactor);
      final paddedHeight = spotHeight * (1.0 + paddingFactor);

      // Rect 생성
      final spotRect = Rect.fromCenter(
        center: Offset(spot.x, spot.y),
        width: paddedWidth,
        height: paddedHeight,
      );

      // 터치 포인트가 Rect 안에 포함되는지 확인
      if (spotRect.contains(touchPoint)) {
        // 면적 계산
        final area = paddedWidth * paddedHeight;
        overlappingSpots.add((index: i, area: area));
      }
    }

    // 여러 스팟이 겹치는 경우, 면적이 가장 작은 스팟 선택
    if (overlappingSpots.isNotEmpty) {
      overlappingSpots.sort((a, b) => a.area.compareTo(b.area));
      
      final selectedSpot = overlappingSpots.first;
      final spotIndex = selectedSpot.index;
      
      _onCorrectTap(spotIndex, globalTapPosition, containerSize);
    } else {
      // 틀림
      _onWrongTap(tapPosition, containerSize);
    }

    // 모든 스팟을 찾았는지 확인
    if (_foundSpots.every((found) => found)) {
      _endGame(true);
    }
  }

  /// 정답 처리
  void _onCorrectTap(int spotIndex, Offset globalTapPosition, Size containerSize) {
    if (_foundSpots[spotIndex]) return;

    setState(() {
      _foundSpots[spotIndex] = true;
      _foundCount++;
      _lastFoundSpotIndex = spotIndex;
    });

    HapticFeedback.lightImpact();
    _soundManager.playSparkleSound();

    // 스팟 애니메이션 시작
    _createSpotAnimationController(spotIndex);
    _spotAnimationControllers[spotIndex]?.forward(from: 0.0);

    // 입자 애니메이션 시작
    final checkboxIndex = _foundCount - 1;
    _startParticleAnimation(globalTapPosition, checkboxIndex);

    // 체크박스 애니메이션
    _createCheckboxAnimationController(checkboxIndex);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _checkboxAnimationControllers[checkboxIndex]?.forward(from: 0.0);
      }
    });
  }

  /// 오답 처리
  void _onWrongTap(Offset tapPosition, Size containerSize) {
    HapticFeedback.mediumImpact();

    setState(() {
      _wrongTapPosition = tapPosition;
      _showWrongTapX = true;
    });

    _wrongTapController.forward(from: 0.0);
    _shakeController.forward(from: 0.0);
  }

  /// 입자 애니메이션 시작
  void _startParticleAnimation(Offset startPosition, int targetIndex) {
    if (targetIndex >= _checkboxKeys.length) return;

    final RenderBox? checkboxBox =
        _checkboxKeys[targetIndex].currentContext?.findRenderObject() as RenderBox?;
    if (checkboxBox == null) return;

    final checkboxPosition = checkboxBox.localToGlobal(Offset.zero);
    final checkboxCenter = Offset(
      checkboxPosition.dx + checkboxBox.size.width / 2,
      checkboxPosition.dy + checkboxBox.size.height / 2,
    );

    final random = Random();
    for (int i = 0; i < 8; i++) {
      final particle = _ParticleData(
        id: DateTime.now().millisecondsSinceEpoch + i,
        startPosition: startPosition +
            Offset(
              random.nextDouble() * 20 - 10,
              random.nextDouble() * 20 - 10,
            ),
        endPosition: checkboxCenter,
        progress: 0.0,
        color: _spotCircleColor,
        size: 6.0 + random.nextDouble() * 4,
      );
      _particles.add(particle);
    }

    _particleTimer?.cancel();
    _particleTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        final toRemove = <_ParticleData>[];
        for (final particle in _particles) {
          particle.progress += 0.05;
          if (particle.progress >= 1.0) {
            toRemove.add(particle);
          }
        }
        _particles.removeWhere((p) => toRemove.contains(p));

        if (_particles.isEmpty) {
          timer.cancel();
        }
      });
    });
  }

  void _endGame(bool isWin) async {
    _gameTimer?.cancel();
    setState(() {
      _isGameOver = true;
      _isGameWon = isWin;
    });

    if (isWin) {
      _soundManager.playGameCompleteSound();
      await _missionService.completeGame();
      _showWinDialog();
    } else {
      _showLoseDialog();
    }
  }

  /// 승리 다이얼로그
  void _showWinDialog() async {
    if (!mounted) return;

    // 순차 모드일 경우 진행 상태 저장
    if (widget.isSequentialMode && widget.stageId != null) {
      await HiddenProgressManager.setStageCompleted(widget.stageId!, true);
      
      // 다음 스테이지로 자동 진행
      final nextStageId = HiddenProgressManager.getNextStageId(widget.stageId!);
      if (nextStageId != null) {
        await HiddenProgressManager.saveCurrentStage(nextStageId);
      }
    }

    // 뽑기권 획득 시도
    await _ticketManager.initialize();
    final canEarn = _ticketManager.canEarnTicketToday;

    // 다음 스테이지 ID 확인
    final int? nextStageId = widget.isSequentialMode && widget.stageId != null
        ? HiddenProgressManager.getNextStageId(widget.stageId!)
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GameResultDialog(
        isWin: true,
        foundCount: _foundSpots.where((f) => f).length,
        totalCount: _currentStage?.spots.length ?? 0,
        canEarnTicket: canEarn,
        remainingTickets: _ticketManager.remainingDailyTickets,
        isSequentialMode: widget.isSequentialMode,
        currentStageId: widget.stageId,
        nextStageId: nextStageId,
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
        onNextStage: nextStageId != null
            ? () async {
                Navigator.of(context).pop();
                if (context.mounted) {
                  await Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HiddenPictureScreen(
                        stageId: nextStageId,
                        isSequentialMode: true,
                      ),
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }

  /// 전면 광고 보고 뽑기권 획득
  Future<void> _claimTicketWithAd() async {
    if (!mounted) return;
    await _adMobHandler.showInterstitialAd();
    if (!mounted) return;
    await _claimTicket();
  }

  /// 뽑기권 획득
  Future<void> _claimTicket() async {
    final earned = await _ticketManager.earnTicket();

    if (!mounted) return;

    if (earned) {
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
    
    final int? nextStageId = widget.isSequentialMode && widget.stageId != null
        ? HiddenProgressManager.getNextStageId(widget.stageId!)
        : null;

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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/gacha_coin.webp',
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
                      onPressed: () async {
                        Navigator.of(context).pop();
                        if (nextStageId != null && context.mounted) {
                          await Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HiddenPictureScreen(
                                stageId: nextStageId,
                                isSequentialMode: true,
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A90E2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isKorean ? '다음 단계' : 'Next Stage',
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

  /// 시간초과 다이얼로그
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

  Future<void> _restartGame() async {
    _gameTimer?.cancel();
    _particleTimer?.cancel();
    await _initializeGame();
    if (mounted) {
      setState(() {});
    }
  }

  /// 광고 보고 30초 추가
  Future<void> _watchAdForExtraTime() async {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    if (_adMobHandler.isRewardedAdLoaded) {
      bool rewarded = false;

      await _adMobHandler.showRewardedAd(
        onRewarded: (rewardItem) {
          rewarded = true;
        },
        onAdDismissed: () {
          if (rewarded && mounted) {
            setState(() {
              _remainingTime += 30;
            });
            _startTimer();

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
          } else if (mounted) {
            _showTimeUpDialog();
          }
        },
      );
    } else {
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
        _showTimeUpDialog();
      }
    }
  }

  /// 힌트 사용 (광고 시청 후)
  void _useHint() async {
    if (_hasUsedHint || _isGameOver) return;

    _pauseTimer();

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
      _showHintSpots();
      _resumeTimer();
    }
  }

  void _showHintSpots() {
    setState(() {
      _hasUsedHint = true;
      _isShowingHint = true;
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isShowingHint = false;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStage == null) {
      final isKorean = Localizations.localeOf(context).languageCode == 'ko';
      return Scaffold(
        appBar: AppBar(
          title: Text(isKorean ? '숨은그림찾기' : 'Hidden Picture'),
        ),
        body: Center(
          child: Text(
            isKorean ? '스테이지를 불러올 수 없습니다.' : 'Failed to load stage.',
          ),
        ),
      );
    }

    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Text(
          isKorean
              ? '${_currentStage!.stage} 스테이지'
              : 'Stage ${_currentStage!.stage}',
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
      body: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final shakeOffset = sin(_shakeAnimation.value * pi * 4) *
              (1 - _shakeAnimation.value) *
              10;
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: child,
          );
        },
        child: Stack(
          children: [
            Column(
              children: [
                // 게임 정보 바
                _buildInfoBar(),

                // 이미지 영역 (확대/축소 가능)
                _buildImageArea(),

                // 하단 버튼 영역
                _buildBottomButtons(),

                // 배너 광고 공간 확보 (배너 높이 + 마진)
                SizedBox(
                  height: 84, // 배너 높이(약 60) + 하단 마진(24)
                ),
              ],
            ),

            // 입자 애니메이션 오버레이
            ..._buildParticles(),

            // 하단 배너 광고 (최하단 고정)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: const _BannerAdContainer(),
            ),
          ],
        ),
      ),
    );
  }

  /// 입자 위젯들 빌드
  List<Widget> _buildParticles() {
    return _particles.map((particle) {
      final currentPosition = Offset.lerp(
        particle.startPosition,
        particle.endPosition,
        Curves.easeInOut.transform(particle.progress),
      )!;

      final opacity = 1.0 - (particle.progress * 0.5);
      final scale = 1.0 - (particle.progress * 0.3);

      return Positioned(
        left: currentPosition.dx - particle.size / 2,
        top: currentPosition.dy - particle.size / 2,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: particle.size,
            height: particle.size,
            decoration: BoxDecoration(
              color: particle.color.withOpacity(opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: particle.color.withOpacity(opacity * 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildInfoBar() {
    final totalCount = _currentStage?.spots.length ?? 0;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _isShowingHint ? const Color(0xFFFFF8E1) : const Color(0xFFE6F3FF),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 위: 캐릭터 이미지 + 히트박스
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 찾아야 하는 캐릭터 이미지
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A90E2),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Transform.scale(
                    scale: 1.15,
                    child: Image.asset(
                      _currentStage?.characterImage ?? 'assets/capybara/blue3.webp',
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),

              // 히트박스 영역
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.start,
                  children: List.generate(totalCount, (index) {
                    return _buildCheckbox(index);
                  }),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 아래: 게임 시간 (한 줄로)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                size: 16,
                color: _remainingTime <= 30 ? Colors.red : const Color(0xFF4A90E2),
              ),
              const SizedBox(width: 6),
              Text(
                '${_formatTime(_remainingTime)} / ${_formatTime(_currentStage?.timeLimit ?? 0)}',
                style: TextStyle(
                  fontSize: 14,
                  color: _remainingTime <= 30 ? Colors.red : const Color(0xFF2C5F8B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          if (_debugMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_lastTapCoord.isNotEmpty)
                    Text(
                      '📍 터치 좌표: $_lastTapCoord',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  Text(
                    '📐 이미지 비율: ${_imageAspectRatio.toStringAsFixed(3)} (H/W)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 개별 체크박스 위젯
  Widget _buildCheckbox(int index) {
    final isFound = index < _foundCount;
    final animation = _checkboxAnimations[index];
    final hasAnimation = animation != null && isFound;

    return Container(
      key: _checkboxKeys[index],
      child: hasAnimation
          ? AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (animation.value * 0.3) * (1 - animation.value),
                  child: _buildCheckboxContent(isFound),
                );
              },
            )
          : _buildCheckboxContent(isFound),
    );
  }

  Widget _buildCheckboxContent(bool isFound) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFound ? _spotCircleColor : Colors.white,
        border: Border.all(
          color: isFound ? _spotCircleColor : const Color(0xFFBDBDBD),
          width: 2.5,
        ),
        boxShadow: isFound
            ? [
                BoxShadow(
                  color: _spotCircleColor.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: isFound
          ? const Icon(
              Icons.check,
              color: Colors.white,
              size: 20,
            )
          : ClipOval(
              child: Opacity(
                opacity: 0.2,
                child: Transform.scale(
                  scale: 1.5,
                  child: Image.asset(
                    _currentStage?.characterImage ?? 'assets/capybara/blue3.webp',
                    fit: BoxFit.cover,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: Color(0xFFBDBDBD),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
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

  /// 이미지 영역
  Widget _buildImageArea() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라벨
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isKorean ? '숨은 그림을 찾아보세요!' : 'Find Hidden Objects!',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90E2),
                ),
              ),
              // 줌 레벨 표시
              if (_currentScale > 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_currentScale * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 이미지
          LayoutBuilder(
            builder: (context, constraints) {
              final imageWidth = constraints.maxWidth;
              final imageActualHeight = imageWidth * _imageAspectRatio;
              
              return Container(
                key: _imageKey,
                width: imageWidth,
                height: imageActualHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A90E2),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: imageWidth,
                    height: imageActualHeight,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 3.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      child: GestureDetector(
                        // 더블탭으로 확대/축소
                        onDoubleTapDown: (details) {
                          if (_currentScale == 1.0) {
                            final tapPosition = details.localPosition;
                            final double scale = 2.0;
                            
                            final double dx = -tapPosition.dx * (scale - 1.0);
                            final double dy = -tapPosition.dy * (scale - 1.0);
                            
                            setState(() {
                              _transformationController.value = Matrix4.identity()
                                ..translate(dx, dy)
                                ..scale(scale);
                              _currentScale = scale;
                            });
                          } else {
                            _resetZoom();
                          }
                        },
                        onTapUp: (details) {
                          if (!_isGameOver) {
                            final RenderBox? box =
                                _imageKey.currentContext?.findRenderObject() as RenderBox?;
                            Offset globalPos = details.globalPosition;
                            if (box != null) {
                              globalPos = box.localToGlobal(details.localPosition);
                            }

                            _onImageTapped(
                              details.localPosition,
                              Size(imageWidth, imageActualHeight),
                              globalPos,
                            );
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 이미지
                            Image.asset(
                              _currentStage!.image,
                              key: _imageWidgetKey,
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
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
                                        _currentStage!.image.split('/').last,
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
                            ..._buildFoundSpotMarkers(imageWidth, imageActualHeight),

                            // 오답 X 표시
                            if (_showWrongTapX && _wrongTapPosition != null)
                              _buildWrongTapMarker(),

                            // 힌트 표시
                            if (_isShowingHint)
                              ..._buildHintMarkers(imageWidth, imageActualHeight),

                            // 디버그 모드: 모든 스팟 위치 표시
                            if (_debugMode)
                              ..._buildDebugSpotMarkers(imageWidth, imageActualHeight),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 오답 X 표시 위젯
  Widget _buildWrongTapMarker() {
    return AnimatedBuilder(
      animation: _wrongTapAnimation,
      builder: (context, child) {
        return Positioned(
          left: _wrongTapPosition!.dx - 20,
          top: _wrongTapPosition!.dy - 20,
          child: Transform.scale(
            scale: _wrongTapAnimation.value,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.3),
                border: Border.all(color: Colors.red, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.close,
                  color: Colors.red,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 찾은 스팟 마커들
  List<Widget> _buildFoundSpotMarkers(double containerWidth, double containerHeight) {
    final markers = <Widget>[];
    
    final imageRect = _calculateActualImageRect(Size(containerWidth, containerHeight));
    
    const circleSize = kSpotCircleSize;
    const circleRadius = circleSize / 2;

    for (int i = 0; i < _foundSpots.length; i++) {
      if (_foundSpots[i]) {
        final spot = _currentStage!.spots[i];
        final animation = _spotAnimations[i];

        markers.add(
          AnimatedBuilder(
            animation: animation ?? const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              final scale = animation?.value ?? 1.0;
              return Positioned(
                left: imageRect.offsetX + spot.x * imageRect.width - circleRadius,
                top: imageRect.offsetY + spot.y * imageRect.height - circleRadius,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _spotCircleColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: _spotCircleColor.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return markers;
  }

  /// 힌트 마커
  List<Widget> _buildHintMarkers(double containerWidth, double containerHeight) {
    final markers = <Widget>[];
    
    final imageRect = _calculateActualImageRect(Size(containerWidth, containerHeight));
    
    const circleSize = kSpotCircleSize;
    const circleRadius = circleSize / 2;

    for (int i = 0; i < _foundSpots.length; i++) {
      if (!_foundSpots[i]) {
        final spot = _currentStage!.spots[i];
        markers.add(
          Positioned(
            left: imageRect.offsetX + spot.x * imageRect.width - circleRadius,
            top: imageRect.offsetY + spot.y * imageRect.height - circleRadius,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange, width: 3),
                color: Colors.orange.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  /// 디버그 모드: 모든 스팟 위치 표시
  List<Widget> _buildDebugSpotMarkers(double containerWidth, double containerHeight) {
    final actualImageRect = _calculateActualImageRect(Size(containerWidth, containerHeight));
    return _buildDebugMarkersWithRect(actualImageRect.width, actualImageRect.height, actualImageRect.offsetX, actualImageRect.offsetY);
  }

  List<Widget> _buildDebugMarkersWithRect(double imageWidth, double imageHeight, double offsetX, double offsetY) {
    final markers = <Widget>[];
    
    final circleRadius = kDefaultTouchRadius * imageWidth;
    final circleSize = circleRadius * 2;

    for (int i = 0; i < _foundSpots.length; i++) {
      final spot = _currentStage!.spots[i];
      final isFound = _foundSpots[i];

      markers.add(
        Positioned(
          left: offsetX + spot.x * imageWidth - circleRadius,
          top: offsetY + spot.y * imageHeight - circleRadius,
          child: Container(
            width: circleSize,
            height: circleSize,
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

      final touchRadius = kDefaultTouchRadius * imageWidth;
      markers.add(
        Positioned(
          left: offsetX + spot.x * imageWidth - touchRadius,
          top: offsetY + spot.y * imageHeight - touchRadius,
          child: Container(
            width: touchRadius * 2,
            height: touchRadius * 2,
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

  /// 하단 버튼 영역
  Widget _buildBottomButtons() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 줌 리셋 버튼
          if (_currentScale > 1.0)
            GestureDetector(
              onTap: _resetZoom,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
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
                    const Icon(Icons.zoom_out_map,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      isKorean ? '원래대로' : 'Reset',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 힌트 버튼
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
}

/// 입자 데이터 클래스
class _ParticleData {
  final int id;
  final Offset startPosition;
  final Offset endPosition;
  double progress;
  final Color color;
  final double size;

  _ParticleData({
    required this.id,
    required this.startPosition,
    required this.endPosition,
    required this.progress,
    required this.color,
    required this.size,
  });
}

/// 게임 결과 다이얼로그
class _GameResultDialog extends StatelessWidget {
  final bool isWin;
  final int foundCount;
  final int totalCount;
  final bool canEarnTicket;
  final int remainingTickets;
  final VoidCallback onClaimTicket;
  final VoidCallback onHome;
  final VoidCallback onReplay;
  final bool isSequentialMode;
  final int? currentStageId;
  final int? nextStageId;
  final VoidCallback? onNextStage;

  const _GameResultDialog({
    required this.isWin,
    required this.foundCount,
    required this.totalCount,
    required this.canEarnTicket,
    required this.remainingTickets,
    required this.onClaimTicket,
    required this.onHome,
    required this.onReplay,
    this.isSequentialMode = false,
    this.currentStageId,
    this.nextStageId,
    this.onNextStage,
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
            Text(
              isKorean ? '게임 완료!' : 'Game Complete!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 24),

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
                      Text(isKorean ? '발견한 숨은그림' : 'Found'),
                      Text(
                        '$foundCount / $totalCount',
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/gacha_coin.webp',
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
                          ? '아래 버튼을 클릭해서 뽑기권을 1개 얻을 수 있어요!'
                          : 'Click the button below to get 1 Gacha Ticket!',
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

            // 다음 단계 버튼
            if (isSequentialMode && nextStageId != null && onNextStage != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNextStage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isKorean ? '다음 단계' : 'Next Stage',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // 홈/다시하기 버튼
            if (!isSequentialMode || nextStageId == null)
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
              )
            else
              TextButton(
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
    return _adMobHandler.getBannerAd();
  }
}
