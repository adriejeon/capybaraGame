import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // 디버그 모드 (개발 중에만 true로 설정)
  static const bool _debugMode = false;
  String _lastTapCoord = '';

  // 이미지 비율 (동적으로 계산)
  double _imageAspectRatio = 0.56; // 기본값 (572/1024)

  // ========== 전역 터치 반경 설정 ==========
  // 모든 스팟에 동일하게 적용되는 터치 반경 (이미지 너비의 4%)
  static const double kDefaultTouchRadius = 0.04;
  
  // 정답 원 시각적 표시 크기 (고정값)
  static const double kSpotCircleSize = 30.0;

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
  bool _isOriginalImageWrongTap = true; // 오답 표시가 어느 이미지에 있는지

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
  final GlobalKey _originalImageKey = GlobalKey();
  final GlobalKey _wrongImageKey = GlobalKey();
  
  // 실제 Image 위젯의 GlobalKey (정확한 렌더링 영역 계산용)
  final GlobalKey _originalImageWidgetKey = GlobalKey();
  final GlobalKey _wrongImageWidgetKey = GlobalKey();

  // 최근에 찾은 스팟 인덱스 (체크박스 애니메이션용)
  int? _lastFoundSpotIndex;

  @override
  void initState() {
    super.initState();
    _initializeGame(); // async지만 await 없이 호출 (초기화는 백그라운드에서)
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
    final level =
        SpotDifferenceDataManager.difficultyToLevel(widget.difficulty);
    _currentStage = await _dataManager.getRandomStage(level);

    if (_currentStage == null) {
      return;
    }

    _foundSpots = List.filled(_currentStage!.spots.length, false);
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
  /// BoxFit.fitWidth는 width에 맞추고 height는 이미지 비율에 맞게 조정
  /// Alignment.topCenter를 사용하므로 상단 중앙 정렬
  /// 반환값: (실제 이미지 너비, 실제 이미지 높이, X 오프셋, Y 오프셋)
  ({double width, double height, double offsetX, double offsetY}) _calculateActualImageRect(Size containerSize) {
    // BoxFit.fitWidth: width에 맞추고 height는 이미지 비율에 맞게 조정
    // 이미지의 실제 렌더링 크기 (100% width로 표시)
    final actualWidth = containerSize.width;
    final actualHeight = containerSize.width * _imageAspectRatio;
    
    // Alignment.topCenter: 상단 중앙 정렬
    // - offsetX: 중앙 정렬이므로 항상 0 (width가 컨테이너와 같으므로)
    // - offsetY: 상단 정렬이므로 항상 0
    return (
      width: actualWidth,
      height: actualHeight,
      offsetX: 0.0,
      offsetY: 0.0,
    );
  }

  /// 실제 Image 위젯의 RenderBox를 사용하여 정확한 렌더링 영역 계산
  /// 반환값: (실제 이미지 너비, 실제 이미지 높이, X 오프셋, Y 오프셋, 성공 여부)
  ({double width, double height, double offsetX, double offsetY, bool success}) _getActualImageRectFromRenderBox(bool isOriginal) {
    final imageKey = isOriginal ? _originalImageWidgetKey : _wrongImageWidgetKey;
    final containerKey = isOriginal ? _originalImageKey : _wrongImageKey;
    
    // Image 위젯의 RenderBox 가져오기
    final imageBox = imageKey.currentContext?.findRenderObject() as RenderBox?;
    // Container의 RenderBox 가져오기
    final containerBox = containerKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (imageBox == null || containerBox == null) {
      return (width: 0, height: 0, offsetX: 0, offsetY: 0, success: false);
    }
    
    // Container의 크기
    final containerSize = containerBox.size;
    
    // Image 위젯의 위치 (Container 기준)
    final imagePosition = imageBox.localToGlobal(Offset.zero);
    final containerPosition = containerBox.localToGlobal(Offset.zero);
    final relativePosition = imagePosition - containerPosition;
    
    // BoxFit.contain으로 인한 실제 이미지 렌더링 영역 계산
    final containerRatio = containerSize.height / containerSize.width;
    double actualWidth, actualHeight, offsetX, offsetY;
    
    if (_imageAspectRatio > containerRatio) {
      // 이미지가 세로로 더 길다 → 높이에 맞추고 좌우 여백
      actualHeight = containerSize.height;
      actualWidth = containerSize.height / _imageAspectRatio;
      offsetX = relativePosition.dx + (containerSize.width - actualWidth) / 2;
      offsetY = relativePosition.dy;
    } else {
      // 이미지가 가로로 더 길다 → 너비에 맞추고 상하 여백
      actualWidth = containerSize.width;
      actualHeight = containerSize.width * _imageAspectRatio;
      offsetX = relativePosition.dx;
      offsetY = relativePosition.dy + (containerSize.height - actualHeight) / 2;
    }
    
    return (width: actualWidth, height: actualHeight, offsetX: offsetX, offsetY: offsetY, success: true);
  }

  /// 이미지 터치 처리 (BoxFit.cover + InteractiveViewer 줌/팬 고려한 정확한 좌표 변환)
  void _onImageTapped(
      Offset tapPosition, Size containerSize, bool isOriginal, Offset globalTapPosition) {
    if (_isGameOver || _currentStage == null) return;

    // InteractiveViewer의 변환 행렬 (줌 + 팬)
    final matrix = _transformationController.value;
    
    // Matrix4에서 스케일과 translation 추출
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    
    // 역변환 계산: (localPos - translation) / scale
    // 이는 Matrix4.inverted()를 사용한 것과 동일한 결과
    final adjustedTapPosition = Offset(
      (tapPosition.dx - translation.x) / scale,
      (tapPosition.dy - translation.y) / scale,
    );

    // BoxFit.fitWidth로 인한 실제 이미지 렌더링 영역 계산
    // width에 100% 맞추고 height는 이미지 비율에 맞게 조정 (상하 여백 가능)
    final actualImageRect = _calculateActualImageRect(containerSize);
    
    // 터치 위치에서 이미지 영역의 오프셋을 빼서 순수 이미지 내 좌표로 변환
    final touchInImageX = adjustedTapPosition.dx - actualImageRect.offsetX;
    final touchInImageY = adjustedTapPosition.dy - actualImageRect.offsetY;
    
    // 이미지 영역 밖이면 무시
    if (touchInImageX < 0 || touchInImageX > actualImageRect.width ||
        touchInImageY < 0 || touchInImageY > actualImageRect.height) {
      return;
    }

    // 비율 좌표로 변환 (0.0 ~ 1.0)
    final relativeX = touchInImageX / actualImageRect.width;
    final relativeY = touchInImageY / actualImageRect.height;

    _processTouchWithRelativeCoords(relativeX, relativeY, tapPosition, containerSize, isOriginal, globalTapPosition);
  }

  /// 비율 좌표를 사용하여 스팟 판정 처리 (Rect 기반)
  void _processTouchWithRelativeCoords(double relativeX, double relativeY, Offset tapPosition,
      Size containerSize, bool isOriginal, Offset globalTapPosition) {
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

      // Padding 추가 (15% 여유 공간)
      const double paddingFactor = 0.15;
      final paddedWidth = spotWidth * (1.0 + paddingFactor);
      final paddedHeight = spotHeight * (1.0 + paddingFactor);

      // Rect 생성 (relative_x, relative_y는 중심점이므로 Rect.fromCenter 사용)
      // 모든 좌표는 비율 좌표(0.0 ~ 1.0)로 작업
      final spotRect = Rect.fromCenter(
        center: Offset(spot.x, spot.y),
        width: paddedWidth,
        height: paddedHeight,
      );

      // 터치 포인트가 Rect 안에 포함되는지 확인
      if (spotRect.contains(touchPoint)) {
        // 면적 계산 (비율 좌표 기준)
        final area = paddedWidth * paddedHeight;
        overlappingSpots.add((index: i, area: area));
      }
    }

    // 여러 스팟이 겹치는 경우, 면적이 가장 작은 스팟 선택
    if (overlappingSpots.isNotEmpty) {
      // 면적 기준으로 정렬 (작은 것부터)
      overlappingSpots.sort((a, b) => a.area.compareTo(b.area));
      
      final selectedSpot = overlappingSpots.first;
      final spotIndex = selectedSpot.index;
      
      _onCorrectTap(spotIndex, globalTapPosition, containerSize);
    } else {
      // 틀림
      _onWrongTap(tapPosition, containerSize, isOriginal);
    }

    // 모든 스팟을 찾았는지 확인
    if (_foundSpots.every((found) => found)) {
      _endGame(true);
    }
  }

  /// 정답 처리
  void _onCorrectTap(int spotIndex, Offset globalTapPosition, Size containerSize) {
    setState(() {
      _foundSpots[spotIndex] = true;
      _lastFoundSpotIndex = spotIndex;
    });

    // 가벼운 진동 피드백
    HapticFeedback.lightImpact();

    // 사운드 재생 (sparkle.mp3)
    _soundManager.playSparkleSound();

    // 스팟 애니메이션 시작
    _createSpotAnimationController(spotIndex);
    _spotAnimationControllers[spotIndex]?.forward(from: 0.0);

    // 입자 애니메이션 시작 (정답 위치에서 상단 체크박스로)
    _startParticleAnimation(globalTapPosition, spotIndex);

    // 체크박스 애니메이션 (입자 도착 후 시작)
    _createCheckboxAnimationController(spotIndex);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _checkboxAnimationControllers[spotIndex]?.forward(from: 0.0);
      }
    });
  }

  /// 오답 처리
  void _onWrongTap(Offset tapPosition, Size containerSize, bool isOriginal) {
    // 오답 카운트 제거됨

    // 진동 피드백 (더 강하게)
    HapticFeedback.mediumImpact();

    // X 표시 위치 저장 및 표시
    setState(() {
      _wrongTapPosition = tapPosition;
      _showWrongTapX = true;
      _isOriginalImageWrongTap = isOriginal;
    });

    // X 표시 애니메이션 시작
    _wrongTapController.forward(from: 0.0);

    // 화면 흔들림 애니메이션
    _shakeController.forward(from: 0.0);
  }

  /// 입자 애니메이션 시작 (특정 체크박스로)
  void _startParticleAnimation(Offset startPosition, int targetIndex) {
    // 해당 체크박스의 위치 계산
    if (targetIndex >= _checkboxKeys.length) return;

    final RenderBox? checkboxBox =
        _checkboxKeys[targetIndex].currentContext?.findRenderObject() as RenderBox?;
    if (checkboxBox == null) return;

    final checkboxPosition = checkboxBox.localToGlobal(Offset.zero);
    final checkboxCenter = Offset(
      checkboxPosition.dx + checkboxBox.size.width / 2,
      checkboxPosition.dy + checkboxBox.size.height / 2,
    );

    // 여러 개의 입자 생성
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

    // 입자 애니메이션 업데이트
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

    // 보상형 광고 표시
    if (_adMobHandler.isRewardedAdLoaded) {
      bool rewarded = false;

      await _adMobHandler.showRewardedAd(
        onRewarded: (rewardItem) {
          rewarded = true;
        },
        onAdDismissed: () {
          if (rewarded && mounted) {
            // 30초 추가하고 타이머 재시작
            setState(() {
              _remainingTime += 30;
            });
            _startTimer();

            // 성공 메시지
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
            // 광고를 끝까지 보지 않음 - 시간 초과 다이얼로그 다시 표시
            _showTimeUpDialog();
          }
        },
      );
    } else {
      // 광고가 로드되지 않음 - 시간 초과 다이얼로그 다시 표시
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

        // 시간 초과 다이얼로그 다시 표시
        _showTimeUpDialog();
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
      final isKorean = Localizations.localeOf(context).languageCode == 'ko';
      return Scaffold(
        appBar: AppBar(
          title: Text(isKorean ? '틀린그림찾기' : 'Spot the Difference'),
        ),
        body: Center(
          child: Text(
            isKorean ? '스테이지를 불러올 수 없습니다.' : 'Failed to load stage.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Localizations.localeOf(context).languageCode == 'ko'
                  ? '${_getDifficultyText()} - 틀린그림찾기'
                  : '${_getDifficultyText()} - Spot the Difference',
            ),
            if (_debugMode && _currentStage != null)
              Text(
                Localizations.localeOf(context).languageCode == 'ko'
                    ? '스테이지: ${_currentStage!.level}-${_currentStage!.stage}'
                    : 'Stage: ${_currentStage!.level}-${_currentStage!.stage}',
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
      body: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          // 화면 흔들림 효과
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
                // 게임 정보 바 (체크박스 형태)
                _buildInfoBar(),

                // 이미지 영역 (동기화된 확대/축소) - 높이 제한
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 570, // 최대 높이 제한 (두 이미지 합쳐서) - 살짝 축소
                    ),
                    child: _buildSyncedImageArea(),
                  ),
                ),

                // 하단 버튼 영역
                _buildBottomButtons(),

                // 하단 배너 광고
                const _BannerAdContainer(),
              ],
            ),

            // 입자 애니메이션 오버레이
            ..._buildParticles(),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 시간 표시 (고정 너비)
              SizedBox(
                width: 70, // 고정 너비 설정
                child: _buildInfoItem(
                    isKorean ? '시간' : 'Time', _formatTime(_remainingTime)),
              ),
              
              const SizedBox(width: 16), // 시간과 체크박스 사이 간격

              // 체크박스들 (한 줄에 맞는 만큼만, 넘치면 아래로)
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.start, // 왼쪽 정렬
                  children: List.generate(totalCount, (index) {
                    return _buildCheckbox(index);
                  }),
                ),
              ),
            ],
          ),
          // 디버그 모드: 터치 좌표 및 이미지 비율 표시
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
    final isFound = _foundSpots[index];
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
      width: 28,
      height: 28,
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
              size: 18,
            )
          : const Icon(
              Icons.help_outline,
              color: Color(0xFFBDBDBD),
              size: 16,
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

  /// 동기화된 이미지 영역 (두 이미지가 같이 확대/축소)
  Widget _buildSyncedImageArea() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // 원본 이미지 (높이 축소)
          Expanded(
            flex: 7, // 높이 축소 (기존 9에서 7로)
            child: _buildSyncedInteractiveImage(
              key: _originalImageKey,
              imagePath: _currentStage!.originalImage,
              isOriginal: true,
              label: isKorean ? '원본' : 'Original',
            ),
          ),
          const SizedBox(height: 8),
          // 틀린그림 이미지 (높이 축소)
          Expanded(
            flex: 7, // 높이 축소 (기존 9에서 7로)
            child: _buildSyncedInteractiveImage(
              key: _wrongImageKey,
              imagePath: _currentStage!.wrongImage,
              isOriginal: false,
              label: isKorean ? '틀린그림' : 'Different',
            ),
          ),
        ],
      ),
    );
  }

  /// 동기화된 InteractiveViewer 이미지
  Widget _buildSyncedInteractiveImage({
    required GlobalKey key,
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
        const SizedBox(height: 4),
        // 이미지 (InteractiveViewer로 감싸서 확대/축소 가능)
        LayoutBuilder(
          builder: (context, constraints) {
            // 이미지의 실제 높이 계산 (width에 맞춰서 비율에 따라)
            final imageWidth = constraints.maxWidth;
            final imageActualHeight = imageWidth * _imageAspectRatio;
            
            return Container(
              key: key,
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
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final imageHeight = imageActualHeight;

                  return InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 3.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    onInteractionUpdate: (details) {
                      // 줌 레벨 업데이트
                      final scale = _transformationController.value.getMaxScaleOnAxis();
                      setState(() {
                        _currentScale = scale;
                      });
                    },
                    onInteractionEnd: (details) {
                      // 상호작용 종료 시 줌 레벨 업데이트
                      final scale = _transformationController.value.getMaxScaleOnAxis();
                      setState(() {
                        _currentScale = scale;
                      });
                    },
                    child: GestureDetector(
                      onTapDown: (details) {
                        if (!_isGameOver) {
                          // Global position 계산
                          final RenderBox? box =
                              key.currentContext?.findRenderObject() as RenderBox?;
                          Offset globalPos = details.globalPosition;
                          if (box != null) {
                            globalPos = box.localToGlobal(details.localPosition);
                          }

                          _onImageTapped(
                            details.localPosition,
                            Size(imageWidth, imageHeight),
                            isOriginal,
                            globalPos,
                          );
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 이미지 (반응형으로 프레임 width에 100% 맞춤, 이미지가 잘리지 않도록)
                          Image.asset(
                            imagePath,
                            key: isOriginal ? _originalImageWidgetKey : _wrongImageWidgetKey,
                            fit: BoxFit.fitWidth, // 프레임의 width에 100% 맞춤 (반응형)
                            alignment: Alignment.topCenter, // 상단 중앙 정렬
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

                          // 찾은 스팟 표시 (테두리만 있는 연한 초록색 동그라미)
                          ..._buildFoundSpotMarkers(imageWidth, imageHeight),

                          // 오답 X 표시 (해당 이미지에만 표시)
                          if (_showWrongTapX &&
                              _wrongTapPosition != null &&
                              _isOriginalImageWrongTap == isOriginal)
                            _buildWrongTapMarker(),

                          // 힌트 표시
                          if (_isShowingHint)
                            ..._buildHintMarkers(imageWidth, imageHeight),

                          // 디버그 모드: 모든 스팟 위치 표시
                          if (_debugMode)
                            ..._buildDebugSpotMarkers(imageWidth, imageHeight, isOriginal),
                        ],
                      ),
                    ),
                  );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
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

  /// 찾은 스팟 마커들 (테두리만 있는 연한 초록색 동그라미 - 체크 아이콘 없음)
  /// 시각적 크기는 kSpotCircleSize (30x30) 고정
  List<Widget> _buildFoundSpotMarkers(double containerWidth, double containerHeight) {
    final markers = <Widget>[];
    
    // 실제 이미지 영역 계산
    final imageRect = _calculateActualImageRect(Size(containerWidth, containerHeight));
    
    // 정답 원 크기 = 고정값 30x30
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
                      // 테두리만 있는 동그라미 (배경 없음)
                      border: Border.all(
                        color: _spotCircleColor,
                        width: 3,
                      ),
                      // 외곽선 그림자 (시인성 강화 - 복잡한 배경에서도 잘 보이도록)
                      boxShadow: [
                        // 외부 검은색 그림자 (강화)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                        // 내부 발광 효과
                        BoxShadow(
                          color: _spotCircleColor.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    // 체크 아이콘 없음 - 테두리만!
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

  /// 힌트 마커 (kSpotCircleSize 크기로 통일)
  List<Widget> _buildHintMarkers(double containerWidth, double containerHeight) {
    final markers = <Widget>[];
    
    // 실제 이미지 영역 계산
    final imageRect = _calculateActualImageRect(Size(containerWidth, containerHeight));
    
    // 힌트 원 크기 = 고정값 30x30
    const circleSize = kSpotCircleSize;
    const circleRadius = circleSize / 2;

    for (int i = 0; i < _foundSpots.length; i++) {
      if (!_foundSpots[i]) {
        // 아직 찾지 못한 스팟만 힌트 표시
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

  /// 디버그 모드: 모든 스팟 위치 표시 (kDefaultTouchRadius 기준)
  /// actualImageRect 기준으로 정확히 표시
  List<Widget> _buildDebugSpotMarkers(double containerWidth, double containerHeight, bool isOriginal) {
    // 실제 이미지 렌더링 영역 계산 (BoxFit.contain 여백 고려)
    final actualImageRect = _calculateActualImageRect(Size(containerWidth, containerHeight));
    return _buildDebugMarkersWithRect(actualImageRect.width, actualImageRect.height, actualImageRect.offsetX, actualImageRect.offsetY);
  }

  /// 디버그 마커를 실제 이미지 영역 기준으로 생성
  List<Widget> _buildDebugMarkersWithRect(double imageWidth, double imageHeight, double offsetX, double offsetY) {
    final markers = <Widget>[];
    
    // 디버그 원 크기 = kDefaultTouchRadius 기준 (실제 이미지 너비 기준)
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

      // 터치 반경 표시 (원) - kDefaultTouchRadius 기준
      // (개별 spot.radius는 무시, 전역 상수 사용)
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

  /// 하단 버튼 영역 (힌트 + 줌 리셋)
  Widget _buildBottomButtons() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 줌 리셋 버튼 (확대 상태일 때만 표시)
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

  const _GameResultDialog({
    required this.isWin,
    required this.foundCount,
    required this.totalCount,
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
