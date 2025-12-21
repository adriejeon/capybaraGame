import 'dart:async' as dart_async;
import 'dart:math';
import 'package:flame/components.dart' hide Vector2;
import 'package:flame/components.dart' as flame show Vector2;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../utils/gacha_glass_constants.dart';

/// 가챠 통 물리 시뮬레이션 게임
class GachaPhysicsGame extends Forge2DGame {
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

  // 인형 개수
  int dollCount = 25;

  // 스폰 타이머 (dart:async의 Timer 사용)
  dart_async.Timer? _spawnTimer;
  int _spawnedCount = 0;

  // 고정 해상도 (선택적)
  final flame.Vector2? _fixedResolution;

  // 게임 크기 설정
  GachaPhysicsGame({flame.Vector2? fixedResolution})
      : _fixedResolution = fixedResolution,
        super(
          gravity: Vector2(0, 2000.0), // 중력 강화 (픽셀 단위에 맞게 매우 강하게)
          zoom: 1.0,
        );

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

    // 유리창 경계 생성
    _createGlassBoundaries();

    // 초기 인형 스폰 (약간 지연시켜 경계가 먼저 생성되도록)
    await Future.delayed(const Duration(milliseconds: 100));
    _spawnInitialDolls();
  }

  /// 유리창 경계 생성 (보이지 않는 벽) - 깊은 U자형 그릇 모양
  void _createGlassBoundaries() {
    // 유리구슬은 화면 중앙에 있고, 너비는 화면의 약 70%
    // 깊은 U자 형태의 경계를 만들어 인형이 바닥 중앙으로 모이도록 함

    // 게임 좌표계: (0,0)이 왼쪽 상단
    // glassCenterX_px = glassWidth / 2 (화면 중심 X)
    // glassCenterY_px = glassHeight / 2 (화면 중심 Y)

    // 좌우 폭을 좁혀서 유리구슬 안쪽에 인형이 갇히도록 (80% 정도로 좁힘)
    final innerHalfWidth = (glassWidth / 2) * 0.80;

    // 상단 Y 위치 (인형이 떨어지는 시작점) - 상단은 뚫려있어야 함
    final topY = glassHeight * 0.05; // 화면 상단에서 5% 아래

    // 하단 Y 위치 (바닥) - 분홍색 받침대 바로 위까지 깊숙하게 내리기
    // 화면 하단에서 더 깊게 내려가도록 설정
    final bottomY = glassHeight - 5.0; // 화면 하단에서 5px 위 (더 깊게)

    // U자 형태의 경계 점들 생성
    final List<Vector2> boundaryPoints = [];

    // 좌측 벽 (위에서 아래로) - 유리구슬 외곽선을 따라
    final leftWallSegments = 40;
    for (int i = 0; i <= leftWallSegments; i++) {
      final t = i / leftWallSegments; // 0.0 ~ 1.0
      // 좌측 벽: 약간 곡선 형태로 안쪽으로 휘어짐
      final curveFactor = sin(t * pi) * 0.05; // 곡선 효과 (5% 정도)
      final x = glassCenterX_px - innerHalfWidth * (1 - curveFactor);
      final y = topY + t * (bottomY - topY);
      boundaryPoints.add(Vector2(x, y));
    }

    // 바닥 (깊은 U자 곡선) - 좌측에서 우측으로
    // 중앙이 가장 깊고, 좌우로 올라가는 U자 모양
    final bottomSegments = 50;
    for (int i = 0; i <= bottomSegments; i++) {
      final t = i / bottomSegments; // 0.0 ~ 1.0
      // U자 곡선: 중앙이 가장 깊고 좌우로 올라감
      final normalizedX = (t - 0.5) * 2; // -1.0 ~ 1.0
      final curveHeight = normalizedX * normalizedX; // 포물선 형태 (0.0 ~ 1.0)
      final x = glassCenterX_px - innerHalfWidth + t * innerHalfWidth * 2;
      // 바닥 중앙이 가장 깊고, 좌우로 갈수록 올라감 (U자 모양)
      // 중앙 깊이: bottomY에서 추가로 15% 더 깊게
      final y = bottomY + curveHeight * (glassHeight * 0.15);
      boundaryPoints.add(Vector2(x, y));
    }

    // 우측 벽 (아래에서 위로) - 유리구슬 외곽선을 따라
    final rightWallSegments = 40;
    for (int i = rightWallSegments; i >= 0; i--) {
      final t = i / rightWallSegments; // 1.0 ~ 0.0
      // 우측 벽: 약간 곡선 형태로 안쪽으로 휘어짐
      final curveFactor = sin(t * pi) * 0.05; // 곡선 효과 (5% 정도)
      final x = glassCenterX_px + innerHalfWidth * (1 - curveFactor);
      final y = topY + t * (bottomY - topY);
      boundaryPoints.add(Vector2(x, y));
    }

    // ChainShape로 전체 경계를 하나의 체인으로 생성
    // 각 선분을 EdgeShape로 생성
    for (int i = 0; i < boundaryPoints.length - 1; i++) {
      final edge = EdgeShape()..set(boundaryPoints[i], boundaryPoints[i + 1]);

      final bodyDef = BodyDef(
        type: BodyType.static,
        position: Vector2.zero(),
      );

      // 벽을 얼음판처럼 미끄럽게 만들기 (friction = 0.0)
      final fixtureDef = FixtureDef(edge)
        ..friction = 0.0 // 완전 미끄러움 (인형이 벽에 달라붙지 않음)
        ..restitution = 0.0; // 탄성 제거 (튕기지 않음)

      world.createBody(bodyDef)..createFixture(fixtureDef);
    }
  }

  /// 초기 인형 스폰 (Timer.periodic을 사용하여 순차적으로 생성)
  void _spawnInitialDolls() async {
    // 약간의 지연을 두고 스폰 (경계가 완전히 생성된 후)
    await Future.delayed(const Duration(milliseconds: 200));

    // 기존 타이머가 있으면 취소
    _spawnTimer?.cancel();
    _spawnedCount = 0;

    // Timer.periodic을 사용하여 0.1초마다 인형을 하나씩 생성
    _spawnTimer =
        dart_async.Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_spawnedCount >= dollCount) {
        // 모든 인형을 생성했으면 타이머 취소
        timer.cancel();
        _spawnTimer = null;
        return;
      }

      // 인형 하나 생성
      _spawnSingleDoll();
      _spawnedCount++;
    });
  }

  /// 인형 하나 생성 (겹치지 않도록 위치 분산)
  void _spawnSingleDoll() {
    final random = Random();

    // 인형들이 겹치지 않도록 X축과 Y축으로 분산 배치
    final innerHalfWidth = (glassWidth / 2) * 0.80;
    final topY = glassHeight * 0.1; // 상단 10% 영역
    final spawnHeight = glassHeight * 0.3; // 스폰 영역 높이 (상단 30%)

    // X 위치: 유리통 너비 전체에 골고루 분산
    final spawnX =
        glassCenterX_px + (random.nextDouble() - 0.5) * innerHalfWidth * 1.8;

    // Y 위치: 세로로도 간격을 두어 배치 (겹치지 않게)
    // 생성된 인형 수에 따라 높이 분산
    final yOffset = (_spawnedCount % 5) * (dollSize * 0.3);
    final spawnY = topY + (random.nextDouble() * spawnHeight * 0.3) + yOffset;

    // 랜덤 이미지 선택
    final imageIndex = random.nextInt(dollImages.length);

    final doll = DollComponent(
      position: Vector2(spawnX, spawnY),
      imagePath: dollImages[imageIndex],
      size: flame.Vector2.all(dollSize),
    );

    add(doll);
  }

  /// 인형 하나 스폰
  void _spawnDoll() {
    final random = Random();

    // 스폰 위치 (유리창 안의 랜덤 위치)
    // 게임 좌표계는 (0,0)이 왼쪽 상단
    // glassCenterX_px는 게임 화면의 중심 X
    // glassCenterY_px는 게임 화면의 중심 Y

    // 경계 내부에 스폰하도록 좁힌 폭 사용 (경계와 동일한 폭)
    final innerHalfWidth = (glassWidth / 2) * 0.80;

    // X: 중심 기준 좌우로 랜덤 분산 (경계 내부)
    final spawnX =
        glassCenterX_px + (random.nextDouble() - 0.5) * innerHalfWidth * 1.6;

    // Y: 상단에서 스폰 (인형이 떨어지도록)
    // 인형들이 위에서 떨어져서 바닥에 쌓이도록 상단에서 스폰
    final topY = glassHeight * 0.1; // 상단 10% 영역
    final spawnY =
        topY + random.nextDouble() * glassHeight * 0.2; // 상단 20% 영역에 랜덤 배치

    // 랜덤 이미지 선택
    final imageIndex = random.nextInt(dollImages.length);

    // 인형 컴포넌트 생성
    final doll = DollComponent(
      position: Vector2(spawnX, spawnY), // forge2d의 Vector2
      imagePath: dollImages[imageIndex],
      size: flame.Vector2.all(dollSize), // flame의 Vector2
    );

    add(doll);
  }

  /// 인형 추가 (외부에서 호출 가능)
  void addDoll() {
    _spawnDoll();
  }

  /// 모든 인형 제거
  void clearDolls() {
    // 스폰 타이머 취소
    _spawnTimer?.cancel();
    _spawnTimer = null;
    _spawnedCount = 0;

    children.whereType<DollComponent>().forEach((doll) {
      doll.removeFromParent();
    });
  }

  /// 인형 개수 설정
  void setDollCount(int count) {
    dollCount = count;
    clearDolls();
    _spawnInitialDolls();
  }
}

