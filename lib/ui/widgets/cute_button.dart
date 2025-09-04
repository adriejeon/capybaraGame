import 'package:flutter/material.dart';
import 'dart:math';

/// 3D 질감이 있는 게임 버튼 (이미지 스타일)
class CuteGameButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color primaryColor;
  final Color shadowColor;
  final IconData? icon;
  final double width;
  final double height;

  const CuteGameButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.primaryColor = const Color(0xFFFFA500), // 주황색
    this.shadowColor = const Color(0xFFE67E22), // 진한 주황색
    this.icon,
    this.width = 200,
    this.height = 60,
  });

  @override
  State<CuteGameButton> createState() => _CuteGameButtonState();
}

class _CuteGameButtonState extends State<CuteGameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                children: [
                  // 메인 그림자 (오른쪽 아래로 6px)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      width: widget.width,
                      height: widget.height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        color: widget.shadowColor,
                      ),
                    ),
                  ),
                  // 메인 버튼
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: widget.width,
                      height: widget.height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFFFD700), // 밝은 노란색 (상단)
                            const Color(0xFFFFA500), // 주황색 (중간)
                            const Color(0xFFE67E22), // 진한 주황색 (하단)
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // 상단 하이라이트 (타원형)
                          Positioned(
                            top: 8,
                            left: widget.width * 0.15,
                            right: widget.width * 0.15,
                            child: Container(
                              height: 16,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.7),
                                    Colors.white.withValues(alpha: 0.2),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 나무 질감 효과
                          Positioned.fill(
                            child: CustomPaint(
                              painter: WoodTexturePainter(),
                            ),
                          ),
                          // 텍스트와 아이콘
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(
                                    widget.icon,
                                    color: Colors.white,
                                    size: 24,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  widget.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 나무 질감을 그리는 CustomPainter
class WoodTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final random = Random(42); // 고정된 시드로 일관된 패턴

    // 왼쪽 가장자리 나무 결
    for (int i = 0; i < 4; i++) {
      final y = size.height * 0.15 + (i * size.height * 0.2);
      final length =
          size.height * 0.15 + random.nextDouble() * size.height * 0.1;
      canvas.drawLine(
        Offset(3, y),
        Offset(3, y + length),
        paint,
      );
    }

    // 오른쪽 가장자리 나무 결
    for (int i = 0; i < 4; i++) {
      final y = size.height * 0.15 + (i * size.height * 0.2);
      final length =
          size.height * 0.15 + random.nextDouble() * size.height * 0.1;
      canvas.drawLine(
        Offset(size.width - 3, y),
        Offset(size.width - 3, y + length),
        paint,
      );
    }

    // 중앙 부분의 미세한 나무 결
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final x = size.width * 0.2 + (i * size.width * 0.2);
      final y = size.height * 0.2 + random.nextDouble() * size.height * 0.6;
      final length =
          size.height * 0.1 + random.nextDouble() * size.height * 0.1;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + length),
        centerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 난이도별 색상 테마 (주황색 계열로 변경)
class DifficultyColors {
  static const Color easy = Color(0xFF4CAF50); // 초록색
  static const Color easyShadow = Color(0xFF2E7D32); // 진한 초록색

  static const Color medium = Color(0xFFFF9800); // 주황색
  static const Color mediumShadow = Color(0xFFE65100); // 진한 주황색

  static const Color hard = Color(0xFFF44336); // 빨간색
  static const Color hardShadow = Color(0xFFC62828); // 진한 빨간색
}
