import 'package:shared_preferences/shared_preferences.dart';
import '../game/models/spot_difference_data.dart';

/// 틀린그림찾기 진행 상태 관리
class SpotProgressManager {
  static const String _keyPrefix = 'spot_progress_';
  static const String _keyCurrentStage = 'spot_current_stage';

  /// 현재 진행 중인 스테이지 저장 (예: "2-3")
  static Future<void> saveCurrentStage(String stageId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentStage, stageId);
  }

  /// 현재 진행 중인 스테이지 불러오기
  /// 저장된 값이 없거나 유효하지 않으면 "1-1" 반환
  static Future<String> getCurrentStage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStage = prefs.getString(_keyCurrentStage);
    
    if (savedStage == null) {
      return '1-1';
    }
    
    // 저장된 스테이지가 유효한지 확인
    if (_isValidStageId(savedStage)) {
      return savedStage;
    }
    
    // 유효하지 않은 스테이지면 1-1로 리셋
    await prefs.setString(_keyCurrentStage, '1-1');
    return '1-1';
  }
  
  /// 스테이지 ID가 유효한지 확인
  static bool _isValidStageId(String stageId) {
    final parts = stageId.split('-');
    if (parts.length != 2) return false;
    
    final level = int.tryParse(parts[0]);
    final stage = int.tryParse(parts[1]);
    
    if (level == null || stage == null) return false;
    if (level < 1 || level > 5) return false;
    
    // 레벨별 최대 스테이지 개수 확인
    final maxStage = SpotDifferenceDataManager.stageCountByLevel[level] ?? 6;
    if (stage < 1 || stage > maxStage) return false;
    
    return true;
  }

  /// 특정 스테이지 완료 여부 저장
  static Future<void> setStageCompleted(String stageId, bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$stageId', completed);
  }

  /// 특정 스테이지 완료 여부 확인
  static Future<bool> isStageCompleted(String stageId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$stageId') ?? false;
  }

  /// 다음 스테이지 ID 계산
  /// 현재: "1-1", 다음: "1-2" ... "1-6" 다음: "2-1" ... "5-7" 다음: null
  static String? getNextStageId(String currentStageId) {
    final parts = currentStageId.split('-');
    if (parts.length != 2) return null;

    final level = int.tryParse(parts[0]);
    final stage = int.tryParse(parts[1]);

    if (level == null || stage == null) return null;
    if (level < 1 || level > 5) return null;

    // 레벨별 최대 스테이지 개수 가져오기
    final maxStage = SpotDifferenceDataManager.stageCountByLevel[level] ?? 6;
    
    if (stage < 1 || stage > maxStage) return null;

    // 같은 레벨 내에서 다음 스테이지가 있는지 확인
    if (stage < maxStage) {
      return '$level-${stage + 1}';
    } else if (level < 5) {
      // 다음 레벨의 첫 번째 스테이지
      return '${level + 1}-1';
    } else {
      // 마지막 스테이지 (5-7) 완료
      return null;
    }
  }

  /// 이전 스테이지 ID 계산
  static String? getPreviousStageId(String currentStageId) {
    final parts = currentStageId.split('-');
    if (parts.length != 2) return null;

    final level = int.tryParse(parts[0]);
    final stage = int.tryParse(parts[1]);

    if (level == null || stage == null) return null;
    if (level < 1 || level > 5) return null;

    // 레벨별 최대 스테이지 개수 가져오기
    final maxStage = SpotDifferenceDataManager.stageCountByLevel[level] ?? 6;
    if (stage < 1 || stage > maxStage) return null;

    if (stage > 1) {
      // 같은 레벨 내에서 이전 스테이지
      return '$level-${stage - 1}';
    } else if (level > 1) {
      // 이전 레벨의 마지막 스테이지
      final prevLevelMaxStage = SpotDifferenceDataManager.stageCountByLevel[level - 1] ?? 6;
      return '${level - 1}-$prevLevelMaxStage';
    } else {
      // 첫 번째 스테이지 (1-1)
      return null;
    }
  }

  /// 진행률 계산 (%)
  /// 레벨별 스테이지 개수: 레벨1=6, 레벨2=6, 레벨3=6, 레벨4=6, 레벨5=7 (총 31개)
  static Future<double> getProgress() async {
    int completedCount = 0;
    int totalStages = 0;

    for (int level = 1; level <= 5; level++) {
      final stageCount = SpotDifferenceDataManager.stageCountByLevel[level] ?? 6;
      totalStages += stageCount;
      
      for (int stage = 1; stage <= stageCount; stage++) {
        final stageId = '$level-$stage';
        final completed = await isStageCompleted(stageId);
        if (completed) {
          completedCount++;
        }
      }
    }

    return totalStages > 0 ? (completedCount / totalStages) * 100 : 0.0;
  }

  /// 모든 진행 상태 초기화
  static Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 현재 스테이지를 1-1로 리셋
    await prefs.setString(_keyCurrentStage, '1-1');
    
    // 모든 스테이지 완료 상태 제거 (레벨별 스테이지 개수 고려)
    for (int level = 1; level <= 5; level++) {
      final stageCount = SpotDifferenceDataManager.stageCountByLevel[level] ?? 6;
      for (int stage = 1; stage <= stageCount; stage++) {
        final stageId = '$level-$stage';
        await prefs.remove('$_keyPrefix$stageId');
      }
    }
  }
}
