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

  // Ad Unit IDs - 실제 광고 ID
  static const String _androidBannerRealId =
      'ca-app-pub-9203710218960521/5357551967';
  static const String _iosBannerRealId =
      'ca-app-pub-9203710218960521/5167293358';
  static const String _androidInterstitialRealId =
      'ca-app-pub-9203710218960521/6154153533';
  static const String _iosInterstitialRealId =
      'ca-app-pub-9203710218960521/4568527551';

  // 광고 상태 관리
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

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

      // 배너 광고는 즉시 로딩
      Future.delayed(const Duration(milliseconds: 0), () async {
        if (_isSupported && isAdEnabled) {
          await _loadBannerAd();
          print('AdMob: 배너 광고 로드 시작 (즉시 로딩)');
        }
      });
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
    if (!isAdEnabled) {
      return Container(
        height: 50,
        width: double.infinity,
        color: Colors.grey[300],
        child: const Center(
          child: Text(
            '광고 비활성화',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (_bannerAd == null) {
      return Container(
        height: 50,
        width: double.infinity,
        color: Colors.grey[300],
        child: const Center(
          child: Text(
            '광고 로딩 중...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  // 배너 광고 로드
  Future<void> _loadBannerAd() async {
    final adUnitId = await _bannerAdUnitId;
    print('AdMob: 배너 광고 로드 시작 - ID: $adUnitId');

    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('AdMob: 배너 광고 로드 완료');
          debugPrint('배너 광고 로드 완료');
          _notifyBannerStateChanged(); // 상태 변경 알림
        },
        onAdFailedToLoad: (ad, error) {
          print('AdMob: 배너 광고 로드 실패: $error');
          debugPrint('배너 광고 로드 실패: $error');
          ad.dispose();
          _bannerAd = null;
          _notifyBannerStateChanged(); // 상태 변경 알림
        },
      ),
      request: const AdRequest(),
    );

    print('AdMob: 배너 광고 로드 요청 전송');
    _bannerAd?.load();
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

  // 배너 광고 인스턴스 접근
  BannerAd? get bannerAd => _bannerAd;

  // 전면 광고 로드 상태 확인
  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  // 리소스 정리
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
  }
}
