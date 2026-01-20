import '../../utils/constants.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

/// 숨은 그림 위치 (0.0 ~ 1.0 비율 좌표)
class HiddenSpot {
  final double x; // 0.0 ~ 1.0 (이미지 너비 기준 비율, 중심점)
  final double y; // 0.0 ~ 1.0 (이미지 높이 기준 비율, 중심점)
  final double radius; // 0.0 ~ 1.0 (터치 허용 반경, 이미지 너비 기준)
  final double? width; // 0.0 ~ 1.0 (이미지 너비 기준 비율, null이면 radius 기반으로 계산)
  final double? height; // 0.0 ~ 1.0 (이미지 높이 기준 비율, null이면 radius 기반으로 계산)

  const HiddenSpot({
    required this.x,
    required this.y,
    this.radius = 0.08, // 기본 터치 허용 반경 8%
    this.width,
    this.height,
  });

  /// 실제 너비 (비율 좌표) - width가 없으면 radius * 2 사용
  double get actualWidth => width ?? (radius * 2);

  /// 실제 높이 (비율 좌표) - height가 없으면 radius * 2 사용
  double get actualHeight => height ?? (radius * 2);

  /// JSON에서 HiddenSpot 생성 (픽셀 단위를 비율로 자동 변환)
  /// 
  /// JSON 데이터 구조:
  /// - x, y: 좌측 상단 픽셀 좌표
  /// - width, height: 픽셀 단위 크기
  /// - center_x, center_y: 중심점 픽셀 좌표
  /// - relative_x, relative_y: 중심점 비율 좌표 (0.0 ~ 1.0) - 이 값 사용
  /// - relative_radius: 비율 반경
  factory HiddenSpot.fromJson(Map<String, dynamic> json) {
    // relative_x, relative_y는 이미 비율 좌표 (중심점)이므로 직접 사용
    final relativeX = (json['relative_x'] as num?)?.toDouble();
    final relativeY = (json['relative_y'] as num?)?.toDouble();
    
    if (relativeX == null || relativeY == null) {
      throw ArgumentError('relative_x and relative_y are required in JSON');
    }
    
    final relativeRadius = (json['relative_radius'] as num?)?.toDouble() ?? 0.08;

    // width, height 처리 (픽셀 단위를 비율로 변환)
    double? widthRatio;
    double? heightRatio;

    if (json['width'] != null) {
      final widthValue = (json['width'] as num).toDouble();
      
      // 값이 1.0보다 크면 픽셀 단위로 간주하고 비율로 변환
      if (widthValue > 1.0) {
        // 기준 해상도 역산: center_x / relative_x = baseWidth
        double baseWidth = 1024.0; // 기본값 (fallback)
        
        if (json['center_x'] != null && relativeX > 0) {
          final centerX = (json['center_x'] as num).toDouble();
          baseWidth = centerX / relativeX;
        }
        
        widthRatio = widthValue / baseWidth;
        
        // 변환 결과가 1.0을 초과하면 안 됨 (검증)
        if (widthRatio! > 1.0) {
          print('[Warning] widthRatio > 1.0: $widthRatio, 원본 width: $widthValue, baseWidth: $baseWidth');
          widthRatio = 1.0; // 최대값으로 제한
        }
      } else {
        // 이미 비율 좌표 (0.0 ~ 1.0)
        widthRatio = widthValue;
      }
    }

    if (json['height'] != null) {
      final heightValue = (json['height'] as num).toDouble();
      
      // 값이 1.0보다 크면 픽셀 단위로 간주하고 비율로 변환
      if (heightValue > 1.0) {
        // 기준 해상도 역산: center_y / relative_y = baseHeight
        double baseHeight = 572.0; // 기본값 (fallback)
        
        if (json['center_y'] != null && relativeY > 0) {
          final centerY = (json['center_y'] as num).toDouble();
          baseHeight = centerY / relativeY;
        }
        
        heightRatio = heightValue / baseHeight;
        
        // 변환 결과가 1.0을 초과하면 안 됨 (검증)
        if (heightRatio! > 1.0) {
          print('[Warning] heightRatio > 1.0: $heightRatio, 원본 height: $heightValue, baseHeight: $baseHeight');
          heightRatio = 1.0; // 최대값으로 제한
        }
      } else {
        // 이미 비율 좌표 (0.0 ~ 1.0)
        heightRatio = heightValue;
      }
    }

    return HiddenSpot(
      x: relativeX,
      y: relativeY,
      radius: relativeRadius,
      width: widthRatio,
      height: heightRatio,
    );
  }
}

