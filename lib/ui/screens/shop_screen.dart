import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/theme_manager.dart';
import '../../services/coin_manager.dart';
import '../../services/iap_service.dart';
import '../../sound_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../data/ticket_manager.dart';
import '../../ads/admob_handler.dart';

/// 상점 화면
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ThemeManager _themeManager = ThemeManager();
  final SoundManager _soundManager = SoundManager();
  final IAPService _iapService = IAPService();
  final TicketManager _ticketManager = TicketManager();

  late TabController _tabController;

  // 인앱결제 구매 완료 스트림 리스닝용
  StreamSubscription<String>? _purchaseCompletedSubscription;

  List<ThemeItem> _themes = [];
  int _currentCoins = 0;
  int _currentTickets = 0;
  bool _isLoading = true;
  String _currentThemeId = 'default';
  bool _adsRemovedPurchased = false; // 광고 제거 구매 여부

  // 현재 구매 진행 중인 상품 ID (로딩 다이얼로그 관리용)
  String? _purchasingProductId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    // 인앱결제 구매 완료 스트림 리스닝 시작
    // 실제 구매가 완료되면 이 스트림을 통해 알림을 받음
    _purchaseCompletedSubscription = _iapService.purchaseCompleted.listen(
      _onPurchaseCompleted,
      onError: (error) {
        print('[ShopScreen] 구매 완료 스트림 에러: $error');
      },
    );

    _loadData();
  }

  @override
  void dispose() {
    _purchaseCompletedSubscription?.cancel();
    _tabController.dispose();
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

  Future<void> _loadData() async {
    try {
      await _themeManager.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('테마 로드 타임아웃');
          throw TimeoutException('테마 로드 타임아웃');
        },
      );
      await _iapService.initialize();
      await _ticketManager.initialize();

      // 광고 제거 구매 여부 확인
      final prefs = await SharedPreferences.getInstance();
      _adsRemovedPurchased = prefs.getBool('ads_removed_purchased') ?? false;

      final coins = await CoinManager.getCoins();
      if (mounted) {
        setState(() {
          _themes = _themeManager.themes;
          _currentCoins = coins;
          _currentTickets = _ticketManager.ticketCount;
          _currentThemeId = _themeManager.currentThemeId;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('데이터 로드 실패: $e');
      if (mounted) {
        setState(() {
          _themes = _themeManager.themes.isNotEmpty ? _themeManager.themes : [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Text(localizations.shop),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4A90E2),
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.palette),
              text: isKorean ? '테마 스토어' : 'Theme Store',
            ),
            Tab(
              icon: const Icon(Icons.shopping_bag),
              text: isKorean ? '코인 충전소' : 'Coin Shop',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildThemeStore(),
                _buildCoinShop(),
              ],
            ),
    );
  }

  /// 테마 스토어 탭
  Widget _buildThemeStore() {
    return Column(
      children: [
        // 코인 표시
        _buildCoinDisplay(),

        // 테마 그리드
        Expanded(
          child: _buildThemeGrid(),
        ),
      ],
    );
  }

  /// 코인 충전소 탭 (뽑기권 구매)
  Widget _buildCoinShop() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 현재 보유 티켓 표시
          _buildTicketDisplay(),

          const SizedBox(height: 24),

          // 코인 팩 섹션
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '⭐️',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  isKorean ? '뽑기권 구매' : 'Gacha Tickets',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 코인 팩 카드들
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildCoinPackCard(IAPService.products[0]), // 5개
                const SizedBox(height: 12),
                _buildCoinPackCard(IAPService.products[1]), // 20개 (주력)
                const SizedBox(height: 12),
                _buildCoinPackCard(IAPService.products[2]), // 60개
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 광고 제거 섹션
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isKorean ? '🚫 광고 제거' : '🚫 Remove Ads',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRemoveAdsCard(IAPService.products[3]),
          ),

          const SizedBox(height: 24),

          // 구매 복원 버튼
          Center(
            child: TextButton(
              onPressed: _restorePurchases,
              child: Text(
                isKorean ? '구매 복원' : 'Restore Purchases',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 코인 표시 위젯
  Widget _buildCoinDisplay() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/coin-2.webp',
            width: 32,
            height: 32,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.monetization_on,
                color: Colors.amber,
                size: 32,
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            '$_currentCoins',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Localizations.localeOf(context).languageCode == 'ko'
                ? '코인'
                : 'Coins',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 티켓 보유량 표시 위젯
  ///
  /// 흰색 테두리만으로 보유 뽑기권을 가로 배치하여 중앙 정렬하여 표시합니다.
  Widget _buildTicketDisplay() {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              isKorean ? '현재 보유 중인 뽑기권' : 'Current Gacha Tickets',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$_currentTickets${isKorean ? '개' : ''}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상품 ID에 맞는 썸네일 이미지 경로 반환
  String _getProductThumbnail(String productId) {
    switch (productId) {
      case IAPService.coinPack5Id:
        return 'assets/images/ticket_05.png';
      case IAPService.coinPack20Id:
        return 'assets/images/ticket_25.png';
      case IAPService.coinPack60Id:
        return 'assets/images/ticket_60.png';
      default:
        return 'assets/images/gacha_coin.webp';
    }
  }

  /// 코인 팩 카드
  Widget _buildCoinPackCard(IAPProduct product) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final price = _iapService.getProductPrice(product.id) ??
        (isKorean ? product.priceKo : product.priceEn);

    return GestureDetector(
      onTap: () => _purchaseProduct(product.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: product.isFeatured
              ? Border.all(color: const Color(0xFF4A90E2), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: product.isFeatured
                  ? const Color(0xFF4A90E2).withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: product.isFeatured ? 15 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                // 상품 썸네일 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    _getProductThumbnail(product.id),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.confirmation_number,
                          color: Color(0xFFFFB74D),
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // 상품 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 베스트 배지
                      if (product.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1493),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isKorean ? '베스트' : 'BEST',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (product.isFeatured) const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isKorean ? product.titleKo : product.titleEn,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          if (product.bonusAmount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${product.bonusAmount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isKorean
                            ? product.descriptionKo
                            : product.descriptionEn,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // 가격 버튼
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: product.isFeatured
                            ? const Color(0xFF4A90E2)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        price,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: product.isFeatured
                              ? Colors.white
                              : const Color(0xFF333333),
                        ),
                      ),
                    ),
                    // 할인 배지 (가격 버튼의 오른쪽 상단)
                    if (product.discountPercent > 0)
                      Positioned(
                        top: -16,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 광고 제거 카드
  ///
  /// 코인 팩 카드와 동일한 디자인으로 구성됩니다.
  /// 구매 완료 시 비활성화되고 "구매 완료" 칩이 표시됩니다.
  Widget _buildRemoveAdsCard(IAPProduct product) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final price = _iapService.getProductPrice(product.id) ??
        (isKorean ? product.priceKo : product.priceEn);

    return GestureDetector(
      onTap: _adsRemovedPurchased ? null : () => _purchaseProduct(product.id),
      child: Opacity(
        opacity: _adsRemovedPurchased ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 아이콘
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.block,
                  color: Color(0xFFFFB74D),
                  size: 40,
                ),
              ),
              const SizedBox(width: 16),

              // 상품 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKorean ? product.titleKo : product.titleEn,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isKorean ? product.descriptionKo : product.descriptionEn,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 가격 버튼 또는 구매 완료 칩
              const SizedBox(width: 24),
              _adsRemovedPurchased
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isKorean ? '구매 완료' : 'Purchased',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        price,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상점 통계 위젯
  Widget _buildShopStats() {
    final localizations = AppLocalizations.of(context)!;
    final purchasedCount = _themeManager.purchasedCount;
    final totalCount = _themeManager.totalCount;
    final completionRate = (purchasedCount / totalCount) * 100;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Text(
            localizations.purchasedThemes,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$purchasedCount/$totalCount',
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF4A90E2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: purchasedCount / totalCount,
            backgroundColor: const Color(0xFFE6F3FF),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF4A90E2),
            ),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${localizations.completionRate}: ${completionRate.round()}%',
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

  /// 테마 그리드 위젯
  Widget _buildThemeGrid() {
    if (_themes.isEmpty) {
      return Center(
        child: Text(
          Localizations.localeOf(context).languageCode == 'ko'
              ? '테마가 없습니다'
              : 'No themes available',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _themes.length,
        itemBuilder: (context, index) {
          final theme = _themes[index];
          return _buildThemeCard(theme);
        },
      ),
    );
  }

  /// 테마 카드 위젯
  Widget _buildThemeCard(ThemeItem theme) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final isSelected = theme.id == _currentThemeId;
    final canPurchase = !theme.isPurchased && _currentCoins >= theme.price;

    return GestureDetector(
      onTap: () => _onThemeCardTapped(theme),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A90E2)
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: theme.imagePath.isEmpty
                    ? Container(
                        color: const Color(0xFFF0F8FF),
                        child: const Center(
                          child: Icon(
                            Icons.palette,
                            size: 64,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      )
                    : Image.asset(
                        theme.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 48,
                            ),
                          );
                        },
                      ),
              ),
              if (!theme.isPurchased)
                Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKorean ? theme.name : theme.nameEn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (theme.isPurchased)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.purchased,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/coin-2.webp',
                              width: 18,
                              height: 18,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber,
                                  size: 18,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${theme.price}',
                              style: TextStyle(
                                color: canPurchase
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 테마 카드 탭 이벤트
  void _onThemeCardTapped(ThemeItem theme) {
    if (theme.isPurchased) {
      _selectTheme(theme);
    } else {
      _showPurchaseDialog(theme);
    }
  }

  /// 테마 선택
  void _selectTheme(ThemeItem theme) async {
    await _themeManager.selectTheme(theme.id);
    if (mounted) {
      setState(() {
        _currentThemeId = theme.id;
      });
      _showSuccessMessage(AppLocalizations.of(context)!.themeApplied);
    }
  }

  /// 구매 다이얼로그 표시
  void _showPurchaseDialog(ThemeItem theme) {
    final localizations = AppLocalizations.of(context)!;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    final canPurchase = _currentCoins >= theme.price;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          localizations.themePurchase,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4A90E2),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: theme.imagePath.isEmpty
                    ? Container(
                        color: const Color(0xFFF0F8FF),
                        child: const Center(
                          child: Icon(
                            Icons.palette,
                            size: 48,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      )
                    : Image.asset(
                        theme.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 32,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isKorean ? theme.name : theme.nameEn,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/coin-2.webp',
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 24,
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '${theme.price}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!canPurchase)
              Text(
                localizations.notEnoughCoins,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              localizations.cancel,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: canPurchase ? () => _purchaseTheme(theme) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              localizations.purchase,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 테마 구매
  void _purchaseTheme(ThemeItem theme) async {
    final localizations = AppLocalizations.of(context)!;

    final success = await CoinManager.spendCoins(theme.price);
    if (!success) {
      Navigator.of(context).pop();
      _showErrorMessage(localizations.notEnoughCoins);
      return;
    }

    await _themeManager.purchaseTheme(theme.id);
    await _themeManager.selectTheme(theme.id);
    await _loadData();

    if (mounted) {
      Navigator.of(context).pop();
      _showSuccessMessage(localizations.themePurchased);
    }
  }

  /// 인앱결제 상품 구매
  ///
  /// [productId]에 해당하는 상품의 구매를 요청합니다.
  ///
  /// 중요: buyProduct()의 반환값은 구매 요청이 성공적으로 시작되었는지만 나타냅니다.
  /// 실제 구매 완료는 purchaseCompleted 스트림을 통해 _onPurchaseCompleted()에서 처리됩니다.
  void _purchaseProduct(String productId) async {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    // 이미 구매 중인 경우 중복 요청 방지
    if (_purchasingProductId != null) {
      _showErrorMessage(
        isKorean
            ? '구매 처리 중입니다. 잠시만 기다려주세요.'
            : 'Purchase in progress. Please wait.',
      );
      return;
    }

    // 구매 중 로딩 표시
    _purchasingProductId = productId;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              isKorean ? '구매 처리 중...' : 'Processing purchase...',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );

    // 구매 요청 시작
    // 반환값은 요청 시작 성공 여부일 뿐, 실제 구매 완료는 아님
    final success = await _iapService.buyProduct(productId);

    if (mounted) {
      if (!success) {
        // 구매 요청 실패 시 (상품을 찾을 수 없음, 이미 구매함 등)
        Navigator.of(context).pop(); // 로딩 닫기
        _purchasingProductId = null;

        _showErrorMessage(
          isKorean
              ? '구매 요청에 실패했습니다. 다시 시도해주세요.'
              : 'Purchase request failed. Please try again.',
        );
      }
      // 구매 요청이 성공한 경우, 실제 구매 완료는 _onPurchaseCompleted()에서 처리됨
      // 로딩 다이얼로그는 구매 완료 시점에 닫힘
    }
  }

  /// 구매 완료 콜백
  ///
  /// purchaseCompleted 스트림을 통해 실제 구매가 완료되었을 때 호출됩니다.
  /// 이 시점에서 UI를 업데이트하고 성공 메시지를 표시합니다.
  void _onPurchaseCompleted(String productId) async {
    if (!mounted) return;

    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    // 로딩 다이얼로그 닫기
    if (_purchasingProductId == productId) {
      Navigator.of(context).pop();
      _purchasingProductId = null;
    }

    // 광고 제거 상품 구매 완료 시 상태 업데이트
    if (productId == IAPService.removeAdsId) {
      final prefs = await SharedPreferences.getInstance();
      _adsRemovedPurchased = prefs.getBool('ads_removed_purchased') ?? false;
    }

    // 데이터 리로드
    await _ticketManager.initialize();

    // UI 업데이트
    setState(() {
      _currentTickets = _ticketManager.ticketCount;
    });

    // 성공 메시지 표시
    _showSuccessMessage(
      isKorean ? '구매가 완료되었습니다!' : 'Purchase complete!',
    );

    print('[ShopScreen] 구매 완료 처리됨: $productId');
  }

  /// 구매 복원
  ///
  /// 비소비성 상품(광고 제거 등)의 구매를 복원합니다.
  /// 복원된 구매는 purchaseCompleted 스트림을 통해 알림을 받습니다.
  void _restorePurchases() async {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    // 구매 복원 요청
    await _iapService.restorePurchases();

    if (mounted) {
      // 복원은 비동기로 처리되므로, 실제 복원 완료는 purchaseCompleted 스트림을 통해 알림을 받음
      // 여기서는 요청이 제출되었다는 메시지만 표시
      _showSuccessMessage(
        isKorean
            ? '구매 복원을 요청했습니다. 잠시만 기다려주세요.'
            : 'Restore request submitted. Please wait.',
      );
    }
  }

  /// 성공 메시지 표시
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 에러 메시지 표시
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
