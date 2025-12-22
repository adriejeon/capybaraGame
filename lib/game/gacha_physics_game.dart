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

  // 전경 인형 개수 (물리 적용)
  int dollCount = 5;
  
  // 배경 인형 개수 (고정, 물리 연산 없음)
  static const int backgroundDollCount = 20;
  
  // 인형 통 크기 비율 (한 곳에서 관리)
  // 이 값을 변경하면 통의 가로 크기가 변경됩니다
  // 0.60 = 좁게, 0.65 = 기본, 0.70 = 넓게, 0.80 = 매우 넓게
  static const double containerWidthRatio = 0.65;

  // 스폰 타이머 (dart:async의 Timer 사용)
  dart_async.Timer? _spawnTimer;
  int _spawnedCount = 0;
  
  // 얼음땡 전체 타이머: 게임 시작 후 일정 시간이 지나면 모든 인형을 Static으로 변환
  dart_async.Timer? _freezeAllTimer;
  double _gameStartTime = 0.0;

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

    // 배경 인형 생성 (고정, 물리 연산 없음)
    _spawnBackgroundDolls();

    // 전경 인형 스폰 (약간 지연시켜 경계가 먼저 생성되도록)
    await Future.delayed(const Duration(milliseconds: 100));
    _spawnInitialDolls();
    
    // 얼음땡 전체 타이머 시작: 게임 시작 후 1.5초가 지나면 모든 인형을 비활성화
    _gameStartTime = 0.0;
    _freezeAllTimer = dart_async.Timer(const Duration(milliseconds: 1500), () {
      _freezeAllDolls();
    });
  }

  /// 유리창 경계 생성 (보이지 않는 벽) - 원형/타원형 그릇 모양
  void _createGlassBoundaries() {
    // 유리구슬은 화면 중앙에 있고, 원형/타원형 경계를 만들어 인형이 동그란 통 안에 있도록 함

    // 게임 좌표계: (0,0)이 왼쪽 상단
    // glassCenterX_px = glassWidth / 2 (화면 중심 X)
    // glassCenterY_px = glassHeight / 2 (화면 중심 Y)

    // 좌우 폭을 더 좁혀서 가챠 배경 이미지의 유리구슬과 정확히 일치하도록
    final innerHalfWidth = (glassWidth / 2) * containerWidthRatio;

    // 상단 Y 위치 - 상단 경계를 완전히 막아서 인형이 위에 붙지 않도록
    final topY = 30.0; // 화면 상단에서 30px 아래 (마진 확보)

    // 하단 Y 위치 (바닥) - 아래 20px 마진을 확실히 확보
    final bottomY = glassHeight - 20.0; // 화면 하단에서 20px 위

    // 타원형 경계의 중심과 반지름
    final centerX = glassCenterX_px;
    final centerY = (topY + bottomY) / 2; // 상단과 하단의 중간
    final radiusX = innerHalfWidth; // 가로 반지름
    final radiusY = (bottomY - topY) / 2; // 세로 반지름

    // 원형/타원형 경계 점들 생성
    final List<Vector2> boundaryPoints = [];
    final segments = 120; // 원형을 더 부드럽게 만들기 위해 세그먼트 수 증가

    // 타원형 경계 생성 (시계 방향으로, 상단부터 시작)
    // 상단과 하단을 평평하게 막아서 인형이 경계 밖으로 나가지 않도록 함
    final segments = 100;
    
    // 상단 평평한 부분 (왼쪽에서 오른쪽으로)
    final topSegments = 20;
    for (int i = 0; i <= topSegments; i++) {
      final t = i / topSegments;
      final x = glassCenterX_px - innerHalfWidth + t * innerHalfWidth * 2;
      final y = topY; // 상단을 평평하게
      boundaryPoints.add(Vector2(x, y));
    }
    
    // 우측 벽 (타원형 곡선) - 상단에서 하단까지
    final rightSegments = 30;
    for (int i = 1; i <= rightSegments; i++) {
      final t = i / rightSegments; // 0.0 ~ 1.0
      // 각도: 0 (우측 상단)부터 -π (우측 하단)까지
      final angle = -t * pi;
      final x = centerX + radiusX * cos(angle);
      final y = centerY + radiusY * sin(angle);
      // Y 좌표를 상단과 하단 경계 내로 제한
      final clampedY = y.clamp(topY, bottomY);
      boundaryPoints.add(Vector2(x, clampedY));
    }
    
    // 하단 평평한 부분 (오른쪽에서 왼쪽으로)
    final bottomSegments = 20;
    for (int i = 0; i <= bottomSegments; i++) {
      final t = i / bottomSegments;
      final x = glassCenterX_px + innerHalfWidth - t * innerHalfWidth * 2;
      final y = bottomY; // 하단을 평평하게
      boundaryPoints.add(Vector2(x, y));
    }
    
    // 좌측 벽 (타원형 곡선) - 하단에서 상단까지
    final leftSegments = 30;
    for (int i = 1; i <= leftSegments; i++) {
      final t = i / leftSegments; // 0.0 ~ 1.0
      // 각도: -π (좌측 하단)부터 -2π (좌측 상단)까지
      final angle = -pi - t * pi;
      final x = centerX + radiusX * cos(angle);
      final y = centerY + radiusY * sin(angle);
      // Y 좌표를 상단과 하단 경계 내로 제한
      final clampedY = y.clamp(topY, bottomY);
      boundaryPoints.add(Vector2(x, clampedY));
    }

    // ChainShape로 전체 경계를 하나의 체인으로 생성
    // 각 선분을 EdgeShape로 생성
    for (int i = 0; i < boundaryPoints.length - 1; i++) {
      final edge = EdgeShape()..set(boundaryPoints[i], boundaryPoints[i + 1]);

      final bodyDef = BodyDef(
        type: BodyType.static,
        position: Vector2.zero(),
      );

      // 벽을 미끄럽게 만들기 (friction = 0.1)
      final fixtureDef = FixtureDef(edge)
        ..friction = 0.1 // 미끄러움 (인형이 바닥으로 잘 모이도록)
        ..restitution = 0.0; // 탄성 제거 (튕기지 않음)

      world.createBody(bodyDef)..createFixture(fixtureDef);
    }
  }

  /// 배경 인형 생성 (고정, 물리 연산 없음)
  void _spawnBackgroundDolls() {
    final random = Random();
    // 경계와 동일한 크기로 맞춤
    final innerHalfWidth = (glassWidth / 2) * containerWidthRatio;
    final bottomY = glassHeight - 20.0;

    for (int i = 0; i < backgroundDollCount; i++) {
      // 바닥 근처에 랜덤 배치 (쌓여있는 느낌)
      // bottomY를 절대 넘지 않도록 인형 크기의 반만큼 여유 공간 확보
      final dollRadius = dollSize / 2;
      final maxY = bottomY - dollRadius; // 인형이 bottomY를 넘지 않도록
      final normalizedY = random.nextDouble(); // 0.0 ~ 1.0
      final y = maxY - (normalizedY * normalizedY * glassHeight * 0.4); // 바닥에서 위로 분산
      
      // X 위치: 좌우로 넓게 분산하여 동그란 통의 왼쪽과 오른쪽에도 인형이 쌓이도록
      // 경계 내부 전체에 골고루 분산 (좌우 끝까지 포함)
      final x = glassCenterX_px + (random.nextDouble() - 0.5) * innerHalfWidth * 1.8;
      
      // 랜덤 이미지 선택
      final imageIndex = random.nextInt(dollImages.length);
      
      // 랜덤 회전
      final angle = random.nextDouble() * 2 * pi;
      
      // Static 인형 컴포넌트 생성 (물리 연산 없음)
      final backgroundDoll = StaticDollComponent(
        position: flame.Vector2(x, y),
        imagePath: dollImages[imageIndex],
        size: flame.Vector2.all(dollSize),
        angle: angle,
      );
      
      add(backgroundDoll);
    }
  }

  /// 초기 전경 인형 스폰 (물리 적용, 5개만)
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
    // 경계와 동일한 크기로 맞춤
    final innerHalfWidth = (glassWidth / 2) * containerWidthRatio;
    final topY = 30.0; // 상단 30px 마진 (경계와 일치)
    final bottomY = glassHeight - 20.0; // 하단 20px 마진

    // X 위치: 좌우로 넓게 분산하여 동그란 통의 왼쪽과 오른쪽에도 인형이 쌓이도록
    // 경계 내부 전체에 골고루 분산 (좌우 끝까지 포함하되 경계를 넘지 않도록)
    final spawnXRange = innerHalfWidth * 0.9; // 경계를 약간 안쪽으로 제한
    final spawnX =
        glassCenterX_px + (random.nextDouble() - 0.5) * spawnXRange * 2;

    // Y 위치: 무조건 상단에서만 스폰하여 아래로 떨어지게 함
    // 상단 경계 바로 아래에서 스폰 (topY + 충분한 여유 공간)
    final spawnMargin = dollSize * 0.5; // 상단 경계에서 충분한 여유 공간
    final spawnY = topY + spawnMargin; // 상단에서만 스폰 (항상 동일한 높이)
    
    // 스폰 위치가 경계 내부인지 확인하고 조정
    final distanceFromCenter = (spawnX - glassCenterX_px).abs();
    final finalSpawnX = distanceFromCenter > innerHalfWidth * 0.95
        ? glassCenterX_px + (spawnX > glassCenterX_px ? 1 : -1) * innerHalfWidth * 0.9
        : spawnX;

    // 랜덤 이미지 선택
    final imageIndex = random.nextInt(dollImages.length);

    final doll = DollComponent(
      position: Vector2(finalSpawnX, spawnY),
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
    final innerHalfWidth = (glassWidth / 2) * containerWidthRatio;

    // X: 좌우로 넓게 분산하여 동그란 통의 왼쪽과 오른쪽에도 인형이 쌓이도록
    // 경계 내부 전체에 골고루 분산 (좌우 끝까지 포함하되 경계를 넘지 않도록)
    final topY = 30.0; // 상단 30px 마진 (경계와 일치)
    final spawnXRange = innerHalfWidth * 0.9; // 경계를 약간 안쪽으로 제한
    final spawnX =
        glassCenterX_px + (random.nextDouble() - 0.5) * spawnXRange * 2;

    // Y: 무조건 상단에서만 스폰하여 아래로 떨어지게 함
    final spawnMargin = dollSize * 0.5; // 상단 경계에서 충분한 여유 공간
    final spawnY = topY + spawnMargin; // 상단에서만 스폰 (항상 동일한 높이)
    
    // 스폰 위치가 경계 내부인지 확인하고 조정
    final distanceFromCenter = (spawnX - glassCenterX_px).abs();
    final finalSpawnX = distanceFromCenter > innerHalfWidth * 0.95
        ? glassCenterX_px + (spawnX > glassCenterX_px ? 1 : -1) * innerHalfWidth * 0.9
        : spawnX;

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

  /// 모든 인형 제거 (전경 인형만 제거, 배경은 유지)
  void clearDolls() {
    // 스폰 타이머 취소
    _spawnTimer?.cancel();
    _spawnTimer = null;
    _spawnedCount = 0;
    
    // 얼음땡 타이머 취소
    _freezeAllTimer?.cancel();
    _freezeAllTimer = null;

    // 전경 인형만 제거 (Dynamic Body)
    children.whereType<DollComponent>().forEach((doll) {
      doll.removeFromParent();
    });
  }
  
  /// 모든 인형을 Static으로 변환 (얼음땡 - 확실한 방법)
  void _freezeAllDolls() {
    children.whereType<DollComponent>().forEach((doll) {
      doll.freeze(); // DollComponent의 freeze 메서드 호출
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
  
  // 얼음땡 로직: 정지 시간 추적
  double _timeSinceStop = 0.0;
  bool _isFrozen = false; // Static으로 변환되었는지 여부

  DollComponent({
    required Vector2 position, // forge2d의 Vector2 (물리 바디 위치)
    required this.imagePath,
    required this.size, // flame의 Vector2 (스프라이트 크기)
  }) : super(
          bodyDef: BodyDef(
            type: BodyType.dynamic, // 동적 바디 (인형이 떨어지도록)
            position: position,
            angle: Random().nextDouble() * 2 * pi, // 랜덤 회전
            linearDamping: 0.5, // 바닥에 닿은 뒤 미세하게 미끄러지는 힘을 빨리 없애줌
            angularDamping: 0.5, // 회전 저항 적당히
            allowSleep: true, // 인형이 정지하면 Sleep 상태로 전환 (지터링 방지)
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

    // 동적 바디 물리 속성 설정 (5개를 위한 최적화)
    final fixtureDef = FixtureDef(shape)
      ..density = 2.0 // 높은 밀도 (너무 가볍게 날아다니지 않도록)
      ..friction = 0.3 // 마찰력 (인형끼리는 적당히)
      ..restitution = 0.05; // 반발력 (거의 안 튀김)

    body.createFixture(fixtureDef);

    // 초기 속도 제거 (바닥에 안정적으로 놓이도록)
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0.0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 상단에 떠 있는 인형을 강제로 아래로 내리기
    if (body.isActive) {
      final topY = 30.0; // 상단 경계 (30px 마진)
      final currentY = body.position.y;
      final dollRadius = size.x / 2;
      
      // 인형이 상단 경계 위에 있거나 상단 경계 근처에 붙어있으면 강제로 아래로 내림
      if (currentY < topY + dollRadius * 2) {
        // 아래쪽으로 강한 힘을 가해서 떨어지게 함
        final currentVelocity = body.linearVelocity;
        // Y 속도를 강제로 아래 방향으로 설정
        body.linearVelocity = Vector2(currentVelocity.x * 0.5, max(currentVelocity.y, 100.0));
      }
    }

    // 얼음땡 로직: 정지한 인형을 비활성화 (지터링 완전 제거)
    if (!_isFrozen && body.isActive) {
      final velocity = body.linearVelocity;
      final speed = velocity.length;
      final angularSpeed = body.angularVelocity.abs();
      
      // 속도가 아주 느려진 상태 (0.2 미만) 체크 (더 빠르게 감지)
      if (speed < 0.2 && angularSpeed < 0.2) {
        _timeSinceStop += dt;
        
        // 0.2초 이상 정지 상태가 유지되면 Body 비활성화 (더 빠르게 얼음땡)
        if (_timeSinceStop >= 0.2) {
          _freezeBody();
        }
      } else {
        // 움직이고 있으면 타이머 리셋
        _timeSinceStop = 0.0;
      }
    }

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
  
  /// 인형을 비활성화 (얼음땡 - 완전히 고정)
  /// 외부에서도 호출 가능 (게임 레벨의 전체 타이머에서 사용)
  void freeze() {
    if (_isFrozen || !body.isActive) {
      return;
    }
    
    _freezeBody();
  }
  
  /// 내부 메서드: Body를 비활성화하여 물리 계산에서 제외
  void _freezeBody() {
    // 속도 완전히 제거
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0.0;
    
    // Body 비활성화 (물리 엔진이 더 이상 위치를 계산하지 않음)
    body.setActive(false);
    _isFrozen = true;
    
    // Body가 비활성화되면 물리 엔진이 위치를 업데이트하지 않으므로
    // 지터링이 완전히 사라짐 (0.0% 움직임)
  }
}

/// 배경 인형 컴포넌트 (고정, 물리 연산 없음)
class StaticDollComponent extends Component with HasGameRef<GachaPhysicsGame> {
  final String imagePath;
  final flame.Vector2 size;
  final flame.Vector2 position;
  final double angle;
  SpriteComponent? spriteComponent;

  StaticDollComponent({
    required this.position,
    required this.imagePath,
    required this.size,
    required this.angle,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 이미지 로드
    try {
      final sprite = await gameRef.loadSprite(imagePath);
      spriteComponent = SpriteComponent(
        sprite: sprite,
        size: size,
        anchor: Anchor.center,
        position: position,
        angle: angle,
      );
      add(spriteComponent!);
    } catch (e) {
      // 이미지 로드 실패 시 에러 처리
      print('Failed to load background doll image: $imagePath, error: $e');
      // 기본 아이콘으로 대체 시도
      try {
        final fallbackSprite = await gameRef.loadSprite('gacha_doll_1.png');
        spriteComponent = SpriteComponent(
          sprite: fallbackSprite,
          size: size,
          anchor: Anchor.center,
          position: position,
          angle: angle,
        );
        add(spriteComponent!);
      } catch (e2) {
        print('Failed to load fallback image: $e2');
      }
    }
  }
}