/// 숨은그림찾기 스테이지 데이터
class HiddenPictureStage {
  final int stage; // 스테이지 (1~9)
  final String image; // 이미지 경로
  final List<HiddenSpot> spots; // 숨은 그림 위치들
  final int timeLimit; // 시간 제한 (초)
  final int spotCount; // 찾아야 할 숨은 그림 개수
  final String characterImage; // 찾아야 하는 캐릭터 이미지 경로

  const HiddenPictureStage({
    required this.stage,
    required this.image,
    required this.spots,
    required this.timeLimit,
    required this.spotCount,
    required this.characterImage,
  });
}

/// 숨은그림찾기 데이터 관리자
class HiddenPictureDataManager {
  static final HiddenPictureDataManager _instance =
      HiddenPictureDataManager._internal();
  factory HiddenPictureDataManager() => _instance;
  HiddenPictureDataManager._internal();

  /// 스테이지 개수 (1~9)
  static const int totalStages = 9;

  /// 시간 제한 (모든 스테이지 동일)
  static const int timeLimit = 90; // 1분 30초 (90초)

  /// 찾아야 할 숨은 그림 개수 (모든 스테이지 동일)
  static const int spotCount = 5; // 5개

  /// JSON 파일에서 스팟 데이터 로드
  Future<List<HiddenSpot>?> _loadSpotsFromJson(int stage) async {
    final jsonPath = 'assets/hidden_json/$stage-stage.json';
    
    try {
      final jsonString = await rootBundle.loadString(jsonPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => HiddenSpot.fromJson(json)).toList();
    } catch (e) {
      print('[HiddenPicture] JSON 파일 로드 실패: $jsonPath - $e');
      return null;
    }
  }

  /// 스테이지별 캐릭터 이미지 경로 가져오기
  String _getCharacterImageForStage(int stage) {
    switch (stage) {
      case 1:
        return 'assets/capybara/blue3.webp';
      case 2:
        return 'assets/capybara/blue4.webp';
      case 3:
        return 'assets/capybara/black1.webp';
      case 4:
        return 'assets/capybara/black2.webp';
      case 5:
        return 'assets/capybara/blue2.webp';
      case 6:
        return 'assets/capybara/black3.webp';
      case 7:
        return 'assets/capybara/blue1.webp';
      case 8:
        return 'assets/capybara/brown1.webp';
      case 9:
        return 'assets/capybara/brown2.webp';
      default:
        return 'assets/capybara/blue3.webp'; // 기본값
    }
  }

  /// 스테이지 데이터 가져오기 (JSON에서 로드)
  Future<HiddenPictureStage?> getStage(int stage) async {
    if (stage < 1 || stage > totalStages) {
      return null;
    }
    
    // JSON 파일에서 로드 시도
    final jsonSpots = await _loadSpotsFromJson(stage);
    if (jsonSpots != null && jsonSpots.isNotEmpty) {
      print('[HiddenPicture] JSON에서 로드: $stage-stage (${jsonSpots.length}개 스팟)');
      return HiddenPictureStage(
        stage: stage,
        image: 'assets/hidden/$stage-stage.png',
        spots: jsonSpots,
        timeLimit: timeLimit,
        spotCount: spotCount,
        characterImage: _getCharacterImageForStage(stage),
      );
    }
    
    // JSON이 없으면 null 반환
    print('[HiddenPicture] JSON 파일이 없습니다: $stage-stage');
    return null;
  }

  /// 모든 스테이지 가져오기
  Future<List<HiddenPictureStage>> getAllStages() async {
    final stages = <HiddenPictureStage>[];

    for (int i = 1; i <= totalStages; i++) {
      final stage = await getStage(i);
      if (stage != null) {
        stages.add(stage);
      }
    }

    return stages;
  }

  /// 다음 스테이지 ID 계산 (1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → null)
  static int? getNextStageId(int currentStage) {
    if (currentStage >= 1 && currentStage < totalStages) {
      return currentStage + 1;
    }
    return null; // 마지막 스테이지
  }

  /// 이전 스테이지 ID 계산 (9 → 8 → 7 → 6 → 5 → 4 → 3 → 2 → 1 → null)
  static int? getPreviousStageId(int currentStage) {
    if (currentStage > 1 && currentStage <= totalStages) {
      return currentStage - 1;
    }
    return null; // 첫 번째 스테이지
  }
}
