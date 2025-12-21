import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/gacha_glass_constants.dart';

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
  // 공유 상수 사용
  static const double _glassSize = GachaGlassConstants.glassSize;
  static const double _glassTop = GachaGlassConstants.glassTop;
  static const double _glassCenterX = GachaGlassConstants.glassCenterX;
  static const double _glassCenterY = GachaGlassConstants.glassCenterY;
  static const double _glassWidthRatio = GachaGlassConstants.glassWidthRatio;
  static const double _glassHeightRatio = GachaGlassConstants.glassHeightRatio;

  // 인형 설정
  static const int _dollCount = GachaGlassConstants.dollCount;
  static const double _dollSize = GachaGlassConstants.dollSize;
  static const List<String> _dollImages = [
    'assets/images/gacha_doll_1.png',
    'assets/images/gacha_doll_2.png',
    'assets/images/gacha_doll_3.png',
  ];

  // 애니메이션 설정
  static const Duration _animationDuration = Duration(milliseconds: 2000);
  static const double _maxBounceHeight = 100.0; // 최대 튀는 높이

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
  /// 물리적 공간을 확보하면서 쌓이도록 배치
  void _initializeDolls() {
    _dolls.clear();

    // 인형들 간의 최소 거리 (상대적 비율, 겹치지 않도록)
    // initialX, initialY는 -1.0 ~ 1.0 범위의 상대적 위치
    final minDistance = 0.15; // 상대적 최소 거리 (15%)

    // 레이어별로 인형 배치 (바닥부터 위로)
    final layers = <List<DollData>>[];

    for (int i = 0; i < _dollCount; i++) {
      bool placed = false;
      int attempts = 0;
      const maxAttempts = 100;

      while (!placed && attempts < maxAttempts) {
        attempts++;

        // 랜덤 X 위치 (원형 영역 내, 중심에서 벗어나지 않게)
        final angle = _random.nextDouble() * 2 * pi;
        final radiusRatio = _random.nextDouble() * 0.65 + 0.15; // 0.15 ~ 0.8
        final xOffset = cos(angle) * radiusRatio;

        // 레이어별로 Y 위치 결정 (바닥부터 위로 쌓기)
        double yOffset = 0.0;
        int targetLayer = 0;

        // 기존 레이어들을 확인하여 적절한 레이어 찾기
        bool foundLayer = false;
        for (int layerIndex = 0; layerIndex < layers.length; layerIndex++) {
          final layer = layers[layerIndex];
          bool canPlaceInLayer = true;

          // 이 레이어의 다른 인형들과 충돌 체크
          for (final existingDoll in layer) {
            final dx = xOffset - existingDoll.initialX;
            final dy = 0.0; // 같은 레이어이므로 Y 차이는 0
            final distance = sqrt(dx * dx + dy * dy);
            if (distance < minDistance) {
              canPlaceInLayer = false;
              break;
            }
          }

          if (canPlaceInLayer) {
            targetLayer = layerIndex;
            // 레이어의 Y 위치 계산 (바닥부터 위로)
            // initialY: 0.0 = 바닥, 1.0 = 상단 (바닥 기준)
            // 하단부터 위로 쌓이므로 0.0부터 시작
            yOffset = targetLayer * 0.12; // 각 레이어마다 0.12씩 위로 (더 조밀하게)
            foundLayer = true;
            break;
          }
        }

        // 적절한 레이어를 찾지 못했으면 새 레이어 생성
        if (!foundLayer) {
          targetLayer = layers.length;
          yOffset = targetLayer * 0.12;
        }

        // 유리창 하단 경계 체크 (initialY가 0.4를 넘지 않도록, 바닥 기준)
        if (yOffset > 0.4) {
          continue; // 하단 경계를 넘으면 다시 시도
        }

        // 회전 각도: 더 큰 랜덤 회전 (쓰러진 것처럼 보이게)
        final rotation = _random.nextDouble() * pi * 0.8 -
            pi * 0.4; // -0.4π ~ 0.4π 라디안 (약 -72도 ~ 72도)

        // 애니메이션 지연: 각 인형마다 다른 타이밍
        final delay = _random.nextDouble() * 0.3;

        // 튀는 높이: 각 인형마다 다른 높이
        final bounceHeight = _random.nextDouble() * 0.7 + 0.3;

        final newDoll = DollData(
          imageIndex: _random.nextInt(_dollImages.length),
          initialX: xOffset,
          initialY: yOffset,
          rotation: rotation,
          delay: delay,
          bounceHeight: bounceHeight,
        );

        // 새 레이어 생성 (필요한 경우)
        if (targetLayer >= layers.length) {
          layers.add([]);
        }

        // 레이어에 추가
        layers[targetLayer].add(newDoll);
        _dolls.add(newDoll);
        placed = true;
      }
    }
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
        // 기계 이미지 크기 계산 (화면 경계에서 잘리지 않도록 여유 공간 확보)
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
                          glassHeight: glassHeight,
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
    required double glassHeight, // 유리창 높이
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

        // Y: 바닥 기준으로 배치 (initialY는 0.0 = 바닥, 값이 클수록 위로)
        // 유리창 하단에서부터 쌓이도록 계산
        // bounceOffset을 빼서 튀어오르는 효과 적용
        final bottomY = glassHeight - 16.0; // 유리창 하단 (여유 공간 포함)
        // y는 인형의 중심 Y 좌표 (Positioned의 top: y - _dollSize / 2이므로)
        // 인형의 하단이 바닥에 닿으려면: y = bottomY - _dollSize / 2
        var y = bottomY -
            _dollSize / 2 - // 인형 중심이 바닥에서 반 크기만큼 위에 있도록
            (doll.initialY *
                glassRadius *
                _glassHeightRatio *
                0.7) - // 바닥부터 위로 쌓기
            bounceOffset;

        // 유리창 하단 경계 체크 (인형이 바닥 아래로 가지 않도록)
        final minY = bottomY - _dollSize / 2;
        if (y < minY) {
          y = minY;
        }

        // 회전 애니메이션 (튀는 동안 약간 회전) + 흔들림 회전
        final shakeRotation = widget.shakeAnimation != null
            ? widget.shakeAnimation!.value * 0.05 // 작은 회전
            : 0.0;
        final rotation = doll.rotation +
            (progress * pi * 0.5 * doll.bounceHeight) +
            shakeRotation;

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
