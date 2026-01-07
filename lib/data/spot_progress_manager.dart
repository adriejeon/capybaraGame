import 'package:shared_preferences/shared_preferences.dart';

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
  /// 저장된 값이 없으면 "1-1" 반환
  static Future<String> getCurrentStage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentStage) ?? '1-1';
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
  /// 현재: "1-1", 다음: "1-2" ... "1-6" 다음: "2-1" ... "5-6" 다음: null
  static String? getNextStageId(String currentStageId) {
    final parts = currentStageId.split('-');
    if (parts.length != 2) return null;

    final level = int.tryParse(parts[0]);
    final stage = int.tryParse(parts[1]);

    if (level == null || stage == null) return null;
    if (level < 1 || level > 5) return null;
    if (stage < 1 || stage > 6) return null;

    // 1-1부터 5-6까지 순차적으로 진행
    // 각 레벨마다 6개 스테이지 (1~6)
    if (stage < 6) {
      // 같은 레벨 내에서 다음 스테이지
      return '$level-${stage + 1}';
    } else if (level < 5) {
      // 다음 레벨의 첫 번째 스테이지
      return '${level + 1}-1';
    } else {
      // 마지막 스테이지 (5-6) 완료
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
    if (stage < 1 || stage > 6) return null;

    if (stage > 1) {
      // 같은 레벨 내에서 이전 스테이지
      return '$level-${stage - 1}';
    } else if (level > 1) {
      // 이전 레벨의 마지막 스테이지
      return '${level - 1}-6';
    } else {
      // 첫 번째 스테이지 (1-1)
      return null;
    }
  }

  /// 진행률 계산 (%)
  /// 총 30개 스테이지 (5레벨 x 6스테이지)
  static Future<double> getProgress() async {
    int completedCount = 0;
    const totalStages = 30; // 5 레벨 * 6 스테이지

    for (int level = 1; level <= 5; level++) {
      for (int stage = 1; stage <= 6; stage++) {
        final stageId = '$level-$stage';
        final completed = await isStageCompleted(stageId);
        if (completed) {
          completedCount++;
        }
      }
    }

    return (completedCount / totalStages) * 100;
  }

  /// 모든 진행 상태 초기화
  static Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 현재 스테이지를 1-1로 리셋
    await prefs.setString(_keyCurrentStage, '1-1');
    
    // 모든 스테이지 완료 상태 제거
    for (int level = 1; level <= 5; level++) {
      for (int stage = 1; stage <= 6; stage++) {
        final stageId = '$level-$stage';
        await prefs.remove('$_keyPrefix$stageId');
      }
    }
  }
}
