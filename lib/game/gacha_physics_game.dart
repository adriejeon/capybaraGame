import 'dart:math';
import 'package:flame/components.dart' as flame;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../utils/gacha_glass_constants.dart';

/// 가챠 통 정적 배치 게임 (물리 엔진 없음)
class GachaPhysicsGame extends FlameGame {
  // 유리창 크기 및 위치 상수 (공유 상수 사용)
  static const double glassSize = GachaGlassConstants.glassSize;
  static const double glassWidthRatio = GachaGlassConstants.glassWidthRatio;
  static const double glassHeightRatio = GachaGlassConstants.glassHeightRatio;
  static const double glassCenterX = GachaGlassConstants.glassCenterX;
  static const double glassCenterY = GachaGlassConstants.glassCenterY;

  // 인형 설정 (공유 상수 사용)
  static const double dollSize = GachaGlassConstants.dollSize;
  static const List<String> dollImages = GachaGlassConstants.dollImages;

  // 유리창 크기 (픽셀 단위)
  late double glassWidth;
  late double glassHeight;
  late double glassCenterX_px;
  late double glassCenterY_px;

  // onLoad() 완료 여부 추적
  bool _isLoaded = false;

  /// 게임 로드 완료 여부
  bool get isLoaded => _isLoaded;

  // 전경 인형 개수 (물리 적용)
  int dollCount = 1;

  // 배경 인형 개수 (고정, 물리 연산 없음)
  // 전경 인형과 합쳐서 총 개수가 되므로, 전경 인형이 많으면 배경 인형을 줄이는 것을 권장
  static const int backgroundDollCount = 0; // 배경 인형 비활성화 (총 개수 = 전경 20개만)

  // 인형 통 크기 비율 (한 곳에서 관리)
  // 이 값을 변경하면 통의 가로 크기가 변경됩니다
  // 0.60 = 좁게, 0.65 = 기본, 0.70 = 넓게, 0.80 = 매우 넓게
  static const double containerWidthRatio =
      0.70; // 통 가로 크기 증가 (기본 0.65에서 0.75로)

  // 통 위치 조정 (Y축 오프셋)
  // 양수 = 아래로, 음수 = 위로 이동
  // 통을 위로 올리려면 음수 값을 사용하세요 (예: -20.0)
  static const double containerOffsetY = 13.0; // 통을 위로 30px 이동

  // 통 세로 크기 조정 (마진 조정)
  // 이 값을 줄이면 통의 세로 높이가 커집니다 (마진이 줄어듦)
  // 기본값: 상단 40px, 하단 20px
  static const double containerTopMargin =
      15.0; // 상단 마진 (기본 40.0에서 20.0으로 줄여서 높이 증가)
  static const double containerBottomMargin =
      40.0; // 하단 마진 (기본 20.0에서 10.0으로 줄여서 높이 증가)

  // 고정 해상도 (선택적)
  final flame.Vector2? _fixedResolution;

  // 게임 크기 설정
  GachaPhysicsGame({flame.Vector2? fixedResolution})
      : _fixedResolution = fixedResolution,
        super();

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  bool get debugMode => false; // 디버깅용 테두리 숨기기

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 고정 해상도가 설정되어 있으면 적용
    if (_fixedResolution != null) {
      camera.viewfinder.visibleGameSize = _fixedResolution;
    }

    // 인형 이미지들을 미리 로드
    await images.loadAll(dollImages);

