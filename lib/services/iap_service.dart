import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/ticket_manager.dart';
import '../data/collection_manager.dart';
import '../ads/admob_handler.dart';
import '../utils/constants.dart';

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
  final GameDifficulty? guaranteedDifficulty; // 보장 캐릭터 등급

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
    this.guaranteedDifficulty,
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
  final CollectionManager _collectionManager = CollectionManager();

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
  
  // 처리된 구매 ID 저장 키 (중복 방지용)
  static const String _processedPurchasesKey = 'processed_purchase_ids';
  
  // 처리된 구매 ID 목록 (메모리 캐시)
  final Set<String> _processedPurchaseIds = {};

  // 상품 ID 정의
  static const String coinPack5Id = 'ticket_05';
  static const String coinPack20Id = 'ticket_25';
  static const String coinPack60Id = 'ticket_60';
  static const String removeAdsId = 'remove_ads';

  // 상품 정보 (UI 표시용)
  static const List<IAPProduct> products = [
    IAPProduct(
      id: coinPack5Id,
      titleKo: '뽑기권 5개',
      titleEn: '5 Gacha Tickets',
      descriptionKo: '어린이바라 캐릭터 1개 보장',
      descriptionEn: 'Child Level character guaranteed',
      coinAmount: 5,
      priceKo: '₩1,500',
      priceEn: '\$0.99',
      guaranteedDifficulty: GameDifficulty.level2,
    ),
    IAPProduct(
      id: coinPack20Id,
      titleKo: '뽑기권 25개',
      titleEn: '25 Gacha Tickets',
      descriptionKo: '청소년바라 캐릭터 1개 보장',
      descriptionEn: 'Teen Level character guaranteed',
      coinAmount: 25,
      bonusAmount: 0,
      priceKo: '₩5,500',
      priceEn: '\$4.00',
      isFeatured: true,
      discountPercent: 25,
      guaranteedDifficulty: GameDifficulty.level3,
    ),
    IAPProduct(
      id: coinPack60Id,
      titleKo: '뽑기권 60개',
      titleEn: '60 Gacha Tickets',
      descriptionKo: '어른바라 캐릭터 1개 보장',
      descriptionEn: 'Adult Level character guaranteed',
      coinAmount: 60,
      priceKo: '₩11,000',
      priceEn: '\$8.00',
      guaranteedDifficulty: GameDifficulty.level4,
    ),
    IAPProduct(
      id: removeAdsId,
      titleKo: '광고 제거',
      titleEn: 'Remove Ads',
      descriptionKo: '모든 광고를 영구적으로 제거합니다',
      descriptionEn: 'Remove all ads permanently',
      coinAmount: 0,
      priceKo: '₩5,500',
      priceEn: '\$4.00',
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

      // 컬렉션 매니저 초기화
      await _collectionManager.initializeCollection();

      // 기존 구매 상태 확인 (광고 제거 등 비소비성 상품)
      await _checkExistingPurchases();
      
      // 처리된 구매 ID 목록 로드
      await _loadProcessedPurchaseIds();
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

  /// 처리된 구매 ID 목록 로드
  Future<void> _loadProcessedPurchaseIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedIds = prefs.getStringList(_processedPurchasesKey);
      if (savedIds != null) {
        _processedPurchaseIds.addAll(savedIds);
        print('[IAP] 처리된 구매 ID ${_processedPurchaseIds.length}개 로드됨');
      }
    } catch (e) {
      print('[IAP] 처리된 구매 ID 로드 실패: $e');
    }
  }

  /// 구매 ID를 SharedPreferences에 저장
  Future<void> _savePurchaseId(String purchaseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_processedPurchasesKey, _processedPurchaseIds.toList());
      print('[IAP] ✅ 구매 ID 영구 저장 완료: $purchaseId');
    } catch (e) {
      print('[IAP] ❌ 구매 ID 저장 실패: $e');
      // 메모리에는 이미 추가되어 있으므로 재시작 전까지는 중복 방지 작동
    }
  }

  /// 이미 처리된 구매인지 확인
  bool _isPurchaseAlreadyProcessed(String? purchaseId) {
    if (purchaseId == null || purchaseId.isEmpty) return false;
    return _processedPurchaseIds.contains(purchaseId);
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
          print('[IAP] 구매 완료: ${purchaseDetails.productID}, purchaseID: ${purchaseDetails.purchaseID}');

          // purchaseID 확인
          if (purchaseDetails.purchaseID == null || purchaseDetails.purchaseID!.isEmpty) {
            print('[IAP] ⚠️ purchaseID가 없습니다. 구매 처리 스킵');
            if (purchaseDetails.pendingCompletePurchase) {
              await _inAppPurchase.completePurchase(purchaseDetails);
            }
            continue;
          }

          final purchaseId = purchaseDetails.purchaseID!;

          // 중복 구매 체크
          if (_isPurchaseAlreadyProcessed(purchaseId)) {
            print('[IAP] ⚠️ 이미 처리된 구매입니다. 중복 방지: $purchaseId');
            
            // 구매 완료 처리만 하고 보상은 지급하지 않음
            if (purchaseDetails.pendingCompletePurchase) {
              await _inAppPurchase.completePurchase(purchaseDetails);
            }
            continue; // 다음 구매로 넘어감
          }

          // ✅ 즉시 메모리에 추가 (Race Condition 방지)
          _processedPurchaseIds.add(purchaseId);
          print('[IAP] 🔒 구매 처리 시작 - 메모리에 잠금: $purchaseId');

          // 구매 검증 및 보상 지급
          await _deliverProduct(purchaseDetails);
          
          // SharedPreferences에 영구 저장
          await _savePurchaseId(purchaseId);

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
      // 뽑기권 5개 지급 + 어린이바라 캐릭터 1개 보장 (소비성 상품)
      await _ticketManager.addTickets(5);
      
      // 어린이바라 캐릭터 보장 지급
      final result = await _collectionManager.addGuaranteedNewCard(GameDifficulty.level2);
      if (result != null) {
        print('[IAP] 어린이바라 캐릭터 보장 지급 완료: ${result.card?.imagePath}');
      } else {
        print('[IAP] 어린이바라 캐릭터를 모두 보유 중입니다. 뽑기권만 지급됩니다.');
      }
      
      print('[IAP] 뽑기권 5개 지급 완료');
    } else if (productId == coinPack20Id) {
      // 뽑기권 25개 지급 + 청소년바라 캐릭터 1개 보장 (소비성 상품)
      await _ticketManager.addTickets(25);
      
      // 청소년바라 캐릭터 보장 지급
      final result = await _collectionManager.addGuaranteedNewCard(GameDifficulty.level3);
      if (result != null) {
        print('[IAP] 청소년바라 캐릭터 보장 지급 완료: ${result.card?.imagePath}');
      } else {
        print('[IAP] 청소년바라 캐릭터를 모두 보유 중입니다. 뽑기권만 지급됩니다.');
      }
      
      print('[IAP] 뽑기권 25개 지급 완료');
    } else if (productId == coinPack60Id) {
      // 뽑기권 60개 지급 + 어른바라 캐릭터 1개 보장 (소비성 상품)
      await _ticketManager.addTickets(60);
      
      // 어른바라 캐릭터 보장 지급
      final result = await _collectionManager.addGuaranteedNewCard(GameDifficulty.level4);
      if (result != null) {
        print('[IAP] 어른바라 캐릭터 보장 지급 완료: ${result.card?.imagePath}');
      } else {
        print('[IAP] 어른바라 캐릭터를 모두 보유 중입니다. 뽑기권만 지급됩니다.');
      }
      
      print('[IAP] 뽑기권 60개 지급 완료');
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


