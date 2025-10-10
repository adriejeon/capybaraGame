import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../data/collection_manager.dart';
import '../../utils/constants.dart';
import '../../sound_manager.dart';

/// 컬렉션 화면
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with WidgetsBindingObserver {
  final CollectionManager _collectionManager = CollectionManager();
  final SoundManager _soundManager = SoundManager();
  List<CollectionItem> _collection = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCollection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _soundManager.pauseBgm();
        break;
      case AppLifecycleState.resumed:
        _soundManager.resumeBgm();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        _soundManager.pauseBgm();
        break;
    }
  }

  Future<void> _loadCollection() async {
    try {
      await _collectionManager.initializeCollection();
      setState(() {
        _collection = _collectionManager.collection;
        _isLoading = false;
      });
    } catch (e) {
      print('컬렉션 로드 실패: $e');
      setState(() {
        _collection = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF), // 연한 파스텔 하늘색
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.collectionTitle),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 컬렉션 통계
                _buildCollectionStats(),

                // 컬렉션 그리드
                Expanded(
                  child: _buildCollectionGrid(),
                ),
              ],
            ),
    );
  }

  /// 컬렉션 통계 위젯
  Widget _buildCollectionStats() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                AppLocalizations.of(context)!.total,
                '${_collectionManager.unlockedCount}/${_collectionManager.totalCount}',
                const Color(0xFF4A90E2),
              ),
              _buildStatItem(
                AppLocalizations.of(context)!.easy,
                '${_collectionManager.getUnlockedCountByDifficulty(GameDifficulty.easy)}/20',
                const Color(0xFFFFD700), // 노란색
              ),
              _buildStatItem(
                AppLocalizations.of(context)!.normal,
                '${_collectionManager.getUnlockedCountByDifficulty(GameDifficulty.medium)}/15',
                const Color(0xFF4A90E2), // 파란색
              ),
              _buildStatItem(
                AppLocalizations.of(context)!.hard,
                '${_collectionManager.getUnlockedCountByDifficulty(GameDifficulty.hard)}/10',
                const Color(0xFF9B59B6), // 보라색
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _collectionManager.unlockedCount /
                _collectionManager.totalCount,
            backgroundColor: const Color(0xFFE6F3FF),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${AppLocalizations.of(context)!.completionRate}: ${((_collectionManager.unlockedCount / _collectionManager.totalCount) * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4A90E2),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 통계 아이템 위젯
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 컬렉션 그리드 위젯
  Widget _buildCollectionGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, // 한 줄에 5개
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: _collection.length,
        itemBuilder: (context, index) {
          final item = _collection[index];
          return _buildCollectionCard(item, index);
        },
      ),
    );
  }

  /// 컬렉션 카드 위젯
  Widget _buildCollectionCard(CollectionItem item, int index) {
    return GestureDetector(
      onTap: () => _onCardTapped(item, index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getDifficultyColor(item.difficulty).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // 카드 이미지
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: Image.asset(
                  item.isUnlocked
                      ? item.imagePath
                      : 'assets/capybara/collection/collection.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              // NEW 태그
              if (item.isUnlocked && item.isNew)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4444), // 빨간색 배경
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 난이도별 색상 반환
  Color _getDifficultyColor(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return const Color(0xFFFFD700); // 노란색
      case GameDifficulty.medium:
        return const Color(0xFF4A90E2); // 파란색
      case GameDifficulty.hard:
        return const Color(0xFF9B59B6); // 보라색
    }
  }

  /// 난이도 텍스트 반환
  String _getDifficultyText(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return AppLocalizations.of(context)!.easy;
      case GameDifficulty.medium:
        return AppLocalizations.of(context)!.normal;
      case GameDifficulty.hard:
        return AppLocalizations.of(context)!.hard;
    }
  }

  /// 카드 클릭 처리
  void _onCardTapped(CollectionItem item, int index) async {
    // NEW 태그가 있는 카드를 클릭한 경우 태그 제거
    if (item.isUnlocked && item.isNew) {
      await _collectionManager.removeNewTag(item.id);
      // 컬렉션 다시 로드하여 UI 업데이트
      await _loadCollection();
    }

    // 카드 상세 정보 다이얼로그 표시
    _showCardDetail(item, index);
  }

  /// 카드 상세 정보 다이얼로그
  void _showCardDetail(CollectionItem item, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 카드 이미지
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _getDifficultyColor(item.difficulty),
                    width: 3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item.isUnlocked
                        ? item.imagePath
                        : 'assets/capybara/collection/collection.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 50,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 카드 정보
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.cardNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '#${item.id}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.difficulty,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(item.difficulty),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getDifficultyText(item.difficulty),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.status,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          item.isUnlocked
                              ? AppLocalizations.of(context)!.unlocked
                              : AppLocalizations.of(context)!.locked,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: item.isUnlocked
                                ? const Color(0xFF5CB85C)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.close,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4A90E2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
