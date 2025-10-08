import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'ui/screens/home_screen.dart';
import 'sound_manager.dart';
import 'ads/admob_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 스플래시 화면 유지
  FlutterNativeSplash.preserve(
      widgetsBinding: WidgetsFlutterBinding.ensureInitialized());

  // SoundManager 초기화
  await SoundManager().initialize();

  // AdMob 초기화
  await AdMobHandler.initialize();

  runApp(const CapybaraGameApp());
}

class CapybaraGameApp extends StatelessWidget {
  const CapybaraGameApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
