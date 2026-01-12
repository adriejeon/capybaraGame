import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/daily_mission.dart';
import 'coin_manager.dart';

/// 데일리 미션 서비스
class DailyMissionService {
  static const String _missionsKey = 'daily_missions';
  static const String _lastResetDateKey = 'daily_missions_last_reset';
  static const String _missionVersionKey = 'daily_missions_version';
  static const int _currentMissionVersion = 3; // 미션 텍스트 업데이트 (2024)

  static final DailyMissionService _instance = DailyMissionService._internal();
  factory DailyMissionService() => _instance;
  DailyMissionService._internal();

  List<DailyMission> _missions = [];
  DateTime? _lastResetDate;

  /// 미션 초기화
  Future<void> initialize() async {
    await _checkAndResetIfNeeded();
    await _loadMissions();
  }

  /// 미션 로드
  Future<void> _loadMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt(_missionVersionKey) ?? 1;
    final missionsJson = prefs.getString(_missionsKey);

    // 버전이 다르면 미션 리셋
    if (savedVersion != _currentMissionVersion) {
      print('미션 버전 업데이트: $savedVersion -> $_currentMissionVersion');
      _missions = DailyMission.createDefaultMissions();
      await prefs.setInt(_missionVersionKey, _currentMissionVersion);
      await _saveMissions();
      return;
    }

    if (missionsJson != null) {
      try {
        final jsonList = jsonDecode(missionsJson) as List;
        _missions = jsonList
            .map((json) => DailyMission.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        
        // 누락된 미션 체크 및 추가
        await _addMissingMissions();
      } catch (e) {
        print('데일리 미션 로드 실패: $e');
        _missions = DailyMission.createDefaultMissions();
        await _saveMissions();
      }
    } else {
      _missions = DailyMission.createDefaultMissions();
      await prefs.setInt(_missionVersionKey, _currentMissionVersion);
      await _saveMissions();
    }
  }

  /// 누락된 미션 추가
  Future<void> _addMissingMissions() async {
    final defaultMissions = DailyMission.createDefaultMissions();
    final existingTypes = _missions.map((m) => m.type).toSet();
    
    var added = false;
    for (final defaultMission in defaultMissions) {
      if (!existingTypes.contains(defaultMission.type)) {
        print('누락된 미션 추가: ${defaultMission.titleKo}');
        _missions.add(defaultMission);
        added = true;
      }
    }
    
    if (added) {
      await _saveMissions();
    }
  }

  /// 미션 저장
  Future<void> _saveMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _missions.map((mission) => mission.toJson()).toList();
    await prefs.setString(_missionsKey, jsonEncode(jsonList));
  }

  /// 날짜 체크 및 리셋
  Future<void> _checkAndResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetString = prefs.getString(_lastResetDateKey);

    DateTime? lastReset;
    if (lastResetString != null) {
      lastReset = DateTime.tryParse(lastResetString);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 마지막 리셋 날짜가 없거나 오늘이 아니면 리셋
    if (lastReset == null || 
        DateTime(lastReset.year, lastReset.month, lastReset.day) != today) {
      await _resetMissions();
      await prefs.setString(_lastResetDateKey, today.toIso8601String());
      _lastResetDate = today;
    } else {
      _lastResetDate = lastReset;
    }
  }

  /// 미션 리셋
  Future<void> _resetMissions() async {
    _missions = DailyMission.createDefaultMissions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_missionVersionKey, _currentMissionVersion);
    await _saveMissions();
    print('데일리 미션이 리셋되었습니다.');
  }

  /// 미션 진행 업데이트
  Future<bool> updateMissionProgress(DailyMissionType type) async {
    await initialize(); // 매번 초기화해서 자정 체크
    
    final missionIndex = _missions.indexWhere((m) => m.type == type);
    if (missionIndex == -1) return false;

    final mission = _missions[missionIndex];

    // 이미 완료된 미션이면 무시
    if (mission.isCompleted) return false;

    // 진행도 증가
    final newCount = mission.currentCount + 1;
    final isNowCompleted = newCount >= mission.targetCount;

    _missions[missionIndex] = mission.copyWith(
      currentCount: newCount,
      isCompleted: isNowCompleted,
    );

    await _saveMissions();

    // 완료 상태만 반환 (코인은 사용자가 수동으로 수령해야 함)
    if (isNowCompleted) {
      print('미션 조건 달성! 미션 모달에서 보상을 수령하세요.');
      return true; // 새로 완료됨
    }

    return false; // 진행만 됨
  }

  /// 미션 보상 수령
  Future<bool> claimReward(DailyMissionType type) async {
    await initialize();
    
    final missionIndex = _missions.indexWhere((m) => m.type == type);
    if (missionIndex == -1) return false;

    final mission = _missions[missionIndex];

    // 완료되지 않았거나 이미 수령한 경우
    if (!mission.isCompleted || mission.isClaimed) return false;

    // 코인 지급
    await CoinManager.addCoins(mission.coinReward);
    
    // 수령 상태 업데이트
    _missions[missionIndex] = mission.copyWith(isClaimed: true);
    await _saveMissions();

    print('미션 보상 수령! ${mission.coinReward}코인 획득');
    return true;
  }

  /// 출석 체크 미션 완료
  Future<bool> completeAttendance() async {
    return await updateMissionProgress(DailyMissionType.attendance);
  }

  /// 게임 완료 미션 진행
  Future<bool> completeGame() async {
    return await updateMissionProgress(DailyMissionType.playGames);
  }

  /// 캐릭터 수집 미션 진행
  Future<bool> collectCharacter() async {
    return await updateMissionProgress(DailyMissionType.collectCharacter);
  }

  /// 광고 시청 미션 진행
  Future<bool> watchAd() async {
    return await updateMissionProgress(DailyMissionType.watchAd);
  }

  /// 친구에게 공유 미션 진행
  Future<bool> shareToFriend() async {
    return await updateMissionProgress(DailyMissionType.shareToFriend);
  }

  /// 전체 미션 리스트 반환
  List<DailyMission> get missions => List.unmodifiable(_missions);

  /// 완료된 미션 수 반환
  int get completedCount => _missions.where((m) => m.isCompleted).length;

  /// 전체 미션 수 반환
  int get totalCount => _missions.length;

  /// 모든 미션 완료 여부
  bool get allCompleted => completedCount == totalCount;

  /// 미션 강제 리셋 (테스트용)
  Future<void> forceReset() async {
    await _resetMissions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastResetDateKey, DateTime.now().toIso8601String());
  }
}

