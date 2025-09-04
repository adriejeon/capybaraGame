import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'game_screen.dart';

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
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // 난이도 선택 버튼들
              Column(
                children: [
                  // 쉬움 버튼
                  _buildImageButton(
                    context,
                    'assets/images/button-easy.png',
                    GameDifficulty.easy,
                  ),

                  const SizedBox(height: 25),

                  // 보통 버튼
                  _buildImageButton(
                    context,
                    'assets/images/button-normal.png',
                    GameDifficulty.medium,
                  ),

                  const SizedBox(height: 25),

                  // 어려움 버튼
                  _buildImageButton(
                    context,
                    'assets/images/button-hard.png',
                    GameDifficulty.hard,
                  ),
                ],
              ),

              const Spacer(flex: 4),
            ],
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
  ) {
    return GestureDetector(
      onTap: () => _startGame(context, difficulty),
      child: Container(
        width: 320,
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            width: 320,
            height: 110,
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
}
