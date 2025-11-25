/// 데일리 미션 타입
enum DailyMissionType {
  attendance, // 출석 체크
  playGames, // 게임 3판 완료
  collectCharacter, // 새로운 캐릭터 1종 수집
  watchAd, // 광고 1개 보기
}

/// 데일리 미션 모델
class DailyMission {
  final DailyMissionType type;
  final String titleKo;
  final String titleEn;
  final String descriptionKo;
  final String descriptionEn;
  final int targetCount;
  final int currentCount;
  final int coinReward;
  final bool isCompleted; // 조건 충족 여부
  final bool isClaimed; // 보상 수령 여부

  DailyMission({
    required this.type,
    required this.titleKo,
    required this.titleEn,
    required this.descriptionKo,
    required this.descriptionEn,
    required this.targetCount,
    required this.currentCount,
    required this.coinReward,
    required this.isCompleted,
    this.isClaimed = false,
  });

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'titleKo': titleKo,
      'titleEn': titleEn,
      'descriptionKo': descriptionKo,
      'descriptionEn': descriptionEn,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'coinReward': coinReward,
      'isCompleted': isCompleted,
      'isClaimed': isClaimed,
    };
  }

  /// JSON에서 생성
  factory DailyMission.fromJson(Map<String, dynamic> json) {
    return DailyMission(
      type: DailyMissionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DailyMissionType.attendance,
      ),
      titleKo: json['titleKo'] ?? '',
      titleEn: json['titleEn'] ?? '',
      descriptionKo: json['descriptionKo'] ?? '',
      descriptionEn: json['descriptionEn'] ?? '',
      targetCount: json['targetCount'] ?? 1,
      currentCount: json['currentCount'] ?? 0,
      coinReward: json['coinReward'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      isClaimed: json['isClaimed'] ?? false,
    );
  }

  /// 복사
  DailyMission copyWith({
    DailyMissionType? type,
    String? titleKo,
    String? titleEn,
    String? descriptionKo,
    String? descriptionEn,
    int? targetCount,
    int? currentCount,
    int? coinReward,
    bool? isCompleted,
    bool? isClaimed,
  }) {
    return DailyMission(
      type: type ?? this.type,
      titleKo: titleKo ?? this.titleKo,
      titleEn: titleEn ?? this.titleEn,
      descriptionKo: descriptionKo ?? this.descriptionKo,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      coinReward: coinReward ?? this.coinReward,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  /// 진행률 (0.0 ~ 1.0)
  double get progress {
    if (targetCount == 0) return 0.0;
    return (currentCount / targetCount).clamp(0.0, 1.0);
  }

  /// 기본 미션 생성
  static List<DailyMission> createDefaultMissions() {
    return [
      DailyMission(
        type: DailyMissionType.attendance,
        titleKo: '출석 체크',
        titleEn: 'Daily Check-in',
        descriptionKo: '오늘 출석하고 코인을 받아가세요!',
        descriptionEn: 'Check in today and get coins!',
        targetCount: 1,
        currentCount: 0,
        coinReward: 10,
        isCompleted: false,
      ),
      DailyMission(
        type: DailyMissionType.playGames,
        titleKo: '게임 3판 완료',
        titleEn: 'Complete 3 Games',
        descriptionKo: '카피바라 짝 맞추기 게임을 3판 완료하세요',
        descriptionEn: 'Complete 3 matching games',
        targetCount: 3,
        currentCount: 0,
        coinReward: 30,
        isCompleted: false,
      ),
      DailyMission(
        type: DailyMissionType.collectCharacter,
        titleKo: '새 캐릭터 수집',
        titleEn: 'Collect New Character',
        descriptionKo: '새로운 카피바라 캐릭터 1종을 수집하세요',
        descriptionEn: 'Collect 1 new capybara character',
        targetCount: 1,
        currentCount: 0,
        coinReward: 30,
        isCompleted: false,
      ),
      DailyMission(
        type: DailyMissionType.watchAd,
        titleKo: '광고 1개 보기',
        titleEn: 'Watch 1 Ad',
        descriptionKo: '하루에 아무 광고나 1개를 시청하세요',
        descriptionEn: 'Watch any ad once a day',
        targetCount: 1,
        currentCount: 0,
        coinReward: 20,
        isCompleted: false,
      ),
    ];
  }
}

