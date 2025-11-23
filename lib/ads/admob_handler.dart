import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import '../utils/app_environment.dart';

class AdmobHandler {
  // 싱글톤 구현
  static final AdmobHandler _instance = AdmobHandler._internal();
  factory AdmobHandler() => _instance;
  AdmobHandler._internal();

  // 상태 업데이트 콜백
  void Function()? _onBannerStateChanged;

  // 광고 활성화 여부
  static bool isAdEnabled = true;

  // Ad Unit IDs - 테스트 광고 ID
  static const String _androidBannerTestId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _iosBannerTestId =
      'ca-app-pub-3940256099942544/2435281174';
  static const String _androidInterstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialTestId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _androidRewardedTestId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedTestId =
      'ca-app-pub-3940256099942544/1712485313';

  // Ad Unit IDs - 실제 광고 ID
  static const String _androidBannerRealId =
      'ca-app-pub-2849900511629508/2314513629';
  static const String _iosBannerRealId =
      'ca-app-pub-2849900511629508/8479756283';
  static const String _androidInterstitialRealId =
      'ca-app-pub-2849900511629508/6501170644';
  static const String _iosInterstitialRealId =
      'ca-app-pub-2849900511629508/4460620220';
  static const String _androidRewardedRealId =
      'ca-app-pub-2849900511629508/3933363387';
  static const String _iosRewardedRealId =
      'ca-app-pub-2849900511629508/5977072794';

  // 광고 상태 관리
  BannerAd? _bannerAd;
  double? _currentBannerHeight;
  bool _isBannerLoading = false;
  bool _isBannerAdInWidgetTree = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  // 지원되는 플랫폼인지 확인
  bool get _isSupported {
    return Platform.isIOS || Platform.isAndroid;
  }

  // 광고 ID 가져오기
  Future<String> get _bannerAdUnitId async {
    if (!_isSupported) {
      isAdEnabled = false;
      return '';
    }

    // 앱스토어 버전일 때만 실제 광고 ID 사용
    if (await AppEnvironment.isAppStore()) {
      print("AdMob: Production environment detected. Using REAL ad units.");
      if (Platform.isAndroid) {
        return _androidBannerRealId;
      }
      if (Platform.isIOS) {
        return _iosBannerRealId;
      }
    }

    // 그 외 모든 경우(Debug, TestFlight, Ad Hoc 등)는 테스트 광고 ID 사용
    print("AdMob: Test/Debug environment detected. Using TEST ad units.");
    if (Platform.isAndroid) {
      return _androidBannerTestId;
    }
    // iOS
    return _iosBannerTestId;
  }

  Future<String> get _interstitialAdUnitId async {
    if (!_isSupported) {
      isAdEnabled = false;
      return '';
    }

    // 앱스토어 버전일 때만 실제 광고 ID 사용
    if (await AppEnvironment.isAppStore()) {
      print(
          "AdMob: Production environment detected. Using REAL interstitial ad units.");
      if (Platform.isAndroid) {
        return _androidInterstitialRealId;
      }
      if (Platform.isIOS) {
        return _iosInterstitialRealId;
      }
    }

    // 그 외 모든 경우(Debug, TestFlight, Ad Hoc 등)는 테스트 광고 ID 사용
    print(
        "AdMob: Test/Debug environment detected. Using TEST interstitial ad units.");
    if (Platform.isAndroid) {
      return _androidInterstitialTestId;
    }
    // iOS
    return _iosInterstitialTestId;
  }

  Future<String> get _rewardedAdUnitId async {
    if (!_isSupported) {
      isAdEnabled = false;
      return '';
    }

    // 앱스토어 버전일 때만 실제 광고 ID 사용
    if (await AppEnvironment.isAppStore()) {
      print(
          "AdMob: Production environment detected. Using REAL rewarded ad units.");
      if (Platform.isAndroid) {
        return _androidRewardedRealId;
      }
      if (Platform.isIOS) {
        return _iosRewardedRealId;
      }
    }

    // 그 외 모든 경우(Debug, TestFlight, Ad Hoc 등)는 테스트 광고 ID 사용
    print(
        "AdMob: Test/Debug environment detected. Using TEST rewarded ad units.");
    if (Platform.isAndroid) {
      return _androidRewardedTestId;
    }
    // iOS
    return _iosRewardedTestId;
  }

