import '../../utils/constants.dart';

/// 틀린그림찾기 스팟 위치 (0.0 ~ 1.0 비율 좌표)
class DifferenceSpot {
  final double x; // 0.0 ~ 1.0 (이미지 너비 기준 비율)
  final double y; // 0.0 ~ 1.0 (이미지 높이 기준 비율)
  final double radius; // 0.0 ~ 1.0 (터치 허용 반경, 이미지 너비 기준)

  const DifferenceSpot({
    required this.x,
    required this.y,
    this.radius = 0.08, // 기본 터치 허용 반경 8%
  });
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
    1: 7, // 1-1 ~ 1-7
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

  /// 모든 스테이지 데이터 (OpenCV 자동 분석 + 수동 조정)
  /// 이미지 비교 스크립트로 자동 감지 후 수동 검증 완료
  static final Map<String, List<DifferenceSpot>> _spotData = {
    // ========== 레벨 1 (아기 단계) - 3개 스팟 ==========
    // 1-1: 태양(얼굴), 모자(밀짚->베레), 옷(줄무늬->별무늬), 음식(수박->오렌지), 야자수(코코넛)
    '1-1': [
      const DifferenceSpot(x: 0.46, y: 0.08, radius: 0.08),   // 태양 얼굴
      const DifferenceSpot(x: 0.50, y: 0.28, radius: 0.10),   // 모자
      const DifferenceSpot(x: 0.04, y: 0.32, radius: 0.06),   // 야자수 코코넛
    ],
    // 1-2: 침대에서 자는 카피바라 (수동 조정)
    // 실제 차이점: 1) 담요 폴카닷, 2) 화분 잎 색상, 3) 책 개수
    '1-2': [
      const DifferenceSpot(x: 0.50, y: 0.55, radius: 0.12),   // 담요 폴카닷 (카피바라 몸 위)
      const DifferenceSpot(x: 0.15, y: 0.25, radius: 0.08),   // 화분 잎 색상 (왼쪽 창문)
      const DifferenceSpot(x: 0.10, y: 0.20, radius: 0.06),   // 책 개수 (창문 위)
    ],
    // 1-3: 자동 감지 결과 기반
    '1-3': [
      const DifferenceSpot(x: 0.19, y: 0.67, radius: 0.08),
      const DifferenceSpot(x: 0.35, y: 0.30, radius: 0.06),
      const DifferenceSpot(x: 0.86, y: 0.10, radius: 0.08),
    ],
    // 1-4: 자동 감지 결과 기반
    '1-4': [
      const DifferenceSpot(x: 0.24, y: 0.73, radius: 0.08),
      const DifferenceSpot(x: 0.41, y: 0.67, radius: 0.08),
      const DifferenceSpot(x: 0.59, y: 0.40, radius: 0.06),
    ],
    // 1-5: 자동 감지 결과 기반
    '1-5': [
      const DifferenceSpot(x: 0.81, y: 0.46, radius: 0.06),
      const DifferenceSpot(x: 0.41, y: 0.20, radius: 0.08),
      const DifferenceSpot(x: 0.08, y: 0.08, radius: 0.08),
    ],
    // 1-6: 아기카피바라 옷색상, 버섯, 새 (이미지 비율: 1024x448)
    '1-6': [
      const DifferenceSpot(x: 0.30, y: 0.52, radius: 0.10),   // 왼쪽 아기 카피바라 옷 (파란줄→빨간줄)
      const DifferenceSpot(x: 0.12, y: 0.58, radius: 0.08),   // 버섯 추가
      const DifferenceSpot(x: 0.08, y: 0.28, radius: 0.08),   // 새 위치
    ],
    // 1-7: 나비색상, 왼쪽꽃색상, 나뭇잎
    '1-7': [
      const DifferenceSpot(x: 0.52, y: 0.27, radius: 0.06),   // 나비
      const DifferenceSpot(x: 0.12, y: 0.52, radius: 0.08),   // 왼쪽 꽃
      const DifferenceSpot(x: 0.10, y: 0.12, radius: 0.08),   // 나뭇잎
    ],

    // ========== 레벨 2 (어린이 단계) - 4개 스팟 ==========
    '2-1': [
      const DifferenceSpot(x: 0.65, y: 0.92, radius: 0.06),
      const DifferenceSpot(x: 0.74, y: 0.54, radius: 0.06),
      const DifferenceSpot(x: 0.23, y: 0.44, radius: 0.08),
      const DifferenceSpot(x: 0.64, y: 0.27, radius: 0.07),
    ],
    '2-2': [
      const DifferenceSpot(x: 0.96, y: 0.93, radius: 0.05),
      const DifferenceSpot(x: 0.93, y: 0.74, radius: 0.05),
      const DifferenceSpot(x: 0.51, y: 0.43, radius: 0.07),
      const DifferenceSpot(x: 0.81, y: 0.32, radius: 0.10),
    ],
    '2-3': [
      const DifferenceSpot(x: 0.96, y: 0.93, radius: 0.05),
      const DifferenceSpot(x: 0.10, y: 0.79, radius: 0.05),
      const DifferenceSpot(x: 0.93, y: 0.74, radius: 0.05),
      const DifferenceSpot(x: 0.51, y: 0.52, radius: 0.12),
    ],
    '2-4': [
      const DifferenceSpot(x: 0.84, y: 0.70, radius: 0.06),
      const DifferenceSpot(x: 0.68, y: 0.66, radius: 0.06),
      const DifferenceSpot(x: 0.56, y: 0.41, radius: 0.08),
      const DifferenceSpot(x: 0.41, y: 0.40, radius: 0.07),
    ],
    '2-5': [
      const DifferenceSpot(x: 0.17, y: 0.82, radius: 0.06),
      const DifferenceSpot(x: 0.39, y: 0.77, radius: 0.06),
      const DifferenceSpot(x: 0.20, y: 0.58, radius: 0.08),
      const DifferenceSpot(x: 0.92, y: 0.43, radius: 0.07),
    ],
    '2-6': [
      const DifferenceSpot(x: 0.03, y: 0.87, radius: 0.05),
      const DifferenceSpot(x: 0.97, y: 0.71, radius: 0.05),
      const DifferenceSpot(x: 0.70, y: 0.42, radius: 0.08),
      const DifferenceSpot(x: 0.21, y: 0.41, radius: 0.06),
    ],

    // ========== 레벨 3 (청소년 단계) - 5개 스팟 ==========
    '3-1': [
      const DifferenceSpot(x: 0.27, y: 0.90, radius: 0.07),
      const DifferenceSpot(x: 0.13, y: 0.84, radius: 0.05),
      const DifferenceSpot(x: 0.89, y: 0.82, radius: 0.05),
      const DifferenceSpot(x: 0.43, y: 0.66, radius: 0.06),
      const DifferenceSpot(x: 0.46, y: 0.14, radius: 0.06),
    ],
    '3-2': [
      const DifferenceSpot(x: 0.32, y: 0.92, radius: 0.07),
      const DifferenceSpot(x: 0.74, y: 0.50, radius: 0.12),
      const DifferenceSpot(x: 0.33, y: 0.70, radius: 0.08),
      const DifferenceSpot(x: 0.45, y: 0.25, radius: 0.08),
      const DifferenceSpot(x: 0.85, y: 0.15, radius: 0.06),
    ],
    '3-3': [
      const DifferenceSpot(x: 0.45, y: 0.63, radius: 0.06),
      const DifferenceSpot(x: 0.30, y: 0.63, radius: 0.06),
      const DifferenceSpot(x: 0.72, y: 0.45, radius: 0.07),
      const DifferenceSpot(x: 0.49, y: 0.34, radius: 0.08),
      const DifferenceSpot(x: 0.17, y: 0.11, radius: 0.08),
    ],
    '3-4': [
      const DifferenceSpot(x: 0.92, y: 0.74, radius: 0.08),
      const DifferenceSpot(x: 0.50, y: 0.67, radius: 0.05),
      const DifferenceSpot(x: 0.68, y: 0.60, radius: 0.05),
      const DifferenceSpot(x: 0.32, y: 0.34, radius: 0.12),
      const DifferenceSpot(x: 0.14, y: 0.05, radius: 0.05),
    ],
    '3-5': [
      const DifferenceSpot(x: 0.88, y: 0.97, radius: 0.06),
      const DifferenceSpot(x: 0.76, y: 0.79, radius: 0.05),
      const DifferenceSpot(x: 0.90, y: 0.67, radius: 0.08),
      const DifferenceSpot(x: 0.30, y: 0.55, radius: 0.15),
      const DifferenceSpot(x: 0.95, y: 0.22, radius: 0.08),
    ],
    '3-6': [
      const DifferenceSpot(x: 0.84, y: 0.91, radius: 0.06),
      const DifferenceSpot(x: 0.35, y: 0.85, radius: 0.08),
      const DifferenceSpot(x: 0.12, y: 0.76, radius: 0.10),
      const DifferenceSpot(x: 0.44, y: 0.56, radius: 0.06),
      const DifferenceSpot(x: 0.51, y: 0.07, radius: 0.05),
    ],

    // ========== 레벨 4 (어른 단계) - 5개 스팟 ==========
    '4-1': [
      const DifferenceSpot(x: 0.11, y: 0.87, radius: 0.10),
      const DifferenceSpot(x: 0.77, y: 0.89, radius: 0.07),
      const DifferenceSpot(x: 0.52, y: 0.51, radius: 0.10),
      const DifferenceSpot(x: 0.69, y: 0.37, radius: 0.05),
      const DifferenceSpot(x: 0.33, y: 0.21, radius: 0.06),
    ],
    '4-2': [
      const DifferenceSpot(x: 0.96, y: 0.93, radius: 0.05),
      const DifferenceSpot(x: 0.78, y: 0.30, radius: 0.07),
      const DifferenceSpot(x: 0.10, y: 0.18, radius: 0.05),
      const DifferenceSpot(x: 0.42, y: 0.73, radius: 0.15),
      const DifferenceSpot(x: 0.60, y: 0.50, radius: 0.08),
    ],
    '4-3': [
      const DifferenceSpot(x: 0.96, y: 0.93, radius: 0.05),
      const DifferenceSpot(x: 0.37, y: 0.63, radius: 0.12),
      const DifferenceSpot(x: 0.81, y: 0.41, radius: 0.10),
      const DifferenceSpot(x: 0.50, y: 0.25, radius: 0.08),
      const DifferenceSpot(x: 0.20, y: 0.35, radius: 0.08),
    ],
    '4-4': [
      const DifferenceSpot(x: 0.16, y: 0.82, radius: 0.10),
      const DifferenceSpot(x: 0.46, y: 0.67, radius: 0.05),
      const DifferenceSpot(x: 0.65, y: 0.30, radius: 0.15),
      const DifferenceSpot(x: 0.35, y: 0.25, radius: 0.08),
      const DifferenceSpot(x: 0.85, y: 0.20, radius: 0.06),
    ],
    '4-5': [
      const DifferenceSpot(x: 0.87, y: 0.81, radius: 0.05),
      const DifferenceSpot(x: 0.69, y: 0.74, radius: 0.05),
      const DifferenceSpot(x: 0.87, y: 0.69, radius: 0.05),
      const DifferenceSpot(x: 0.66, y: 0.47, radius: 0.08),
      const DifferenceSpot(x: 0.14, y: 0.39, radius: 0.06),
    ],
    '4-6': [
      const DifferenceSpot(x: 0.94, y: 0.85, radius: 0.08),
      const DifferenceSpot(x: 0.39, y: 0.48, radius: 0.15),
      const DifferenceSpot(x: 0.94, y: 0.22, radius: 0.05),
      const DifferenceSpot(x: 0.97, y: 0.05, radius: 0.05),
      const DifferenceSpot(x: 0.15, y: 0.30, radius: 0.08),
    ],

    // ========== 레벨 5 (신의 경지) - 6개 스팟 ==========
    '5-1': [
      const DifferenceSpot(x: 0.26, y: 0.89, radius: 0.07),
      const DifferenceSpot(x: 0.03, y: 0.77, radius: 0.05),
      const DifferenceSpot(x: 0.82, y: 0.68, radius: 0.05),
      const DifferenceSpot(x: 0.30, y: 0.52, radius: 0.10),
      const DifferenceSpot(x: 0.71, y: 0.63, radius: 0.06),
      const DifferenceSpot(x: 0.84, y: 0.17, radius: 0.08),
    ],
    '5-2': [
      const DifferenceSpot(x: 0.87, y: 0.85, radius: 0.10),
      const DifferenceSpot(x: 0.71, y: 0.35, radius: 0.10),
      const DifferenceSpot(x: 0.14, y: 0.30, radius: 0.05),
      const DifferenceSpot(x: 0.50, y: 0.60, radius: 0.08),
      const DifferenceSpot(x: 0.30, y: 0.75, radius: 0.06),
      const DifferenceSpot(x: 0.90, y: 0.20, radius: 0.06),
    ],
    '5-3': [
      const DifferenceSpot(x: 0.08, y: 0.91, radius: 0.05),
      const DifferenceSpot(x: 0.89, y: 0.87, radius: 0.04),
      const DifferenceSpot(x: 0.64, y: 0.85, radius: 0.05),
      const DifferenceSpot(x: 0.47, y: 0.76, radius: 0.08),
      const DifferenceSpot(x: 0.93, y: 0.36, radius: 0.05),
      const DifferenceSpot(x: 0.47, y: 0.31, radius: 0.05),
    ],
    '5-4': [
      const DifferenceSpot(x: 0.66, y: 0.91, radius: 0.08),
      const DifferenceSpot(x: 0.18, y: 0.84, radius: 0.10),
      const DifferenceSpot(x: 0.89, y: 0.89, radius: 0.10),
      const DifferenceSpot(x: 0.50, y: 0.62, radius: 0.05),
      const DifferenceSpot(x: 0.96, y: 0.63, radius: 0.05),
      const DifferenceSpot(x: 0.10, y: 0.28, radius: 0.10),
    ],
    '5-5': [
      const DifferenceSpot(x: 0.96, y: 0.93, radius: 0.05),
      const DifferenceSpot(x: 0.27, y: 0.87, radius: 0.05),
      const DifferenceSpot(x: 0.27, y: 0.60, radius: 0.05),
      const DifferenceSpot(x: 0.66, y: 0.58, radius: 0.05),
      const DifferenceSpot(x: 0.59, y: 0.38, radius: 0.06),
      const DifferenceSpot(x: 0.50, y: 0.12, radius: 0.05),
    ],
    '5-6': [
      const DifferenceSpot(x: 0.30, y: 0.91, radius: 0.05),
      const DifferenceSpot(x: 0.96, y: 0.93, radius: 0.05),
      const DifferenceSpot(x: 0.39, y: 0.70, radius: 0.08),
      const DifferenceSpot(x: 0.91, y: 0.57, radius: 0.05),
      const DifferenceSpot(x: 0.12, y: 0.48, radius: 0.08),
      const DifferenceSpot(x: 0.42, y: 0.27, radius: 0.10),
    ],
    // 5-7: 드래곤 머리(카피바라->드래곤), 모자 색상, 천사들 옷/날개 변화
    '5-7': [
      const DifferenceSpot(x: 0.67, y: 0.50, radius: 0.10),   // 드래곤 머리
      const DifferenceSpot(x: 0.46, y: 0.28, radius: 0.06),   // 모자 색상
      const DifferenceSpot(x: 0.76, y: 0.28, radius: 0.06),   // 오른쪽 천사 옷
      const DifferenceSpot(x: 0.10, y: 0.55, radius: 0.06),   // 왼쪽 천사
      const DifferenceSpot(x: 0.92, y: 0.80, radius: 0.05),   // 오른쪽 아래 천사
      const DifferenceSpot(x: 0.70, y: 0.83, radius: 0.05),   // 가운데 아래 천사
    ],
  };

  /// 스테이지 데이터 가져오기
  SpotDifferenceStage? getStage(int level, int stage) {
    final key = '$level-$stage';
    final spots = _spotData[key];

    if (spots == null) {
      return null;
    }

    return SpotDifferenceStage(
      level: level,
      stage: stage,
      originalImage: 'assets/soptTheDifference/$key.png',
      wrongImage: 'assets/soptTheDifference/$key-wrong.png',
      spots: spots,
      timeLimit: timeLimitByLevel[level] ?? 60,
      spotCount: spotCountByLevel[level] ?? 3,
    );
  }

  /// 해당 레벨의 모든 스테이지 가져오기
  List<SpotDifferenceStage> getStagesByLevel(int level) {
    final stageCount = stageCountByLevel[level] ?? 0;
    final stages = <SpotDifferenceStage>[];

    for (int i = 1; i <= stageCount; i++) {
      final stage = getStage(level, i);
      if (stage != null) {
        stages.add(stage);
      }
    }

    return stages;
  }

  /// 해당 레벨의 랜덤 스테이지 가져오기
  SpotDifferenceStage? getRandomStage(int level) {
    final stages = getStagesByLevel(level);
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
