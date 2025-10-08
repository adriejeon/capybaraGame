import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../game/models/card.dart';
import '../../game/models/card_factory.dart';
import '../widgets/game_card_widget.dart';
import '../../sound_manager.dart';
import '../../data/collection_manager.dart';
import '../../data/game_counter.dart';
import '../../ads/admob_handler.dart';
import 'collection_screen.dart';

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

  Timer? _gameTimer;
  Timer? _hintTimer;
  Timer? _idleTimer; // 사용자 비활성 상태 체크용 타이머
  int _remainingTime = 0;
  int _score = 0;
  int _moves = 0;
  int _comboCount = 0;

  final List<GameCard> _selectedCards = [];
  bool _isProcessing = false;
  GameState _gameState = GameState.playing;
  bool _isShowingHint = false; // 카드 힌트 표시 중인지 확인

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGame();
    _setupAnimations();
    // 전면 광고 미리 로드 (약간의 지연 후)
    Future.delayed(const Duration(milliseconds: 1000), () {
      AdMobHandler().loadInterstitialAd();
      print('게임 화면 - 전면 광고 로드 시작');
    });
    // 캐릭터 수령용 전면 광고 미리 로드
    AdMobHandler().loadRewardInterstitialAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameTimer?.cancel();
    _hintTimer?.cancel();
    _idleTimer?.cancel();
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

  /// 사용자 비활성 상태 체크 타이머 시작
  void _startIdleTimer() {
    // 쉬움 난이도에서는 힌트 제공하지 않음
    if (widget.difficulty == GameDifficulty.easy) return;

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
    setState(() {
      _isShowingHint = true;
      // 모든 카드를 앞면으로 뒤집기
      for (final card in _gameBoard.cards) {
        card.flip();
      }
    });

    // 3초 후 모든 카드를 뒷면으로 뒤집기
    Timer(const Duration(milliseconds: 3000), () {
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

  void _endGame(bool isWin) {
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

      // 선물 박스 다이얼로그 표시 (카드는 아직 추가하지 않음)
      _showGiftBoxDialog();
    } else {
      // 결과 다이얼로그 표시
      _showGameResultDialog(isWin, null);
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

  /// 선물 박스 다이얼로그 표시
  void _showGiftBoxDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '축하합니다!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '모든 카드를 맞추셨습니다!',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              // 선물 박스 이미지
              Center(
                child: GestureDetector(
                  onTap: () => _openGiftBox(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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
                        onTap: () => _openGiftBox(context),
                        borderRadius: BorderRadius.circular(12),
                        splashColor: const Color(0xFFFFD700).withOpacity(0.3),
                        highlightColor:
                            const Color(0xFFFFD700).withOpacity(0.1),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/capybara/collection/gift_box.jpg',
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD700), width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Color(0xFFB8860B),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '눌러서 카피바라 뽑기!',
                        style: TextStyle(
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
                    Text('점수: $_score점', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('이동 횟수: $_moves번',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('남은 시간: ${GameHelpers.formatTime(_remainingTime)}',
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
                  child: const Text(
                    '홈으로',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  child: const Text(
                    '다시 하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
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
        title: const Text(
          '시간 종료',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '다시 도전해보세요!',
                style: TextStyle(fontSize: 18),
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
                    Text('점수: $_score점', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('이동 횟수: $_moves번',
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
                  child: const Text(
                    '홈으로',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  child: const Text(
                    '다시 하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    AdMobHandler().showRewardInterstitialAd(
      onAdClosed: () {
        // 광고가 닫힌 후 캐릭터 받기
        _giveCharacterReward();
      },
    );
  }

  /// 캐릭터 보상 지급
  void _giveCharacterReward() async {
    // 컬렉션에 새 카드 추가
    await _collectionManager.initializeCollection();
    final result = await _collectionManager.addNewCard(widget.difficulty);

    // 카드 뽑기 다이얼로그 표시
    _showCardDrawDialog(result);
  }

  /// 카드 뽑기 다이얼로그 표시 (애니메이션 포함)
  void _showCardDrawDialog(CollectionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CardDrawDialog(
        result: result,
        onComplete: () {
          Navigator.of(context).pop(); // 카드 뽑기 다이얼로그 닫기
          _showFinalResultDialog(result); // 최종 결과 다이얼로그 표시
        },
      ),
    );
  }

  /// 최종 결과 다이얼로그 표시
  void _showFinalResultDialog(CollectionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          result.isNewCard ? '새로운 카피바라!' : '카피바라 카드',
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
                        result.message,
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
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const CollectionScreen(),
                    ),
                    (route) => route.isFirst, // 첫 번째 페이지(메인)까지만 유지
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '컬렉션 확인하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
                  child: const Text(
                    '홈으로',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  child: const Text(
                    '다시 하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _restartGame() async {
    // 게임 횟수 증가
    await GameCounter.incrementGameCount();

    // 현재 게임 횟수와 광고 표시 여부 확인
    final gameCount = await GameCounter.getTodayGameCount();
    final shouldShowAd = await GameCounter.shouldShowAd();
    print('게임 재시작 - 현재 횟수: $gameCount, 광고 표시: $shouldShowAd');

    if (shouldShowAd) {
      print('전면 광고 표시 시작 (재시작)');
      // 광고가 준비되지 않았으면 강제로 로드
      if (!AdMobHandler().isInterstitialAdReady) {
        print('광고 준비 안됨 - 강제 로드 시작 (재시작)');
        AdMobHandler().loadInterstitialAd();
        // 2초 후 다시 시도
        Future.delayed(const Duration(seconds: 2), () {
          AdMobHandler().showInterstitialAd(
            onAdClosed: () {
              print('전면 광고 닫힘 - 게임 재시작');
              _restartGameDirectly();
            },
          );
        });
      } else {
        // 광고 표시 후 게임 재시작
        AdMobHandler().showInterstitialAd(
          onAdClosed: () {
            print('전면 광고 닫힘 - 게임 재시작');
            // 광고가 닫힌 후 게임 재시작
            _restartGameDirectly();
          },
        );
      }
    } else {
      print('광고 없이 게임 재시작');
      // 광고 없이 바로 게임 재시작
      _restartGameDirectly();
    }
  }

  /// 게임 직접 재시작 (광고 로직 없이)
  void _restartGameDirectly() {
    setState(() {
      _initializeGame();
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

          // 게임 보드 (스크롤 가능)
          Expanded(
            child: _buildGameBoard(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfoBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _isShowingHint
          ? const Color(0xFFFFF8E1) // 힌트 표시 중일 때는 주황색
          : const Color(0xFFE6F3FF), // 연한 파스텔 하늘색
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
              '시간', GameHelpers.formatTime(_remainingTime), Icons.timer),
          _buildInfoItem('점수', '$_score', Icons.star),
          _buildInfoItem('이동', '$_moves', Icons.touch_app),
          _buildInfoItem('콤보', '$_comboCount', Icons.local_fire_department),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4A90E2), size: 20), // 파스텔 하늘색
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4A90E2),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF2C5F8B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGameBoard() {
    if (widget.difficulty == GameDifficulty.easy) {
      // 쉬움 난이도: 화면에 맞게 카드 크기 조정 및 중앙 정렬
      return LayoutBuilder(
        builder: (context, constraints) {
          // 화면 크기에 맞게 카드 크기 계산
          final availableWidth = constraints.maxWidth - 32; // 좌우 패딩 제외
          final availableHeight = constraints.maxHeight - 80; // 하단 마진 80px 확보

          // 2x4 그리드에 맞게 카드 크기 계산 (2개씩 4줄)
          final cardWidth = (availableWidth - 8) / 2; // 8px 간격, 2개 카드
          final cardHeight = (availableHeight - 24) / 4; // 24px 간격, 4개 카드
          final cardSize = cardWidth < cardHeight ? cardWidth : cardHeight;

          // 카드 크기를 조정 (0.9배)
          final finalCardSize = cardSize * 0.9;

          return Center(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 80, // 하단 마진 80px
              ),
              child: SizedBox(
                width: finalCardSize * 2 + 8, // 카드 2개 + 간격 8px
                height: finalCardSize * 4 + 24, // 카드 4개 + 간격 24px
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
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
          );
        },
      );
    }

    // 보통/어려움 난이도: 화면에 맞게 카드 크기 조정
    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 크기에 맞게 카드 크기 계산
        final availableWidth = constraints.maxWidth - 32; // 좌우 패딩 제외
        final availableHeight = constraints.maxHeight - 80; // 하단 마진 80px 확보

        // 그리드 크기에 맞게 카드 크기 계산
        final cardWidth = (availableWidth - ((_gameBoard.gridWidth - 1) * 8)) /
            _gameBoard.gridWidth;
        final cardHeight =
            (availableHeight - ((_gameBoard.gridHeight - 1) * 8)) /
                _gameBoard.gridHeight;
        final cardSize = cardWidth < cardHeight ? cardWidth : cardHeight;

        // 카드 크기를 조정 (0.9배)
        final finalCardSize = cardSize * 0.9;

        return Center(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80, // 하단 마진 80px
            ),
            child: SizedBox(
              width: finalCardSize * _gameBoard.gridWidth +
                  ((_gameBoard.gridWidth - 1) * 8),
              height: finalCardSize * _gameBoard.gridHeight +
                  ((_gameBoard.gridHeight - 1) * 8),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gameBoard.gridWidth,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
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
        );
      },
    );
  }

  String _getDifficultyText() {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return '쉬워요!';
      case GameDifficulty.medium:
        return '할만해요!';
      case GameDifficulty.hard:
        return '어려워요..';
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
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  bool _showCard = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimation();
  }

  void _setupAnimations() {
    // 스케일 애니메이션 (선물 박스 -> 카드)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // 회전 애니메이션
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    // 페이드 애니메이션
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    // 1. 선물 박스 스케일 애니메이션
    await _scaleController.forward();

    // 2. 회전 애니메이션과 함께 카드로 변환
    _rotationController.forward();

    // 0.5초 후 카드 표시
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _showCard = true;
    });

    // 3. 카드 페이드 인
    await _fadeController.forward();

    // 2초 후 완료 콜백 호출
    await Future.delayed(const Duration(milliseconds: 2000));
    widget.onComplete();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
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
            const Text(
              '카드를 뽑는 중...',
              style: TextStyle(
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
                  _fadeController,
                ]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * 3.14159,
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
                                  'assets/capybara/collection/gift_box.jpg',
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
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            if (_showCard) ...[
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.result.isNewCard ? '새로운 카피바라!' : '이미 가지고 있는 카피바라',
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
