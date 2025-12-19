import 'dart:math';
import 'package:flutter/material.dart';

/// 가챠 기계 위젯
/// 유리창 안에 인형들이 쌓여있고, 버튼을 누르면 튀어오르는 애니메이션을 제공합니다.
class GachaMachineWidget extends StatefulWidget {
  /// 가챠 버튼을 눌렀을 때 호출되는 콜백
  final VoidCallback? onGachaPressed;

  /// 가챠 애니메이션이 진행 중인지 여부
  final bool isAnimating;

  /// 흔들림 애니메이션 (인형만 흔들리도록 사용)
  final Animation<double>? shakeAnimation;

  const GachaMachineWidget({
    super.key,
    this.onGachaPressed,
    this.isAnimating = false,
    this.shakeAnimation,
  });

  @override
  State<GachaMachineWidget> createState() => _GachaMachineWidgetState();
}

class _GachaMachineWidgetState extends State<GachaMachineWidget>
    with TickerProviderStateMixin {
  // 유리창 위치 및 크기 조정 상수 (이미지에 맞게 미세 조정 가능)
  static const double _glassSize = 1.1; // 기계 이미지 너비 대비 유리창 크기 비율
  static const double _glassTop = 0.2; // 기계 이미지 상단에서 유리창까지의 거리 비율
  static const double _glassCenterX = 0.5; // 유리창 중심 X 위치 (0.0 ~ 1.0)
  static const double _glassCenterY = 0.3; // 유리창 중심 Y 위치 (0.0 ~ 1.0)
  static const double _glassWidthRatio = 0.88; // 유리창 가로 비율 (기본값 1.0)
  static const double _glassHeightRatio = 0.9; // 유리창 세로 비율 (0.85 = 가로보다 세로가 짧아서 타원형)

  // 인형 설정
  static const int _dollCount = 15; // 인형 개수
  static const double _dollSize = 60.0; // 인형 이미지 크기
  static const List<String> _dollImages = [
    'assets/images/gacha_doll_1.png',
    'assets/images/gacha_doll_2.png',
    'assets/images/gacha_doll_3.png',
  ];

  // 애니메이션 설정
  static const Duration _animationDuration = Duration(milliseconds: 2000);
  static const double _maxBounceHeight = 80.0; // 최대 튀는 높이

  late AnimationController _bounceController;
  final List<DollData> _dolls = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeDolls();
    _bounceController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GachaMachineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 isAnimating이 true로 변경되면 애니메이션 시작
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _startBounceAnimation();
    }
    // 애니메이션이 끝나면 인형들을 원래 위치로 복귀
    if (!widget.isAnimating && oldWidget.isAnimating) {
      _resetDollsPosition();
    }
  }

  /// 인형 데이터 초기화
  void _initializeDolls() {
    _dolls.clear();
    for (int i = 0; i < _dollCount; i++) {
      _dolls.add(_createRandomDoll());
    }
  }

  /// 랜덤 인형 데이터 생성
  /// 유리통 바닥 쪽에 자연스럽게 쌓이도록 위치와 회전을 랜덤하게 설정
  DollData _createRandomDoll() {
    // X 위치: 유리창 전체 너비에 걸쳐 넓게 분산 (-0.9 ~ 0.9)
    // 중심에서 좌우로 넓게 퍼지도록 설정
    final xOffset = (_random.nextDouble() - 0.5) * 1.8; // -0.9 ~ 0.9
    
    // Y 위치: 유리창 하단에 몰리도록 설정
    // initialY가 클수록 아래쪽 (유리창 중심 기준 아래)
    // 0.6 ~ 1.0 범위로 설정하여 바닥 쪽에 더 가깝게 쌓이도록 함
    final yOffset = _random.nextDouble() * 0.4 + 0.6; // 0.6 ~ 1.0 (하단 40% 영역)
    
    // 회전 각도: 0 ~ 2π 완전 랜덤
    final rotation = _random.nextDouble() * 2 * pi;
    
    // 애니메이션 지연: 각 인형마다 다른 타이밍
    final delay = _random.nextDouble() * 0.3; // 0 ~ 0.3초 지연
    
    // 튀는 높이: 각 인형마다 다른 높이
    final bounceHeight = _random.nextDouble() * 0.7 + 0.3; // 0.3 ~ 1.0 배율
    
    return DollData(
      imageIndex: _random.nextInt(_dollImages.length),
      initialX: xOffset,
      initialY: yOffset,
      rotation: rotation,
      delay: delay,
      bounceHeight: bounceHeight,
    );
  }

  /// 튀어오르는 애니메이션 시작
  Future<void> _startBounceAnimation() async {
    _bounceController.reset();
    await _bounceController.forward();
    // 애니메이션 완료 후 인형들을 원래 위치로 복귀
    _resetDollsPosition();
  }

  /// 인형들을 원래 위치로 복귀 (바닥에 쌓인 상태)
  void _resetDollsPosition() {
    if (mounted) {
      setState(() {
        // 인형들을 다시 초기화하여 바닥에 쌓인 상태로 복귀
        _initializeDolls();
        _bounceController.reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 기계 이미지 크기 계산
        final imageWidth = constraints.maxWidth * 0.8;
        final imageHeight = imageWidth * 1.4;

        // 유리창 크기 및 위치 계산
        final glassBaseRadius = imageWidth * _glassSize / 2;
        final glassWidth = glassBaseRadius * 2 * _glassWidthRatio;
        final glassHeight = glassBaseRadius * 2 * _glassHeightRatio;
        final glassCenterX = imageWidth * _glassCenterX;
        final glassCenterY = imageHeight * _glassCenterY;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 배경: 가챠 기계 이미지
            Image.asset(
              'assets/images/gacha.png',
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: imageWidth,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey[600]!, width: 4),
                  ),
                  child: const Icon(
                    Icons.all_inbox,
                    size: 80,
                    color: Colors.white,
                  ),
                );
              },
            ),

            // 유리창 영역 (타원형으로 제한)
            Positioned(
              left: glassCenterX - glassWidth / 2,
              top: glassCenterY - glassHeight / 2,
              child: ClipRRect(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(
                    glassWidth / 2,
                    glassHeight / 2,
                  ),
                ),
                child: SizedBox(
                  width: glassWidth,
                  height: glassHeight,
                  child: Stack(
                    children: [
                      // 인형들
                      ..._dolls.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doll = entry.value;
                        return _buildDoll(
                          doll: doll,
                          glassRadius: glassBaseRadius,
                          glassCenterX: glassWidth / 2,
                          glassCenterY: glassHeight / 2,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 개별 인형 위젯 빌드
  Widget _buildDoll({
    required DollData doll,
    required double glassRadius, // 기본 반지름 (타원형 계산에 사용)
    required double glassCenterX, // 타원형 중심 X
    required double glassCenterY, // 타원형 중심 Y
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bounceController,
        if (widget.shakeAnimation != null) widget.shakeAnimation!,
      ]),
      builder: (context, child) {
        // 흔들림 효과 계산 (인형만 흔들림)
        final shakeOffset = widget.shakeAnimation != null
            ? widget.shakeAnimation!.value * 3.0 // 작은 흔들림
            : 0.0;

        // 애니메이션 진행도 (지연 시간 고려)
        double progress = _bounceController.value;
        if (progress < doll.delay) {
          progress = 0.0;
        } else {
          progress = (progress - doll.delay) / (1.0 - doll.delay);
          progress = progress.clamp(0.0, 1.0);
        }

        // 튀어오르는 효과 계산 (Curves.bounceOut과 sin 함수 조합)
        final bounceCurve = Curves.bounceOut.transform(progress);
        final sinWave = sin(progress * pi * 4) * 0.3; // 추가 움직임
        final bounceOffset = bounceCurve * _maxBounceHeight * doll.bounceHeight;
        final horizontalOffset = sinWave * 20.0 * doll.bounceHeight;

        // 최종 위치 계산 (타원형에 맞게 조정)
        // X: 유리창 중심 기준 좌우로 분산 (가로 비율 고려) + 흔들림 + 튀어오르는 효과
        final x = glassCenterX +
            (doll.initialX * glassRadius * _glassWidthRatio * 0.9) +
            horizontalOffset +
            shakeOffset;
        
        // Y: 유리창 중심 기준 아래쪽에 배치 (세로 비율 고려)
        // initialY가 0.6~1.0 범위이므로, 중심에서 아래쪽으로 배치됨
        // bounceOffset을 빼서 튀어오르는 효과 적용
        final y = glassCenterY +
            (doll.initialY * glassRadius * _glassHeightRatio * 0.9) -
            bounceOffset;

        // 회전 애니메이션 (튀는 동안 약간 회전) + 흔들림 회전
        final shakeRotation = widget.shakeAnimation != null
            ? widget.shakeAnimation!.value * 0.05 // 작은 회전
            : 0.0;
        final rotation = doll.rotation + (progress * pi * 0.5 * doll.bounceHeight) + shakeRotation;

        return Positioned(
          left: x - _dollSize / 2,
          top: y - _dollSize / 2,
          child: Transform.rotate(
            angle: rotation,
            child: Image.asset(
              _dollImages[doll.imageIndex],
              width: _dollSize,
              height: _dollSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: _dollSize,
                  height: _dollSize,
                  decoration: BoxDecoration(
                    color: Colors.pink[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets,
                    color: Colors.white,
                    size: 30,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// 인형 데이터 클래스
class DollData {
  final int imageIndex; // 사용할 이미지 인덱스 (0~2)
  final double initialX; // 초기 X 위치 (중심 기준, -1.0 ~ 1.0)
  final double initialY; // 초기 Y 위치 (중심 기준, 0.0 ~ 1.0)
  final double rotation; // 초기 회전 각도 (라디안)
  final double delay; // 애니메이션 지연 시간 (0.0 ~ 1.0)
  final double bounceHeight; // 튀는 높이 배율 (0.0 ~ 1.0)

  DollData({
    required this.imageIndex,
    required this.initialX,
    required this.initialY,
    required this.rotation,
    required this.delay,
    required this.bounceHeight,
  });
}
