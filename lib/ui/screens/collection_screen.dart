import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../data/collection_manager.dart';
import '../../utils/constants.dart';
import '../../sound_manager.dart';
import '../../services/share_service.dart';
import '../../data/home_character_manager.dart';

/// 컬렉션 화면
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final CollectionManager _collectionManager = CollectionManager();
  final SoundManager _soundManager = SoundManager();
  final HomeCharacterManager _homeCharacterManager = HomeCharacterManager();
  List<CollectionItem> _collection = [];
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    // TabController는 initState에서 초기화
    _tabController = TabController(length: 5, vsync: this); // 5개 레벨
    WidgetsBinding.instance.addObserver(this);
    _loadCollection();
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
      await _collectionManager.initializeCollection().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('컬렉션 로드 타임아웃');
          throw TimeoutException('컬렉션 로드 타임아웃');
        },
      );
      if (mounted) {
        setState(() {
          _collection = _collectionManager.collection;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('컬렉션 로드 실패: $e');
      if (mounted) {
        setState(() {
          _collection = _collectionManager.collection.isNotEmpty
              ? _collectionManager.collection
              : [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // TabController가 초기화되지 않았으면 로딩 화면 표시
    if (_tabController == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F8FF),
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.collectionTitle),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF), // 연한 파스텔 하늘색
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.collectionTitle),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController!,
              isScrollable: true, // 가로 스크롤 가능
              tabAlignment: TabAlignment.start,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF4A90E2),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                Tab(text: AppLocalizations.of(context)!.level1),
                Tab(text: AppLocalizations.of(context)!.level2),
                Tab(text: AppLocalizations.of(context)!.level3),
                Tab(text: AppLocalizations.of(context)!.level4),
                Tab(text: AppLocalizations.of(context)!.level5),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController!,
              children: [
                // 레벨별 탭
                _buildTabContent(GameDifficulty.level1),
                _buildTabContent(GameDifficulty.level2),
                _buildTabContent(GameDifficulty.level3),
                _buildTabContent(GameDifficulty.level4),
                _buildTabContent(GameDifficulty.level5),
              ],
            ),
    );
  }

  /// 탭 컨텐츠 빌드
  Widget _buildTabContent(GameDifficulty difficulty) {
    // 난이도별로 필터링
    final filteredCollection = _collection
        .where((item) => item.difficulty == difficulty)
        .toList();

    return Column(
      children: [
        // 난이도별 완료율 표시
        _buildDifficultyStats(difficulty),

        // 컬렉션 그리드
        Expanded(
          child: _buildFilteredCollectionGrid(filteredCollection),
        ),
      ],
    );
  }

  /// 난이도별 완료율 위젯
  Widget _buildDifficultyStats(GameDifficulty difficulty) {
    final totalCount = difficulty == GameDifficulty.level5 ? 15 : 10;
    final unlockedCount =
        _collectionManager.getUnlockedCountByDifficulty(difficulty);
    final completionRate = (unlockedCount / totalCount) * 100;

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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$unlockedCount/$totalCount',
                style: TextStyle(
                  fontSize: 24,
                  color: _getDifficultyColor(difficulty),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: unlockedCount / totalCount,
            backgroundColor: const Color(0xFFE6F3FF),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getDifficultyColor(difficulty),
            ),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${AppLocalizations.of(context)!.completionRate}: ${completionRate.round()}%',
            style: TextStyle(
              fontSize: 14,
              color: _getDifficultyColor(difficulty),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 필터링된 컬렉션 그리드 위젯
  Widget _buildFilteredCollectionGrid(List<CollectionItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          Localizations.localeOf(context).languageCode == 'ko'
              ? '컬렉션이 없습니다'
              : 'No collection items',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, // 한 줄에 5개
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          // 원본 인덱스를 찾기 위해
          final originalIndex = _collection.indexOf(item);
          return _buildCollectionCard(item, originalIndex);
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
      case GameDifficulty.level1:
        return const Color(0xFF4CAF50); // 초록색
      case GameDifficulty.level2:
        return const Color(0xFF2196F3); // 파란색
      case GameDifficulty.level3:
        return const Color(0xFFFF9800); // 주황색
      case GameDifficulty.level4:
        return const Color(0xFF9C27B0); // 보라색
      case GameDifficulty.level5:
        return const Color(0xFFE91E63); // 핑크색
    }
  }

  /// 난이도 텍스트 반환
  String _getDifficultyText(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.level1:
        return AppLocalizations.of(context)!.level1;
      case GameDifficulty.level2:
        return AppLocalizations.of(context)!.level2;
      case GameDifficulty.level3:
        return AppLocalizations.of(context)!.level3;
      case GameDifficulty.level4:
        return AppLocalizations.of(context)!.level4;
      case GameDifficulty.level5:
        return AppLocalizations.of(context)!.level5;
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
          // 잠금 해제된 카드에만 버튼 표시
          if (item.isUnlocked) ...[
            // 홈에 배치 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // 컬렉션 이미지 경로를 홈 캐릭터 ID로 변환
                  final characterId = _homeCharacterManager
                      .convertCollectionPathToCharacterId(item.imagePath);
                  await _homeCharacterManager.setHomeCharacter(characterId);
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.setAsHomeSuccess,
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.home, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.setAsHome,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 친구에게 보여주기 버튼 (테두리만 있는 스타일)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ShareService.shareCharacter(
                    characterImagePath: item.imagePath,
                    context: context,
                  );
                },
                icon: const Icon(Icons.share, size: 20),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'ko'
                      ? '친구에게 보여주기'
                      : 'Show to Friends',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A90E2),
                  side: const BorderSide(
                    color: Color(0xFF4A90E2),
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
