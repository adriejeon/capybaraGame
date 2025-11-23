import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import 'game_screen.dart';
import 'collection_screen.dart';
import '../widgets/sound_settings_dialog.dart';
import '../../ads/admob_handler.dart';
import '../../data/game_counter.dart';
import '../../state/locale_state.dart';
import '../../data/home_character_manager.dart';

/// 메인 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final AdmobHandler _adMobHandler = AdmobHandler();
  final HomeCharacterManager _homeCharacterManager = HomeCharacterManager();
  double? _lastBannerWidth;
  int _currentLevelIndex = 0; // 현재 선택된 레벨 인덱스 (0~4)
  AnimationController? _bounceController;
  Animation<double>? _bounceAnimation;
  int _currentMessageIndex = 0;
  Timer? _messageTimer; // 말풍선 변경 타이머
  String _lastCharacterId = ''; // 마지막 캐릭터 ID 추적

  // 레벨 목록
  final List<GameDifficulty> _levels = [
    GameDifficulty.level1,
    GameDifficulty.level2,
    GameDifficulty.level3,
    GameDifficulty.level4,
    GameDifficulty.level5,
  ];

  // 카피바라 메시지 목록 (한국어)
  final List<String> _messagesKo = [
    '안녕~ 오늘도 느긋하게!',
    '게임 한판 어때?',
    '천천히 즐겨봐~',
    '평화로운 하루야 🌿',
    '느긋함이 최고지!',
    '편안하게 놀자~',
    '여유를 가져봐!',
    '힐링 타임이야 ✨',
    '함께 놀아줘서 고마워~',
    '오늘은 어떤 카드를?',
  ];

  // 카피바라 메시지 목록 (영어)
  final List<String> _messagesEn = [
    'Hi~ Take it easy!',
    'How about a game?',
    'Enjoy at your pace~',
    'Peaceful day 🌿',
    'Chill is the best!',
    'Let\'s relax~',
    'Take it slow!',
    'Healing time ✨',
    'Thanks for playing~',
    'Which card today?',
  ];

  @override
  void initState() {
    super.initState();
    // WidgetsBindingObserver 등록
    WidgetsBinding.instance.addObserver(this);

    // 현재 캐릭터 ID 저장
    _lastCharacterId = _homeCharacterManager.currentCharacterId;

    // 전면 광고 미리 로드 (즉시 로드)
    Future.delayed(const Duration(milliseconds: 0), () async {
      await _adMobHandler.loadInterstitialAd();
      print('홈 화면 - 전면 광고 로드 시작');
    });
    // 배너 광고 상태 변경 콜백 설정
    _adMobHandler.setBannerCallback(() {
      if (mounted) {
        setState(() {});
      }
    });

    // 바운스 애니메이션 초기화 (더 크고 부드러운 움직임)
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _bounceController!,
      curve: Curves.easeInOut,
    ));

    // 애니메이션 시작
    _bounceController!.repeat(reverse: true);

    // 메시지 자동 변경 타이머 시작 (10초마다)
    _startMessageTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bounceController?.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 활성화되면 캐릭터 갱신 확인
    if (state == AppLifecycleState.resumed) {
      _checkCharacterUpdate();
    }
  }

  /// 캐릭터가 변경되었는지 확인하고 UI 갱신
  Future<void> _checkCharacterUpdate() async {
    await _homeCharacterManager.initialize();

    if (mounted &&
        _lastCharacterId != _homeCharacterManager.currentCharacterId) {
      _lastCharacterId = _homeCharacterManager.currentCharacterId;
      _changeMessageRandom();
      setState(() {});
    }
  }

  /// 말풍선 메시지 변경 타이머 시작
  void _startMessageTimer() {
    _messageTimer?.cancel();
    _messageTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) %
              (Localizations.localeOf(context).languageCode == 'ko'
                  ? _messagesKo.length
                  : _messagesEn.length);
        });
      }
    });
  }

  /// 말풍선 메시지 랜덤으로 변경 (캐릭터 교체 시)
  void _changeMessageRandom() {
    if (mounted) {
      final random = Random();
      final messages = Localizations.localeOf(context).languageCode == 'ko'
          ? _messagesKo
          : _messagesEn;
      setState(() {
        _currentMessageIndex = random.nextInt(messages.length);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentWidth = MediaQuery.of(context).size.width;
    if (_lastBannerWidth == null ||
        (currentWidth - _lastBannerWidth!).abs() > 0.5) {
      _lastBannerWidth = currentWidth;
      unawaited(_adMobHandler.loadBannerAd(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/main.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter, // 이미지를 하단에 맞춤
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 상단 버튼 영역 (컬렉션 + 설정)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center, // 세로 중앙 정렬
                  children: [
                    // 컬렉션 버튼 (왼쪽)
                    _buildCollectionIconButton(context),
                    // 설정 버튼 (오른쪽)
                    _buildSettingsButton(context),
                  ],
                ),
              ),
              // 나머지 콘텐츠
              Expanded(
                child: Stack(
                  children: [
                    // 배너 광고 (하단에서 40px 위)
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: _buildBannerAd(),
                    ),
                    // 메인 콘텐츠 - 레벨 선택 + 카피바라 캐릭터
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 20.0,
                          right: 20.0,
                          top: 20.0,
                          bottom: 20.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // 위쪽 여백
                            const SizedBox(height: 20),
                            // 레벨 선택 버튼
                            _buildLevelSelector(context),
                            // 간격
                            const Spacer(),
                            // 홈 카피바라 캐릭터
                            _buildHomeCharacter(context),
                            // 아래쪽 여백 (광고 위)
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 컬렉션 아이콘 버튼 생성 (상단 왼쪽)
  Widget _buildCollectionIconButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 화면 너비의 18% (최소 110px, 최대 170px) - 더 크게
    final buttonWidth = (screenWidth * 0.18).clamp(110.0, 170.0);
    // 화면 높이의 16% (최소 100px, 최대 150px) - 더 크게
    final buttonHeight = (screenHeight * 0.16).clamp(100.0, 150.0);

    return GestureDetector(
      onTap: () => _openCollection(context),
      child: Consumer<LocaleState>(
        builder: (context, localeState, child) {
          final isEnglish = localeState.currentLocale.languageCode == 'en';
          final imagePath = isEnglish
              ? 'assets/images/button-collection-en.png'
              : 'assets/images/button-collection.png';

          // 이미지 크기에 맞게만 공간 차지하도록 제한
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: buttonWidth,
              maxHeight: buttonHeight,
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain, // contain으로 변경하여 잘림 방지
              errorBuilder: (context, error, stackTrace) {
                // 이미지 로드 실패 시 기본 컬렉션 아이콘 표시
                return Container(
                  width: buttonWidth,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFF9800),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.collections,
                    color: const Color(0xFFFF9800),
                    size: buttonWidth * 0.37,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// 설정 버튼 생성
  Widget _buildSettingsButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 화면 너비의 17% (최소 67px, 최대 100px)
    final buttonWidth = (screenWidth * 0.17).clamp(67.0, 100.0);
    // 화면 높이의 8% (최소 61px, 최대 90px)
    final buttonHeight = (screenHeight * 0.08).clamp(61.0, 90.0);

    return GestureDetector(
      onTap: () => _showSoundSettings(context),
      child: Image.asset(
        'assets/images/button-setting.png',
        width: buttonWidth,
        height: buttonHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 이미지 로드 실패 시 기본 설정 아이콘 표시
          return Container(
            width: buttonWidth,
            height: buttonHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF4A90E2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.settings,
              color: const Color(0xFF4A90E2),
              size: buttonWidth * 0.36,
            ),
          );
        },
      ),
    );
  }

  /// 레벨 선택 위젯 (중앙 버튼 + 양옆 arrow)
  Widget _buildLevelSelector(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 화살표 버튼: 화면 너비의 12% (최소 50px, 최대 80px)
    final arrowSize = (screenWidth * 0.12).clamp(50.0, 80.0);
    // 상단 버튼과 동일한 마진: 화면 너비의 2%
    final sidePadding = (screenWidth * 0.02).clamp(12.0, 20.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sidePadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 왼쪽 arrow (왼쪽 끝에 배치)
          _buildArrowButton(
            isBack: true,
            enabled: _currentLevelIndex > 0,
            size: arrowSize,
            onTap: () {
              if (_currentLevelIndex > 0) {
                setState(() {
                  _currentLevelIndex--;
                });
              }
            },
          ),

          // 중앙 레벨 버튼 (유연한 크기)
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 사용 가능한 너비 계산 (전체 너비 - 화살표 버튼 2개 - 간격)
                final spacing = screenWidth * 0.02; // 화면 너비의 2% 간격
                final availableWidth =
                    constraints.maxWidth - (arrowSize * 2) - spacing;
                // 사용 가능한 공간의 95% 사용, 화면 너비의 50-60% 범위로 줄임
                final buttonWidth = (availableWidth * 0.95)
                    .clamp(screenWidth * 0.50, screenWidth * 0.60);
                // 높이는 너비의 34% 또는 화면 높이의 12-18%로 줄임
                final buttonHeight = (buttonWidth * 0.34)
                    .clamp(screenHeight * 0.12, screenHeight * 0.18);

                return _buildLevelButton(
                  context,
                  _levels[_currentLevelIndex],
                  buttonWidth,
                  buttonHeight,
                );
              },
            ),
          ),

          // 오른쪽 arrow (오른쪽 끝에 배치)
          _buildArrowButton(
            isBack: false,
            enabled: _currentLevelIndex < _levels.length - 1,
            size: arrowSize,
            onTap: () {
              if (_currentLevelIndex < _levels.length - 1) {
                setState(() {
                  _currentLevelIndex++;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  /// Arrow 버튼 생성
  Widget _buildArrowButton({
    required bool isBack,
    required bool enabled,
    required double size,
    required VoidCallback onTap,
  }) {
    // 이미지 경로 결정
    final imagePath = isBack
        ? (enabled
            ? 'assets/images/arrow-back-active.png'
            : 'assets/images/arrow-back-disabled.png')
        : (enabled
            ? 'assets/images/arrow-front-active.png'
            : 'assets/images/arrow-front-disabled.png');

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // 이미지 로드 실패 시 기본 아이콘 표시
              return Container(
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.white.withOpacity(0.9)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBack ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
                  color: enabled ? const Color(0xFF4A90E2) : Colors.grey,
                  size: size * 0.5,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 레벨 버튼 생성
  Widget _buildLevelButton(
    BuildContext context,
    GameDifficulty difficulty,
    double width,
    double height,
  ) {
    return Consumer<LocaleState>(
      builder: (context, localeState, child) {
        final isEnglish = localeState.currentLocale.languageCode == 'en';

        // 레벨에 따른 이미지 경로
        String imagePath;
        switch (difficulty) {
          case GameDifficulty.level1:
            imagePath = 'assets/images/button-level1.png';
            break;
          case GameDifficulty.level2:
            imagePath = 'assets/images/button-level2.png';
            break;
          case GameDifficulty.level3:
            imagePath = 'assets/images/button-level3.png';
            break;
          case GameDifficulty.level4:
            imagePath = 'assets/images/button-level4.png';
            break;
          case GameDifficulty.level5:
            imagePath = 'assets/images/button-level5.png';
            break;
        }

        // 영어 모드일 때 -en 접미사 추가
        if (isEnglish) {
          final dotIndex = imagePath.lastIndexOf('.');
          if (dotIndex != -1) {
            imagePath =
                '${imagePath.substring(0, dotIndex)}-en${imagePath.substring(dotIndex)}';
          }
        }

        return GestureDetector(
          onTap: () => _startGame(context, difficulty),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) {
                  // 영어 이미지가 없으면 기본 이미지 사용
                  if (isEnglish) {
                    final koreanPath = imagePath.replaceAll('-en', '');
                    return Image.asset(
                      koreanPath,
                      fit: BoxFit.contain,
                      width: width,
                      height: height,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 40,
                          ),
                        );
                      },
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 게임 시작
  void _startGame(BuildContext context, GameDifficulty difficulty) async {
    // 게임 횟수 증가
    await GameCounter.incrementGameCount();

    print('홈 화면에서 게임 시작 - 광고 없이 바로 시작');
    // 홈 화면에서 게임 시작 시에는 광고 없이 바로 시작
    _navigateToGame(context, difficulty);
  }

  /// 게임 화면으로 이동
  void _navigateToGame(BuildContext context, GameDifficulty difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(difficulty: difficulty),
      ),
    );
  }

  /// 컬렉션 화면 열기
  void _openCollection(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CollectionScreen(),
      ),
    );

    // 컬렉션 화면에서 돌아온 후 캐릭터 갱신 확인
    await _checkCharacterUpdate();
  }

  /// 홈 카피바라 캐릭터 위젯
  Widget _buildHomeCharacter(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    // 캐릭터 크기: 화면 높이의 20-25% 정도 (적당한 크기)
    final characterHeight = (screenHeight * 0.22).clamp(150.0, 250.0);
    final characterWidth = (screenWidth * 0.5).clamp(180.0, 300.0);

    return GestureDetector(
      onTap: () => _openCollection(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 말풍선
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Stack(
              key: ValueKey<int>(_currentMessageIndex),
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 말풍선 메인 박스
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF9E6),
                        Color(0xFFFFF3D4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xFFFFD699),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '💭',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          isKorean
                              ? _messagesKo[_currentMessageIndex]
                              : _messagesEn[_currentMessageIndex],
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF6B5D4F),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // 말풍선 꼬리 (아래쪽 중앙)
                Positioned(
                  bottom: -2,
                  child: CustomPaint(
                    size: const Size(24, 12),
                    painter: _SpeechBubbleTailPainter(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 카피바라 이미지 (바운스 애니메이션 - 항상 적용)
          AnimatedBuilder(
            animation: _bounceAnimation ?? const AlwaysStoppedAnimation(0),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _bounceAnimation?.value ?? 0),
                child: child,
              );
            },
            child: Container(
              constraints: BoxConstraints(
                maxHeight: characterHeight,
                maxWidth: characterWidth,
              ),
              child: Image.asset(
                _homeCharacterManager.currentCharacterImagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // 이미지 로드 실패 시 기본 이미지 표시
                  return Image.asset(
                    'assets/home_capybara/easy1.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.pets,
                          size: 80,
                          color: Colors.grey,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 안내 텍스트 (작게)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF4A90E2).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              isKorean ? '탭해서 캐릭터 변경' : 'Tap to change',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4A90E2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 사운드 설정 다이얼로그 표시
  void _showSoundSettings(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SoundSettingsDialog(),
    );
  }

  /// 배너 광고 위젯 빌드 (안전하게)
  Widget _buildBannerAd() {
    // Key를 사용하여 위젯 인스턴스를 고유하게 유지
    return KeyedSubtree(
      key: const ValueKey('home_banner_ad'),
      child: _adMobHandler.getBannerAd(),
    );
  }
}

/// 말풍선 꼬리를 그리는 CustomPainter
class _SpeechBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFF3D4)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFFFD699)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();

    // 말풍선 꼬리 삼각형 그리기 (위쪽이 넓고 아래로 뾰족)
    path.moveTo(size.width / 2 - 10, 0); // 왼쪽 위
    path.lineTo(size.width / 2, size.height); // 아래 끝 (뾰족한 부분)
    path.lineTo(size.width / 2 + 10, 0); // 오른쪽 위
    path.close();

    // 그림자 효과
    canvas.drawShadow(path, Colors.black.withOpacity(0.1), 3.0, false);

    // 꼬리 채우기
    canvas.drawPath(path, paint);

    // 꼬리 테두리
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
