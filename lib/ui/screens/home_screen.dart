import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import 'game_screen.dart';
import 'collection_screen.dart';
import '../widgets/sound_settings_dialog.dart';
import '../../ads/admob_handler.dart';
import '../../data/game_counter.dart';
import '../../state/locale_state.dart';

/// 메인 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AdmobHandler _adMobHandler = AdmobHandler();

  @override
  void initState() {
    super.initState();
    // 스플래시 화면 종료
    FlutterNativeSplash.remove();
    // 전면 광고 미리 로드 (약간의 지연 후)
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _adMobHandler.loadInterstitialAd();
      print('홈 화면 - 전면 광고 로드 시작');
    });
    // 배너 광고 상태 변경 콜백 설정
    _adMobHandler.setBannerCallback(() {
      if (mounted) {
        setState(() {});
      }
    });
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
          child: Stack(
            children: [
              // 언어 교체 버튼 (상단 왼쪽)
              Positioned(
                top: 16,
                left: 16,
                child: _buildLanguageButton(context),
              ),
              // 설정 버튼 (상단 오른쪽)
              Positioned(
                top: 16,
                right: 16,
                child: _buildSettingsButton(context),
              ),
              // 배너 광고 (하단에서 40px 위)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: _adMobHandler.getBannerAd(),
              ),
              // 메인 콘텐츠
              LayoutBuilder(
                builder: (context, constraints) {
                  // 화면 크기에 따라 버튼 크기 조정
                  final screenWidth = constraints.maxWidth;
                  final screenHeight = constraints.maxHeight;

                  // 버튼 크기를 화면 크기에 맞게 조정
                  final buttonWidth = (screenWidth * 0.6).clamp(280.0, 400.0);
                  final buttonHeight = (buttonWidth * 0.34).clamp(90.0, 140.0);

                  // 화면 비율에 따라 버튼 위치 조정
                  final isTablet = screenWidth > 800; // 태블릿/아이패드 감지
                  final topFlex = 1; // 모든 디바이스에서 상단 여백 최소화
                  final bottomFlex =
                      isTablet ? 5 : 6; // 모든 디바이스에서 하단 영역 조금 더 늘림

                  return Column(
                    children: [
                      // 상단 여백 (반응형)
                      Expanded(
                        flex: topFlex,
                        child: Container(),
                      ),

                      // 버튼 영역 (반응형 위치)
                      Expanded(
                        flex: bottomFlex,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  screenHeight * 0.02, // 모든 디바이스에서 하단 여백 더 최소화
                              left: 20,
                              right: 20,
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center, // 모든 디바이스에서 중앙 정렬
                              children: [
                                // 난이도 선택 버튼들
                                Column(
                                  children: [
                                    // 쉬움 버튼
                                    _buildImageButton(
                                      context,
                                      'assets/images/button-easy.png',
                                      GameDifficulty.easy,
                                      buttonWidth,
                                      buttonHeight,
                                    ),

                                    SizedBox(
                                        height: isTablet
                                            ? screenHeight * 0.02
                                            : screenHeight * 0.025),

                                    // 보통 버튼
                                    _buildImageButton(
                                      context,
                                      'assets/images/button-normal.png',
                                      GameDifficulty.medium,
                                      buttonWidth,
                                      buttonHeight,
                                    ),

                                    SizedBox(
                                        height: isTablet
                                            ? screenHeight * 0.02
                                            : screenHeight * 0.025),

                                    // 어려움 버튼
                                    _buildImageButton(
                                      context,
                                      'assets/images/button-hard.png',
                                      GameDifficulty.hard,
                                      buttonWidth,
                                      buttonHeight,
                                    ),

                                    SizedBox(
                                        height: isTablet
                                            ? screenHeight * 0.02
                                            : screenHeight * 0.025),

                                    // 컬렉션 버튼
                                    _buildCollectionButton(
                                      context,
                                      buttonWidth,
                                      buttonHeight,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 언어 교체 버튼 생성
  Widget _buildLanguageButton(BuildContext context) {
    return Consumer<LocaleState>(
      builder: (context, localeState, child) {
        // 현재 언어에 따라 표시할 이미지 결정
        final isKorean = localeState.currentLocale.languageCode == 'ko';
        final imagePath = isKorean
            ? 'assets/images/lang-en.png'
            : 'assets/images/lang-kr.png';

        return GestureDetector(
          onTap: () => localeState.toggleLocale(),
          child: Container(
            width: 67,
            height: 61,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 이미지 로드 실패 시 기본 언어 아이콘 표시
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF4A90E2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isKorean ? Icons.language : Icons.translate,
                      color: const Color(0xFF4A90E2),
                      size: 24,
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

  /// 설정 버튼 생성
  Widget _buildSettingsButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSoundSettings(context),
      child: Container(
        width: 67,
        height: 61,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/images/button-setting.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 이미지 로드 실패 시 기본 설정 아이콘 표시
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF4A90E2),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.settings,
                  color: Color(0xFF4A90E2),
                  size: 24,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 이미지 버튼 생성
  Widget _buildImageButton(
    BuildContext context,
    String imagePath,
    GameDifficulty difficulty,
    double width,
    double height,
  ) {
    return Consumer<LocaleState>(
      builder: (context, localeState, child) {
        // 현재 언어에 따라 이미지 경로 결정
        final isEnglish = localeState.currentLocale.languageCode == 'en';
        String finalImagePath = imagePath;

        if (isEnglish) {
          // 영어 모드일 때 -en 접미사 추가
          final dotIndex = imagePath.lastIndexOf('.');
          if (dotIndex != -1) {
            finalImagePath =
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
                finalImagePath,
                fit: BoxFit.contain,
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) {
                  // 영어 이미지가 없으면 기본 이미지 사용
                  if (isEnglish) {
                    return Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
                      width: width,
                      height: height,
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

  /// 컬렉션 버튼 생성
  Widget _buildCollectionButton(
    BuildContext context,
    double width,
    double height,
  ) {
    return Consumer<LocaleState>(
      builder: (context, localeState, child) {
        // 현재 언어에 따라 이미지 경로 결정
        final isEnglish = localeState.currentLocale.languageCode == 'en';
        String imagePath = 'assets/images/button-collection.png';

        if (isEnglish) {
          // 영어 모드일 때 -en 접미사 추가
          imagePath = 'assets/images/button-collection-en.png';
        }

        return GestureDetector(
          onTap: () => _openCollection(context),
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
                    return Image.asset(
                      'assets/images/button-collection.png',
                      fit: BoxFit.contain,
                      width: width,
                      height: height,
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.collections,
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
  void _openCollection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CollectionScreen(),
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
