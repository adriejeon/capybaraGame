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
import '../../ads/admob_handler.dart';
import 'collection_screen.dart';
import '../../services/share_service.dart';
import '../../services/coin_manager.dart';

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
  bool _hasReceivedReward = false; // 보상형 광고에서 보상을 받았는지 추적
  CollectionResult? _currentRewardResult; // 현재 뽑은 카피바라 결과 저장
  int _currentCoinReward = 0; // 현재 게임에서 받은 코인 보상

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGame();
    _setupAnimations();
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

  /// 선물 박스 다이얼로그 표시
  void _showGiftBoxDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
                    Text('${AppLocalizations.of(context)!.gameScore}: $_score${AppLocalizations.of(context)!.scoreUnit}',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${AppLocalizations.of(context)!.moves}: $_moves${AppLocalizations.of(context)!.movesUnit}',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                        '${AppLocalizations.of(context)!.gameTime}: ${GameHelpers.formatTime(_remainingTime)}',
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
                    Text('${AppLocalizations.of(context)!.score}: $_score${AppLocalizations.of(context)!.scoreUnit}',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${AppLocalizations.of(context)!.moves}: $_moves${AppLocalizations.of(context)!.movesUnit}',
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
    // 코인 보상 지급 (레벨에 따라 다른 금액)
    int coinReward = 0;
    switch (widget.difficulty) {
      case GameDifficulty.level1:
        coinReward = 10;
        break;
      case GameDifficulty.level2:
        coinReward = 20;
        break;
      case GameDifficulty.level3:
        coinReward = 30;
        break;
      case GameDifficulty.level4:
        coinReward = 40;
        break;
      case GameDifficulty.level5:
        coinReward = 50;
        break;
    }
    await CoinManager.addCoins(coinReward);
    _currentCoinReward = coinReward; // 코인 보상 저장
    
    // 컬렉션에 새 카드 추가
    await _collectionManager.initializeCollection();
    final result = await _collectionManager.addNewCard(widget.difficulty);
    
    // 현재 뽑은 결과 저장 (다시 뽑기 기능용)
    _currentRewardResult = result;

    // 카드 뽑기 다이얼로그 표시
    _showCardDrawDialog(result, coinReward);
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
    showDialog(
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
              // 코인 보상 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFFA500),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/coin.png',
                      width: 30,
                      height: 30,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.monetization_on,
                          color: Colors.white,
                          size: 30,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+$coinReward',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
          // 카피바라 다시 뽑기 버튼 (항상 표시)
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // 다이얼로그 닫기
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
                'assets/images/gameover.png',
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

    // 보상 받음 플래그 초기화
    _hasReceivedReward = false;
    final previousCardId = _currentRewardResult!.card!.id;
    // 이전 결과를 백업 (보상을 받지 않았을 때 복원하기 위해)
    final previousResult = _currentRewardResult;

    // 보상형 광고가 준비되지 않았으면 로드
    if (!_adMobHandler.isRewardedAdLoaded) {
      await _adMobHandler.loadRewardedAd();
    }

    // 보상형 광고 표시
    await _adMobHandler.showRewardedAd(
      onRewarded: (reward) {
        print('보상 획득: ${reward.type}, ${reward.amount}');
        _hasReceivedReward = true;
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
          _buildInfoItem(AppLocalizations.of(context)!.time,
              GameHelpers.formatTime(_remainingTime), Icons.timer),
          _buildInfoItem(
              AppLocalizations.of(context)!.score, '$_score', Icons.star),
          _buildInfoItem(
              AppLocalizations.of(context)!.moves, '$_moves', Icons.touch_app),
          _buildInfoItem(AppLocalizations.of(context)!.combo, '$_comboCount',
              Icons.local_fire_department),
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
    if (widget.difficulty == GameDifficulty.level1) {
      // 레벨 1: 화면에 맞게 카드 크기 조정 및 중앙 정렬
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
