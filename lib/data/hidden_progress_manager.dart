import 'package:shared_preferences/shared_preferences.dart';
import '../game/models/hidden_picture_data.dart';

/// 숨은그림찾기 진행 상태 관리
class HiddenProgressManager {
  static const String _keyPrefix = 'hidden_progress_';
  static const String _keyCurrentStage = 'hidden_current_stage';

  /// 현재 진행 중인 스테이지 저장 (1~10)
  static Future<void> saveCurrentStage(int stageId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentStage, stageId);
  }

  /// 현재 진행 중인 스테이지 불러오기
  /// 저장된 값이 없거나 유효하지 않으면 1 반환
  static Future<int> getCurrentStage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStage = prefs.getInt(_keyCurrentStage);
    
    if (savedStage == null) {
      return 1;
    }
    
    // 저장된 스테이지가 유효한지 확인
    if (_isValidStageId(savedStage)) {
      return savedStage;
    }
    
    // 유효하지 않은 스테이지면 1로 리셋
    await prefs.setInt(_keyCurrentStage, 1);
    return 1;
  }
  
  /// 스테이지 ID가 유효한지 확인
  static bool _isValidStageId(int stageId) {
    return stageId >= 1 && stageId <= HiddenPictureDataManager.totalStages;
  }

  /// 특정 스테이지 완료 여부 저장
  static Future<void> setStageCompleted(int stageId, bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$stageId', completed);
  }

  /// 특정 스테이지 완료 여부 확인
  static Future<bool> isStageCompleted(int stageId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$stageId') ?? false;
  }

  /// 다음 스테이지 ID 계산 (1 → 2 → 3 → ... → 10 → null)
  static int? getNextStageId(int currentStage) {
    return HiddenPictureDataManager.getNextStageId(currentStage);
  }

  /// 이전 스테이지 ID 계산 (10 → 9 → 8 → ... → 1 → null)
  static int? getPreviousStageId(int currentStage) {
    return HiddenPictureDataManager.getPreviousStageId(currentStage);
  }

  /// 진행률 계산 (%)
  static Future<double> getProgress() async {
    int completedCount = 0;
    final totalStages = HiddenPictureDataManager.totalStages;

    for (int stage = 1; stage <= totalStages; stage++) {
      final completed = await isStageCompleted(stage);
      if (completed) {
        completedCount++;
      }
    }

    return totalStages > 0 ? (completedCount / totalStages) * 100 : 0.0;
  }

  /// 마지막 완료된 스테이지의 다음 스테이지 ID 찾기
  /// 이어서하기 기능에서 사용: 완료된 스테이지 중 가장 마지막 스테이지의 다음 스테이지 반환
  /// 완료된 스테이지가 없으면 1 반환
  static Future<int> getNextStageFromLastCompleted() async {
    int? lastCompletedStageId;
    
    // 모든 스테이지를 순서대로 확인하여 마지막 완료된 스테이지 찾기
    for (int stage = 1; stage <= HiddenPictureDataManager.totalStages; stage++) {
      final completed = await isStageCompleted(stage);
      if (completed) {
        lastCompletedStageId = stage;
      }
    }
    
    // 마지막 완료된 스테이지가 있으면 그 다음 스테이지 반환
    if (lastCompletedStageId != null) {
      final nextStageId = getNextStageId(lastCompletedStageId);
      if (nextStageId != null) {
        return nextStageId;
      }
      // 마지막 스테이지까지 모두 완료한 경우, 마지막 스테이지 반환
      return lastCompletedStageId;
    }
    
    // 완료된 스테이지가 없으면 첫 번째 스테이지 반환
    return 1;
  }

  /// 모든 진행 상태 초기화
  static Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 현재 스테이지를 1로 리셋
    await prefs.setInt(_keyCurrentStage, 1);
    
    // 모든 스테이지 완료 상태 제거
    for (int stage = 1; stage <= HiddenPictureDataManager.totalStages; stage++) {
      await prefs.remove('$_keyPrefix$stage');
    }
  }
}
