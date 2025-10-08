import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdMobHandler {
  static final AdMobHandler _instance = AdMobHandler._internal();
  factory AdMobHandler() => _instance;
  AdMobHandler._internal();

  // 테스트 광고 단위 ID
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // 실제 광고 단위 ID
  static const String _bannerAdUnitId =
      'ca-app-pub-9203710218960521/5167293358';
  static const String _interstitialAdUnitId =
      'ca-app-pub-9203710218960521/4568527551';
  static const String _rewardAdUnitId =
      'ca-app-pub-9203710218960521/5715331537';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  InterstitialAd? _rewardInterstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isRewardInterstitialAdReady = false;

  // 광고 콜백 함수들
  VoidCallback? _onAdClosed;
  VoidCallback? _onRewardAdClosed;

  // AdMob 초기화
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();

    // 가족 광고 설정 (미성년자 보호)
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
        maxAdContentRating: MaxAdContentRating.g,
        testDeviceIds: ['SIMULATOR'], // 시뮬레이터를 테스트 디바이스로 설정
      ),
    );

    print('AdMob 초기화 완료 - 테스트 디바이스 설정됨');
  }

  // 배너 광고 생성
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: getBannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('배너 광고 로드됨');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('배너 광고 로드 실패: $error');
          ad.dispose();
        },
        onAdOpened: (ad) {
          debugPrint('배너 광고 열림');
        },
        onAdClosed: (ad) {
          debugPrint('배너 광고 닫힘');
        },
      ),
    );
  }

  // 전면 광고 로드
  void loadInterstitialAd() {
    print('전면 광고 로드 시작 - AdUnitId: ${getInterstitialAdUnitId()}');
    InterstitialAd.load(
      adUnitId: getInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          print('전면 광고 로드 성공 - 준비 완료');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('전면 광고 표시됨');
            },
            onAdDismissedFullScreenContent: (ad) {
              print('전면 광고 닫힘');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              // 광고가 닫힌 후 콜백 실행
              if (_onAdClosed != null) {
                _onAdClosed!();
                _onAdClosed = null;
              }
              // 광고가 닫힌 후 새로운 광고 로드
              print('전면 광고 재로드 시작');
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('전면 광고 표시 실패: $error');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('전면 광고 로드 실패: $error');
          _isInterstitialAdReady = false;
          // 3초 후 재시도
          Future.delayed(const Duration(seconds: 3), () {
            print('전면 광고 재시도 로드');
            loadInterstitialAd();
          });
        },
      ),
    );
  }

  // 전면 광고 표시
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    print(
        '전면 광고 표시 시도 - 준비 상태: $_isInterstitialAdReady, 광고 인스턴스: ${_interstitialAd != null}');
    if (_interstitialAd != null && _isInterstitialAdReady) {
      _onAdClosed = onAdClosed;
      print('전면 광고 표시 실행');
      _interstitialAd!.show();
    } else {
      print('전면 광고가 준비되지 않음 - 콜백 즉시 실행');
      // 광고가 준비되지 않았으면 콜백 즉시 실행
      if (onAdClosed != null) {
        onAdClosed();
      }
    }
  }

  // 캐릭터 수령용 전면 광고 로드
  void loadRewardInterstitialAd() {
    print('캐릭터 수령용 전면 광고 로드 시작');
    InterstitialAd.load(
      adUnitId: getRewardInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardInterstitialAd = ad;
          _isRewardInterstitialAdReady = true;
          print('캐릭터 수령용 전면 광고 로드 성공');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('캐릭터 수령용 전면 광고 표시됨');
            },
            onAdDismissedFullScreenContent: (ad) {
              print('캐릭터 수령용 전면 광고 닫힘');
              ad.dispose();
              _rewardInterstitialAd = null;
              _isRewardInterstitialAdReady = false;
              // 광고가 닫힌 후 콜백 실행
              if (_onRewardAdClosed != null) {
                _onRewardAdClosed!();
                _onRewardAdClosed = null;
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('캐릭터 수령용 전면 광고 표시 실패: $error');
              ad.dispose();
              _rewardInterstitialAd = null;
              _isRewardInterstitialAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('캐릭터 수령용 전면 광고 로드 실패: $error');
          _isRewardInterstitialAdReady = false;
        },
      ),
    );
  }

  // 캐릭터 수령용 전면 광고 표시
  void showRewardInterstitialAd({VoidCallback? onAdClosed}) {
    if (_rewardInterstitialAd != null && _isRewardInterstitialAdReady) {
      _onRewardAdClosed = onAdClosed;
      _rewardInterstitialAd!.show();
    } else {
      debugPrint('캐릭터 수령용 전면 광고가 준비되지 않음');
      // 광고가 준비되지 않았으면 콜백 즉시 실행
      if (onAdClosed != null) {
        onAdClosed();
      }
    }
  }

  // 캐릭터 수령용 전면 광고 준비 상태 확인
  bool get isRewardInterstitialAdReady => _isRewardInterstitialAdReady;

  // 전면 광고 준비 상태 확인
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  // 배너 광고 정리
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  // 전면 광고 정리
  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }

  // 모든 광고 정리
  void dispose() {
    disposeBannerAd();
    disposeInterstitialAd();
  }

  // 테스트 모드 확인
  bool get isTestMode {
    // 디버그 모드이거나 시뮬레이터에서는 항상 테스트 모드
    return kDebugMode || _isTestDevice();
  }

  // 테스트 디바이스 확인 (TestFlight, 시뮬레이터 등)
  bool _isTestDevice() {
    // 시뮬레이터나 TestFlight 환경에서는 테스트 광고 사용
    return true; // 개발 중에는 항상 테스트 광고 사용
  }

  // 배너 광고 단위 ID 반환
  String getBannerAdUnitId() {
    final adUnitId = isTestMode ? _testBannerAdUnitId : _bannerAdUnitId;
    print('배너 광고 ID 선택 - 테스트 모드: $isTestMode, AdUnitId: $adUnitId');
    return adUnitId;
  }

  // 전면 광고 단위 ID 반환
  String getInterstitialAdUnitId() {
    final adUnitId =
        isTestMode ? _testInterstitialAdUnitId : _interstitialAdUnitId;
    print('전면 광고 ID 선택 - 테스트 모드: $isTestMode, AdUnitId: $adUnitId');
    return adUnitId;
  }

  // 캐릭터 수령용 전면 광고 단위 ID 반환
  String getRewardInterstitialAdUnitId() {
    final adUnitId = isTestMode ? _testInterstitialAdUnitId : _rewardAdUnitId;
    print('캐릭터 수령용 전면 광고 ID 선택 - 테스트 모드: $isTestMode, AdUnitId: $adUnitId');
    return adUnitId;
  }
}
