import 'package:flutter/material.dart';
import 'ui/screens/home_screen.dart';

void main() {
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
