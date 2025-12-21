import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/ticket_manager.dart';
import '../ads/admob_handler.dart';

/// 인앱결제 상품 정보
class IAPProduct {
  final String id;
  final String titleKo;
  final String titleEn;
  final String descriptionKo;
  final String descriptionEn;
  final int coinAmount;
  final int bonusAmount;
  final String priceKo;
  final String priceEn;
  final bool isFeatured; // 주력 상품 여부
  final int discountPercent; // 할인율 (0이면 할인 없음)
  final bool isAdRemoval; // 광고 제거 상품 여부

  const IAPProduct({
    required this.id,
    required this.titleKo,
    required this.titleEn,
    required this.descriptionKo,
    required this.descriptionEn,
    required this.coinAmount,
    this.bonusAmount = 0,
    required this.priceKo,
    required this.priceEn,
    this.isFeatured = false,
    this.discountPercent = 0,
    this.isAdRemoval = false,
  });

  int get totalCoins => coinAmount + bonusAmount;
}

/// 인앱결제 서비스
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final TicketManager _ticketManager = TicketManager();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isPurchasePending = false;

  // 구매 완료 콜백을 위한 StreamController
  // UI에서 실제 구매 완료를 감지하기 위해 사용
  final StreamController<String> _purchaseCompletedController =
      StreamController<String>.broadcast();
  Stream<String> get purchaseCompleted => _purchaseCompletedController.stream;

  // 광고 제거 구매 여부 확인용 키
  static const String _adsRemovedPurchasedKey = 'ads_removed_purchased';

  // 상품 ID 정의
  static const String coinPack5Id = 'gacha_coin_5';
  static const String coinPack20Id = 'gacha_coin_20';
  static const String coinPack60Id = 'gacha_coin_60';
  static const String removeAdsId = 'remove_ads';

  // 상품 정보 (UI 표시용)
  static const List<IAPProduct> products = [
    IAPProduct(
      id: coinPack5Id,
      titleKo: '가챠 코인 5개',
      titleEn: '5 Gacha Coins',
      descriptionKo: '가챠 코인 5개를 획득합니다',
      descriptionEn: 'Get 5 Gacha Coins',
      coinAmount: 5,
      priceKo: '₩1,500',
      priceEn: '\$0.99',
    ),
    IAPProduct(
      id: coinPack20Id,
      titleKo: '가챠 코인 20개',
      titleEn: '20 Gacha Coins',
      descriptionKo: '20개 + 보너스 5개!',
      descriptionEn: '20 + 5 Bonus!',
      coinAmount: 20,
      bonusAmount: 5,
      priceKo: '₩4,900',
      priceEn: '\$3.99',
      isFeatured: true,
      discountPercent: 25,
    ),
    IAPProduct(
      id: coinPack60Id,
      titleKo: '가챠 코인 60개',
      titleEn: '60 Gacha Coins',
      descriptionKo: '대량 구매 팩',
      descriptionEn: 'Bulk Pack',
      coinAmount: 60,
      priceKo: '₩12,000',
      priceEn: '\$9.99',
    ),
    IAPProduct(
      id: removeAdsId,
      titleKo: '광고 제거',
      titleEn: 'Remove Ads',
      descriptionKo: '모든 광고를 영구적으로 제거합니다',
      descriptionEn: 'Remove all ads permanently',
      coinAmount: 0,
      priceKo: '₩4,900',
      priceEn: '\$3.99',
      isAdRemoval: true,
    ),
  ];

  bool get isAvailable => _isAvailable;
  bool get isPurchasePending => _isPurchasePending;
  List<ProductDetails> get storeProducts => _products;

  /// 서비스 초기화
  ///
  /// 인앱결제 서비스를 초기화하고 상품 정보를 로드합니다.
  /// 예외 발생 시 안전하게 처리하여 앱 크래시를 방지합니다.
  Future<void> initialize() async {
    try {
      // 인앱결제 사용 가능 여부 확인
      // iOS 시뮬레이터나 스토어 연결 실패 시 예외가 발생할 수 있음
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        print('[IAP] 인앱결제를 사용할 수 없습니다');
        return;
      }

      // 구매 스트림 리스닝
      // 실제 구매 완료는 이 스트림을 통해 비동기로 처리됨
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (error) {
          print('[IAP] 구매 스트림 에러: $error');
        },
      );

      // 상품 정보 로드
      await _loadProducts();

      // 티켓 매니저 초기화
      await _ticketManager.initialize();

      // 기존 구매 상태 확인 (광고 제거 등 비소비성 상품)
      await _checkExistingPurchases();
    } catch (e) {
      // 초기화 중 예외 발생 시 안전하게 처리
      print('[IAP] 초기화 실패: $e');
      _isAvailable = false;
    }
  }

  /// 기존 구매 상태 확인
  ///
  /// 비소비성 상품(광고 제거 등)의 구매 상태를 확인하고 복원합니다.
  Future<void> _checkExistingPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adsRemovedPurchased =
          prefs.getBool(_adsRemovedPurchasedKey) ?? false;

      if (adsRemovedPurchased) {
        // 이미 구매한 경우 광고 제거 상태 복원
        await AdmobHandler().setAdsRemoved(true);
        print('[IAP] 기존 광고 제거 구매 상태 복원됨');
      }
    } catch (e) {
      print('[IAP] 기존 구매 상태 확인 실패: $e');
    }
  }

  /// 상품 정보 로드
  Future<void> _loadProducts() async {
    final Set<String> productIds = {
      coinPack5Id,
      coinPack20Id,
      coinPack60Id,
      removeAdsId,
    };

    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        print('[IAP] 상품 조회 에러: ${response.error}');
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        print('[IAP] 찾을 수 없는 상품: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      print('[IAP] 로드된 상품: ${_products.length}개');
    } catch (e) {
      print('[IAP] 상품 로드 실패: $e');
    }
  }

  /// 구매 업데이트 처리
  ///
  /// purchaseStream을 통해 전달되는 구매 상태 변경을 처리합니다.
  /// 실제 구매 완료는 이 메서드에서 처리되며, UI는 purchaseCompleted 스트림을 통해 알림을 받습니다.
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          // 구매 요청이 제출되었고 처리 중인 상태
          _isPurchasePending = true;
          print('[IAP] 구매 대기 중: ${purchaseDetails.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 구매가 성공적으로 완료된 상태
          _isPurchasePending = false;
          print('[IAP] 구매 완료: ${purchaseDetails.productID}');

          // 구매 검증 및 보상 지급
          await _deliverProduct(purchaseDetails);

          // 구매 완료 처리 (스토어에 완료 신호 전송)
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }

          // UI에 구매 완료 알림 (실제 구매 완료 시점)
          _purchaseCompletedController.add(purchaseDetails.productID);
          break;

        case PurchaseStatus.error:
          // 구매 중 에러 발생
          _isPurchasePending = false;
          print('[IAP] 구매 에러: ${purchaseDetails.error}');
          break;

        case PurchaseStatus.canceled:
          // 사용자가 구매를 취소함
          _isPurchasePending = false;
          print('[IAP] 구매 취소됨');
          break;
      }
    }
  }

  /// 상품 배달 (보상 지급)
  ///
  /// 구매가 완료된 상품에 대한 보상을 지급합니다.
  /// 소비성 상품(코인)은 매번 지급되고, 비소비성 상품(광고 제거)은 한 번만 지급됩니다.
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final productId = purchaseDetails.productID;

    if (productId == coinPack5Id) {
      // 가챠 코인 5개 지급 (소비성 상품)
      await _ticketManager.addTickets(5);
      print('[IAP] 가챠 코인 5개 지급 완료');
    } else if (productId == coinPack20Id) {
      // 가챠 코인 25개 지급 (20 + 5 보너스, 소비성 상품)
      await _ticketManager.addTickets(25);
      print('[IAP] 가챠 코인 25개 지급 완료');
    } else if (productId == coinPack60Id) {
      // 가챠 코인 60개 지급 (소비성 상품)
      await _ticketManager.addTickets(60);
      print('[IAP] 가챠 코인 60개 지급 완료');
    } else if (productId == removeAdsId) {
      // 광고 제거 (비소비성 상품)
      await AdmobHandler().setAdsRemoved(true);

      // 구매 상태 저장 (중복 구매 방지 및 복원용)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adsRemovedPurchasedKey, true);

      print('[IAP] 광고 제거 완료');
    }
  }

  /// 상품 구매
  ///
  /// [productId]에 해당하는 상품을 구매합니다.
  /// 반환값은 구매 요청이 성공적으로 시작되었는지를 나타내며,
  /// 실제 구매 완료는 purchaseCompleted 스트림을 통해 알림을 받아야 합니다.
  ///
  /// 비소비성 상품(광고 제거)의 경우 중복 구매를 방지합니다.
  Future<bool> buyProduct(String productId) async {
    if (!_isAvailable) {
      print('[IAP] 인앱결제를 사용할 수 없습니다');
      return false;
    }

    // 비소비성 상품 중복 구매 방지
    if (productId == removeAdsId) {
      final prefs = await SharedPreferences.getInstance();
      final alreadyPurchased = prefs.getBool(_adsRemovedPurchasedKey) ?? false;

      if (alreadyPurchased) {
        print('[IAP] 이미 구매한 상품입니다: $productId');
        return false;
      }
    }

    // 스토어에서 상품 찾기
    ProductDetails? productDetails;
    try {
      productDetails = _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      print('[IAP] 상품을 찾을 수 없습니다: $productId');
      return false;
    }

    // 구매 파라미터 생성
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    try {
      // 소비성 상품과 비소비성 상품을 구분하여 구매 처리
      if (productId == removeAdsId) {
        // 비소비성 상품: 광고 제거
        // buyNonConsumable()을 사용하여 비소비성 상품으로 구매
        final bool success = await _inAppPurchase.buyNonConsumable(
          purchaseParam: purchaseParam,
        );
        return success;
      } else {
        // 소비성 상품: 코인 팩
        // buyConsumable()을 사용하여 소비성 상품으로 구매
        // autoConsume: true로 설정하여 자동 소비 처리
        final bool success = await _inAppPurchase.buyConsumable(
          purchaseParam: purchaseParam,
          autoConsume: true,
        );
        return success;
      }
    } catch (e) {
      print('[IAP] 구매 실패: $e');
      return false;
    }
  }

  /// 구매 복원 (비소비성 상품)
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    await _inAppPurchase.restorePurchases();
  }

  /// 서비스 정리
  ///
  /// 리소스를 정리하고 스트림을 닫습니다.
  void dispose() {
    _subscription?.cancel();
    _purchaseCompletedController.close();
  }

  /// 상품 정보 가져오기 (UI 표시용)
  IAPProduct? getProductInfo(String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// 실제 가격 가져오기 (스토어에서)
  String? getProductPrice(String productId) {
    try {
      final storeProduct = _products.firstWhere((p) => p.id == productId);
      return storeProduct.price;
    } catch (e) {
      return null;
    }
  }
}

