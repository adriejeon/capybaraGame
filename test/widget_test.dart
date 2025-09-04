// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:capybara_game/main.dart';

void main() {
  testWidgets('Capybara Game App starts correctly',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CapybaraGameApp());

    // Verify that the home screen loads
    expect(find.text('🦫 카피바라'), findsOneWidget);
    expect(find.text('짝 맞추기 게임'), findsOneWidget);
    expect(find.text('난이도를 선택하세요'), findsOneWidget);

    // Verify difficulty buttons exist
    expect(find.text('쉬움 (8장)'), findsOneWidget);
    expect(find.text('보통 (24장)'), findsOneWidget);
    expect(find.text('어려움 (32장)'), findsOneWidget);
  });
}
