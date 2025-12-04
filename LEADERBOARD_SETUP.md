# 리더보드 설정 가이드

카피바라 게임에 Game Center (iOS)와 Google Play Games (Android) 리더보드를 설정하는 방법입니다.

---

## 📋 목차
1. [iOS Game Center 설정](#ios-game-center-설정)
2. [Android Google Play Games 설정](#android-google-play-games-설정)
3. [리더보드 ID 업데이트](#리더보드-id-업데이트)
4. [테스트 방법](#테스트-방법)

---

## 🍎 iOS Game Center 설정

### 1. Apple Developer Console 설정

1. **Apple Developer Console** 접속
   - https://developer.apple.com/account 접속
   - "Certificates, Identifiers & Profiles" 선택

2. **App ID 확인**
   - Identifiers에서 앱의 Bundle ID 확인
   - 예: `com.yourcompany.capybara_game`

3. **App Store Connect 접속**
   - https://appstoreconnect.apple.com 접속
   - "나의 앱" 선택 > 카피바라 게임 선택

4. **Game Center 활성화**
   - 앱 정보 > "기능" 탭 선택
   - "Game Center" 활성화

### 2. 리더보드 생성

1. **리더보드 추가**
   - Game Center > "리더보드" 선택
   - "+" 버튼 클릭하여 새 리더보드 추가

2. **5개의 리더보드 생성** (레벨별)
   
   **Level 1 리더보드:**
   - 리더보드 ID: `capybara_level1_leaderboard`
   - 이름(한국어): `레벨 1 순위`
   - 이름(영어): `Level 1 Leaderboard`
   - 점수 형식: 정수 (Integer)
   - 정렬 순서: 높은 점수 우선 (High to Low)

   **Level 2 리더보드:**
   - 리더보드 ID: `capybara_level2_leaderboard`
   - 이름(한국어): `레벨 2 순위`
   - 이름(영어): `Level 2 Leaderboard`
   - 점수 형식: 정수 (Integer)
   - 정렬 순서: 높은 점수 우선

   **Level 3 리더보드:**
   - 리더보드 ID: `capybara_level3_leaderboard`
   - 이름(한국어): `레벨 3 순위`
   - 이름(영어): `Level 3 Leaderboard`
   - 점수 형식: 정수 (Integer)
   - 정렬 순서: 높은 점수 우선

   **Level 4 리더보드:**
   - 리더보드 ID: `capybara_level4_leaderboard`
   - 이름(한국어): `레벨 4 순위`
   - 이름(영어): `Level 4 Leaderboard`
   - 점수 형식: 정수 (Integer)
   - 정렬 순서: 높은 점수 우선

   **Level 5 리더보드:**
   - 리더보드 ID: `capybara_level5_leaderboard`
   - 이름(한국어): `레벨 5 순위`
   - 이름(영어): `Level 5 Leaderboard`
   - 점수 형식: 정수 (Integer)
   - 정렬 순서: 높은 점수 우선

### 3. Xcode 프로젝트 설정

1. **Xcode에서 프로젝트 열기**
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. **Signing & Capabilities 설정**
   - Runner 타겟 선택
   - "Signing & Capabilities" 탭 선택
   - "+ Capability" 버튼 클릭
   - "Game Center" 추가

3. **Bundle ID 확인**
   - General 탭에서 Bundle Identifier가 Apple Developer Console과 일치하는지 확인

---

## 🤖 Android Google Play Games 설정

### 1. Google Play Console 설정

1. **Google Play Console 접속**
   - https://play.google.com/console 접속
   - 카피바라 게임 앱 선택

2. **Play Games Services 설정**
   - 좌측 메뉴에서 "Play Games Services" > "설정 및 관리" 선택
   - "게임 만들기" 버튼 클릭 (처음 설정하는 경우)

3. **게임 정보 입력**
   - 게임 이름: `카피바라 찾기`
   - 카테고리: 퍼즐 게임
   - 게임 설명 입력

### 2. 리더보드 생성

1. **리더보드 메뉴 선택**
   - "Play Games Services" > "리더보드" 선택
   - "리더보드 만들기" 버튼 클릭

2. **5개의 리더보드 생성** (레벨별)

   **Level 1 리더보드:**
   - 이름: `레벨 1 순위`
   - 설명: `레벨 1에서 가장 높은 점수를 기록한 플레이어`
   - 점수 형식: 숫자
   - 정렬: 큰 값이 우선
   - 생성 후 리더보드 ID 복사 (예: `CgkI...`)

   **Level 2-5 리더보드:**
   - 동일한 방식으로 생성
   - 각 리더보드 ID를 따로 메모

### 3. OAuth 2.0 클라이언트 설정

1. **게임 서비스 설정**
   - "Play Games Services" > "설정 및 관리" > "구성" 선택

2. **자격증명 추가**
   - "OAuth 클라이언트 만들기" 클릭
   - 유형: Android
   - 패키지 이름: `com.adriejeon.capybara_game` (또는 실제 패키지 이름)
   - SHA-1 인증서 지문 추가

3. **SHA-1 인증서 지문 얻기**
   ```bash
   # 디버그 키스토어
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # 릴리스 키스토어 (실제 배포용)
   keytool -list -v -keystore android/keystore/capybara_game.jks -alias capybara
   ```

4. **앱 ID 복사**
   - 게임 서비스 대시보드에서 "앱 ID" 복사
   - 예: `1234567890`

### 4. strings.xml 업데이트

`android/app/src/main/res/values/strings.xml` 파일에서:

```xml
<string name="app_id">YOUR_GOOGLE_PLAY_GAMES_APP_ID</string>
```

위 부분을 실제 앱 ID로 교체:

```xml
<string name="app_id">1234567890</string>
```

`android/app/src/main/res/values-en/strings.xml`에도 동일하게 적용

---

## 🔄 리더보드 ID 업데이트

### lib/services/leaderboard_service.dart 파일 수정

```dart
static const Map<GameDifficulty, LeaderboardIds> _leaderboardIds = {
  GameDifficulty.level1: LeaderboardIds(
    ios: 'capybara_level1_leaderboard',        // iOS 리더보드 ID
    android: 'CgkI...(실제 ID)',                // Android 리더보드 ID
  ),
  GameDifficulty.level2: LeaderboardIds(
    ios: 'capybara_level2_leaderboard',
    android: 'CgkI...(실제 ID)',
  ),
  GameDifficulty.level3: LeaderboardIds(
    ios: 'capybara_level3_leaderboard',
    android: 'CgkI...(실제 ID)',
  ),
  GameDifficulty.level4: LeaderboardIds(
    ios: 'capybara_level4_leaderboard',
    android: 'CgkI...(실제 ID)',
  ),
  GameDifficulty.level5: LeaderboardIds(
    ios: 'capybara_level5_leaderboard',
    android: 'CgkI...(실제 ID)',
  ),
};
```

---

## 🧪 테스트 방법

### iOS 테스트

1. **Sandbox 계정 생성**
   - App Store Connect > "사용자 및 액세스" > "Sandbox 테스터"
   - 새 테스터 계정 생성

2. **디바이스에서 테스트**
   ```bash
   flutter run --release
   ```

3. **Sandbox 계정으로 로그인**
   - 기기 설정 > Game Center에서 로그아웃
   - 앱 실행 시 Sandbox 계정으로 로그인

4. **확인 사항**
   - 게임 완료 후 점수가 제출되는지 확인
   - 리더보드 버튼 클릭 시 순위가 표시되는지 확인

### Android 테스트

1. **내부 테스트 트랙 설정**
   - Google Play Console > "테스트" > "내부 테스트"
   - 테스터 이메일 추가

2. **앱 빌드 및 업로드**
   ```bash
   flutter build appbundle --release
   ```
   - 생성된 AAB 파일을 내부 테스트 트랙에 업로드

3. **테스트 디바이스에 설치**
   - 테스트 링크를 통해 앱 설치
   - Google Play Games 앱 설치 확인

4. **확인 사항**
   - 자동으로 로그인되는지 확인
   - 게임 완료 후 점수 제출 확인
   - 리더보드에서 순위 확인

---

## 🎮 리더보드 사용법

### 플레이어 관점

1. **홈 화면에서 리더보드 버튼 클릭**
   - 하단의 4개 버튼 중 가장 오른쪽 버튼

2. **처음 사용 시**
   - iOS: Game Center 로그인 요청
   - Android: Google Play Games 로그인 요청

3. **리더보드 확인**
   - 전체 순위 보기
   - 친구 순위 보기
   - 자신의 순위 확인

4. **점수 기록**
   - 게임을 완료하면 자동으로 점수가 제출됩니다
   - 높은 점수만 업데이트됩니다

---

## 🔧 문제 해결

### iOS 문제

**문제: Game Center 로그인이 안 됨**
- Xcode에서 Game Center Capability가 추가되었는지 확인
- 디바이스의 Game Center에 로그인되어 있는지 확인
- Sandbox 테스터 계정 사용 확인

**문제: 리더보드가 표시되지 않음**
- App Store Connect에서 리더보드가 "준비" 상태인지 확인
- 리더보드 ID가 코드와 일치하는지 확인

### Android 문제

**문제: Google Play Games 로그인 실패**
- SHA-1 인증서가 올바르게 등록되었는지 확인
- 패키지 이름이 일치하는지 확인
- 앱 ID가 strings.xml에 올바르게 설정되었는지 확인

**문제: 리더보드가 비어있음**
- Google Play Console에서 리더보드가 게시되었는지 확인
- 앱이 내부 테스트 이상의 트랙에 업로드되었는지 확인

---

## 📚 추가 리소스

- [Apple Game Center 문서](https://developer.apple.com/game-center/)
- [Google Play Games Services 문서](https://developers.google.com/games/services)
- [games_services 패키지 문서](https://pub.dev/packages/games_services)

---

## ✅ 체크리스트

설정 완료 확인:

### iOS
- [ ] Apple Developer Console에서 Game Center 활성화
- [ ] 5개의 리더보드 생성 (level1~level5)
- [ ] Xcode에서 Game Center Capability 추가
- [ ] 코드에 iOS 리더보드 ID 업데이트
- [ ] Sandbox 계정으로 테스트

### Android
- [ ] Google Play Console에서 Play Games Services 설정
- [ ] 5개의 리더보드 생성
- [ ] OAuth 2.0 클라이언트 설정 (SHA-1 등록)
- [ ] strings.xml에 앱 ID 추가
- [ ] 코드에 Android 리더보드 ID 업데이트
- [ ] 내부 테스트 트랙에서 테스트

---

궁금한 점이 있으면 언제든지 문의하세요! 🎮