  // 초기화
  Future<void> initialize() async {
    if (!_isSupported) {
      isAdEnabled = false;
      print('AdMob: 지원되지 않는 플랫폼');
      return;
    }

    try {
      print('AdMob: 초기화 시작...');

      // MobileAds 초기화
      await MobileAds.instance.initialize();
      print('AdMob: MobileAds 초기화 완료');

      // RequestConfiguration 설정
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
          maxAdContentRating: MaxAdContentRating.g,
          testDeviceIds: kDebugMode ? ['SIMULATOR'] : [],
        ),
      );
      print('AdMob: RequestConfiguration 설정 완료');
    } catch (e) {
      debugPrint('AdMob 초기화 실패: $e');
      isAdEnabled = false;
      print('AdMob: 광고 비활성화됨');
    }
  }

  // 상태 업데이트 콜백 설정
  void setBannerCallback(void Function() callback) {
    _onBannerStateChanged = callback;
  }

  // 상태 업데이트 알림
  void _notifyBannerStateChanged() {
    _onBannerStateChanged?.call();
  }

  // 배너 광고 위젯
  Widget getBannerAd() {
    final placeholderHeight =
        _currentBannerHeight ?? _bannerAd?.size.height.toDouble() ?? 50;

    if (!isAdEnabled) {
      return _buildBannerPlaceholder(
        height: placeholderHeight,
        message: '광고 비활성화',
      );
    }

    if (_bannerAd == null) {
      return _buildBannerPlaceholder(
        height: placeholderHeight,
        message: '광고 로딩 중...',
      );
    }

    // 이미 위젯 트리에 있는 경우 플레이스홀더 반환
    if (_isBannerAdInWidgetTree) {
      return _buildBannerPlaceholder(
        height: placeholderHeight,
        message: '광고 표시 중...',
      );
    }

    final bannerHeight = _bannerAd!.size.height.toDouble();

    // 새로운 위젯 인스턴스를 생성하여 위젯 트리 충돌 방지
    // 고유한 키를 사용하여 위젯이 재사용되지 않도록 함
    return _BannerAdWidget(
      key: const ValueKey('banner_ad_widget'), // 고정된 키 사용
      bannerAd: _bannerAd!,
      height: bannerHeight,
      width: _bannerAd!.size.width.toDouble(),
      onWidgetCreated: () {
        _isBannerAdInWidgetTree = true;
      },
      onWidgetDisposed: () {
        _isBannerAdInWidgetTree = false;
      },
    );
  }

  Widget _buildBannerPlaceholder({
    required double height,
    required String message,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[300],
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // 배너 광고 로드
  Future<void> loadBannerAd(BuildContext context) async {
    if (!isAdEnabled || !_isSupported || _isBannerLoading) {
      return;
    }

    final width = MediaQuery.of(context).size.width;
    if (width <= 0) {
      print('AdMob: 유효하지 않은 화면 너비 - 배너 로드를 건너뜁니다.');
      return;
    }

    _isBannerLoading = true;

    try {
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        width.truncate(),
      );

      if (adaptiveSize == null) {
        print('AdMob: 적응형 배너 크기를 가져오지 못했습니다.');
        _isBannerLoading = false;
        return;
      }

      _currentBannerHeight = adaptiveSize.height.toDouble();

      final adUnitId = await _bannerAdUnitId;
      print('AdMob: 배너 광고 로드 시작 - ID: $adUnitId');

      // 이전 광고가 위젯 트리에 있으면 먼저 제거
      if (_bannerAd != null) {
        _isBannerAdInWidgetTree = false;
        await _bannerAd?.dispose();
      }
      _bannerAd = BannerAd(
        size: adaptiveSize,
        adUnitId: adUnitId,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('AdMob: 배너 광고 로드 완료');
            debugPrint('배너 광고 로드 완료');
            _isBannerLoading = false;
            _isBannerAdInWidgetTree = false; // 새 광고가 로드되면 플래그 리셋
            _notifyBannerStateChanged(); // 상태 변경 알림
          },
          onAdFailedToLoad: (ad, error) {
            print('AdMob: 배너 광고 로드 실패: $error');
            debugPrint('배너 광고 로드 실패: $error');
            ad.dispose();
            _bannerAd = null;
            _isBannerLoading = false;
            _isBannerAdInWidgetTree = false;
            _notifyBannerStateChanged(); // 상태 변경 알림
          },
        ),
        request: const AdRequest(),
      );

      print('AdMob: 배너 광고 로드 요청 전송');
      _bannerAd?.load();
    } catch (e) {
      debugPrint('적응형 배너 로드 중 오류: $e');
      _bannerAd = null;
      _isBannerLoading = false;
      _isBannerAdInWidgetTree = false;
      _notifyBannerStateChanged();
    }
  }

  // 전면 광고 로드
  Future<void> loadInterstitialAd() async {
    if (!isAdEnabled) return;

    final adUnitId = await _interstitialAdUnitId;
    final completer = Completer<void>();

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoaded = false;
          completer.completeError(error);
        },
      ),
    );

    return completer.future;
  }

  // 다음 광고 미리 로드 (대기하지 않음)
  Future<void> preloadNextAd() async {
    if (!isAdEnabled) return;

    final adUnitId = await _interstitialAdUnitId;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoaded = false;
          debugPrint('다음 광고 로드 실패: $error');
        },
      ),
    );
  }

  // 전면 광고 표시
  Future<void> showInterstitialAd() async {
    if (!isAdEnabled || !_isInterstitialAdLoaded) {
      return;
    }

    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialAdLoaded = false;
        preloadNextAd(); // 다음 광고 미리 로드 (non-blocking)
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isInterstitialAdLoaded = false;
        preloadNextAd(); // 실패해도 다음 광고 미리 로드
      },
    );

    await _interstitialAd?.show();
  }

  // 보상형 광고 로드
  Future<void> loadRewardedAd() async {
    if (!isAdEnabled) return;

    final adUnitId = await _rewardedAdUnitId;
    final completer = Completer<void>();

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          print('AdMob: 보상형 광고 로드 완료');
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoaded = false;
          print('AdMob: 보상형 광고 로드 실패: $error');
          completer.completeError(error);
        },
      ),
    );

    return completer.future;
  }

  // 다음 보상형 광고 미리 로드 (대기하지 않음)
  Future<void> preloadNextRewardedAd() async {
    if (!isAdEnabled) return;

    final adUnitId = await _rewardedAdUnitId;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          print('AdMob: 다음 보상형 광고 로드 완료');
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoaded = false;
          debugPrint('다음 보상형 광고 로드 실패: $error');
        },
      ),
    );
  }

  // 보상형 광고 표시
  Future<void> showRewardedAd({
    required Function(RewardItem) onRewarded,
    Function()? onAdDismissed,
    Function(Ad)? onAdFailedToShow,
  }) async {
    if (!isAdEnabled || !_isRewardedAdLoaded) {
      print('AdMob: 보상형 광고가 로드되지 않았습니다.');
      return;
    }

    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedAdLoaded = false;
        onAdDismissed?.call();
        preloadNextRewardedAd(); // 다음 광고 미리 로드 (non-blocking)
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isRewardedAdLoaded = false;
        onAdFailedToShow?.call(ad);
        preloadNextRewardedAd(); // 실패해도 다음 광고 미리 로드
      },
    );

    _rewardedAd?.setImmersiveMode(true);
    await _rewardedAd?.show(
      onUserEarnedReward: (ad, reward) {
        print('AdMob: 보상 획득 - ${reward.type}: ${reward.amount}');
        onRewarded(reward);
      },
    );
  }

  // 배너 광고 인스턴스 접근
  BannerAd? get bannerAd => _bannerAd;

  // 전면 광고 로드 상태 확인
  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  // 보상형 광고 로드 상태 확인
  bool get isRewardedAdLoaded => _isRewardedAdLoaded;

  // 리소스 정리
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    _currentBannerHeight = null;
    _isBannerLoading = false;
    _isBannerAdInWidgetTree = false;
    _isRewardedAdLoaded = false;
  }
}

/// 배너 광고 위젯 (AdWidget을 안전하게 관리)
class _BannerAdWidget extends StatefulWidget {
  final BannerAd bannerAd;
  final double height;
  final double width;
  final VoidCallback onWidgetCreated;
  final VoidCallback onWidgetDisposed;

  const _BannerAdWidget({
    super.key,
    required this.bannerAd,
    required this.height,
    required this.width,
    required this.onWidgetCreated,
    required this.onWidgetDisposed,
  });

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // 위젯이 생성되었음을 알림
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        widget.onWidgetCreated();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 위젯이 dispose되었음을 알림
    widget.onWidgetDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Center(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AdWidget(ad: widget.bannerAd),
        ),
      ),
    );
  }
}
