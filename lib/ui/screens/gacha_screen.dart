import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../data/ticket_manager.dart';
import '../../data/collection_manager.dart';
import '../../utils/constants.dart';
import '../../sound_manager.dart';
import '../../services/daily_mission_service.dart';

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
  GameDifficulty _selectedDifficulty = GameDifficulty.level1;

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

    // 3. 뽑기통 흔들림 애니메이션 (반복)
    for (int i = 0; i < 15; i++) {
      await _shakeController.forward();
      await _shakeController.reverse();
    }

    // 4. 캐릭터 뽑기
    final result = await _collectionManager.addNewCard(_selectedDifficulty);
    
    // 데일리 미션 업데이트
    await _missionService.collectCharacter();

    // 5. 결과 표시
    setState(() {
      _gachaResult = result;
      _showResult = true;
    });

    _soundManager.playMatchSuccessSound();
    await _resultPopController.forward();

    // 6. 애니메이션 리셋
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
        return isKorean ? '아기 단계' : 'Baby';
      case GameDifficulty.level2:
        return isKorean ? '어린이 단계' : 'Child';
      case GameDifficulty.level3:
        return isKorean ? '청소년 단계' : 'Teen';
      case GameDifficulty.level4:
        return isKorean ? '어른 단계' : 'Adult';
      case GameDifficulty.level5:
        return isKorean ? '신의 경지' : 'Legend';
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

                // 난이도 선택
                _buildDifficultySelector(),

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
          // 뽑기권 아이콘 (임시 회색 박스)
          Container(
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

  Widget _buildDifficultySelector() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              isKorean ? '뽑기 등급 선택' : 'Select Grade',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: GameDifficulty.values.map((difficulty) {
                final isSelected = _selectedDifficulty == difficulty;
                return GestureDetector(
                  onTap: _isGachaing
                      ? null
                      : () {
                          setState(() {
                            _selectedDifficulty = difficulty;
                          });
                        },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4A90E2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF4A90E2),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _getDifficultyText(difficulty),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGachaMachine() {
    return Center(
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _isGachaing ? _shakeAnimation.value : 0.0,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 뽑기통 (임시 회색 박스)
            Container(
              width: 200,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey[600]!, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.all_inbox,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '뽑기통',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getDifficultyText(_selectedDifficulty),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
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
                      opacity: 1 - progress,
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
                ? const Color(0xFFFFB74D)
                : Colors.grey[400],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGachaing) ...[
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
              ] else ...[
                const Icon(Icons.celebration, size: 28),
                const SizedBox(width: 12),
                Text(
                  isKorean ? '뽑기! (1장)' : 'Draw! (1)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final result = _gachaResult!;

    return GestureDetector(
      onTap: _closeResult,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: ScaleTransition(
            scale: _resultPopAnimation,
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

                  // 등급 표시
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F3FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getDifficultyText(_selectedDifficulty),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 닫기 안내
                  Text(
                    isKorean ? '탭하여 닫기' : 'Tap to close',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
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