    // 화면 크기 기반으로 유리창 크기 계산
    final screenSize = camera.viewfinder.visibleGameSize ?? size;
    // fixedResolution이 설정되어 있으면 그 크기를 사용, 아니면 계산
    if (_fixedResolution != null) {
      // fixedResolution이 게임 크기이므로, 그대로 사용
      glassWidth = _fixedResolution!.x;
      glassHeight = _fixedResolution!.y;
      // 게임 좌표계는 (0,0)이 왼쪽 상단이므로, 중심은 화면 크기의 절반
      // 게임 화면이 유리구슬 영역만큼의 크기이므로, 중심은 화면의 정중앙
      glassCenterX_px = glassWidth / 2; // 게임 화면의 중심 X
      glassCenterY_px = glassHeight / 2; // 게임 화면의 중심 Y
    } else {
      // fixedResolution이 없으면 기존 계산 방식 사용
      final imageWidth = screenSize.x;
      final imageHeight = screenSize.y;
      final glassBaseRadius = imageWidth * glassSize / 2;

      glassWidth = glassBaseRadius * 2 * glassWidthRatio;
      glassHeight = glassBaseRadius * 2 * glassHeightRatio;
      glassCenterX_px = imageWidth * glassCenterX;
      glassCenterY_px = imageHeight * glassCenterY;
    }

    // 정적 인형 배치 생성
    await _spawnStaticDolls();

