import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/theme_manager.dart';
import '../../services/coin_manager.dart';
import '../../sound_manager.dart';
import '../../l10n/app_localizations.dart';

/// 상점 화면
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ThemeManager _themeManager = ThemeManager();
  final SoundManager _soundManager = SoundManager();
  List<ThemeItem> _themes = [];
  int _currentCoins = 0;
  bool _isLoading = true;
  String _currentThemeId = 'default';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
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

  Future<void> _loadData() async {
    try {
      await _themeManager.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('테마 로드 타임아웃');
          throw TimeoutException('테마 로드 타임아웃');
        },
      );
      final coins = await CoinManager.getCoins();
      if (mounted) {
        setState(() {
          _themes = _themeManager.themes;
          _currentCoins = coins;
          _currentThemeId = _themeManager.currentThemeId;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('테마 로드 실패: $e');
      if (mounted) {
        setState(() {
          _themes = _themeManager.themes.isNotEmpty
              ? _themeManager.themes
              : [];
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
      backgroundColor: const Color(0xFFF0F8FF), // 연한 파스텔 하늘색
      appBar: AppBar(
        title: Text(localizations.shop),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
        actions: [
          // 코인 표시
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700),
                  width: 2,
                ),
              ),
              child: Row(
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
                  const SizedBox(width: 6),
                  Text(
                    _currentCoins.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 상점 통계
                _buildShopStats(),

                // 테마 그리드
                Expanded(
                  child: _buildThemeGrid(),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 한 줄에 2개
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
              // 테마 이미지 또는 기본 배경
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
              // 어두운 오버레이 (미구매 시)
              if (!theme.isPurchased)
                Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              // 선택됨 표시
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
              // 테마 정보
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
      // 이미 구매한 테마 -> 선택
      _selectTheme(theme);
    } else {
      // 미구매 테마 -> 구매 다이얼로그 표시
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
            // 테마 이미지 미리보기
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

    // 코인 차감
    final success = await CoinManager.spendCoins(theme.price);
    if (!success) {
      Navigator.of(context).pop();
      _showErrorMessage(localizations.notEnoughCoins);
      return;
    }

    // 테마 구매
    await _themeManager.purchaseTheme(theme.id);

    // 테마 자동 선택
    await _themeManager.selectTheme(theme.id);

    // 데이터 리로드
    await _loadData();

    if (mounted) {
      Navigator.of(context).pop();
      _showSuccessMessage(localizations.themePurchased);
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

