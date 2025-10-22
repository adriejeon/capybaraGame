import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'ui/screens/home_screen.dart';
import 'sound_manager.dart';
import 'ads/admob_handler.dart';
import 'state/locale_state.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: '941590ef92057f63649c0c5b886f918c',
  );

  // SoundManager 초기화
  await SoundManager().initialize();

  // AdMob 초기화
  final AdmobHandler adMobHandler = AdmobHandler();
  await adMobHandler.initialize();

  // LocaleState 초기화
  final localeState = LocaleState();
  await localeState.loadSavedLocale();

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
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
