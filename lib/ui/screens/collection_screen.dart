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
    // 난이도별 이야기 목록 가져오기
    final stories = _collectionManager.getStoriesByDifficulty(difficulty);

    return Column(
      children: [
        // 난이도별 완료율 표시
        _buildDifficultyStats(difficulty),

        // 이야기 그룹 리스트
        Expanded(
          child: _buildStoriesList(stories, difficulty),
        ),
      ],
    );
  }

  /// 난이도별 완료율 위젯
  Widget _buildDifficultyStats(GameDifficulty difficulty) {
    // 각 난이도별 실제 카드 개수
    int totalCount;
    if (difficulty == GameDifficulty.level1) {
      totalCount = 20; // 아기 단계: 20개 (에피소드 1: 10개 + 에피소드 2: 10개)
    } else if (difficulty == GameDifficulty.level2) {
      totalCount = 20; // 어린이 단계: 20개 (에피소드 1: 10개 + 에피소드 2: 10개)
    } else if (difficulty == GameDifficulty.level3) {
      totalCount = 20; // 청소년 단계: 20개 (에피소드 1: 10개 + 에피소드 2: 10개)
    } else if (difficulty == GameDifficulty.level4) {
      totalCount = 10; // 어른 단계: 10개
    } else {
      totalCount = 10; // 신의 경지: 10개
    }
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

  /// 이야기 리스트 위젯
  Widget _buildStoriesList(List<Story> stories, GameDifficulty difficulty) {
    if (stories.isEmpty) {
      return Center(
        child: Text(
          Localizations.localeOf(context).languageCode == 'ko'
              ? '이야기가 없습니다'
              : 'No stories',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    // 신의 경지 단계는 하나의 그룹으로 합쳐서 표시
    if (difficulty == GameDifficulty.level5 && stories.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildCombinedLevel5Group(stories, difficulty),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: stories.length,
      itemBuilder: (context, index) {
        final story = stories[index];
        return _buildStoryGroup(story, difficulty);
      },
    );
  }

  /// 신의 경지 단계 통합 그룹 위젯 (10개 카드 모두 표시)
  Widget _buildCombinedLevel5Group(List<Story> stories, GameDifficulty difficulty) {
    // 신의 경지는 story.id == 5만 사용 (정확히 10개)
    final targetStory = stories.firstWhere(
      (s) => s.id == 5,
      orElse: () => stories.first,
    );
    final allCards = _collectionManager.getCardsByStoryId(targetStory.id);
    
    final totalUnlocked = _collectionManager.getUnlockedCountByDifficulty(difficulty);
    final totalCount = 10; // 신의 경지는 항상 10개
    final isAllUnlocked = totalUnlocked >= totalCount;
    final locale = Localizations.localeOf(context);
    final isKo = locale.languageCode == 'ko';
    
    // story.id == 5의 제목 사용
    final firstStory = targetStory;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이야기 제목
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getDifficultyColor(difficulty).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Text(
                  isKo ? firstStory.titleKo : firstStory.titleEn,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getDifficultyColor(difficulty),
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalUnlocked/$totalCount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // 카드 그리드 (10개 모두 표시)
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: allCards.length,
              itemBuilder: (context, index) {
                final card = allCards[index];
                final originalIndex = _collection.indexOf(card);
                return _buildCollectionCard(card, originalIndex);
              },
            ),
          ),
          // 히든 스토리 보기 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAllUnlocked ? () {
                  // 신의 경지 단계는 story.id == 5를 전달
                  _showStoryDetail(targetStory);
                } : null,
                child: Text(
                  isKo ? '히든 스토리 보기' : 'View Hidden Story',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAllUnlocked
                      ? _getDifficultyColor(difficulty)
                      : Colors.grey[300],
                  foregroundColor: isAllUnlocked
                      ? Colors.white
                      : Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 이야기 그룹 위젯
  Widget _buildStoryGroup(Story story, GameDifficulty difficulty) {
    final cards = _collectionManager.getCardsByStoryId(story.id);
    final unlockedCount = _collectionManager.getUnlockedCardCountByStoryId(story.id);
    final totalCount = cards.length;
    
    // 각 에피소드 그룹의 모든 카드를 모았는지 확인
    final isAllUnlocked = unlockedCount == totalCount;
    
    final locale = Localizations.localeOf(context);
    final isKo = locale.languageCode == 'ko';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이야기 제목
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getDifficultyColor(difficulty).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Text(
                  isKo ? story.titleKo : story.titleEn,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getDifficultyColor(difficulty),
                  ),
                ),
                const Spacer(),
                Text(
                  '$unlockedCount/$totalCount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // 카드 그리드
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                final originalIndex = _collection.indexOf(card);
                return _buildCollectionCard(card, originalIndex);
              },
            ),
          ),
          // 히든 스토리 보기 버튼
          // 신의 경지 단계는 두 그룹 모두에 버튼 표시, 전체 15개를 모았을 때만 활성화
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAllUnlocked ? () {
                  _showStoryDetail(story);
                } : null,
                child: Text(
                  isKo ? '히든 스토리 보기' : 'View Hidden Story',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAllUnlocked
                      ? _getDifficultyColor(difficulty)
                      : Colors.grey[300],
                  foregroundColor: isAllUnlocked
                      ? Colors.white
                      : Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
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
                      : 'assets/images/null-card.png',
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
                        : 'assets/images/null-card.png',
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
                        backgroundColor: Colors.grey[900]!.withOpacity(0.8),
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

  /// 이야기 상세 정보 다이얼로그
  void _showStoryDetail(Story story) {
    final locale = Localizations.localeOf(context);
    final isKo = locale.languageCode == 'ko';
    
    // 아기 단계(story.id == 1, 7), 어린이 단계(story.id == 2, 8), 청소년 단계(story.id == 3, 9), 어른 단계(story.id == 4), 신의 경지(story.id == 5)일 때는 웹툰 모달 표시
    if (story.id == 1 || story.id == 7 || story.id == 2 || story.id == 8 || story.id == 3 || story.id == 9 || story.id == 4 || story.id == 5) {
      _showStoryComicModal(story);
      return;
    }
    
    final cards = _collectionManager.getCardsByStoryId(story.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getDifficultyColor(story.difficulty),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isKo ? story.titleKo : story.titleEn,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getDifficultyColor(story.difficulty),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이야기 설명
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(story.difficulty).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isKo ? story.descriptionKo : story.descriptionEn,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 수집한 카드들
                Text(
                  isKo ? '수집한 카드들' : 'Collected Cards',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: card.isUnlocked
                              ? _getDifficultyColor(story.difficulty)
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          card.isUnlocked
                              ? card.imagePath
                              : 'assets/images/null-card.png',
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
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.close,
              style: TextStyle(
                fontSize: 16,
                color: _getDifficultyColor(story.difficulty),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 웹툰 이야기 모달 표시
  void _showStoryComicModal(Story story) {
    final locale = Localizations.localeOf(context);
    final isKo = locale.languageCode == 'ko';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => _StoryComicModal(
        story: story,
        isKo: isKo,
      ),
    );
  }
}

/// 웹툰 이야기 모달 위젯
class _StoryComicModal extends StatefulWidget {
  final Story story;
  final bool isKo;

  const _StoryComicModal({
    required this.story,
    required this.isKo,
  });

  @override
  State<_StoryComicModal> createState() => _StoryComicModalState();
}

class _StoryComicModalState extends State<_StoryComicModal>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _currentPage = 0;

  // 이미지 경로 리스트
  List<String> get _imagePaths {
    if (widget.story.id == 1) {
      // 아기 단계 - 에피소드 1 (걸음마 연습)
      if (widget.isKo) {
        return [
          'assets/toon/baby_story_1.png',
          'assets/toon/baby_story_2.png',
          'assets/toon/baby_story_3.png',
        ];
      } else {
        return [
          'assets/toon/baby_story_en_1.png',
          'assets/toon/baby_story_en_2.png',
          'assets/toon/baby_story_en_3.png',
        ];
      }
    } else if (widget.story.id == 7) {
      // 아기 단계 - 에피소드 2 (엄마처럼 하고 싶어!)
      if (widget.isKo) {
        return [
          'assets/toon/baby_story_2_1.png',
          'assets/toon/baby_story_2_2.png',
          'assets/toon/baby_story_2_3.png',
        ];
      } else {
        return [
          'assets/toon/baby_story_2_en_1.png',
          'assets/toon/baby_story_2_en_2.png',
          'assets/toon/baby_story_2_en_3.png',
        ];
      }
    } else if (widget.story.id == 2) {
      // 어린이 단계 - 에피소드 1 (친구가 좋아)
      if (widget.isKo) {
        return [
          'assets/toon/child_story_1.png',
          'assets/toon/child_story_2.png',
          'assets/toon/child_story_3.png',
        ];
      } else {
        return [
          'assets/toon/child_story_en_1.png',
          'assets/toon/child_story_en_2.png',
          'assets/toon/child_story_en_3.png',
        ];
      }
    } else if (widget.story.id == 8) {
      // 어린이 단계 - 에피소드 2 (첫 이별)
      if (widget.isKo) {
        return [
          'assets/toon/child_story_2_1.png',
          'assets/toon/child_story_2_2.png',
          'assets/toon/child_story_2_3.png',
        ];
      } else {
        return [
          'assets/toon/child_story_2_en_1.png',
          'assets/toon/child_story_2_en_2.png',
          'assets/toon/child_story_2_en_3.png',
        ];
      }
    } else if (widget.story.id == 3) {
      // 청소년 단계 - 에피소드 1 (첫 사랑)
      if (widget.isKo) {
        return [
          'assets/toon/teen_story_1.png',
          'assets/toon/teen_story_2.png',
          'assets/toon/teen_story_3.png',
        ];
      } else {
        return [
          'assets/toon/teen_story_en_1.png',
          'assets/toon/teen_story_en_2.png',
          'assets/toon/teen_story_en_3.png',
        ];
      }
    } else if (widget.story.id == 9) {
      // 청소년 단계 - 에피소드 2 (나만의 감성)
      if (widget.isKo) {
        return [
          'assets/toon/teen_story_2_1.png',
          'assets/toon/teen_story_2_2.png',
          'assets/toon/teen_story_2_3.png',
        ];
      } else {
        return [
          'assets/toon/teen_story_2_en_1.png',
          'assets/toon/teen_story_2_en_2.png',
          'assets/toon/teen_story_2_en_3.png',
        ];
      }
    } else if (widget.story.id == 4) {
      // 어른 단계
      if (widget.isKo) {
        return [
          'assets/toon/adult_story_1.png',
          'assets/toon/adult_story_2.png',
          'assets/toon/adult_story_3.png',
        ];
      } else {
        return [
          'assets/toon/adult_story_en_1.png',
          'assets/toon/adult_story_en_2.png',
          'assets/toon/adult_story_en_3.png',
        ];
      }
    } else if (widget.story.id == 5) {
      // 신의 경지 단계
      if (widget.isKo) {
        return [
          'assets/toon/god_story_1.png',
          'assets/toon/god_story_2.png',
          'assets/toon/god_story_3.png',
        ];
      } else {
        return [
          'assets/toon/god_story_en_1.png',
          'assets/toon/god_story_en_2.png',
          'assets/toon/god_story_en_3.png',
        ];
      }
    } else {
      // 기본값 (아기 단계)
      if (widget.isKo) {
        return [
          'assets/toon/baby_story_1.png',
          'assets/toon/baby_story_2.png',
          'assets/toon/baby_story_3.png',
        ];
      } else {
        return [
          'assets/toon/baby_story_en_1.png',
          'assets/toon/baby_story_en_2.png',
          'assets/toon/baby_story_en_3.png',
        ];
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isKo
                              ? widget.story.titleKo
                              : widget.story.titleEn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // 페이지 인디케이터
                      Text(
                        '${_currentPage + 1}/${_imagePaths.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 닫기 버튼
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // 웹툰 이미지 뷰어
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _imagePaths.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          // 탭으로도 다음 페이지 이동 가능
                          if (index < _imagePaths.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Image.asset(
                            _imagePaths[index],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white54,
                                      size: 50,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      widget.isKo
                                          ? '이미지를 불러올 수 없습니다'
                                          : 'Failed to load image',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 하단 네비게이션
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 이전 버튼
                      ElevatedButton.icon(
                        onPressed: _currentPage > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          widget.isKo ? '이전' : 'Previous',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white.withOpacity(0.0),
                          disabledForegroundColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      // 페이지 인디케이터 점
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _imagePaths.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                      // 다음 버튼
                      ElevatedButton.icon(
                        onPressed: _currentPage < _imagePaths.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          widget.isKo ? '다음' : 'Next',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white.withOpacity(0.0),
                          disabledForegroundColor: Colors.white.withOpacity(0.3),
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
    );
  }
}
