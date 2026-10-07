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

  /// AI 일과를 만드는 중에 새로 만들려 할 때의 팝업 문장
  ///
  /// In ko, this message translates to:
  /// **'이미 일과를 만들고 있어요.\n다 만든 뒤에 새 일과를 만들 수 있어요'**
  String get creditBlockedBusy;

  /// 이번 주 크레딧을 다 써서 막힌 팝업 문장. reset 은 다시 채워지는 시각(예: 9월 28일(월) 0시)
  ///
  /// In ko, this message translates to:
  /// **'이번 주 크레딧을 모두 사용했어요.\n{reset}부터 다시 만들 수 있어요'**
  String creditBlockedExhausted(String reset);

  /// 광고 보고 크레딧을 받는 제안 문장. count 는 광고 한 번에 받는 크레딧 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{광고를 끝까지 보면 크레딧 {count}개를 받아요}}'**
  String creditAdOffer(int count);

  /// 광고 시청 뒤 크레딧을 받았다는 팝업 제목. count 는 받은 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{크레딧 {count}개를 받았어요}}'**
  String creditReceivedTitle(int count);

  /// 받은 수를 모를 때의 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 받았어요'**
  String get creditReceivedTitleNoCount;

  /// 크레딧이 없을 때 광고를 보러 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 더 만들기'**
  String get creditAdWatchMore;

  /// 광고를 불러오는 동안의 대기 팝업
  ///
  /// In ko, this message translates to:
  /// **'광고를 준비하고 있어요'**
  String get adRewardPreparing;

  /// 광고를 본 뒤 서버 지급을 기다리는 동안의 대기 팝업
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 확인하고 있어요'**
  String get adRewardConfirming;

  /// 광고 로드 실패 안내
  ///
  /// In ko, this message translates to:
  /// **'지금은 광고를 불러올 수 없어요.\n잠시 후 다시 해주세요'**
  String get adRewardLoadFailed;

  /// 광고를 중간에 닫았을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'광고를 끝까지 봐야 크레딧을 받을 수 있어요.\n처음부터 다시 해주세요'**
  String get adRewardNotWatched;

  /// 시청은 끝났는데 지급 확인이 오지 않을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'크레딧 확인이 늦어지고 있어요.\n잠시 후 설정에서 확인해주세요'**
  String get adRewardSlow;

  /// 하루 한도를 다 받았을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'오늘은 광고로 받을 수 있는 크레딧을 모두 받았어요.\n내일 다시 해주세요'**
  String get adRewardDailyLimit;

  /// 계정이 동결돼 받을 수 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요'**
  String get adRewardCheckAccount;

  /// 광고 보상 기능이 꺼져 있을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'지금은 광고로 크레딧을 받을 수 없어요.'**
  String get adRewardUnavailable;

  /// 세션을 못 만든 알 수 없는 이유의 안내
  ///
  /// In ko, this message translates to:
  /// **'지금은 광고로 크레딧을 받을 수 없어요.\n잠시 후 다시 해주세요'**
  String get adRewardUnavailableRetry;

  /// 서버가 지급하지 않은 그 밖의 이유의 안내
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 받지 못했어요.\n잠시 후 다시 해주세요'**
  String get adRewardFailed;

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

  /// 역할 카드 제목에서 색이 다른 앞부분(민트). 뒤에 roleLabelSuffix 가 이어 붙는다
  ///
  /// In ko, this message translates to:
  /// **'보호자'**
  String get roleGuardianWord;

  /// 역할 카드 제목에서 색이 다른 앞부분(주황)
  ///
  /// In ko, this message translates to:
  /// **'이룸이'**
  String get roleElumiWord;

  /// 역할 카드 제목의 나머지. 앞부분과 이어 붙여 `보호자가 사용해요` 가 된다
  ///
  /// In ko, this message translates to:
  /// **'가 사용해요'**
  String get roleLabelSuffix;

  /// 보호자 역할 카드 설명
  ///
  /// In ko, this message translates to:
  /// **'일과를 만들고 관리해요'**
  String get roleGuardianDescription;

  /// 이룸이 역할 카드 설명
  ///
  /// In ko, this message translates to:
  /// **'일과를 실천해요'**
  String get roleElumiDescription;

  /// 역할 선택 화면 제목. 줄바꿈 위치까지 문구의 일부
  ///
  /// In ko, this message translates to:
  /// **'이 휴대폰은 누가\n사용하나요?'**
  String get roleSelectTitle;

  /// 역할 선택 화면 부제
  ///
  /// In ko, this message translates to:
  /// **'보호자모드와 이룸이모드가 나눠져 있어요'**
  String get roleSelectDescription;

  /// 카카오 로그인 버튼
  ///
  /// In ko, this message translates to:
  /// **'카카오로 로그인'**
  String get loginKakaoButton;

  /// 네이버 로그인 버튼
  ///
  /// In ko, this message translates to:
  /// **'네이버로 로그인'**
  String get loginNaverButton;

  /// Apple 로그인 버튼. 애플이 허용한 승인 문구라 번역 단계에서 공식 문구를 따른다
  ///
  /// In ko, this message translates to:
  /// **'Apple로 로그인'**
  String get loginAppleButton;

  /// 소셜 로그인 진행 중 버튼 문구
  ///
  /// In ko, this message translates to:
  /// **'연결하고 있어요'**
  String get loginConnecting;

  /// 마지막으로 쓴 로그인 수단 표시
  ///
  /// In ko, this message translates to:
  /// **'최근 로그인'**
  String get loginLastUsed;

  /// 같은 이메일로 다른 수단으로 가입돼 있을 때의 제목
  ///
  /// In ko, this message translates to:
  /// **'이미 가입된 계정이에요'**
  String get loginDuplicateTitle;

  /// 같은 경우의 안내(서버 문구가 이긴다)
  ///
  /// In ko, this message translates to:
  /// **'처음 쓰신 방법으로 로그인해주세요'**
  String get loginDuplicateFallback;

  /// 로그인 중 오프라인일 때의 제목
  ///
  /// In ko, this message translates to:
  /// **'인터넷 연결을 확인해주세요'**
  String get loginOfflineTitle;

  /// 같은 경우의 안내
  ///
  /// In ko, this message translates to:
  /// **'연결한 뒤 다시 해주세요'**
  String get loginOfflineFallback;

  /// 로그인 실패의 제목
  ///
  /// In ko, this message translates to:
  /// **'로그인하지 못했어요'**
  String get loginFailedTitle;

  /// 로그인 실패의 안내(서버 문구가 이긴다)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get loginFailedFallback;

  /// 약관 동의 화면 제목(불러오는 중·본문 공통)
  ///
  /// In ko, this message translates to:
  /// **'약관에 동의해주세요'**
  String get consentTitle;

  /// 약관을 읽어 오는 동안의 안내(동의 화면·약관 목록)
  ///
  /// In ko, this message translates to:
  /// **'약관을 불러오고 있어요'**
  String get consentLoading;

  /// 동의를 저장하는 동안 버튼 문구
  ///
  /// In ko, this message translates to:
  /// **'저장하고 있어요'**
  String get consentSaving;

  /// 동의 저장 실패의 기본 문구(서버 문구가 이긴다). 뒤에 에러 코드가 붙는다
  ///
  /// In ko, this message translates to:
  /// **'동의를 저장하지 못했어요. 다시 해주세요'**
  String get consentSaveFailed;

  /// 필수 항목을 모두 켰을 때의 부제
  ///
  /// In ko, this message translates to:
  /// **'항목을 눌러 상세 내용을 볼 수 있어요'**
  String get consentDescriptionReady;

  /// 필수 항목이 남았을 때의 부제(다음 버튼이 꺼진 이유)
  ///
  /// In ko, this message translates to:
  /// **'서비스 사용을 위해 약관 동의가 필요해요'**
  String get consentDescriptionNeeded;

  /// 전체 동의 버튼
  ///
  /// In ko, this message translates to:
  /// **'서비스 이용약관 전체 동의'**
  String get consentAllAgree;

  /// 약관 행의 필수 표시. 약관 문서 화면의 머리 줄에도 쓴다
  ///
  /// In ko, this message translates to:
  /// **'필수'**
  String get consentRequiredTag;

  /// 약관 행의 선택 표시. 약관 문서 화면의 머리 줄에도 쓴다
  ///
  /// In ko, this message translates to:
  /// **'선택'**
  String get consentOptionalTag;

  /// 약관 칩의 필수 항목
  ///
  /// In ko, this message translates to:
  /// **'[필수] {label}'**
  String consentChipRequired(String label);

  /// 약관 칩의 선택 항목
  ///
  /// In ko, this message translates to:
  /// **'[선택] {label}'**
  String consentChipOptional(String label);

  /// 약관 문서 화면 끝의 줄. label 은 consentRequiredTag·consentOptionalTag 중 하나라 번역가가 순서·구분자를 바꿀 수 있다
  ///
  /// In ko, this message translates to:
  /// **'{label} · 버전 {version}'**
  String consentDocumentMeta(String label, String version);

  /// 약관 목록 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'약관 및 개인정보처리방침'**
  String get consentListTitle;

  /// 약관 목록의 필수 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'필수항목'**
  String get consentGroupRequired;

  /// 약관 목록의 선택 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'선택항목'**
  String get consentGroupOptional;

  /// 이룸을 쓰는 당사자를 부르는 말. 이름을 못 받았을 때의 대체 호칭이기도 하다. 번역 여부는 용어집이 정한다
  ///
  /// In ko, this message translates to:
  /// **'이룸이'**
  String get commonElumiName;

  /// 캐릭터 종류(접근성 안내)
  ///
  /// In ko, this message translates to:
  /// **'고양이'**
  String get characterCatLabel;

  /// 고양이 캐릭터의 카드 아래 이름. 번역 여부는 용어집이 정한다
  ///
  /// In ko, this message translates to:
  /// **'루루'**
  String get characterCatName;

  /// 캐릭터 종류(접근성 안내)
  ///
  /// In ko, this message translates to:
  /// **'여우'**
  String get characterFoxLabel;

  /// 여우 캐릭터의 카드 아래 이름. 번역 여부는 용어집이 정한다
  ///
  /// In ko, this message translates to:
  /// **'포포'**
  String get characterFoxName;

  /// 서비스 에이전트(루미)의 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'병아리'**
  String get agentChickLabel;

  /// 카드 그림 방식 이름
  ///
  /// In ko, this message translates to:
  /// **'만화'**
  String get imageStyleCartoonLabel;

  /// 카드 그림 방식 설명
  ///
  /// In ko, this message translates to:
  /// **'캐릭터가 나오는 그림이에요'**
  String get imageStyleCartoonDescription;

  /// 카드 그림 방식 이름
  ///
  /// In ko, this message translates to:
  /// **'실사'**
  String get imageStyleRealisticLabel;

  /// 카드 그림 방식 설명
  ///
  /// In ko, this message translates to:
  /// **'실제 물건 사진처럼 보여요'**
  String get imageStyleRealisticDescription;

  /// 카드 그림 방식 이름
  ///
  /// In ko, this message translates to:
  /// **'직접 찍은 사진'**
  String get imageStylePhotoOnlyLabel;

  /// 카드 그림 방식 설명
  ///
  /// In ko, this message translates to:
  /// **'그림은 직접 찍은 사진으로 넣어요. 글은 계속 만들어 드려요'**
  String get imageStylePhotoOnlyDescription;

  /// 도움 목표 선택지
  ///
  /// In ko, this message translates to:
  /// **'해야 할 일을 순서대로 이해해요'**
  String get goalStepByStep;

  /// 도움 목표 선택지
  ///
  /// In ko, this message translates to:
  /// **'필요한 준비물을 스스로 챙겨요'**
  String get goalPrepareItems;

  /// 도움 목표 선택지
  ///
  /// In ko, this message translates to:
  /// **'새로운 상황을 미리 준비해요'**
  String get goalPrepareNew;

  /// 도움 목표 선택지
  ///
  /// In ko, this message translates to:
  /// **'혼자 끝까지 해내는 경험을 만들어요'**
  String get goalIndependent;

  /// 캐릭터 고르기 화면 제목. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}의 하루를 함께할\n친구를 골라주세요'**
  String onboardingCharacterTitle(String name);

  /// 캐릭터 고르기 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'선택한 친구가 카드 속 주인공이 되어 도와줘요'**
  String get onboardingCharacterDescription;

  /// 도움 목표 화면 제목. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}의 어떤 순간을\n도와주고 싶으신가요?'**
  String onboardingGoalsTitle(String name);

  /// 도움 목표 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'여러 개를 선택할 수 있어요'**
  String get onboardingGoalsDescription;

  /// 카드 그림 방식 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'카드 그림은 어떤 방식으로\n만들까요?'**
  String get onboardingImageStyleTitle;

  /// 카드 그림 방식 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'나중에 설정에서 바꿀 수 있어요'**
  String get onboardingImageStyleDescription;

  /// 카드 그림 방식 화면의 건너뛰기 링크
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get onboardingImageStyleSkip;

  /// 이름 입력 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 어떻게\n불러드릴까요?'**
  String get onboardingNameTitle;

  /// 이름 입력 화면 설명(개인정보 최소수집 안내)
  ///
  /// In ko, this message translates to:
  /// **'정확한 실명이 아니어도 괜찮아요'**
  String get onboardingNameDescription;

  /// 이름 입력칸 힌트
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해주세요'**
  String get onboardingNameHint;

  /// 이름 입력 화면에서 초대 코드로 합류하는 링크
  ///
  /// In ko, this message translates to:
  /// **'초대 코드가 있어요'**
  String get onboardingNameInviteLink;

  /// 온보딩 완료 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'내용 정리가 모두\n완료됐어요'**
  String get onboardingCompletionTitle;

  /// 온보딩 완료 화면의 진행도 문구
  ///
  /// In ko, this message translates to:
  /// **'100% 완료!'**
  String get onboardingCompletionProgress;

  /// 스플래시 로고를 화면 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'이룸'**
  String get onboardingSplashLogoLabel;

  /// 비밀암호 만들기 1단계 제목
  ///
  /// In ko, this message translates to:
  /// **'보호자님만 아는\n비밀암호를 만들어주세요'**
  String get pinCreateTitle;

  /// 비밀암호 재입력 단계 제목
  ///
  /// In ko, this message translates to:
  /// **'암호를 한번 더\n입력해주세요'**
  String get pinConfirmTitle;

  /// 비밀암호 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'보호자모드로 변경할 때 사용하는 암호예요'**
  String get pinDescription;

  /// 재입력이 처음 암호와 다를 때 설명 자리에 뜨는 안내
  ///
  /// In ko, this message translates to:
  /// **'암호가 달라요. 다시 넣어주세요'**
  String get pinMismatch;

  /// 암호 점 영역을 화면 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'암호 넣기'**
  String get pinInputSemanticLabel;

  /// 비밀암호를 두 번 맞춘 뒤 나타나는 확정 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get pinStartButton;

  /// 이룸이 만들기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 만들지 못했어요'**
  String get pinProfileCreateFailedTitle;

  /// 이룸이 만들기 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get pinProfileCreateFailedFallback;

  /// 설정 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'설정을 저장하지 못했어요'**
  String get pinSaveFailedTitle;

  /// 설정 저장 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'설정 화면에서 다시 확인해주세요'**
  String get pinSaveFailedFallback;

  /// 이룸이 휴대폰 설정 페이지 제목
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get elumiSettingsTitle;

  /// 이룸이 설정의 카드 체크 진동 스위치 줄
  ///
  /// In ko, this message translates to:
  /// **'카드 체크 진동'**
  String get elumiSettingsHapticLabel;

  /// 이룸이 설정의 약관 줄
  ///
  /// In ko, this message translates to:
  /// **'약관 및 개인정보처리방침'**
  String get elumiSettingsTermsLabel;

  /// 이룸이 설정의 로그아웃 줄
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get elumiSettingsLogoutLabel;

  /// 이룸이 설정의 회원탈퇴 줄
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴'**
  String get elumiSettingsWithdrawLabel;

  /// 로그아웃 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 하실건가요?'**
  String get elumiSettingsLogoutTitle;

  /// 로그아웃 확인 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'이 휴대폰의 연결이 끊어져요\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요'**
  String get elumiSettingsLogoutMessage;

  /// 로그아웃 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'로그아웃하지 못했어요'**
  String get elumiSettingsLogoutFailTitle;

  /// 회원탈퇴 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴 하실건가요?'**
  String get elumiSettingsWithdrawTitle;

  /// 회원탈퇴 확인 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'이 휴대폰의 연결만 끊어져요\n일과와 별은 보호자 휴대폰에 남고\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요'**
  String get elumiSettingsWithdrawMessage;

  /// 이룸이 전용 휴대폰에서 초대 링크를 열었을 때의 토스트
  ///
  /// In ko, this message translates to:
  /// **'이 휴대폰에서는 초대를 받을 수 없어요\n보호자 휴대폰에서 열어주세요'**
  String get inviteRejectedOnElumiDevice;

  /// 회원탈퇴 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하지 못했어요'**
  String get elumiSettingsWithdrawFailTitle;

  /// 연결 끊기 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get elumiSettingsExitFailedFallback;

  /// 보호자 설정의 이룸이 휴대폰 연결 상태 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰'**
  String get linkStatusTitle;

  /// 연결 끊기 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'연결을 끊을까요?'**
  String get linkStatusRevokeConfirmTitle;

  /// 연결 끊기 확인 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰에서 일과를 볼 수 없어요\n다시 연결하려면 새 암호를 만들면 돼요'**
  String get linkStatusRevokeConfirmMessage;

  /// 연결 끊기 확인 팝업의 위험 버튼
  ///
  /// In ko, this message translates to:
  /// **'연결 끊기'**
  String get linkStatusRevokeConfirmAction;

  /// 연결 끊기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'연결을 끊지 못했어요'**
  String get linkStatusRevokeFailTitle;

  /// 연결 끊기 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get linkStatusRevokeFailedFallback;

  /// 연결 끊기 성공 스낵바
  ///
  /// In ko, this message translates to:
  /// **'연결을 끊었어요'**
  String get linkStatusRevoked;

  /// 이미 끊긴 연결을 끊으려 했을 때 스낵바
  ///
  /// In ko, this message translates to:
  /// **'이미 끊겨 있어요'**
  String get linkStatusAlreadyRevoked;

  /// 연결 상태 조회 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'연결 상태를 불러오지 못했어요'**
  String get linkStatusLoadFailedFallback;

  /// 연결된 휴대폰이 여러 대일 때 붙이는 번호 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰 {number}'**
  String linkDeviceNumbered(int number);

  /// 연결된 휴대폰의 상태 글자
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get linkStatusConnected;

  /// 연결된 휴대폰 카드의 연결 끊기 버튼
  ///
  /// In ko, this message translates to:
  /// **'연결 끊기'**
  String get linkStatusRevokeButton;

  /// 연결 끊기 버튼 아래 안내
  ///
  /// In ko, this message translates to:
  /// **'끊으면 이룸이 휴대폰에서\n일과를 볼 수 없어요'**
  String get linkStatusRevokeHint;

  /// 연결된 휴대폰이 하나도 없을 때
  ///
  /// In ko, this message translates to:
  /// **'연결된 휴대폰이 없어요'**
  String get linkStatusEmpty;

  /// 연결 없음 상태에서 연결 암호 만들기로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰 연결하기'**
  String get linkStatusConnectAction;

  /// 설정에서 연 연결 암호 화면의 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰 연결'**
  String get linkCodeSettingsTitle;

  /// 보호자 휴대폰의 연결 암호 화면 제목. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}의 휴대폰을\n연결할까요?'**
  String linkCodeAskTitle(String name);

  /// 연결 암호 화면의 설명. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}의 휴대폰에서 아래 코드를 입력하세요'**
  String linkCodeEnterHint(String name);

  /// 연결 암호 발급 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'암호를 만들지 못했어요. 다시 해주세요'**
  String get linkCodeIssueFailedFallback;

  /// 연결 암호 화면의 타이머 자리에 뜨는 만료 안내
  ///
  /// In ko, this message translates to:
  /// **'암호가 만료됐어요'**
  String get linkCodeExpired;

  /// 이룸이 휴대폰이 연결됐을 때 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 연결에 성공했어요!'**
  String get linkCodeSuccessTitle;

  /// 온보딩에서 연 연결 암호 화면의 시작 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get linkCodeStartButton;

  /// 온보딩에서 연 연결 암호 화면의 건너뛰기 글자
  ///
  /// In ko, this message translates to:
  /// **'나중에 할게요'**
  String get linkCodeLater;

  /// 연결 암호 화면의 다시 만들기 칩(시안 그대로)
  ///
  /// In ko, this message translates to:
  /// **'코드 다시 만들기'**
  String get linkRetryChipLabel;

  /// 이룸이 휴대폰의 코드 입력 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'보호자에게서 받은 코드를\n입력해주세요'**
  String get linkEnterTitle;

  /// 이룸이 휴대폰의 코드 입력 안내. linkEnterGuidePath 를 문장 안에 그대로 포함해야 밑줄이 그려진다
  ///
  /// In ko, this message translates to:
  /// **'코드는 보호자 휴대폰의\n설정 → 이룸이 휴대폰 연결하기에 있어요'**
  String get linkEnterGuide;

  /// linkEnterGuide 안에서 밑줄을 그을 부분. 안내문에 똑같이 들어 있어야 한다
  ///
  /// In ko, this message translates to:
  /// **'설정 → 이룸이 휴대폰 연결하기'**
  String get linkEnterGuidePath;

  /// 연결이 밖에서 끊겨 코드 입력 화면으로 돌아왔을 때 설명(다음 행동 포함)
  ///
  /// In ko, this message translates to:
  /// **'연결이 끊어졌어요\n보호자에게 새 연결 암호를 받아 입력해주세요'**
  String get linkEnterLinkLost;

  /// 코드 입력 화면의 시작 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get linkEnterStartButton;

  /// 여섯 칸 입력 영역을 화면 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'연결 암호 넣기'**
  String get linkEnterInputLabel;

  /// 연결 암호 입력 실패(모양이 틀리거나 없는 암호)
  ///
  /// In ko, this message translates to:
  /// **'암호가 맞지 않아요'**
  String get linkEnterWrongCode;

  /// 연결 암호가 만료됐을 때
  ///
  /// In ko, this message translates to:
  /// **'암호가 만료됐어요. 새 암호를 받아주세요'**
  String get linkEnterExpired;

  /// 연결 중 오프라인일 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'연결하지 못했어요. 인터넷을 확인해주세요'**
  String get linkEnterOffline;

  /// 연결 중 그 밖의 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'연결하지 못했어요. 다시 해주세요'**
  String get linkEnterFailed;

  /// 이름이 없는 보호자를 부르는 대체 호칭
  ///
  /// In ko, this message translates to:
  /// **'보호자'**
  String get commonGuardianName;

  /// 함께하는 사람의 구분 이름(가족·보호자). 표시용이며 서버로 가는 값이 아니다
  ///
  /// In ko, this message translates to:
  /// **'보호자'**
  String get guardianKindGuardian;

  /// 함께하는 사람의 구분 이름(센터·기관 선생님). 표시용이며 서버로 가는 값이 아니다
  ///
  /// In ko, this message translates to:
  /// **'센터 선생님'**
  String get guardianKindCaregiver;

  /// 초대 링크를 메신저로 보낼 때의 글. 보내는 사람의 앱 언어로 만들어진다. url 은 링크(번역하지 않는다), code 는 3-3 으로 끊은 초대 코드
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n초대 코드는 {minutes, plural, other{{minutes}분}} 동안만 쓸 수 있어요.\n\n{url}\n\n링크가 열리지 않으면 앱에서 직접 넣어주세요.\n초대 코드 {code}'**
  String inviteShareMessage(int minutes, String url, String code);

  /// 내 이름·구분 고치기 시트의 제목
  ///
  /// In ko, this message translates to:
  /// **'내 이름 고치기'**
  String get guardiansEditTitle;

  /// 내 이름 고치기 시트의 설명
  ///
  /// In ko, this message translates to:
  /// **'이 이룸이를 함께 돌보는 사람에게 보이는 이름이에요. 실명이 아니어도 괜찮아요'**
  String get guardiansEditDescription;

  /// 내 이름 입력칸의 예시 글
  ///
  /// In ko, this message translates to:
  /// **'엄마, 아빠, 센터 선생님'**
  String get guardiansEditNameHint;

  /// 내 이름 고치기 시트의 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get guardiansEditSave;

  /// 함께 돌보기 그만두기 확인 팝업 제목(되돌릴 수 없는 일)
  ///
  /// In ko, this message translates to:
  /// **'함께 돌보기를 그만둘까요?'**
  String get guardiansLeaveConfirmTitle;

  /// 마지막 보호자가 나갈 때의 확인 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'함께하는 보호자가 없어요\n나가면 이룸이와 만든 일과, 모은 별이 모두 사라져요\n되돌릴 수 없어요'**
  String get guardiansLeaveConfirmMessageLast;

  /// 다른 보호자가 남아 있을 때의 확인 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'내가 연결한 이룸이 휴대폰이 있다면 연결이 끊어져요\n남은 보호자가 새 연결 암호를 만들어야 다시 쓸 수 있어요\n내가 만든 일과는 사라져요\n이룸이와 다른 보호자의 일과·별은 그대로예요'**
  String get guardiansLeaveConfirmMessageOthers;

  /// 함께 돌보기 그만두기 확인 팝업의 위험 버튼
  ///
  /// In ko, this message translates to:
  /// **'그만두기'**
  String get guardiansLeaveConfirmAction;

  /// 함께 돌보기 그만두기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'나가지 못했어요'**
  String get guardiansLeaveFailTitle;

  /// 나가기 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get guardiansLeaveFailedFallback;

  /// 함께 돌보기를 그만둔 뒤의 알림. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}에서 나왔어요'**
  String guardiansLeft(String name);

  /// 내 이름 고치기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'이름을 고치지 못했어요'**
  String get guardiansNameEditFailTitle;

  /// 이름 고치기 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get guardiansNameEditFailedFallback;

  /// 함께하는 사람 화면의 제목
  ///
  /// In ko, this message translates to:
  /// **'함께하는 사람'**
  String get guardiansTitle;

  /// 이룸이가 없을 때의 안내 제목
  ///
  /// In ko, this message translates to:
  /// **'함께하는 사람을 볼 이룸이가 없어요'**
  String get guardiansNoProfileMessage;

  /// 이룸이가 없을 때의 안내 설명
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 먼저 등록해주세요'**
  String get guardiansNoProfileDescription;

  /// 함께하는 사람 목록의 머리 설명. name 은 이룸이 호칭(한국어는 조사를 `를` 로 고정해 둔 현행 문구)
  ///
  /// In ko, this message translates to:
  /// **'{name}를 함께 돌보는 사람이에요'**
  String guardiansCaption(String name);

  /// 함께하는 사람 화면의 보조 설명(보호자와 이룸이 휴대폰 연결을 구분)
  ///
  /// In ko, this message translates to:
  /// **'일과를 같이 만드는 가족이나 선생님이에요. 이룸이가 쓰는 휴대폰은 설정의 이룸이 휴대폰에서 연결해요'**
  String get guardiansIntro;

  /// 목록 조회 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'함께하는 사람을 불러오지 못했어요'**
  String get guardiansLoadFailedFallback;

  /// 목록이 비어 있을 때의 안내(서버에 있을 수 없는 상태)
  ///
  /// In ko, this message translates to:
  /// **'함께하는 사람을 찾지 못했어요'**
  String get guardiansEmptyMessage;

  /// 목록에 내 줄만 있을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'아직 혼자 돌보고 있어요. 가족이나 선생님을 초대해보세요'**
  String get guardiansAloneHint;

  /// 초대 코드 만들기로 가는 줄
  ///
  /// In ko, this message translates to:
  /// **'다른 보호자 초대하기'**
  String get guardiansInviteAction;

  /// 초대 코드 넣기로 가는 줄
  ///
  /// In ko, this message translates to:
  /// **'받은 초대 코드 넣기'**
  String get guardiansEnterCodeAction;

  /// 함께 돌보기 그만두기 줄(위험색)
  ///
  /// In ko, this message translates to:
  /// **'함께 돌보기 그만두기'**
  String get guardiansLeaveAction;

  /// 그만두기 줄 아래 설명(혼자 돌볼 때)
  ///
  /// In ko, this message translates to:
  /// **'혼자 돌보고 있어서 그만두면 이룸이와 일과, 별이 모두 사라져요'**
  String get guardiansLeaveHintAlone;

  /// 그만두기 줄 아래 설명(다른 보호자가 있을 때)
  ///
  /// In ko, this message translates to:
  /// **'내가 만든 일과만 사라지고, 다른 보호자의 일과는 그대로예요'**
  String get guardiansLeaveHintWithOthers;

  /// 목록에서 내 줄에 붙는 작은 표시
  ///
  /// In ko, this message translates to:
  /// **'나'**
  String get guardiansMeBadge;

  /// 초대 링크 공유 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'링크를 보내지 못했어요'**
  String get inviteCodeShareFailTitle;

  /// 초대 링크 공유 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'초대 코드를 직접 알려주세요'**
  String get inviteCodeShareFailFallback;

  /// 초대 코드 화면의 남은 시간 자리에 보이는 만료 안내
  ///
  /// In ko, this message translates to:
  /// **'초대 코드가 만료됐어요'**
  String get inviteCodeExpired;

  /// 초대 코드 만들기 화면의 제목
  ///
  /// In ko, this message translates to:
  /// **'초대 코드'**
  String get inviteCodeTitle;

  /// 초대 링크를 공유 시트로 보내는 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'링크로 보내기'**
  String get inviteCodeShareButton;

  /// 초대 코드 화면의 머리 제목
  ///
  /// In ko, this message translates to:
  /// **'함께할 보호자에게\n코드를 알려주세요'**
  String get inviteCodeHeaderTitle;

  /// 초대 코드 화면 설명. name 은 이룸이 호칭. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'받은 분이 {name}{batchim, select, yes{을} other{를}} 함께 돌봐요'**
  String inviteCodeAsk(String name, String batchim);

  /// 이룸이가 없을 때의 안내 제목
  ///
  /// In ko, this message translates to:
  /// **'함께 돌볼 이룸이가 없어요'**
  String get inviteCodeNoProfileMessage;

  /// 이룸이가 없을 때의 안내 설명
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 먼저 등록해주세요'**
  String get inviteCodeNoProfileDescription;

  /// 초대 코드 발급 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'초대 코드를 만들지 못했어요'**
  String get inviteCodeIssueFailedFallback;

  /// 초대 코드를 다시 만드는 칩
  ///
  /// In ko, this message translates to:
  /// **'초대 코드 다시 만들기'**
  String get inviteCodeRetryChip;

  /// 다시 만들기 아래 안내(앞 코드가 폐기됨)
  ///
  /// In ko, this message translates to:
  /// **'다시 만들면 이전 코드는 쓸 수 없어요'**
  String get inviteCodeRetryNote;

  /// 초대 코드는 보호자용이라는 안내
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 쓰는 휴대폰은 여기서 붙이지 않아요\n설정의 이룸이 휴대폰에서 연결해요'**
  String get inviteCodeElumiPhoneNote;

  /// 링크로 열렸지만 코드를 못 쓰는 모양일 때의 안내. 에러 코드를 문구에 함께 둔다
  ///
  /// In ko, this message translates to:
  /// **'초대 링크가 맞지 않아요. 보낸 분께 다시 받아주세요 (E-INV-LINK)'**
  String get inviteEnterLinkInvalid;

  /// 직접 친 코드의 모양이 틀릴 때의 안내. 에러 코드를 문구에 함께 둔다
  ///
  /// In ko, this message translates to:
  /// **'초대 코드가 맞지 않아요 (E-INV-FORM)'**
  String get inviteEnterFormInvalid;

  /// 초대 코드를 넣고 합류했을 때의 알림. name 은 이룸이 호칭. batchim 은 한국어 조사 선택용(yes/no)
  ///
  /// In ko, this message translates to:
  /// **'{name}{batchim, select, yes{을} other{를}} 함께 돌보게 됐어요'**
  String inviteJoined(String name, String batchim);

  /// 없는·쓴 코드일 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'초대 코드가 맞지 않아요'**
  String get inviteEnterNotFound;

  /// 만료된 코드일 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'초대 코드가 만료됐어요. 새 코드를 받아주세요'**
  String get inviteEnterExpired;

  /// 시도 한도에 걸렸을 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 뒤에 다시 해주세요'**
  String get inviteEnterTooManyAttempts;

  /// 이미 함께하는 이룸이일 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'이미 함께하고 있는 이룸이예요'**
  String get inviteEnterAlreadyGuardian;

  /// 이룸이 휴대폰에서 합류하려 할 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰에서는 할 수 없어요'**
  String get inviteEnterForbiddenForElumi;

  /// 서버가 코드 모양을 거절했을 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'초대 코드가 맞지 않아요'**
  String get inviteEnterInvalidInput;

  /// 오프라인일 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'연결하지 못했어요. 인터넷을 확인해주세요'**
  String get inviteEnterOffline;

  /// 그 밖의 실패일 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'연결하지 못했어요. 다시 해주세요'**
  String get inviteEnterOther;

  /// 약관 미동의로 합류가 막혔을 때의 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'초대 코드를 넣지 못했어요'**
  String get inviteEnterConsentFailTitle;

  /// 약관 미동의 팝업에서 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'약관에 먼저 동의해주세요'**
  String get inviteEnterConsentFallback;

  /// 링크로 받은 코드로 합류하는 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'함께하기'**
  String get inviteEnterJoinButton;

  /// 링크로 받은 코드를 거두고 직접 입력으로 바꾸는 밑줄 글
  ///
  /// In ko, this message translates to:
  /// **'다른 코드 넣기'**
  String get inviteEnterManualLink;

  /// 초대 코드 넣기 화면의 머리 제목
  ///
  /// In ko, this message translates to:
  /// **'초대 코드를\n넣어주세요'**
  String get inviteEnterTitle;

  /// 링크로 받은 코드가 채워졌을 때의 설명
  ///
  /// In ko, this message translates to:
  /// **'링크로 받은 초대 코드예요. 맞으면 함께하기를 눌러주세요'**
  String get inviteEnterDescriptionFromLink;

  /// 직접 입력할 때의 설명
  ///
  /// In ko, this message translates to:
  /// **'함께하는 보호자에게 받은 여섯 글자예요'**
  String get inviteEnterDescriptionManual;

  /// 초대 코드를 어디서 받는지 알려 주는 안내 카드의 첫 줄
  ///
  /// In ko, this message translates to:
  /// **'함께하는 보호자 휴대폰에서'**
  String get inviteEnterWhereFrom;

  /// 안내 카드의 길 안내(강조 줄)
  ///
  /// In ko, this message translates to:
  /// **'설정 → 함께하는 사람'**
  String get inviteEnterWherePath;

  /// 안내 카드의 마지막 줄
  ///
  /// In ko, this message translates to:
  /// **'초대 코드를 만들면 여섯 글자가 나와요'**
  String get inviteEnterWhereHow;

  /// 화면 낭독기가 읽는 여섯 칸의 이름(링크로 받았을 때)
  ///
  /// In ko, this message translates to:
  /// **'링크로 받은 초대 코드'**
  String get inviteEnterSemanticsFromLink;

  /// 화면 낭독기가 읽는 여섯 칸의 이름(직접 입력)
  ///
  /// In ko, this message translates to:
  /// **'초대 코드 넣기'**
  String get inviteEnterSemanticsInput;

  /// 이룸이를 바꾼 뒤의 알림
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 바꿨어요'**
  String get profileSwitchChanged;

  /// 이룸이 바꾸기 화면의 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 바꾸기'**
  String get profileSwitchTitle;

  /// 목록 조회 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'이룸이 목록을 불러오지 못했어요'**
  String get profileSwitchLoadFailedFallback;

  /// 목록이 비었을 때의 안내 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 목록을 불러오지 못했어요'**
  String get profileSwitchLoadFailedMessage;

  /// 이룸이 바꾸기 목록에서 지금 고른 줄을 낭독기가 읽는 문장. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}, 지금 보는 이룸이'**
  String profileSwitchSelected(String name);

  /// 공지 팝업 체크박스. 숨기는 기간이 기본(7일)일 때
  ///
  /// In ko, this message translates to:
  /// **'일주일간 보지 않기'**
  String get noticeHideWeek;

  /// 공지 팝업 체크박스. 숨기는 기간이 기본이 아닐 때. days 는 일수
  ///
  /// In ko, this message translates to:
  /// **'{days, plural, other{{days}일간 보지 않기}}'**
  String noticeHideDays(int days);

  /// 공지의 링크 버튼이 외부 브라우저를 못 열었을 때. 괄호 안은 추적용 에러 코드(번역하지 않는다)
  ///
  /// In ko, this message translates to:
  /// **'링크를 열지 못했어요 ({code})'**
  String noticeLinkOpenFailed(String code);

  /// 공지 팝업 바깥 배경 막을 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'공지 닫기'**
  String get noticeCloseBarrier;

  /// 카드 사진 업로드 실패 — 크기
  ///
  /// In ko, this message translates to:
  /// **'사진이 너무 커요. 다른 사진을 골라 주세요'**
  String get cardPhotoTooLarge;

  /// 카드 사진 업로드 실패 — 형식
  ///
  /// In ko, this message translates to:
  /// **'JPG나 PNG 사진만 올릴 수 있어요'**
  String get cardPhotoWrongType;

  /// 카드 사진 업로드 실패 — 읽기
  ///
  /// In ko, this message translates to:
  /// **'사진을 읽지 못했어요. 다른 사진을 골라 주세요'**
  String get cardPhotoUnreadable;

  /// 카드 사진 고르기 실패
  ///
  /// In ko, this message translates to:
  /// **'사진을 가져오지 못했어요. 다시 해주세요'**
  String get cardPhotoPickFailed;

  /// 추가 질문 준비 로딩의 제목(줄바꿈 위치는 시안대로)
  ///
  /// In ko, this message translates to:
  /// **'루미가 내용을\n정리하고 있어요'**
  String get routineLoadingPrepareTitle;

  /// 행동카드 생성 로딩의 제목(줄바꿈 위치는 시안대로)
  ///
  /// In ko, this message translates to:
  /// **'루미가 행동카드를\n만들고 있어요'**
  String get routineLoadingGenerateTitle;

  /// 준비 로딩 체크리스트 1
  ///
  /// In ko, this message translates to:
  /// **'적어 주신 상황을 살펴보고 있어요'**
  String get routineStageReviewSituation;

  /// 준비 로딩 체크리스트 2
  ///
  /// In ko, this message translates to:
  /// **'꼭 필요한 내용만 정리해요'**
  String get routineStageTidyEssentials;

  /// 준비 로딩 체크리스트 3
  ///
  /// In ko, this message translates to:
  /// **'추가 질문을 생각하고 있어요'**
  String get routineStageThinkQuestions;

  /// 생성 로딩 체크리스트 1
  ///
  /// In ko, this message translates to:
  /// **'오늘의 일과를 읽고 있어요'**
  String get routineStageReadRoutine;

  /// 생성 로딩 체크리스트 2
  ///
  /// In ko, this message translates to:
  /// **'중요한 준비물을 찾고 있어요'**
  String get routineStageFindItems;

  /// 생성 로딩 체크리스트 3
  ///
  /// In ko, this message translates to:
  /// **'순서를 정리하고 있어요'**
  String get routineStageOrderSteps;

  /// 서버가 죽었을 때의 추천 칩 1 글
  ///
  /// In ko, this message translates to:
  /// **'비 오는 날 등교'**
  String get suggestionRainyText;

  /// 추천 칩 1 이 입력창에 채우는 문장
  ///
  /// In ko, this message translates to:
  /// **'비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요'**
  String get suggestionRainyPrompt;

  /// 추천 칩 2 글
  ///
  /// In ko, this message translates to:
  /// **'병원 방문 준비'**
  String get suggestionHospitalText;

  /// 추천 칩 2 가 입력창에 채우는 문장
  ///
  /// In ko, this message translates to:
  /// **'이룸이와 함께 병원에 가야 하는데 무서워하지 않게 준비하고 싶어요'**
  String get suggestionHospitalPrompt;

  /// 추천 칩 3 글
  ///
  /// In ko, this message translates to:
  /// **'체험학습 준비'**
  String get suggestionTripText;

  /// 추천 칩 3 이 입력창에 채우는 문장
  ///
  /// In ko, this message translates to:
  /// **'체험학습 가는 날 아침에 챙길 것들을 순서대로 알려주고 싶어요'**
  String get suggestionTripPrompt;

  /// 추천 칩 4 글
  ///
  /// In ko, this message translates to:
  /// **'새로운 장소 방문'**
  String get suggestionNewPlaceText;

  /// 추천 칩 4 가 입력창에 채우는 문장
  ///
  /// In ko, this message translates to:
  /// **'처음 가보는 장소에 가기 전에 이룸이가 마음의 준비를 하게 돕고 싶어요'**
  String get suggestionNewPlacePrompt;

  /// 추천 칩 5 글
  ///
  /// In ko, this message translates to:
  /// **'여름방학 방과후 수업 준비'**
  String get suggestionAfterSchoolText;

  /// 추천 칩 5 가 입력창에 채우는 문장
  ///
  /// In ko, this message translates to:
  /// **'방학 중 방과후 수업에 갈 준비를 순서대로 알려주고 싶어요'**
  String get suggestionAfterSchoolPrompt;

  /// 보호자 홈의 오늘 일과 구역 제목
  ///
  /// In ko, this message translates to:
  /// **'오늘 일과'**
  String get guardianHomeTodayRoutine;

  /// 보호자 홈의 지난 일과 구역 제목
  ///
  /// In ko, this message translates to:
  /// **'지난 일과'**
  String get guardianHomePastRoutine;

  /// 보호자 홈에서 이룸이 화면으로 넘어가는 배지 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'이룸이 화면으로 가기'**
  String get guardianHomeGoChildScreen;

  /// 보호자 홈의 설정 아이콘 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get guardianHomeSettings;

  /// 보호자 홈의 인사말(Figma 문구, 줄바꿈 위치도 디자인이 정한 대로). name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'안녕하세요,\n{name} 보호자님 👋🏻'**
  String guardianHomeGreeting(String name);

  /// 보호자 홈 인사말 아래 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'오늘은 어떤 일과를 준비할까요?'**
  String get guardianHomeSubtitle;

  /// 비밀암호 만들기에서 확인 입력이 다를 때의 안내(온보딩 문구와 같다)
  ///
  /// In ko, this message translates to:
  /// **'암호가 달라요. 다시 넣어주세요'**
  String get pinChangeMismatchCreate;

  /// 비밀암호 바꾸기에서 입력이 다를 때의 안내(시안 문구)
  ///
  /// In ko, this message translates to:
  /// **'암호가 달라요. 다시 입력해주세요'**
  String get pinChangeMismatch;

  /// 비밀암호 만들기 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'비밀암호를 만들지 못했어요'**
  String get pinChangeCreateFailedTitle;

  /// 비밀암호 바꾸기 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'비밀암호를 바꾸지 못했어요'**
  String get pinChangeFailedTitle;

  /// 비밀암호 저장 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get pinChangeFailedFallback;

  /// 비밀암호 만들기를 마쳤을 때의 스낵바
  ///
  /// In ko, this message translates to:
  /// **'비밀암호를 만들었어요'**
  String get pinChangeCreatedSnack;

  /// 비밀암호 바꾸기를 마쳤을 때의 스낵바
  ///
  /// In ko, this message translates to:
  /// **'비밀암호를 바꿨어요'**
  String get pinChangeChangedSnack;

  /// 비밀암호 바꾸기 1단계(지금 암호 확인) 큰 제목
  ///
  /// In ko, this message translates to:
  /// **'지금 비밀암호를\n입력해주세요'**
  String get pinChangeVerifyTitle;

  /// 비밀암호 만들기 입력 단계 큰 제목(온보딩 문구와 같다)
  ///
  /// In ko, this message translates to:
  /// **'보호자님만 아는\n비밀암호를 만들어주세요'**
  String get pinChangeCreateTitle;

  /// 비밀암호 만들기·재입력 단계와 바꾸기 새 암호 단계가 함께 쓰는 설명
  ///
  /// In ko, this message translates to:
  /// **'보호자모드로 변경할 때 사용하는 암호예요'**
  String get pinModeHint;

  /// 비밀암호 바꾸기 2단계(새 암호) 큰 제목
  ///
  /// In ko, this message translates to:
  /// **'새 비밀암호를\n입력해주세요'**
  String get pinChangeEnterTitle;

  /// 비밀암호 만들기 재입력 단계 큰 제목(온보딩 문구와 같다)
  ///
  /// In ko, this message translates to:
  /// **'암호를 한번 더\n입력해주세요'**
  String get pinChangeCreateConfirmTitle;

  /// 비밀암호 바꾸기 3단계(새 암호 재입력) 큰 제목
  ///
  /// In ko, this message translates to:
  /// **'비밀암호를 한번 더\n입력해주세요'**
  String get pinChangeConfirmTitle;

  /// 비밀암호 바꾸기 3단계 설명
  ///
  /// In ko, this message translates to:
  /// **'이제 곧 비밀암호 변경이 끝나요'**
  String get pinChangeConfirmHint;

  /// 비밀암호 바꾸기 화면 머리 제목
  ///
  /// In ko, this message translates to:
  /// **'비밀암호 변경하기'**
  String get pinChangeHeaderTitle;

  /// 비밀암호 변경 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get pinChangeSave;

  /// 암호 점 자리를 낭독기가 읽는 이름(입력한 숫자는 읽지 않는다)
  ///
  /// In ko, this message translates to:
  /// **'암호 넣기'**
  String get pinChangeInputLabel;

  /// 보상 고치기 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'보상을 저장하지 못했어요'**
  String get rewardSaveFailedTitle;

  /// 보상 저장 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get rewardSaveFailedFallback;

  /// 보상 설명 팝업 제목이자 도움말 버튼 이름
  ///
  /// In ko, this message translates to:
  /// **'보상이 왜 필요한가요?'**
  String get rewardWhyTitle;

  /// 보상이 왜 필요한지 설명하는 팝업 본문(세 문장, 줄바꿈 유지)
  ///
  /// In ko, this message translates to:
  /// **'일과를 마친 뒤 기다리는 것이 있으면 이룸이가 끝까지 해낼 힘이 생겨요.\n한 달 뒤 선물보다 오늘 바로 줄 수 있는 작은 것이 더 잘 통해요.\n정하지 않아도 일과는 만들 수 있어요.'**
  String get rewardWhyMessage;

  /// 보상 정하기 화면 큰 제목(줄바꿈은 시안 그대로)
  ///
  /// In ko, this message translates to:
  /// **'일과가 끝나면\n어떤 보상을 줄까요?'**
  String get rewardHeadlineTitle;

  /// 보상 정하기 화면 부제
  ///
  /// In ko, this message translates to:
  /// **'일과를 완료하는 데 큰 동기가 될 거예요'**
  String get rewardHeadlineBody;

  /// 보상 정하기를 건너뛰는 밑줄 링크
  ///
  /// In ko, this message translates to:
  /// **'나중에 할게요'**
  String get rewardLater;

  /// 그림 방식을 바꾼 뒤 스낵바
  ///
  /// In ko, this message translates to:
  /// **'그림 방식을 바꿨어요'**
  String get imageStyleChangedSnack;

  /// 그림 방식 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'그림 방식을 저장하지 못했어요'**
  String get imageStyleSaveFailedTitle;

  /// 그림 방식 저장 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get imageStyleSaveFailedFallback;

  /// 그림 방식 설정 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'그림 방식'**
  String get imageStyleTitle;

  /// 크레딧 때문에 막혔을 때의 로딩 실패 제목
  ///
  /// In ko, this message translates to:
  /// **'지금은 만들 수 없어요'**
  String get routineLoadingBlockedTitle;

  /// 준비 로딩 실패 제목
  ///
  /// In ko, this message translates to:
  /// **'질문을 준비하지 못했어요'**
  String get routineLoadingPrepareFailed;

  /// 생성 로딩 실패 제목
  ///
  /// In ko, this message translates to:
  /// **'카드를 만들지 못했어요'**
  String get routineLoadingGenerateFailed;

  /// 일과 만들기 로딩의 진행률을 낭독기가 읽는 문장
  ///
  /// In ko, this message translates to:
  /// **'{percent}% 진행됐어요'**
  String routineLoadingPercent(int percent);

  /// 로딩 실패 화면의 다시 하기 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 하기'**
  String get routineLoadingRetry;

  /// 로딩 실패 화면의 홈 버튼
  ///
  /// In ko, this message translates to:
  /// **'홈으로'**
  String get routineLoadingHome;

  /// 임시저장 목록 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장'**
  String get draftRoutinesTitle;

  /// 임시저장 목록을 못 불러왔을 때의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'임시저장을 불러오지 못했어요'**
  String get draftRoutinesLoadFailedFallback;

  /// 줄을 밀면 나오는 삭제 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'임시저장 삭제'**
  String get draftRoutinesDeleteLabel;

  /// 임시저장 삭제 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장을 삭제하실건가요?'**
  String get draftRoutinesDeleteConfirmTitle;

  /// 임시저장 삭제 확인 팝업의 삭제 버튼
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get draftRoutinesDeleteAction;

  /// 임시저장 삭제 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장을 삭제하지 못했어요'**
  String get draftRoutinesDeleteFailedTitle;

  /// 임시저장 삭제 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get draftRoutinesDeleteFailedFallback;

  /// 보상을 안 정한 임시저장 줄의 보상 자리 글
  ///
  /// In ko, this message translates to:
  /// **'미설정'**
  String get draftRoutinesRewardUnset;

  /// 임시저장 줄의 보상 앞 말머리
  ///
  /// In ko, this message translates to:
  /// **'완료 시'**
  String get draftRoutinesRewardLabel;

  /// 임시저장 줄 오른쪽 알약 버튼
  ///
  /// In ko, this message translates to:
  /// **'이어서'**
  String get draftRoutinesResume;

  /// 임시저장이 0건일 때 제목
  ///
  /// In ko, this message translates to:
  /// **'만들다 만 일과가 없어요'**
  String get draftRoutinesEmptyTitle;

  /// 임시저장이 0건일 때 설명
  ///
  /// In ko, this message translates to:
  /// **'일과를 만들다 그만두면 여기에 남아요'**
  String get draftRoutinesEmptyBody;

  /// 카드 삭제 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'카드를 삭제하실건가요?'**
  String get cardReviewDeleteConfirmTitle;

  /// 카드 삭제 확인 팝업의 삭제 버튼
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get cardReviewDeleteAction;

  /// 카드 소리 재생 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'소리를 재생하지 못했어요'**
  String get cardReviewSoundFailedTitle;

  /// 카드 소리 재생 실패 팝업 안내
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 소리를 켜고 다시 눌러주세요'**
  String get cardReviewSoundFailedFallback;

  /// 일과 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'일과를 저장하지 못했어요'**
  String get cardReviewSaveFailedTitle;

  /// 일과 저장 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get cardReviewSaveFailedFallback;

  /// 카드 고친 내용 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'고친 내용을 저장하지 못했어요'**
  String get cardReviewEditFailedTitle;

  /// 카드 고친 내용 저장 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get cardReviewEditFailedFallback;

  /// 카드 추가 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'카드를 추가하지 못했어요'**
  String get cardReviewAddFailedTitle;

  /// 카드 추가 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get cardReviewAddFailedFallback;

  /// 카드 순서 바꾸기 중 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get cardReviewReorderDone;

  /// 카드 검토 화면 하단 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'카드 저장하기'**
  String get cardReviewSave;

  /// 일과 입력 화면 큰 제목(줄바꿈은 디자인이 정한 대로)
  ///
  /// In ko, this message translates to:
  /// **'오늘은 어떤 준비가\n필요한가요?'**
  String get routineInputTitle;

  /// 일과 입력 화면 부제
  ///
  /// In ko, this message translates to:
  /// **'AI 루미가 작은 행동 단계로 나눠드려요'**
  String get routineInputSubtitle;

  /// 일과 입력창 안내 글(포커스가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'평소 이야기하듯 입력해주세요'**
  String get routineInputHint;

  /// 일과 입력창 전송 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get routineInputSend;

  /// 로그아웃 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 하실건가요?'**
  String get guardianSettingsLogoutConfirmTitle;

  /// 회원탈퇴 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴 하실건가요?'**
  String get guardianSettingsWithdrawConfirmTitle;

  /// 회원탈퇴 확인 팝업의 되돌릴 수 없다는 고지
  ///
  /// In ko, this message translates to:
  /// **'만든 일과와 모은 별이 모두 사라져요\n다시 로그인해도 되돌릴 수 없어요'**
  String get guardianSettingsWithdrawConfirmMessage;

  /// 회원탈퇴 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하지 못했어요'**
  String get guardianSettingsWithdrawFailedTitle;

  /// 회원탈퇴 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get guardianSettingsWithdrawFailedFallback;

  /// 보호자 설정 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get guardianSettingsTitle;

  /// 설정 줄 — 함께 돌보는 사람 목록
  ///
  /// In ko, this message translates to:
  /// **'함께하는 사람'**
  String get guardianSettingsPeople;

  /// 설정 줄 — 임시저장 목록
  ///
  /// In ko, this message translates to:
  /// **'임시저장'**
  String get guardianSettingsDrafts;

  /// 설정 줄 — 비밀암호 바꾸기
  ///
  /// In ko, this message translates to:
  /// **'비밀암호 변경하기'**
  String get guardianSettingsPinChange;

  /// 설정 줄 — 약관 목록
  ///
  /// In ko, this message translates to:
  /// **'약관 및 개인정보처리방침'**
  String get guardianSettingsTerms;

  /// 설정 줄 — 로그아웃
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get guardianSettingsLogout;

  /// 설정 줄 — 회원탈퇴
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴'**
  String get guardianSettingsWithdraw;

  /// 설정 줄 — 이룸이 휴대폰이 이미 연결됐을 때
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰'**
  String get guardianSettingsLinkConnected;

  /// 설정 줄 — 이룸이 휴대폰을 아직 연결하지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'이룸이 휴대폰 연결하기'**
  String get guardianSettingsLinkConnect;

  /// 설정 줄 — 이룸이 휴대폰 연결 상태 값
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get guardianSettingsLinkStatus;

  /// 설정 줄 — 연결된 이룸이가 둘 이상일 때 보는 이룸이를 바꾼다
  ///
  /// In ko, this message translates to:
  /// **'이룸이 바꾸기'**
  String get guardianSettingsProfileSwitch;

  /// 설정 줄 — 카드 그림 방식
  ///
  /// In ko, this message translates to:
  /// **'그림 방식'**
  String get guardianSettingsImageStyle;

  /// 설정 줄 — 이룸이가 카드를 체크할 때 진동 켜기/끄기
  ///
  /// In ko, this message translates to:
  /// **'카드 체크 진동'**
  String get guardianSettingsHaptic;

  /// 추가 질문 화면 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'카드 만들기'**
  String get questionMakeCards;

  /// 추가 질문의 직접 입력 칩
  ///
  /// In ko, this message translates to:
  /// **'+ 직접 입력하기'**
  String get questionCustomAdd;

  /// 추가 질문 직접 입력칸 안내 글
  ///
  /// In ko, this message translates to:
  /// **'직접 적어주세요'**
  String get questionCustomHint;

  /// 추가 질문 직접 입력칸의 닫기 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'직접 입력 닫기'**
  String get questionCustomClose;

  /// 추가 질문에서 고른 칩의 X 버튼을 낭독기가 읽는 이름. label 은 칩 글자
  ///
  /// In ko, this message translates to:
  /// **'{label} 지우기'**
  String questionClearLabel(String label);

  /// 카드 검토 화면 머리. count 는 만들어진 카드 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{카드 {count}개를 만들었어요}}'**
  String cardReviewMade(int count);

  /// 카드 검토 화면 보상 줄의 앞말. 뒤에 보상 글이 이어 붙으므로 끝의 공백을 유지한다
  ///
  /// In ko, this message translates to:
  /// **'완료 시 '**
  String get cardReviewRewardLead;

  /// 카드 검토 화면에서 보상을 아직 안 정했을 때 보상 줄
  ///
  /// In ko, this message translates to:
  /// **'보상 정하기'**
  String get cardReviewRewardSet;

  /// 카드 검토 화면 아래 순서 변경 안내 한 줄
  ///
  /// In ko, this message translates to:
  /// **'카드를 길게 눌러 순서를 변경하세요'**
  String get cardReviewReorderHint;

  /// 카드 검토 화면 도구 버튼. 순서 변경 모드를 켜고 끈다
  ///
  /// In ko, this message translates to:
  /// **'카드 순서 변경'**
  String get cardReviewToolReorder;

  /// 카드 검토 화면 도구 버튼. 지금 보는 카드를 고친다
  ///
  /// In ko, this message translates to:
  /// **'이 카드 수정'**
  String get cardReviewToolEdit;

  /// 카드 검토 화면 도구 버튼. 카드를 새로 더한다
  ///
  /// In ko, this message translates to:
  /// **'카드 추가'**
  String get cardReviewToolAdd;

  /// 카드 순서 변경 모드의 위쪽 제목
  ///
  /// In ko, this message translates to:
  /// **'카드 순서 변경'**
  String get cardReviewReorderTitle;

  /// 카드 순서 변경 모드의 닫기 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'순서 변경 취소'**
  String get cardReviewReorderCancel;

  /// 카드 검토 화면의 빈 상태 제목
  ///
  /// In ko, this message translates to:
  /// **'만들어진 카드가 없어요'**
  String get cardReviewEmptyTitle;

  /// 카드 검토 화면의 빈 상태 안내. 에러 코드는 화면이 따로 붙인다
  ///
  /// In ko, this message translates to:
  /// **'일과를 처음부터 다시 만들어 주세요'**
  String get cardReviewEmptyBody;

  /// 카드가 없을 때 일과 입력으로 돌아가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 만들기'**
  String get cardReviewEmptyAction;

  /// 카드 순서 바꾸기에서 낭독기 사용자가 쓰는 동작 이름
  ///
  /// In ko, this message translates to:
  /// **'앞으로 옮기기'**
  String get cardMoveForward;

  /// 카드 순서 바꾸기에서 낭독기 사용자가 쓰는 동작 이름
  ///
  /// In ko, this message translates to:
  /// **'뒤로 옮기기'**
  String get cardMoveBackward;

  /// 카드를 읽어 주는 중일 때 소리 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'읽기 멈추기'**
  String get cardSpeakStop;

  /// 카드를 읽어 주는 소리 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'소리로 듣기'**
  String get cardSpeak;

  /// 카드 검토 화면 카드 위 지우기 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'이 카드 지우기'**
  String get cardDeleteLabel;

  /// 사진이 없는 카드의 그림 자리 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'사진 추가'**
  String get cardAddPhoto;

  /// 카드 크게 보기 팝업의 배경 막 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'카드 닫기'**
  String get cardViewerBarrierLabel;

  /// 카드 크게 보기에서 소리 재생이 실패했을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'소리를 재생하지 못했어요'**
  String get cardViewerSoundFailedTitle;

  /// 카드 크게 보기에서 소리 재생이 실패했을 때 서버 문구가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 소리를 켜고 다시 눌러주세요'**
  String get cardViewerSoundFailedFallback;

  /// 카드 크게 보기의 닫기 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'카드 닫기'**
  String get cardViewerClose;

  /// 카드 수정 시트가 추가 모드일 때 제목
  ///
  /// In ko, this message translates to:
  /// **'새로운 카드 추가'**
  String get cardEditAddTitle;

  /// 카드 수정 시트가 수정 모드일 때 제목
  ///
  /// In ko, this message translates to:
  /// **'카드 수정'**
  String get cardEditTitle;

  /// 카드 수정 시트의 제목 입력칸 이름
  ///
  /// In ko, this message translates to:
  /// **'제목'**
  String get cardEditFieldTitle;

  /// 카드 수정 시트 제목 입력칸 안내 글
  ///
  /// In ko, this message translates to:
  /// **'카드 제목을 적어주세요'**
  String get cardEditTitleHint;

  /// 카드 수정 시트의 설명 입력칸 이름
  ///
  /// In ko, this message translates to:
  /// **'설명'**
  String get cardEditFieldDescription;

  /// 카드 수정 시트 설명 입력칸 안내 글
  ///
  /// In ko, this message translates to:
  /// **'카드 설명을 적어주세요'**
  String get cardEditDescriptionHint;

  /// 카드 수정 시트가 추가 모드일 때 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'추가하기'**
  String get cardEditAddAction;

  /// 카드 수정 시트가 수정 모드일 때 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get cardEditDoneAction;

  /// 사진 권한 안내 화면에서 사진 찍기로 바꾸는 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'사진 찍기'**
  String get cardPhotoPermissionTake;

  /// 사진 권한 안내 화면에서 갤러리로 바꾸는 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'갤러리에서 고르기'**
  String get cardPhotoPermissionGallery;

  /// 사진 권한 안내 화면의 휴대폰 설정 열기 버튼
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get cardPhotoPermissionOpenSettings;

  /// 카메라 권한이 막혔을 때 사진 권한 안내 제목
  ///
  /// In ko, this message translates to:
  /// **'카메라를 쓸 수 없어요'**
  String get cardPhotoPermissionCameraTitle;

  /// 사진 접근 권한이 막혔을 때 사진 권한 안내 제목
  ///
  /// In ko, this message translates to:
  /// **'사진을 볼 수 없어요'**
  String get cardPhotoPermissionGalleryTitle;

  /// 카메라 권한이 막혔을 때 사진 권한 안내 설명
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 설정에서 카메라를 켜면 사진을 찍을 수 있어요'**
  String get cardPhotoPermissionCameraBody;

  /// 사진 접근 권한이 막혔을 때 사진 권한 안내 설명
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 설정에서 사진 접근을 켜면 고를 수 있어요'**
  String get cardPhotoPermissionGalleryBody;

  /// 사진 권한 안내에서 휴대폰 설정을 못 열었을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'설정을 열지 못했어요'**
  String get cardPhotoSettingsFailedTitle;

  /// 사진 권한 안내에서 휴대폰 설정을 못 열었을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 설정에서 직접 켜 주세요'**
  String get cardPhotoSettingsFailedFallback;

  /// 사진 고르기 시트의 사진 찍기 줄
  ///
  /// In ko, this message translates to:
  /// **'사진 찍기'**
  String get cardPhotoSourceTake;

  /// 사진 고르기 시트의 갤러리 줄
  ///
  /// In ko, this message translates to:
  /// **'갤러리에서 고르기'**
  String get cardPhotoSourceGallery;

  /// 사진 고르기 시트 아래 개인정보 주의 안내
  ///
  /// In ko, this message translates to:
  /// **'얼굴이나 개인정보가 나오지 않게 찍어 주세요'**
  String get cardPhotoSourcePrivacy;

  /// 사진 올리기가 실패했는데 자리가 없어 팝업으로 알릴 때 제목. message 는 실패 사유(서버 문구가 우선)
  ///
  /// In ko, this message translates to:
  /// **'사진을 올리지 못했어요.\n{message}'**
  String cardPhotoUploadFailedDialog(String message);

  /// 카드 그림 아래 사진 바꾸기 칩의 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'사진 바꾸기'**
  String get cardPhotoChange;

  /// 사진을 올리는 동안 그림 위에 덮이는 안내
  ///
  /// In ko, this message translates to:
  /// **'사진을 올리고 있어요'**
  String get cardPhotoUploading;

  /// 사진 올리기 실패 때 그림 위에 덮이는 안내 제목
  ///
  /// In ko, this message translates to:
  /// **'사진을 올리지 못했어요'**
  String get cardPhotoUploadFailed;

  /// 사진 올리기 실패 안내의 다시 하기 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 하기'**
  String get cardPhotoRetry;

  /// AI 크레딧 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'이번 주 AI 생성'**
  String get creditCardTitle;

  /// AI 크레딧 카드가 불러오는 중일 때 낭독 문구
  ///
  /// In ko, this message translates to:
  /// **'이번 주 AI 생성 사용량을 불러오고 있어요'**
  String get creditCardLoading;

  /// AI 크레딧 카드 조회가 실패했을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'사용량을 불러오지 못했어요'**
  String get creditCardLoadFailed;

  /// AI 크레딧 카드 조회 실패의 다시 하기 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 하기'**
  String get creditCardRetry;

  /// AI 크레딧 카드에서 일과를 만드는 중일 때 줄
  ///
  /// In ko, this message translates to:
  /// **'일과를 만들고 있어요'**
  String get creditGenerating;

  /// AI 크레딧 카드에서 크레딧을 다 썼을 때 첫 줄
  ///
  /// In ko, this message translates to:
  /// **'이번 주 크레딧을 모두 사용했어요'**
  String get creditExhausted;

  /// AI 크레딧 카드에서 크레딧을 다 썼을 때 둘째 줄
  ///
  /// In ko, this message translates to:
  /// **'만든 일과 보기와 직접 고치기는 계속 할 수 있어요'**
  String get creditExhaustedStillOk;

  /// AI 크레딧 카드의 안내 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'AI 크레딧 안내'**
  String get creditInfoLabel;

  /// AI 크레딧 카드의 낭독용 숫자 줄. available 은 남은 수, weekly 는 주간 지급량
  ///
  /// In ko, this message translates to:
  /// **'{available} / {weekly} 크레딧 남음'**
  String creditAmountLeft(int available, int weekly);

  /// AI 크레딧 카드에서 큰 숫자(남은 수) 뒤에 이어 붙는 작은 글자. 앞의 공백을 유지한다
  ///
  /// In ko, this message translates to:
  /// **' / {weekly} 크레딧 남음'**
  String creditAmountRest(int weekly);

  /// AI 크레딧이 다시 채워지는 시각 줄. reset 은 시각 문구(예: 9월 28일(월) 0시)
  ///
  /// In ko, this message translates to:
  /// **'{reset}에 다시 채워져요'**
  String aiCreditResetLine(String reset);

  /// AI 크레딧 안내 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'AI 크레딧은 이렇게 줄어요'**
  String get creditCostTitle;

  /// AI 크레딧 단가 안내. textCost 는 일과 글 단가, imageCost 는 카드 그림 한 장 단가(서버 값)
  ///
  /// In ko, this message translates to:
  /// **'일과 글을 만들 때 {textCost, plural, other{{textCost}개}}, 그림이 완성된 카드 1장마다 {imageCost, plural, other{{imageCost}개}}씩 써요.'**
  String creditCostLine(int textCost, int imageCost);

  /// AI 크레딧 안내 팝업의 둘째 문장
  ///
  /// In ko, this message translates to:
  /// **'크레딧이 남아 있을 때 시작한 일과는 그림이 많아도 끝까지 만들어져요.'**
  String get creditCostKeepGoing;

  /// AI 크레딧 안내 팝업의 셋째 문장
  ///
  /// In ko, this message translates to:
  /// **'매주 월요일 0시에 다시 채워져요.'**
  String get creditWeeklyRefill;

  /// 보호자 홈의 새 일과 만들기 버튼
  ///
  /// In ko, this message translates to:
  /// **'새로운 일과 만들기'**
  String get routineCreateButton;

  /// 일과 줄을 밀었을 때 나오는 삭제 버튼 기본 글자
  ///
  /// In ko, this message translates to:
  /// **'일과 삭제'**
  String get routineSwipeDelete;

  /// 일과 줄을 밀었을 때 나오는 수정 버튼
  ///
  /// In ko, this message translates to:
  /// **'일과 수정'**
  String get routineSwipeEdit;

  /// 일과 입력 화면의 추천 목록이 실패했을 때 한 줄(서버 문구가 우선)
  ///
  /// In ko, this message translates to:
  /// **'추천을 불러오지 못했어요 · 다시 시도'**
  String get routineSuggestLoadFailed;

  /// 일과 만들기 흐름 위쪽 집 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'홈으로 가기'**
  String get routineFlowHomeLabel;

  /// 일과 만들기 흐름 위쪽 임시저장 버튼의 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'임시저장'**
  String get routineFlowDraftLabel;

  /// 일과 만들기를 나가는 팝업의 머무는 버튼
  ///
  /// In ko, this message translates to:
  /// **'계속 만들기'**
  String get routineFlowLeaveStay;

  /// 일과 만들기를 나가는 팝업의 나가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'나가기'**
  String get routineFlowLeaveConfirm;

  /// 일과 만들기를 나가는 팝업 제목. 적은 내용이 사라지는 경우
  ///
  /// In ko, this message translates to:
  /// **'일과 만들기를 그만둘까요?'**
  String get routineLeaveDiscardTitle;

  /// 일과 만들기를 나가는 팝업 설명. 적은 내용이 사라지는 경우
  ///
  /// In ko, this message translates to:
  /// **'지금 나가면 적은 내용은 남지 않아요'**
  String get routineLeaveDiscardMessage;

  /// 카드를 만드는 중에 나가는 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장에 두고 나갈까요?'**
  String get routineLeaveDraftWhenReadyTitle;

  /// 카드를 만드는 중에 나가는 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'카드가 다 만들어지면 임시저장에 남아요\n설정에서 이어서 만들 수 있어요'**
  String get routineLeaveDraftWhenReadyMessage;

  /// 카드 검토 화면에서 나가는 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장에 두고 나갈까요?'**
  String get routineLeaveDraftTitle;

  /// 카드 검토 화면에서 나가는 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'설정의 임시저장에서\n이어서 만들 수 있어요'**
  String get routineLeaveDraftMessage;

  /// 저장한 일과를 고치다 나가는 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'저장하지 않고 나갈까요?'**
  String get routineLeaveEditTitle;

  /// 저장한 일과를 고치다 나가는 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'뺀 카드는 저장하기를 눌러야 빠져요'**
  String get routineLeaveEditMessage;

  /// 일과 줄 아래 보상 글자 앞의 이름표
  ///
  /// In ko, this message translates to:
  /// **'완료 시'**
  String get routineTileRewardLabel;

  /// 지난 일과 줄의 다시하기 버튼
  ///
  /// In ko, this message translates to:
  /// **'일과 다시하기'**
  String get routineTileRerun;

  /// 일과 상세 시트에서 카드 순서 저장이 실패했을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'순서를 저장하지 못했어요'**
  String get routineDetailReorderFailedTitle;

  /// 일과 상세 시트에서 카드 순서 저장이 실패했을 때 서버 문구가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get routineDetailReorderFailedFallback;

  /// 지난 일과 상세 시트 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'일과 다시하기'**
  String get routineDetailRerun;

  /// 오늘 일과 상세 시트 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'편집하기'**
  String get routineDetailEdit;

  /// 이룸이가 다 끝낸 오늘 일과의 상세 시트 아래 버튼(눌리지 않는다)
  ///
  /// In ko, this message translates to:
  /// **'다 끝낸 일과예요'**
  String get routineDetailFinishedToday;

  /// 일과 상세 시트의 카드 줄 낭독 힌트
  ///
  /// In ko, this message translates to:
  /// **'눌러서 카드 크게 보기'**
  String get routineDetailOpenHint;

  /// 일과 상세 시트에서 보상을 정하지 않았을 때 보상 줄
  ///
  /// In ko, this message translates to:
  /// **'일과 완료 후 보상이 없어요'**
  String get routineDetailNoReward;

  /// 보상 직접 입력칸 안내 글
  ///
  /// In ko, this message translates to:
  /// **'예) 유튜브 10분 보기'**
  String get rewardInputHint;

  /// 보호자 홈에서 일과 순서 저장이 실패했을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'순서를 저장하지 못했어요'**
  String get todayRoutineReorderFailedTitle;

  /// 보호자 홈에서 일과 순서 저장이 실패했을 때 서버 문구가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get todayRoutineReorderFailedFallback;

  /// 보호자 홈에서 일과를 지우기 전 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'일과를 삭제하실건가요?'**
  String get todayRoutineDeleteConfirmTitle;

  /// 이룸이가 한 단계라도 한 일과를 지우려 할 때 안내 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 시작한 일과예요'**
  String get todayRoutineStartedTitle;

  /// 시작한 일과를 지울 수 없는 이유를 알리는 안내 팝업 문장
  ///
  /// In ko, this message translates to:
  /// **'한 일이 기록으로 남도록 지울 수 없어요'**
  String get todayRoutineStartedMessage;

  /// 보호자 홈 일과 삭제 확인 팝업의 삭제 버튼
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get todayRoutineDeleteAction;

  /// 보호자 홈에서 일과 삭제가 실패했을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'일과를 삭제하지 못했어요'**
  String get todayRoutineDeleteFailedTitle;

  /// 보호자 홈에서 일과 삭제가 실패했을 때 서버 문구가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get todayRoutineDeleteFailedFallback;

  /// 보호자 홈 오늘 일과 조회가 실패했을 때 서버 문구가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'일과를 불러오지 못했어요'**
  String get todayRoutineLoadFailedFallback;

  /// 지난 일과를 오늘로 복제하다 실패했을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'일과를 다시 만들지 못했어요'**
  String get todayRoutineRerunFailedTitle;

  /// 지난 일과를 오늘로 복제하다 실패했을 때 서버 문구가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get todayRoutineRerunFailedFallback;

  /// 지난 일과를 오늘 일과로 복제한 뒤의 알림. title 은 일과 제목(조사는 받침을 모르므로 을(를) 로 쓴다)
  ///
  /// In ko, this message translates to:
  /// **'{title}을(를) 오늘 일과에 담았어요'**
  String todayRoutineCopied(String title);

  /// 보호자 홈 지난 일과 조회가 실패했을 때 서버 문구가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'지난 일과를 불러오지 못했어요'**
  String get todayRoutinePastLoadFailedFallback;

  /// 보호자 홈 오늘 일과가 0건일 때 첫 줄
  ///
  /// In ko, this message translates to:
  /// **'아직 만든 일과가 없어요'**
  String get todayRoutineEmptyTitle;

  /// 보호자 홈 오늘 일과가 0건일 때 둘째 줄
  ///
  /// In ko, this message translates to:
  /// **'오늘의 첫 행동카드를 만들어보세요'**
  String get todayRoutineEmptyHint;

  /// 보호자 홈 지난 일과가 0건일 때 줄
  ///
  /// In ko, this message translates to:
  /// **'지난 일과가 없어요'**
  String get todayRoutinePastEmpty;

  /// 홈 코치마크 1단계. *로 감싼 부분이 강조된다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 수행할 *새로운\n일과를 만들 수 있어요*'**
  String get homeCoachCreate;

  /// 홈 코치마크 2단계. *로 감싼 부분이 강조된다
  ///
  /// In ko, this message translates to:
  /// **'일과를 *왼쪽으로 스와이프*하면\n*수정하거나 삭제*할 수 있어요'**
  String get homeCoachSwipe;

  /// 홈 코치마크 3단계. *로 감싼 부분이 강조된다
  ///
  /// In ko, this message translates to:
  /// **'캐릭터 아이콘을 누르면\n*이룸이모드로 바꿀 수 있어요*'**
  String get homeCoachSwitch;

  /// 이룸이 홈 인사말(시안 문구, 줄바꿈 위치 유지). name 은 이룸이 호칭. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'오늘 {name}{batchim, select, yes{이} other{가}}\n할 일들이에요. 힘내봐요!'**
  String childHomeGreeting(String name, String batchim);

  /// 이룸이 홈에 일과가 하나도 없을 때의 제목. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'아직 {name}의\n일과가 없어요'**
  String childHomeEmptyTitle(String name);

  /// 일과가 없을 때의 안내(보호자 폰에서 보는 이룸이 화면)
  ///
  /// In ko, this message translates to:
  /// **'보호자 화면에서 일과를 만들 수 있어요'**
  String get childHomeEmptyHint;

  /// 일과가 없을 때의 안내(이룸이 전용 휴대폰)
  ///
  /// In ko, this message translates to:
  /// **'보호자 휴대폰에서 일과를 만들 수 있어요'**
  String get childHomeEmptyHintDevice;

  /// 이룸이 홈 오른쪽 위 캐릭터 배지를 낭독기가 읽는 이름(보호자 화면으로 이동)
  ///
  /// In ko, this message translates to:
  /// **'보호자 화면으로 가기'**
  String get childHomeToGuardianLabel;

  /// 이룸이 홈 오른쪽 위 톱니 아이콘을 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get childHomeSettingsLabel;

  /// 이룸이 홈 일과 타일에서 보상 앞에 붙는 말(회색)
  ///
  /// In ko, this message translates to:
  /// **'다하면'**
  String get childHomeRewardPrefix;

  /// 별 화면 문구. count 는 모은 별 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!}}'**
  String childStarsEarned(int count);

  /// 이룸이 홈 별 표시를 낭독기가 읽는 문장. count 는 모은 별 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{별 {count}개 모았어요}}'**
  String childStarsSemantics(int count);

  /// 카드 넘기기 영역을 낭독기가 읽는 문장. total 은 전체 장수, index 는 지금 몇 번째(1부터)
  ///
  /// In ko, this message translates to:
  /// **'카드 {total}장 중 {index}번째'**
  String childCardPagerLabel(int total, int index);

  /// 카드 읽어 주기(음성)가 실패했을 때 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'소리를 재생하지 못했어요'**
  String get childDetailSoundFailedTitle;

  /// 카드 읽어 주기(음성)가 실패했을 때 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'휴대폰 소리를 켜고 다시 눌러주세요'**
  String get childDetailSoundFailedFallback;

  /// 카드 상세의 체크 버튼을 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'다 했어요'**
  String get childDetailCheckLabel;

  /// 보상 칩에서 보상 글 앞에 붙는 말. 끝의 공백 한 칸이 보상 글과의 사이다
  ///
  /// In ko, this message translates to:
  /// **'다하면 '**
  String get rewardBannerPrefix;

  /// 보상 화면(루미) 큰 제목
  ///
  /// In ko, this message translates to:
  /// **'축하해요!'**
  String get rewardLumiTitle;

  /// 보상 화면(루미) 두 줄 설명. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'할 일을 해내서 루미가\n{name}에게 별을 가져왔어요'**
  String rewardLumiMessage(String name);

  /// 보상 화면(루미) 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'오예!'**
  String get rewardLumiButton;

  /// 보상 화면(포포) 큰 제목
  ///
  /// In ko, this message translates to:
  /// **'잘했어요!'**
  String get rewardPopoTitle;

  /// 보상 화면(포포) 두 줄 설명. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'포포가 {name}에게\n축하의 선물로 큰 별을 가져왔어요'**
  String rewardPopoMessage(String name);

  /// 보상 화면(포포) 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'좋아요!'**
  String get rewardPopoButton;

  /// 보상 화면(루루) 큰 제목. 루루만 별이 아니라 선물을 가져온다
  ///
  /// In ko, this message translates to:
  /// **'멋져요!'**
  String get rewardRuruTitle;

  /// 보상 화면(루루) 두 줄 설명. name 은 이룸이 호칭. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'{name}{batchim, select, yes{이} other{가}} 할 일을 해내서\n루루가 선물을 가져왔다고 해요'**
  String rewardRuruMessage(String name, String batchim);

  /// 보상 화면(루루) 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'신난다!'**
  String get rewardRuruButton;

  /// 일과를 다 끝냈을 때 한 번 뜨는 화면의 큰 제목
  ///
  /// In ko, this message translates to:
  /// **'일과를 끝냈어요!'**
  String get routineDoneTitle;

  /// 일과 완료 화면 하단 버튼(누르면 이룸이 홈으로)
  ///
  /// In ko, this message translates to:
  /// **'오예!'**
  String get routineDoneButton;

  /// 보호자 → 이룸이 화면 전환의 암호 안내
  ///
  /// In ko, this message translates to:
  /// **'암호를 입력하면 이룸이 화면으로 바뀌어요'**
  String get modeSwitchToChild;

  /// 이룸이 → 보호자 화면 전환의 암호 안내
  ///
  /// In ko, this message translates to:
  /// **'암호를 입력하면 보호자 화면으로 바뀌어요'**
  String get modeSwitchToGuardian;

  /// 화면 전환 암호 입력 화면의 제목(시안 문구)
  ///
  /// In ko, this message translates to:
  /// **'비밀암호를 입력하세요'**
  String get modeSwitchTitle;

  /// 화면 전환 암호가 틀렸을 때 설명 자리에 뜨는 안내
  ///
  /// In ko, this message translates to:
  /// **'암호가 달라요. 다시 넣어주세요'**
  String get modeSwitchMismatch;

  /// 암호 점 영역을 낭독기가 읽는 이름(누르면 키패드가 올라온다)
  ///
  /// In ko, this message translates to:
  /// **'암호 넣기'**
  String get modeSwitchPinLabel;

  /// 저장된 암호를 읽지 못했을 때 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'암호를 확인하지 못했어요'**
  String get modeSwitchReadFailedTitle;

  /// 저장된 암호를 읽지 못했을 때 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 해주세요'**
  String get modeSwitchReadFailedFallback;

  /// 암호가 없는 이룸이 휴대폰에서 보호자 화면을 열려 할 때 제목(줄바꿈 위치 유지)
  ///
  /// In ko, this message translates to:
  /// **'보호자 휴대폰에서\n열어 주세요'**
  String get modeSwitchBlockedTitle;

  /// 암호가 없는 이룸이 휴대폰에서 보호자 화면을 열려 할 때 설명
  ///
  /// In ko, this message translates to:
  /// **'이 휴대폰에서는 보호자 화면을 열 수 없어요'**
  String get modeSwitchBlockedDescription;

  /// 보호자 화면을 열 수 없다는 안내의 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'돌아가기'**
  String get modeSwitchBlockedBack;

  /// No description provided for @installationRetryMessage.
  ///
  /// In ko, this message translates to:
  /// **'휴대폰의 로그인 정보를 확인하지 못했어요. 다시 시도해 주세요.'**
  String get installationRetryMessage;

  /// No description provided for @installationRetryButton.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get installationRetryButton;
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
