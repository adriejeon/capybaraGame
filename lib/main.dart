import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'ui/screens/home_screen.dart';
import 'sound_manager.dart';
import 'ads/admob_handler.dart';
import 'state/locale_state.dart';
import 'l10n/app_localizations.dart';
import 'data/home_character_manager.dart';
import 'services/game_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  // iOS 추적 권한 요청
  await AppTrackingTransparency.requestTrackingAuthorization();

  // 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: '941590ef92057f63649c0c5b886f918c',
  );

  // SoundManager 초기화
  await SoundManager().initialize();

  // AdMob 초기화
  final AdmobHandler adMobHandler = AdmobHandler();
  await adMobHandler.initialize();
  
  // 광고 제거 구매 상태 로드 (이전에 구매한 경우 배너/전면 광고 비활성화)
  await adMobHandler.loadAdsRemovedStatus();

  // LocaleState 초기화
  final localeState = LocaleState();
  await localeState.loadSavedLocale();

  // HomeCharacterManager 초기화
  await HomeCharacterManager().initialize();

  // 게임 서비스 (리더보드) 로그인
  await GameService.signIn();

  runApp(CapybaraGameApp(localeState: localeState));
}

class CapybaraGameApp extends StatelessWidget {
  final LocaleState localeState;

  const CapybaraGameApp({super.key, required this.localeState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LocaleState>(
      create: (_) => localeState,
      child: Consumer<LocaleState>(
        builder: (context, localeState, child) {
          return MaterialApp(
            title: '카피바라 짝 맞추기 게임',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.brown,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'Pretendard', // 한글 폰트 (기본값)
            ),
            locale: localeState.currentLocale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ko', 'KR'),
              Locale('en', 'US'),
            ],
            // 앱 전체에 텍스트 크기 고정 적용
            builder: (context, child) {
              final mediaQueryData = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQueryData.copyWith(
                  textScaler: TextScaler.linear(1.0), // 글자 크기 배율을 1.0으로 고정
                ),
                child: child!,
              );
            },
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
