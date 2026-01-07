import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../l10n/app_localizations.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../game/models/card.dart';
import '../../game/models/card_factory.dart';
import '../widgets/game_card_widget.dart';
import '../../sound_manager.dart';
import '../../data/collection_manager.dart';
import '../../data/game_counter.dart';
import '../../data/ticket_manager.dart';
import '../../ads/admob_handler.dart';
import 'collection_screen.dart';
import '../../services/share_service.dart';
import '../../services/coin_manager.dart';
import '../../services/daily_mission_service.dart';
import '../../services/game_service.dart';

/// 실제 게임 화면
class GameScreen extends StatefulWidget {
  final GameDifficulty difficulty;

  const GameScreen({
    super.key,
    required this.difficulty,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameBoard _gameBoard;
  late AnimationController _flipAnimationController;
  final SoundManager _soundManager = SoundManager();
  final CollectionManager _collectionManager = CollectionManager();
  final AdmobHandler _adMobHandler = AdmobHandler();
  final DailyMissionService _missionService = DailyMissionService();
  final TicketManager _ticketManager = TicketManager();

  Timer? _gameTimer;
  Timer? _hintTimer;
  Timer? _idleTimer; // 사용자 비활성 상태 체크용 타이머
  Timer? _initialHintTimer; // 초기 카드 힌트 타이머
  Timer? _hintItemTimer; // 힌트 아이템 타이머
  DateTime? _timerPausedAt; // 타이머가 일시정지된 시점
  int _remainingTime = 0;
  int _score = 0;
  int _moves = 0;
  int _comboCount = 0;

  final List<GameCard> _selectedCards = [];
  bool _isProcessing = false;
  GameState _gameState = GameState.playing;
  bool _isShowingHint = false; // 카드 힌트 표시 중인지 확인
  bool _hasReceivedReward = false; // 보상형 광고에서 보상을 받았는지 추적
  CollectionResult? _currentRewardResult; // 현재 뽑은 카피바라 결과 저장
  int _currentCoinReward = 0; // 현재 게임에서 받은 코인 보상
  String _pendingAction = ''; // 사용자가 선택한 액션 ('home' 또는 'restart')
  bool _hasUsedRedraw = false; // 이번 게임에서 다시 뽑기를 사용했는지 추적
  bool _hasWatchedHintAd = false; // 힌트 아이템 광고를 시청했는지 추적
  bool _isWatchingAdForHint = false; // 힌트 아이템을 위한 광고 시청 중인지 추적

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGame();
    _setupAnimations();
    // 배너 광고는 _BannerAdContainer에서 관리하므로 여기서는 로드하지 않음
    // 전면 광고 미리 로드 (약간의 지연 후)
    Future.delayed(const Duration(milliseconds: 1000), () async {
      await _adMobHandler.loadInterstitialAd();
      print('게임 화면 - 전면 광고 로드 시작');
    });
    // 보상형 광고 미리 로드 (약간의 지연 후)
    Future.delayed(const Duration(milliseconds: 1500), () async {
      await _adMobHandler.loadRewardedAd();
      print('게임 화면 - 보상형 광고 로드 시작');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameTimer?.cancel();
    _hintTimer?.cancel();
    _idleTimer?.cancel();
    _initialHintTimer?.cancel();
    _hintItemTimer?.cancel();
    _flipAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // 앱이 백그라운드로 이동하거나 비활성화될 때 배경음 일시정지
        _soundManager.pauseBgm();
        break;
      case AppLifecycleState.resumed:
        // 앱이 다시 활성화될 때 배경음 재개
        _soundManager.resumeBgm();
        break;
      case AppLifecycleState.detached:
        // 앱이 종료될 때는 특별한 처리 없음
        break;
      case AppLifecycleState.hidden:
        // 앱이 숨겨질 때 배경음 일시정지
        _soundManager.pauseBgm();
        break;
    }
  }

  void _initializeGame() {
    // 기존 타이머들 모두 취소 (충돌 방지)
    _gameTimer?.cancel();
    _hintTimer?.cancel();
    _idleTimer?.cancel();
    _initialHintTimer?.cancel();

    // 게임 보드 생성
    _gameBoard = CapybaraCardFactory.createGameBoard(widget.difficulty);

    // 타이머 설정
    _remainingTime = GameHelpers.getTimeLimit(widget.difficulty);
    _startTimer();
    _startIdleTimer();

    // 초기값 설정
    _score = 0;
    _moves = 0;
    _comboCount = 0;
    _selectedCards.clear();
    _gameState = GameState.playing;
    _isShowingHint = false;
    _hasUsedRedraw = false; // 다시 뽑기 플래그 초기화
    _hasWatchedHintAd = false; // 힌트 아이템 광고 플래그 초기화

    // 게임 시작 시 카드 힌트 표시
    _showInitialCardHint();
  }

  void _setupAnimations() {
    _flipAnimationController = AnimationController(
      duration: GameConstants.cardFlipDuration,
      vsync: this,
    );
  }

  void _startTimer() {
    _gameTimer?.cancel();

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _endGame(false);
      }
    });
  }

  /// 타이머 일시정지 (힌트 모달, 광고 시청 등)
  void _pauseTimer() {
    if (_gameTimer != null && _gameTimer!.isActive) {
      _gameTimer?.cancel();
      _timerPausedAt = DateTime.now(); // 일시정지 시점 기록 (플래그용)
    }
  }

  /// 타이머 재개
  void _resumeTimer() {
    if (_gameState == GameState.playing && _timerPausedAt != null) {
      _timerPausedAt = null; // 일시정지 플래그 초기화
      _startTimer(); // 남은 시간 그대로 타이머 재시작
    }
  }

  /// 사용자 비활성 상태 체크 타이머 시작
  void _startIdleTimer() {
    // 레벨 1에서는 힌트 제공하지 않음
    if (widget.difficulty == GameDifficulty.level1) return;

    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 5), () {
      if (_gameState == GameState.playing &&
          !_isProcessing &&
          !_isShowingHint) {
        _showHint();
      }
    });
  }

  /// 사용자 액션 시 비활성 타이머 리셋
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _startIdleTimer();
  }

  /// 게임 시작 시 모든 카드 힌트 표시
  void _showInitialCardHint() {
    // 이전 초기 힌트 타이머가 있으면 취소
    _initialHintTimer?.cancel();

    setState(() {
      _isShowingHint = true;
      // 모든 카드를 앞면으로 뒤집기
      for (final card in _gameBoard.cards) {
        card.flip();
      }
    });

    // 3초 후 모든 카드를 뒷면으로 뒤집기
    _initialHintTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _isShowingHint = false;
          // 모든 카드를 뒷면으로 뒤집기
          for (final card in _gameBoard.cards) {
            card.flip();
          }
        });
      }
    });
  }

  void _showHint() {
    // 매칭되지 않은 카드들 중에서 랜덤하게 선택
    final unmatchedCards = _gameBoard.cards
        .where((card) => !card.isMatched && !card.isFlipped)
        .toList();

    if (unmatchedCards.length < 2) return;

    // 랜덤하게 2-3장의 카드를 선택해서 잠시 보여주기
    final random = Random();
    final hintCount = random.nextInt(2) + 2; // 2-3장
    final hintCards = <GameCard>[];

    for (int i = 0; i < hintCount && i < unmatchedCards.length; i++) {
      final randomIndex = random.nextInt(unmatchedCards.length);
      final card = unmatchedCards[randomIndex];
      if (!hintCards.contains(card)) {
        hintCards.add(card);
      }
    }

    // 선택된 카드들을 잠시 뒤집기
    setState(() {
      for (final card in hintCards) {
        card.flip();
      }
    });

    // 1.5초 후 다시 뒤집기
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          for (final card in hintCards) {
            if (!card.isMatched) {
              card.flip();
            }
          }
        });
        // 힌트 표시 후 비활성 타이머 다시 시작
        _resetIdleTimer();
      }
    });
  }

  void _onCardTapped(GameCard card) {
    if (_isProcessing ||
        card.isMatched ||
        card.isFlipped ||
        _selectedCards.length >= 2 ||
        _gameState != GameState.playing ||
        _isShowingHint) {
      // 힌트 표시 중에는 카드 선택 불가
      return;
    }

    // 카드 선택 시 사운드 재생
    _soundManager.playCardFlipSound();

    setState(() {
      card.flip();
      _selectedCards.add(card);
      _moves++;
    });

    // 사용자 액션 시 비활성 타이머 리셋
    _resetIdleTimer();

    if (_selectedCards.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    _isProcessing = true;

    final card1 = _selectedCards[0];
    final card2 = _selectedCards[1];

    if (card1.pairId == card2.pairId) {
      // 매칭 성공
      _handleMatch(card1, card2);
    } else {
      // 매칭 실패
      _handleMismatch(card1, card2);
    }
  }

  void _handleMatch(GameCard card1, GameCard card2) {
    _comboCount++;

    // 카드 매칭 성공 시 사운드 재생
    _soundManager.playMatchSuccessSound();

    setState(() {
      card1.markAsMatched();
      card2.markAsMatched();

      // 점수 계산
      _score += GameConstants.baseScore +
          (_comboCount * GameConstants.comboMultiplier);

      _selectedCards.clear();
      _isProcessing = false;
    });

    // 게임 완료 체크
    if (_gameBoard.isGameComplete()) {
      _endGame(true);
    }
  }

  void _handleMismatch(GameCard card1, GameCard card2) {
    _comboCount = 0; // 콤보 리셋

    // 잠시 기다린 후 카드 뒤집기
    Timer(const Duration(milliseconds: 1000), () {
      setState(() {
        card1.flip();
        card2.flip();
        _selectedCards.clear();
        _isProcessing = false;
      });
    });
  }

  void _endGame(bool isWin) async {
    _gameTimer?.cancel();
    _hintTimer?.cancel();
    _idleTimer?.cancel();

    setState(() {
      _gameState = isWin ? GameState.gameOver : GameState.gameOver;
    });

    if (isWin) {
      // 시간 보너스 추가
      _score += _remainingTime * GameConstants.timeBonus;
      // 게임 완료 시 사운드 재생
      _soundManager.playGameCompleteSound();

      // 게임 완료 보상: 10 코인 지급
      await CoinManager.addCoins(10);

      // 데일리 미션: 게임 완료 업데이트
      await _missionService.completeGame();

      // 리더보드에 점수 제출
      await GameService.submitScore(_score);

      // 선물 박스 다이얼로그 표시 (카드는 아직 추가하지 않음)
      _showGiftBoxDialog();
    } else {
      // 시간 초과 시 항상 광고 보고 시간 연장 다이얼로그 표시
      _showTimeExtensionDialog();
    }
  }

  void _showGameResultDialog(bool isWin, CollectionResult? result) {
    if (isWin && result != null) {
      // 게임 승리 시 선물 박스 다이얼로그 먼저 표시
      _showGiftBoxDialog();
    } else {
      // 게임 실패 시 기존 다이얼로그 표시
      _showFailureDialog();
    }
  }

  /// 선물 박스 다이얼로그 표시 (뽑기권 획득)
  void _showGiftBoxDialog() async {
    // 티켓 매니저 초기화
    await _ticketManager.initialize();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TicketRewardDialog(
        score: _score,
        moves: _moves,
        remainingTime: _remainingTime,
        difficulty: widget.difficulty,
        canEarnTicket: _ticketManager.canEarnTicketToday,
        remainingTickets: _ticketManager.remainingDailyTickets,
        currentTicketCount: _ticketManager.ticketCount,
        onClaimTicket: () => _claimTicket(context),
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

  /// 뽑기권 획득
  Future<void> _claimTicket(BuildContext dialogContext) async {
    // 전면 광고 표시
    await _adMobHandler.showInterstitialAd();

    if (!mounted) return;

    // 뽑기권 획득 시도
    final earned = await _ticketManager.earnTicket();

    if (earned) {
      // 데일리 미션 업데이트
      await _missionService.completeGame();

      Navigator.of(dialogContext).pop();
      _showTicketEarnedDialog();
    } else {
      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ko'
                ? '오늘 뽑기권을 모두 획득했습니다!'
                : 'You\'ve earned all tickets for today!',
          ),
        ),
      );
      Navigator.of(context).pop(); // 홈으로 이동
    }
  }

  /// 뽑기권 획득 완료 다이얼로그
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
              const SizedBox(height: 20),
              // 코인 획득 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/coin.webp',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isKorean ? '+10 코인' : '+10 Coins',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB8860B),
                      ),
                    ),
                  ],
                ),
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
                      child: Text(
                        isKorean ? '홈으로' : 'Home',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _restartGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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

  /// 게임 실패 다이얼로그 표시
  void _showFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          AppLocalizations.of(context)!.gameFailure,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.gameFailedMessage,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6F3FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${AppLocalizations.of(context)!.score}: $_score${AppLocalizations.of(context)!.scoreUnit}',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                        '${AppLocalizations.of(context)!.moves}: $_moves${AppLocalizations.of(context)!.movesUnit}',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // 홈으로 돌아가기
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.gameHome,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    AppLocalizations.of(context)!.playAgain,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 선물 박스 열기 (카드 뽑기)
  void _openGiftBox(BuildContext context) async {
    Navigator.of(context).pop(); // 선물 박스 다이얼로그 닫기

    // 광고 표시 후 캐릭터 받기
    await _adMobHandler.showInterstitialAd();
    // 광고가 닫힌 후 캐릭터 받기
    _giveCharacterReward();
  }

  /// 캐릭터 보상 지급
  void _giveCharacterReward() async {
    // 게임 완료 보상은 10코인으로 고정 (이미 _endGame에서 지급됨)
    _currentCoinReward = 10;

    // 컬렉션에 새 카드 추가
    await _collectionManager.initializeCollection();
    final result = await _collectionManager.addNewCard(widget.difficulty);

    // 현재 뽑은 결과 저장 (다시 뽑기 기능용)
    _currentRewardResult = result;

    // 카드 뽑기 다이얼로그 표시
    _showCardDrawDialog(result, _currentCoinReward);
  }

  /// 카드 뽑기 다이얼로그 표시 (애니메이션 포함)
  void _showCardDrawDialog(CollectionResult result, int coinReward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CardDrawDialog(
        result: result,
        onComplete: () {
          Navigator.of(context).pop(); // 카드 뽑기 다이얼로그 닫기
          _showFinalResultDialog(result, coinReward); // 최종 결과 다이얼로그 표시
        },
      ),
    );
  }

  /// 최종 결과 다이얼로그 표시
  void _showFinalResultDialog(CollectionResult result, int coinReward) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          result.isNewCard
              ? AppLocalizations.of(context)!.gameSuccess
              : AppLocalizations.of(context)!.gameCompleted,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 카드 이미지
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: result.isNewCard
                        ? const Color(0xFF4A90E2)
                        : const Color(0xFFF0AD4E),
                    width: 3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: result.card != null
                      ? Image.asset(
                          result.card!.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 30,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 30,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: result.isNewCard
                      ? const Color(0xFFE8F5E8)
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: result.isNewCard
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFFF0AD4E),
                      width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      result.isNewCard ? Icons.stars : Icons.info,
                      color: result.isNewCard
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFFF0AD4E),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.isNewCard
                            ? AppLocalizations.of(context)!.newCapybaraFound
                            : AppLocalizations.of(context)!.alreadyCollected,
                        style: TextStyle(
                          fontSize: 14,
                          color: result.isNewCard
                              ? const Color(0xFF2C5F8B)
                              : const Color(0xFFB8860B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (result.isNewCard) ...[
            // 새로운 카드 획득 시 컬렉션 확인 버튼 표시
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _pendingAction = 'collection';
                  Navigator.of(context).pop(true); // 다이얼로그 닫기 (코인 모달 표시함)
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  AppLocalizations.of(context)!.collection,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 카피바라 다시 뽑기 버튼 (게임당 1번만 사용 가능)
          if (!_hasUsedRedraw) ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 다이얼로그는 광고가 실제로 표시될 때 닫도록 변경
                      _redrawCapybaraWithRewardedAd();
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.redrawCapybara,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A90E2),
                      side: const BorderSide(
                        color: Color(0xFF4A90E2),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'AD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // 친구에게 자랑하기 버튼 (테두리만 있는 스타일)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                String difficultyText;
                switch (widget.difficulty) {
                  case GameDifficulty.level1:
                    difficultyText = 'level1';
                    break;
                  case GameDifficulty.level2:
                    difficultyText = 'level2';
                    break;
                  case GameDifficulty.level3:
                    difficultyText = 'level3';
                    break;
                  case GameDifficulty.level4:
                    difficultyText = 'level4';
                    break;
                  case GameDifficulty.level5:
                    difficultyText = 'level5';
                    break;
                }

                // 게임 완료 시간 계산 (초기 시간 - 남은 시간)
                final initialTime = GameHelpers.getTimeLimit(widget.difficulty);
                final completedTime = initialTime - _remainingTime;

                await ShareService.shareGameScore(
                  score: _score,
                  difficulty: difficultyText,
                  gameTime: completedTime,
                  context: context,
                );

                // 데일리 미션: 친구에게 공유하기 업데이트
                await _missionService.shareToFriend();
              },
              icon: const Icon(Icons.share, size: 20),
              label: Text(
                Localizations.localeOf(context).languageCode == 'ko'
                    ? '친구에게 자랑하기'
                    : 'Share with Friends',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A90E2),
                side: const BorderSide(
                  color: Color(0xFF4A90E2),
                  width: 2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _pendingAction = 'home';
                    Navigator.of(context).pop(true); // 다이얼로그 닫기 (코인 모달 표시함)
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.gameHome,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _pendingAction = 'restart';
                    Navigator.of(context).pop(true); // 다이얼로그 닫기 (코인 모달 표시함)
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.playAgain,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).then((shouldShowCoinModal) {
      // 다이얼로그가 닫힐 때 코인 획득 모달 표시
      if (shouldShowCoinModal == true && mounted) {
        _showCoinRewardModal();
      }
    });
  }

  /// 코인 획득 모달 표시
  void _showCoinRewardModal() {
    final localizations = AppLocalizations.of(context)!;

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
              colors: [
                Color(0xFFE8F4F8),
                Color(0xFFD6EBF5),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF4A90E2),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 코인 이미지
              Image.asset(
                'assets/images/coin-2.webp',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/coin.webp',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.monetization_on,
                        size: 120,
                        color: Colors.amber,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              // 텍스트
              Text(
                localizations.gameCompleteCoinReward,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 코인 모달 닫기
                    // 사용자가 선택한 액션 실행
                    if (_pendingAction == 'home') {
                      Navigator.of(context).pop(); // 홈으로 돌아가기
                    } else if (_pendingAction == 'restart') {
                      _restartGame(); // 게임 재시작
                    } else if (_pendingAction == 'collection') {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const CollectionScreen(),
                        ),
                        (route) => route.isFirst, // 첫 번째 페이지(메인)까지만 유지
                      );
                    }
                    _pendingAction = ''; // 액션 초기화
                  },
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
                    localizations.ok,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _restartGame() async {
    // 게임 횟수 증가
    await GameCounter.incrementGameCount();

    print('게임 재시작 - 광고 없이 바로 재시작');
    // 게임 완료 후 다시 플레이 시에는 광고 없이 바로 재시작
    _restartGameDirectly();
  }

  /// 게임 직접 재시작 (광고 로직 없이)
  void _restartGameDirectly() {
    setState(() {
      _initializeGame();
    });
  }

  /// 시간 연장 다이얼로그 표시
  void _showTimeExtensionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          AppLocalizations.of(context)!.timeUpTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/gameover.webp',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // 이미지 로드 실패 시 기본 아이콘 표시
                  return const Icon(
                    Icons.schedule,
                    size: 64,
                    color: Color(0xFF333333),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.timeUpMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.timeUpSubMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 포기하기 선택 시 게임 실패 처리
                  _showGameResultDialog(false, null);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  AppLocalizations.of(context)!.giveUp,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _watchAdForTimeExtension();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.watchAd,
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

  /// 광고 시청 후 시간 연장 (보상형 광고 사용)
  void _watchAdForTimeExtension() async {
    print('시간 연장을 위한 보상형 광고 시청 시작');

    // 보상 받음 플래그 초기화
    _hasReceivedReward = false;

    // 보상형 광고가 준비되지 않았으면 강제로 로드
    if (!_adMobHandler.isRewardedAdLoaded) {
      print('보상형 광고 준비 안됨 - 강제 로드 시작 (시간 연장)');
      await _adMobHandler.loadRewardedAd();
      // 2초 후 다시 시도
      Future.delayed(const Duration(seconds: 2), () async {
        if (_adMobHandler.isRewardedAdLoaded) {
          await _adMobHandler.showRewardedAd(
            onRewarded: (reward) {
              print('보상 획득: ${reward.type}, ${reward.amount}');
              _hasReceivedReward = true; // 보상 받음 플래그 설정
              // 보상을 받았으면 즉시 시간 연장하지 않고, 광고가 닫힐 때 처리
            },
            onAdDismissed: () {
              print('보상형 광고 닫힘');
              if (mounted) {
                if (_hasReceivedReward) {
                  // 보상을 받았으면 시간 연장
                  print('보상을 받았으므로 시간 연장');
                  _extendGameTime();
                } else {
                  // 보상을 받지 않았으면 게임 종료하고 홈으로
                  print('보상을 받지 않았으므로 게임 종료');
                  _gameTimer?.cancel();
                  _hintTimer?.cancel();
                  _idleTimer?.cancel();
                  Navigator.of(context).pop(); // 홈으로 돌아가기
                }
              }
            },
            onAdFailedToShow: (ad) {
              print('보상형 광고 표시 실패 - 게임 종료');
              // 광고 표시 실패 시 게임 종료하고 홈으로
              if (mounted) {
                _gameTimer?.cancel();
                _hintTimer?.cancel();
                _idleTimer?.cancel();
                Navigator.of(context).pop(); // 홈으로 돌아가기
              }
            },
          );
        } else {
          print('보상형 광고 로드 실패 - 게임 종료');
          // 광고 로드 실패 시 게임 종료하고 홈으로
          if (mounted) {
            _gameTimer?.cancel();
            _hintTimer?.cancel();
            _idleTimer?.cancel();
            Navigator.of(context).pop(); // 홈으로 돌아가기
          }
        }
      });
    } else {
      // 보상형 광고 표시
      await _adMobHandler.showRewardedAd(
        onRewarded: (reward) {
          print('보상 획득: ${reward.type}, ${reward.amount}');
          _hasReceivedReward = true; // 보상 받음 플래그 설정
          // 보상을 받았으면 즉시 시간 연장하지 않고, 광고가 닫힐 때 처리
        },
        onAdDismissed: () {
          print('보상형 광고 닫힘');
          if (mounted) {
            if (_hasReceivedReward) {
              // 보상을 받았으면 시간 연장
              print('보상을 받았으므로 시간 연장');
              _extendGameTime();
            } else {
              // 보상을 받지 않았으면 게임 종료하고 홈으로
              print('보상을 받지 않았으므로 게임 종료');
              _gameTimer?.cancel();
              _hintTimer?.cancel();
              _idleTimer?.cancel();
              Navigator.of(context).pop(); // 홈으로 돌아가기
            }
          }
        },
        onAdFailedToShow: (ad) {
          print('보상형 광고 표시 실패 - 게임 종료');
          // 광고 표시 실패 시 게임 종료하고 홈으로
          if (mounted) {
            _gameTimer?.cancel();
            _hintTimer?.cancel();
            _idleTimer?.cancel();
            Navigator.of(context).pop(); // 홈으로 돌아가기
          }
        },
      );
    }
  }

  /// 게임 시간 연장 (30초 추가)
  void _extendGameTime() {
    setState(() {
      _remainingTime = 30; // 30초 추가
      _gameState = GameState.playing;
    });

    // 타이머 재시작
    _startTimer();
    _startIdleTimer();

    print('게임 시간 30초 연장 완료');
  }

  /// 보상형 광고를 보고 카피바라 다시 뽑기
  void _redrawCapybaraWithRewardedAd() async {
    if (_currentRewardResult == null || _currentRewardResult!.card == null) {
      print('뽑을 카피바라 정보가 없습니다.');
      return;
    }

    // 이미 다시 뽑기를 사용했으면 리턴
    if (_hasUsedRedraw) {
      print('이미 이번 게임에서 다시 뽑기를 사용했습니다.');
      return;
    }

    // 보상 받음 플래그 초기화
    _hasReceivedReward = false;
    final previousCardId = _currentRewardResult!.card!.id;
    // 이전 결과를 백업 (보상을 받지 않았을 때 복원하기 위해)
    final previousResult = _currentRewardResult;

    // 보상형 광고가 준비되지 않았으면 로드
    if (!_adMobHandler.isRewardedAdLoaded) {
      print('보상형 광고 준비 안됨 - 강제 로드 시작 (카피바라 다시 뽑기)');
      await _adMobHandler.loadRewardedAd();
      // 2초 후 다시 시도 (광고가 완전히 로드될 때까지 대기)
      await Future.delayed(const Duration(seconds: 2));

      // 2초 후에도 광고가 로드되지 않았으면 에러 처리
      if (!_adMobHandler.isRewardedAdLoaded) {
        print('보상형 광고 로드 실패 - 이전 결과 팝업 복원');
        if (mounted && previousResult != null) {
          // 다이얼로그가 이미 닫혔을 수 있으므로 다시 표시
          _showFinalResultDialog(previousResult, _currentCoinReward);
        }
        return;
      }
    }

    // 현재 표시된 다이얼로그 닫기 (광고 표시 전에)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }

    // 보상형 광고 표시
    await _adMobHandler.showRewardedAd(
      onRewarded: (reward) {
        print('보상 획득: ${reward.type}, ${reward.amount}');
        _hasReceivedReward = true;
        _hasUsedRedraw = true; // 다시 뽑기 사용 플래그 설정
      },
      onAdDismissed: () {
        if (mounted) {
          if (_hasReceivedReward) {
            // 보상을 받았으면 다시 뽑기
            print('보상을 받았으므로 카피바라 다시 뽑기');
            _redrawCapybara(previousCardId);
          } else {
            // 보상을 받지 않았으면 이전 결과 팝업 다시 표시
            print('보상을 받지 않았으므로 이전 결과 팝업 복원');
            if (previousResult != null) {
              _showFinalResultDialog(previousResult, _currentCoinReward);
            }
          }
        }
      },
      onAdFailedToShow: (ad) {
        print('보상형 광고 표시 실패 - 이전 결과 팝업 복원');
        // 광고 표시 실패 시에도 이전 결과 팝업 다시 표시
        if (mounted && previousResult != null) {
          _showFinalResultDialog(previousResult, _currentCoinReward);
        }
      },
    );
  }

  /// 카피바라 다시 뽑기 (이전 카드 잠금 후 새 카드 뽑기)
  void _redrawCapybara(int previousCardId) async {
    // 이전 카드를 잠금 상태로 되돌리기
    await _collectionManager.lockCard(previousCardId);

    // 새 카드 뽑기
    await _collectionManager.initializeCollection();
    final newResult = await _collectionManager.addNewCard(widget.difficulty);

    // 현재 뽑은 결과 업데이트
    _currentRewardResult = newResult;

    // 새 카드 뽑기 다이얼로그 표시 (코인은 이미 지급되었으므로 동일한 금액 표시)
    _showCardDrawDialog(newResult, _currentCoinReward);
  }

  /// 힌트 아이템 버튼 클릭
  void _onHintItemButtonTapped() {
    _showHintItemModal();
  }

  /// 힌트 아이템 모달 표시
  void _showHintItemModal() {
    final localizations = AppLocalizations.of(context)!;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    // 게임 타이머 일시정지
    _pauseTimer();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE8F4F8),
                Color(0xFFD6EBF5),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF4A90E2),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 타이틀
              Text(
                isKorean ? '아이템 사용' : 'Use Item',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90E2),
                ),
              ),
              const SizedBox(height: 24),

              // 아이콘 이미지
              Image.asset(
                'assets/images/glasses2.webp',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.remove_red_eye,
                    size: 100,
                    color: Color(0xFF4A90E2),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 설명 텍스트
              Text(
                isKorean
                    ? '광고 보고 전체 카드 앞면 2초간 보기'
                    : 'Watch ad to see all cards for 2 seconds',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // 광고 보기 버튼 or 힌트 사용 버튼
              SizedBox(
                width: double.infinity,
                child: _hasWatchedHintAd
                    ? ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _useHintItem();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isKorean
                              ? '2초간 모든 카드 앞면 보기'
                              : 'Show All Cards for 2 Seconds',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          // 모달은 닫지 않고, 광고 시청 후에 닫도록 함
                          _watchAdForHintItem();
                        },
                        icon: const Icon(Icons.play_circle_outline, size: 24),
                        label: Text(
                          isKorean ? '광고 보기' : 'Watch Ad',
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
              const SizedBox(height: 12),

              // 닫기 버튼
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    localizations.close,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // 모달이 닫히면 게임 타이머 재개 (광고 시청 중이 아닐 때만)
      if (mounted &&
          _gameState == GameState.playing &&
          _timerPausedAt != null &&
          !_isWatchingAdForHint) {
        _resumeTimer();
      }
    });
  }

  /// 힌트 아이템용 광고 시청
  void _watchAdForHintItem() async {
    print('힌트 아이템을 위한 보상형 광고 시청 시작');

    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    // 광고 시청 중 플래그 설정
    _isWatchingAdForHint = true;

    // 광고 시청 중에도 게임 타이머 일시정지 (이미 일시정지되어 있으면 그대로 유지)
    if (_timerPausedAt == null) {
      _pauseTimer();
    }

    // 모달 닫기 (광고 시청 시작)
    Navigator.of(context).pop();

    // 보상 받음 플래그 초기화
    _hasReceivedReward = false;

    // 보상형 광고가 준비되지 않았으면 강제로 로드
    if (!_adMobHandler.isRewardedAdLoaded) {
      print('보상형 광고 준비 안됨 - 강제 로드 시작 (힌트 아이템)');
      await _adMobHandler.loadRewardedAd();
      // 2초 후 다시 시도
      await Future.delayed(const Duration(seconds: 2));

      if (!_adMobHandler.isRewardedAdLoaded) {
        print('보상형 광고 로드 실패 - 힌트 아이템 사용 불가');
        if (mounted) {
          // 광고 시청 완료 플래그 해제
          _isWatchingAdForHint = false;
          // 타이머 재개
          if (_gameState == GameState.playing) {
            _resumeTimer();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isKorean ? '광고를 불러올 수 없습니다.' : 'Failed to load ad.',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.grey[900]!.withOpacity(0.8),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    // 보상형 광고 표시
    await _adMobHandler.showRewardedAd(
      onRewarded: (reward) {
        print('보상 획득: ${reward.type}, ${reward.amount}');
        _hasReceivedReward = true;
      },
      onAdDismissed: () {
        print('보상형 광고 닫힘 (힌트 아이템)');
        if (mounted) {
          // 광고 시청 완료 플래그 해제
          _isWatchingAdForHint = false;

          if (_hasReceivedReward) {
            // 보상을 받았으면 힌트 아이템 사용 가능 상태로 변경
            print('보상을 받았으므로 힌트 아이템 사용 가능');
            setState(() {
              _hasWatchedHintAd = true;
            });
            // 모달 다시 표시 (타이머는 이미 일시정지 상태이므로 재개하지 않음)
            _showHintItemModal();
          } else {
            print('보상을 받지 않았으므로 힌트 아이템 사용 불가');
            // 보상을 받지 않았으면 타이머 재개
            if (_gameState == GameState.playing) {
              _resumeTimer();
            }
          }
        }
      },
      onAdFailedToShow: (ad) {
        print('보상형 광고 표시 실패 - 힌트 아이템 사용 불가');
        if (mounted) {
          // 광고 시청 완료 플래그 해제
          _isWatchingAdForHint = false;
          // 타이머 재개
          if (_gameState == GameState.playing) {
            _resumeTimer();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isKorean ? '광고를 표시할 수 없습니다.' : 'Failed to show ad.',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.grey[900]!.withOpacity(0.8),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  /// 힌트 아이템 사용 (2초간 모든 카드 앞면 보기)
  void _useHintItem() {
    // 이전 힌트 타이머가 있으면 취소
    _hintItemTimer?.cancel();

    setState(() {
      _isShowingHint = true;
      // 모든 카드를 앞면으로 뒤집기 (매칭된 카드 제외)
      for (final card in _gameBoard.cards) {
        if (!card.isMatched && !card.isFlipped) {
          card.flip();
        }
      }
    });

    // 정확히 2초 후 모든 카드를 뒷면으로 뒤집기
    _hintItemTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _isShowingHint = false;
          // 모든 카드를 뒷면으로 뒤집기 (매칭된 카드 제외)
          for (final card in _gameBoard.cards) {
            if (!card.isMatched && card.isFlipped) {
              card.flip();
            }
          }
          // 힌트 아이템 사용 완료 후 플래그 초기화
          _hasWatchedHintAd = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF), // 연한 파스텔 하늘색
      appBar: AppBar(
        title: Text(_getDifficultyText()),
        backgroundColor: Colors.white, // 하얀색 헤더
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
          ),
        ],
      ),
      body: Column(
        children: [
          // 게임 정보 바
          _buildGameInfoBar(),

          // 게임 보드 + 힌트 버튼 (스크롤 가능)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 게임 보드
                  _buildGameBoard(),

                  // 힌트 버튼 (카드 영역과 16px 간격)
                  _buildHintButton(),
                ],
              ),
            ),
          ),

          // 광고 배너 (하단 고정)
          const _BannerAdContainer(),
        ],
      ),
    );
  }

  Widget _buildGameInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isShowingHint
          ? const Color(0xFFFFF8E1) // 힌트 표시 중일 때는 주황색
          : const Color(0xFFE6F3FF), // 연한 파스텔 하늘색
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(AppLocalizations.of(context)!.time,
              GameHelpers.formatTime(_remainingTime)),
          _buildInfoItem(AppLocalizations.of(context)!.score, '$_score'),
          _buildInfoItem(AppLocalizations.of(context)!.moves, '$_moves'),
          _buildInfoItem(AppLocalizations.of(context)!.combo, '$_comboCount'),
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
            fontSize: 11,
            color: Color(0xFF4A90E2),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF2C5F8B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 힌트 버튼 빌드 (화면 중앙, 카드 영역과 16px 간격)
  Widget _buildHintButton() {
    final screenWidth = MediaQuery.of(context).size.width;

    // 반응형 버튼 크기 (화면 크기에 비례)
    final buttonSize = screenWidth * 0.12; // 화면 너비의 12% (10%에서 증가)
    final minButtonSize = 45.0; // 최소 크기 (40에서 증가)
    final maxButtonSize = 58.0; // 최대 크기 (50에서 증가)
    final finalButtonSize = buttonSize.clamp(minButtonSize, maxButtonSize);

    return Container(
      padding: const EdgeInsets.only(top: 0, bottom: 0),
      color: Colors.transparent, // 배경 투명
      child: Center(
        child: GestureDetector(
          onTap: _onHintItemButtonTapped,
          child: Container(
            width: finalButtonSize,
            height: finalButtonSize,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(finalButtonSize * 0.24), // 12px 비율
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(finalButtonSize * 0.24),
              child: Image.asset(
                'assets/images/glasses.webp',
                fit: BoxFit.contain,
                width: finalButtonSize,
                height: finalButtonSize,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.transparent,
                    child: Icon(
                      Icons.remove_red_eye,
                      color: const Color(0xFF4A90E2),
                      size: finalButtonSize * 0.56, // 28px 비율
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 전체 화면 높이를 가져오기
        final screenHeight = MediaQuery.of(context).size.height;

        // 카드 영역이 차지할 수 있는 최대 높이 (화면의 60% - 애드몹 광고 하단 마진 60px을 위한 공간 확보)
        final maxCardAreaHeight = screenHeight * 0.62;

        // 사용 가능한 화면 크기 계산 (패딩 제외)
        final availableWidth = constraints.maxWidth - 32; // 좌우 패딩 16 * 2
        final availableHeight = maxCardAreaHeight - 32; // 상하 패딩 16 * 2

        // 그리드 간격을 고려한 실제 카드 영역 계산
        final totalHorizontalSpacing = (_gameBoard.gridWidth - 1) * 8.0;
        final totalVerticalSpacing = (_gameBoard.gridHeight - 1) * 8.0;

        // 카드 크기 계산 (너비와 높이 기준)
        final cardWidthByWidth =
            (availableWidth - totalHorizontalSpacing) / _gameBoard.gridWidth;
        final cardHeightByHeight =
            (availableHeight - totalVerticalSpacing) / _gameBoard.gridHeight;

        // 너비와 높이 중 작은 값을 선택하여 정사각형 유지 + 여유 공간 확보
        final calculatedCardSize = (cardWidthByWidth < cardHeightByHeight
                ? cardWidthByWidth
                : cardHeightByHeight) *
            0.98; // 0.98로 약간의 여유 공간

        // 카드 크기 제한 (최소 50px, 최대 140px)
        final cardSize = calculatedCardSize.clamp(40.0, 140.0);

        // 실제 그리드 전체 크기 계산
        final gridWidth =
            cardSize * _gameBoard.gridWidth + totalHorizontalSpacing;
        final gridHeight =
            cardSize * _gameBoard.gridHeight + totalVerticalSpacing;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxCardAreaHeight, // 최대 높이 제한
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gameBoard.gridWidth,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1, // 정사각형 비율
                  ),
                  itemCount: _gameBoard.cards.length,
                  itemBuilder: (context, index) {
                    final card = _gameBoard.cards[index];
                    return GameCardWidget(
                      card: card,
                      onTap: () => _onCardTapped(card),
                      flipAnimation: _flipAnimationController,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getDifficultyText() {
    switch (widget.difficulty) {
      case GameDifficulty.level1:
        return AppLocalizations.of(context)!.level1;
      case GameDifficulty.level2:
        return AppLocalizations.of(context)!.level2;
      case GameDifficulty.level3:
        return AppLocalizations.of(context)!.level3;
      case GameDifficulty.level4:
        return AppLocalizations.of(context)!.level4;
      case GameDifficulty.level5:
        return AppLocalizations.of(context)!.level5;
    }
  }
}

/// 카드 뽑기 애니메이션 다이얼로그
class _CardDrawDialog extends StatefulWidget {
  final CollectionResult result;
  final VoidCallback onComplete;

  const _CardDrawDialog({
    required this.result,
    required this.onComplete,
  });

  @override
  State<_CardDrawDialog> createState() => _CardDrawDialogState();
}

class _CardDrawDialogState extends State<_CardDrawDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;

  bool _showCard = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimation();
  }

  void _setupAnimations() {
    // 스케일 애니메이션 (선물 박스 -> 카드) - 더 빠르고 급격하게
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // 회전 애니메이션 - 더 빠르게
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    // 덜컹덜컹 효과를 위한 shake 애니메이션
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.12)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.12, end: 0.12)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.12, end: -0.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.08, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_shakeController);

    // 페이드 애니메이션 - 더 빠르게
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
  }

  void _startAnimation() async {
    // 1. 선물 박스 스케일 애니메이션과 shake 동시 시작
    _shakeController.repeat(); // 반복적으로 덜컹덜컹
    await _scaleController.forward();

    // 2. 회전 애니메이션과 함께 카드로 변환
    _rotationController.forward();

    // 0.2초 후 카드 표시 (더 빠르게)
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _showCard = true;
    });
    _shakeController.stop(); // shake 중지

    // 3. 카드 페이드 인
    await _fadeController.forward();

    // 1.5초 후 완료 콜백 호출 (더 빠르게)
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onComplete();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.drawingCard,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            // 애니메이션 영역
            SizedBox(
              width: 150,
              height: 150,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _scaleController,
                  _rotationController,
                  _shakeController,
                  _fadeController,
                ]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.translate(
                      offset: Offset(_shakeAnimation.value * 20, 0),
                      child: Transform.rotate(
                        angle: _rotationAnimation.value * 3.14159 +
                            _shakeAnimation.value * 0.3,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _showCard
                                  ? (widget.result.isNewCard
                                      ? const Color(0xFF4A90E2)
                                      : const Color(0xFFF0AD4E))
                                  : const Color(0xFFFFD700),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _showCard
                                ? FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: widget.result.card != null
                                        ? Image.asset(
                                            widget.result.card!.imagePath,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: 40,
                                            ),
                                          ),
                                  )
                                : Image.asset(
                                    'assets/capybara/collection/gift_box.webp',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.card_giftcard,
                                          color: Colors.grey,
                                          size: 50,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            if (_showCard) ...[
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.result.isNewCard
                      ? AppLocalizations.of(context)!.gameSuccess
                      : AppLocalizations.of(context)!.gameCompleted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 선물 박스 다이얼로그 위젯 (덜컹덜컹 애니메이션 포함)
class _GiftBoxDialog extends StatefulWidget {
  final int score;
  final int moves;
  final int remainingTime;
  final GameDifficulty difficulty;
  final VoidCallback onOpenGiftBox;

  const _GiftBoxDialog({
    required this.score,
    required this.moves,
    required this.remainingTime,
    required this.difficulty,
    required this.onOpenGiftBox,
  });

  @override
  State<_GiftBoxDialog> createState() => _GiftBoxDialogState();
}

class _GiftBoxDialogState extends State<_GiftBoxDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupShakeAnimation();
    _startShakeAnimation();
  }

  void _setupShakeAnimation() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 덜컹덜컹 효과를 위한 애니메이션 (좌우로 흔들림) - 더 빠르고 강하게
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: -0.12)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.12, end: 0.12)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.12, end: -0.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_shakeController);
  }

  void _startShakeAnimation() async {
    // 0.2초 대기 후 시작 (더 빠르게)
    await Future.delayed(const Duration(milliseconds: 200));

    // 반복적으로 덜컹덜컹
    while (mounted) {
      await _shakeController.forward();
      _shakeController.reset();
      // 1초 대기 후 다시 애니메이션 (더 빠르게 반복)
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        AppLocalizations.of(context)!.gameComplete,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.gameCompleteMessage,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            // 선물 박스 이미지 (덜컹덜컹 애니메이션)
            Center(
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * 15, 0),
                    child: Transform.rotate(
                      angle: _shakeAnimation.value * 0.5,
                      child: GestureDetector(
                        onTap: widget.onOpenGiftBox,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: const Color(0xFFFFD700), // 골드 색상
                              width: 3,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 0),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onOpenGiftBox,
                              borderRadius: BorderRadius.circular(12),
                              splashColor:
                                  const Color(0xFFFFD700).withOpacity(0.3),
                              highlightColor:
                                  const Color(0xFFFFD700).withOpacity(0.1),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/capybara/collection/gift_box.webp',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.card_giftcard,
                                        color: Colors.grey,
                                        size: 50,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app,
                    color: Color(0xFFB8860B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.gameAllMatched,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB8860B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6F3FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${AppLocalizations.of(context)!.gameScore}: ${widget.score}${AppLocalizations.of(context)!.scoreUnit}',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                      '${AppLocalizations.of(context)!.moves}: ${widget.moves}${AppLocalizations.of(context)!.movesUnit}',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                      '${AppLocalizations.of(context)!.gameTime}: ${GameHelpers.formatTime(widget.remainingTime)}',
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: const [],
    );
  }
}

/// 배너 광고 컨테이너 (한 번만 생성되어 재사용됨)
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
    // 위젯이 생성된 후 배너 광고 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _adMobHandler.loadBannerAd(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 40, // 하단 마진 40px
      ),
      child: _adMobHandler.getBannerAd(),
    );
  }
}

