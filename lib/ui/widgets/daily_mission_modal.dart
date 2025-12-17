import 'package:flutter/material.dart';
import '../../data/daily_mission.dart';
import '../../services/daily_mission_service.dart';
import '../../services/coin_manager.dart';
import '../../l10n/app_localizations.dart';

/// 데일리 미션 모달
class DailyMissionModal extends StatefulWidget {
  const DailyMissionModal({super.key});

  @override
  State<DailyMissionModal> createState() => _DailyMissionModalState();
}

class _DailyMissionModalState extends State<DailyMissionModal> {
  final DailyMissionService _missionService = DailyMissionService();
  List<DailyMission> _missions = [];
  bool _isLoading = true;
  int _currentCoins = 0;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    await _missionService.initialize();
    final coins = await CoinManager.getCoins();
    
    if (mounted) {
      setState(() {
        _missions = _missionService.missions;
        _currentCoins = coins;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAttendanceCheck() async {
    final localizations = AppLocalizations.of(context)!;
    final completed = await _missionService.completeAttendance();
    
    if (completed) {
      // 미션 조건 달성 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.missionClaimSuccess,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.grey[900]!.withOpacity(0.8),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    
    await _loadMissions(); // 미션 상태 새로고침
  }

  Future<void> _claimMissionReward(DailyMission mission) async {
    final localizations = AppLocalizations.of(context)!;
    
    final claimed = await _missionService.claimReward(mission.type);
    
    if (claimed) {
      // 보상 받기 성공
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.missionCompleteReward(mission.coinReward),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.grey[900]!.withOpacity(0.8),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await _loadMissions(); // 미션 상태 새로고침
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.75;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        height: modalHeight,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F4F8),
              Color(0xFFD6EBF5),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF4A90E2),
            width: 3,
          ),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4A90E2),
                    Color(0xFF5BA3F5),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(27),
                  topRight: Radius.circular(27),
                ),
                border: const Border(
                  bottom: BorderSide(
                    color: Color(0xFF4A90E2),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.dailyMissions,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // 완료 카운트 표시
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_missionService.completedCount}/${_missionService.totalCount}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 미션 리스트
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _missions.length,
                      itemBuilder: (context, index) {
                        final mission = _missions[index];
                        return _buildMissionCard(mission, isKorean);
                      },
                    ),
            ),

            // 닫기 버튼
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.close,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(DailyMission mission, bool isKorean) {
    final title = isKorean ? mission.titleKo : mission.titleEn;
    final description = isKorean ? mission.descriptionKo : mission.descriptionEn;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // 메인 컨텐츠 (보상 수령하면 흐릿하게)
          Opacity(
            opacity: mission.isClaimed ? 0.5 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4A90E2),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 아이콘
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4A90E2),
                            Color(0xFF5BA3F5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _getMissionIcon(mission.type),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 텍스트 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A90E2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 진행 바
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: mission.progress,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF4A90E2),
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${mission.currentCount}/${mission.targetCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // 보상 표시
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/coin.webp',
                                width: 18,
                                height: 18,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.monetization_on,
                                    color: Colors.amber[700],
                                    size: 18,
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${mission.coinReward}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),

                          // 미션 버튼
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: _buildMissionButton(mission, isKorean),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 완료 도장 (보상 수령 시에만 표시)
          if (mission.isClaimed)
            Positioned.fill(
              child: Center(
                child: Image.asset(
                  'assets/images/mission_complete.webp',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getMissionIcon(DailyMissionType type) {
    switch (type) {
      case DailyMissionType.attendance:
        return Icons.event_available;
      case DailyMissionType.playGames:
        return Icons.games;
      case DailyMissionType.collectCharacter:
        return Icons.pets;
      case DailyMissionType.watchAd:
        return Icons.play_circle_outline;
      case DailyMissionType.shareToFriend:
        return Icons.share;
    }
  }

  Widget _buildMissionButton(DailyMission mission, bool isKorean) {
    final localizations = AppLocalizations.of(context)!;
    
    // 이미 보상을 받은 경우
    if (mission.isClaimed) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.grey[600],
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          localizations.missionClaimed,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 조건을 달성했지만 보상을 받지 않은 경우
    if (mission.isCompleted) {
      return ElevatedButton(
        onPressed: () => _claimMissionReward(mission),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50), // 초록색
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_giftcard, size: 18),
            const SizedBox(width: 6),
            Text(
              localizations.missionClaim,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // 출석 미션이고 조건 미달성인 경우
    if (mission.type == DailyMissionType.attendance) {
      return ElevatedButton(
        onPressed: _handleAttendanceCheck,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          localizations.missionCheckIn,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 기타 미션 - 진행중 상태
    return ElevatedButton(
      onPressed: null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.grey[600],
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Text(
        localizations.missionInProgress,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

