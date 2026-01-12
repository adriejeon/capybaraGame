import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../utils/app_environment.dart';
import '../services/daily_mission_service.dart';

class AdmobHandler {
  // 싱글톤 구현
  static final AdmobHandler _instance = AdmobHandler._internal();
  factory AdmobHandler() => _instance;
  AdmobHandler._internal();

  // 상태 업데이트 콜백
  void Function()? _onBannerStateChanged;

  // 광고 활성화 여부 (전체 광고 on/off)
  static bool isAdEnabled = true;

  // 광고 제거 여부 (배너/전면 광고만 제거, 보상형 광고는 유지)
  static const String _adsRemovedKey = 'ads_removed';
  bool _adsRemoved = false;

  bool get adsRemoved => _adsRemoved;

  /// 배너/전면 광고 활성화 여부 (광고 제거 시 false)
  bool get isBannerAndInterstitialEnabled => isAdEnabled && !_adsRemoved;

  /// 보상형 광고 활성화 여부 (광고 제거해도 유지)
  bool get isRewardedAdEnabled => isAdEnabled;

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
  bool _isInitialized = false; // 초기화 완료 여부

  // 지원되는 플랫폼인지 확인
  bool get _isSupported {
    return Platform.isIOS || Platform.isAndroid;
  }

  /// 광고 제거 상태 로드
  /// 
  /// 광고 제거 구매 상태를 로드합니다.
  /// 배너/전면 광고는 비활성화되지만, 보상형 광고는 유지됩니다.
  Future<void> loadAdsRemovedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_adsRemovedKey) ?? false;
    if (_adsRemoved) {
      // 주의: isAdEnabled는 변경하지 않음 (보상형 광고 유지를 위해)
      print('[AdMob] 광고 제거 상태 로드됨 - 배너/전면 광고 비활성화 (보상형 광고는 유지)');
    }
  }

  /// 광고 제거 설정
  /// 
  /// 광고 제거 구매 시 배너/전면 광고만 제거하고, 보상형 광고는 유지합니다.
  Future<void> setAdsRemoved(bool removed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, removed);
    _adsRemoved = removed;
    // 주의: isAdEnabled는 변경하지 않음 (보상형 광고 유지를 위해)

    if (removed) {
      // 기존 배너 광고만 제거 (전면 광고는 로드하지 않으면 됨)
      _bannerAd?.dispose();
      _bannerAd = null;
      _isBannerAdInWidgetTree = false;
      
      // 전면 광고도 제거
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialAdLoaded = false;
      
      print('[AdMob] 광고 제거 완료 - 배너/전면 광고 비활성화 (보상형 광고는 유지)');
    }
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

    // 이미 초기화되었으면 스킵
    if (_isInitialized) {
      print('AdMob: 이미 초기화됨 - 스킵');
      return;
    }

    try {
      print('AdMob: 초기화 시작...');

      // MobileAds 초기화 (이미 초기화되었으면 즉시 완료)
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
      _isInitialized = true;
      print('AdMob: 초기화 완료 - 광고 로드 가능');
    } catch (e) {
      debugPrint('AdMob 초기화 실패: $e');
      isAdEnabled = false;
      _isInitialized = false;
      print('AdMob: 광고 비활성화됨 - 초기화 실패: $e');
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
    // 광고가 비활성화되었거나 광고 제거를 구매한 경우 아무것도 표시하지 않음
    if (!isBannerAndInterstitialEnabled) {
      return const SizedBox.shrink();
    }

    // 광고가 로드되지 않았으면 아무것도 표시하지 않음 (회색 영역 제거)
    if (_bannerAd == null) {
      return const SizedBox.shrink();
    }

    // 이미 위젯 트리에 있는 경우 아무것도 표시하지 않음
    // 같은 BannerAd 인스턴스는 하나의 AdWidget에만 사용 가능
    // 이는 AdMob SDK의 제약사항입니다
    if (_isBannerAdInWidgetTree) {
      return const SizedBox.shrink();
    }

    final bannerHeight = _bannerAd!.size.height.toDouble();

    // 위젯 트리에 없는 경우에만 새로운 위젯 생성
    // 새로운 위젯 인스턴스를 생성하여 위젯 트리 충돌 방지
    // 고유한 키를 사용하여 위젯이 재사용되지 않도록 함
    return _BannerAdWidget(
      key: ValueKey(
          'banner_ad_${DateTime.now().millisecondsSinceEpoch}'), // 고유한 키 사용
      bannerAd: _bannerAd!,
      height: bannerHeight,
      width: _bannerAd!.size.width.toDouble(),
      onWidgetCreated: () {
        // 위젯이 실제로 트리에 추가되었을 때 플래그 설정
        _isBannerAdInWidgetTree = true;
      },
      onWidgetDisposed: () {
        // dispose 시 즉시 플래그 리셋
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
    if (!_isInitialized) {
      print('AdMob: 초기화되지 않음 - 배너 광고 로드 시도 중...');
      // 초기화되지 않았으면 초기화 시도
      await initialize();
      if (!_isInitialized) {
        print('AdMob: 초기화 실패 - 배너 광고 로드 건너뜀');
        return;
      }
    }

    if (!isBannerAndInterstitialEnabled || !_isSupported || _isBannerLoading) {
      print(
          'AdMob: 배너 광고 로드 조건 불만족 - isBannerAndInterstitialEnabled: $isBannerAndInterstitialEnabled, _isSupported: $_isSupported, _isBannerLoading: $_isBannerLoading');
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

      if (adUnitId.isEmpty) {
        print('AdMob: 배너 광고 ID가 비어있음 - 로드 중단');
        _isBannerLoading = false;
        return;
      }

      // 이전 광고가 위젯 트리에 있으면 먼저 제거
      if (_bannerAd != null) {
        _isBannerAdInWidgetTree = false;
        await Future.delayed(const Duration(milliseconds: 100)); // 약간의 지연
        await _bannerAd?.dispose();
        _bannerAd = null;
        await Future.delayed(
            const Duration(milliseconds: 100)); // dispose 완료 대기
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

            // 로드 실패 시 3초 후 재시도 (최대 1회)
            if (error.code == 2) {
              // 네트워크 오류
              print('AdMob: 3초 후 배너 광고 재시도');
              Future.delayed(const Duration(seconds: 3), () {
                if (!_isBannerLoading && _bannerAd == null) {
                  _retryLoadBannerAd(context, adaptiveSize, adUnitId);
                }
              });
            }
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

  // 배너 광고 재시도 로드 (내부 메서드)
  Future<void> _retryLoadBannerAd(
    BuildContext context,
    AdSize adSize,
    String adUnitId,
  ) async {
    if (_isBannerLoading || _bannerAd != null) {
      return;
    }

    _isBannerLoading = true;
    print('AdMob: 배너 광고 재시도 로드 시작');

    try {
      _bannerAd = BannerAd(
        size: adSize,
        adUnitId: adUnitId,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('AdMob: 배너 광고 재시도 로드 완료');
            _isBannerLoading = false;
            _isBannerAdInWidgetTree = false;
            _notifyBannerStateChanged();
          },
          onAdFailedToLoad: (ad, error) {
            print('AdMob: 배너 광고 재시도 로드 실패: $error');
            ad.dispose();
            _bannerAd = null;
            _isBannerLoading = false;
            _isBannerAdInWidgetTree = false;
            _notifyBannerStateChanged();
          },
        ),
        request: const AdRequest(),
      );

      _bannerAd?.load();
    } catch (e) {
      debugPrint('배너 광고 재시도 로드 중 오류: $e');
      _bannerAd = null;
      _isBannerLoading = false;
      _isBannerAdInWidgetTree = false;
      _notifyBannerStateChanged();
    }
  }

  // 전면 광고 로드
  Future<void> loadInterstitialAd() async {
    if (!_isInitialized) {
      print('AdMob: 초기화되지 않음 - 전면 광고 로드 시도 중...');
      // 초기화되지 않았으면 초기화 시도
      await initialize();
      if (!_isInitialized) {
        print('AdMob: 초기화 실패 - 전면 광고 로드 건너뜀');
        return;
      }
    }

    // 광고 제거 구매 시 전면 광고 로드 건너뜀
    if (!isBannerAndInterstitialEnabled) {
      print('AdMob: 광고 제거됨 - 전면 광고 로드 건너뜀');
      return;
    }

    try {
      final adUnitId = await _interstitialAdUnitId;
      print('AdMob: 전면 광고 로드 시작 - ID: $adUnitId');

      if (adUnitId.isEmpty) {
        print('AdMob: 전면 광고 ID가 비어있음 - 로드 중단');
        return;
      }

      final completer = Completer<void>();

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoaded = true;
            print('AdMob: 전면 광고 로드 완료');
            completer.complete();
          },
          onAdFailedToLoad: (error) {
            _isInterstitialAdLoaded = false;
            print(
                'AdMob: 전면 광고 로드 실패 - Code: ${error.code}, Message: ${error.message}, Domain: ${error.domain}');
            debugPrint('전면 광고 로드 실패 상세: $error');
            completer.completeError(error);
          },
        ),
      );

      return completer.future;
    } catch (e) {
      print('AdMob: 전면 광고 로드 중 예외 발생: $e');
      debugPrint('전면 광고 로드 예외 상세: $e');
      rethrow;
    }
  }

  // 다음 전면 광고 미리 로드 (대기하지 않음)
  Future<void> preloadNextAd() async {
    // 광고 제거 구매 시 전면 광고 로드 건너뜀
    if (!isBannerAndInterstitialEnabled) return;

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
    if (!_isInitialized) {
      print('AdMob: 초기화되지 않음 - 전면 광고 표시 건너뜀');
      // 초기화되지 않았으면 초기화 시도
      await initialize();
      if (!_isInitialized) {
        return;
      }
    }

    // 광고 제거 구매 시 전면 광고 표시 건너뜀
    if (!isBannerAndInterstitialEnabled) {
      print('AdMob: 광고 제거됨 - 전면 광고 표시 건너뜀');
      return;
    }

    if (!_isInterstitialAdLoaded) {
      print('AdMob: 전면 광고가 로드되지 않음 - 표시 건너뜀');
      return;
    }

    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialAdLoaded = false;
        // 데일리 미션: 광고 시청 업데이트
        _updateAdMission();
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
  // 광고 제거를 구매해도 보상형 광고는 유지됨
  Future<void> loadRewardedAd() async {
    if (!_isInitialized) {
      print('AdMob: 초기화되지 않음 - 보상형 광고 로드 시도 중...');
      // 초기화되지 않았으면 초기화 시도
      await initialize();
      if (!_isInitialized) {
        print('AdMob: 초기화 실패 - 보상형 광고 로드 건너뜀');
        return;
      }
    }

    // 보상형 광고는 광고 제거와 상관없이 isAdEnabled만 체크
    if (!isRewardedAdEnabled) {
      print('AdMob: 광고 비활성화됨 - 보상형 광고 로드 건너뜀');
      return;
    }

    print('AdMob: 보상형 광고 로드 시작...');
    try {
      final adUnitId = await _rewardedAdUnitId;
      print('AdMob: 보상형 광고 ID: $adUnitId');

      if (adUnitId.isEmpty) {
        print('AdMob: 보상형 광고 ID가 비어있음 - 로드 중단');
        return;
      }

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
            print(
                'AdMob: 보상형 광고 로드 실패 - Code: ${error.code}, Message: ${error.message}, Domain: ${error.domain}');
            debugPrint('보상형 광고 로드 실패 상세: $error');
            completer.completeError(error);
          },
        ),
      );

      return completer.future;
    } catch (e) {
      print('AdMob: 보상형 광고 로드 중 예외 발생: $e');
      debugPrint('보상형 광고 로드 예외 상세: $e');
      rethrow;
    }
  }

  // 다음 보상형 광고 미리 로드 (대기하지 않음)
  // 광고 제거를 구매해도 보상형 광고는 유지됨
  Future<void> preloadNextRewardedAd() async {
    if (!isRewardedAdEnabled) return;

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
  // 광고 제거를 구매해도 보상형 광고는 유지됨
  Future<void> showRewardedAd({
    required Function(RewardItem) onRewarded,
    Function()? onAdDismissed,
    Function(Ad)? onAdFailedToShow,
  }) async {
    if (!_isInitialized) {
      print('AdMob: 초기화되지 않음 - 보상형 광고 표시 건너뜀');
      // 초기화되지 않았으면 초기화 시도
      await initialize();
      if (!_isInitialized) {
        return;
      }
    }

    // 보상형 광고는 광고 제거와 상관없이 isAdEnabled만 체크
    if (!isRewardedAdEnabled) {
      print('AdMob: 광고 비활성화됨 - 보상형 광고 표시 건너뜀');
      return;
    }

    if (!_isRewardedAdLoaded) {
      print('AdMob: 보상형 광고가 로드되지 않았습니다.');
      return;
    }

    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedAdLoaded = false;
        // 데일리 미션: 광고 시청 업데이트
        _updateAdMission();
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

  // 데일리 미션 광고 시청 업데이트
  void _updateAdMission() {
    final missionService = DailyMissionService();
    missionService.watchAd();
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
    // 위젯이 생성되었음을 즉시 알림
    // initState에서 호출하여 위젯이 트리에 추가되는 것을 확실히 표시
    widget.onWidgetCreated();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 위젯이 dispose되었음을 즉시 알림
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