/// 뽑기권 획득 다이얼로그 (게임 완료 시)
class _TicketRewardDialog extends StatefulWidget {
  final int score;
  final int moves;
  final int remainingTime;
  final GameDifficulty difficulty;
  final bool canEarnTicket;
  final int remainingTickets;
  final int currentTicketCount;
  final VoidCallback onClaimTicket;
  final VoidCallback onHome;
  final VoidCallback onReplay;

  const _TicketRewardDialog({
    required this.score,
    required this.moves,
    required this.remainingTime,
    required this.difficulty,
    required this.canEarnTicket,
    required this.remainingTickets,
    required this.currentTicketCount,
    required this.onClaimTicket,
    required this.onHome,
    required this.onReplay,
  });

  @override
  State<_TicketRewardDialog> createState() => _TicketRewardDialogState();
}

class _TicketRewardDialogState extends State<_TicketRewardDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _setupShakeAnimation();
    _startShakeAnimation();
  }

  void _setupShakeAnimation() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.1, end: 0.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_shakeController);
  }

  void _startShakeAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));

    while (mounted) {
      await _shakeController.forward();
      _shakeController.reset();
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F4F8), Color(0xFFD6EBF5)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF4A90E2), width: 3),
        ),
        child: SingleChildScrollView(
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
              const SizedBox(height: 20),

              // 점수 정보
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    _buildScoreRow(
                      isKorean ? '점수' : 'Score',
                      '${widget.score}${isKorean ? '점' : ' pts'}',
                    ),
                    const SizedBox(height: 8),
                    _buildScoreRow(
                      isKorean ? '이동 횟수' : 'Moves',
                      '${widget.moves}${isKorean ? '회' : ''}',
                    ),
                    const SizedBox(height: 8),
                    _buildScoreRow(
                      isKorean ? '남은 시간' : 'Time Left',
                      GameHelpers.formatTime(widget.remainingTime),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 뽑기권 획득 영역
              if (widget.canEarnTicket) ...[
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value * 10, 0),
                      child: Transform.rotate(
                        angle: _shakeAnimation.value * 0.3,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFFFFD699), width: 2),
                    ),
                    child: Column(
                      children: [
                        // 뽑기권 이미지
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/gacha_coin.webp',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.grey[600]!, width: 2),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.confirmation_number,
                                        size: 36,
                                        color: Colors.white,
                                      ),
                                      Text(
                                        '뽑기권',
                                        style: TextStyle(
                                          fontSize: 10,
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
                        const SizedBox(height: 16),
                        Text(
                          isKorean
                              ? '뽑기권 1개를 받을 수 있어요!'
                              : 'You can get 1 Gacha Ticket!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isKorean
                              ? '현재 보유: ${widget.currentTicketCount}개'
                              : 'Current: ${widget.currentTicketCount}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          isKorean
                              ? '오늘 남은 획득 횟수: ${widget.remainingTickets}회'
                              : 'Remaining today: ${widget.remainingTickets}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onClaimTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
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
                        const Icon(Icons.confirmation_number, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          isKorean ? '뽑기권 받기' : 'Get Ticket',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.grey[600], size: 32),
                      const SizedBox(height: 8),
                      Text(
                        isKorean
                            ? '오늘 뽑기권을 모두 획득했습니다'
                            : 'You\'ve earned all tickets for today',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 홈/다시하기 버튼
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onHome,
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
                      onPressed: widget.onReplay,
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

  Widget _buildScoreRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A90E2),
          ),
        ),
      ],
    );
  }
}