    // onLoad() 완료 표시
    _isLoaded = true;
  }

  /// 정적 인형 배치 생성 (물리 엔진 없이 자연스럽게 엉켜있는 배치)
  Future<void> _spawnStaticDolls() async {
    final random = Random();
    final innerHalfWidth = (glassWidth / 2) * containerWidthRatio;
    final topY = _containerTopY;
    final bottomY = _containerBottomY;
    final centerX = glassCenterX_px;

    // 통 크기/위치 디버그 정보 출력
    print(
        'Container settings: widthRatio=$containerWidthRatio, topMargin=$containerTopMargin, '
        'bottomMargin=$containerBottomMargin, offsetY=$containerOffsetY');
    print(
        'Container area: topY=$topY, bottomY=$bottomY, innerHalfWidth=$innerHalfWidth, '
        'height=${bottomY - topY}');

    // 인형들 간의 최소 거리 (겹치지 않도록)
    final minDistance = dollSize * 0.85;

    // 레이어별로 인형 배치 (바닥부터 위로)
    final layers = <List<StaticDollComponent>>[];

    int successfullyPlaced = 0;
    for (int i = 0; i < dollCount; i++) {
      bool placed = false;
      int attempts = 0;
      const maxAttempts = 500; // 시도 횟수 증가

      while (!placed && attempts < maxAttempts) {
        attempts++;

        // 랜덤 X 위치 (원형 영역 내, 중심에서 벗어나지 않게)
        final spawnAngle = random.nextDouble() * 2 * pi;
        final radiusRatio = random.nextDouble() * 0.7 + 0.1; // 0.1 ~ 0.8
        final xOffset = cos(spawnAngle) * radiusRatio * innerHalfWidth;
        final x = centerX + xOffset;

        // 레이어별로 Y 위치 결정 (바닥부터 위로 쌓기)
        double y = 0.0;
        int targetLayer = 0;

        // 기존 레이어들을 확인하여 적절한 레이어 찾기
        bool foundLayer = false;
        for (int layerIndex = 0; layerIndex < layers.length; layerIndex++) {
          final layer = layers[layerIndex];
          bool canPlaceInLayer = true;

          // 이 레이어의 다른 인형들과 충돌 체크
          for (final existingDoll in layer) {
            final dx = x - existingDoll.position.x;
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
            final layerY = bottomY - dollSize / 2 - (targetLayer * minDistance);
            y = layerY;
            foundLayer = true;
            break;
          }
        }

        // 적절한 레이어를 찾지 못했으면 새 레이어 생성
        if (!foundLayer) {
          targetLayer = layers.length;
          final layerY = bottomY - dollSize / 2 - (targetLayer * minDistance);
          y = layerY;
        }

        // 상단 경계 체크
        if (y < topY + dollSize) {
          continue; // 상단 경계를 넘으면 다시 시도
        }

        // X 경계 체크 (타원형 경계 내부인지 확인)
        final distanceFromCenterX = (x - centerX).abs();
        if (distanceFromCenterX > innerHalfWidth * 0.95) {
          continue; // 경계를 넘으면 다시 시도
        }

        // 랜덤 이미지 선택
        final imageIndex = random.nextInt(dollImages.length);

        // 랜덤 회전 (자연스럽게 엉켜있는 느낌)
        final rotationAngle =
            random.nextDouble() * pi * 0.6 - pi * 0.3; // -0.3π ~ 0.3π

        // Static 인형 컴포넌트 생성
        final doll = StaticDollComponent(
          position: flame.Vector2(x, y),
          imagePath: dollImages[imageIndex],
          size: flame.Vector2.all(dollSize),
          angle: rotationAngle,
        );

        // 상단 경계 설정
        doll.setTopBoundary(topY);

        // 새 레이어 생성 (필요한 경우)
        if (targetLayer >= layers.length) {
          layers.add([]);
        }

        // 레이어에 추가
        layers[targetLayer].add(doll);
        add(doll);
        placed = true;
        successfullyPlaced++;
      }

      // 배치 실패 시 로그 출력
      if (!placed) {
        print(
            'Warning: Failed to place doll ${i + 1}/${dollCount} after $maxAttempts attempts');
        print(
            'Container area: topY=$topY, bottomY=$bottomY, innerHalfWidth=$innerHalfWidth');
      }
    }

    // 배치 결과 로그
    print(
        'Doll placement: $successfullyPlaced/$dollCount dolls placed successfully');

    // 모든 인형의 onLoad()가 완료될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// 통의 상단 Y 위치 계산 (containerOffsetY 적용)
  double get _containerTopY => containerTopMargin + containerOffsetY;

  /// 통의 하단 Y 위치 계산 (containerOffsetY 적용)
  double get _containerBottomY =>
      glassHeight - containerBottomMargin + containerOffsetY;

  /// 인형 개수 설정
  Future<void> setDollCount(int count) async {
    // onLoad()가 완료될 때까지 대기 (glassWidth 등이 초기화되어야 함)
    if (!_isLoaded) {
      // onLoad()가 완료될 때까지 대기
      // 최대 1초까지 기다림 (타임아웃 방지)
      int waitCount = 0;
      while (!_isLoaded && waitCount < 500) {
        await Future.delayed(const Duration(milliseconds: 50));
        waitCount++;
      }

      // 여전히 로드되지 않았으면 에러 (초기화 문제)
      if (!_isLoaded) {
        print('Warning: setDollCount called before onLoad completed');
        return; // 조기 반환하여 에러 방지
      }
    }

    dollCount = count;

    // 기존 인형 제거
    children.whereType<StaticDollComponent>().forEach((doll) {
      doll.removeFromParent();
    });

    // 새로운 인형 배치 생성
    await _spawnStaticDolls();
  }

  /// 인형 재배치 (통 크기/위치 변경 시 사용)
  Future<void> reloadDolls() async {
    // 현재 dollCount로 다시 배치
    await setDollCount(dollCount);
  }

  /// 팝콘처럼 튀어오르는 애니메이션 시작
  void startPopcornAnimation() {
    final dolls = children.whereType<StaticDollComponent>().toList();
    print('startPopcornAnimation: found ${dolls.length} dolls');

    if (dolls.isEmpty) {
      print('Warning: No dolls found for popcorn animation');
      return;
    }

    final random = Random();

    // 인형들을 랜덤하게 섞어서 더 자연스러운 순서로 애니메이션 시작
    dolls.shuffle(random);

    // 각 인형마다 다른 타이밍으로 애니메이션 시작
    for (int i = 0; i < dolls.length; i++) {
      final doll = dolls[i];
      // 더 짧은 지연 시간: 0~0.2초 사이에 분산 (더 빠르게 시작)
      final delay = random.nextDouble() * 0.2;
      doll.startBounceAnimation(delay: delay);
    }

    print('Popcorn animation started for ${dolls.length} dolls');
  }

  /// 애니메이션 리셋 (원래 위치로 복귀)
  void resetAnimation() {
    final dolls = children.whereType<StaticDollComponent>().toList();
    for (final doll in dolls) {
      doll.resetToOriginalPosition();
    }
  }
}