/// 인형 컴포넌트 (물리 바디 포함)
class DollComponent extends BodyComponent<GachaPhysicsGame> {
  final String imagePath;
  final flame.Vector2 size;
  SpriteComponent? spriteComponent;

  DollComponent({
    required Vector2 position, // forge2d의 Vector2 (물리 바디 위치)
    required this.imagePath,
    required this.size, // flame의 Vector2 (스프라이트 크기)
  }) : super(
          bodyDef: BodyDef(
            type: BodyType.dynamic, // 동적 바디 (인형이 떨어지도록)
            position: position,
            angle: Random().nextDouble() * 2 * pi, // 랜덤 회전
            linearDamping: 0.0, // 공기 저항 없음 (빠르게 떨어지도록)
          ),
          renderBody: false, // 충돌체 시각화 숨기기 (카피바라 이미지만 보이도록)
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 이미지 로드 - Flame의 loadSprite는 assets/images/를 기본 경로로 추가
    // 이미지가 미리 로드되어 있으므로 바로 사용
    try {
      final sprite = await game.loadSprite(imagePath);
      spriteComponent = SpriteComponent(
        sprite: sprite,
        size: size,
        anchor: Anchor.center,
      );
      add(spriteComponent!);
    } catch (e) {
      // 이미지 로드 실패 시 에러 처리
      print('Failed to load doll image: $imagePath, error: $e');
      // 기본 아이콘으로 대체 시도
      try {
        final fallbackSprite = await game.loadSprite('gacha_doll_1.png');
        spriteComponent = SpriteComponent(
          sprite: fallbackSprite,
          size: size,
          anchor: Anchor.center,
        );
        add(spriteComponent!);
      } catch (e2) {
        // 기본 이미지도 실패하면 빈 컴포넌트 생성하지 않음 (흰색 배경 방지)
        print('Failed to load fallback image: $e2');
        // spriteComponent를 생성하지 않으면 흰색 배경이 나타나지 않음
        // onLoad 실패 시 물리 바디만 생성하고 스프라이트는 추가하지 않음
      }
    }

    // 물리 바디 생성 (원형)
    // 충돌체 크기를 인형 이미지 크기의 80%로 축소 (자연스럽게 쌓이도록)
    final shape = CircleShape();
    shape.radius = (size.x / 2) * 0.8;

    // 동적 바디 물리 속성 설정
    final fixtureDef = FixtureDef(shape)
      ..density = 1.0 // 밀도 (묵직하게)
      ..friction = 0.3 // 마찰력 (인형끼리는 적당히 비벼지면서 쌓이도록)
      ..restitution = 0.02; // 반발력 (절대 튀어 오르지 않게, 0.0~0.05)

    body.createFixture(fixtureDef);

    // 초기 속도 부여 (아래쪽으로 힘을 받게)
    body.linearVelocity = Vector2(0, 20);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 스프라이트를 물리 바디 위치와 동기화
    // spriteComponent가 초기화되었는지 확인 (onLoad가 완료되었는지)
    if (spriteComponent != null) {
      try {
        // body.position은 forge2d의 Vector2, spriteComponent.position은 flame의 Vector2
        // 두 타입이 다르므로 명시적으로 변환
        final bodyPos = body.position;
        spriteComponent!.position = flame.Vector2(bodyPos.x, bodyPos.y);
        spriteComponent!.angle = body.angle;
      } catch (e) {
        // 위치 동기화 실패 시 무시
      }
    }
  }
}
