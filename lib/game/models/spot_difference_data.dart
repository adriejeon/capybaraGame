import '../../utils/constants.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

/// 틀린그림찾기 스팟 위치 (0.0 ~ 1.0 비율 좌표)
class DifferenceSpot {
  final double x; // 0.0 ~ 1.0 (이미지 너비 기준 비율, 중심점)
  final double y; // 0.0 ~ 1.0 (이미지 높이 기준 비율, 중심점)
  final double radius; // 0.0 ~ 1.0 (터치 허용 반경, 이미지 너비 기준) - 하위 호환성용
  final double? width; // 0.0 ~ 1.0 (이미지 너비 기준 비율, null이면 radius 기반으로 계산)
  final double? height; // 0.0 ~ 1.0 (이미지 높이 기준 비율, null이면 radius 기반으로 계산)

  const DifferenceSpot({
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

  /// JSON에서 DifferenceSpot 생성 (픽셀 단위를 비율로 자동 변환)
  /// 
  /// JSON 데이터 구조:
  /// - x, y: 좌측 상단 픽셀 좌표
  /// - width, height: 픽셀 단위 크기
  /// - center_x, center_y: 중심점 픽셀 좌표
  /// - relative_x, relative_y: 중심점 비율 좌표 (0.0 ~ 1.0) - 이 값 사용
  /// - relative_radius: 비율 반경
  factory DifferenceSpot.fromJson(Map<String, dynamic> json) {
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

    return DifferenceSpot(
      x: relativeX,
      y: relativeY,
      radius: relativeRadius,
      width: widthRatio,
      height: heightRatio,
    );
  }
}

/// 틀린그림찾기 스테이지 데이터
class SpotDifferenceStage {
  final int level; // 레벨 (1~5)
  final int stage; // 스테이지 (1~7)
  final String originalImage; // 원본 이미지 경로
  final String wrongImage; // 틀린그림 이미지 경로
  final List<DifferenceSpot> spots; // 틀린 부분 위치들
  final int timeLimit; // 시간 제한 (초)
  final int spotCount; // 찾아야 할 틀린그림 개수

  const SpotDifferenceStage({
    required this.level,
    required this.stage,
    required this.originalImage,
    required this.wrongImage,
    required this.spots,
    required this.timeLimit,
    required this.spotCount,
  });

  /// 레벨 이름 반환
  String get levelName {
    switch (level) {
      case 1:
        return '아기 단계';
      case 2:
        return '어린이 단계';
      case 3:
        return '청소년 단계';
      case 4:
        return '어른 단계';
      case 5:
        return '신의 경지';
      default:
        return '레벨 $level';
    }
  }

  /// GameDifficulty 반환
  GameDifficulty get difficulty {
    switch (level) {
      case 1:
        return GameDifficulty.level1;
      case 2:
        return GameDifficulty.level2;
      case 3:
        return GameDifficulty.level3;
      case 4:
        return GameDifficulty.level4;
      case 5:
        return GameDifficulty.level5;
      default:
        return GameDifficulty.level1;
    }
  }
}

/// 틀린그림찾기 데이터 관리자
class SpotDifferenceDataManager {
  static final SpotDifferenceDataManager _instance =
      SpotDifferenceDataManager._internal();
  factory SpotDifferenceDataManager() => _instance;
  SpotDifferenceDataManager._internal();

  /// 레벨별 스테이지 개수
  static const Map<int, int> stageCountByLevel = {
    1: 6, // 1-1 ~ 1-6 (1-7 제외)
    2: 6, // 2-1 ~ 2-6
    3: 6, // 3-1 ~ 3-6
    4: 6, // 4-1 ~ 4-6
    5: 7, // 5-1 ~ 5-7
  };

  /// 레벨별 시간 제한
  static const Map<int, int> timeLimitByLevel = {
    1: 60, // 60초
    2: 50, // 50초
    3: 45, // 45초
    4: 40, // 40초
    5: 35, // 35초
  };

  /// 레벨별 찾아야 할 틀린그림 개수
  static const Map<int, int> spotCountByLevel = {
    1: 3, // 3개
    2: 4, // 4개
    3: 5, // 5개
    4: 5, // 5개
    5: 6, // 6개
  };

  /// 모든 스테이지 데이터 (JSON 파일에서 변환된 스팟 데이터)
  /// diff_data.json의 픽셀 좌표를 비율 좌표로 변환하여 반영
  static final Map<String, List<DifferenceSpot>> _spotData = {
    // ========== 레벨 1 (아기 단계) ==========
    '1-1': [
      const DifferenceSpot(x: 0.5669, y: 0.7170, radius: 0.2000),
      const DifferenceSpot(x: 0.5928, y: 0.4410, radius: 0.2000),
      const DifferenceSpot(x: 0.0396, y: 0.3490, radius: 0.1320),
      const DifferenceSpot(x: 0.5151, y: 0.3038, radius: 0.2000),
      const DifferenceSpot(x: 0.3877, y: 0.1997, radius: 0.1464),
      const DifferenceSpot(x: 0.5649, y: 0.1102, radius: 0.2000),
      const DifferenceSpot(x: 0.3066, y: 0.5451, radius: 0.1464),
    ],
    '1-2': [
      const DifferenceSpot(x: 0.4946, y: 0.8802, radius: 0.0441),
      const DifferenceSpot(x: 0.4717, y: 0.7969, radius: 0.0441),
      const DifferenceSpot(x: 0.3726, y: 0.8073, radius: 0.2000),
      const DifferenceSpot(x: 0.6250, y: 0.6823, radius: 0.0441),
      const DifferenceSpot(x: 0.5132, y: 0.6259, radius: 0.0405),
      const DifferenceSpot(x: 0.5503, y: 0.5269, radius: 0.1794),
      const DifferenceSpot(x: 0.8091, y: 0.4983, radius: 0.2000),
      const DifferenceSpot(x: 0.3887, y: 0.1892, radius: 0.2000),
      const DifferenceSpot(x: 0.7915, y: 0.2135, radius: 0.2000),
    ],
    '1-3': [
      const DifferenceSpot(x: 0.1865, y: 0.6641, radius: 0.2000),
      const DifferenceSpot(x: 0.8203, y: 0.1276, radius: 0.1425),
      const DifferenceSpot(x: 0.9004, y: 0.0703, radius: 0.1650),
      const DifferenceSpot(x: 0.1387, y: 0.0694, radius: 0.2000),
      const DifferenceSpot(x: 0.0171, y: 0.0590, radius: 0.2000),
      const DifferenceSpot(x: 0.6191, y: 0.5573, radius: 0.1464),
    ],
    '1-4': [
      const DifferenceSpot(x: 0.2471, y: 0.7231, radius: 0.2000),
      const DifferenceSpot(x: 0.4062, y: 0.6701, radius: 0.2000),
      const DifferenceSpot(x: 0.1133, y: 0.4523, radius: 0.1170),
      const DifferenceSpot(x: 0.7202, y: 0.3594, radius: 0.1575),
      const DifferenceSpot(x: 0.6816, y: 0.2005, radius: 0.2000),
      const DifferenceSpot(x: 0.6919, y: 0.0547, radius: 0.1719),
      const DifferenceSpot(x: 0.4082, y: 0.1128, radius: 0.1464),
      const DifferenceSpot(x: 0.5879, y: 0.3993, radius: 0.1464),
    ],
    '1-5': [
      const DifferenceSpot(x: 0.5728, y: 0.9497, radius: 0.2000),
      const DifferenceSpot(x: 0.4771, y: 0.7413, radius: 0.2000),
      const DifferenceSpot(x: 0.6230, y: 0.7309, radius: 0.1245),
      const DifferenceSpot(x: 0.8135, y: 0.4566, radius: 0.1095),
      const DifferenceSpot(x: 0.9673, y: 0.4852, radius: 0.2000),
      const DifferenceSpot(x: 0.4185, y: 0.2205, radius: 0.2000),
      const DifferenceSpot(x: 0.0796, y: 0.0712, radius: 0.2000),
    ],
    '1-7': [
      const DifferenceSpot(x: 0.5527, y: 0.2135, radius: 0.1464),
      const DifferenceSpot(x: 0.4756, y: 0.4392, radius: 0.1464),
      const DifferenceSpot(x: 0.5508, y: 0.4340, radius: 0.1464),
      const DifferenceSpot(x: 0.4766, y: 0.5382, radius: 0.1464),
      const DifferenceSpot(x: 0.5166, y: 0.4757, radius: 0.1464),
      const DifferenceSpot(x: 0.9707, y: 0.4392, radius: 0.1464),
      const DifferenceSpot(x: 0.0898, y: 0.4861, radius: 0.1464),
      const DifferenceSpot(x: 0.8760, y: 0.5764, radius: 0.1464),
    ],

    // ========== 레벨 2 (어린이 단계) ==========
    '2-1': [
      const DifferenceSpot(x: 0.6934, y: 0.9497, radius: 0.2000),
      const DifferenceSpot(x: 0.9321, y: 0.8542, radius: 0.1650),
      const DifferenceSpot(x: 0.5142, y: 0.7951, radius: 0.2000),
      const DifferenceSpot(x: 0.2612, y: 0.4809, radius: 0.2000),
      const DifferenceSpot(x: 0.6431, y: 0.2656, radius: 0.2000),
      const DifferenceSpot(x: 0.8022, y: 0.1797, radius: 0.1866),
      const DifferenceSpot(x: 0.1787, y: 0.4010, radius: 0.1464),
      const DifferenceSpot(x: 0.9819, y: 0.1528, radius: 0.1464),
      const DifferenceSpot(x: 0.7422, y: 0.5469, radius: 0.1464),
    ],
    '2-2': [
      const DifferenceSpot(x: 0.5518, y: 0.7682, radius: 0.1650),
      const DifferenceSpot(x: 0.8433, y: 0.4141, radius: 0.2000),
      const DifferenceSpot(x: 0.9424, y: 0.4280, radius: 0.2000),
      const DifferenceSpot(x: 0.8184, y: 0.2387, radius: 0.2000),
      const DifferenceSpot(x: 0.9561, y: 0.0868, radius: 0.2000),
      const DifferenceSpot(x: 0.8682, y: 0.0564, radius: 0.2000),
      const DifferenceSpot(x: 0.6919, y: 0.0321, radius: 0.1575),
      const DifferenceSpot(x: 0.6260, y: 0.1927, radius: 0.1464),
      const DifferenceSpot(x: 0.7461, y: 0.0885, radius: 0.1464),
    ],
    '2-3': [
      const DifferenceSpot(x: 0.3560, y: 0.7023, radius: 0.1575),
      const DifferenceSpot(x: 0.1851, y: 0.5790, radius: 0.1209),
      const DifferenceSpot(x: 0.5430, y: 0.2752, radius: 0.2000),
      const DifferenceSpot(x: 0.7666, y: 0.6997, radius: 0.1464),
    ],
    '2-4': [
      const DifferenceSpot(x: 0.8413, y: 0.6953, radius: 0.1944),
      const DifferenceSpot(x: 0.6855, y: 0.6623, radius: 0.1539),
      const DifferenceSpot(x: 0.0664, y: 0.3793, radius: 0.2000),
      const DifferenceSpot(x: 0.5347, y: 0.4722, radius: 0.1755),
      const DifferenceSpot(x: 0.2734, y: 0.4592, radius: 0.1944),
      const DifferenceSpot(x: 0.4102, y: 0.4184, radius: 0.2000),
      const DifferenceSpot(x: 0.6030, y: 0.3906, radius: 0.2000),
      const DifferenceSpot(x: 0.1992, y: 0.5156, radius: 0.1464),
    ],
    '2-5': [
      const DifferenceSpot(x: 0.1680, y: 0.8064, radius: 0.2000),
      const DifferenceSpot(x: 0.3779, y: 0.7682, radius: 0.1095),
      const DifferenceSpot(x: 0.8213, y: 0.7292, radius: 0.0879),
      const DifferenceSpot(x: 0.2046, y: 0.5773, radius: 0.2000),
      const DifferenceSpot(x: 0.9204, y: 0.4253, radius: 0.2000),
      const DifferenceSpot(x: 0.6504, y: 0.2344, radius: 0.0954),
      const DifferenceSpot(x: 0.6885, y: 0.0825, radius: 0.0660),
      const DifferenceSpot(x: 0.8193, y: 0.1823, radius: 0.1464),
    ],
    '2-6': [
      const DifferenceSpot(x: 0.5347, y: 0.9288, radius: 0.2000),
      const DifferenceSpot(x: 0.9790, y: 0.7118, radius: 0.1575),
      const DifferenceSpot(x: 0.2129, y: 0.4132, radius: 0.1980),
      const DifferenceSpot(x: 0.7021, y: 0.3984, radius: 0.2000),
      const DifferenceSpot(x: 0.7871, y: 0.2309, radius: 0.1464),
      const DifferenceSpot(x: 0.7598, y: 0.3472, radius: 0.1464),
      const DifferenceSpot(x: 0.6279, y: 0.6493, radius: 0.1464),
    ],

    // ========== 레벨 3 (청소년 단계) ==========
    '3-1': [
      const DifferenceSpot(x: 0.2988, y: 0.8984, radius: 0.2000),
      const DifferenceSpot(x: 0.4429, y: 0.6250, radius: 0.1359),
      const DifferenceSpot(x: 0.7798, y: 0.4514, radius: 0.1245),
      const DifferenceSpot(x: 0.9590, y: 0.3776, radius: 0.1905),
      const DifferenceSpot(x: 0.4702, y: 0.1372, radius: 0.1719),
      const DifferenceSpot(x: 0.6719, y: 0.5330, radius: 0.1464),
    ],
    '3-2': [
      const DifferenceSpot(x: 0.3481, y: 0.9115, radius: 0.2000),
      const DifferenceSpot(x: 0.3892, y: 0.6849, radius: 0.1209),
      const DifferenceSpot(x: 0.5762, y: 0.7552, radius: 0.2000),
      const DifferenceSpot(x: 0.7368, y: 0.2995, radius: 0.1425),
      const DifferenceSpot(x: 0.6284, y: 0.0408, radius: 0.1209),
      const DifferenceSpot(x: 0.8892, y: 0.2648, radius: 0.2000),
    ],
    '3-3': [
      const DifferenceSpot(x: 0.2993, y: 0.6250, radius: 0.2000),
      const DifferenceSpot(x: 0.4482, y: 0.6476, radius: 0.2000),
      const DifferenceSpot(x: 0.0698, y: 0.5373, radius: 0.2000),
      const DifferenceSpot(x: 0.7295, y: 0.5243, radius: 0.1245),
      const DifferenceSpot(x: 0.7217, y: 0.3950, radius: 0.1650),
      const DifferenceSpot(x: 0.4966, y: 0.3438, radius: 0.2000),
      const DifferenceSpot(x: 0.3247, y: 0.1198, radius: 0.2000),
    ],
    '3-4': [
      const DifferenceSpot(x: 0.9893, y: 0.7378, radius: 0.1980),
      const DifferenceSpot(x: 0.3228, y: 0.3446, radius: 0.2000),
      const DifferenceSpot(x: 0.6558, y: 0.5382, radius: 0.1980),
      const DifferenceSpot(x: 0.8066, y: 0.3012, radius: 0.1539),
      const DifferenceSpot(x: 0.1353, y: 0.3090, radius: 0.2000),
      const DifferenceSpot(x: 0.4980, y: 0.6684, radius: 0.1464),
      const DifferenceSpot(x: 0.0195, y: 0.8507, radius: 0.1464),
    ],
    '3-5': [
      const DifferenceSpot(x: 0.9707, y: 0.5903, radius: 0.2000),
      const DifferenceSpot(x: 0.0767, y: 0.4826, radius: 0.2000),
      const DifferenceSpot(x: 0.3623, y: 0.4323, radius: 0.1980),
      const DifferenceSpot(x: 0.0283, y: 0.2292, radius: 0.2000),
      const DifferenceSpot(x: 0.9629, y: 0.2248, radius: 0.2000),
      const DifferenceSpot(x: 0.5537, y: 0.6823, radius: 0.1464),
    ],
    '3-6': [
      const DifferenceSpot(x: 0.3623, y: 0.7856, radius: 0.2000),
      const DifferenceSpot(x: 0.1357, y: 0.7326, radius: 0.2000),
      const DifferenceSpot(x: 0.8711, y: 0.7422, radius: 0.2000),
      const DifferenceSpot(x: 0.5137, y: 0.0677, radius: 0.2000),
      const DifferenceSpot(x: 0.1865, y: 0.7899, radius: 0.1464),
    ],

    // ========== 레벨 4 (어른 단계) ==========
    '4-1': [
      const DifferenceSpot(x: 0.7725, y: 0.9427, radius: 0.2000),
      const DifferenceSpot(x: 0.0820, y: 0.8828, radius: 0.2000),
      const DifferenceSpot(x: 0.5869, y: 0.4714, radius: 0.2000),
      const DifferenceSpot(x: 0.6914, y: 0.3672, radius: 0.1539),
      const DifferenceSpot(x: 0.3296, y: 0.2075, radius: 0.1866),
      const DifferenceSpot(x: 0.5474, y: 0.0712, radius: 0.2000),
      const DifferenceSpot(x: 0.6963, y: 0.6007, radius: 0.1464),
      const DifferenceSpot(x: 0.4854, y: 0.3611, radius: 0.1464),
    ],
    '4-2': [
      const DifferenceSpot(x: 0.5112, y: 0.7882, radius: 0.2000),
      const DifferenceSpot(x: 0.0522, y: 0.5556, radius: 0.2000),
      const DifferenceSpot(x: 0.7798, y: 0.3012, radius: 0.2000),
      const DifferenceSpot(x: 0.2471, y: 0.2882, radius: 0.2000),
      const DifferenceSpot(x: 0.6445, y: 0.6441, radius: 0.1464),
    ],
    '4-3': [
      const DifferenceSpot(x: 0.2192, y: 0.9271, radius: 0.2000),
      const DifferenceSpot(x: 0.3013, y: 0.7934, radius: 0.1944),
      const DifferenceSpot(x: 0.0781, y: 0.7326, radius: 0.2000),
      const DifferenceSpot(x: 0.3418, y: 0.6276, radius: 0.0624),
      const DifferenceSpot(x: 0.3501, y: 0.3411, radius: 0.1359),
      const DifferenceSpot(x: 0.9189, y: 0.3455, radius: 0.2000),
      const DifferenceSpot(x: 0.5635, y: 0.3950, radius: 0.2000),
    ],
    '4-4': [
      const DifferenceSpot(x: 0.1362, y: 0.7839, radius: 0.1719),
      const DifferenceSpot(x: 0.6963, y: 0.3455, radius: 0.1464),
      const DifferenceSpot(x: 0.3809, y: 0.4149, radius: 0.1464),
      const DifferenceSpot(x: 0.3818, y: 0.2292, radius: 0.1464),
      const DifferenceSpot(x: 0.4932, y: 0.3854, radius: 0.1464),
      const DifferenceSpot(x: 0.5791, y: 0.4757, radius: 0.1464),
      const DifferenceSpot(x: 0.9414, y: 0.1580, radius: 0.1464),
    ],
    '4-5': [
      const DifferenceSpot(x: 0.6660, y: 0.4757, radius: 0.2000),
      const DifferenceSpot(x: 0.1426, y: 0.3898, radius: 0.2000),
      const DifferenceSpot(x: 0.3179, y: 0.3707, radius: 0.1650),
      const DifferenceSpot(x: 0.9644, y: 0.1519, radius: 0.1719),
    ],
    '4-6': [
      const DifferenceSpot(x: 0.2842, y: 0.8620, radius: 0.2000),
      const DifferenceSpot(x: 0.3154, y: 0.7292, radius: 0.1395),
      const DifferenceSpot(x: 0.0977, y: 0.7795, radius: 0.2000),
      const DifferenceSpot(x: 0.9053, y: 0.7717, radius: 0.2000),
      const DifferenceSpot(x: 0.3984, y: 0.3290, radius: 0.2000),
      const DifferenceSpot(x: 0.7139, y: 0.2040, radius: 0.1686),
      const DifferenceSpot(x: 0.1182, y: 0.2179, radius: 0.2000),
      const DifferenceSpot(x: 0.4912, y: 0.4306, radius: 0.1464),
      const DifferenceSpot(x: 0.6768, y: 0.4479, radius: 0.1464),
      const DifferenceSpot(x: 0.9355, y: 0.1389, radius: 0.1464),
    ],

    // ========== 레벨 5 (신의 경지) ==========
    '5-1': [
      const DifferenceSpot(x: 0.5894, y: 0.8993, radius: 0.2000),
      const DifferenceSpot(x: 0.2700, y: 0.8759, radius: 0.2000),
      const DifferenceSpot(x: 0.8179, y: 0.6762, radius: 0.1719),
      const DifferenceSpot(x: 0.7207, y: 0.6302, radius: 0.1539),
      const DifferenceSpot(x: 0.2192, y: 0.4271, radius: 0.2000),
      const DifferenceSpot(x: 0.8149, y: 0.1024, radius: 0.2000),
      const DifferenceSpot(x: 0.3037, y: 0.5868, radius: 0.1464),
      const DifferenceSpot(x: 0.4629, y: 0.3872, radius: 0.1464),
      const DifferenceSpot(x: 0.8623, y: 0.1944, radius: 0.1464),
    ],
    '5-2': [
      const DifferenceSpot(x: 0.8623, y: 0.8863, radius: 0.2000),
      const DifferenceSpot(x: 0.6982, y: 0.5061, radius: 0.1539),
      const DifferenceSpot(x: 0.6094, y: 0.3941, radius: 0.1539),
      const DifferenceSpot(x: 0.7251, y: 0.2865, radius: 0.2000),
      const DifferenceSpot(x: 0.7725, y: 0.3924, radius: 0.1464),
      const DifferenceSpot(x: 0.8232, y: 0.1840, radius: 0.1464),
      const DifferenceSpot(x: 0.7852, y: 0.7934, radius: 0.1464),
    ],
    '5-3': [
      const DifferenceSpot(x: 0.0781, y: 0.9028, radius: 0.1245),
      const DifferenceSpot(x: 0.9136, y: 0.7726, radius: 0.1425),
      const DifferenceSpot(x: 0.5151, y: 0.7057, radius: 0.1425),
      const DifferenceSpot(x: 0.4385, y: 0.6918, radius: 0.1830),
      const DifferenceSpot(x: 0.9263, y: 0.3585, radius: 0.1944),
      const DifferenceSpot(x: 0.5913, y: 0.1128, radius: 0.1209),
      const DifferenceSpot(x: 0.6689, y: 0.0990, radius: 0.0879),
      const DifferenceSpot(x: 0.7881, y: 0.1120, radius: 0.2000),
      const DifferenceSpot(x: 0.1265, y: 0.0833, radius: 0.1095),
    ],
    '5-4': [
      const DifferenceSpot(x: 0.7085, y: 0.9210, radius: 0.1575),
      const DifferenceSpot(x: 0.1938, y: 0.7613, radius: 0.2000),
      const DifferenceSpot(x: 0.9590, y: 0.6302, radius: 0.1095),
      const DifferenceSpot(x: 0.1118, y: 0.4106, radius: 0.1284),
      const DifferenceSpot(x: 0.1733, y: 0.3003, radius: 0.0879),
      const DifferenceSpot(x: 0.0376, y: 0.2422, radius: 0.1284),
      const DifferenceSpot(x: 0.4751, y: 0.1944, radius: 0.1170),
      const DifferenceSpot(x: 0.6484, y: 0.1727, radius: 0.1095),
      const DifferenceSpot(x: 0.1084, y: 0.1432, radius: 0.2000),
      const DifferenceSpot(x: 0.4600, y: 0.0521, radius: 0.1245),
    ],
    '5-5': [
      const DifferenceSpot(x: 0.2847, y: 0.8559, radius: 0.0954),
      const DifferenceSpot(x: 0.2729, y: 0.6024, radius: 0.0840),
      const DifferenceSpot(x: 0.3477, y: 0.5773, radius: 0.1284),
      const DifferenceSpot(x: 0.6548, y: 0.5668, radius: 0.1425),
      const DifferenceSpot(x: 0.5806, y: 0.3273, radius: 0.1944),
      const DifferenceSpot(x: 0.4214, y: 0.3273, radius: 0.2000),
      const DifferenceSpot(x: 0.5020, y: 0.1224, radius: 0.2000),
      const DifferenceSpot(x: 0.0830, y: 0.1181, radius: 0.0660),
      const DifferenceSpot(x: 0.6392, y: 0.0799, radius: 0.1830),
      const DifferenceSpot(x: 0.1450, y: 0.0894, radius: 0.2000),
    ],
    '5-6': [
      const DifferenceSpot(x: 0.0615, y: 0.7865, radius: 0.2000),
      const DifferenceSpot(x: 0.3682, y: 0.6788, radius: 0.2000),
      const DifferenceSpot(x: 0.2461, y: 0.5113, radius: 0.2000),
      const DifferenceSpot(x: 0.9121, y: 0.5660, radius: 0.1095),
      const DifferenceSpot(x: 0.1216, y: 0.4792, radius: 0.1065),
      const DifferenceSpot(x: 0.5181, y: 0.4036, radius: 0.0990),
      const DifferenceSpot(x: 0.9639, y: 0.3490, radius: 0.2000),
      const DifferenceSpot(x: 0.4082, y: 0.2543, radius: 0.1830),
      const DifferenceSpot(x: 0.6904, y: 0.4054, radius: 0.2000),
      const DifferenceSpot(x: 0.0625, y: 0.1441, radius: 0.1464),
      const DifferenceSpot(x: 0.3311, y: 0.1319, radius: 0.1464),
      const DifferenceSpot(x: 0.1885, y: 0.0955, radius: 0.1464),
      const DifferenceSpot(x: 0.9199, y: 0.0660, radius: 0.1464),
    ],
    '5-7': [
      const DifferenceSpot(x: 0.4683, y: 0.9227, radius: 0.2000),
      const DifferenceSpot(x: 0.9258, y: 0.6979, radius: 0.1905),
      const DifferenceSpot(x: 0.7954, y: 0.4661, radius: 0.1284),
      const DifferenceSpot(x: 0.8999, y: 0.4297, radius: 0.1425),
      const DifferenceSpot(x: 0.5620, y: 0.4705, radius: 0.2000),
      const DifferenceSpot(x: 0.3833, y: 0.2335, radius: 0.2000),
      const DifferenceSpot(x: 0.8760, y: 0.0660, radius: 0.1755),
      const DifferenceSpot(x: 0.8623, y: 0.7188, radius: 0.1464),
      const DifferenceSpot(x: 0.4844, y: 0.0642, radius: 0.1464),
    ],
  };

  /// JSON 파일에서 스팟 데이터 로드
  Future<List<DifferenceSpot>?> _loadSpotsFromJson(int level, int stage) async {
    final key = '$level-$stage';
    final jsonPath = 'assets/spot_results_v4/$key.json';
    
    try {
      final jsonString = await rootBundle.loadString(jsonPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => DifferenceSpot.fromJson(json)).toList();
    } catch (e) {
      print('[SpotDifference] JSON 파일 로드 실패: $jsonPath - $e');
      return null;
    }
  }

  /// 스테이지 데이터 가져오기 (JSON 우선, 없으면 하드코딩 데이터 사용)
  Future<SpotDifferenceStage?> getStage(int level, int stage) async {
    final key = '$level-$stage';
    
    // 1. JSON 파일에서 로드 시도
    final jsonSpots = await _loadSpotsFromJson(level, stage);
    if (jsonSpots != null && jsonSpots.isNotEmpty) {
      print('[SpotDifference] JSON에서 로드: $key (${jsonSpots.length}개 스팟)');
      return SpotDifferenceStage(
        level: level,
        stage: stage,
        originalImage: 'assets/soptTheDifference/$key.webp',
        wrongImage: 'assets/soptTheDifference/$key-wrong.webp',
        spots: jsonSpots,
        timeLimit: timeLimitByLevel[level] ?? 60,
        spotCount: spotCountByLevel[level] ?? 3,
      );
    }
    
    // 2. JSON이 없으면 하드코딩된 데이터 사용 (하위 호환성)
    final spots = _spotData[key];
    if (spots == null) {
      return null;
    }
    
    print('[SpotDifference] 하드코딩 데이터 사용: $key (${spots.length}개 스팟)');
    return SpotDifferenceStage(
      level: level,
      stage: stage,
      originalImage: 'assets/soptTheDifference/$key.webp',
      wrongImage: 'assets/soptTheDifference/$key-wrong.webp',
      spots: spots,
      timeLimit: timeLimitByLevel[level] ?? 60,
      spotCount: spotCountByLevel[level] ?? 3,
    );
  }

  /// 해당 레벨의 모든 스테이지 가져오기
  Future<List<SpotDifferenceStage>> getStagesByLevel(int level) async {
    final stageCount = stageCountByLevel[level] ?? 0;
    final stages = <SpotDifferenceStage>[];

    for (int i = 1; i <= stageCount; i++) {
      final stage = await getStage(level, i);
      if (stage != null) {
        stages.add(stage);
      }
    }

    return stages;
  }

  /// 해당 레벨의 랜덤 스테이지 가져오기
  Future<SpotDifferenceStage?> getRandomStage(int level) async {
    final stages = await getStagesByLevel(level);
    if (stages.isEmpty) return null;

    stages.shuffle();
    return stages.first;
  }

  /// GameDifficulty를 레벨 번호로 변환
  static int difficultyToLevel(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.level1:
        return 1;
      case GameDifficulty.level2:
        return 2;
      case GameDifficulty.level3:
        return 3;
      case GameDifficulty.level4:
        return 4;
      case GameDifficulty.level5:
        return 5;
    }
  }
}


