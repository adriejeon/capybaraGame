# 🎮 리더보드 완벽 설정 가이드

카피바라 게임 리더보드를 실제로 작동시키는 완벽한 가이드입니다.

---

## 📋 설정 순서

1. [iOS Game Center 설정](#1-ios-game-center-설정) ⏱️ 20분
2. [Android Google Play Games 설정](#2-android-google-play-games-설정) ⏱️ 30분
3. [앱 코드 업데이트](#3-앱-코드-업데이트) ⏱️ 5분
4. [테스트](#4-테스트) ⏱️ 10분

---

## 1. iOS Game Center 설정

### 1-1. Apple Developer Console 설정

#### Step 1: App Store Connect 접속
1. https://appstoreconnect.apple.com 접속
2. 로그인 후 "나의 앱" 선택
3. 카피바라 게임 선택 (없으면 먼저 앱 등록)

#### Step 2: Game Center 활성화
1. 앱 정보 페이지에서 **"기능"** 탭 선택
2. **"Game Center"** 섹션에서 **"활성화"** 클릭
3. 저장

#### Step 3: 리더보드 생성 (5개)

**리더보드 생성 순서:**
1. Game Center 섹션에서 **"리더보드"** 클릭
2. **"+ 버튼"** 또는 **"리더보드 추가"** 클릭
3. **"단일 리더보드"** 선택

**각 레벨별로 생성:**

##### Level 1 리더보드
```
리더보드 참조 이름: Level 1 - Easy
리더보드 ID: capybara_level1_leaderboard

로컬라이제이션 (한국어):
  - 이름: 레벨 1 순위
  - 점수 형식 타입: 정수
  - 점수 형식: {score}점
  - 접미사: 점
  
로컬라이제이션 (영어):
  - 이름: Level 1 Leaderboard
  - 점수 형식 타입: Integer
  - 점수 형식: {score} points
  - 접미사: points

정렬 순서: 높은 값 우선 (High to Low)
점수 범위: 0 ~ 999999
```

##### Level 2 리더보드
```
리더보드 참조 이름: Level 2 - Normal
리더보드 ID: capybara_level2_leaderboard

로컬라이제이션 (한국어):
  - 이름: 레벨 2 순위
  - 점수 형식 타입: 정수
  - 점수 형식: {score}점
  
로컬라이제이션 (영어):
  - 이름: Level 2 Leaderboard
  - 점수 형식 타입: Integer
  - 점수 형식: {score} points

정렬 순서: 높은 값 우선
```

##### Level 3 리더보드
```
리더보드 참조 이름: Level 3 - Medium
리더보드 ID: capybara_level3_leaderboard

(동일한 형식으로 설정)
```

##### Level 4 리더보드
```
리더보드 참조 이름: Level 4 - Hard
리더보드 ID: capybara_level4_leaderboard

(동일한 형식으로 설정)
```

##### Level 5 리더보드
```
리더보드 참조 이름: Level 5 - Expert
리더보드 ID: capybara_level5_leaderboard

(동일한 형식으로 설정)
```

#### Step 4: 저장 및 제출
1. 각 리더보드 저장
2. **"제출"** 또는 **"검토를 위해 제출"** 클릭
3. Apple 검토 대기 (보통 1-2일)

### 1-2. Xcode 프로젝트 설정

#### Step 1: Xcode에서 프로젝트 열기
```bash
cd ios
open Runner.xcworkspace
```

#### Step 2: Game Center Capability 추가
1. 좌측 프로젝트 네비게이터에서 **"Runner"** 선택
2. **"Signing & Capabilities"** 탭 선택
3. **"+ Capability"** 버튼 클릭
4. **"Game Center"** 검색 후 추가
5. ✅ "Game Center" 섹션이 추가되었는지 확인

#### Step 3: Entitlements 파일 확인
- `ios/Runner/Runner.entitlements` 파일이 자동 생성됨
- 이미 생성되어 있음 ✓

#### Step 4: Bundle ID 확인
1. **"General"** 탭 선택
2. **Bundle Identifier** 확인 (예: `com.adriejeon.capybara_game`)
3. Apple Developer Console의 앱 ID와 일치해야 함

---

## 2. Android Google Play Games 설정

### 2-1. Google Play Console 설정

#### Step 1: Play Games Services 활성화
1. https://play.google.com/console 접속
2. 카피바라 게임 앱 선택
3. 좌측 메뉴에서 **"성장"** > **"Play Games Services"** 선택
4. **"설정 및 관리"** > **"구성"** 선택
5. 아직 설정 안했으면 **"게임 만들기"** 클릭

#### Step 2: 게임 정보 입력
```
게임 이름: 카피바라 찾기
카테고리: 퍼즐
설명: 귀여운 카피바라 짝 맞추기 게임
```

#### Step 3: OAuth 클라이언트 설정

##### SHA-1 인증서 지문 얻기

**디버그 키스토어:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**릴리스 키스토어:**
```bash
keytool -list -v -keystore android/keystore/capybara_game.jks -alias capybara
```

SHA-1 값을 복사하세요 (예: `AB:CD:EF:12:34:...`)

##### OAuth 클라이언트 생성
1. **"자격 증명"** 탭 선택
2. **"OAuth 클라이언트 만들기"** 클릭
3. 정보 입력:
   ```
   유형: Android
   이름: Capybara Game Android
   패키지 이름: com.adriejeon.capybara_game
   SHA-1 인증서 지문: (위에서 복사한 값)
   ```
4. **"저장"** 클릭
5. **릴리스 키스토어용으로 추가로 1개 더 생성** (릴리스 빌드용)

#### Step 4: 앱 ID 확인 및 복사
1. **"게임 서비스"** 메인 페이지로 이동
2. 상단에 **"프로젝트 ID"** 또는 **"앱 ID"** 표시됨
3. 숫자로 된 ID 복사 (예: `123456789012`)

### 2-2. 리더보드 생성 (5개)

#### Step 1: 리더보드 메뉴
1. Play Games Services > **"리더보드"** 선택
2. **"리더보드 만들기"** 클릭

#### Step 2: 각 레벨별 리더보드 생성

##### Level 1 리더보드
```
이름: 레벨 1 순위
아이콘: (선택 사항)
설명: 레벨 1에서 가장 높은 점수를 기록한 플레이어

점수 형식:
  - 정수 (Integer)
  - 형식 문자열: {0}점
  
정렬 순서: 큰 값이 우선 (Larger is better)
최소 점수: 0
최대 점수: 999999

기본 세트: (아무 세트나 선택)
```

**저장 후 리더보드 ID 복사** → 예: `CgkI4au8i7MWEAIQAQ`

##### Level 2-5 리더보드도 동일하게 생성
- Level 2: `레벨 2 순위`
- Level 3: `레벨 3 순위`
- Level 4: `레벨 4 순위`
- Level 5: `레벨 5 순위`

**각 리더보드 ID를 메모장에 따로 저장하세요!**

#### Step 3: 게임 게시
1. 모든 리더보드 생성 완료 후
2. Play Games Services 설정 페이지로 이동
3. **"게임 게시"** 또는 **"Play Games Services 공개"** 버튼 클릭
4. ✅ 상태가 "게시됨"으로 변경되어야 함

### 2-3. Android 앱 설정 파일 업데이트

#### strings.xml 업데이트
`android/app/src/main/res/values/strings.xml`:
```xml
<string name="app_id">123456789012</string>
```
→ 실제 앱 ID로 교체

`android/app/src/main/res/values-en/strings.xml`도 동일하게

#### games-ids.xml 업데이트
`android/app/src/main/res/values/games-ids.xml`:
```xml
<string name="leaderboard_level1" translatable="false">CgkI4au8i7MWEAIQAQ</string>
<string name="leaderboard_level2" translatable="false">CgkI4au8i7MWEAIQBA</string>
<string name="leaderboard_level3" translatable="false">CgkI4au8i7MWEAIQBg</string>
<string name="leaderboard_level4" translatable="false">CgkI4au8i7MWEAIQBw</string>
<string name="leaderboard_level5" translatable="false">CgkI4au8i7MWEAIQBz</string>
```
→ 실제 리더보드 ID로 교체

---

## 3. 앱 코드 업데이트

### lib/config/leaderboard_config.dart 수정

**파일 위치:** `lib/config/leaderboard_config.dart`

```dart
class LeaderboardConfig {
  /// iOS Game Center 리더보드 ID
  /// Apple Developer Console에서 생성한 실제 ID로 교체
  static const String iosLevel1 = 'capybara_level1_leaderboard';
  static const String iosLevel2 = 'capybara_level2_leaderboard';
  static const String iosLevel3 = 'capybara_level3_leaderboard';
  static const String iosLevel4 = 'capybara_level4_leaderboard';
  static const String iosLevel5 = 'capybara_level5_leaderboard';

  /// Android Google Play Games 리더보드 ID
  /// Google Play Console에서 생성한 실제 ID로 교체
  static const String androidLevel1 = 'CgkI4au8i7MWEAIQAQ';  // ← 실제 ID
  static const String androidLevel2 = 'CgkI4au8i7MWEAIQBA';  // ← 실제 ID
  static const String androidLevel3 = 'CgkI4au8i7MWEAIQBg';  // ← 실제 ID
  static const String androidLevel4 = 'CgkI4au8i7MWEAIQBw';  // ← 실제 ID
  static const String androidLevel5 = 'CgkI4au8i7MWEAIQBz';  // ← 실제 ID

  /// 리더보드 활성화 여부
  /// 아직 설정 중이면 false, 완료되면 true
  static const bool isEnabled = true;  // ← 설정 완료 후 true로
}
```

---

## 4. 테스트

### 4-1. iOS 테스트

#### Sandbox 계정 생성
1. App Store Connect > **"사용자 및 액세스"** > **"Sandbox 테스터"**
2. **"+"** 버튼 클릭
3. 테스트 계정 생성 (실제 이메일 주소 사용)
   ```
   이름: Test User
   성: Capybara
   이메일: test.capybara@example.com (실제 이메일)
   비밀번호: (강력한 비밀번호)
   국가: 대한민국
   ```

#### 디바이스에서 테스트
1. **iPhone 설정 앱** 실행
2. **Game Center** 선택
3. 기존 계정 로그아웃 (있는 경우)
4. 앱 실행
5. 리더보드 버튼 클릭 시 Sandbox 계정으로 로그인
6. 게임 완료 후 점수 확인
7. 리더보드에서 순위 확인

#### 빌드 및 실행
```bash
# TestFlight 업로드
flutter build ipa
# 또는 직접 디바이스에 설치
flutter run --release
```

### 4-2. Android 테스트

#### 내부 테스트 트랙 설정
1. Google Play Console > **"테스트"** > **"내부 테스트"**
2. **"새 버전 만들기"** 클릭
3. 테스터 목록에 본인 이메일 추가

#### AAB 빌드 및 업로드
```bash
flutter build appbundle --release
```

생성 위치: `build/app/outputs/bundle/release/app-release.aab`

1. Google Play Console에서 내부 테스트 트랙에 업로드
2. **"검토를 위해 제출"** 클릭
3. 승인 대기 (보통 몇 시간 ~ 1일)

#### 테스트 디바이스에 설치
1. Play Console에서 **"테스트 링크"** 복사
2. 테스트 디바이스에서 링크 접속
3. **Google Play Games** 앱 설치 (미설치 시)
4. 카피바라 게임 설치
5. 앱 실행
6. 자동으로 Play Games 로그인됨
7. 리더보드 버튼 클릭하여 확인

---

## 5. 문제 해결

### iOS 문제

#### "Game Center에 로그인이 필요합니다" 메시지
**원인:**
- Game Center Capability가 추가되지 않음
- Entitlements 파일 누락

**해결:**
1. Xcode에서 Signing & Capabilities 확인
2. Game Center가 추가되었는지 확인
3. Runner.entitlements 파일 존재 확인

#### "리더보드를 불러올 수 없습니다"
**원인:**
- 리더보드가 Apple 검토 중
- 리더보드 ID가 잘못됨

**해결:**
1. App Store Connect에서 리더보드 상태 확인
2. 리더보드 ID가 코드와 정확히 일치하는지 확인
3. Sandbox 계정으로 로그인했는지 확인

#### "순위가 표시되지 않음"
**원인:**
- 테스트 점수가 아직 제출되지 않음
- Sandbox 환경 지연

**해결:**
1. 게임을 여러 번 플레이하여 점수 제출
2. 30분 후 다시 확인 (Sandbox 지연 시간)
3. 다른 Sandbox 계정으로도 플레이하여 점수 추가

### Android 문제

#### "로그인이 필요합니다" 메시지
**원인:**
- Play Games Services가 게시되지 않음
- SHA-1 인증서가 잘못됨
- 앱 ID가 잘못됨

**해결:**
1. Play Console에서 게임이 "게시됨" 상태인지 확인
2. SHA-1 인증서 다시 확인:
   ```bash
   # 디버그용
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # 릴리스용
   keytool -list -v -keystore android/keystore/capybara_game.jks -alias capybara
   ```
3. OAuth 클라이언트에 정확한 SHA-1 등록되었는지 확인
4. strings.xml의 app_id가 올바른지 확인

#### "리더보드가 비어있음"
**원인:**
- 앱이 내부 테스트 이상 트랙에 업로드되지 않음
- 리더보드 ID가 잘못됨

**해결:**
1. 앱을 내부 테스트 트랙에 업로드했는지 확인
2. games-ids.xml의 리더보드 ID 확인
3. 게임을 플레이하여 점수 제출 후 확인

#### "403 오류" 또는 "인증 실패"
**원인:**
- 패키지 이름 불일치
- OAuth 클라이언트 설정 오류

**해결:**
1. AndroidManifest.xml의 패키지 이름 확인
2. Play Console OAuth 클라이언트의 패키지 이름과 일치하는지 확인
3. SHA-1이 디버그/릴리스 모두 등록되었는지 확인

---

## 6. 디버그 로그 확인

앱 실행 시 다음 로그를 확인하세요:

### 앱 시작 시
```
=== 리더보드 설정 정보 ===
활성화: true
설정 완료: true (또는 false)
iOS Level 1: capybara_level1_leaderboard
Android Level 1: CgkI...
========================
게임 서비스: 로그인 시도 중...
게임 서비스: 로그인 성공 ✓
```

### 게임 완료 시
```
점수 제출: 시도 중... (점수: 1500, 난이도: level1)
점수 제출: 성공 ✓ (1500점 - level1)
```

### 리더보드 버튼 클릭 시
```
리더보드: 표시 시도 중...
리더보드 표시: 전체 목록
리더보드 표시: 성공 ✓
```

### 오류 발생 시
```
게임 서비스: 로그인 실패 또는 취소 (결과: error)
점수 제출: 로그인 실패 - 점수 제출 중단
리더보드 표시: 오류 발생 - [상세 오류 메시지]
```

---

## 7. 체크리스트

### iOS 설정
- [ ] App Store Connect > Game Center 활성화
- [ ] 5개의 리더보드 생성 (level1~level5)
- [ ] 각 리더보드 ID 복사 및 메모
- [ ] Xcode에서 Game Center Capability 추가
- [ ] Runner.entitlements 파일 확인
- [ ] Sandbox 테스터 계정 생성
- [ ] lib/config/leaderboard_config.dart에 iOS 리더보드 ID 입력

### Android 설정
- [ ] Google Play Console > Play Games Services 설정
- [ ] OAuth 클라이언트 생성 (디버그 + 릴리스)
- [ ] SHA-1 인증서 등록
- [ ] 5개의 리더보드 생성
- [ ] 각 리더보드 ID 복사 및 메모
- [ ] 앱 ID 확인
- [ ] android/app/src/main/res/values/strings.xml에 앱 ID 입력
- [ ] android/app/src/main/res/values/games-ids.xml에 리더보드 ID 입력
- [ ] lib/config/leaderboard_config.dart에 Android 리더보드 ID 입력
- [ ] 내부 테스트 트랙에 앱 업로드

### 최종 확인
- [ ] lib/config/leaderboard_config.dart의 isEnabled = true로 설정
- [ ] 앱 빌드 및 테스트
- [ ] 게임 완료 시 점수 제출 로그 확인
- [ ] 리더보드에서 점수 표시 확인
- [ ] 친구 순위 기능 테스트

---

## 8. 빠른 시작 요약

### 필수 단계 (5분)

1. **Apple Developer Console**
   - Game Center 활성화
   - 5개 리더보드 생성
   - ID 복사

2. **Google Play Console**
   - Play Games Services 설정
   - 5개 리더보드 생성
   - ID 복사
   - 앱 ID 복사

3. **코드 업데이트**
   ```dart
   // lib/config/leaderboard_config.dart
   static const String iosLevel1 = '실제_ID';
   static const String androidLevel1 = '실제_ID';
   static const bool isEnabled = true;
   ```

4. **Android XML 업데이트**
   ```xml
   <!-- strings.xml -->
   <string name="app_id">실제_앱_ID</string>
   
   <!-- games-ids.xml -->
   <string name="leaderboard_level1">실제_리더보드_ID</string>
   ```

5. **빌드 및 테스트**
   ```bash
   flutter build appbundle --release  # Android
   flutter build ipa                   # iOS
   ```

---

## 9. 추가 팁

### 개발 중 테스트
- `lib/config/leaderboard_config.dart`에서 `isEnabled = false`로 설정
- 리더보드 기능 일시적으로 비활성화
- 앱이 정상 작동하는지 먼저 확인

### 단계별 활성화
1. iOS만 먼저 설정하고 테스트
2. Android 설정 후 테스트
3. 모든 플랫폼 동시에 활성화

### 로그 모니터링
```bash
# iOS
flutter run --release

# Android
flutter run --release
adb logcat | grep "게임 서비스\|리더보드\|점수 제출"
```

---

궁금한 점이나 오류가 발생하면 로그를 확인하고 문의해주세요! 🎮

