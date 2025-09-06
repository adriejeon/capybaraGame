import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'game_screen.dart';
import 'collection_screen.dart';
import '../widgets/sound_settings_dialog.dart';

/// 메인 홈 화면
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              // 설정 버튼 (상단 오른쪽)
              Positioned(
                top: 16,
                right: 16,
                child: _buildSettingsButton(context),
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
          ),
        ),
      ),
    );
  }

  /// 컬렉션 버튼 생성
  Widget _buildCollectionButton(
    BuildContext context,
    double width,
    double height,
  ) {
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
            'assets/images/button-collection.png',
            fit: BoxFit.contain,
            width: width,
            height: height,
          ),
        ),
      ),
    );
  }

  /// 게임 시작
  void _startGame(BuildContext context, GameDifficulty difficulty) {
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
