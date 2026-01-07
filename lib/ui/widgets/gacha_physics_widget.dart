import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart' as flame;
import '../../game/gacha_physics_game.dart';
import '../../utils/gacha_glass_constants.dart';

/// 가챠 기계 물리 시뮬레이션 위젯
class GachaPhysicsWidget extends StatefulWidget {
  /// 가챠 애니메이션이 진행 중인지 여부
  final bool isAnimating;

  /// 흔들림 애니메이션 (인형만 흔들리도록 사용)
  final Animation<double>? shakeAnimation;

  /// 인형 개수
  final int dollCount;

  const GachaPhysicsWidget({
    super.key,
    this.isAnimating = false,
    this.shakeAnimation,
    this.dollCount = GachaGlassConstants.dollCount,
  });

  @override
  State<GachaPhysicsWidget> createState() => _GachaPhysicsWidgetState();
}

class _GachaPhysicsWidgetState extends State<GachaPhysicsWidget> {
  GachaPhysicsGame? _game;
  flame.Vector2? _gameSize;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(GachaPhysicsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 인형 개수가 변경되면 업데이트
    if (oldWidget.dollCount != widget.dollCount && _game != null) {
      _game!.setDollCount(widget.dollCount);
    }

    // 애니메이션 시작/종료 처리
    if (_game != null) {
      if (widget.isAnimating && !oldWidget.isAnimating) {
        print('GachaPhysicsWidget: Animation started, isLoaded=${_game!.isLoaded}');
        // 애니메이션 시작 (게임이 로드되었는지 확인)
        if (_game!.isLoaded) {
          _game!.startPopcornAnimation();
        } else {
          print('GachaPhysicsWidget: Game not loaded yet, waiting for onLoad...');
          // 게임이 아직 로드되지 않았으면, 로드 완료 후 애니메이션 시작
          _game!.onLoad().then((_) {
            print('GachaPhysicsWidget: Game loaded, starting animation...');
            if (mounted && widget.isAnimating) {
              _game?.startPopcornAnimation();
            }
          });
        }
      } else if (!widget.isAnimating && oldWidget.isAnimating) {
        print('GachaPhysicsWidget: Animation stopped');
        // 애니메이션 종료 및 리셋
        if (_game!.isLoaded) {
          _game!.resetAnimation();
        }
      }
    } else {
      print('GachaPhysicsWidget: _game is null, cannot start animation');
    }
  }
  
  /// 통 크기/위치 변경사항을 반영하기 위해 인형 재배치
  /// 통 크기/위치 상수를 변경한 후 이 메서드를 호출하세요
  void reloadDolls() {
    if (_game != null && _game!.isLoaded) {
      _game!.reloadDolls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 기계 이미지 크기 계산 (gacha_machine_widget.dart와 동일)
        final imageWidth = constraints.maxWidth * 0.8;
        final imageHeight = imageWidth * 1.4;

        // 유리창 크기 및 위치 계산 (gacha_machine_widget.dart의 상수 사용)
        final glassSize = GachaGlassConstants.glassSize;
        final glassWidthRatio = GachaGlassConstants.glassWidthRatio;
        final glassHeightRatio = GachaGlassConstants.glassHeightRatio;
        final glassCenterX = GachaGlassConstants.glassCenterX;
        final glassCenterY = GachaGlassConstants.glassCenterY;

        final glassBaseRadius = imageWidth * glassSize / 2;
        final glassWidth = glassBaseRadius * 2 * glassWidthRatio;
        final glassHeight = glassBaseRadius * 2 * glassHeightRatio;
        final glassCenterX_px = imageWidth * glassCenterX;
        final glassCenterY_px = imageHeight * glassCenterY;

        // 게임 크기 설정 (한 번만, build에서 게임 생성은 피함)
        final currentGameSize = flame.Vector2(glassWidth, glassHeight);
        if (_game == null ||
            _gameSize == null ||
            _gameSize!.x != glassWidth ||
            _gameSize!.y != glassHeight) {
          _gameSize = currentGameSize;
          // 게임은 한 번만 생성하고 재사용
          if (_game == null) {
            _game = GachaPhysicsGame(fixedResolution: _gameSize);
            // 게임이 완전히 로드된 후에 setDollCount 호출 (비동기로 처리)
            _game?.onLoad().then((_) {
              // onLoad 완료 후 setDollCount 호출
              // 통 크기/위치 상수는 컴파일 타임 상수이므로, 앱 재시작 시 자동 반영됨
              _game?.setDollCount(widget.dollCount);
            });
          }
          // 주의: build 메서드에서 reloadDolls()를 호출하면 애니메이션 중에 인형이 재배치되어 애니메이션이 방해될 수 있음
          // 통 크기/위치 변경은 앱 재시작 시 자동 반영되므로, build에서 재배치할 필요 없음
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // 배경: 가챠 기계 이미지
            Image.asset(
              'assets/images/gacha.webp',
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

            // 물리 시뮬레이션 게임 (유리창 영역에만 표시)
            Positioned(
              left: (constraints.maxWidth - imageWidth) / 2 +
                  (glassCenterX_px - glassWidth / 2) +
                  GachaGlassConstants.physicsOffsetX, // 미세 조정 오프셋 X
              top: (constraints.maxHeight - imageHeight) / 2 +
                  (glassCenterY_px - glassHeight / 2) +
                  GachaGlassConstants.physicsOffsetY, // 미세 조정 오프셋 Y
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(glassWidth * 0.5), // 타원형 클리핑
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: SizedBox(
                    width: glassWidth,
                    height: glassHeight,
                    child: _game != null
                        ? GameWidget<GachaPhysicsGame>.controlled(
                            gameFactory: () => _game!,
                          )
                        : const SizedBox(), // 게임이 초기화될 때까지 빈 위젯
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _game?.pauseEngine();
    super.dispose();
  }
}
