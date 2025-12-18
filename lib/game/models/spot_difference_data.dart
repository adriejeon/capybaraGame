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

  /// 모든 스테이지 데이터 (OpenCV 자동 분석 결과 - v3.0 색상 감지 강화)
  /// find_differences_v3.py 스크립트로 자동 생성됨
  static final Map<String, List<DifferenceSpot>> _spotData = {
    // ========== 레벨 1 (아기 단계) ==========
    '1-1': [
      const DifferenceSpot(x: 0.6494, y: 0.7902, radius: 0.2473),
      const DifferenceSpot(x: 0.5166, y: 0.3339, radius: 0.198),
      const DifferenceSpot(x: 0.0342, y: 0.3479, radius: 0.0416),
      const DifferenceSpot(x: 0.5645, y: 0.1066, radius: 0.116),
    ],
    '1-2': [
      const DifferenceSpot(x: 0.8076, y: 0.4983, radius: 0.0633),   // 램프 (주황→초록)
      const DifferenceSpot(x: 0.3887, y: 0.2028, radius: 0.0938),   // 화분
      const DifferenceSpot(x: 0.791, y: 0.2168, radius: 0.068),     // 벽 그림
    ],
    '1-3': [
      const DifferenceSpot(x: 0.9121, y: 0.8899, radius: 0.0885),
      const DifferenceSpot(x: 0.1895, y: 0.7133, radius: 0.1096),
      const DifferenceSpot(x: 0.9492, y: 0.5717, radius: 0.0609),
      const DifferenceSpot(x: 0.8232, y: 0.1259, radius: 0.0434),
      const DifferenceSpot(x: 0.1006, y: 0.1101, radius: 0.1207),
    ],
    '1-4': [
      const DifferenceSpot(x: 0.8789, y: 0.8322, radius: 0.1318),
      const DifferenceSpot(x: 0.3096, y: 0.6731, radius: 0.3715),
      const DifferenceSpot(x: 0.6943, y: 0.4545, radius: 0.0984),
      const DifferenceSpot(x: 0.6758, y: 0.1993, radius: 0.0527),
      const DifferenceSpot(x: 0.6895, y: 0.0507, radius: 0.0422),
    ],
    '1-5': [
      const DifferenceSpot(x: 0.8135, y: 0.9266, radius: 0.2039),
      const DifferenceSpot(x: 0.4961, y: 0.7902, radius: 0.1541),
      const DifferenceSpot(x: 0.8105, y: 0.4563, radius: 0.0311),
      const DifferenceSpot(x: 0.959, y: 0.486, radius: 0.0586),
      const DifferenceSpot(x: 0.4023, y: 0.201, radius: 0.0762),
      const DifferenceSpot(x: 0.0762, y: 0.0664, radius: 0.0709),
    ],
    '1-6': [
      const DifferenceSpot(x: 0.5, y: 0.5, radius: 0.6),
    ],
    '1-7': [
      const DifferenceSpot(x: 0.5, y: 0.5, radius: 0.6),
    ],

    // ========== 레벨 2 (어린이 단계) ==========
    '2-1': [
      const DifferenceSpot(x: 0.5146, y: 0.8024, radius: 0.0521),
      const DifferenceSpot(x: 0.7422, y: 0.5402, radius: 0.0275),
      const DifferenceSpot(x: 0.2363, y: 0.4371, radius: 0.0961),
      const DifferenceSpot(x: 0.6338, y: 0.1818, radius: 0.1225),
    ],
    '2-2': [
      const DifferenceSpot(x: 0.959, y: 0.9283, radius: 0.0316),
      const DifferenceSpot(x: 0.9365, y: 0.7395, radius: 0.0434),
      const DifferenceSpot(x: 0.5059, y: 0.4301, radius: 0.0604),
      const DifferenceSpot(x: 0.7871, y: 0.299, radius: 0.2549),
    ],
    '2-3': [
      const DifferenceSpot(x: 0.959, y: 0.9301, radius: 0.0316),
      const DifferenceSpot(x: 0.1826, y: 0.5804, radius: 0.0369),
      const DifferenceSpot(x: 0.542, y: 0.2745, radius: 0.0562),
      const DifferenceSpot(x: 0.834, y: 0.1101, radius: 0.0387),
    ],
    '2-4': [
      const DifferenceSpot(x: 0.959, y: 0.9283, radius: 0.0316),
      const DifferenceSpot(x: 0.6201, y: 0.6871, radius: 0.1213),
      const DifferenceSpot(x: 0.834, y: 0.6958, radius: 0.0521),
      const DifferenceSpot(x: 0.0723, y: 0.3794, radius: 0.1254),
    ],
    '2-5': [
      const DifferenceSpot(x: 0.9629, y: 0.9318, radius: 0.0375),
      const DifferenceSpot(x: 0.8623, y: 0.8986, radius: 0.1014),
      const DifferenceSpot(x: 0.2012, y: 0.5787, radius: 0.0873),
      const DifferenceSpot(x: 0.915, y: 0.4073, radius: 0.0832),
    ],
    '2-6': [
      const DifferenceSpot(x: 0.9697, y: 0.7133, radius: 0.0363),
      const DifferenceSpot(x: 0.6777, y: 0.5507, radius: 0.1646),
      const DifferenceSpot(x: 0.21, y: 0.4143, radius: 0.0451),
      const DifferenceSpot(x: 0.333, y: 0.0857, radius: 0.0574),
    ],

    // ========== 레벨 3 (청소년 단계) ==========
    '3-1': [
      const DifferenceSpot(x: 0.7988, y: 0.8934, radius: 0.184),
      const DifferenceSpot(x: 0.1016, y: 0.8252, radius: 0.0691),
      const DifferenceSpot(x: 0.9248, y: 0.722, radius: 0.0357),
      const DifferenceSpot(x: 0.7725, y: 0.4423, radius: 0.0428),
      const DifferenceSpot(x: 0.4531, y: 0.1119, radius: 0.0715),
    ],
    '3-2': [
      const DifferenceSpot(x: 0.7363, y: 0.5, radius: 0.3352),
      const DifferenceSpot(x: 0.877, y: 0.8689, radius: 0.133),
      const DifferenceSpot(x: 0.334, y: 0.7028, radius: 0.102),
      const DifferenceSpot(x: 0.2295, y: 0.4948, radius: 0.1154),
      const DifferenceSpot(x: 0.624, y: 0.0542, radius: 0.0363),
    ],
    '3-3': [
      const DifferenceSpot(x: 0.499, y: 0.8689, radius: 0.0592),
      const DifferenceSpot(x: 0.0654, y: 0.5524, radius: 0.0814),
      const DifferenceSpot(x: 0.2881, y: 0.5997, radius: 0.1055),
      const DifferenceSpot(x: 0.4473, y: 0.6486, radius: 0.0779),
      const DifferenceSpot(x: 0.3301, y: 0.2395, radius: 0.2918),
    ],
    '3-4': [
      const DifferenceSpot(x: 0.8281, y: 0.9318, radius: 0.0768),
      const DifferenceSpot(x: 0.96, y: 0.9283, radius: 0.0299),
      const DifferenceSpot(x: 0.6074, y: 0.6678, radius: 0.1723),
      const DifferenceSpot(x: 0.3398, y: 0.3531, radius: 0.2062),
      const DifferenceSpot(x: 0.1191, y: 0.3234, radius: 0.0861),
    ],
    '3-5': [
      const DifferenceSpot(x: 0.8408, y: 0.7028, radius: 0.1986),
      const DifferenceSpot(x: 0.0723, y: 0.4808, radius: 0.0697),
      const DifferenceSpot(x: 0.3643, y: 0.4318, radius: 0.0521),
      const DifferenceSpot(x: 0.0342, y: 0.2203, radius: 0.0826),
      const DifferenceSpot(x: 0.9561, y: 0.2185, radius: 0.1037),
    ],
    '3-6': [
      const DifferenceSpot(x: 0.8867, y: 0.7587, radius: 0.1494),
      const DifferenceSpot(x: 0.2451, y: 0.7622, radius: 0.2941),
      const DifferenceSpot(x: 0.3887, y: 0.549, radius: 0.1418),
      const DifferenceSpot(x: 0.8594, y: 0.4773, radius: 0.041),
      const DifferenceSpot(x: 0.5107, y: 0.0699, radius: 0.0469),
    ],

    // ========== 레벨 4 (어른 단계) ==========
    '4-1': [
      const DifferenceSpot(x: 0.959, y: 0.9283, radius: 0.0346),
      const DifferenceSpot(x: 0.7451, y: 0.9353, radius: 0.0926),
      const DifferenceSpot(x: 0.1309, y: 0.8094, radius: 0.1576),
      const DifferenceSpot(x: 0.5488, y: 0.5367, radius: 0.2068),
      const DifferenceSpot(x: 0.3271, y: 0.2063, radius: 0.0445),
    ],
    '4-2': [
      const DifferenceSpot(x: 0.5, y: 0.6084, radius: 0.6),
      const DifferenceSpot(x: 0.8096, y: 0.257, radius: 0.1283),
      const DifferenceSpot(x: 0.1084, y: 0.1783, radius: 0.0404),
    ],
    '4-3': [
      const DifferenceSpot(x: 0.5, y: 0.528, radius: 0.5994),
      const DifferenceSpot(x: 0.625, y: 0.8846, radius: 0.0393),
      const DifferenceSpot(x: 0.7266, y: 0.25, radius: 0.0604),
      const DifferenceSpot(x: 0.1592, y: 0.1783, radius: 0.0416),
    ],
    '4-4': [
      const DifferenceSpot(x: 0.3916, y: 0.5577, radius: 0.4699),
      const DifferenceSpot(x: 0.9092, y: 0.4038, radius: 0.0416),
      const DifferenceSpot(x: 0.8545, y: 0.1259, radius: 0.1746),
    ],
    '4-5': [
      const DifferenceSpot(x: 0.3281, y: 0.5, radius: 0.3492),
      const DifferenceSpot(x: 0.9072, y: 0.743, radius: 0.0996),
      const DifferenceSpot(x: 0.6348, y: 0.3252, radius: 0.198),
      const DifferenceSpot(x: 0.9141, y: 0.1538, radius: 0.1031),
      const DifferenceSpot(x: 0.1855, y: 0.1136, radius: 0.0475),
    ],
    '4-6': [
      const DifferenceSpot(x: 0.5, y: 0.5, radius: 0.6),
      const DifferenceSpot(x: 0.7139, y: 0.1888, radius: 0.0475),
    ],

    // ========== 레벨 5 (신의 경지) ==========
    '5-1': [
      const DifferenceSpot(x: 0.9072, y: 0.8409, radius: 0.1066),
      const DifferenceSpot(x: 0.6016, y: 0.9003, radius: 0.1541),
      const DifferenceSpot(x: 0.2471, y: 0.6696, radius: 0.232),
      const DifferenceSpot(x: 0.7441, y: 0.6538, radius: 0.1283),
      const DifferenceSpot(x: 0.4238, y: 0.4231, radius: 0.0691),
      const DifferenceSpot(x: 0.8428, y: 0.1731, radius: 0.0979),
    ],
    '5-2': [
      const DifferenceSpot(x: 0.6338, y: 0.9476, radius: 0.0879),
      const DifferenceSpot(x: 0.8623, y: 0.8619, radius: 0.1482),
      const DifferenceSpot(x: 0.9678, y: 0.7255, radius: 0.0457),
      const DifferenceSpot(x: 0.6865, y: 0.3497, radius: 0.1377),
      const DifferenceSpot(x: 0.2295, y: 0.465, radius: 0.0346),
      const DifferenceSpot(x: 0.1396, y: 0.3024, radius: 0.027),
    ],
    '5-3': [
      const DifferenceSpot(x: 0.7012, y: 0.8199, radius: 0.3586),
      const DifferenceSpot(x: 0.1182, y: 0.8619, radius: 0.1418),
      const DifferenceSpot(x: 0.9268, y: 0.3601, radius: 0.0434),
      const DifferenceSpot(x: 0.7881, y: 0.1119, radius: 0.0521),
      const DifferenceSpot(x: 0.126, y: 0.0839, radius: 0.0328),
    ],
    '5-4': [
      const DifferenceSpot(x: 0.5, y: 0.757, radius: 0.6),
      const DifferenceSpot(x: 0.9551, y: 0.5979, radius: 0.0551),
      const DifferenceSpot(x: 0.5811, y: 0.3864, radius: 0.092),
      const DifferenceSpot(x: 0.1396, y: 0.3636, radius: 0.0738),
      const DifferenceSpot(x: 0.083, y: 0.1888, radius: 0.0879),
      const DifferenceSpot(x: 0.4756, y: 0.1976, radius: 0.034),
    ],
    '5-5': [
      const DifferenceSpot(x: 0.5, y: 0.5, radius: 0.6),
    ],
    '5-6': [
      const DifferenceSpot(x: 0.959, y: 0.9283, radius: 0.0328),
      const DifferenceSpot(x: 0.2598, y: 0.9003, radius: 0.0592),
      const DifferenceSpot(x: 0.2715, y: 0.4738, radius: 0.3258),
      const DifferenceSpot(x: 0.6953, y: 0.4161, radius: 0.1623),
      const DifferenceSpot(x: 0.958, y: 0.3514, radius: 0.0656),
      const DifferenceSpot(x: 0.915, y: 0.0962, radius: 0.0709),
    ],
    '5-7': [
      const DifferenceSpot(x: 0.8975, y: 0.7955, radius: 0.1119),
      const DifferenceSpot(x: 0.4707, y: 0.8916, radius: 0.1313),
      const DifferenceSpot(x: 0.3428, y: 0.6031, radius: 0.3732),
      const DifferenceSpot(x: 0.7607, y: 0.4615, radius: 0.0738),
      const DifferenceSpot(x: 0.3965, y: 0.2535, radius: 0.0744),
      const DifferenceSpot(x: 0.8779, y: 0.0664, radius: 0.041),
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

