import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @appName.
  ///
  /// In ko, this message translates to:
  /// **'카피바라 게임'**
  String get appName;

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'카피바라 게임'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In ko, this message translates to:
  /// **'앱을 초기화하는 중...'**
  String get loading;

  /// No description provided for @drawingCard.
  ///
  /// In ko, this message translates to:
  /// **'카드를 뽑는 중...'**
  String get drawingCard;

  /// No description provided for @adLoading.
  ///
  /// In ko, this message translates to:
  /// **'광고 로딩 중...'**
  String get adLoading;

  /// No description provided for @home.
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get home;

  /// No description provided for @play.
  ///
  /// In ko, this message translates to:
  /// **'플레이'**
  String get play;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @easy.
  ///
  /// In ko, this message translates to:
  /// **'쉬움'**
  String get easy;

  /// No description provided for @normal.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get normal;

  /// No description provided for @hard.
  ///
  /// In ko, this message translates to:
  /// **'어려움'**
  String get hard;

  /// No description provided for @collection.
  ///
  /// In ko, this message translates to:
  /// **'컬렉션'**
  String get collection;

  /// No description provided for @gameComplete.
  ///
  /// In ko, this message translates to:
  /// **'축하합니다!'**
  String get gameComplete;

  /// No description provided for @gameCompleteMessage.
  ///
  /// In ko, this message translates to:
  /// **'게임을 완료했습니다!'**
  String get gameCompleteMessage;

  /// No description provided for @completionTime.
  ///
  /// In ko, this message translates to:
  /// **'완료 시간'**
  String get completionTime;

  /// No description provided for @goHome.
  ///
  /// In ko, this message translates to:
  /// **'홈으로'**
  String get goHome;

  /// No description provided for @playAgain.
  ///
  /// In ko, this message translates to:
  /// **'다시 플레이'**
  String get playAgain;

  /// No description provided for @gameFailed.
  ///
  /// In ko, this message translates to:
  /// **'게임 실패!'**
  String get gameFailed;

  /// No description provided for @gameFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'시간이 다 되었습니다.\n다시 시도해보세요!'**
  String get gameFailedMessage;

  /// No description provided for @continueGame.
  ///
  /// In ko, this message translates to:
  /// **'이어서 하기'**
  String get continueGame;

  /// No description provided for @time.
  ///
  /// In ko, this message translates to:
  /// **'시간'**
  String get time;

  /// No description provided for @score.
  ///
  /// In ko, this message translates to:
  /// **'점수'**
  String get score;

  /// No description provided for @level.
  ///
  /// In ko, this message translates to:
  /// **'레벨'**
  String get level;

  /// No description provided for @moves.
  ///
  /// In ko, this message translates to:
  /// **'이동'**
  String get moves;

  /// No description provided for @combo.
  ///
  /// In ko, this message translates to:
  /// **'콤보'**
  String get combo;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @gameSettings.
  ///
  /// In ko, this message translates to:
  /// **'게임 설정'**
  String get gameSettings;

  /// No description provided for @backgroundMusic.
  ///
  /// In ko, this message translates to:
  /// **'배경음악'**
  String get backgroundMusic;

  /// No description provided for @backgroundMusicDesc.
  ///
  /// In ko, this message translates to:
  /// **'게임 배경음악 재생'**
  String get backgroundMusicDesc;

  /// No description provided for @soundEffects.
  ///
  /// In ko, this message translates to:
  /// **'효과음'**
  String get soundEffects;

  /// No description provided for @soundEffectsDesc.
  ///
  /// In ko, this message translates to:
  /// **'버튼 클릭 및 게임 효과음'**
  String get soundEffectsDesc;

  /// No description provided for @vibration.
  ///
  /// In ko, this message translates to:
  /// **'진동 효과'**
  String get vibration;

  /// No description provided for @vibrationDesc.
  ///
  /// In ko, this message translates to:
  /// **'터치 시 진동 피드백'**
  String get vibrationDesc;

  /// No description provided for @info.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get info;

  /// No description provided for @appVersion.
  ///
  /// In ko, this message translates to:
  /// **'앱 버전'**
  String get appVersion;

  /// No description provided for @developer.
  ///
  /// In ko, this message translates to:
  /// **'개발자'**
  String get developer;

  /// No description provided for @contact.
  ///
  /// In ko, this message translates to:
  /// **'문의하기'**
  String get contact;

  /// No description provided for @data.
  ///
  /// In ko, this message translates to:
  /// **'데이터'**
  String get data;

  /// No description provided for @resetData.
  ///
  /// In ko, this message translates to:
  /// **'데이터 초기화'**
  String get resetData;

  /// No description provided for @resetDataDesc.
  ///
  /// In ko, this message translates to:
  /// **'모든 게임 데이터를 삭제합니다'**
  String get resetDataDesc;

  /// No description provided for @resetDataConfirm.
  ///
  /// In ko, this message translates to:
  /// **'모든 게임 데이터가 삭제됩니다.\n정말로 진행하시겠습니까?'**
  String get resetDataConfirm;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @reset.
  ///
  /// In ko, this message translates to:
  /// **'초기화'**
  String get reset;

  /// No description provided for @dataResetComplete.
  ///
  /// In ko, this message translates to:
  /// **'데이터가 초기화되었습니다'**
  String get dataResetComplete;

  /// No description provided for @collectionTitle.
  ///
  /// In ko, this message translates to:
  /// **'카피바라 컬렉션'**
  String get collectionTitle;

  /// No description provided for @collectionDesc.
  ///
  /// In ko, this message translates to:
  /// **'수집한 카피바라들을 확인해보세요!'**
  String get collectionDesc;

  /// No description provided for @unlocked.
  ///
  /// In ko, this message translates to:
  /// **'해금됨'**
  String get unlocked;

  /// No description provided for @locked.
  ///
  /// In ko, this message translates to:
  /// **'잠김'**
  String get locked;

  /// No description provided for @total.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get total;

  /// No description provided for @completionRate.
  ///
  /// In ko, this message translates to:
  /// **'완료율'**
  String get completionRate;

  /// No description provided for @cardNumber.
  ///
  /// In ko, this message translates to:
  /// **'카드 번호'**
  String get cardNumber;

  /// No description provided for @difficulty.
  ///
  /// In ko, this message translates to:
  /// **'난이도'**
  String get difficulty;

  /// No description provided for @status.
  ///
  /// In ko, this message translates to:
  /// **'상태'**
  String get status;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @gameRules.
  ///
  /// In ko, this message translates to:
  /// **'게임 규칙'**
  String get gameRules;

  /// No description provided for @gameControls.
  ///
  /// In ko, this message translates to:
  /// **'조작 방법'**
  String get gameControls;

  /// No description provided for @control1.
  ///
  /// In ko, this message translates to:
  /// **'1. 카드를 터치하여 뒤집으세요'**
  String get control1;

  /// No description provided for @control2.
  ///
  /// In ko, this message translates to:
  /// **'2. 같은 카드 두 장을 찾아 매칭하세요'**
  String get control2;

  /// No description provided for @control3.
  ///
  /// In ko, this message translates to:
  /// **'3. 모든 카드를 매칭하면 게임 완료!'**
  String get control3;

  /// No description provided for @tutorialTitle.
  ///
  /// In ko, this message translates to:
  /// **'게임 사용법'**
  String get tutorialTitle;

  /// No description provided for @tutorialWelcome.
  ///
  /// In ko, this message translates to:
  /// **'카피바라 게임에\n오신 것을 환영합니다!'**
  String get tutorialWelcome;

  /// No description provided for @tutorialDescription.
  ///
  /// In ko, this message translates to:
  /// **'카피바라 게임은 메모리 카드 매칭 게임입니다!\n같은 카피바라 카드 두 장을 찾아 매칭하는 것이 목표입니다.'**
  String get tutorialDescription;

  /// No description provided for @tutorialStartTip.
  ///
  /// In ko, this message translates to:
  /// **'쉬운 난이도부터 시작해서 차근차근 배워보세요!'**
  String get tutorialStartTip;

  /// No description provided for @tutorialEasy.
  ///
  /// In ko, this message translates to:
  /// **'쉬움 (4×3)'**
  String get tutorialEasy;

  /// No description provided for @tutorialEasySubtitle.
  ///
  /// In ko, this message translates to:
  /// **'기본 메모리 게임'**
  String get tutorialEasySubtitle;

  /// No description provided for @tutorialEasyDesc.
  ///
  /// In ko, this message translates to:
  /// **'4×3 격자에서 6쌍의 카드를 매칭합니다.\n시간 제한이 있어서 빠르게 기억해야 해요!'**
  String get tutorialEasyDesc;

  /// No description provided for @tutorialNormal.
  ///
  /// In ko, this message translates to:
  /// **'보통 (4×4)'**
  String get tutorialNormal;

  /// No description provided for @tutorialNormalSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'조금 더 복잡한 도전'**
  String get tutorialNormalSubtitle;

  /// No description provided for @tutorialNormalDesc.
  ///
  /// In ko, this message translates to:
  /// **'4×4 격자에서 8쌍의 카드를 매칭합니다.\n더 많은 카드를 기억해야 해요!'**
  String get tutorialNormalDesc;

  /// No description provided for @tutorialHard.
  ///
  /// In ko, this message translates to:
  /// **'어려움 (6×4)'**
  String get tutorialHard;

  /// No description provided for @tutorialHardSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'진짜 메모리 마스터 도전'**
  String get tutorialHardSubtitle;

  /// No description provided for @tutorialHardDesc.
  ///
  /// In ko, this message translates to:
  /// **'6×4 격자에서 12쌍의 카드를 매칭합니다.\n최고의 기억력이 필요해요!'**
  String get tutorialHardDesc;

  /// No description provided for @gameTime.
  ///
  /// In ko, this message translates to:
  /// **'시간'**
  String get gameTime;

  /// No description provided for @gameScore.
  ///
  /// In ko, this message translates to:
  /// **'점수'**
  String get gameScore;

  /// No description provided for @gameLevel.
  ///
  /// In ko, this message translates to:
  /// **'레벨'**
  String get gameLevel;

  /// No description provided for @gameHome.
  ///
  /// In ko, this message translates to:
  /// **'홈으로'**
  String get gameHome;

  /// No description provided for @gameContinue.
  ///
  /// In ko, this message translates to:
  /// **'이어서 하기'**
  String get gameContinue;

  /// No description provided for @gameSuccess.
  ///
  /// In ko, this message translates to:
  /// **'축하합니다!'**
  String get gameSuccess;

  /// No description provided for @gameCompleted.
  ///
  /// In ko, this message translates to:
  /// **'완료!'**
  String get gameCompleted;

  /// No description provided for @gameAllMatched.
  ///
  /// In ko, this message translates to:
  /// **'모든 카드를 매칭했습니다!'**
  String get gameAllMatched;

  /// No description provided for @gameCompletionTime.
  ///
  /// In ko, this message translates to:
  /// **'완료 시간: {time}'**
  String gameCompletionTime(Object time);

  /// No description provided for @gameFailure.
  ///
  /// In ko, this message translates to:
  /// **'게임 실패!'**
  String get gameFailure;

  /// No description provided for @gameTimeUp.
  ///
  /// In ko, this message translates to:
  /// **'시간이 다 되었습니다.\n다시 시도해보세요!'**
  String get gameTimeUp;

  /// No description provided for @capybara1.
  ///
  /// In ko, this message translates to:
  /// **'검은 카피바라'**
  String get capybara1;

  /// No description provided for @capybara2.
  ///
  /// In ko, this message translates to:
  /// **'파란 카피바라'**
  String get capybara2;

  /// No description provided for @capybara3.
  ///
  /// In ko, this message translates to:
  /// **'갈색 카피바라'**
  String get capybara3;

  /// No description provided for @capybara4.
  ///
  /// In ko, this message translates to:
  /// **'어두운 갈색 카피바라'**
  String get capybara4;

  /// No description provided for @capybara5.
  ///
  /// In ko, this message translates to:
  /// **'어두운 회색 카피바라'**
  String get capybara5;

  /// No description provided for @capybara6.
  ///
  /// In ko, this message translates to:
  /// **'녹색 카피바라'**
  String get capybara6;

  /// No description provided for @capybara7.
  ///
  /// In ko, this message translates to:
  /// **'회색 카피바라'**
  String get capybara7;

  /// No description provided for @capybara8.
  ///
  /// In ko, this message translates to:
  /// **'네이비 카피바라'**
  String get capybara8;

  /// No description provided for @capybara9.
  ///
  /// In ko, this message translates to:
  /// **'분홍 카피바라'**
  String get capybara9;

  /// No description provided for @capybara10.
  ///
  /// In ko, this message translates to:
  /// **'해적 카피바라'**
  String get capybara10;

  /// No description provided for @capybara11.
  ///
  /// In ko, this message translates to:
  /// **'보라 카피바라'**
  String get capybara11;

  /// No description provided for @capybara12.
  ///
  /// In ko, this message translates to:
  /// **'흰색 카피바라'**
  String get capybara12;

  /// No description provided for @capybara13.
  ///
  /// In ko, this message translates to:
  /// **'노란 카피바라'**
  String get capybara13;

  /// No description provided for @capybara14.
  ///
  /// In ko, this message translates to:
  /// **'요리사 카피바라'**
  String get capybara14;

  /// No description provided for @capybara15.
  ///
  /// In ko, this message translates to:
  /// **'의사 카피바라'**
  String get capybara15;

  /// No description provided for @capybaraDefault.
  ///
  /// In ko, this message translates to:
  /// **'기본 카피바라'**
  String get capybaraDefault;

  /// No description provided for @timeUpTitle.
  ///
  /// In ko, this message translates to:
  /// **'시간이 부족해요!'**
  String get timeUpTitle;

  /// No description provided for @timeUpMessage.
  ///
  /// In ko, this message translates to:
  /// **'광고를 보고 30초 더 얻어보세요!'**
  String get timeUpMessage;

  /// No description provided for @timeUpSubMessage.
  ///
  /// In ko, this message translates to:
  /// **'게임을 이어서 진행할 수 있어요'**
  String get timeUpSubMessage;

  /// No description provided for @giveUp.
  ///
  /// In ko, this message translates to:
  /// **'포기하기'**
  String get giveUp;

  /// No description provided for @watchAd.
  ///
  /// In ko, this message translates to:
  /// **'광고 보러가기'**
  String get watchAd;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
