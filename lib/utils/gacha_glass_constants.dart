/// 가챠 기계 유리창 위치 및 크기 상수
/// gacha_machine_widget.dart와 gacha_physics_game.dart에서 공유
class GachaGlassConstants {
  // 유리창 위치 및 크기 조정 상수
  static const double glassSize = 0.97;
  static const double glassTop = 1.0;
  static const double glassCenterX = 0.375;
  static const double glassCenterY = 0.33;
  static const double glassWidthRatio = 0.9;
  static const double glassHeightRatio = 0.82;

  // 물리 엔진 위치 미세 조정 오프셋 (픽셀 단위)
  // 이 값들을 조정하여 인형 영역의 위치를 미세하게 조정할 수 있습니다
  static const double physicsOffsetX = 0.0; // 좌우 조정 (양수: 오른쪽, 음수: 왼쪽)
  static const double physicsOffsetY = 0.0; // 상하 조정 (양수: 아래, 음수: 위)

  // 인형 설정
  static const int dollCount = 10; // 원하는 개수로 변경 가능
  static const double dollSize = 60.0;
  static const List<String> dollImages = [
    'gacha_doll_1.webp',
    'gacha_doll_2.webp',
    'gacha_doll_3.webp',
  ];
}
