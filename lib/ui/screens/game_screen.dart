import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../game/models/card.dart';
import '../../game/models/card_factory.dart';
import '../widgets/game_card_widget.dart';

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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameBoard _gameBoard;
  late AnimationController _flipAnimationController;

  Timer? _gameTimer;
  Timer? _hintTimer;
  int _remainingTime = 0;
  int _score = 0;
  int _moves = 0;
  int _comboCount = 0;

  final List<GameCard> _selectedCards = [];
  bool _isProcessing = false;
  GameState _gameState = GameState.playing;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _setupAnimations();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _hintTimer?.cancel();
    _flipAnimationController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    // 게임 보드 생성
    _gameBoard = CapybaraCardFactory.createGameBoard(widget.difficulty);

    // 타이머 설정
    _remainingTime = GameHelpers.getTimeLimit(widget.difficulty);
    _startTimer();
    _startHintTimer();

    // 초기값 설정
    _score = 0;
    _moves = 0;
    _comboCount = 0;
    _selectedCards.clear();
    _gameState = GameState.playing;
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

  void _startHintTimer() {
    // 쉬움 난이도에서는 힌트 제공하지 않음
    if (widget.difficulty == GameDifficulty.easy) return;

    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_gameState == GameState.playing && !_isProcessing) {
        _showHint();
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
      }
    });
  }

  void _onCardTapped(GameCard card) {
    if (_isProcessing ||
        card.isMatched ||
        card.isFlipped ||
        _selectedCards.length >= 2 ||
        _gameState != GameState.playing) {
      return;
    }

    setState(() {
      card.flip();
      _selectedCards.add(card);
      _moves++;
    });

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

    setState(() {
      _gameState = isWin ? GameState.gameOver : GameState.gameOver;
    });

    if (isWin) {
      // 시간 보너스 추가
      _score += _remainingTime * GameConstants.timeBonus;
    }

    // 결과 다이얼로그 표시
    _showGameResultDialog(isWin);
  }

  void _showGameResultDialog(bool isWin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // 하얀색 배경
        title: Text(
          isWin ? '축하합니다!' : '시간 종료',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width:
              MediaQuery.of(context).size.width * 0.8, // 다이얼로그 너비를 화면의 80%로 설정
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // 전체 컨텐츠 좌측 정렬
            children: [
              Text(
                isWin ? '모든 카드를 맞추셨습니다!' : '다시 도전해보세요!',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity, // 다이얼로그에 꽉 차게
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA), // 연한 회색
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6F3FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 좌측 정렬
                  children: [
                    Text('점수: $_score점', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('이동 횟수: $_moves번',
                        style: const TextStyle(fontSize: 16)),
                    if (isWin) ...[
                      const SizedBox(height: 8),
                      Text('남은 시간: ${GameHelpers.formatTime(_remainingTime)}',
                          style: const TextStyle(fontSize: 16)),
                    ],
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
                    foregroundColor: const Color(0xFF4A90E2), // 파란색 텍스트
                    padding:
                        const EdgeInsets.symmetric(vertical: 16), // 버튼 높이 증가
                  ),
                  child: const Text(
                    '홈으로',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold), // 텍스트 크기 증가
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _restartGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2), // 진한 파란색 배경
                    foregroundColor: Colors.white, // 흰색 텍스트
                    padding:
                        const EdgeInsets.symmetric(vertical: 16), // 버튼 높이 증가
                  ),
                  child: const Text(
                    '다시 하기',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold), // 텍스트 크기 증가
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
    setState(() {
      _initializeGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF), // 연한 파스텔 하늘색
      appBar: AppBar(
        title: Text('카피바라 짝 맞추기 - ${_getDifficultyText()}'),
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
      color: const Color(0xFFE6F3FF), // 연한 파스텔 하늘색
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

          // 최소/최대 카드 크기 제한
          final minCardSize = 60.0;
          final maxCardSize = 120.0;
          final finalCardSize = cardSize.clamp(minCardSize, maxCardSize);

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

        // 최소/최대 카드 크기 제한
        final minCardSize = 40.0;
        final maxCardSize = 100.0;
        final finalCardSize = cardSize.clamp(minCardSize, maxCardSize);

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
        return '쉬움';
      case GameDifficulty.medium:
        return '보통';
      case GameDifficulty.hard:
        return '어려움';
    }
  }
}