/// 정적 인형 컴포넌트 (물리 연산 없음)
class StaticDollComponent extends flame.Component
    with flame.HasGameRef<GachaPhysicsGame> {
  final String imagePath;
  final flame.Vector2 size;
  final flame.Vector2 position; // 원래 위치
  final double angle; // 원래 회전 각도
  flame.SpriteComponent? spriteComponent;

  // 애니메이션 관련
  double _animationProgress = 0.0;
  bool _isAnimating = false;
  double _bounceHeight = 0.0; // 튀어오르는 높이 (랜덤)
  double _delay = 0.0; // 애니메이션 지연 시간 (외부에서 설정)
  double _horizontalOffset = 0.0; // 수평 이동 (랜덤)
  double _rotationOffset = 0.0; // 회전 오프셋
  double _animationSpeed = 1.0; // 애니메이션 속도 (랜덤)
  int _bounceCount = 1; // 튀어오르는 횟수 (1~3회)
  double _topBoundary = 0.0; // 상단 경계 (게임에서 설정)

  StaticDollComponent({
    required this.position,
    required this.imagePath,
    required this.size,
    required this.angle,
  }) {
    // 각 인형마다 랜덤한 애니메이션 속성 설정
    final random = Random();
    _bounceHeight = random.nextDouble() * 80.0 + 40.0; // 40~120px (적당한 높이)
    _horizontalOffset = (random.nextDouble() - 0.5) * 30.0; // -15~15px (적당한 범위)
    _rotationOffset =
        (random.nextDouble() - 0.5) * 0.6; // -0.3~0.3 라디안 (적당한 회전)
    _animationSpeed = random.nextDouble() * 0.2 + 0.8; // 0.8~1.0배속 (적당한 속도)
    _bounceCount = random.nextInt(2) + 1; // 1~2회 튀어오르기 (더 간단하게)
  }

  /// 상단 경계 설정 (게임에서 호출)
  void setTopBoundary(double topY) {
    _topBoundary = topY + 20.0; // 상단 20px 마진
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 이미지 로드
    try {
      final sprite = await gameRef.loadSprite(imagePath);
      spriteComponent = flame.SpriteComponent(
        sprite: sprite,
        size: size,
        anchor: flame.Anchor.center,
        position: position,
        angle: angle,
      );
      add(spriteComponent!);
    } catch (e) {
      // 이미지 로드 실패 시 에러 처리
      print('Failed to load background doll image: $imagePath, error: $e');
      // 기본 아이콘으로 대체 시도
      try {
        final fallbackSprite = await gameRef.loadSprite('gacha_doll_1.webp');
        spriteComponent = flame.SpriteComponent(
          sprite: fallbackSprite,
          size: size,
          anchor: flame.Anchor.center,
          position: position,
          angle: angle,
        );
        add(spriteComponent!);
      } catch (e2) {
        print('Failed to load fallback image: $e2');
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isAnimating && spriteComponent != null) {
      // 애니메이션 진행도 업데이트 (속도 적용 - 더 빠르게)
      _animationProgress += dt * 1.0 * _animationSpeed;

      // 지연 시간 고려
      double effectiveProgress = _animationProgress - _delay;
      if (effectiveProgress < 0) {
        // 지연 중일 때는 약간의 준비 동작 (살짝 떨림)
        final shakeAmount = sin(_animationProgress * pi * 8) * 2.0;
        spriteComponent!.position = flame.Vector2(
          position.x + shakeAmount,
          position.y,
        );
        return;
      }

      // 애니메이션 완료 체크 (튀어오르는 횟수에 따라 다름)
      final totalDuration =
          0.8 * _bounceCount + 0.2; // 각 튀어오르기 0.8초 + 떨어지는 시간 0.2초 (더 빠르게)
      if (effectiveProgress > totalDuration) {
        _isAnimating = false;
        _animationProgress = 0.0;
        resetToOriginalPosition();
        return;
      }

      // 여러 번 튀어오르는 효과 계산
      double bounceValue = 0.0;
      final bounceDuration = 0.8; // 각 튀어오르기 지속 시간 (더 빠르게)
      final bounceIndex = (effectiveProgress / bounceDuration).floor();
      final bounceProgress =
          (effectiveProgress % bounceDuration) / bounceDuration;

      if (bounceIndex < _bounceCount) {
        // 튀어오르는 단계
        if (bounceProgress < 0.5) {
          // 위로 튀어오르기 (0~50%) - 더 부드럽게
          final t = bounceProgress / 0.5;
          bounceValue =
              _bounceOutCurve(t) * _bounceHeight * (1.0 - bounceIndex * 0.3);
        } else {
          // 아래로 떨어지기 (50~100%) - 스무스하게 떨어지도록
          final t = (bounceProgress - 0.5) / 0.5;
          // easeIn 커브를 사용하여 자연스럽게 떨어지도록
          final easeInT = t * t; // 제곱 커브로 가속도 적용
          final peakHeight = _bounceHeight * (1.0 - bounceIndex * 0.3);
          bounceValue = peakHeight * (1.0 - easeInT);
        }
      } else {
        // 마지막 떨어지기 - 더 빠르게
        final fallProgress =
            (effectiveProgress - bounceDuration * _bounceCount) / 0.2;
        if (fallProgress < 1.0) {
          // easeIn 커브를 사용하여 자연스럽게 떨어지도록
          final easeInT = fallProgress * fallProgress; // 제곱 커브로 가속도 적용
          bounceValue = (1.0 - easeInT) * _bounceHeight * 0.3;
        }
      }

      // 수평 이동 (더 부드러운 움직임, 떨어질 때 감소)
      final isFalling = bounceIndex >= _bounceCount ||
          (bounceIndex < _bounceCount && bounceProgress > 0.5);
      final fallDamping = isFalling
          ? (1.0 - (effectiveProgress / totalDuration).clamp(0.0, 1.0))
          : 1.0;
      final horizontalMovement = sin(effectiveProgress * pi * 2) *
          _horizontalOffset *
          (0.5 + sin(effectiveProgress * pi * 1.5) * 0.5) *
          fallDamping;

      // 회전 효과 (더 부드러운 회전, 떨어질 때 감소)
      final rotationMovement = sin(effectiveProgress * pi * 1.5) *
          _rotationOffset *
          1.5 *
          fallDamping;

      // 최종 위치 계산
      final newX = position.x + horizontalMovement;
      var newY = position.y - bounceValue; // 위로 튀어오르므로 Y는 감소

      // 상단 경계 체크 (상단 20px 마진 유지)
      final minY = _topBoundary + size.y / 2;
      if (newY < minY) {
        newY = minY;
        bounceValue = position.y - minY; // 제한된 높이만큼만 튀어오름
      }

      final newAngle = angle + rotationMovement;

      spriteComponent!.position = flame.Vector2(newX, newY);
      spriteComponent!.angle = newAngle;
    }
  }

  /// BounceOut 커브 계산 (팝콘 튀어오르는 효과)
  double _bounceOutCurve(double t) {
    if (t < 1 / 2.75) {
      return 7.5625 * t * t;
    } else if (t < 2 / 2.75) {
      return 7.5625 * (t -= 1.5 / 2.75) * t + 0.75;
    } else if (t < 2.5 / 2.75) {
      return 7.5625 * (t -= 2.25 / 2.75) * t + 0.9375;
    } else {
      return 7.5625 * (t -= 2.625 / 2.75) * t + 0.984375;
    }
  }

  /// 튀어오르는 애니메이션 시작
  void startBounceAnimation({double delay = 0.0}) {
    _isAnimating = true;
    _animationProgress = 0.0;
    _delay = delay;
  }

  /// 원래 위치로 복귀
  void resetToOriginalPosition() {
    if (spriteComponent != null) {
      spriteComponent!.position = position;
      spriteComponent!.angle = angle;
    }
    _isAnimating = false;
    _animationProgress = 0.0;
  }
}
