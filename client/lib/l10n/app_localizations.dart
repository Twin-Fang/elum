import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('es'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// 앱 이름. 운영체제의 앱 전환 화면에 보인다.
  ///
  /// In ko, this message translates to:
  /// **'이룸'**
  String get appTitle;

  /// 팝업의 확인 버튼
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get commonConfirm;

  /// 팝업·시트의 취소 버튼
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// 팝업·시트의 닫기 버튼
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;

  /// 온보딩 등 단계 화면의 다음 버튼
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get commonNext;

  /// 실패 화면의 다시 시도 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get commonRetry;

  /// 지난 일과 카드에 적는 날짜. 예: 2026년 9월 20일
  ///
  /// In ko, this message translates to:
  /// **'{year}년 {month}월 {day}일'**
  String dateYearMonthDay(int year, int month, int day);

  /// 이룸이 휴대폰이 연결된 날. 예: 9월 18일부터
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일부터'**
  String dateMonthDaySince(int month, int day);

  /// 짧은 요일. weekday 는 mon·tue·wed·thu·fri·sat·sun 중 하나다.
  ///
  /// In ko, this message translates to:
  /// **'{weekday, select, mon{월} tue{화} wed{수} thu{목} fri{금} sat{토} sun{일} other{}}'**
  String weekdayShort(String weekday);

  /// AI 크레딧이 다시 채워지는 시각. weekday 는 weekdayShort 결과다. 예: 9월 28일(월) 0시
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일({weekday}) {hour}시'**
  String creditResetAt(int month, int day, String weekday, int hour);

  /// creditResetAt 에서 분이 0이 아닐 때. 예: 9월 29일(화) 3시 30분
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일({weekday}) {hour}시 {minute}분'**
  String creditResetAtMinute(
    int month,
    int day,
    String weekday,
    int hour,
    int minute,
  );

  /// 다음 초기화 시각을 서버가 주지 않았을 때의 문구
  ///
  /// In ko, this message translates to:
  /// **'다음 주 월요일 0시'**
  String get creditResetFallback;

  /// 팝업 바깥 배경 막을 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'팝업 닫기'**
  String get commonPopupClose;

  /// 뒤로가기 화살표를 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'뒤로 가기'**
  String get commonBack;

  /// 잘못된 경로로 들어왔을 때의 화면 문구
  ///
  /// In ko, this message translates to:
  /// **'화면을 찾을 수 없어요'**
  String get commonScreenNotFound;

  /// 서버가 이유를 주지 않은 일시 실패의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 해주세요'**
  String get commonRetryLater;

  /// 실패 화면의 다시 시도 버튼. 괄호 안은 추적용 에러 코드(번역하지 않는다)
  ///
  /// In ko, this message translates to:
  /// **'다시 시도 ({code})'**
  String commonRetryWithCode(String code);

  /// 제목 문장이 문장부호 없이 끝날 때 붙이는 마침표. 일본어·중국어는 。
  ///
  /// In ko, this message translates to:
  /// **'.'**
  String get sentenceStop;

  /// 서버에 닿지 못했을 때(오프라인) 무엇을 하면 되는지
  ///
  /// In ko, this message translates to:
  /// **'인터넷 연결을 확인해주세요'**
  String get failureHintOffline;

  /// 서버가 제때 답하지 않았을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'연결이 느려요. 잠시 후 다시 해주세요'**
  String get failureHintTimeout;

  /// 공용 와이파이 가로채기 등 인증서 문제의 안내
  ///
  /// In ko, this message translates to:
  /// **'안전하지 않은 연결이에요. 다른 망에서 해주세요'**
  String get failureHintBadCertificate;

  /// 코치마크 한 단계를 낭독기가 읽는 문장. message 는 강조 표식을 걷어낸 안내문
  ///
  /// In ko, this message translates to:
  /// **'안내 {index}/{total}. {message}'**
  String coachStepLabel(int index, int total, String message);

  /// 광고임을 알리는 라벨(일과로 오인해 누르는 것을 막는다)
  ///
  /// In ko, this message translates to:
  /// **'광고'**
  String get commonAd;

  /// 설정의 앱 정보 줄 이름
  ///
  /// In ko, this message translates to:
  /// **'앱 정보'**
  String get commonAppInfo;

  /// 코치마크를 닫는 버튼·동작의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'안내 닫기'**
  String get coachCloseHint;

  /// 코치마크 다음 단계로 가는 동작의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'다음 안내'**
  String get coachNextHint;

  /// 마지막 코치마크 단계의 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'화면을 누르면 닫혀요'**
  String get coachTapToClose;

  /// 코치마크 중간 단계의 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'화면을 누르면 다음으로 넘어가요'**
  String get coachTapToNext;

  /// 로그인 장면의 윗줄 문구
  ///
  /// In ko, this message translates to:
  /// **'오늘의 하루,'**
  String get loginSceneEyebrow;

  /// 로그인 장면의 큰 문구
  ///
  /// In ko, this message translates to:
  /// **'차근차근 함께해요'**
  String get loginSceneTitle;

  /// 스토어 열기 실패 팝업의 제목
  ///
  /// In ko, this message translates to:
  /// **'스토어를 열지 못했어요'**
  String get appStatusStoreOpenFailedTitle;

  /// 스토어 열기 실패 시 직접 하는 방법 안내
  ///
  /// In ko, this message translates to:
  /// **'스토어에서 이룸을 찾아 업데이트해주세요'**
  String get appStatusStoreOpenFailedFallback;

  /// 점검 중 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'잠시 쉬고 있어요'**
  String get appStatusMaintenanceTitle;

  /// 점검 중 화면의 기본 설명(서버가 문구를 주면 그것이 이긴다)
  ///
  /// In ko, this message translates to:
  /// **'조금 뒤에 다시 열어주세요'**
  String get appStatusMaintenanceBody;

  /// 점검 화면의 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 확인하기'**
  String get appStatusRecheck;

  /// 강제 업데이트 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'새 이룸이 나왔어요'**
  String get appStatusUpdateTitle;

  /// 강제 업데이트 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'앱을 새로 받아야 이어서 쓸 수 있어요.\n스토어에서 이룸을 업데이트해주세요'**
  String get appStatusUpdateBody;

  /// 스토어 주소가 없을 때의 버튼
  ///
  /// In ko, this message translates to:
  /// **'업데이트했어요'**
  String get appStatusUpdated;

  /// 스토어로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'업데이트하러 가기'**
  String get appStatusGoUpdate;

  /// 다른 보호자가 만든 일과에 붙는 문구. name 은 만든 사람이 이 이룸이 안에서 불리는 이름. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'{name}{batchim, select, yes{이} other{가}} 만든 일과예요'**
  String routineForeignCreator(String name, String batchim);

  /// 만든 사람 이름을 모를 때의 문구
  ///
  /// In ko, this message translates to:
  /// **'다른 보호자가 만든 일과예요'**
  String get routineForeignCreatorUnknown;

  /// AI 가 제목을 못 만들었을 때의 대체 제목
  ///
  /// In ko, this message translates to:
  /// **'오늘의 일과'**
  String get routineDefaultTitle;

  /// 보상 프리셋 칩
  ///
  /// In ko, this message translates to:
  /// **'좋아하는 간식'**
  String get rewardPresetSnack;

  /// 보상 프리셋 칩
  ///
  /// In ko, this message translates to:
  /// **'유튜브 10분'**
  String get rewardPresetVideo;

  /// 보상 프리셋 칩
  ///
  /// In ko, this message translates to:
  /// **'좋아하는 놀이'**
  String get rewardPresetPlay;

  /// 보상 프리셋 칩
  ///
  /// In ko, this message translates to:
  /// **'산책'**
  String get rewardPresetWalk;

  /// 프리셋에 없는 보상을 직접 적는 칩
  ///
  /// In ko, this message translates to:
  /// **'직접 입력'**
  String get rewardPresetCustom;
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
      <String>['en', 'es', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
