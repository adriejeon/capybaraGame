import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../data/ticket_manager.dart';
import '../../data/collection_manager.dart';
import '../../utils/constants.dart';
import '../../sound_manager.dart';
import '../../services/daily_mission_service.dart';
import '../widgets/gacha_physics_widget.dart';
import '../../utils/gacha_glass_constants.dart';
import 'collection_screen.dart';

/// 뽑기통 화면
/// 뽑기권을 사용해서 캐릭터를 뽑을 수 있는 화면
class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  final TicketManager _ticketManager = TicketManager();
  final CollectionManager _collectionManager = CollectionManager();
  final SoundManager _soundManager = SoundManager();
  final DailyMissionService _missionService = DailyMissionService();

  int _currentTickets = 0;
  bool _isGachaing = false; // 뽑기 중 여부
  bool _showResult = false; // 결과 표시 여부
  CollectionResult? _gachaResult; // 뽑기 결과

  // 애니메이션 컨트롤러
  late AnimationController _shakeController;
  late AnimationController _ticketMoveController;
  late AnimationController _resultPopController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _ticketMoveAnimation;
  late Animation<double> _resultPopAnimation;

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupAnimations();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _ticketMoveController.dispose();
    _resultPopController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _ticketManager.initialize();
    await _collectionManager.initializeCollection();
    setState(() {
      _currentTickets = _ticketManager.ticketCount;
    });
  }

  void _setupAnimations() {
    // 뽑기통 흔들림 애니메이션
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    // 뽑기권 이동 애니메이션
    _ticketMoveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _ticketMoveAnimation = CurvedAnimation(
      parent: _ticketMoveController,
      curve: Curves.easeInBack,
    );

    // 결과 팝업 애니메이션
    _resultPopController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _resultPopAnimation = CurvedAnimation(
      parent: _resultPopController,
      curve: Curves.elasticOut,
    );
  }

  /// 뽑기 시작
  Future<void> _startGacha() async {
    if (_isGachaing) return;
    if (_currentTickets <= 0) {
      _showNoTicketDialog();
      return;
    }

    setState(() {
      _isGachaing = true;
      _showResult = false;
      _gachaResult = null;
    });

    // 1. 뽑기권 사용
    final used = await _ticketManager.useTicket();
    if (!used) {
      setState(() {
        _isGachaing = false;
      });
      return;
    }

    setState(() {
      _currentTickets = _ticketManager.ticketCount;
    });

    // 2. 뽑기권이 뽑기통으로 이동하는 애니메이션
    await _ticketMoveController.forward();

    // 3. 애니메이션과 동시에 캐릭터 뽑기 시작 (병렬 처리로 지연 최소화)
    final resultFuture = _collectionManager.addRandomCard();
    final missionFuture = _missionService.collectCharacter();

    // 4. 뽑기통 흔들림 애니메이션 (반복) + 진동
    for (int i = 0; i < 15; i++) {
      // 진동 효과 추가 (손맛 향상)
      HapticFeedback.lightImpact();
      await _shakeController.forward();
      await _shakeController.reverse();
    }

    // 5. DB 작업 완료 대기 (대부분 이미 완료됨)
    final result = await resultFuture;
    await missionFuture;

    // 6. 결과 표시
    setState(() {
      _gachaResult = result;
      _showResult = true;
    });

    _soundManager.playMatchSuccessSound();
    await _resultPopController.forward();

    // 7. 애니메이션 리셋
    _ticketMoveController.reset();

    setState(() {
      _isGachaing = false;
    });
  }

  void _showNoTicketDialog() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isKorean ? '뽑기권 부족' : 'No Tickets',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isKorean
              ? '뽑기권이 없습니다.\n게임을 완료하면 뽑기권을 얻을 수 있어요!'
              : 'You don\'t have any tickets.\nComplete a game to earn tickets!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              isKorean ? '확인' : 'OK',
              style: const TextStyle(color: Color(0xFF4A90E2)),
            ),
          ),
        ],
      ),
    );
  }

  void _closeResult() {
    setState(() {
      _showResult = false;
      _gachaResult = null;
    });
    _resultPopController.reset();
  }

  String _getDifficultyText(GameDifficulty difficulty) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    switch (difficulty) {
      case GameDifficulty.level1:
        return isKorean ? '아기바라' : 'Baby';
      case GameDifficulty.level2:
        return isKorean ? '어린이바라' : 'Child';
      case GameDifficulty.level3:
        return isKorean ? '청소년바라' : 'Teen';
      case GameDifficulty.level4:
        return isKorean ? '어른바라' : 'Adult';
      case GameDifficulty.level5:
        return isKorean ? '신이된바라' : 'Legend';
    }
  }

  Color _getRarityColor(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.level1:
        return const Color(0xFF8BC34A); // 초록색 (일반)
      case GameDifficulty.level2:
        return const Color(0xFF4A90E2); // 파란색 (레어)
      case GameDifficulty.level3:
        return const Color(0xFF9C27B0); // 보라색 (에픽)
      case GameDifficulty.level4:
        return const Color(0xFFFF9800); // 주황색 (레전더리)
      case GameDifficulty.level5:
        return const Color(0xFFE91E63); // 분홍색 (신화)
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Text(isKorean ? '뽑기통' : 'Gacha'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 뽑기권 보유량 표시
                _buildTicketDisplay(),

                // 뽑기통 영역
                Expanded(
                  child: _buildGachaMachine(),
                ),

                // 뽑기 버튼
                _buildGachaButton(),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // 결과 오버레이
          if (_showResult && _gachaResult != null) _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildTicketDisplay() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 뽑기권 이미지
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/gacha_coin.webp',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.confirmation_number,
                    color: Colors.white,
                    size: 24,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKorean ? '보유 뽑기권' : 'Tickets',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '$_currentTickets${isKorean ? '개' : ''}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGachaMachine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 가챠 기계 물리 시뮬레이션 위젯
            GachaPhysicsWidget(
              isAnimating: _isGachaing,
              shakeAnimation: _isGachaing ? _shakeAnimation : null,
              dollCount:
                  _currentTickets > 0 ? GachaGlassConstants.dollCount : 0,
            ),

            // 뽑기권 이동 애니메이션
            if (_isGachaing)
              AnimatedBuilder(
                animation: _ticketMoveAnimation,
                builder: (context, child) {
                  final progress = _ticketMoveAnimation.value;
                  return Transform.translate(
                    offset: Offset(
                      0,
                      -100 + (progress * 200), // 위에서 아래로 이동
                    ),
                    child: Opacity(
                      opacity: (1 - progress).clamp(0.0, 1.0),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[500],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.confirmation_number,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGachaButton() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isGachaing ? null : _startGacha,
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentTickets > 0
                ? const Color(0xFF4A90E2)
                : Colors.grey[400],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 5,
          ),
          child: _isGachaing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isKorean ? '뽑는 중...' : 'Drawing...',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Text(
                  isKorean ? '카피바라 뽑기' : 'Draw Capybara',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final result = _gachaResult!;

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: ScaleTransition(
          scale: _resultPopAnimation,
          child: GestureDetector(
            onTap: () {}, // 배경 탭으로 닫히지 않도록
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: result.isNewCard
                        ? const Color(0xFF4A90E2).withOpacity(0.4)
                        : const Color(0xFFF0AD4E).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 타이틀
                  Text(
                    result.isNewCard
                        ? (isKorean ? '새로운 캐릭터!' : 'New Character!')
                        : (isKorean ? '이미 있는 캐릭터' : 'Already Have'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: result.isNewCard
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFFF0AD4E),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 캐릭터 이미지
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: result.isNewCard
                            ? const Color(0xFF4A90E2)
                            : const Color(0xFFF0AD4E),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: result.card != null
                          ? Image.asset(
                              result.card!.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.pets,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.pets,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 등급 표시 (뽑힌 카드의 단계)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getRarityColor(
                          result.card?.difficulty ?? GameDifficulty.level1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getDifficultyText(
                          result.card?.difficulty ?? GameDifficulty.level1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 버튼들 (각각 50% 너비)
                  Row(
                    children: [
                      // 닫기 버튼 (왼쪽, 50%)
                      Expanded(
                        child: TextButton(
                          onPressed: _closeResult,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            isKorean ? '닫기' : 'Close',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 컬렉션 보러가기 버튼 (오른쪽, 50%)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            _closeResult();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CollectionScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            isKorean ? '컬렉션' : 'Collection',
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
        ),
      ),
    );
  }
}

