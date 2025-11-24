import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../utils/constants.dart';
import 'game_screen.dart';
import 'collection_screen.dart';
import '../widgets/sound_settings_dialog.dart';
import '../../ads/admob_handler.dart';
import '../../data/game_counter.dart';
import '../../state/locale_state.dart';
import '../../data/home_character_manager.dart';
import '../../services/coin_manager.dart';

/// 메인 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final AdmobHandler _adMobHandler = AdmobHandler();
  final HomeCharacterManager _homeCharacterManager = HomeCharacterManager();
  int _currentLevelIndex = 0; // 현재 선택된 레벨 인덱스 (0~4)
  AnimationController? _bounceController;
  Animation<double>? _bounceAnimation;
  int _currentMessageIndex = 0;
  Timer? _messageTimer; // 말풍선 변경 타이머
  String _lastCharacterId = ''; // 마지막 캐릭터 ID 추적
  bool _showingTapMessage = false; // 탭 메시지 표시 여부
  DateTime? _lastTapTime; // 마지막 탭 시간 (햅틱 중복 방지)
  Timer? _tapMessageResetTimer; // 탭 메시지 리셋 타이머
  int _currentCoins = 0; // 현재 코인

  // 실시간 추종 드래그 상태
  Offset _dragOffset = Offset.zero; // 현재 드래그 오프셋
  Offset? _dragStartPosition; // 드래그 시작 위치
  Offset? _lastDragPosition; // 이전 드래그 위치 (속도 계산용)
  DateTime? _lastDragTime; // 이전 드래그 시간 (속도 계산용)
  bool _isDragging = false; // 드래그 중인지 여부
  Timer? _returnTimer; // 원위치 복귀 타이머

  // 강도 기반 흔들림 상태
  Offset _shakeOffset = Offset.zero; // 흔들림 오프셋
  Timer? _shakeDecayTimer; // 흔들림 감쇠 타이머
  double _shakeIntensity = 0.0; // 현재 흔들림 강도

  static const List<int> _androidDunDunPattern = [
    0, // 즉시 시작
    90, // 첫 진동
    70, // 짧은 휴식
    160, // 두 번째 강한 진동
    90, // 다음 휴식
    200, // 마무리 롱 진동 (두둥)
  ];
  static const List<int> _androidDunDunIntensities = [
    0,
    200,
    0,
    255,
    0,
    220,
  ];

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
    '가만히 있으면 기분이 좋아져',
    '편안한 하루가 되길 바래',
    '틀려도 돼, 괜찮아~',
    '천천히 다시 해보자',
    '급할 거 없어. 우리에게 시간은 많아.',
    '너는 정말 대단해!',
    '너는 카드 짝 맞추기의 달인이야',
    '게임하다 잠들어도 괜찮아~',
    '내 짝꿍은 어디 숨었을까?',
    '우리 게임 은근 재밌다구~',
    '승부보다는 편안하게 즐기자~',
    '오늘도 고생했어.',
    '바쁜 날이었지? 나랑 같이 쉬자~',
    '힘들면 언제나 나한테 기대',
    '난 언제나 네 편이야.',
    '사랑해 사랑해',
    '오늘도 사랑해',
    '나랑 놀자',
    '오늘은 아무것도 안해도 괜찮은 날이야',
    '가끔은 멈춰 서도 돼~',
    '네가 있어서 행복해',
    '네가 와서 너무 행복해',
    '숨 한번 크게 쉬어볼까? 후~~',
    '나한테는 네가 가장 소중해',
    '행복은 가까이에 있대 🍀',
    '걱정은 잠시 내려놓자.',
    '네가 너무 보고싶었어.',
    '나랑 같이 놀자',
    '인생은 훌랄라~',
    '맛있는게 제일 좋아',
    '자도 자도 졸려',
    '기분이 어떄? 아임 파인 애플',
    '나를 잊지마',
    '나 잊으면 안돼',
    '절대 나 잊으면 안돼, 알겠지?',
    '네가 좋으면 나도 좋아 ^ㅇ^',
    '웃으면 복이 온대',
    '행복해서 웃는게 아니야, 웃어서 행복한거야.',
    '너를 항상 웃게 해주고 싶어',
    '너를 항상 행복하게 해줄게',
    '너는 내 전부야.'
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
    'Staying still makes you feel better',
    'Hope you have a peaceful day',
    'It\'s okay to make mistakes~',
    'Let\'s try again slowly',
    'No rush. We have plenty of time.',
    'You\'re amazing!',
    'You\'re a master at matching cards',
    'It\'s okay to fall asleep while playing~',
    'Where did my pair hide?',
    'Our game is surprisingly fun~',
    'Let\'s enjoy it comfortably rather than competing~',
    'You worked hard today.',
    'It was a busy day, right? Let\'s rest together~',
    'Lean on me whenever it\'s tough',
    'I\'m always on your side.',
    'I love you, I love you',
    'I love you today too',
    'Let\'s play together',
    'Today is a day when it\'s okay to do nothing',
    'Sometimes it\'s okay to stop~',
    'I\'m happy because you\'re here',
    'I\'m so happy you came',
    'Let\'s take a deep breath? Hoo~~',
    'You\'re the most precious to me',
    'Happiness is close by 🍀',
    'Let\'s put our worries aside for a moment.',
    'I missed you so much.',
    'Let\'s play together',
    'Life is hooray~',
    'I love delicious food the most',
    'I\'m sleepy even after sleeping',
    'How are you feeling? I\'m fine, thank you',
    'Don\'t forget me',
    'You can\'t forget me',
    'You must never forget me, okay?',
    'If you\'re happy, I\'m happy too ^ㅇ^',
    'Laughing brings good fortune',
    'It\'s not that we laugh because we\'re happy, we\'re happy because we laugh.',
    'I want to always make you smile',
    'I\'ll always make you happy',
    'You are my everything.',
  ];

  // 탭 전용 대사 목록 (한국어)
  final List<String> _tapMessagesKo = [
    '왜 눌러? 간지러워~',
    '아잉 간지러워~',
    '간질간질해!',
    '까르륵 히히히',
    '이긍이긍',
    '꺄르르륵!',
    '아~ 간질간질!',
    '히히 그만~',
    '으흐흐 간지러워',
    '꺄~ 간지러워요!',
  ];

  // 탭 전용 대사 목록 (영어)
  final List<String> _tapMessagesEn = [
    'Why are you poking me? It tickles~',
    'Ah, it tickles~',
    'So ticklish!',
    'Hehe giggles',
    'Squirm squirm',
    'Kyahaha!',
    'Ah~ tickly tickly!',
    'Hehe stop~',
    'Ehehe it tickles',
    'Kya~ that tickles!',
  ];

  @override
  void initState() {
    super.initState();
    // WidgetsBindingObserver 등록
    WidgetsBinding.instance.addObserver(this);

    // 현재 캐릭터 ID 저장
    _lastCharacterId = _homeCharacterManager.currentCharacterId;

    // 코인 로드
    _loadCoins();

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

    // 메시지 자동 변경 타이머 시작 (40초마다)
    _startMessageTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bounceController?.dispose();
    _messageTimer?.cancel();
    _tapMessageResetTimer?.cancel();
    _returnTimer?.cancel();
    _shakeDecayTimer?.cancel();
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

  /// 코인 로드
  Future<void> _loadCoins() async {
    final coins = await CoinManager.getCoins();
    if (mounted) {
      setState(() {
        _currentCoins = coins;
      });
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
    _messageTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted) {
        final random = Random();
        final messages = Localizations.localeOf(context).languageCode == 'ko'
            ? _messagesKo
            : _messagesEn;
        setState(() {
          // 현재 메시지와 다른 랜덤 메시지 선택
          int newIndex;
          do {
            newIndex = random.nextInt(messages.length);
          } while (newIndex == _currentMessageIndex && messages.length > 1);
          _currentMessageIndex = newIndex;
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

  /// 카피바라 드래그 시작 처리
  void _onCapybaraDragStart(DragStartDetails details) {
    _dragStartPosition = details.localPosition;
    _lastDragPosition = details.localPosition;
    _lastDragTime = DateTime.now();
    _isDragging = true;
    _returnTimer?.cancel();
    _shakeDecayTimer?.cancel();

    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!).inMilliseconds > 200) {
      _lastTapTime = now;
      unawaited(_triggerHapticFeedback());
    }

    // 탭 메시지 표시
    if (!_showingTapMessage) {
      final random = Random();
      final isKorean = Localizations.localeOf(context).languageCode == 'ko';
      final tapMessages = isKorean ? _tapMessagesKo : _tapMessagesEn;
      final randomIndex = random.nextInt(tapMessages.length);

      setState(() {
        _showingTapMessage = true;
        _currentMessageIndex = randomIndex;
      });
    }

    _tapMessageResetTimer?.cancel();
  }

  /// 카피바라 드래그 중 처리 (손가락 따라 이동 + 속도 기반 흔들림)
  void _onCapybaraDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _dragStartPosition == null) return;

    final now = DateTime.now();

    // 속도 계산 (픽셀/밀리초)
    double velocity = 0.0;
    if (_lastDragPosition != null && _lastDragTime != null) {
      final dt = now.difference(_lastDragTime!).inMilliseconds;
      if (dt > 0) {
        final distance = (details.localPosition - _lastDragPosition!).distance;
        velocity = distance / dt; // px/ms
      }
    }

    setState(() {
      // 드래그 거리 계산 (최대 이동 제한 적용)
      final rawOffset = details.localPosition - _dragStartPosition!;
      const maxDrag = 50.0; // 최대 드래그 거리 (약간 줄임)

      _dragOffset = Offset(
        rawOffset.dx.clamp(-maxDrag, maxDrag),
        rawOffset.dy.clamp(-maxDrag, maxDrag),
      );

      // 속도 기반 흔들림 강도 계산 (0.5 이상이면 흔들림 시작)
      if (velocity > 0.5) {
        _shakeIntensity = (velocity * 15).clamp(0.0, 25.0); // 최대 25px 흔들림

        // 랜덤 방향으로 흔들림 추가
        final random = Random();
        _shakeOffset = Offset(
          (random.nextDouble() - 0.5) * _shakeIntensity,
          (random.nextDouble() - 0.5) * _shakeIntensity * 0.7, // Y축은 약하게
        );
      }
    });

    _lastDragPosition = details.localPosition;
    _lastDragTime = now;
  }

  /// 카피바라 드래그 종료 처리 (원위치 복귀 + 흔들림 감쇠)
  void _onCapybaraDragEnd(DragEndDetails details) {
    _isDragging = false;
    _dragStartPosition = null;
    _lastDragPosition = null;
    _lastDragTime = null;

    // 부드럽게 원위치로 복귀
    _returnTimer?.cancel();
    _returnTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        // 탄성 복귀 효과
        _dragOffset = Offset(
          _dragOffset.dx * 0.85,
          _dragOffset.dy * 0.85,
        );

        // 거의 원위치에 도달하면 정확히 0으로 설정하고 타이머 정지
        if (_dragOffset.distance < 0.5) {
          _dragOffset = Offset.zero;
          timer.cancel();
        }
      });
    });

    // 흔들림 감쇠 효과
    _shakeDecayTimer?.cancel();
    _shakeDecayTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        // 흔들림 강도 감쇠
        _shakeIntensity *= 0.90;

        // 랜덤 감쇠하는 흔들림
        if (_shakeIntensity > 0.5) {
          final random = Random();
          _shakeOffset = Offset(
            (random.nextDouble() - 0.5) * _shakeIntensity,
            (random.nextDouble() - 0.5) * _shakeIntensity * 0.7,
          );
        } else {
          _shakeOffset = Offset.zero;
          _shakeIntensity = 0.0;
          timer.cancel();
        }
      });
    });

    // 메시지 복귀 타이머
    _tapMessageResetTimer?.cancel();
    _tapMessageResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        final random = Random();
        final messages = Localizations.localeOf(context).languageCode == 'ko'
            ? _messagesKo
            : _messagesEn;
        setState(() {
          _showingTapMessage = false;
          _currentMessageIndex = random.nextInt(messages.length);
        });
      }
    });
  }

  /// 빠른 탭 처리 (드래그 없이 탭만 할 경우)
  void _onCapybaraTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!).inMilliseconds > 200) {
      _lastTapTime = now;
      unawaited(_triggerHapticFeedback());
    }

    // 탭 메시지 표시
    if (!_showingTapMessage) {
      final random = Random();
      final isKorean = Localizations.localeOf(context).languageCode == 'ko';
      final tapMessages = isKorean ? _tapMessagesKo : _tapMessagesEn;
      final randomIndex = random.nextInt(tapMessages.length);

      setState(() {
        _showingTapMessage = true;
        _currentMessageIndex = randomIndex;
      });
    }

    _tapMessageResetTimer?.cancel();
    _tapMessageResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        final random = Random();
        final messages = Localizations.localeOf(context).languageCode == 'ko'
            ? _messagesKo
            : _messagesEn;
        setState(() {
          _showingTapMessage = false;
          _currentMessageIndex = random.nextInt(messages.length);
        });
      }
    });
  }

  /// 플랫폼에 맞춰 두둥두둥 진동을 실행
  Future<void> _triggerHapticFeedback() async {
    if (!kIsWeb && Platform.isAndroid) {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        final supportsCustom =
            await Vibration.hasCustomVibrationsSupport() ?? false;
        if (supportsCustom) {
          await Vibration.vibrate(
            pattern: _androidDunDunPattern,
            intensities: _androidDunDunIntensities,
          );
        } else {
          await Vibration.vibrate(duration: 180);
        }
        return;
      }
    }

    // iOS 등에서는 기존 햅틱으로 대체
    HapticFeedback.mediumImpact();
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
              // 상단 영역 (코인 + 설정)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 코인 표시 (왼쪽)
                    _buildCoinDisplay(context),
                    // 설정 버튼 (오른쪽)
                    _buildSettingsButton(context),
                  ],
                ),
              ),
              // 나머지 콘텐츠
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildLevelSelector(context),
                      const SizedBox(height: 32),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildHomeCharacter(context),
                            const SizedBox(height: 56),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 하단 버튼 영역 (미션 + 컬렉션 + 상점)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  top: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMissionButton(context),
                    const SizedBox(width: 8),
                    _buildCollectionButton(context),
                    const SizedBox(width: 8),
                    _buildShopButton(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 하단 버튼 공통 크기 계산 (폭 대비 높이 0.8 비율 유지)
  Size _getSideButtonSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = (screenWidth * 0.20).clamp(110.0, 170.0);
    final height = (baseWidth * 0.82).clamp(90.0, 135.0);
    return Size(baseWidth, height);
  }

  /// 코인 표시 위젯 (상단 왼쪽)
  Widget _buildCoinDisplay(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/coin.png',
                width: 34,
                height: 34,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 34,
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                _currentCoins.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 1),
                      blurRadius: 2,
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

  /// 일일 미션 버튼 (왼쪽)
  Widget _buildMissionButton(BuildContext context) {
    final buttonSize = _getSideButtonSize(context);

    return GestureDetector(
      onTap: () {
        // TODO: 일일 미션 화면 열기
        print('일일 미션 버튼 클릭');
      },
      child: Consumer<LocaleState>(
        builder: (context, localeState, child) {
          final isEnglish = localeState.currentLocale.languageCode == 'en';
          final imagePath = isEnglish
              ? 'assets/images/mission-en.png'
              : 'assets/images/mission.png';

          return Container(
            width: buttonSize.width,
            height: buttonSize.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      size: 40,
                      color: Colors.purple,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// 컬렉션 버튼 (오른쪽 위)
  Widget _buildCollectionButton(BuildContext context) {
    final buttonSize = _getSideButtonSize(context);

    return GestureDetector(
      onTap: () => _openCollection(context),
      child: Consumer<LocaleState>(
        builder: (context, localeState, child) {
          final isEnglish = localeState.currentLocale.languageCode == 'en';
          final imagePath = isEnglish
              ? 'assets/images/collection-en.png'
              : 'assets/images/collection.png';

          return Container(
            width: buttonSize.width,
            height: buttonSize.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.collections,
                      size: 40,
                      color: Colors.orange,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// 상점 버튼 (오른쪽 아래)
  Widget _buildShopButton(BuildContext context) {
    final buttonSize = _getSideButtonSize(context);

    return GestureDetector(
      onTap: () {
        // TODO: 상점 화면 열기
        print('상점 버튼 클릭');
      },
      child: Consumer<LocaleState>(
        builder: (context, localeState, child) {
          final isEnglish = localeState.currentLocale.languageCode == 'en';
          final imagePath = isEnglish
              ? 'assets/images/shop-en.png'
              : 'assets/images/shop.png';

          return Container(
            width: buttonSize.width,
            height: buttonSize.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      size: 40,
                      color: Colors.green,
                    ),
                  );
                },
              ),
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

    // 컬렉션 화면에서 돌아온 후 캐릭터 갱신 확인 및 코인 리로드
    await _checkCharacterUpdate();
    await _loadCoins();
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
      onTap: _onCapybaraTap,
      onPanStart: _onCapybaraDragStart,
      onPanUpdate: _onCapybaraDragUpdate,
      onPanEnd: _onCapybaraDragEnd,
      child: AnimatedBuilder(
        animation: _bounceAnimation ?? const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              _dragOffset.dx + _shakeOffset.dx, // 드래그 + 흔들림 X
              (_bounceAnimation?.value ?? 0) +
                  _dragOffset.dy +
                  _shakeOffset.dy, // 바운스 + 드래그 + 흔들림 Y
            ),
            child: child,
          );
        },
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
                    child: Text(
                      () {
                        if (_showingTapMessage) {
                          final tapMessages =
                              isKorean ? _tapMessagesKo : _tapMessagesEn;
                          final index =
                              _currentMessageIndex >= tapMessages.length
                                  ? 0
                                  : _currentMessageIndex;
                          return tapMessages[index];
                        } else {
                          final messages = isKorean ? _messagesKo : _messagesEn;
                          final index = _currentMessageIndex >= messages.length
                              ? 0
                              : _currentMessageIndex;
                          return messages[index];
                        }
                      }(),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B5D4F),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 말풍선 꼬리 (아래쪽 중앙, 말풍선 본체와 겹치게 배치)
                  Positioned(
                    bottom: 2,
                    child: CustomPaint(
                      size: const Size(24, 12),
                      painter: _SpeechBubbleTailPainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 카피바라 이미지 (Transform은 외부 AnimatedBuilder에서 처리됨)
            Container(
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
          ],
        ),
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

    // 꼬리 테두리 (위쪽 가장자리 제외 - 말풍선 본체와 이어지는 부분)
    // 왼쪽 가장자리만 그리기
    final leftBorderPath = Path();
    leftBorderPath.moveTo(size.width / 2 - 10, 0);
    leftBorderPath.lineTo(size.width / 2, size.height);
    canvas.drawPath(leftBorderPath, borderPaint);

    // 오른쪽 가장자리만 그리기
    final rightBorderPath = Path();
    rightBorderPath.moveTo(size.width / 2 + 10, 0);
    rightBorderPath.lineTo(size.width / 2, size.height);
    canvas.drawPath(rightBorderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
