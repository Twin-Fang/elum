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

  /// 보호자 홈 알림 꺼짐 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'알림을 켜 둘까요?'**
  String get notificationOffNoticeTitle;

  /// 보호자 홈 알림 꺼짐 카드 본문 (이룸이가 일과를 끝낸 알림을 받는다는 뜻)
  ///
  /// In ko, this message translates to:
  /// **'일과를 끝내면 알려 드려요'**
  String get notificationOffNoticeBody;

  /// 설정의 알림 설정 줄 오른쪽 값 (기기 알림이 꺼졌을 때)
  ///
  /// In ko, this message translates to:
  /// **'꺼짐'**
  String get notificationOffValue;

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

  /// 이룸이 기기가 연결된 날. 예: 9월 18일부터
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

  /// creditResetFallback 의 월 단위 크레딧 문구
  ///
  /// In ko, this message translates to:
  /// **'다음 달 1일 0시'**
  String get creditResetFallbackMonth;

  /// AI 일과를 만드는 중에 새로 만들려 할 때의 팝업 문장
  ///
  /// In ko, this message translates to:
  /// **'이미 일과를 만들고 있어요.\n다 만든 뒤에 새 일과를 만들 수 있어요'**
  String get creditBlockedBusy;

  /// 광고 시청 뒤 크레딧을 받았다는 팝업 제목. count 는 받은 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{크레딧 {count}개를 받았어요}}'**
  String creditReceivedTitle(int count);

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
  /// **'크레딧 확인이 늦어지고 있어요.\n광고는 다시 안 봐도 돼요. 내 정보 → 내 크레딧 보기에서 확인해 주세요'**
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
  /// **'지금 점검 중이에요'**
  String get appStatusMaintenanceTitle;

  /// 점검 중 화면의 기본 설명(서버가 문구를 주면 그것이 이긴다)
  ///
  /// In ko, this message translates to:
  /// **'점검이 끝나면 다시 쓸 수 있어요.\n조금 뒤에 확인해주세요'**
  String get appStatusMaintenanceBody;

  /// 점검 화면의 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 확인하기'**
  String get appStatusRecheck;

  /// 강제 업데이트 카드의 문구 (두 줄)
  ///
  /// In ko, this message translates to:
  /// **'지금 업데이트하고\n새로워진 이룸을 이용해보세요!'**
  String get appStatusUpdateTitle;

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
  /// **'이 기기는 누가\n사용하나요?'**
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

  /// 카드 그림 방식 이름 (Free, Twemoji)
  ///
  /// In ko, this message translates to:
  /// **'이모지 그림'**
  String get imageStyleEmojiLabel;

  /// 카드 그림 방식 설명
  ///
  /// In ko, this message translates to:
  /// **'귀여운 이모지로 물건을 보여줘요'**
  String get imageStyleEmojiDescription;

  /// 카드 그림 방식 이름 (Free, Mulberry 그림 기호)
  ///
  /// In ko, this message translates to:
  /// **'그림 기호'**
  String get imageStyleSymbolLabel;

  /// 카드 그림 방식 설명
  ///
  /// In ko, this message translates to:
  /// **'하는 동작을 선 그림으로 보여줘요'**
  String get imageStyleSymbolDescription;

  /// 카드 그림 방식 이름 (Pro, AI 만화 그림)
  ///
  /// In ko, this message translates to:
  /// **'만화 그림'**
  String get imageStyleCharacterLabel;

  /// 카드 그림 방식 설명
  ///
  /// In ko, this message translates to:
  /// **'만화 속 아이가 직접 해 보여요'**
  String get imageStyleCharacterDescription;

  /// 카드 그림 방식 이름 (Pro, AI 실사 그림)
  ///
  /// In ko, this message translates to:
  /// **'사진 같은 그림'**
  String get imageStyleRealisticLabel;

  /// 카드 그림 방식 설명
  ///
  /// In ko, this message translates to:
  /// **'실제 물건처럼 보여요'**
  String get imageStyleRealisticDescription;

  /// 그림 방식 목록 위 크레딧 띠의 왼쪽 이름
  ///
  /// In ko, this message translates to:
  /// **'크레딧'**
  String get imageStyleCreditLabel;

  /// 크레딧 띠 — 일과 하나를 만들 때 드는 크레딧. count 는 서버 단가
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{일과 하나에 {count}개}}'**
  String imageStyleCreditRoutine(int count);

  /// 크레딧 띠 — 요금제 혜택으로 일과 글 몫에 크레딧이 들지 않을 때 (그림 한 장 단가는 따로 보임)
  ///
  /// In ko, this message translates to:
  /// **'일과 글은 크레딧 없이'**
  String get imageStyleCreditRoutineFree;

  /// 크레딧 띠 — 만화·실사에서 카드 그림 한 장마다 더 드는 크레딧. count 는 서버 단가
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{그림 한 장에 {count}개}}'**
  String imageStyleCreditImage(int count);

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
  /// **'선택한 친구가 홈과 보상 화면에서 함께해요'**
  String get onboardingCharacterDescription;

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

  /// 그림 방식 화면 크레딧 띠 아래 첫 설명 (주 단위). count 는 서버 지급량
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{크레딧은 매주 {count}개 받아요. 일과와 그림을 만들 때 써요}}'**
  String onboardingImageStyleCreditIntroWeek(int count);

  /// 그림 방식 화면 크레딧 띠 아래 첫 설명 (달 단위). count 는 서버 지급량
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{크레딧은 매달 {count}개 받아요. 일과와 그림을 만들 때 써요}}'**
  String onboardingImageStyleCreditIntroMonth(int count);

  /// 그림 방식 화면 크레딧 띠 아래 첫 설명 (지급량을 모를 때)
  ///
  /// In ko, this message translates to:
  /// **'크레딧은 일과와 그림을 만들 때 써요'**
  String get onboardingImageStyleCreditIntro;

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

  /// 온보딩 저장 실패 시 서버가 문구를 못 줄 때의 기본 안내 (화면에 남아 시작하기로 다시 보냄)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 시작하기를 다시 눌러주세요'**
  String get pinSaveFailedFallback;

  /// 이룸이 기기 설정 페이지 제목
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get elumiSettingsTitle;

  /// 이룸이 설정의 카드 체크 진동 스위치 줄
  ///
  /// In ko, this message translates to:
  /// **'카드 체크 진동'**
  String get elumiSettingsHapticLabel;

  /// 이룸이 설정의 칭찬 소리 스위치 줄 — 카드를 체크하면 효과음과 '잘했어요!' 음성이 나온다 (#777)
  ///
  /// In ko, this message translates to:
  /// **'카드 체크 칭찬 소리'**
  String get elumiSettingsPraiseSoundLabel;

  /// 이룸이 설정의 스위치 줄 — 일과 진행(카드) 화면이 떠 있는 동안 기기 화면이 꺼지지 않게 한다 (#970)
  ///
  /// In ko, this message translates to:
  /// **'카드 볼 때 화면 켜 두기'**
  String get elumiSettingsScreenAwakeLabel;

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
  /// **'로그아웃할까요?'**
  String get elumiSettingsLogoutTitle;

  /// 로그아웃 확인 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'이 기기의 연결이 끊어져요\n다시 쓰려면 보호자에게\n연결 코드를 받아야 해요'**
  String get elumiSettingsLogoutMessage;

  /// 로그아웃 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'로그아웃하지 못했어요'**
  String get elumiSettingsLogoutFailTitle;

  /// 회원탈퇴 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴할까요?'**
  String get elumiSettingsWithdrawTitle;

  /// 회원탈퇴 확인 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'이 기기의 연결만 끊어져요\n일과와 별은 보호자 기기에 남고\n다시 쓰려면 보호자에게\n연결 코드를 받아야 해요'**
  String get elumiSettingsWithdrawMessage;

  /// 이룸이 화면 회원탈퇴 확인 팝업의 위험 버튼 (행동 이름, #1171)
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하기'**
  String get elumiSettingsWithdrawAction;

  /// 이룸이 전용 기기에서 초대 링크를 열었을 때의 토스트
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서는 초대를 받을 수 없어요\n보호자 기기에서 열어주세요'**
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

  /// 보호자 설정의 이룸이 기기 연결 상태 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기'**
  String get linkStatusTitle;

  /// 연결 끊기 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'연결을 끊을까요?'**
  String get linkStatusRevokeConfirmTitle;

  /// 연결 끊기 확인 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기에서 일과를 볼 수 없어요\n다시 연결하려면 새 코드를 만들면 돼요'**
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

  /// 연결된 기기가 여러 대일 때 붙이는 번호 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기 {number}'**
  String linkDeviceNumbered(int number);

  /// 연결된 기기의 상태 글자
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get linkStatusConnected;

  /// 연결된 기기 카드의 연결 끊기 버튼
  ///
  /// In ko, this message translates to:
  /// **'연결 끊기'**
  String get linkStatusRevokeButton;

  /// 연결 끊기 버튼 아래 안내
  ///
  /// In ko, this message translates to:
  /// **'끊으면 이룸이 기기에서\n일과를 볼 수 없어요'**
  String get linkStatusRevokeHint;

  /// 연결된 기기가 하나도 없을 때
  ///
  /// In ko, this message translates to:
  /// **'연결된 기기가 없어요'**
  String get linkStatusEmpty;

  /// 연결된 기기를 누가 연결했는지. name 은 연결 암호를 만든 보호자가 이 이룸이 안에서 불리는 이름(없으면 '보호자'). batchim 은 한국어 조사 선택용이라 다른 언어는 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'{name}{batchim, select, yes{이} other{가}} 연결'**
  String linkStatusConnectedBy(String name, String batchim);

  /// 내가 만든 연결 암호로 붙은 기기
  ///
  /// In ko, this message translates to:
  /// **'내가 연결'**
  String get linkStatusConnectedByMe;

  /// 연결한 사람과 연결 날짜를 한 줄로 잇는다. 예: 김선생님이 연결 · 10월 13일부터
  ///
  /// In ko, this message translates to:
  /// **'{by} · {since}'**
  String linkStatusConnectedByAndSince(String by, String since);

  /// 연결된 기기가 있어도 목록 아래에서 연결 암호 만들기로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'+ 다른 기기 연결하기'**
  String get linkStatusAddAction;

  /// 연결 없음 상태에서 연결 암호 만들기로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기 연결하기'**
  String get linkStatusConnectAction;

  /// 설정에서 연 연결 암호 화면의 제목
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기 연결'**
  String get linkCodeSettingsTitle;

  /// 보호자 기기의 연결 암호 화면 제목. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}의 기기를\n연결할까요?'**
  String linkCodeAskTitle(String name);

  /// 연결 암호 화면의 설명. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}의 기기에서 아래 코드를 입력하세요'**
  String linkCodeEnterHint(String name);

  /// 연결 코드 발급 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'코드를 만들지 못했어요. 다시 해주세요'**
  String get linkCodeIssueFailedFallback;

  /// 이룸이 기기가 연결됐을 때 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'기기 연결에 성공했어요!'**
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

  /// 연결 암호 남은 시간(09:59) 오른쪽에 붙는 안내
  ///
  /// In ko, this message translates to:
  /// **'뒤에 코드가 바뀌어요'**
  String get linkCodeChangesAfter;

  /// 연결 암호 화면의 다시 만들기 칩(시안 그대로)
  ///
  /// In ko, this message translates to:
  /// **'코드 다시 만들기'**
  String get linkRetryChipLabel;

  /// 이룸이 기기의 코드 입력 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'보호자에게서 받은 코드를\n입력해주세요'**
  String get linkEnterTitle;

  /// 이룸이 기기의 코드 입력 안내. linkEnterGuidePath 를 문장 안에 그대로 포함해야 밑줄이 그려진다
  ///
  /// In ko, this message translates to:
  /// **'코드는 보호자 기기의 이 자리에 있어요\n내 정보 → 톱니바퀴 → 이룸이 기기 연결하기'**
  String get linkEnterGuide;

  /// linkEnterGuide 안에서 밑줄을 그을 부분. 안내문에 똑같이 들어 있어야 한다
  ///
  /// In ko, this message translates to:
  /// **'내 정보 → 톱니바퀴 → 이룸이 기기 연결하기'**
  String get linkEnterGuidePath;

  /// 연결이 밖에서 끊겨 코드 입력 화면으로 돌아왔을 때 설명(다음 행동 포함)
  ///
  /// In ko, this message translates to:
  /// **'연결이 끊어졌어요\n보호자에게 새 연결 코드를 받아 입력해주세요'**
  String get linkEnterLinkLost;

  /// 코드 입력 화면의 시작 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get linkEnterStartButton;

  /// 여섯 칸 입력 영역을 화면 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'연결 코드 넣기'**
  String get linkEnterInputLabel;

  /// 연결 코드 입력 실패(모양이 틀리거나 없는 코드)
  ///
  /// In ko, this message translates to:
  /// **'코드가 맞지 않아요'**
  String get linkEnterWrongCode;

  /// 연결 코드가 만료됐을 때
  ///
  /// In ko, this message translates to:
  /// **'코드가 만료됐어요. 새 코드를 받아주세요'**
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
  /// **'선생님'**
  String get guardianKindCaregiver;

  /// 초대 링크를 메신저로 보낼 때의 글. 보내는 사람의 앱 언어로 만들어진다. url 은 링크(번역하지 않는다), code 는 3-3 으로 끊은 초대 코드
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n초대 코드는 {minutes, plural, other{{minutes}분}} 동안만 쓸 수 있어요.\n\n{url}\n\n링크가 열리지 않으면 앱에서 직접 넣어주세요.\n초대 코드 {code}'**
  String inviteShareMessage(int minutes, String url, String code);

  /// 내 이름·구분 변경 시트의 제목
  ///
  /// In ko, this message translates to:
  /// **'내 이름 변경하기'**
  String get guardiansEditTitle;

  /// 내 이름 변경 시트의 설명
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 함께 돌보는 사람에게 보이는 이름이에요.\n실명이 아니어도 괜찮아요'**
  String get guardiansEditDescription;

  /// 내 이름 입력칸의 예시 글
  ///
  /// In ko, this message translates to:
  /// **'엄마, 아빠, 선생님'**
  String get guardiansEditNameHint;

  /// 내 이름 변경 시트의 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
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
  /// **'내가 연결한 이룸이 기기가 있다면 연결이 끊어져요\n남은 보호자가 새 연결 코드를 만들어야 다시 쓸 수 있어요\n내가 만든 일과는 사라져요\n이룸이와 다른 보호자의 일과·별은 그대로예요'**
  String get guardiansLeaveConfirmMessageOthers;

  /// 함께 돌보기 그만두기 확인 팝업의 위험 버튼
  ///
  /// In ko, this message translates to:
  /// **'그만두기'**
  String get guardiansLeaveConfirmAction;

  /// 마지막 보호자가 그만둘 때 둘째 단계(글자 입력 확인) 팝업 제목. 시안 없는 임시 배치
  ///
  /// In ko, this message translates to:
  /// **'한 번 더 확인할게요'**
  String get guardiansLeaveTypeTitle;

  /// 마지막 보호자가 그만둘 때 둘째 단계 안내. phrase 는 guardiansLeaveTypePhrase
  ///
  /// In ko, this message translates to:
  /// **'이룸이와 일과, 별이 모두 사라져요\n아래 칸에 \'{phrase}\'라고\n똑같이 입력해 주세요'**
  String guardiansLeaveTypeMessage(String phrase);

  /// 마지막 보호자가 그만둘 때 입력해야 하는 문구. 비교 원본이자 입력칸 안내 글 — 번역하면 그 언어 문구를 입력함
  ///
  /// In ko, this message translates to:
  /// **'그만두기'**
  String get guardiansLeaveTypePhrase;

  /// 마지막 보호자 그만두기 둘째 단계 실행 버튼. 문구가 맞을 때만 켜짐
  ///
  /// In ko, this message translates to:
  /// **'그만두기'**
  String get guardiansLeaveTypeAction;

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

  /// 함께하는 사람 목록 머리 설명
  ///
  /// In ko, this message translates to:
  /// **'일과를 같이 만드는 가족이나 선생님이에요'**
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
  /// **'내가 만든 일과만 사라져요'**
  String get guardiansLeaveHintWithOthers;

  /// 내가 만든 초대 코드로 다른 보호자가 합류했을 때 팝업 제목. name 은 합류한 사람 이름(없으면 기본 호칭)
  ///
  /// In ko, this message translates to:
  /// **'{name}님이 함께하게 됐어요'**
  String inviteCodeGuestJoinedTitle(String name);

  /// 목록에서 내 줄에 붙는 작은 표시
  ///
  /// In ko, this message translates to:
  /// **'나'**
  String get guardiansMeBadge;

  /// 함께하는 사람 목록 묶음 위 제목. count 는 나를 포함한 사람 수
  ///
  /// In ko, this message translates to:
  /// **'함께 돌보는 사람 {count}명'**
  String guardiansPeopleHeader(int count);

  /// 초대하기·초대 코드 넣기 묶음 위 제목
  ///
  /// In ko, this message translates to:
  /// **'초대'**
  String get guardiansInviteHeader;

  /// 내 줄 오른쪽 버튼. 누르면 내 이름·구분을 변경하는 시트가 열린다
  ///
  /// In ko, this message translates to:
  /// **'이름 변경'**
  String get guardiansRenameAction;

  /// 초대 링크 공유 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'링크를 보내지 못했어요'**
  String get inviteCodeShareFailTitle;

  /// 초대 링크 공유 실패 시 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'코드를 직접 알려주세요'**
  String get inviteCodeShareFailFallback;

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
  /// **'코드를 받은 분이 {name}{batchim, select, yes{을} other{를}} 함께 돌봐요'**
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

  /// 이룸이 기기에서 합류하려 할 때 서버가 문구를 못 줄 때의 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기에서는 할 수 없어요'**
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

  /// 초대 코드 넣기 하단 버튼(여섯 칸을 채워야 켜짐, 링크로 받은 코드도 같은 버튼)
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get inviteEnterStartButton;

  /// 링크로 받은 코드를 거두고 직접 입력으로 바꾸는 밑줄 글
  ///
  /// In ko, this message translates to:
  /// **'다른 코드 넣기'**
  String get inviteEnterManualLink;

  /// 초대 코드 넣기 화면의 머리 제목
  ///
  /// In ko, this message translates to:
  /// **'초대 코드를\n입력해주세요'**
  String get inviteEnterTitle;

  /// 링크로 받은 코드가 채워졌을 때의 설명
  ///
  /// In ko, this message translates to:
  /// **'링크로 받은 초대 코드예요. 맞으면 시작하기를 눌러주세요'**
  String get inviteEnterDescriptionFromLink;

  /// 직접 입력할 때의 설명(코드를 받는 길)
  ///
  /// In ko, this message translates to:
  /// **'코드는 함께하는 보호자 기기의\n내정보 → 함께하는 사람에 있어요'**
  String get inviteEnterDescriptionManual;

  /// 직접 입력 설명(inviteEnterDescriptionManual) 안에서 밑줄을 긋는 길 안내. 설명 문구에 그대로 들어 있어야 함
  ///
  /// In ko, this message translates to:
  /// **'내정보 → 함께하는 사람'**
  String get inviteEnterDescriptionPath;

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

  /// 보호자 홈 종 아이콘 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get notificationBellLabel;

  /// 종 아이콘에 빨간 점이 있을 때 낭독 이름에 덧붙이는 말
  ///
  /// In ko, this message translates to:
  /// **'읽지 않은 알림이 있어요'**
  String get notificationBellUnreadLabel;

  /// 알림 화면 제목과 첫 번째 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get notificationTabNotifications;

  /// 알림 화면 두 번째 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'공지사항'**
  String get notificationTabNotices;

  /// 알림 목록 날짜 묶음 머리글: 오늘
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get notificationDayToday;

  /// 알림 목록 날짜 묶음 머리글: 어제
  ///
  /// In ko, this message translates to:
  /// **'어제'**
  String get notificationDayYesterday;

  /// 알림 목록 날짜 묶음 머리글: 어제보다 오래된 것
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get notificationDayEarlier;

  /// 알림 목록의 전체 읽음 처리 버튼
  ///
  /// In ko, this message translates to:
  /// **'모두 읽음'**
  String get notificationMarkAllRead;

  /// 알림이 하나도 없을 때의 문구
  ///
  /// In ko, this message translates to:
  /// **'아직 받은 알림이 없어요'**
  String get notificationEmpty;

  /// 알림 화면 공지사항 탭에 공지가 하나도 없을 때의 문구
  ///
  /// In ko, this message translates to:
  /// **'아직 올라온 공지가 없어요'**
  String get notificationNoticeEmpty;

  /// 공지사항 탭 목록을 받지 못했을 때의 문구
  ///
  /// In ko, this message translates to:
  /// **'공지를 불러오지 못했어요'**
  String get notificationNoticeFailed;

  /// 알림 설정 화면 제목과 보호자 설정의 진입 줄
  ///
  /// In ko, this message translates to:
  /// **'알림 설정'**
  String get notificationSettingsTitle;

  /// 알림 설정: 전체 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'모든 알림 받기'**
  String get notificationSettingAll;

  /// 알림 설정: 일과 완료 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 일과를 끝냈을 때'**
  String get notificationSettingRoutineCompleted;

  /// 알림 설정: 일과 전송 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'다른 보호자가 일과를 보냈을 때'**
  String get notificationSettingRoutineSent;

  /// 알림 설정: 보호자 합류 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'새 보호자가 함께할 때'**
  String get notificationSettingCoGuardianJoined;

  /// 알림 설정: 크레딧 충전 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'이번 주 크레딧이 채워졌을 때'**
  String get notificationSettingCreditRefilled;

  /// 알림 설정: 의견 처리 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'의견을 처리했을 때'**
  String get notificationSettingFeedbackResolved;

  /// 알림 설정: 이야기 글 댓글 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'이야기: 내 글에 댓글이 달렸을 때'**
  String get notificationSettingTalkCommented;

  /// 알림 설정: 이야기 글 가져감 푸시 스위치
  ///
  /// In ko, this message translates to:
  /// **'이야기: 내 글을 가져갔을 때'**
  String get notificationSettingTalkImported;

  /// 알림 설정 맨 위 안내: 기기 알림 권한이 꺼짐
  ///
  /// In ko, this message translates to:
  /// **'기기 알림이 꺼져 있어요'**
  String get notificationPermissionOff;

  /// 기기 알림 꺼짐 안내 띠의 버튼 (안 물었으면 권한 창, 거부했으면 기기 설정)
  ///
  /// In ko, this message translates to:
  /// **'켜기'**
  String get notificationTurnOnDeviceNotification;

  /// 알림 설정 저장 실패 팝업 문구
  ///
  /// In ko, this message translates to:
  /// **'설정을 저장하지 못했어요'**
  String get notificationSettingSaveFailed;

  /// 알림 설정 불러오기 실패 문구
  ///
  /// In ko, this message translates to:
  /// **'설정을 불러오지 못했어요'**
  String get notificationSettingLoadFailed;

  /// 알림 목록을 받지 못했을 때의 문구
  ///
  /// In ko, this message translates to:
  /// **'알림을 불러오지 못했어요'**
  String get notificationListFailed;

  /// 알림이 가리키는 이룸이가 내 목록에 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'이 이룸이의 알림은 더 볼 수 없어요'**
  String get notificationProfileUnavailable;

  /// 알림 줄: 이룸이가 일과 하나를 끝냄. title 은 일과 제목
  ///
  /// In ko, this message translates to:
  /// **'\'{title}\' 일과를 끝냈어요'**
  String notificationRoutineCompletedOne(String title);

  /// 알림 줄: 이룸이가 하루에 일과 여러 개를 끝냄(묶음). count 는 개수
  ///
  /// In ko, this message translates to:
  /// **'일과 {count}개를 끝냈어요'**
  String notificationRoutineCompletedMany(int count);

  /// 알림 줄: 일과를 끝냄(제목을 모를 때)
  ///
  /// In ko, this message translates to:
  /// **'일과를 끝냈어요'**
  String get notificationRoutineCompletedNoTitle;

  /// 알림 줄: 다른 보호자가 일과를 보냄. title 은 일과 제목
  ///
  /// In ko, this message translates to:
  /// **'함께하는 보호자가 \'{title}\' 일과를 보냈어요'**
  String notificationRoutineSent(String title);

  /// 알림 줄: 다른 보호자가 일과를 보냄(제목을 모를 때)
  ///
  /// In ko, this message translates to:
  /// **'함께하는 보호자가 새 일과를 보냈어요'**
  String get notificationRoutineSentNoTitle;

  /// 알림 줄: 새 보호자가 합류함
  ///
  /// In ko, this message translates to:
  /// **'새 보호자가 함께하기 시작했어요'**
  String get notificationCoGuardianJoined;

  /// 알림 줄: 주간 크레딧이 다시 채워짐
  ///
  /// In ko, this message translates to:
  /// **'이번 주 크레딧이 채워졌어요'**
  String get notificationCreditRefilled;

  /// 알림 줄: 보낸 의견이 처리됨
  ///
  /// In ko, this message translates to:
  /// **'보내 주신 의견을 확인하고 처리했어요'**
  String get notificationFeedbackResolved;

  /// 알림 줄: 내 이야기 글에 댓글이 달림(묶음). count 는 댓글 수
  ///
  /// In ko, this message translates to:
  /// **'내 글에 댓글이 {count}개 달렸어요'**
  String notificationTalkPostCommented(int count);

  /// 알림 줄: 내 이야기 글을 다른 보호자가 가져감(묶음). count 는 가져간 사람 수
  ///
  /// In ko, this message translates to:
  /// **'보호자 {count}명이 내 글의 일과를 가져갔어요'**
  String notificationTalkPostImported(int count);

  /// 알림 줄: 월요일마다 오는 주간 리포트
  ///
  /// In ko, this message translates to:
  /// **'지난주 리포트가 도착했어요'**
  String get notificationWeeklyReportReady;

  /// 알림 줄: 운영자 알림의 제목을 못 받았을 때 (#1273)
  ///
  /// In ko, this message translates to:
  /// **'이룸에서 알려 드려요'**
  String get notificationAdminMessageFallback;

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

  /// 입력에 이룸이가 할 행동이 없어 카드 0장일 때의 안내 제목
  ///
  /// In ko, this message translates to:
  /// **'어떤 일과인지 알려 주세요'**
  String get routineLoadingInputNeededTitle;

  /// 카드 0장 안내에서 입력 화면으로 돌아가는 버튼. 적은 글은 그대로 남는다
  ///
  /// In ko, this message translates to:
  /// **'다시 적기'**
  String get routineLoadingEditInput;

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
  /// **'임시저장 지우기'**
  String get draftRoutinesDeleteLabel;

  /// 임시저장 삭제 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장을 지울까요?'**
  String get draftRoutinesDeleteConfirmTitle;

  /// 임시저장 삭제 확인 팝업의 삭제 버튼
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get draftRoutinesDeleteAction;

  /// 임시저장 삭제 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장을 지우지 못했어요'**
  String get draftRoutinesDeleteFailedTitle;

  /// 임시저장 삭제 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get draftRoutinesDeleteFailedFallback;

  /// 보상을 안 정한 임시저장 줄의 보상 자리 글. `완료 시` 말머리 없이 이 글만 보인다
  ///
  /// In ko, this message translates to:
  /// **'보상 아직 안 정했어요'**
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
  /// **'카드를 지울까요?'**
  String get cardReviewDeleteConfirmTitle;

  /// 카드 삭제 확인 팝업의 삭제 버튼
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get cardReviewDeleteAction;

  /// 카드 소리 재생 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'소리를 재생하지 못했어요'**
  String get cardReviewSoundFailedTitle;

  /// 카드 소리 재생 실패 팝업 안내
  ///
  /// In ko, this message translates to:
  /// **'기기 소리를 켜고 다시 눌러주세요'**
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

  /// 직접 추가한 카드의 그림을 서버가 그리는 동안 그림칸에 뜨는 안내
  ///
  /// In ko, this message translates to:
  /// **'그림을 만들고 있어요'**
  String get cardImageGeneratingLabel;

  /// 카드 추가 때 크레딧이 모자라 AI 그림 대신 그림 기호를 넣었을 때 아래 토스트
  ///
  /// In ko, this message translates to:
  /// **'크레딧이 모자라 기본 그림을 넣었어요. 이 카드 수정에서 AI 그림을 그릴 수 있어요'**
  String get cardImageNoCreditToast;

  /// 카드 추가 때 AI 그림을 만들지 못해 그림 기호로 남았을 때 아래 토스트
  ///
  /// In ko, this message translates to:
  /// **'그림을 만들지 못해 기본 그림을 넣었어요'**
  String get cardImageUnavailableToast;

  /// 일과 만들기에서 AI 그림 일부를 못 그려 그림 기호로 둔 뒤 카드확인에 들어설 때 한 번 뜨는 토스트 (#1178). '이 카드 수정' = cardReviewToolEdit, 'AI 그림 그리기' = cardFirstDrawChip. 처음 그리기는 크레딧을 써서 무료라고 쓰지 않음
  ///
  /// In ko, this message translates to:
  /// **'그림을 만들지 못한 카드는 기본 그림으로 넣었어요. 이 카드 수정에서 AI 그림을 그릴 수 있어요'**
  String get cardImageMissingAfterCreateToast;

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
  /// **'로그아웃할까요?'**
  String get guardianSettingsLogoutConfirmTitle;

  /// 회원탈퇴 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴할까요?'**
  String get guardianSettingsWithdrawConfirmTitle;

  /// 회원탈퇴 확인 팝업의 되돌릴 수 없다는 고지
  ///
  /// In ko, this message translates to:
  /// **'만든 일과와 모은 별이 모두 사라져요\n다시 로그인해도 되돌릴 수 없어요'**
  String get guardianSettingsWithdrawConfirmMessage;

  /// 회원탈퇴 1단계 경고 팝업의 위험 버튼 (행동 이름, #1171)
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하기'**
  String get guardianSettingsWithdrawConfirmAction;

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

  /// 회원탈퇴 확인 팝업에 덧붙이는 줄. App Store 결제 Pro 가 자동 갱신 중일 때만 보임 — Apple 은 서버가 구독을 해지할 수 없음 (#1155)
  ///
  /// In ko, this message translates to:
  /// **'Pro 구독은 탈퇴해도 이어져요\n앱스토어에서\n직접 해지해 주세요'**
  String get guardianSettingsWithdrawAppStoreSubscriptionNotice;

  /// 회원탈퇴 확인 팝업에 덧붙이는 줄. Google Play 결제 Pro 가 자동 갱신 중일 때만 보임 — 탈퇴하면 서버가 자동 갱신을 해지함 (#1158)
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하면 플레이스토어 Pro 구독의\n다음 결제를 멈춰요'**
  String get guardianSettingsWithdrawGooglePlaySubscriptionNotice;

  /// 회원탈퇴 둘째 단계(글자 입력 확인) 팝업 제목. 시안 없는 임시 배치 (#1155)
  ///
  /// In ko, this message translates to:
  /// **'한 번 더 확인할게요'**
  String get guardianSettingsWithdrawTypeTitle;

  /// 회원탈퇴 둘째 단계 안내. phrase 는 guardianSettingsWithdrawTypePhrase (#1155)
  ///
  /// In ko, this message translates to:
  /// **'아래 칸에 \'{phrase}\'라고\n똑같이 입력해 주세요'**
  String guardianSettingsWithdrawTypeMessage(String phrase);

  /// 회원탈퇴 둘째 단계에서 입력해야 하는 문구. 비교 원본이자 입력칸 안내 글 — 번역하면 그 언어 문구를 입력함 (#1155)
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴'**
  String get guardianSettingsWithdrawTypePhrase;

  /// 회원탈퇴 둘째 단계 실행 버튼. 문구가 맞을 때만 켜짐 (#1155)
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하기'**
  String get guardianSettingsWithdrawTypeAction;

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

  /// 설정 줄 — 의견 보내기 화면으로 간다
  ///
  /// In ko, this message translates to:
  /// **'의견 보내기'**
  String get guardianSettingsFeedback;

  /// 의견 보내기 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'의견 보내기'**
  String get feedbackTitle;

  /// 의견 입력창 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'불편했던 점을 편하게 적어 주세요'**
  String get feedbackHint;

  /// 의견과 함께 최근 앱 상태 기록을 보낼지 고르는 체크 문구
  ///
  /// In ko, this message translates to:
  /// **'앱 상태 기록과 기기 정보 보내기'**
  String get feedbackIncludeLog;

  /// 의견 보내기 버튼
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get feedbackSend;

  /// 의견을 보낸 뒤 잠깐 뜨는 알림
  ///
  /// In ko, this message translates to:
  /// **'의견을 보냈어요'**
  String get feedbackSent;

  /// 의견 보내기 실패 팝업의 제목
  ///
  /// In ko, this message translates to:
  /// **'의견을 보내지 못했어요'**
  String get feedbackFailedTitle;

  /// 의견 보내기 실패 팝업의 할 일 안내(서버가 이유를 주지 않았을 때)
  ///
  /// In ko, this message translates to:
  /// **'적은 글은 그대로 있어요. 잠시 후 다시 보내 주세요'**
  String get feedbackFailedFallback;

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

  /// 설정 줄 — 이룸이 기기가 이미 연결됐을 때
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기'**
  String get guardianSettingsLinkConnected;

  /// 설정 줄 — 이룸이 기기를 아직 연결하지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기 연결하기'**
  String get guardianSettingsLinkConnect;

  /// 설정 줄 — 이룸이 기기 연결 상태 값
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

  /// 설정 줄 — 이룸이가 카드를 체크할 때 효과음과 칭찬 음성 켜기/끄기 (#777)
  ///
  /// In ko, this message translates to:
  /// **'카드 체크 칭찬 소리'**
  String get guardianSettingsPraiseSound;

  /// 설정 줄 — 이룸이 일과 진행(카드) 화면이 떠 있는 동안 기기 화면 꺼짐 막기 켜기/끄기 (#970)
  ///
  /// In ko, this message translates to:
  /// **'카드 볼 때 화면 켜 두기'**
  String get guardianSettingsScreenAwake;

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
  /// **'카드를 길게 눌러 순서를 바꿀 수 있어요'**
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
  /// **'기기 소리를 켜고 다시 눌러주세요'**
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

  /// 사진 권한 안내 화면의 기기 설정 열기 버튼
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
  /// **'기기 설정에서 카메라를 켜면 사진을 찍을 수 있어요'**
  String get cardPhotoPermissionCameraBody;

  /// 사진 접근 권한이 막혔을 때 사진 권한 안내 설명
  ///
  /// In ko, this message translates to:
  /// **'기기 설정에서 사진 접근을 켜면 고를 수 있어요'**
  String get cardPhotoPermissionGalleryBody;

  /// 사진 권한 안내에서 기기 설정을 못 열었을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'설정을 열지 못했어요'**
  String get cardPhotoSettingsFailedTitle;

  /// 사진 권한 안내에서 기기 설정을 못 열었을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'기기 설정에서 직접 켜 주세요'**
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

  /// creditCardTitle 의 월 단위 크레딧 문구
  ///
  /// In ko, this message translates to:
  /// **'이번 달 AI 생성'**
  String get creditCardTitleMonth;

  /// AI 크레딧 카드가 불러오는 중일 때 낭독 문구
  ///
  /// In ko, this message translates to:
  /// **'이번 주 AI 생성 사용량을 불러오고 있어요'**
  String get creditCardLoading;

  /// creditCardLoading 의 월 단위 크레딧 문구
  ///
  /// In ko, this message translates to:
  /// **'이번 달 AI 생성 사용량을 불러오고 있어요'**
  String get creditCardLoadingMonth;

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

  /// creditExhausted 의 월 단위 크레딧 문구
  ///
  /// In ko, this message translates to:
  /// **'이번 달 크레딧을 모두 사용했어요'**
  String get creditExhaustedMonth;

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

  /// 보호자 홈의 새 일과 만들기 버튼
  ///
  /// In ko, this message translates to:
  /// **'새로운 일과 만들기'**
  String get routineCreateButton;

  /// 일과 줄을 밀었을 때 나오는 삭제 버튼 기본 글자
  ///
  /// In ko, this message translates to:
  /// **'일과 지우기'**
  String get routineSwipeDelete;

  /// 일과 줄을 밀었을 때 나오는 수정 버튼
  ///
  /// In ko, this message translates to:
  /// **'일과 수정'**
  String get routineSwipeEdit;

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
  /// **'카드가 다 만들어지면 임시저장에 남아요\n내정보에서 이어서 만들 수 있어요'**
  String get routineLeaveDraftWhenReadyMessage;

  /// 카드 검토 화면에서 나가는 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'임시저장에 두고 나갈까요?'**
  String get routineLeaveDraftTitle;

  /// 카드 검토 화면에서 나가는 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'내정보의 임시저장에서\n이어서 만들 수 있어요'**
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
  /// **'일과를 지울까요?'**
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
  /// **'지우기'**
  String get todayRoutineDeleteAction;

  /// 보호자 홈에서 일과 삭제가 실패했을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'일과를 지우지 못했어요'**
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
  /// **'일과를 *왼쪽으로 스와이프*하면\n*수정하거나 지울* 수 있어요'**
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

  /// 일과가 없을 때의 안내(이룸이 전용 기기)
  ///
  /// In ko, this message translates to:
  /// **'보호자 기기에서 일과를 만들 수 있어요'**
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
  /// **'기기 소리를 켜고 다시 눌러주세요'**
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

  /// 일과 완료 화면 제목 아래 두 줄 안내. name 은 이룸이 호칭이고 조사는 받침과 무관하게 `를`로 고정한다
  ///
  /// In ko, this message translates to:
  /// **'할 일을 모두 해낸\n{name}를 위해 준비했어요'**
  String routineDoneMessage(String name);

  /// 일과 완료 화면 하단 버튼(누르면 이룸이 홈으로)
  ///
  /// In ko, this message translates to:
  /// **'해냈어요!'**
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
  /// **'비밀암호를 입력해 주세요'**
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

  /// 암호가 없는 이룸이 기기에서 보호자 화면을 열려 할 때 제목(줄바꿈 위치 유지)
  ///
  /// In ko, this message translates to:
  /// **'보호자 기기에서\n열어 주세요'**
  String get modeSwitchBlockedTitle;

  /// 암호가 없는 이룸이 기기에서 보호자 화면을 열려 할 때 설명
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서는 보호자 화면을 열 수 없어요'**
  String get modeSwitchBlockedDescription;

  /// 보호자 화면을 열 수 없다는 안내의 하단 버튼
  ///
  /// In ko, this message translates to:
  /// **'돌아가기'**
  String get modeSwitchBlockedBack;

  /// 기기 설치 표식을 읽지 못했을 때 오류 화면 제목 (E-INSTALL)
  ///
  /// In ko, this message translates to:
  /// **'잠깐 문제가 생겼어요'**
  String get installationRetryTitle;

  /// 기기 설치 표식을 읽지 못했을 때 오류 화면 안내
  ///
  /// In ko, this message translates to:
  /// **'기기 정보를 확인하지 못했어요. 다시 해볼까요?'**
  String get installationRetryMessage;

  /// No description provided for @installationRetryButton.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get installationRetryButton;

  /// 발급된 코드를 클립보드에 복사하는 하단 보조 버튼(초대 코드·연결 코드 화면 공통)
  ///
  /// In ko, this message translates to:
  /// **'코드 복사하기'**
  String get issuedCodeCopyButton;

  /// 코드를 클립보드에 복사한 뒤 토스트
  ///
  /// In ko, this message translates to:
  /// **'코드를 복사했어요'**
  String get issuedCodeCopied;

  /// 코드·연결 암호 클립보드 복사 실패 팝업 제목(에러 코드 E-CODE-COPY 는 팝업이 붙인다)
  ///
  /// In ko, this message translates to:
  /// **'복사하지 못했어요'**
  String get issuedCodeCopyFailedTitle;

  /// 코드·연결 암호 복사 실패 팝업의 할 일 안내
  ///
  /// In ko, this message translates to:
  /// **'화면에 보이는 코드를 직접 알려주세요'**
  String get issuedCodeCopyFailedFallback;

  /// 연결 코드 링크를 메신저로 보낼 때의 글. 보내는 사람의 앱 언어로 만들어진다. url 은 링크(번역하지 않는다), code 는 3-3 으로 끊은 연결 코드
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 쓸 기기를 연결해요. 그 기기에서 아래 링크를 누르면 이룸 앱에 연결 코드가 채워져요.\n연결 코드는 {minutes, plural, other{{minutes}분}} 동안만 쓸 수 있어요.\n\n{url}\n\n링크가 열리지 않으면 앱에서 직접 넣어주세요.\n연결 코드 {code}'**
  String linkShareMessage(int minutes, String url, String code);

  /// 이미 연결된 이룸이 기기에서 연결 링크를 열었을 때 토스트
  ///
  /// In ko, this message translates to:
  /// **'이미 연결된 기기예요'**
  String get linkRejectedAlreadyLinked;

  /// 보호자 기기에서 이룸이 기기 연결 링크를 열었을 때 토스트
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기에서 열어주세요'**
  String get linkRejectedOnGuardianPhone;

  /// 내 크레딧 화면 제목 · 설정의 요금제 묶음 아래 줄 이름
  ///
  /// In ko, this message translates to:
  /// **'내 크레딧'**
  String get myCreditTitle;

  /// 내 크레딧 머리의 Free 요금제 태그 글자
  ///
  /// In ko, this message translates to:
  /// **'FREE'**
  String get planFreeBadge;

  /// 내 크레딧 위 카드 오른쪽 버튼: 크레딧 사용 내역 화면으로
  ///
  /// In ko, this message translates to:
  /// **'쓴 내역'**
  String get myCreditHistoryButton;

  /// 내 크레딧 큰 숫자 옆 단위
  ///
  /// In ko, this message translates to:
  /// **'개'**
  String get myCreditCountUnit;

  /// 내 크레딧 종류 이름: 매주 채워지는 크레딧
  ///
  /// In ko, this message translates to:
  /// **'주간'**
  String get myCreditKindPeriodicWeek;

  /// 내 크레딧 종류 이름: 매달 채워지는 크레딧
  ///
  /// In ko, this message translates to:
  /// **'월간'**
  String get myCreditKindPeriodicMonth;

  /// 내 크레딧 종류 이름: 선물 · 광고 보상 · 이벤트
  ///
  /// In ko, this message translates to:
  /// **'보너스'**
  String get myCreditKindBonus;

  /// 내 크레딧 종류 이름: 산 크레딧
  ///
  /// In ko, this message translates to:
  /// **'구매'**
  String get myCreditKindPurchased;

  /// 내 크레딧 주간 줄 끝나는 때
  ///
  /// In ko, this message translates to:
  /// **'월요일에 다시 채워져요'**
  String get myCreditRefillWeek;

  /// 내 크레딧 월간 줄 끝나는 때
  ///
  /// In ko, this message translates to:
  /// **'다음 달 1일에 다시 채워져요'**
  String get myCreditRefillMonth;

  /// 내 크레딧 보너스 줄 끝나는 때
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일까지'**
  String myCreditUntilDate(int month, int day);

  /// 내 크레딧 구매 줄 끝나는 때 (제한 없음)
  ///
  /// In ko, this message translates to:
  /// **'기간 제한 없음'**
  String get myCreditNoExpiry;

  /// 내 크레딧 구독 카드 위 작은 제목
  ///
  /// In ko, this message translates to:
  /// **'구독하면'**
  String get myCreditSubscribeLabel;

  /// 내 크레딧 구독 카드 설명 한 줄
  ///
  /// In ko, this message translates to:
  /// **'AI 그림도 그리고 일과도 알아서 보내요'**
  String get myCreditSubscribeBody;

  /// 내 크레딧 꾸러미 구역 제목 (Free: 구독 카드 아래라 크레딧만 사는 것임을 말함)
  ///
  /// In ko, this message translates to:
  /// **'크레딧만 따로 사기'**
  String get myCreditPackLabelFree;

  /// 내 크레딧 꾸러미 구역 제목 (Pro)
  ///
  /// In ko, this message translates to:
  /// **'크레딧 더 사기'**
  String get myCreditPackLabelPro;

  /// 크레딧 부족 팝업 버튼: 내 크레딧 화면의 꾸러미로
  ///
  /// In ko, this message translates to:
  /// **'크레딧 더 받기'**
  String get creditGetMore;

  /// 꾸러미 칸 오른쪽 위 할인율 알약
  ///
  /// In ko, this message translates to:
  /// **'-{percent}%'**
  String myCreditPackDiscount(int percent);

  /// 꾸러미 인기 칸 아래 걸친 알약
  ///
  /// In ko, this message translates to:
  /// **'인기!'**
  String get myCreditPackPopular;

  /// 꾸러미 결제 버튼. price 는 스토어 값
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개 사기}} ({price})'**
  String myCreditPackBuy(int count, String price);

  /// 꾸러미 구매 버튼 아래 안내
  ///
  /// In ko, this message translates to:
  /// **'구매한 크레딧은 기간 제한이 없어요'**
  String get myCreditPackNoExpiryNote;

  /// 스토어 값을 못 불러왔을 때 꾸러미 자리 문구 (에러 코드와 다시 하기가 함께 보임)
  ///
  /// In ko, this message translates to:
  /// **'크레딧 값을 불러오지 못했어요'**
  String get myCreditPackPriceFailed;

  /// 꾸러미 칸 낭독 이름. price 는 스토어 값
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{크레딧 {count}개}}, {price}'**
  String myCreditPackTileLabel(int count, String price);

  /// 결제는 됐는데 서버가 아직 크레딧을 안 넣었을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 아직 받지 못했어요'**
  String get myCreditPurchaseRecheckTitle;

  /// 크레딧 구매 확인 대기 안내
  ///
  /// In ko, this message translates to:
  /// **'결제는 끝났어요. 다시 결제하지 않고 확인만 하면 돼요'**
  String get myCreditPurchaseRecheckBody;

  /// 크레딧 사용 내역 화면의 제목 (Figma 1589:8359)
  ///
  /// In ko, this message translates to:
  /// **'크레딧 사용 내역'**
  String get creditHistoryTitle;

  /// 내 정보 크레딧 카드 맨 아래 줄: 내 크레딧 화면으로
  ///
  /// In ko, this message translates to:
  /// **'내 크레딧 보기'**
  String get creditMineLink;

  /// 사용 내역의 날짜 머리글. 예: 10월 1일
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일'**
  String creditHistoryDay(int month, int day);

  /// 사용 내역 줄의 부제: 종류와 시각. 예: 카드 그림 4장・오전 11:23
  ///
  /// In ko, this message translates to:
  /// **'{kind}・{time}'**
  String creditHistoryDetail(String kind, String time);

  /// 사용 내역 종류: AI 일과 글 만들기 (사용)
  ///
  /// In ko, this message translates to:
  /// **'일과 글 만들기'**
  String get creditHistoryKindRoutineText;

  /// 사용 내역 종류: 일과와 함께 만든 카드 그림 (사용)
  ///
  /// In ko, this message translates to:
  /// **'카드 그림 {count}장'**
  String creditHistoryKindCardImages(int count);

  /// 사용 내역 종류: 카드 한 장의 그림 직접 만들기 (사용)
  ///
  /// In ko, this message translates to:
  /// **'카드 그림 만들기'**
  String get creditHistoryKindCardImage;

  /// 사용 내역 종류: 그림 다시 만들기 (사용)
  ///
  /// In ko, this message translates to:
  /// **'카드 그림 다시 만들기'**
  String get creditHistoryKindImageRegenerate;

  /// 사용 내역 줄의 오른쪽 증감 자리 — 크레딧을 쓰지 않은 무료 다시 그리기·일과 글(요금제 혜택)
  ///
  /// In ko, this message translates to:
  /// **'크레딧 없이'**
  String get creditHistoryFree;

  /// 사용 내역 종류: 주간 지급 (Figma 1589:8444)
  ///
  /// In ko, this message translates to:
  /// **'이번 주 크레딧을 채워드렸어요'**
  String get creditHistoryKindWeeklyGrant;

  /// 사용 내역 종류: 보상형 광고 지급. 시안 없는 임시 문구(디자인 요청 #685 첫째 후보)
  ///
  /// In ko, this message translates to:
  /// **'광고를 보고 받았어요'**
  String get creditHistoryKindAdReward;

  /// 사용 내역 종류: 운영 보너스. 시안 없는 임시 문구(디자인 요청 #685 첫째 후보)
  ///
  /// In ko, this message translates to:
  /// **'운영에서 보너스를 드렸어요'**
  String get creditHistoryKindAdminBonus;

  /// 사용 내역 종류: 그 밖의 지급. 모르는 종류의 증가에도 쓴다
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 받았어요'**
  String get creditHistoryKindOtherGrant;

  /// 사용 내역 종류: 만료. 시안 없는 임시 문구(디자인 요청 #685 첫째 후보)
  ///
  /// In ko, this message translates to:
  /// **'기간이 지나 안 쓴 크레딧이 사라졌어요. 산 크레딧은 그대로예요'**
  String get creditHistoryKindExpired;

  /// 사용 내역 종류: 운영 조정. 시안 없는 임시 문구(디자인 요청 #685 첫째 후보)
  ///
  /// In ko, this message translates to:
  /// **'환불이나 운영 조정으로 크레딧이 바뀌었어요'**
  String get creditHistoryKindAdjusted;

  /// 사용 내역 종류: 앱이 모르는 종류의 감소
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 썼어요'**
  String get creditHistoryKindUnknownSpend;

  /// 사용 내역이 0건일 때. 시안 없는 임시 문구(디자인 요청 #685 첫째 후보)
  ///
  /// In ko, this message translates to:
  /// **'아직 사용한 크레딧이 없어요'**
  String get creditHistoryEmptyTitle;

  /// 사용 내역이 0건일 때 다음 행동 안내
  ///
  /// In ko, this message translates to:
  /// **'일과를 만들면 여기에 기록돼요'**
  String get creditHistoryEmptyBody;

  /// 사용 내역 조회 실패. 다시 하기 버튼과 에러 코드와 함께
  ///
  /// In ko, this message translates to:
  /// **'사용 내역을 불러오지 못했어요'**
  String get creditHistoryLoadFailed;

  /// 사용 내역 다음 쪽 조회 실패. 이미 불러온 내역은 그대로 둔다
  ///
  /// In ko, this message translates to:
  /// **'더 불러오지 못했어요'**
  String get creditHistoryMoreFailed;

  /// 일과 상세 시트의 알림 줄 읽어주기 이름 (#777)
  ///
  /// In ko, this message translates to:
  /// **'일과 알림'**
  String get reminderRowLabel;

  /// 일과 상세 시트 알림 줄 — 알림을 정하지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'알림 없음'**
  String get reminderRowOff;

  /// 일과 상세 시트 알림 줄 — 매일 반복. time 은 기기 형식 시각 (예: 오전 8:00)
  ///
  /// In ko, this message translates to:
  /// **'매일 {time}에 알려요'**
  String reminderRowDaily(String time);

  /// 일과 상세 시트 알림 줄 — 한 번만
  ///
  /// In ko, this message translates to:
  /// **'{time}에 한 번 알려요'**
  String reminderRowOnce(String time);

  /// 일과 알림 설정 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'언제 알려 드릴까요?'**
  String get reminderSheetTitle;

  /// 일과 알림 설정 시트 설명 — 알림은 설정한 기기에서만 울린다
  ///
  /// In ko, this message translates to:
  /// **'정한 시각에 이 기기로 알림이 와요'**
  String get reminderSheetBody;

  /// 일과 알림 설정 시트 — 매일 반복 스위치
  ///
  /// In ko, this message translates to:
  /// **'매일 같은 시각에 알리기'**
  String get reminderRepeatDaily;

  /// 일과 알림 설정 시트 — 처음 켤 때 버튼
  ///
  /// In ko, this message translates to:
  /// **'알림 켜기'**
  String get reminderTurnOn;

  /// 일과 알림 설정 시트 — 이미 켜져 있을 때 버튼
  ///
  /// In ko, this message translates to:
  /// **'알림 시각 바꾸기'**
  String get reminderUpdate;

  /// 일과 알림 설정 시트 — 끄기 글자 버튼
  ///
  /// In ko, this message translates to:
  /// **'알림 끄기'**
  String get reminderTurnOff;

  /// 일과 알림 저장 후 토스트
  ///
  /// In ko, this message translates to:
  /// **'알림을 맞췄어요'**
  String get reminderSavedToast;

  /// 일과 알림 끈 뒤 토스트
  ///
  /// In ko, this message translates to:
  /// **'알림을 껐어요'**
  String get reminderClearedToast;

  /// 알림 권한 거부 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'알림이 꺼져 있어요'**
  String get reminderPermissionDeniedTitle;

  /// 알림 권한 거부 팝업 본문 — 우회 경로 안내
  ///
  /// In ko, this message translates to:
  /// **'기기 설정에서 이룸 알림을 허용하면 일과 시간을 알려 드려요'**
  String get reminderPermissionDeniedBody;

  /// 일과 알림 예약 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'알림을 맞추지 못했어요'**
  String get reminderFailedTitle;

  /// 일과 알림 예약 실패 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 해 주세요'**
  String get reminderFailedBody;

  /// 안드로이드 알림 설정에 보이는 알림 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'일과 알림'**
  String get reminderChannelName;

  /// 일과 알림 제목 — 앱 이름
  ///
  /// In ko, this message translates to:
  /// **'이룸'**
  String get reminderNotificationTitle;

  /// 일과 알림 본문. routineTitle 은 일과 제목 (예: 양치하기)
  ///
  /// In ko, this message translates to:
  /// **'{routineTitle} 할 시간이에요'**
  String reminderNotificationBody(String routineTitle);

  /// 일과 만들기 화면 — 카테고리별 예시 일과 시트를 여는 버튼 (#777)
  ///
  /// In ko, this message translates to:
  /// **'예시 일과 둘러보기'**
  String get routineTemplateOpen;

  /// 일과 만들기 입력칸 아래 그림 방식 알약의 앞 글자 #1287
  ///
  /// In ko, this message translates to:
  /// **'카드 그림'**
  String get routineImageStylePillLabel;

  /// 그림 방식 알약 낭독 문구 #1287
  ///
  /// In ko, this message translates to:
  /// **'카드 그림 방식 {style}, 눌러서 바꾸기'**
  String routineImageStylePillSemantics(String style);

  /// 예시 일과 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'예시 일과'**
  String get routineTemplateSheetTitle;

  /// 예시 일과 시트 설명
  ///
  /// In ko, this message translates to:
  /// **'고르면 입력칸에 채워 드려요. 이룸이에게 맞게 고쳐서 보내세요'**
  String get routineTemplateSheetBody;

  /// 예시 일과 중 처음 써 보는 보호자에게 권하는 항목 표시
  ///
  /// In ko, this message translates to:
  /// **'처음이라면 추천'**
  String get routineTemplateBeginnerBadge;

  /// 예시 일과 카테고리 이름
  ///
  /// In ko, this message translates to:
  /// **'생활 습관'**
  String get routineTemplateCategorySelfCare;

  /// 예시 일과 카테고리 한 줄 설명
  ///
  /// In ko, this message translates to:
  /// **'양치 · 세수 · 옷 입기'**
  String get routineTemplateCategorySelfCareHint;

  /// 예시 일과 카테고리 이름
  ///
  /// In ko, this message translates to:
  /// **'하루 순서'**
  String get routineTemplateCategoryDailyFlow;

  /// 예시 일과 카테고리 한 줄 설명
  ///
  /// In ko, this message translates to:
  /// **'아침 준비 · 하교 후 · 잠자리 (여러 일을 차례로)'**
  String get routineTemplateCategoryDailyFlowHint;

  /// 예시 일과 카테고리 이름
  ///
  /// In ko, this message translates to:
  /// **'집안일'**
  String get routineTemplateCategoryHousehold;

  /// 예시 일과 카테고리 한 줄 설명
  ///
  /// In ko, this message translates to:
  /// **'방 정리 · 그릇 치우기 · 빨래 개기'**
  String get routineTemplateCategoryHouseholdHint;

  /// 예시 일과 카테고리 이름
  ///
  /// In ko, this message translates to:
  /// **'바깥 활동'**
  String get routineTemplateCategoryCommunity;

  /// 예시 일과 카테고리 한 줄 설명
  ///
  /// In ko, this message translates to:
  /// **'버스 타기 · 물건 사기 · 병원 가기'**
  String get routineTemplateCategoryCommunityHint;

  /// 예시 일과 카테고리 이름
  ///
  /// In ko, this message translates to:
  /// **'공부'**
  String get routineTemplateCategoryLearning;

  /// 예시 일과 카테고리 한 줄 설명
  ///
  /// In ko, this message translates to:
  /// **'숙제 시작 · 이름 쓰기 · 책 읽기'**
  String get routineTemplateCategoryLearningHint;

  /// 예시 일과 카테고리 이름
  ///
  /// In ko, this message translates to:
  /// **'감정·관계'**
  String get routineTemplateCategoryFeelings;

  /// 예시 일과 카테고리 한 줄 설명
  ///
  /// In ko, this message translates to:
  /// **'감정 카드 · 인사 · 차례 기다리기'**
  String get routineTemplateCategoryFeelingsHint;

  /// 예시 일과 이름 (selfCare)
  ///
  /// In ko, this message translates to:
  /// **'양치하기'**
  String get routineTemplateBrushTeethText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 혼자 양치를 해 보게 하고 싶어. 칫솔과 치약 꺼내기, 양치컵에 물 받기, 이 닦기, 헹구기, 정리하기까지 순서대로 알려 줘'**
  String get routineTemplateBrushTeethPrompt;

  /// 예시 일과 이름 (selfCare)
  ///
  /// In ko, this message translates to:
  /// **'세수하기'**
  String get routineTemplateWashFaceText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 아침에 혼자 세수를 해 보게 하고 싶어. 물 틀기, 얼굴 적시기, 비누 거품 내기, 헹구기, 수건으로 닦기, 로션 바르기까지 알려 줘'**
  String get routineTemplateWashFacePrompt;

  /// 예시 일과 이름 (selfCare)
  ///
  /// In ko, this message translates to:
  /// **'혼자 옷 입기'**
  String get routineTemplateGetDressedText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 혼자 옷을 입어 보게 하고 싶어. 러닝셔츠, 티셔츠, 바지, 양말 순서로 하나씩 입는 걸 알려 줘'**
  String get routineTemplateGetDressedPrompt;

  /// 예시 일과 이름 (selfCare)
  ///
  /// In ko, this message translates to:
  /// **'밥 먹기'**
  String get routineTemplateEatMealText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 식사 시간에 스스로 해 보게 하고 싶어. 물 마시기, 자기 수저와 그릇 가져가기, 앉아서 먹기, 다 먹은 그릇 갖다 놓기까지 알려 줘'**
  String get routineTemplateEatMealPrompt;

  /// 예시 일과 이름 (selfCare)
  ///
  /// In ko, this message translates to:
  /// **'목욕하기'**
  String get routineTemplateBathTimeText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 목욕을 순서대로 해 보게 하고 싶어. 옷 벗기, 몸에 물 적시기, 머리 감기, 몸 씻기, 헹구기, 수건으로 닦고 옷 입기까지 알려 줘'**
  String get routineTemplateBathTimePrompt;

  /// 예시 일과 이름 (dailyFlow)
  ///
  /// In ko, this message translates to:
  /// **'아침 등교 준비'**
  String get routineTemplateMorningRoutineText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 아침에 일어나서 학교 갈 때까지 할 일을 순서대로 하게 하고 싶어. 일어나기, 화장실 가기, 밥 먹기, 세수와 양치, 옷 입기, 가방 메고 신발 신기까지 알려 줘'**
  String get routineTemplateMorningRoutinePrompt;

  /// 예시 일과 이름 (dailyFlow)
  ///
  /// In ko, this message translates to:
  /// **'학교 다녀와서'**
  String get routineTemplateAfterSchoolText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 학교에서 돌아오면 스스로 할 일을 하게 하고 싶어. 신발 정리하기, 손 씻기, 가방 제자리에 두기, 간식 먹기, 쉬는 시간 갖기까지 알려 줘'**
  String get routineTemplateAfterSchoolPrompt;

  /// 예시 일과 이름 (dailyFlow)
  ///
  /// In ko, this message translates to:
  /// **'자기 전 준비'**
  String get routineTemplateBedtimeText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 잠들기 전에 할 일을 순서대로 하게 하고 싶어. 양치하기, 잠옷 입기, 내일 가방 챙기기, 불 끄고 눕기까지 알려 줘'**
  String get routineTemplateBedtimePrompt;

  /// 예시 일과 이름 (dailyFlow)
  ///
  /// In ko, this message translates to:
  /// **'외출 준비'**
  String get routineTemplateGoingOutText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 밖에 나가기 전에 스스로 준비하게 하고 싶어. 화장실 다녀오기, 겉옷 입기, 물통과 휴대폰 챙기기, 신발 신기, 문 앞에서 기다리기까지 알려 줘'**
  String get routineTemplateGoingOutPrompt;

  /// 예시 일과 이름 (household)
  ///
  /// In ko, this message translates to:
  /// **'방 정리하기'**
  String get routineTemplateTidyRoomText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 놀고 난 뒤 방을 스스로 정리하게 하고 싶어. 장난감 모으기, 상자에 넣기, 책 꽂기, 옷 걸기까지 알려 줘'**
  String get routineTemplateTidyRoomPrompt;

  /// 예시 일과 이름 (household)
  ///
  /// In ko, this message translates to:
  /// **'먹은 그릇 정리하기'**
  String get routineTemplateClearDishesText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 밥을 다 먹고 그릇을 스스로 치우게 하고 싶어. 남은 음식 모으기, 그릇 들고 가기, 싱크대에 넣기, 식탁 닦기까지 알려 줘'**
  String get routineTemplateClearDishesPrompt;

  /// 예시 일과 이름 (household)
  ///
  /// In ko, this message translates to:
  /// **'빨래 개기'**
  String get routineTemplateFoldLaundryText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 마른 빨래를 개서 정리해 보게 하고 싶어. 빨래 가져오기, 양말 짝 맞추기, 수건 접기, 옷 개기, 서랍에 넣기까지 알려 줘'**
  String get routineTemplateFoldLaundryPrompt;

  /// 예시 일과 이름 (household)
  ///
  /// In ko, this message translates to:
  /// **'쓰레기 버리기'**
  String get routineTemplateTakeOutTrashText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 쓰레기를 나눠서 버리는 걸 해 보게 하고 싶어. 쓰레기 모으기, 종이와 플라스틱 나누기, 봉투 묶기, 정해진 곳에 버리기까지 알려 줘'**
  String get routineTemplateTakeOutTrashPrompt;

  /// 예시 일과 이름 (community)
  ///
  /// In ko, this message translates to:
  /// **'버스 타기'**
  String get routineTemplateRideBusText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 혼자 버스를 타 보는 연습을 하고 싶어. 정류장에서 번호 확인하기, 줄 서기, 교통카드 찍기, 자리에 앉기, 내릴 곳에서 벨 누르기까지 알려 줘'**
  String get routineTemplateRideBusPrompt;

  /// 예시 일과 이름 (community)
  ///
  /// In ko, this message translates to:
  /// **'편의점에서 물건 사기'**
  String get routineTemplateBuyItemText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 편의점에서 혼자 물건을 사 보게 하고 싶어. 살 물건 찾기, 계산대에 줄 서기, 물건 올려놓기, 카드나 돈 내기, 영수증 받고 인사하기까지 알려 줘'**
  String get routineTemplateBuyItemPrompt;

  /// 예시 일과 이름 (community)
  ///
  /// In ko, this message translates to:
  /// **'엘리베이터로 층 찾아가기'**
  String get routineTemplateUseElevatorText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 엘리베이터를 타고 정한 층에 혼자 가 보게 하고 싶어. 버튼 누르기, 문 열리면 타기, 숫자 버튼 누르기, 층 숫자 보기, 내리기까지 알려 줘'**
  String get routineTemplateUseElevatorPrompt;

  /// 예시 일과 이름 (community)
  ///
  /// In ko, this message translates to:
  /// **'병원 다녀오기'**
  String get routineTemplateHospitalVisitText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 병원에 가서 순서대로 진료를 받게 하고 싶어. 접수하기, 대기실에서 기다리기, 이름 부르면 들어가기, 진료 받기, 약 받고 인사하기까지 알려 줘'**
  String get routineTemplateHospitalVisitPrompt;

  /// 예시 일과 이름 (learning)
  ///
  /// In ko, this message translates to:
  /// **'숙제 시작하기'**
  String get routineTemplateStartHomeworkText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 숙제를 스스로 시작해서 끝내 보게 하고 싶어. 책상에 앉기, 공책과 연필 꺼내기, 숙제 하기, 다 하면 보여 주기, 가방에 넣기까지 알려 줘'**
  String get routineTemplateStartHomeworkPrompt;

  /// 예시 일과 이름 (learning)
  ///
  /// In ko, this message translates to:
  /// **'이름 쓰기 연습'**
  String get routineTemplateWriteNameText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 연필을 바르게 잡고 자기 이름을 써 보게 하고 싶어. 연필 잡기, 종이 놓기, 이름 따라 쓰기, 혼자 써 보기, 정리하기까지 알려 줘'**
  String get routineTemplateWriteNamePrompt;

  /// 예시 일과 이름 (learning)
  ///
  /// In ko, this message translates to:
  /// **'수 세기 놀이'**
  String get routineTemplateCountObjectsText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 물건을 하나씩 짚으며 수를 세는 연습을 하고 싶어. 물건 늘어놓기, 하나씩 손가락으로 짚기, 소리 내어 세기, 다 센 수 말하기까지 알려 줘'**
  String get routineTemplateCountObjectsPrompt;

  /// 예시 일과 이름 (learning)
  ///
  /// In ko, this message translates to:
  /// **'책 읽는 시간'**
  String get routineTemplateReadBookText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 책 읽는 시간을 스스로 가져 보게 하고 싶어. 책 고르기, 자리에 앉기, 한 쪽씩 넘기며 보기, 다 읽으면 책꽂이에 꽂기까지 알려 줘'**
  String get routineTemplateReadBookPrompt;

  /// 예시 일과 이름 (feelings)
  ///
  /// In ko, this message translates to:
  /// **'화가 날 때 감정 카드 꺼내기'**
  String get routineTemplateEmotionCardText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 친구 때문에 화가 날 때 소리 지르거나 밀지 않고 감정 카드를 꺼내 보여 주게 하고 싶어. 멈추기, 주머니에서 감정 카드 꺼내기, 지금 기분 카드 고르기, 선생님께 보여 주기까지 알려 줘'**
  String get routineTemplateEmotionCardPrompt;

  /// 예시 일과 이름 (feelings)
  ///
  /// In ko, this message translates to:
  /// **'친구와 사이좋게 놀기'**
  String get routineTemplatePlayNicelyText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 친구와 사이좋게 노는 연습을 하고 싶어. 같이 놀자고 말하기, 장난감 나눠 쓰기, 차례 지키기, 끝나면 고마워 말하기까지 알려 줘'**
  String get routineTemplatePlayNicelyPrompt;

  /// 예시 일과 이름 (feelings)
  ///
  /// In ko, this message translates to:
  /// **'인사하기'**
  String get routineTemplateGreetingText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 사람을 만나면 먼저 인사하게 하고 싶어. 상대 얼굴 보기, 손 흔들기, 안녕하세요 말하기, 웃어 주기까지 알려 줘'**
  String get routineTemplateGreetingPrompt;

  /// 예시 일과 이름 (feelings)
  ///
  /// In ko, this message translates to:
  /// **'차례 기다리기'**
  String get routineTemplateWaitTurnText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 줄을 서서 자기 차례를 기다리는 연습을 하고 싶어. 줄 끝에 서기, 앞사람 뒤에서 기다리기, 내 차례 확인하기, 차례가 오면 하기까지 알려 줘'**
  String get routineTemplateWaitTurnPrompt;

  /// 예시 일과 이름 (feelings)
  ///
  /// In ko, this message translates to:
  /// **'도와 달라고 말하기'**
  String get routineTemplateAskHelpText;

  /// 예시 일과를 고르면 입력칸에 채울 문장 — AI 가 이 문장으로 카드를 쪼갠다
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 혼자 하기 어려울 때 도움을 요청하게 하고 싶어. 멈추기, 가까운 어른 찾기, 도와주세요 말하기, 도움 받고 고맙습니다 말하기까지 알려 줘'**
  String get routineTemplateAskHelpPrompt;

  /// 보호자 하단 바·옆 메뉴 칸 이름: 홈
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get guardianTabHome;

  /// 보호자 하단 바·옆 메뉴 칸 이름: 만들어 둔 일과·묶음 관리
  ///
  /// In ko, this message translates to:
  /// **'일과 관리'**
  String get guardianTabManage;

  /// 보호자 하단 바·옆 메뉴 칸 이름: 보호자끼리 나누는 이야기
  ///
  /// In ko, this message translates to:
  /// **'이야기'**
  String get guardianTabTalk;

  /// 보호자 하단 바·옆 메뉴 칸 이름이자 그 칸(프로필) 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'내 정보'**
  String get guardianTabMe;

  /// 내정보 프로필 카드: 닉네임 위 역할 이름. 닉네임이 없으면 이 문구가 이름 자리에 감
  ///
  /// In ko, this message translates to:
  /// **'보호자'**
  String get guardianMyInfoProfileName;

  /// 내정보 프로필 카드: 이메일이 없거나 애플 숨김 주소인 계정 (#849)
  ///
  /// In ko, this message translates to:
  /// **'이메일 비공개'**
  String get guardianMyInfoEmailPrivate;

  /// 내정보 닉네임 카드: 가입일 (예: 2026. 10. 19 가입, 시안 1736:8780)
  ///
  /// In ko, this message translates to:
  /// **'{date} 가입'**
  String guardianMyInfoJoinedOn(DateTime date);

  /// 내정보 이룸이 목록: 이룸이가 여럿일 때 지금 보고 있는 이룸이 표시
  ///
  /// In ko, this message translates to:
  /// **'보는 중'**
  String get guardianMyInfoActiveBadge;

  /// 내정보 닉네임 카드: 연필 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'닉네임 바꾸기'**
  String get guardianNicknameEditLabel;

  /// 보호자 닉네임 변경 시트 제목 (시안 1759:9649 그대로)
  ///
  /// In ko, this message translates to:
  /// **'내 이름 변경하기'**
  String get guardianNicknameSheetTitle;

  /// 보호자 닉네임 변경 시트 설명 2줄. 둘째 줄은 서버 7일 제한 안내
  ///
  /// In ko, this message translates to:
  /// **'이야기를 작성할 때 보이는 이름이에요.\n이름은 7일에 한 번 바꿀 수 있어요'**
  String get guardianNicknameSheetDescription;

  /// 보호자 닉네임 변경 시트 입력칸 안내 글
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해주세요'**
  String get guardianNicknameSheetHint;

  /// 보호자 닉네임 변경 시트 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get guardianNicknameSheetSave;

  /// 보호자 닉네임 형식이 맞지 않을 때 입력칸 아래 안내 (서버 NICKNAME_INVALID_FORMAT 과 같은 규칙)
  ///
  /// In ko, this message translates to:
  /// **'한글, 영문, 숫자, 하이픈으로 2~16자까지 쓸 수 있어요'**
  String get guardianNicknameInvalidFormat;

  /// 7일 제한 중 연필을 눌렀을 때 안내. since 는 dateMonthDaySince 결과(예: 10월 27일부터)
  ///
  /// In ko, this message translates to:
  /// **'{since} 바꿀 수 있어요'**
  String guardianNicknameChangeableFrom(String since);

  /// 보호자 닉네임 저장 성공 알림
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 바꿨어요'**
  String get guardianNicknameChanged;

  /// 보호자 닉네임 저장이 네트워크·서버 오류로 실패했을 때 팝업 문장
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 바꾸지 못했어요'**
  String get guardianNicknameSaveFailed;

  /// 태블릿 옆 메뉴 이룸이 카드에서 이름 아래 작은 글
  ///
  /// In ko, this message translates to:
  /// **'보호자 화면'**
  String get guardianSideNavCaption;

  /// 태블릿 옆 메뉴 맨 아래 이룸이 화면으로 가는 버튼 글자
  ///
  /// In ko, this message translates to:
  /// **'이룸이 화면'**
  String get guardianSideNavChildScreen;

  /// 일과관리 칸 빈 상태 제목
  ///
  /// In ko, this message translates to:
  /// **'아직 만든 일과가 없어요'**
  String get routineLibraryEmptyTitle;

  /// 일과관리 칸 빈 상태 설명
  ///
  /// In ko, this message translates to:
  /// **'아래 + 일과 만들기로 첫 일과를 만들어 보세요'**
  String get routineLibraryEmptyBody;

  /// 일과관리 목록을 못 받았을 때
  ///
  /// In ko, this message translates to:
  /// **'일과를 불러오지 못했어요'**
  String get routineLibraryLoadFailedFallback;

  /// 일과관리 칸 가운데 아래 떠 있는 버튼 글자 (앞에 + 아이콘)
  ///
  /// In ko, this message translates to:
  /// **'새로 만들기'**
  String get routineLibraryCreate;

  /// 일과관리 상세 시트·빠른 메뉴의 오늘 이룸이에게 보내기
  ///
  /// In ko, this message translates to:
  /// **'오늘 보내기'**
  String get routineLibrarySendToday;

  /// 일과관리 상세 시트의 보조 버튼 (검토 화면으로)
  ///
  /// In ko, this message translates to:
  /// **'카드 고치기'**
  String get routineLibraryEditCards;

  /// 같은 날 두 번 보내려 할 때 알림
  ///
  /// In ko, this message translates to:
  /// **'오늘 이미 보낸 일과예요'**
  String get routineLibraryAlreadySent;

  /// 보내기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'보내지 못했어요'**
  String get routineLibrarySendFailedTitle;

  /// 일과관리 동작 실패 팝업 기본 설명
  ///
  /// In ko, this message translates to:
  /// **'잠시 뒤 다시 해 주세요'**
  String get routineLibraryActionFailedFallback;

  /// 복사하기 성공 알림
  ///
  /// In ko, this message translates to:
  /// **'복사본을 만들었어요'**
  String get routineLibraryCopied;

  /// 복사하기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'복사하지 못했어요'**
  String get routineLibraryCopyFailedTitle;

  /// 빠른 메뉴 줄 · 이름 바꾸기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'이름 바꾸기'**
  String get routineLibraryMenuRename;

  /// 빠른 메뉴 줄
  ///
  /// In ko, this message translates to:
  /// **'복사하기'**
  String get routineLibraryMenuCopy;

  /// 빠른 메뉴 줄 · 지우기 확인 버튼
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get routineLibraryMenuRemove;

  /// 이름 바꾸기 입력칸 안내 글
  ///
  /// In ko, this message translates to:
  /// **'일과 이름'**
  String get routineLibraryRenameHint;

  /// 이름 바꾸기 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get routineLibraryRenameSave;

  /// 이름 바꾸기 성공 알림
  ///
  /// In ko, this message translates to:
  /// **'이름을 바꿨어요'**
  String get routineLibraryRenamed;

  /// 이름 바꾸기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'이름을 바꾸지 못했어요'**
  String get routineLibraryRenameFailedTitle;

  /// 지우기 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'이 일과를 지울까요?'**
  String get routineLibraryRemoveConfirmTitle;

  /// 지우기 확인 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'일과 관리에서 빠져요. 이룸이가 한 기록은 그대로 남아요'**
  String get routineLibraryRemoveConfirmMessage;

  /// 지우기 성공 알림
  ///
  /// In ko, this message translates to:
  /// **'일과를 지웠어요'**
  String get routineLibraryRemoved;

  /// 지우기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'지우지 못했어요'**
  String get routineLibraryRemoveFailedTitle;

  /// 격자 칸 ✓ 표시의 화면 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'오늘 보냈어요'**
  String get routineLibrarySentBadge;

  /// 격자 칸 화면 낭독 힌트
  ///
  /// In ko, this message translates to:
  /// **'길게 누르면 메뉴가 열려요'**
  String get routineLibraryTileHint;

  /// 격자 칸 이름 아래: 이야기에서 가져온 일과 표시 (계속 남는다)
  ///
  /// In ko, this message translates to:
  /// **'이야기에서'**
  String get routineLibraryFromTalk;

  /// 격자 칸 배지: 이야기에서 가져온 뒤 아직 열어 보지 않은 일과
  ///
  /// In ko, this message translates to:
  /// **'새 일과'**
  String get routineLibraryNewBadge;

  /// 가져온 일과 상세 맨 위 띠의 왼쪽 문구
  ///
  /// In ko, this message translates to:
  /// **'이야기에서 가져왔어요'**
  String get routineDetailTalkOriginBand;

  /// 가져온 일과 상세 띠의 오른쪽 버튼: 이야기 글 상세로 이동
  ///
  /// In ko, this message translates to:
  /// **'원래 글'**
  String get routineDetailTalkOriginOpenPost;

  /// 가져온 일과 상세 띠의 오른쪽 표시: 원래 글이 내려갔거나 못 받았을 때 (누를 수 없음)
  ///
  /// In ko, this message translates to:
  /// **'내려간 글'**
  String get routineDetailTalkOriginPostGone;

  /// 가져온 일과 상세 띠 전체의 화면 낭독 이름 (버튼)
  ///
  /// In ko, this message translates to:
  /// **'이야기에서 가져왔어요, 원래 글 보기'**
  String get routineDetailTalkOriginBandOpenLabel;

  /// 보내기 성공 알림. title 은 일과 제목(조사는 받침을 모르므로 을(를))
  ///
  /// In ko, this message translates to:
  /// **'{title}을(를) 오늘 일과로 보냈어요'**
  String routineLibrarySent(String title);

  /// 온보딩 예시 분류 화면 제목 (#803). name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name}의 어떤 일을\n돕고 싶으세요?'**
  String onboardingExampleTitle(String name);

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'고른 분류의 예시 일과를 넣어 둘게요.\n여러 개 골라도 돼요.'**
  String get onboardingExampleDescription;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get onboardingExampleSkip;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'아침·저녁 준비'**
  String get exampleCategoryMorningEvening;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'씻기, 옷 입기, 잠자리'**
  String get exampleCategoryMorningEveningHint;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'학교·공부'**
  String get exampleCategorySchoolStudy;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'등교 준비, 숙제'**
  String get exampleCategorySchoolStudyHint;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'집안일·스스로 하기'**
  String get exampleCategoryHouseSelf;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'정리, 식탁 차리기'**
  String get exampleCategoryHouseSelfHint;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'밖에서 해 보기'**
  String get exampleCategoryOutside;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'버스 타기, 물건 사기'**
  String get exampleCategoryOutsideHint;

  /// 온보딩 예시 일과 (#803)
  ///
  /// In ko, this message translates to:
  /// **'예시 일과를 넣지 못했어요'**
  String get exampleRoutinesFailed;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음에 넣기'**
  String get routineGroupMenuAddToGroup;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'순서 바꾸기'**
  String get routineGroupMenuReorder;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음 풀기'**
  String get routineGroupMenuUngroup;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'{name} 묶음, 일과 {count}개'**
  String routineGroupTileLabel(String name, int count);

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'새 묶음'**
  String get routineGroupDefaultName;

  /// 새 묶음 만들기 시트: 이름 칸 위 라벨 (#968, 시안 1877:9740)
  ///
  /// In ko, this message translates to:
  /// **'묶음 이름'**
  String get routineGroupNameLabel;

  /// 새 묶음 만들기 시트: 이름 칸 안내 (#968, 시안 1877:9740)
  ///
  /// In ko, this message translates to:
  /// **'예시: 등교 전 준비'**
  String get routineGroupNameHint;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'새 묶음 만들기'**
  String get routineGroupNewTitle;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'{name}에 넣기'**
  String routineGroupAddTitle(String name);

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'넣을 일과를 보여 줄 순서대로 눌러 주세요'**
  String get routineGroupPickHintNew;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'넣을 일과를 순서대로 눌러 주세요'**
  String get routineGroupPickHint;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'넣을 수 있는 일과가 없어요'**
  String get routineGroupPickEmpty;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'{count}개로 묶기'**
  String routineGroupPickConfirmNew(int count);

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'{count}개 넣기'**
  String routineGroupPickConfirmAdd(int count);

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'무엇을 만들까요?'**
  String get routineGroupCreateMenuTitle;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'새 일과 만들기'**
  String get routineGroupCreateRoutine;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'새 묶음 만들기'**
  String get routineGroupCreateGroup;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'어느 묶음에 넣을까요?'**
  String get routineGroupChooseTitle;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'일과 {count}개'**
  String routineGroupSheetCount(int count);

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'일과 넣기'**
  String get routineGroupSheetAdd;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'{title} 묶음에서 빼기'**
  String routineGroupSheetRemove(String title);

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음을 만들었어요'**
  String get routineGroupCreated;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음에 넣었어요'**
  String get routineGroupAdded;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음을 풀었어요'**
  String get routineGroupUngrouped;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'일과를 다 빼서 묶음을 풀었어요'**
  String get routineGroupUngroupedEmpty;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'{name} 묶음을 오늘 일과로 보냈어요'**
  String routineGroupSent(String name);

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음 안 일과를 오늘 모두 보냈어요'**
  String get routineGroupAllSentAlready;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음을 바꾸지 못했어요'**
  String get routineGroupActionFailedTitle;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'묶음을 풀까요?'**
  String get routineGroupUngroupConfirmTitle;

  /// 일과 묶음 (#807)
  ///
  /// In ko, this message translates to:
  /// **'안에 있던 일과는 일과 관리에 그대로 남아요'**
  String get routineGroupUngroupConfirmMessage;

  /// 묶음 시트 ⊖ 확인 팝업 제목 (#890)
  ///
  /// In ko, this message translates to:
  /// **'{title} 일과를 묶음에서 뺄까요?'**
  String routineGroupRemoveConfirmTitle(String title);

  /// 묶음 시트 ⊖ 확인 팝업 본문 (#890) — 지우기가 아니라 묶음에서 빼기
  ///
  /// In ko, this message translates to:
  /// **'일과는 일과 관리에 그대로 남아요'**
  String get routineGroupRemoveConfirmMessage;

  /// 묶음 시트 ⊖ 확인 팝업 실행 버튼 (#890)
  ///
  /// In ko, this message translates to:
  /// **'빼기'**
  String get routineGroupRemoveConfirmAction;

  /// 이룸이 홈 묶음 상자 (#808)
  ///
  /// In ko, this message translates to:
  /// **'{done} / {total}'**
  String childHomeGroupProgress(int done, int total);

  /// 이룸이 홈 묶음 상자 (#808)
  ///
  /// In ko, this message translates to:
  /// **'다 했어요!'**
  String get childHomeGroupAllDone;

  /// 일과 제목 옆 연필 (화면 낭독기 이름)
  ///
  /// In ko, this message translates to:
  /// **'일과 이름 바꾸기'**
  String get routineTitleEdit;

  /// 일과관리 메뉴 찾기 (#834)
  ///
  /// In ko, this message translates to:
  /// **'더 보기'**
  String get routineDetailMore;

  /// 일과관리 정리 상태 (#837)
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get libraryArrangeDone;

  /// 일과관리 정리 상태 (#837)
  ///
  /// In ko, this message translates to:
  /// **'지우기 또는 묶음 풀기'**
  String get libraryArrangeRemove;

  /// 일과관리 묶음 열기 (#837)
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get routineGroupEditOrder;

  /// 일과관리 묶음 열기 (#837)
  ///
  /// In ko, this message translates to:
  /// **'이 일과만 오늘 보내기'**
  String get routineLibrarySendOnlyThis;

  /// 묶음 열기 일과 줄의 보조 글 (#846)
  ///
  /// In ko, this message translates to:
  /// **'카드 {count}장'**
  String routineGroupRowCardCount(int count);

  /// 일과관리 코치마크 1단계. *로 감싼 부분이 강조된다 (#832)
  ///
  /// In ko, this message translates to:
  /// **'일과를 *누르면* 카드를 볼 수 있어요'**
  String get routineManageCoachTapMessage;

  /// 일과관리 코치마크 2단계 (#832)
  ///
  /// In ko, this message translates to:
  /// **'길게 눌렀다 *떼면* 메뉴가 열려요'**
  String get routineManageCoachLongPressMessage;

  /// 일과관리 코치마크 3단계. 보내도 원본은 일과관리에 남는다 (#832)
  ///
  /// In ko, this message translates to:
  /// **'오늘 보낸 일과에는 *✓*가 붙어요\n홈의 오늘 일과에 들어가고\n여기 일과는 그대로 남아요'**
  String get routineManageCoachSentMessage;

  /// 일과관리 묶음 코치마크 1단계 (#832)
  ///
  /// In ko, this message translates to:
  /// **'길게 누른 채 *움직이면* 정리 상태가 돼요\n다른 일과 위에 놓으면 *묶음*이 되고\n사이에 놓으면 자리를 옮겨요'**
  String get routineManageCoachDragMessage;

  /// 일과관리 묶음 코치마크 2단계 (#832)
  ///
  /// In ko, this message translates to:
  /// **'끌기가 어려우면 *+ 일과 만들기*에서\n*새 묶음 만들기*로도 묶을 수 있어요'**
  String get routineManageCoachCreateGroupMessage;

  /// 카드 검토 코치마크 — 이 카드 수정 버튼. 수정 시트의 사진 칩 이름(사진 추가·바꾸기)이 그림 유무로 갈려 버튼 이름을 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'보고 있는 카드의 *글과 그림*을 고쳐요\n그림은 *내 사진*으로 바꿀 수도 있어요'**
  String get cardReviewCoachEditMessage;

  /// 카드 검토 코치마크 — 카드 순서 변경 버튼. 카드 1장이면 나오지 않는다
  ///
  /// In ko, this message translates to:
  /// **'여기를 누른 뒤 카드를 *길게 눌러 끌면*\n순서가 바뀌어요'**
  String get cardReviewCoachReorderMessage;

  /// 카드 검토 코치마크 마지막 단계 — 저장 버튼. 버튼 이름은 cardReviewSave 와 같아야 한다
  ///
  /// In ko, this message translates to:
  /// **'다 고쳤으면 꼭 *카드 저장하기*를 눌러요\n눌러야 일과가 완성돼요'**
  String get cardReviewCoachSaveMessage;

  /// ? 버튼의 낭독 이름 (카드 검토 상단바, 일과관리 머리). 누르면 그 화면의 코치마크를 다시 띄운다
  ///
  /// In ko, this message translates to:
  /// **'사용법 보기'**
  String get coachHelpLabel;

  /// 첫 일과를 보낸 뒤 뜨는 알림 권한 안내 시트 제목 (#828)
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 일과를 끝내면 알려 드릴까요?'**
  String get pushPermissionSheetTitle;

  /// 알림 권한 안내 시트 설명 — 받게 되는 알림 종류
  ///
  /// In ko, this message translates to:
  /// **'다른 보호자의 소식과 크레딧 안내도 함께 알려 드려요'**
  String get pushPermissionSheetBody;

  /// 알림 권한 안내 시트의 허용 버튼 (누르면 시스템 권한 창)
  ///
  /// In ko, this message translates to:
  /// **'알림 받기'**
  String get pushPermissionAllow;

  /// 알림 권한 안내 시트의 보류 버튼
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get pushPermissionLater;

  /// 시스템 권한 창에서 거부했을 때 안내 팝업 문구
  ///
  /// In ko, this message translates to:
  /// **'알림 설정에서 언제든 켤 수 있어요'**
  String get pushPermissionDenied;

  /// 안드로이드 알림 채널 이름 — 이룸이 일과 완료·공동 보호자·크레딧 소식 푸시 (#828)
  ///
  /// In ko, this message translates to:
  /// **'보호자 알림'**
  String get pushChannelGuardianUpdates;

  /// 알림이 꺼진 보호자 기기에 7일마다 다시 권하는 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'알림이 꺼져 있어요'**
  String get pushPermissionNudgeTitle;

  /// 보호자 다시 권하기 시트 설명
  ///
  /// In ko, this message translates to:
  /// **'켜 두면 이룸이가 일과를 끝냈을 때 바로 알려 드려요'**
  String get pushPermissionNudgeBody;

  /// 이룸이 기기 알림 권한 안내 시트 제목 (연결 직후·7일마다)
  ///
  /// In ko, this message translates to:
  /// **'새 일과가 오면 알려 드릴까요?'**
  String get pushPermissionElumiTitle;

  /// 이룸이 기기 알림 권한 안내 시트 설명
  ///
  /// In ko, this message translates to:
  /// **'보호자가 일과를 보내면 이 기기에 알림이 와요'**
  String get pushPermissionElumiBody;

  /// 다시 권하기·이룸이 기기 시트의 허용 버튼 (안 물었으면 시스템 권한 창, 거부했으면 기기 설정)
  ///
  /// In ko, this message translates to:
  /// **'알림 켜기'**
  String get pushPermissionTurnOn;

  /// 안드로이드 알림 채널 이름 — 이룸이 기기에 오는 새 일과 도착 푸시
  ///
  /// In ko, this message translates to:
  /// **'새 일과 알림'**
  String get pushChannelElumiRoutines;

  /// 가입한 소셜 제공자 배지의 화면 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'카카오'**
  String get signInProviderKakao;

  /// 가입한 소셜 제공자 배지의 화면 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'네이버'**
  String get signInProviderNaver;

  /// 가입한 소셜 제공자 배지의 화면 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'구글'**
  String get signInProviderGoogle;

  /// 가입한 소셜 제공자 배지의 화면 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'애플'**
  String get signInProviderApple;

  /// 일과관리 코치마크 안내 화면의 예시 일과 이름 (#861)
  ///
  /// In ko, this message translates to:
  /// **'아침 준비'**
  String get routineManageCoachSampleMorning;

  /// 일과관리 코치마크 안내 화면의 예시 일과 이름 (#861)
  ///
  /// In ko, this message translates to:
  /// **'양치하기'**
  String get routineManageCoachSampleBrush;

  /// 일과관리 코치마크 안내 화면의 예시 일과 이름 (#861)
  ///
  /// In ko, this message translates to:
  /// **'가방 챙기기'**
  String get routineManageCoachSampleBag;

  /// 보호자 홈에서 하루 한 번 뜨는 업데이트 권유 팝업 제목 (#660)
  ///
  /// In ko, this message translates to:
  /// **'새 버전이 나왔어요'**
  String get updateSuggestionTitle;

  /// 업데이트 권유 팝업 본문
  ///
  /// In ko, this message translates to:
  /// **'업데이트하면 고친 점과 새 기능을 바로 쓸 수 있어요'**
  String get updateSuggestionBody;

  /// 업데이트 권유 팝업의 닫기 버튼
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get updateSuggestionLater;

  /// 이룸이 정보 화면 제목. name 은 이룸이 호칭 (#660)
  ///
  /// In ko, this message translates to:
  /// **'{name} 정보'**
  String elumiInfoTitle(String name);

  /// 내정보 이룸이 줄의 연필 버튼을 낭독기가 읽는 이름. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name} 정보 고치기'**
  String elumiInfoEditLabel(String name);

  /// 이룸이 정보 화면: 이름 줄
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get elumiInfoName;

  /// 이룸이 정보 화면: 캐릭터 줄
  ///
  /// In ko, this message translates to:
  /// **'캐릭터'**
  String get elumiInfoCharacter;

  /// 이룸이 정보 화면: 캐릭터 바꾸기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'캐릭터 바꾸기'**
  String get elumiInfoCharacterSheetTitle;

  /// 이룸이 정보 화면: 그림 방식 바꾸기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'그림 방식 바꾸기'**
  String get elumiInfoImageStyleSheetTitle;

  /// 이룸이 정보 시트의 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get elumiInfoSave;

  /// 이룸이 정보를 저장한 뒤 알림
  ///
  /// In ko, this message translates to:
  /// **'저장했어요'**
  String get elumiInfoSaved;

  /// 이룸이 정보 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'저장하지 못했어요'**
  String get elumiInfoSaveFailedTitle;

  /// 이룸이 정보 저장 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get elumiInfoSaveFailedFallback;

  /// 이룸이 정보 화면: 회원 정보를 못 받았거나 그 이룸이가 목록에 없을 때
  ///
  /// In ko, this message translates to:
  /// **'이룸이 정보를 불러오지 못했어요'**
  String get elumiInfoNotFound;

  /// 이야기 칸 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'이야기'**
  String get talkTitle;

  /// 이야기 칸 아래 가운데 떠 있는 버튼: 내 일과를 올리러 간다 (앞의 + 는 아이콘)
  ///
  /// In ko, this message translates to:
  /// **'올리기'**
  String get talkWriteButton;

  /// 이야기 분류 칩: 분류 없이 전체 보기
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get talkCategoryAll;

  /// 이야기 칸 인기 줄 제목 (최근 7일)
  ///
  /// In ko, this message translates to:
  /// **'이번 주에 많이 가져간 일과에요'**
  String get talkPopularTitle;

  /// 피드 카드 가져감 아이콘 숫자의 읽기 프로그램 문구: 일과관리로 가져간 보호자 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}명 가져감}}'**
  String talkPopularImportCount(int count);

  /// 이야기 칸 최신 글 목록 제목
  ///
  /// In ko, this message translates to:
  /// **'새로 올라왔어요'**
  String get talkLatestTitle;

  /// 이야기 칸 글이 0건일 때 안내
  ///
  /// In ko, this message translates to:
  /// **'아직 나눈 일과가 없어요'**
  String get talkEmptyTitle;

  /// 이야기 칸 분류 칩으로 거른 결과가 0건일 때 안내
  ///
  /// In ko, this message translates to:
  /// **'이 분류에는 아직 나눈 일과가 없어요'**
  String get talkEmptyCategoryTitle;

  /// 이야기 칸 분류 빈 상태 버튼: 전체 칩으로 되돌림
  ///
  /// In ko, this message translates to:
  /// **'전체 보기'**
  String get talkEmptyCategoryAction;

  /// 이야기 칸 첫 쪽 불러오기 실패 문구
  ///
  /// In ko, this message translates to:
  /// **'이야기를 불러오지 못했어요'**
  String get talkFeedFailed;

  /// 닉네임이 없는 글쓴이를 부르는 이름
  ///
  /// In ko, this message translates to:
  /// **'보호자'**
  String get talkAuthorFallback;

  /// 이야기 올리기 맨 위 일과 제목 칸 이름. 고치면 일과관리의 일과 이름도 바뀐다
  ///
  /// In ko, this message translates to:
  /// **'일과 제목'**
  String get talkShareTitleLabel;

  /// 이야기 올리기 일과 제목 칸을 비웠을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'일과 제목을 적어 주세요'**
  String get talkShareTitleHint;

  /// 글쓴이 한마디 칸 이름 (올리기·고치기·상세)
  ///
  /// In ko, this message translates to:
  /// **'내용'**
  String get talkNoteLabel;

  /// 글 카드: 도움이 됐어요 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{도움돼요 {count}}}'**
  String talkHelpfulCount(int count);

  /// 글 카드: 댓글 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{댓글 {count}}}'**
  String talkCommentCount(int count);

  /// 이야기 목록 끝: 다음 쪽 불러오기 실패 시 다시 시도 줄
  ///
  /// In ko, this message translates to:
  /// **'더 불러오지 못했어요. 눌러서 다시 해 보세요'**
  String get talkLoadMoreRetry;

  /// 상세 머리: 카드 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{카드 {count}장}}'**
  String talkDetailStepCount(int count);

  /// 상세 화면: 글 불러오기 실패 문구
  ///
  /// In ko, this message translates to:
  /// **'글을 불러오지 못했어요'**
  String get talkDetailLoadFailed;

  /// 상세 화면: 글이 내려갔거나, 보낸 링크가 꺼졌거나, 없을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'더 볼 수 없는 글이에요'**
  String get talkPostGoneTitle;

  /// 상세 화면: 내려간 글 안내의 버튼
  ///
  /// In ko, this message translates to:
  /// **'이야기로 돌아가기'**
  String get talkPostGoneBack;

  /// 상세 머리 칩: 카드 아이콘 뒤 카드 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}장}}'**
  String talkDetailCardCountChip(int count);

  /// 상세 작성 시각 (예: 10/21 오후 11:42)
  ///
  /// In ko, this message translates to:
  /// **'{date} {time}'**
  String talkDetailPostedAt(DateTime date, DateTime time);

  /// 상세 보기 전환 칩: 카드를 2열 격자로 모아 보기
  ///
  /// In ko, this message translates to:
  /// **'한 눈에 보기'**
  String get talkViewGrid;

  /// 상세 보기 전환 칩: 카드를 한 장씩 크게 넘겨 보기
  ///
  /// In ko, this message translates to:
  /// **'크게 보기'**
  String get talkViewLarge;

  /// 상세 화면: 도움돼요 누르기 실패 안내(팝업)
  ///
  /// In ko, this message translates to:
  /// **'도움돼요를 바꾸지 못했어요. 잠시 뒤에 다시 해 주세요'**
  String get talkHelpfulFailed;

  /// 상세 카드 아래 버튼: 이 일과를 내 일과관리로 가져오기 (앞의 내려받기는 아이콘)
  ///
  /// In ko, this message translates to:
  /// **'일과로 가져오기'**
  String get talkImportButton;

  /// 상세 카드 아래 버튼: 이미 가져온 글(다시 누르면 한 번 더 넣는다)
  ///
  /// In ko, this message translates to:
  /// **'✓ 일과 관리에 넣었어요'**
  String get talkImportedButton;

  /// 상세 머리 줄 오른쪽 공유 아이콘의 읽기 이름: 이 글 링크를 메신저 등 앱 밖으로 보내기 (올리기와 다르다)
  ///
  /// In ko, this message translates to:
  /// **'공유하기'**
  String get talkShareLinkButton;

  /// 이야기 글 링크를 메신저로 보낼 때의 글. title 은 글 제목, url 은 링크(번역하지 않는다)
  ///
  /// In ko, this message translates to:
  /// **'{title}\n이룸 이야기에서 같이 봐요\n\n{url}'**
  String talkShareLinkMessage(String title, String url);

  /// 상세 화면: 공유 시트를 띄우지 못했을 때 안내(팝업)
  ///
  /// In ko, this message translates to:
  /// **'공유하지 못했어요. 잠시 뒤에 다시 해 주세요'**
  String get talkShareLinkFailed;

  /// 이룸이 전용 기기에서 이야기 글 링크를 열었을 때의 토스트
  ///
  /// In ko, this message translates to:
  /// **'이야기 글은 보호자 기기에서 볼 수 있어요'**
  String get talkPostLinkRejectedOnElumiDevice;

  /// 가져오기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'일과로 가져오기'**
  String get talkImportSheetTitle;

  /// 가져오기 시트 안내: 일과관리에만 들어가고 이룸이에게는 보호자가 보내야 간다
  ///
  /// In ko, this message translates to:
  /// **'일과에 추가한 뒤 이룸이에게 맞게 고칠 수 있어요'**
  String get talkImportSheetHint;

  /// 가져오기 시트: 어느 이룸이의 일과관리에 넣을지 고르는 줄 이름 (연결된 이룸이가 2명 이상일 때만)
  ///
  /// In ko, this message translates to:
  /// **'이룸이'**
  String get talkImportElumiLabel;

  /// 가져오기 시트 확인 버튼 (묶음을 안 고르면 묶음 없이 넣는다)
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get talkImportConfirm;

  /// 가져오기 시트: 연결된 이룸이가 한 명도 없을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'이룸이를 먼저 연결해 주세요'**
  String get talkImportNoElumiTitle;

  /// 가져오기 시트: 이룸이 연결 화면으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'이룸이 연결하기'**
  String get talkImportNoElumiAction;

  /// 가져온 직후 토스트. routineTitle 은 가져온 일과 이름. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'{routineTitle}{batchim, select, yes{을} other{를}} 가져왔어요'**
  String talkImportDone(String routineTitle, String batchim);

  /// 가져온 직후 토스트의 버튼: 일과관리 칸으로 이동
  ///
  /// In ko, this message translates to:
  /// **'보러 가기'**
  String get talkImportGoToLibrary;

  /// 가져오기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'일과 관리에 넣지 못했어요'**
  String get talkImportFailedTitle;

  /// 상세 화면: 댓글 목록 제목
  ///
  /// In ko, this message translates to:
  /// **'댓글'**
  String get talkCommentsTitle;

  /// 상세 화면: 댓글 0건 안내
  ///
  /// In ko, this message translates to:
  /// **'아직 댓글이 없어요'**
  String get talkCommentsEmpty;

  /// 댓글 칸 이름: 내가 쓴 댓글 (이름은 민트색)
  ///
  /// In ko, this message translates to:
  /// **'{name}(나)'**
  String talkCommentAuthorMine(String name);

  /// 댓글 칸 이름: 이 글을 올린 보호자가 쓴 댓글
  ///
  /// In ko, this message translates to:
  /// **'{name}(글쓴이)'**
  String talkCommentAuthorPostWriter(String name);

  /// 상세 화면: 운영 정책으로 가려진 내 댓글 자리에 보이는 안내 (작성자 본인에게만)
  ///
  /// In ko, this message translates to:
  /// **'운영 정책에 따라 가렸어요'**
  String get talkCommentHiddenNotice;

  /// 상세 화면: 댓글 첫 쪽 불러오기 실패 안내(다시 하기 버튼과 에러 코드가 아래에 붙는다)
  ///
  /// In ko, this message translates to:
  /// **'댓글을 불러오지 못했어요'**
  String get talkCommentsFailed;

  /// 상세 화면 댓글 입력창 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'댓글을 남겨 보세요'**
  String get talkCommentHint;

  /// 상세 화면 댓글 보내기 버튼
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get talkCommentSend;

  /// 댓글 보내기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'댓글을 보내지 못했어요'**
  String get talkCommentSendFailedTitle;

  /// 이야기 실패 팝업의 기본 안내(서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'잠시 뒤에 다시 해 주세요'**
  String get talkFailedFallback;

  /// 내 댓글 지우기 확인 대화상자 제목
  ///
  /// In ko, this message translates to:
  /// **'댓글을 지울까요?'**
  String get talkCommentDeleteTitle;

  /// 내 댓글 지우기 확인 대화상자·메뉴의 지우기 버튼
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get talkCommentDeleteAction;

  /// 댓글 지우기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'댓글을 지우지 못했어요'**
  String get talkCommentDeleteFailedTitle;

  /// 글·댓글 더보기 메뉴: 신고
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get talkMenuReport;

  /// 글·댓글 더보기 메뉴: 글쓴이 숨기기
  ///
  /// In ko, this message translates to:
  /// **'이 보호자 글 숨기기'**
  String get talkMenuBlock;

  /// 내 글 더보기 메뉴: 한마디와 분류 고치기
  ///
  /// In ko, this message translates to:
  /// **'고치기'**
  String get talkMenuEdit;

  /// 내 글 더보기 메뉴: 글 내리기
  ///
  /// In ko, this message translates to:
  /// **'내리기'**
  String get talkMenuTakeDown;

  /// 상세 화면 오른쪽 위 점 세 개 버튼의 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get talkMoreLabel;

  /// 내 글 내리기 확인 대화상자 제목
  ///
  /// In ko, this message translates to:
  /// **'이 글을 내릴까요?'**
  String get talkTakeDownTitle;

  /// 내 글 내리기 확인 대화상자 안내
  ///
  /// In ko, this message translates to:
  /// **'내린 글은 다른 보호자에게 더 이상 보이지 않아요.'**
  String get talkTakeDownMessage;

  /// 글 내리기 성공 안내(토스트)
  ///
  /// In ko, this message translates to:
  /// **'글을 내렸어요'**
  String get talkTakeDownDone;

  /// 글 내리기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'글을 내리지 못했어요'**
  String get talkTakeDownFailedTitle;

  /// 내 글 고치기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'글 고치기'**
  String get talkEditTitle;

  /// 내 글 고치기 시트 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get talkEditSave;

  /// 글 고치기 성공 안내(토스트)
  ///
  /// In ko, this message translates to:
  /// **'고쳤어요'**
  String get talkEditSaved;

  /// 글 고치기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'글을 고치지 못했어요'**
  String get talkEditFailedTitle;

  /// 한마디 입력창 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'다른 사람 이름, 연락처 등 개인정보는 적지 말아 주세요'**
  String get talkNoteGuide;

  /// 분류 고르기 제목
  ///
  /// In ko, this message translates to:
  /// **'분류'**
  String get talkCategoryTitle;

  /// 신고 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get talkReportTitle;

  /// 신고 시트 보내기 버튼
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get talkReportSubmit;

  /// 신고 성공 안내(토스트)
  ///
  /// In ko, this message translates to:
  /// **'신고했어요'**
  String get talkReportDone;

  /// 신고 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'신고하지 못했어요'**
  String get talkReportFailedTitle;

  /// 신고 사유 1
  ///
  /// In ko, this message translates to:
  /// **'이룸이나 가족 정보가 보여요'**
  String get talkReportReasonPersonalInfo;

  /// 신고 사유 2
  ///
  /// In ko, this message translates to:
  /// **'기분 나쁜 말이 있어요'**
  String get talkReportReasonOffensive;

  /// 신고 사유 3
  ///
  /// In ko, this message translates to:
  /// **'광고나 홍보예요'**
  String get talkReportReasonAdvertising;

  /// 신고 사유 4
  ///
  /// In ko, this message translates to:
  /// **'그 밖의 이유'**
  String get talkReportReasonOther;

  /// 글쓴이 숨기기 확인 대화상자 제목
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님 글을 숨길까요?'**
  String talkBlockTitle(String nickname);

  /// 글쓴이 숨기기 확인 대화상자 안내
  ///
  /// In ko, this message translates to:
  /// **'이 보호자의 글과 댓글이 나에게 안 보여요. 상대방은 알 수 없어요. 내 정보 › 숨긴 보호자에서 다시 볼 수 있어요.'**
  String get talkBlockMessage;

  /// 글쓴이 숨기기 확인 대화상자 버튼
  ///
  /// In ko, this message translates to:
  /// **'숨기기'**
  String get talkBlockAction;

  /// 글쓴이 숨기기 성공 안내(토스트)
  ///
  /// In ko, this message translates to:
  /// **'숨겼어요'**
  String get talkBlockDone;

  /// 글쓴이 숨기기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'숨기지 못했어요'**
  String get talkBlockFailedTitle;

  /// 내 정보 줄 이름이자 숨긴 보호자 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'숨긴 보호자'**
  String get talkBlockedGuardiansTitle;

  /// 숨긴 보호자 화면 0건 안내
  ///
  /// In ko, this message translates to:
  /// **'숨긴 보호자가 없어요'**
  String get talkBlockedGuardiansEmpty;

  /// 숨긴 보호자 화면 불러오기 실패 문구
  ///
  /// In ko, this message translates to:
  /// **'숨긴 보호자를 불러오지 못했어요'**
  String get talkBlockedGuardiansFailed;

  /// 숨긴 보호자 줄 버튼: 숨김 풀기
  ///
  /// In ko, this message translates to:
  /// **'다시 보기'**
  String get talkUnblockAction;

  /// 숨김 풀기 성공 안내(토스트)
  ///
  /// In ko, this message translates to:
  /// **'다시 볼 수 있어요'**
  String get talkUnblockDone;

  /// 숨김 풀기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'숨김을 풀지 못했어요'**
  String get talkUnblockFailedTitle;

  /// 이용 규칙 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'이야기 이용 규칙'**
  String get talkRulesTitle;

  /// 이용 규칙 시트 안내
  ///
  /// In ko, this message translates to:
  /// **'보호자끼리 안전하게 나누려고 이 세 가지를 지켜 주세요.'**
  String get talkRulesIntro;

  /// 이용 규칙 1
  ///
  /// In ko, this message translates to:
  /// **'얼굴·이름·학교·집 주소가 보이지 않게 해 주세요'**
  String get talkRulesPrivacy;

  /// 이용 규칙 2
  ///
  /// In ko, this message translates to:
  /// **'다른 보호자를 존중해 주세요. 비난·광고·홍보는 안 돼요'**
  String get talkRulesRespect;

  /// 이용 규칙 3
  ///
  /// In ko, this message translates to:
  /// **'진단명·병원 정보는 적지 말아 주세요'**
  String get talkRulesNoDiagnosis;

  /// 이용 규칙 동의 체크 문구
  ///
  /// In ko, this message translates to:
  /// **'위 규칙을 읽었고 지킬게요'**
  String get talkRulesAgreeCheck;

  /// 이용 규칙 동의 버튼
  ///
  /// In ko, this message translates to:
  /// **'동의하고 계속하기'**
  String get talkRulesAgreeButton;

  /// 이용 규칙 동의 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'동의를 저장하지 못했어요'**
  String get talkRulesFailedTitle;

  /// 올리기 화면 머리 제목
  ///
  /// In ko, this message translates to:
  /// **'이야기에 올리기'**
  String get talkShareTitle;

  /// 올리기 1단계 일과 고르기 안내
  ///
  /// In ko, this message translates to:
  /// **'어떤 일과를 나눌까요?'**
  String get talkSharePickTitle;

  /// 올릴 일과가 하나도 없을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'올릴 수 있는 일과가 없어요'**
  String get talkSharePickEmpty;

  /// 올릴 일과가 없을 때 설명. 예시는 고치면 올릴 수 있다 (#983)
  ///
  /// In ko, this message translates to:
  /// **'일과 관리에 있는 내 일과만 올릴 수 있어요. 이미 올렸거나 이야기에서 가져온 일과는 빠져요. 예시 일과는 제목이나 카드를 고치면 올릴 수 있어요.'**
  String get talkSharePickEmptyHint;

  /// 올릴 일과 목록 실패 안내
  ///
  /// In ko, this message translates to:
  /// **'일과를 불러오지 못했어요'**
  String get talkSharePickFailed;

  /// 올리기 미리보기 받기 실패 안내
  ///
  /// In ko, this message translates to:
  /// **'올릴 내용을 불러오지 못했어요'**
  String get talkSharePreviewFailed;

  /// 올리기 2단계 사진 고르기 제목
  ///
  /// In ko, this message translates to:
  /// **'사진을 어떻게 올릴까요?'**
  String get talkSharePhotoTitle;

  /// 올리기 2단계 사진 안내
  ///
  /// In ko, this message translates to:
  /// **'얼굴, 이름, 집 주소가 보이면 흐리게 해 주세요.\nAI로 만든 그림은 그대로 올라가요'**
  String get talkSharePhotoGuide;

  /// 사진을 흐리게 올리는 선택지
  ///
  /// In ko, this message translates to:
  /// **'흐리게'**
  String get talkSharePhotoBlur;

  /// 사진을 그대로 올리는 선택지
  ///
  /// In ko, this message translates to:
  /// **'그대로'**
  String get talkSharePhotoKeep;

  /// 사진 고르기를 마치고 넘어가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get talkSharePhotoNext;

  /// 올리기 3단계 카드 미리보기 제목
  ///
  /// In ko, this message translates to:
  /// **'이렇게 보여요'**
  String get talkSharePreviewTitle;

  /// 올리기 3단계 완료 버튼
  ///
  /// In ko, this message translates to:
  /// **'올리기'**
  String get talkShareSubmit;

  /// 올리기 성공 토스트
  ///
  /// In ko, this message translates to:
  /// **'이야기에 올렸어요'**
  String get talkShareDone;

  /// 올리기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'올리지 못했어요'**
  String get talkShareFailedTitle;

  /// 홈: 끝낸 일과 카드 아래 링크, 누르면 이야기 올리기로 간다
  ///
  /// In ko, this message translates to:
  /// **'📖 이야기에 공유해 보기 ›'**
  String get talkShareHint;

  /// 일과관리 ⋯ 메뉴 줄: 이 일과를 이야기에 올리러 간다
  ///
  /// In ko, this message translates to:
  /// **'이야기에 공유하기'**
  String get talkMenuShare;

  /// 내 정보 바로가기 줄 이름이자 내가 쓴 글 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'내가 쓴 글'**
  String get talkMyPostsTitle;

  /// 내가 쓴 글 화면 0건 안내
  ///
  /// In ko, this message translates to:
  /// **'아직 쓴 글이 없어요'**
  String get talkMyPostsEmpty;

  /// 내가 쓴 글 0건 버튼: 이야기 올리기로 이동
  ///
  /// In ko, this message translates to:
  /// **'이야기에 일과 나누기'**
  String get talkMyPostsEmptyAction;

  /// 내가 쓴 글 화면 첫 쪽 불러오기 실패 문구
  ///
  /// In ko, this message translates to:
  /// **'내가 쓴 글을 불러오지 못했어요'**
  String get talkMyPostsFailed;

  /// 일과관리 ⋯ 메뉴 줄: 이미 이야기에 올린 일과면 그 글로 간다
  ///
  /// In ko, this message translates to:
  /// **'내 글 보기'**
  String get talkMenuViewMyPost;

  /// 일과관리 메뉴 줄·링크로 보내기 화면 제목: 이 일과를 아는 사람에게 링크로 보낸다 (이야기에는 안 올라감)
  ///
  /// In ko, this message translates to:
  /// **'링크로 보내기'**
  String get talkLinkSend;

  /// 일과관리 메뉴 줄·끄기 확인 버튼: 보낸 링크를 끈다 (끈 링크로는 더 볼 수 없다)
  ///
  /// In ko, this message translates to:
  /// **'링크 끄기'**
  String get talkLinkTurnOff;

  /// 링크로 보내기 화면: 사진 카드가 없을 때의 질문
  ///
  /// In ko, this message translates to:
  /// **'이 일과를 링크로 보낼까요?'**
  String get talkLinkConfirmTitle;

  /// 링크로 보내기 화면 안내: 링크를 받은 사람만 보고, 이야기에 안 올라가고, 나중에 끌 수 있다
  ///
  /// In ko, this message translates to:
  /// **'링크를 받은 사람만 볼 수 있어요. 이야기에는 올라가지 않아요.\n보낸 뒤에도 일과 관리에서 링크를 끌 수 있어요'**
  String get talkLinkConfirmGuide;

  /// 링크로 보내기 화면 안내: 이미 켜진 링크가 있어 같은 링크를 다시 보낼 때 (처음 보낸 모습 그대로)
  ///
  /// In ko, this message translates to:
  /// **'이미 보낸 링크가 있어요. 처음 보낸 모습 그대로 같은 링크를 다시 보내요.\n바꾼 내용을 보내려면 링크를 끄고 다시 보내 주세요'**
  String get talkLinkResendGuide;

  /// 링크로 보내기 화면: 보호자 사진 카드를 흐리게 할지 묻는 질문
  ///
  /// In ko, this message translates to:
  /// **'사진을 어떻게 보낼까요?'**
  String get talkLinkPhotoTitle;

  /// 링크로 보내기 화면: 사진 흐리게 안내 (AI 그림은 그대로 보인다)
  ///
  /// In ko, this message translates to:
  /// **'얼굴, 이름, 집 주소가 보이면 흐리게 해 주세요.\nAI로 만든 그림은 그대로 보여요'**
  String get talkLinkPhotoGuide;

  /// 링크로 보내기 화면 아래 버튼: 링크를 만들고 공유 시트를 연다
  ///
  /// In ko, this message translates to:
  /// **'링크 만들기'**
  String get talkLinkCreateButton;

  /// 링크로 보내기 화면: 보낼 내용을 못 받았을 때 (다시 하기와 함께)
  ///
  /// In ko, this message translates to:
  /// **'보낼 내용을 불러오지 못했어요'**
  String get talkLinkPreviewFailed;

  /// 링크 만들기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'링크를 만들지 못했어요'**
  String get talkLinkCreateFailedTitle;

  /// 링크를 만들고 공유 시트를 닫은 뒤 토스트
  ///
  /// In ko, this message translates to:
  /// **'링크를 만들었어요'**
  String get talkLinkCreated;

  /// 일과 링크를 메신저로 보낼 때의 글. title 은 이름을 가린 일과 제목, url 은 링크(번역하지 않는다)
  ///
  /// In ko, this message translates to:
  /// **'{title}\n이룸에서 이 일과를 가져가 보세요\n\n{url}'**
  String talkLinkShareMessage(String title, String url);

  /// 링크 끄기 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'링크를 끌까요?'**
  String get talkLinkTurnOffTitle;

  /// 링크 끄기 확인 팝업 안내: 받은 사람은 더 못 보고, 이미 가져간 일과는 남는다
  ///
  /// In ko, this message translates to:
  /// **'링크를 받은 사람은 더 볼 수 없어요. 이미 가져간 일과는 그대로 남아요'**
  String get talkLinkTurnOffMessage;

  /// 링크를 끈 뒤 토스트
  ///
  /// In ko, this message translates to:
  /// **'링크를 껐어요'**
  String get talkLinkTurnOffDone;

  /// 링크 끄기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'링크를 끄지 못했어요'**
  String get talkLinkTurnOffFailedTitle;

  /// 링크로 받은 일과 상세 화면의 머리 제목
  ///
  /// In ko, this message translates to:
  /// **'받은 일과'**
  String get talkLinkReceivedTitle;

  /// 1분이 안 지난 시각 표기
  ///
  /// In ko, this message translates to:
  /// **'방금 전'**
  String get timeAgoJustNow;

  /// 1시간 안쪽 시각 표기
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}분 전}}'**
  String timeAgoMinutes(int count);

  /// 하루 안쪽 시각 표기
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}시간 전}}'**
  String timeAgoHours(int count);

  /// 일주일 안쪽 시각 표기
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}일 전}}'**
  String timeAgoDays(int count);

  /// 일과 진행 링(진행 중)을 화면 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'{percent}% 했어요'**
  String routineProgressRingPercentLabel(int percent);

  /// 일과 진행 링(다 한 일과, 체크 원)을 화면 낭독기가 읽는 이름
  ///
  /// In ko, this message translates to:
  /// **'다 했어요'**
  String get routineProgressRingDoneLabel;

  /// 보호자 설정의 라이선스 줄
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get guardianSettingsLicenses;

  /// 라이선스 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get licenseScreenTitle;

  /// 라이선스 화면 안내
  ///
  /// In ko, this message translates to:
  /// **'이룸은 아래 그림, 글꼴, 프로그램을 사용해 만들었어요. 항목을 누르면 라이선스 전문을 볼 수 있어요.'**
  String get licenseScreenGuide;

  /// 라이선스 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'그림'**
  String get licenseGroupArtwork;

  /// 라이선스 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'글꼴'**
  String get licenseGroupFonts;

  /// 라이선스 묶음 제목, 프로그램 목록 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'프로그램'**
  String get licenseGroupSoftware;

  /// 프로그램 라이선스 목록으로 가는 줄
  ///
  /// In ko, this message translates to:
  /// **'프로그램 목록 보기'**
  String get licenseSoftwareListRow;

  /// 글꼴 이름
  ///
  /// In ko, this message translates to:
  /// **'티머니 둥근바람'**
  String get licenseFontTmoneyName;

  /// 라이선스를 못 읽었을 때
  ///
  /// In ko, this message translates to:
  /// **'목록을 불러오지 못했어요'**
  String get licenseLoadFailedMessage;

  /// 일과 상세 시트 머리의 내려받기 버튼 낭독 이름 · 내보내기 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'인쇄용으로 받기'**
  String get cardExportOpen;

  /// 내보내기 형태 고르기 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'어떻게 받을까요?'**
  String get cardExportFormatSection;

  /// 형태: A4 한 장에 일과 카드 전부
  ///
  /// In ko, this message translates to:
  /// **'일과 한 장'**
  String get cardExportFormatRoutineSheet;

  /// 형태 설명
  ///
  /// In ko, this message translates to:
  /// **'A4 한 장에 순서대로'**
  String get cardExportFormatRoutineSheetCaption;

  /// 형태: 자를 선이 있는 A4
  ///
  /// In ko, this message translates to:
  /// **'오려 쓰는 카드'**
  String get cardExportFormatCutCards;

  /// 형태 설명
  ///
  /// In ko, this message translates to:
  /// **'A4에 자를 선과 함께'**
  String get cardExportFormatCutCardsCaption;

  /// 형태: 카드마다 이미지 한 장
  ///
  /// In ko, this message translates to:
  /// **'카드 한 장씩'**
  String get cardExportFormatCardImages;

  /// 형태 설명
  ///
  /// In ko, this message translates to:
  /// **'카드마다 이미지 한 장'**
  String get cardExportFormatCardImagesCaption;

  /// 오려 쓰는 카드 장수 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'한 쪽에 몇 장 넣을까요?'**
  String get cardExportPerPageSection;

  /// 카드 문장을 넣을지 켜고 끄는 줄
  ///
  /// In ko, this message translates to:
  /// **'카드 문장 넣기'**
  String get cardExportIncludeText;

  /// 디자인 테마 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'카드 디자인'**
  String get cardExportThemeSection;

  /// 테마 이름: 앱 카드 그대로
  ///
  /// In ko, this message translates to:
  /// **'기본'**
  String get cardExportThemeBasic;

  /// 테마 이름: 장식 없는 굵은 테두리
  ///
  /// In ko, this message translates to:
  /// **'단순'**
  String get cardExportThemeSimple;

  /// 테마 이름: 흰 바탕 얇은 테두리
  ///
  /// In ko, this message translates to:
  /// **'잉크 절약'**
  String get cardExportThemeInkSaver;

  /// 테마 이름: 그림까지 흑백
  ///
  /// In ko, this message translates to:
  /// **'흑백'**
  String get cardExportThemeMonochrome;

  /// 테마 이름: 글자를 크게
  ///
  /// In ko, this message translates to:
  /// **'큰 글자'**
  String get cardExportThemeLargeText;

  /// Pro 배지 하나 (미리 보기 판·그림 방식·인쇄 선택지·카드 그림 칩·요금제 화면 공통, ProBadge, #1170)
  ///
  /// In ko, this message translates to:
  /// **'PRO'**
  String get planProBadge;

  /// Free 가 Pro 테마를 눌렀을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'Pro에서 쓸 수 있는 디자인이에요'**
  String get cardExportProThemeLocked;

  /// Free 미리 보기 아래 안내
  ///
  /// In ko, this message translates to:
  /// **'Free는 아래에 이룸 로고 띠가 들어가요'**
  String get cardExportWatermarkNotice;

  /// 미리 보기 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'미리 보기'**
  String get cardExportPreviewSection;

  /// 그림 없는 카드가 있을 때 미리 보기 종이 밖 안내
  ///
  /// In ko, this message translates to:
  /// **'그림이 아직 없는 카드는 제목만 들어가요'**
  String get cardExportMissingPicture;

  /// 카드 그림 일부를 못 받았을 때 미리 보기 종이 밖 안내 (그 카드는 예시 그림·픽토그램·제목으로 대신)
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{그림을 불러오지 못한 카드 {count}장은 다른 그림이나 제목으로 들어가요}}'**
  String cardExportSomePicturesFailed(int count);

  /// PDF 를 다른 앱으로 보낼 때 크기 안내
  ///
  /// In ko, this message translates to:
  /// **'다른 앱에서 인쇄할 때는 실제 크기를 골라 주세요'**
  String get cardExportActualSizeHint;

  /// 기기 인쇄 화면 열기 버튼
  ///
  /// In ko, this message translates to:
  /// **'인쇄하기'**
  String get cardExportPrint;

  /// 공유 시트 열기 버튼
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get cardExportShare;

  /// 그림을 받는 동안
  ///
  /// In ko, this message translates to:
  /// **'카드를 준비하고 있어요'**
  String get cardExportPreparing;

  /// 그림 받기 실패 팝업
  ///
  /// In ko, this message translates to:
  /// **'카드 그림을 불러오지 못했어요'**
  String get cardExportImageFailed;

  /// 파일 만들기 실패 팝업
  ///
  /// In ko, this message translates to:
  /// **'인쇄용 파일을 만들지 못했어요'**
  String get cardExportRenderFailed;

  /// 인쇄 화면을 못 열었을 때
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서 인쇄할 수 없어요. 보내기로 받아 주세요'**
  String get cardExportPrintFailed;

  /// 카드 0장 일과
  ///
  /// In ko, this message translates to:
  /// **'카드가 없는 일과예요'**
  String get cardExportNoCards;

  /// 카드 한 장씩에서 모두 뺐을 때
  ///
  /// In ko, this message translates to:
  /// **'보낼 카드를 하나 이상 골라 주세요'**
  String get cardExportNoneSelected;

  /// Free 인쇄물 아래 띠 오른쪽 한 줄 (로고 옆)
  ///
  /// In ko, this message translates to:
  /// **'일상을 함께 | 이룸 행동카드'**
  String get printBrandTagline;

  /// 픽토그램을 쓴 인쇄물 출처 표기 (라이선스 조건)
  ///
  /// In ko, this message translates to:
  /// **'그림: Mulberry Symbols (CC BY-SA 4.0)'**
  String get cardExportPictogramCredit;

  /// 이모지 그림을 쓴 인쇄물 출처 표기 (라이선스 조건, #1149)
  ///
  /// In ko, this message translates to:
  /// **'그림: Twemoji (CC BY 4.0)'**
  String get cardExportEmojiCredit;

  /// 오려 쓰는 카드 한 쪽 장수 (줄 값 · 시트 고르기)
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}장}}'**
  String cardExportPerPage(int count);

  /// 인쇄용으로 받기 줄: 받는 형태 (누르면 형태 시트) #1224
  ///
  /// In ko, this message translates to:
  /// **'형태'**
  String get cardExportFormatRow;

  /// 인쇄용으로 받기 묶음 머리: 용지 방향 · 장수 · 카드 크기 #1224
  ///
  /// In ko, this message translates to:
  /// **'배치'**
  String get cardExportLayoutSection;

  /// 인쇄용으로 받기 묶음 머리: 디자인 · 카드 문장 #1224
  ///
  /// In ko, this message translates to:
  /// **'꾸밈'**
  String get cardExportStyleSection;

  /// 인쇄용으로 받기 줄: A4 세로·가로 #1224
  ///
  /// In ko, this message translates to:
  /// **'용지 방향'**
  String get cardExportOrientationRow;

  /// 용지 방향 고르기 시트 제목 #1224
  ///
  /// In ko, this message translates to:
  /// **'용지를 어떻게 놓을까요?'**
  String get cardExportOrientationSheetTitle;

  /// 용지 방향 값: 세로 #1224
  ///
  /// In ko, this message translates to:
  /// **'세로'**
  String get cardExportOrientationPortrait;

  /// 용지 방향 값: 가로 #1224
  ///
  /// In ko, this message translates to:
  /// **'가로'**
  String get cardExportOrientationLandscape;

  /// 인쇄용으로 받기 줄: 오려 쓰는 카드 한 쪽 장수 #1224
  ///
  /// In ko, this message translates to:
  /// **'한 장에'**
  String get cardExportPerPageRow;

  /// 인쇄용으로 받기 줄: 카드 크기 #1224
  ///
  /// In ko, this message translates to:
  /// **'카드 크기'**
  String get cardExportCardSizeRow;

  /// 카드 크기 고르기 시트 제목 #1224
  ///
  /// In ko, this message translates to:
  /// **'카드를 얼마나 크게 넣을까요?'**
  String get cardExportCardSizeSheetTitle;

  /// 카드 크기 값: 칸에 맞춰 가장 크게 #1224
  ///
  /// In ko, this message translates to:
  /// **'꽉 차게'**
  String get cardExportCardSizeFit;

  /// 카드 크기 값: 조금 작게 #1224
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get cardExportCardSizeMedium;

  /// 카드 크기 값: 자를 여백을 넓게 #1224
  ///
  /// In ko, this message translates to:
  /// **'작게'**
  String get cardExportCardSizeSmall;

  /// Pro 를 살 수 없을 때 잠긴 형태·배치를 누르면 뜨는 안내 #1224
  ///
  /// In ko, this message translates to:
  /// **'Pro에서 쓸 수 있는 형태예요'**
  String get cardExportProLayoutLocked;

  /// Free 인쇄용으로 받기 아래 Pro 안내 제목 #1224
  ///
  /// In ko, this message translates to:
  /// **'Pro면 원하는 대로 받을 수 있어요'**
  String get cardExportUpsellTitle;

  /// Free 인쇄용으로 받기 아래 Pro 안내 한 줄 #1224
  ///
  /// In ko, this message translates to:
  /// **'일과 한 장, 오려 쓰는 카드, 한 장에 여러 장, 가로 용지, 디자인까지 골라요'**
  String get cardExportUpsellBody;

  /// 결제 직전 보호자 암호 확인 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'결제는 보호자만 할 수 있어요'**
  String get modeSwitchToPurchase;

  /// 혜택 줄: AI 맞춤 그림 방식 (그림 방식에서 열면 맨 위)
  ///
  /// In ko, this message translates to:
  /// **'카드마다 AI가 그려 줘요'**
  String get planBenefitAiImageStyles;

  /// 혜택 줄: 광고 없음
  ///
  /// In ko, this message translates to:
  /// **'광고 없이 써요'**
  String get planBenefitAdsRemoved;

  /// 혜택 줄: 주간 리포트
  ///
  /// In ko, this message translates to:
  /// **'주간 리포트를 받아요'**
  String get planBenefitWeeklyReport;

  /// 혜택 줄: 반복 일과·주간 계획·이룸이 기기 알림
  ///
  /// In ko, this message translates to:
  /// **'요일과 시각을 정해 매일 보내요'**
  String get planBenefitRoutineSchedule;

  /// 혜택 줄: AI 메모
  ///
  /// In ko, this message translates to:
  /// **'내가 고친 방식을 기억해요'**
  String get planBenefitRoutineMemory;

  /// 혜택 줄: 보호자 목소리
  ///
  /// In ko, this message translates to:
  /// **'보호자 목소리로 카드를 읽어 줘요'**
  String get planBenefitGuardianVoice;

  /// 혜택 줄: 일과 생성 글 무료 (카드 그림은 장수만큼 크레딧)
  ///
  /// In ko, this message translates to:
  /// **'일과 글은 크레딧 없이 써요'**
  String get planBenefitFreeRoutineText;

  /// 혜택 줄: 다시 그리기 무료 (하루 한도를 모를 때)
  ///
  /// In ko, this message translates to:
  /// **'하루 정해진 횟수까지 크레딧 없이 다시 그려요'**
  String get planBenefitFreeImageRegenerate;

  /// 혜택 줄: 다시 그리기 무료. count 는 서버 하루 무료 한도
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{하루 {count}번까지 크레딧 없이 다시 그려요}}'**
  String planBenefitFreeImageRegenerateDaily(int count);

  /// 혜택 줄: 주간 크레딧
  ///
  /// In ko, this message translates to:
  /// **'매주 크레딧을 더 많이 받아요'**
  String get planBenefitMoreWeeklyCredits;

  /// 혜택 줄: 월간 크레딧
  ///
  /// In ko, this message translates to:
  /// **'매달 크레딧을 더 많이 받아요'**
  String get planBenefitMoreMonthlyCredits;

  /// 혜택 줄: 워터마크 없음
  ///
  /// In ko, this message translates to:
  /// **'인쇄물 아래 띠 없이 깔끔해요'**
  String get planBenefitCardExportWithoutWatermark;

  /// 혜택 줄: 카드 디자인 테마
  ///
  /// In ko, this message translates to:
  /// **'인쇄 디자인을 모두 골라요'**
  String get planBenefitCardExportAllThemes;

  /// 혜택 줄: 카드 내보내기 형태·배치 #1224
  ///
  /// In ko, this message translates to:
  /// **'일과 한 장, 오려 쓰는 카드로 인쇄해요'**
  String get planBenefitCardExportAllLayouts;

  /// 혜택 묶음 아래 안내
  ///
  /// In ko, this message translates to:
  /// **'Pro가 끝나도 만든 일과와 그림은 그대로 남아요'**
  String get planKeepContentNotice;

  /// 구독 기간 이름: 1개월
  ///
  /// In ko, this message translates to:
  /// **'1개월'**
  String get planPeriodMonthly;

  /// 구독 기간 이름: 1년
  ///
  /// In ko, this message translates to:
  /// **'1년'**
  String get planPeriodYearly;

  /// 결제 버튼
  ///
  /// In ko, this message translates to:
  /// **'구독 시작하기'**
  String get planSubscribe;

  /// 스토어 가격 불러오는 중
  ///
  /// In ko, this message translates to:
  /// **'가격을 불러오고 있어요'**
  String get planPriceLoading;

  /// 스토어 가격 불러오기 실패
  ///
  /// In ko, this message translates to:
  /// **'가격을 불러오지 못했어요'**
  String get planPriceFailed;

  /// 구매 복원 글자 버튼 · 설정 줄
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get planRestore;

  /// 이용약관 링크
  ///
  /// In ko, this message translates to:
  /// **'이용약관'**
  String get planTermsOfUse;

  /// 개인정보처리방침 링크
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침'**
  String get planPrivacyPolicy;

  /// 스토어 구독 관리 화면 열기
  ///
  /// In ko, this message translates to:
  /// **'구독 관리'**
  String get planManageSubscription;

  /// 법적 문구 — #1079 확정 전 초안 · App Store 자동 갱신 안내
  ///
  /// In ko, this message translates to:
  /// **'결제는 구매를 확인할 때 Apple ID 계정으로 청구돼요. 기간이 끝나기 최소 24시간 전에 해지하지 않으면 같은 기간과 가격으로 자동 갱신되고, 기간이 끝나기 전 24시간 안에 다음 요금이 청구돼요.'**
  String get planLegalBillingAppStore;

  /// 법적 문구 — #1079 확정 전 초안 · App Store 해지 안내
  ///
  /// In ko, this message translates to:
  /// **'구독 관리와 해지는 기기 설정의 Apple ID > 구독에서 할 수 있어요. 해지해도 남은 기간까지는 Pro를 쓸 수 있어요.'**
  String get planLegalCancelAppStore;

  /// 법적 문구 — #1079 확정 전 초안 · Google Play 자동 갱신 안내
  ///
  /// In ko, this message translates to:
  /// **'결제는 구매를 확인할 때 Google Play 계정으로 청구돼요. 해지하기 전까지 같은 기간과 가격으로 자동 갱신돼요.'**
  String get planLegalBillingPlayStore;

  /// 법적 문구 — #1079 확정 전 초안 · Google Play 해지 안내
  ///
  /// In ko, this message translates to:
  /// **'구독 관리와 해지는 Google Play 스토어의 결제 및 정기 결제 > 정기 결제에서 할 수 있어요. 해지해도 남은 기간까지는 Pro를 쓸 수 있어요.'**
  String get planLegalCancelPlayStore;

  /// 무료 체험 기간 (스토어 값, 일 단위) #1166
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}일}}'**
  String planTrialDays(int count);

  /// 무료 체험 기간 (스토어 값, 달 단위) #1166
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개월}}'**
  String planTrialMonths(int count);

  /// 무료 체험 기간 (스토어 값, 해 단위) #1166
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}년}}'**
  String planTrialYears(int count);

  /// 고른 상품에 체험이 있을 때 결제 버튼 #1166
  ///
  /// In ko, this message translates to:
  /// **'{trial} 무료로 시작하기'**
  String planStartFreeTrial(String trial);

  /// 법적 문구 — #1079 확정 전 초안 · App Store 무료 체험 해지 안내 (체험 상품이 있을 때만) #1166
  ///
  /// In ko, this message translates to:
  /// **'무료 체험이 끝나기 최소 24시간 전에 해지하면 요금이 청구되지 않아요.'**
  String get planLegalTrialAppStore;

  /// 법적 문구 — #1079 확정 전 초안 · Google Play 무료 체험 해지 안내 (체험 상품이 있을 때만) #1166
  ///
  /// In ko, this message translates to:
  /// **'무료 체험 중에 해지하면 요금이 청구되지 않아요.'**
  String get planLegalTrialPlayStore;

  /// 서버 확인 중 (서버라는 말은 쓰지 않음)
  ///
  /// In ko, this message translates to:
  /// **'결제를 확인하고 있어요'**
  String get planVerifying;

  /// 가족 공유 구매 요청 등 스토어가 결제를 미룸
  ///
  /// In ko, this message translates to:
  /// **'결제 허락을 요청했어요'**
  String get planStorePendingTitle;

  /// 구매 요청 대기 설명
  ///
  /// In ko, this message translates to:
  /// **'허락을 받으면 Pro가 켜져요. 이 화면은 닫아도 돼요.'**
  String get planStorePendingBody;

  /// 결제는 됐지만 아직 Pro가 안 켜짐
  ///
  /// In ko, this message translates to:
  /// **'결제를 확인하고 있어요'**
  String get planVerificationPendingTitle;

  /// 확인 대기 설명 — 결제를 다시 요구하지 않음
  ///
  /// In ko, this message translates to:
  /// **'다시 결제하지 않아도 돼요. 앱을 다시 열면 한 번 더 확인해요'**
  String get planVerificationPendingBody;

  /// 확인 대기 상태에서 다시 확인
  ///
  /// In ko, this message translates to:
  /// **'다시 확인하기'**
  String get planVerificationRetry;

  /// Pro 구독 직후 열린 혜택 안내 닫기 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get planActivatedStart;

  /// 결제 완료
  ///
  /// In ko, this message translates to:
  /// **'Pro를 시작했어요'**
  String get planActivatedTitle;

  /// 서버가 확인했지만 Pro 아님
  ///
  /// In ko, this message translates to:
  /// **'Pro가 켜지지 않았어요'**
  String get planNotActivatedTitle;

  /// 결제했는데 Pro 가 안 켜졌을 때 확인 경로 (iOS)
  ///
  /// In ko, this message translates to:
  /// **'App Store 앱 → 오른쪽 위 내 사진 → 구독에서 이룸 구독을 확인해 주세요'**
  String get planNotActivatedBodyApple;

  /// 결제했는데 Pro 가 안 켜졌을 때 확인 경로 (Android)
  ///
  /// In ko, this message translates to:
  /// **'Play 스토어 앱 → 오른쪽 위 프로필 → 결제 및 정기 결제 → 정기 결제에서 이룸 구독을 확인해 주세요'**
  String get planNotActivatedBodyGoogle;

  /// Pro 가 안 켜졌을 때 스토어 구독 화면 열기 버튼 (iOS)
  ///
  /// In ko, this message translates to:
  /// **'App Store에서 확인하기'**
  String get planOpenAppStore;

  /// Pro 가 안 켜졌을 때 스토어 구독 화면 열기 버튼 (Android)
  ///
  /// In ko, this message translates to:
  /// **'Play 스토어에서 확인하기'**
  String get planOpenPlayStore;

  /// 이미 Pro 인 보호자가 요금제 화면을 엶
  ///
  /// In ko, this message translates to:
  /// **'Pro를 쓰고 있어요'**
  String get planAlreadyProTitle;

  /// 스토어 결제 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'결제하지 못했어요'**
  String get planPurchaseFailedTitle;

  /// 서버가 결제를 거부(400)했을 때 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'결제를 이 계정에 연결하지 못했어요'**
  String get planVerifyFailedTitle;

  /// 회원 id 를 몰라 결제를 시작하지 못함
  ///
  /// In ko, this message translates to:
  /// **'계정 정보를 확인하지 못했어요'**
  String get planAccountFailedTitle;

  /// 결제 실패 팝업 기본 안내
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해주세요'**
  String get planFailedFallback;

  /// 구매 복원 성공
  ///
  /// In ko, this message translates to:
  /// **'Pro를 되찾았어요'**
  String get planRestoreDone;

  /// 구매 복원: 활성 구독 없음
  ///
  /// In ko, this message translates to:
  /// **'되찾을 구독이 없어요'**
  String get planRestoreNothing;

  /// 구매 복원: 되찾을 구독이 없을 때 안내 (iOS)
  ///
  /// In ko, this message translates to:
  /// **'구독할 때 쓴 Apple ID로 이 기기에 로그인돼 있는지 확인해 주세요. 이룸에도 구독할 때와 같은 방법으로 로그인해야 해요'**
  String get planRestoreNothingHintApple;

  /// 구매 복원: 되찾을 구독이 없을 때 안내 (Android)
  ///
  /// In ko, this message translates to:
  /// **'구독할 때 쓴 Google 계정이 Play 스토어에 로그인돼 있는지 확인해 주세요. 이룸에도 구독할 때와 같은 방법으로 로그인해야 해요'**
  String get planRestoreNothingHintGoogle;

  /// 구매 복원 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'구매를 복원하지 못했어요'**
  String get planRestoreFailedTitle;

  /// 구매 복원 중 대기 팝업
  ///
  /// In ko, this message translates to:
  /// **'구매 내역을 확인하고 있어요'**
  String get planRestoring;

  /// 스토어 구독 관리 화면 열기 실패
  ///
  /// In ko, this message translates to:
  /// **'구독 관리 화면을 열지 못했어요'**
  String get planManageFailed;

  /// 약관 링크 열기 실패
  ///
  /// In ko, this message translates to:
  /// **'링크를 열지 못했어요'**
  String get planLinkFailed;

  /// 설정 > 내 요금제 줄 이름
  ///
  /// In ko, this message translates to:
  /// **'내 요금제'**
  String get planSettingsLabel;

  /// 요금제 상태: 무료
  ///
  /// In ko, this message translates to:
  /// **'Free'**
  String get planStatusFree;

  /// 요금제 상태: Pro (기간 제한 없음)
  ///
  /// In ko, this message translates to:
  /// **'Pro'**
  String get planStatusPro;

  /// 요금제 상태: 자동 갱신 예정
  ///
  /// In ko, this message translates to:
  /// **'Pro, {date}에 갱신돼요'**
  String planStatusRenewing(String date);

  /// 요금제 상태: 끝나는 날만 앎
  ///
  /// In ko, this message translates to:
  /// **'Pro, {date}까지'**
  String planStatusUntil(String date);

  /// 요금제 상태: 해지 예약
  ///
  /// In ko, this message translates to:
  /// **'Pro, {date}에 끝나요'**
  String planStatusCancelScheduled(String date);

  /// 요금제 상태: 결제 실패 유예 중
  ///
  /// In ko, this message translates to:
  /// **'Pro, 결제 확인이 필요해요'**
  String get planStatusGracePeriod;

  /// 요금제 상태: 가입 체험 중. days 는 끝나기까지 남은 날(1 이상)
  ///
  /// In ko, this message translates to:
  /// **'Pro 체험 중, {days}일 남았어요'**
  String planStatusTrial(int days);

  /// 요금제 상태: 가입 체험 마지막 날
  ///
  /// In ko, this message translates to:
  /// **'Pro 체험 중, 오늘까지예요'**
  String get planStatusTrialLastDay;

  /// 요금제 상태: 기존 가입자 Pro 선물 (설정 줄 값)
  ///
  /// In ko, this message translates to:
  /// **'Pro 선물'**
  String get planStatusGift;

  /// 요금제 상태: 기존 가입자 Pro 선물, 끝나는 날까지
  ///
  /// In ko, this message translates to:
  /// **'Pro 선물, {date}까지'**
  String planStatusGiftUntil(String date);

  /// 설정 내 요금제 묶음 아래 한 줄: 자동 갱신 예정 (줄 값은 Pro)
  ///
  /// In ko, this message translates to:
  /// **'{date}에 갱신돼요'**
  String planStatusRenewingFooter(String date);

  /// 설정 내 요금제 묶음 아래 한 줄: 끝나는 날만 앎
  ///
  /// In ko, this message translates to:
  /// **'{date}까지 쓸 수 있어요'**
  String planStatusUntilFooter(String date);

  /// 설정 내 요금제 묶음 아래 한 줄: 해지 예약
  ///
  /// In ko, this message translates to:
  /// **'{date}에 끝나요'**
  String planStatusCancelScheduledFooter(String date);

  /// 설정 내 요금제 묶음 아래 한 줄: 결제 실패 유예 중
  ///
  /// In ko, this message translates to:
  /// **'결제 수단을 확인해 주세요'**
  String get planStatusGracePeriodFooter;

  /// 요금제 화면을 여는 버튼 문구 하나 (미리 보기 판·글자 링크·크레딧 부족 팝업 공통, ProUpsellButton, #1170)
  ///
  /// In ko, this message translates to:
  /// **'Pro 알아보기'**
  String get planLearnPro;

  /// 주간 리포트 화면 제목 · 내 정보 바로가기 줄
  ///
  /// In ko, this message translates to:
  /// **'주간 리포트'**
  String get weeklyReportTitle;

  /// 주간 리포트 주 범위. 예: 11월 2일 ~ 11월 8일
  ///
  /// In ko, this message translates to:
  /// **'{startMonth}월 {startDay}일 ~ {endMonth}월 {endDay}일'**
  String weeklyReportWeekRange(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  );

  /// 주 고르기 줄 · 이번 주일 때. range 는 weeklyReportWeekRange
  ///
  /// In ko, this message translates to:
  /// **'이번 주 · {range}'**
  String weeklyReportThisWeekRange(String range);

  /// 주 고르기 왼쪽 화살표 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'지난주 보기'**
  String get weeklyReportPreviousWeek;

  /// 주 고르기 오른쪽 화살표 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'다음 주 보기'**
  String get weeklyReportNextWeek;

  /// 요약 카드 큰 숫자 옆 이름
  ///
  /// In ko, this message translates to:
  /// **'일과 완료율'**
  String get weeklyReportCompletionLabel;

  /// 완료율 숫자
  ///
  /// In ko, this message translates to:
  /// **'{percent}%'**
  String weeklyReportPercent(int percent);

  /// 요약 카드 한 줄 (사실만, 평가 없음)
  ///
  /// In ko, this message translates to:
  /// **'{sent, plural, other{보낸 일과 {sent}개 중 {completed}개를 마쳤어요}}'**
  String weeklyReportCompletionSummary(int sent, int completed);

  /// 하루 칸 · 그 날 보낸 일과가 없을 때
  ///
  /// In ko, this message translates to:
  /// **'-'**
  String get weeklyReportDayNone;

  /// 한 장 하루 칸 · 마친 일과/보낸 일과
  ///
  /// In ko, this message translates to:
  /// **'{completed}/{sent}'**
  String weeklyReportDayCount(int completed, int sent);

  /// 줄 이름 · 이 주에 마친 카드 수
  ///
  /// In ko, this message translates to:
  /// **'받은 별'**
  String get weeklyReportStars;

  /// 줄 이름 · 보상을 정해 둔 일과 중 끝까지 마친 수
  ///
  /// In ko, this message translates to:
  /// **'보상까지 간 일과'**
  String get weeklyReportRewards;

  /// 줄 이름 · 일과를 하나 이상 마친 날이 이어진 가장 긴 날 수
  ///
  /// In ko, this message translates to:
  /// **'연속으로 마친 날'**
  String get weeklyReportStreak;

  /// 개수 값
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개}}'**
  String weeklyReportCount(int count);

  /// 날 수 값
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}일}}'**
  String weeklyReportDays(int count);

  /// 일과별 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'일과별 기록'**
  String get weeklyReportRoutinesSection;

  /// 일과 줄 값 · 보낸 횟수 중 마친 횟수
  ///
  /// In ko, this message translates to:
  /// **'{sent, plural, other{{sent}번 중 {completed}번 마침}}'**
  String weeklyReportRoutineValue(int sent, int completed);

  /// 지난 날 마치지 않고 남은 카드 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'자주 남은 카드'**
  String get weeklyReportRemainingSection;

  /// 남은 카드 줄 이름 · 일과 이름 · 카드 이름
  ///
  /// In ko, this message translates to:
  /// **'{routine} · {step}'**
  String weeklyReportRemainingLabel(String routine, String step);

  /// 남은 카드 횟수 값
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}번}}'**
  String weeklyReportTimes(int count);

  /// 빈 상태 제목
  ///
  /// In ko, this message translates to:
  /// **'이 주에는 보낸 일과가 없어요'**
  String get weeklyReportEmptyTitle;

  /// 빈 상태 안내 한 줄
  ///
  /// In ko, this message translates to:
  /// **'일과를 보내면 이룸이가 마친 기록이 여기에 모여요'**
  String get weeklyReportEmptyBody;

  /// 불러오기 실패 문구 (에러 코드와 다시 하기가 함께 보임)
  ///
  /// In ko, this message translates to:
  /// **'주간 리포트를 불러오지 못했어요'**
  String get weeklyReportLoadFailed;

  /// Pro 가 아닌 계정이 화면에 들어왔을 때 (입구는 숨김)
  ///
  /// In ko, this message translates to:
  /// **'주간 리포트는 Pro에서 볼 수 있어요'**
  String get weeklyReportNotIncluded;

  /// 리포트 저장 시트: 한 장을 PNG 로 공유 시트에
  ///
  /// In ko, this message translates to:
  /// **'이미지'**
  String get weeklyReportShareImage;

  /// 리포트 저장 시트: 한 장을 A4 PDF 로 공유 시트에
  ///
  /// In ko, this message translates to:
  /// **'PDF'**
  String get weeklyReportSharePdf;

  /// 한 장 굽기 실패 팝업
  ///
  /// In ko, this message translates to:
  /// **'보낼 한 장을 만들지 못했어요'**
  String get weeklyReportShareFailed;

  /// 보낼 한 장 제목 · 이룸이 이름
  ///
  /// In ko, this message translates to:
  /// **'{name}의 한 주'**
  String weeklyReportShareTitle(String name);

  /// 보낼 한 장 아래 출처 한 줄 (평가가 아니라 기록이라는 뜻)
  ///
  /// In ko, this message translates to:
  /// **'이룸 앱에 남은 완료 기록을 센 내용이에요'**
  String get weeklyReportShareNote;

  /// 주간 리포트: 숫자 3개 위 구역 제목
  ///
  /// In ko, this message translates to:
  /// **'한 주 기록'**
  String get weeklyReportRecordSection;

  /// 주간 리포트 맨 위 도넛 옆 작은 제목: 완료율
  ///
  /// In ko, this message translates to:
  /// **'완료율'**
  String get weeklyReportDonutLabel;

  /// 도넛 옆 한 줄: 보낸 일과 중 끝낸 일과 수
  ///
  /// In ko, this message translates to:
  /// **'{sent, plural, other{일과 {sent}개 중 {completed}개를 끝냈어요}}'**
  String weeklyReportDonutSummary(int sent, int completed);

  /// 도넛 낭독 라벨: 완료율 퍼센트와 보낸 일과 중 끝낸 수
  ///
  /// In ko, this message translates to:
  /// **'{sent, plural, other{완료율 {percent}퍼센트, 일과 {sent}개 중 {completed}개를 끝냈어요}}'**
  String weeklyReportDonutSemantics(int percent, int sent, int completed);

  /// 요일별 막대 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'요일별 기록'**
  String get weeklyReportDaysSection;

  /// 요일 막대 낭독 라벨. weekday 는 짧은 요일 이름
  ///
  /// In ko, this message translates to:
  /// **'{sent, plural, other{{weekday}요일 일과 {sent}개 중 {completed}개 끝냄}}'**
  String weeklyReportDayBarSemantics(String weekday, int sent, int completed);

  /// 보낸 일과가 없는 요일 막대 낭독 라벨
  ///
  /// In ko, this message translates to:
  /// **'{weekday}요일 보낸 일과 없음'**
  String weeklyReportDayBarEmptySemantics(String weekday);

  /// 주별 추이 선 그래프 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'지난 주들과 견주기'**
  String get weeklyReportTrendSection;

  /// 주별 추이 아래 날짜 이름: 그 주 월요일 월/일
  ///
  /// In ko, this message translates to:
  /// **'{month}/{day}'**
  String weeklyReportTrendWeekLabel(int month, int day);

  /// 주별 추이 점 낭독 라벨: 그 주 월요일 날짜와 끝낸 일과 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{month}월 {day}일 주에 일과 {count}개 끝냄}}'**
  String weeklyReportTrendPointSemantics(int month, int day, int count);

  /// 주간 리포트 돌아보기 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'잘한 것'**
  String get weeklyReportInsightHighlightTitle;

  /// 잘한 것: 일과를 처음 끝까지 함. routine 은 일과 이름, batchim 은 한국어 조사 선택용(yes/no)
  ///
  /// In ko, this message translates to:
  /// **'{routine}{batchim, select, yes{을} other{를}} 이번 주에 처음 끝까지 했어요'**
  String weeklyReportInsightHighlightFirst(String routine, String batchim);

  /// 잘한 것: 보낸 횟수를 모두 끝까지 함. batchim 은 한국어 조사 선택용(yes/no)
  ///
  /// In ko, this message translates to:
  /// **'{routine}{batchim, select, yes{을} other{를}} {count}번 모두 끝까지 했어요'**
  String weeklyReportInsightHighlightEvery(
    String routine,
    String batchim,
    int count,
  );

  /// 잘한 것: 연속으로 끝낸 날 수
  ///
  /// In ko, this message translates to:
  /// **'{days}일 이어서 일과를 끝냈어요'**
  String weeklyReportInsightHighlightStreak(int days);

  /// 잘한 것 아래 작은 글. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'오늘 {name}에게 말해 주세요'**
  String weeklyReportInsightHighlightHint(String name);

  /// 주간 리포트 돌아보기 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'자주 멈춘 곳'**
  String get weeklyReportInsightStuckTitle;

  /// 자주 멈춘 곳 문장
  ///
  /// In ko, this message translates to:
  /// **'{routine}의 {step}에서 {sent}번 중 {remained}번 멈췄어요'**
  String weeklyReportInsightStuckLine(
    String routine,
    String step,
    int sent,
    int remained,
  );

  /// 자주 멈춘 곳 아래 작은 글: 글을 줄이거나 나누기
  ///
  /// In ko, this message translates to:
  /// **'카드 글을 더 짧게 바꾸거나 둘로 나눠 볼 수 있어요'**
  String get weeklyReportInsightStuckShorten;

  /// 자주 멈춘 곳 아래 작은 글: 목소리·사진 붙이기
  ///
  /// In ko, this message translates to:
  /// **'목소리나 사진을 붙여 볼 수 있어요'**
  String get weeklyReportInsightStuckAddMedia;

  /// 자주 멈춘 곳 버튼. 그 카드가 든 일과의 편집 화면으로 감
  ///
  /// In ko, this message translates to:
  /// **'{step} 카드 고치기'**
  String weeklyReportInsightStuckFix(String step);

  /// 자주 멈춘 곳 버튼으로 일과를 못 열었을 때 실패 팝업 문장
  ///
  /// In ko, this message translates to:
  /// **'고칠 일과를 열지 못했어요'**
  String get weeklyReportInsightStuckFixFailed;

  /// 주간 리포트 돌아보기 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'지난주와 달라진 점'**
  String get weeklyReportInsightTrendTitle;

  /// 지난주보다 늘었을 때
  ///
  /// In ko, this message translates to:
  /// **'끝낸 일과가 {before}개에서 {after}개로 늘었어요'**
  String weeklyReportInsightTrendUp(int before, int after);

  /// 지난주보다 줄었을 때 (단정하지 않는 말)
  ///
  /// In ko, this message translates to:
  /// **'끝낸 일과가 {before}개에서 {after}개가 됐어요'**
  String weeklyReportInsightTrendDown(int before, int after);

  /// 지난주와 같을 때
  ///
  /// In ko, this message translates to:
  /// **'지난주와 같이 {after}개를 끝냈어요'**
  String weeklyReportInsightTrendSame(int after);

  /// 달라진 점 막대 이름: 지난주 끝낸 일과 수
  ///
  /// In ko, this message translates to:
  /// **'지난주 {count}'**
  String weeklyReportInsightTrendBarPrevious(int count);

  /// 달라진 점 막대 이름: 이번 주 끝낸 일과 수
  ///
  /// In ko, this message translates to:
  /// **'이번 주 {count}'**
  String weeklyReportInsightTrendBarCurrent(int count);

  /// 주간 리포트 돌아보기 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'걸린 시간'**
  String get weeklyReportInsightDurationTitle;

  /// 일과 평균 걸린 시간 변화 (늘든 줄든 같은 말)
  ///
  /// In ko, this message translates to:
  /// **'{routine}에 걸린 시간이 {before}분에서 {after}분이 됐어요'**
  String weeklyReportInsightDurationLine(String routine, int before, int after);

  /// 주간 리포트 돌아보기 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'가장 오래 머문 카드'**
  String get weeklyReportInsightSlowestTitle;

  /// 가장 오래 머문 카드 문장
  ///
  /// In ko, this message translates to:
  /// **'{routine}의 {step}에서 평균 {minutes}분 머물렀어요'**
  String weeklyReportInsightSlowestLine(
    String routine,
    String step,
    int minutes,
  );

  /// 숫자 3개 중 첫째 이름: 이 주에 끝낸 일과 수
  ///
  /// In ko, this message translates to:
  /// **'끝낸 일과'**
  String get weeklyReportStatCompleted;

  /// 숫자 3개 중 셋째 이름: 마치지 않고 남은 카드 수
  ///
  /// In ko, this message translates to:
  /// **'남은 카드'**
  String get weeklyReportStatRemaining;

  /// 일과별 기록 줄 오른쪽 값: 보낸 횟수 중 마친 횟수
  ///
  /// In ko, this message translates to:
  /// **'{sent, plural, other{{sent}번 중 {completed}번}}'**
  String weeklyReportRoutineRatio(int sent, int completed);

  /// 주간 리포트 아래 버튼: 누르면 PDF·이미지 고르기 시트
  ///
  /// In ko, this message translates to:
  /// **'리포트 저장하기'**
  String get weeklyReportSave;

  /// 리포트 저장 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'리포트를 어떻게 저장할까요?'**
  String get weeklyReportSaveSheetTitle;

  /// 주간 리포트 아래 글자 링크: 지난 리포트 목록 시트
  ///
  /// In ko, this message translates to:
  /// **'지난 리포트 보기'**
  String get weeklyReportPastReports;

  /// 지난 리포트 목록 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'지난 리포트'**
  String get weeklyReportPastSheetTitle;

  /// 지난 리포트 줄 오른쪽 값: 그 주에 끝낸 일과 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{일과 {count}개 끝냄}}'**
  String weeklyReportPastWeekValue(int count);

  /// 지난 리포트 목록이 비었을 때
  ///
  /// In ko, this message translates to:
  /// **'아직 지난 리포트가 없어요'**
  String get weeklyReportPastEmpty;

  /// 지난 리포트 목록 불러오기 실패 (에러 코드와 다시 하기가 함께 보임)
  ///
  /// In ko, this message translates to:
  /// **'지난 리포트를 불러오지 못했어요'**
  String get weeklyReportPastLoadFailed;

  /// Free 에게 미리 보여 주는 주 리포트 위 한 줄
  ///
  /// In ko, this message translates to:
  /// **'첫 리포트는 Pro 없이 미리 볼 수 있어요'**
  String get weeklyReportFreePreviewNote;

  /// Free 첫 리포트 미리 보기 끝 버튼 (요금제 화면을 주간 리포트 혜택 위로 엶)
  ///
  /// In ko, this message translates to:
  /// **'다음 주 리포트도 받아 보기'**
  String get weeklyReportNextWeekUpsell;

  /// 일과 상세 시트(일과관리) 반복 줄 — 아직 정하지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'요일·시각 정하기'**
  String get routineScheduleRowOff;

  /// 반복 줄 접근성 이름
  ///
  /// In ko, this message translates to:
  /// **'반복 요일과 시각'**
  String get routineScheduleRowLabel;

  /// 반복 줄 요약. days 는 요일 목록(예: 월·수·금) 또는 매일·평일·주말, time 은 기기 형식 시각 (예: 오전 8:00)
  ///
  /// In ko, this message translates to:
  /// **'{days} {time}'**
  String routineScheduleSummary(String days, String time);

  /// 일곱 요일 모두 골랐을 때
  ///
  /// In ko, this message translates to:
  /// **'매일'**
  String get routineScheduleEveryDay;

  /// 월~금만 골랐을 때
  ///
  /// In ko, this message translates to:
  /// **'평일'**
  String get routineScheduleWeekdaysOnly;

  /// 토·일만 골랐을 때
  ///
  /// In ko, this message translates to:
  /// **'주말'**
  String get routineScheduleWeekendOnly;

  /// 요일 목록 사이 구분 (예: 월·수·금)
  ///
  /// In ko, this message translates to:
  /// **'·'**
  String get routineScheduleDaySeparator;

  /// 반복 줄·주간 계획 — 저장한 보호자의 Pro 가 끝나 반복이 멈춤 (예약은 남아 있음)
  ///
  /// In ko, this message translates to:
  /// **'Pro가 끝나 멈췄어요'**
  String get routineSchedulePaused;

  /// 주간 계획·반복 시트 — 멈춘 예약 안내
  ///
  /// In ko, this message translates to:
  /// **'Pro가 끝나 반복을 멈췄어요. 정해 둔 요일과 시각은 그대로 남아 있어요'**
  String get routineSchedulePausedNote;

  /// 반복 요일·시각 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'언제 할까요?'**
  String get routineScheduleSheetTitle;

  /// 반복 요일·시각 시트 설명
  ///
  /// In ko, this message translates to:
  /// **'고른 요일마다 이 일과가 오늘 일과로 가요'**
  String get routineScheduleSheetBody;

  /// 반복 시트 — 요일 고르기 라벨
  ///
  /// In ko, this message translates to:
  /// **'요일'**
  String get routineScheduleDaysLabel;

  /// 반복 시트 — 시각 바퀴 라벨
  ///
  /// In ko, this message translates to:
  /// **'시각'**
  String get routineScheduleTimeLabel;

  /// 반복 시트 — 이룸이 기기 알림 스위치
  ///
  /// In ko, this message translates to:
  /// **'그 시각에 이룸이 기기에 알리기'**
  String get routineScheduleNotifyElumi;

  /// 반복 시트·주간 계획 — 연결된 이룸이 기기에 알림 권한이 없음
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기 알림이 꺼져 있어요'**
  String get routineScheduleElumiNotificationOff;

  /// 알림 꺼짐 안내 둘째 줄
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기의 설정에서 이룸 알림을 켜 주세요'**
  String get routineScheduleElumiNotificationOffHint;

  /// 반복 시트·주간 계획 — 연결된 이룸이 기기가 없음
  ///
  /// In ko, this message translates to:
  /// **'이룸이 기기를 연결하면 그 시각에 알림이 가요'**
  String get routineScheduleElumiNoDevice;

  /// 반복 시트 — 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get routineScheduleSave;

  /// 반복 시트 — 끄기 글자 버튼
  ///
  /// In ko, this message translates to:
  /// **'반복 끄기'**
  String get routineScheduleTurnOff;

  /// 반복 저장 성공 토스트
  ///
  /// In ko, this message translates to:
  /// **'요일과 시각을 저장했어요'**
  String get routineScheduleSavedToast;

  /// 반복 끄기 성공 토스트
  ///
  /// In ko, this message translates to:
  /// **'반복을 껐어요'**
  String get routineScheduleTurnedOffToast;

  /// 반복 저장·끄기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'저장하지 못했어요'**
  String get routineScheduleSaveFailedTitle;

  /// 반복 저장·끄기 실패 팝업 기본 문장
  ///
  /// In ko, this message translates to:
  /// **'잠시 뒤 다시 해 주세요'**
  String get routineScheduleSaveFailedFallback;

  /// 반복 시트 — 요일을 하나도 안 골랐을 때 저장 버튼 위 안내
  ///
  /// In ko, this message translates to:
  /// **'요일을 하나 이상 골라 주세요'**
  String get routineSchedulePickDayHint;

  /// 반복 시트 — Free(판매 중)라 저장 버튼이 꺼진 이유. 아래에 Pro 알아보기 입구
  ///
  /// In ko, this message translates to:
  /// **'반복 일과는 Pro에서 저장할 수 있어요'**
  String get routineScheduleProNote;

  /// 일과관리 머리 — 주간 계획 화면 입구 알약
  ///
  /// In ko, this message translates to:
  /// **'주간 계획'**
  String get weeklyPlanEntry;

  /// 주간 계획 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'주간 계획'**
  String get weeklyPlanTitle;

  /// 주간 계획 요일 묶음 제목. weekday 는 weekdayShort 결과
  ///
  /// In ko, this message translates to:
  /// **'{weekday}요일'**
  String weeklyPlanDayTitle(String weekday);

  /// 주간 계획 — 오늘 요일 칩
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get weeklyPlanToday;

  /// 주간 계획 — 그 요일에 반복 일과가 없음
  ///
  /// In ko, this message translates to:
  /// **'정한 일과가 없어요'**
  String get weeklyPlanEmptyDay;

  /// 주간 계획 — 반복 일과가 하나도 없을 때 제목
  ///
  /// In ko, this message translates to:
  /// **'아직 요일을 정한 일과가 없어요'**
  String get weeklyPlanEmptyTitle;

  /// 주간 계획 빈 상태 안내
  ///
  /// In ko, this message translates to:
  /// **'일과 관리에서 일과를 누르고 요일·시각을 정해 보세요'**
  String get weeklyPlanEmptyBody;

  /// 주간 계획 불러오기 실패
  ///
  /// In ko, this message translates to:
  /// **'주간 계획을 불러오지 못했어요'**
  String get weeklyPlanLoadFailed;

  /// 주간 계획 줄 — 이룸이 기기 알림을 끈 반복 일과
  ///
  /// In ko, this message translates to:
  /// **'알림 없음'**
  String get weeklyPlanNotifyOff;

  /// 주간 계획 줄 메타 사이 구분 (예: 오후 3:00 · 알림 없음)
  ///
  /// In ko, this message translates to:
  /// **' · '**
  String get weeklyPlanMetaSeparator;

  /// 카드 수정 시트의 보호자 목소리 칸 — 녹음 전 버튼 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'내 목소리로 녹음하기'**
  String get guardianVoiceRecordAction;

  /// 카드 수정 시트의 보호자 목소리 칸 — 녹음 전 설명
  ///
  /// In ko, this message translates to:
  /// **'카드를 누르면 이 목소리가 들려요'**
  String get guardianVoiceRecordHint;

  /// 보호자 목소리를 녹음하는 동안 칸 글자. seconds 는 지난 초
  ///
  /// In ko, this message translates to:
  /// **'녹음하고 있어요 {seconds}초'**
  String guardianVoiceRecording(int seconds);

  /// 녹음하는 동안 칸 아래 줄 — 최대 길이 안내. seconds 는 최대 초
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초까지 녹음돼요'**
  String guardianVoiceRecordingLimit(int seconds);

  /// 녹음·미리 듣기를 멈추는 버튼 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'멈추기'**
  String get guardianVoiceStop;

  /// 보호자 목소리를 올리는 동안 칸 글자
  ///
  /// In ko, this message translates to:
  /// **'녹음을 저장하고 있어요'**
  String get guardianVoiceSaving;

  /// 녹음이 있을 때 칸 글자 — 이룸이 화면에서 이 녹음이 나온다는 뜻
  ///
  /// In ko, this message translates to:
  /// **'녹음했어요'**
  String get guardianVoiceSaved;

  /// 녹음 미리 듣기 버튼 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'듣기'**
  String get guardianVoicePlay;

  /// 녹음을 새로 하는 버튼 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'다시 녹음'**
  String get guardianVoiceRerecord;

  /// 녹음 지우기 버튼 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get guardianVoiceDelete;

  /// 녹음 지우기 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'녹음을 지울까요?'**
  String get guardianVoiceDeleteConfirmTitle;

  /// 녹음 지우기 확인 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'지우면 기본 목소리로 읽어 줘요'**
  String get guardianVoiceDeleteConfirmMessage;

  /// Pro 가 끝났는데 녹음이 남아 있을 때 칸 제목 — 녹음은 남아 있고 듣기·지우기만 된다
  ///
  /// In ko, this message translates to:
  /// **'기본 목소리로 읽어요'**
  String get guardianVoicePlanEnded;

  /// 마이크 권한이 막혔을 때 칸 제목
  ///
  /// In ko, this message translates to:
  /// **'마이크가 꺼져 있어요'**
  String get guardianVoiceMicDeniedTitle;

  /// 마이크 권한이 막혔을 때 칸 설명 — 앱은 계속 쓸 수 있다
  ///
  /// In ko, this message translates to:
  /// **'켜기 전까지 기본 목소리로 읽어요'**
  String get guardianVoiceMicDeniedBody;

  /// 마이크 권한이 막혔을 때 기기 설정을 여는 버튼
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get guardianVoiceOpenSettings;

  /// 녹음 올리기·지우기·듣기 실패 때 칸 제목
  ///
  /// In ko, this message translates to:
  /// **'녹음을 저장하지 못했어요'**
  String get guardianVoiceFailedTitle;

  /// 녹음 실패 안내의 다시 하기 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 하기'**
  String get guardianVoiceRetry;

  /// 녹음이 너무 짧을 때 실패 사유
  ///
  /// In ko, this message translates to:
  /// **'너무 짧아요. 말한 뒤에 멈추기를 눌러 주세요'**
  String get guardianVoiceTooShort;

  /// 녹음 시작·멈춤 실패 사유
  ///
  /// In ko, this message translates to:
  /// **'녹음하지 못했어요. 다시 해 주세요'**
  String get guardianVoiceRecordFailed;

  /// 녹음 파일이 1MB 를 넘을 때 실패 사유
  ///
  /// In ko, this message translates to:
  /// **'녹음 파일이 너무 커요. 조금 짧게 다시 녹음해 주세요'**
  String get guardianVoiceTooLarge;

  /// 녹음 미리 듣기 실패 사유
  ///
  /// In ko, this message translates to:
  /// **'녹음을 틀지 못했어요'**
  String get guardianVoicePlayFailed;

  /// 녹음 지우기 실패 사유
  ///
  /// In ko, this message translates to:
  /// **'녹음을 지우지 못했어요'**
  String get guardianVoiceDeleteFailed;

  /// 녹음 전 보호자 목소리 칸의 녹음 시작 버튼 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'녹음'**
  String get guardianVoiceRecordChip;

  /// Pro 가 끝났는데 녹음이 남아 있을 때 칸 설명
  ///
  /// In ko, this message translates to:
  /// **'Pro가 끝나도 녹음은 남겨 뒀어요'**
  String get guardianVoicePlanEndedHint;

  /// 설정 줄 — 이룸이별 AI 메모 화면으로 (Pro)
  ///
  /// In ko, this message translates to:
  /// **'AI 메모리'**
  String get guardianSettingsRoutineMemory;

  /// AI 메모리 위 카드 제목. name 은 이룸이 호칭
  ///
  /// In ko, this message translates to:
  /// **'{name} AI 메모리'**
  String memoryHeroTitle(String name);

  /// AI 메모리 위 카드 설명 (다른 보호자와 공유하지 않음)
  ///
  /// In ko, this message translates to:
  /// **'내가 고친 방식을 기억해서 다음 일과를 그렇게 만들어요. 나만 봐요'**
  String get memoryHeroBody;

  /// 숫자 칸 이름: 적용 중인 규칙 수
  ///
  /// In ko, this message translates to:
  /// **'적용 중'**
  String get memoryStatApplied;

  /// 숫자 칸 이름: 관찰 중인 규칙 수
  ///
  /// In ko, this message translates to:
  /// **'관찰 중'**
  String get memoryStatWatching;

  /// 숫자 칸 이름: 일과를 고쳐 보낸 기록 수
  ///
  /// In ko, this message translates to:
  /// **'수정 기록'**
  String get memoryStatEdits;

  /// 목록 머리: 적용 중 탭
  ///
  /// In ko, this message translates to:
  /// **'적용 중인 규칙'**
  String get memoryListAppliedHeader;

  /// 목록 머리 오른쪽 작은 글: 적용 중 탭
  ///
  /// In ko, this message translates to:
  /// **'새 일과에 쓰여요'**
  String get memoryListAppliedHint;

  /// 목록 머리: 관찰 중 탭
  ///
  /// In ko, this message translates to:
  /// **'관찰 중인 규칙'**
  String get memoryListWatchingHeader;

  /// 목록 머리 오른쪽 작은 글: 관찰 중 탭
  ///
  /// In ko, this message translates to:
  /// **'점이 다 차면 적용돼요'**
  String get memoryListWatchingHint;

  /// 목록 머리: 수정 기록 탭
  ///
  /// In ko, this message translates to:
  /// **'고쳐서 보낸 기록'**
  String get memoryListEditsHeader;

  /// 규칙 줄 아래 작은 글: AI 가 찾은 규칙 (몇 개 일과에서 봤나)
  ///
  /// In ko, this message translates to:
  /// **'AI가 찾음, 일과 {count}개'**
  String memoryRuleByAi(int count);

  /// 규칙 줄 아래 작은 글: 직접 적은 규칙
  ///
  /// In ko, this message translates to:
  /// **'내가 적음'**
  String get memoryRuleByMe;

  /// 수정 기록 줄: 카드 장수 변화
  ///
  /// In ko, this message translates to:
  /// **'{before}장 → {after}장'**
  String memoryEditCards(int before, int after);

  /// 수정 기록 줄: 고친 글 수
  ///
  /// In ko, this message translates to:
  /// **'글 {count}곳'**
  String memoryEditTexts(int count);

  /// 적용 중 탭 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'+ 규칙 직접 적기'**
  String get memoryAddRule;

  /// 맨 아래 스위치 이름 (서버 enabled)
  ///
  /// In ko, this message translates to:
  /// **'고친 내용에서 자동으로 찾기'**
  String get memoryAutoFind;

  /// 자동 찾기 스위치 아래 작은 글
  ///
  /// In ko, this message translates to:
  /// **'같은 수정이 일과 {count}개에서 반복되면 적용돼요'**
  String memoryAutoFindNote(int count);

  /// 규칙이 하나도 없을 때
  ///
  /// In ko, this message translates to:
  /// **'일과를 고쳐서 보내면 여기에 쌓여요'**
  String get memoryEmptyTitle;

  /// 수정 기록 탭이 비었을 때
  ///
  /// In ko, this message translates to:
  /// **'아직 고쳐서 보낸 일과가 없어요'**
  String get memoryEmptyEdits;

  /// 규칙 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'낱말 바꾸기'**
  String get memoryTypeWord;

  /// 규칙 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'카드 나누기'**
  String get memoryTypeSplit;

  /// 규칙 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'카드 합치기'**
  String get memoryTypeMerge;

  /// 규칙 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'카드 더하기'**
  String get memoryTypeAdd;

  /// 규칙 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'카드 빼기'**
  String get memoryTypeRemove;

  /// 규칙 종류 이름
  ///
  /// In ko, this message translates to:
  /// **'직접 적은 규칙'**
  String get memoryTypeManual;

  /// 규칙 시트 버튼: 관찰 중 규칙을 바로 적용
  ///
  /// In ko, this message translates to:
  /// **'지금 적용'**
  String get memoryApplyNow;

  /// 규칙 시트 버튼
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get memoryRuleDelete;

  /// 규칙 시트 버튼: 직접 적은 규칙 글 고치기
  ///
  /// In ko, this message translates to:
  /// **'수정'**
  String get memoryRuleEdit;

  /// 규칙 근거 한 줄
  ///
  /// In ko, this message translates to:
  /// **'{routine}, {month}월 {day}일'**
  String memoryEvidenceLine(String routine, int month, int day);

  /// AI 메모리 오른쪽 위 ··· 버튼 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'메뉴'**
  String get memoryMenuLabel;

  /// 오른쪽 위 메뉴
  ///
  /// In ko, this message translates to:
  /// **'파일로 내보내기'**
  String get memoryMenuExport;

  /// 오른쪽 위 메뉴 (위험)
  ///
  /// In ko, this message translates to:
  /// **'메모리 모두 지우기'**
  String get memoryMenuClear;

  /// 내보내기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'메모리를 내보내지 못했어요'**
  String get memoryExportFailed;

  /// 일과를 보낸 직후 카드 머리
  ///
  /// In ko, this message translates to:
  /// **'AI 메모리'**
  String get memoryObsTitle;

  /// 찾은 수정 종류에 맞는 말
  ///
  /// In ko, this message translates to:
  /// **'낱말을 이렇게 바꾸셨어요'**
  String get memoryObsWord;

  /// 찾은 수정 종류에 맞는 말
  ///
  /// In ko, this message translates to:
  /// **'카드를 나누셨어요'**
  String get memoryObsSplit;

  /// 찾은 수정 종류에 맞는 말
  ///
  /// In ko, this message translates to:
  /// **'카드를 합치셨어요'**
  String get memoryObsMerge;

  /// 찾은 수정 종류에 맞는 말
  ///
  /// In ko, this message translates to:
  /// **'카드를 더하셨어요'**
  String get memoryObsAdd;

  /// 찾은 수정 종류에 맞는 말
  ///
  /// In ko, this message translates to:
  /// **'카드를 빼셨어요'**
  String get memoryObsRemove;

  /// 찾은 수정 종류에 맞는 말
  ///
  /// In ko, this message translates to:
  /// **'이렇게 고치셨어요'**
  String get memoryObsManual;

  /// 일과를 보낸 직후 카드 질문
  ///
  /// In ko, this message translates to:
  /// **'{phrase}. 다음 일과에도 이렇게 할까요?'**
  String memoryObsAsk(String phrase);

  /// 카드 버튼: 규칙으로 적용
  ///
  /// In ko, this message translates to:
  /// **'항상 이렇게'**
  String get memoryObsAlways;

  /// 카드 버튼: 카드 닫기
  ///
  /// In ko, this message translates to:
  /// **'이번만'**
  String get memoryObsOnce;

  /// 항상 이렇게를 누른 뒤 카드 문구
  ///
  /// In ko, this message translates to:
  /// **'다음 일과부터 이렇게 만들어요'**
  String get memoryObsDone;

  /// 보이는 최대 2개 밖의 나머지
  ///
  /// In ko, this message translates to:
  /// **'AI 메모리에서 {count}개 더 보기'**
  String memoryObsMore(int count);

  /// 새 일과 결과 화면 제목 아래 알약
  ///
  /// In ko, this message translates to:
  /// **'AI 메모리 규칙 {count}개 적용됨'**
  String memoryAppliedPill(int count);

  /// 메모 더하기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'메모 더하기'**
  String get routineMemoryAddSheetTitle;

  /// 메모 고치기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'메모 고치기'**
  String get routineMemoryEditSheetTitle;

  /// 메모 입력칸 안내 글
  ///
  /// In ko, this message translates to:
  /// **'예: \'씻기\' 대신 \'손 닦기\'라고 써요'**
  String get routineMemoryLineHint;

  /// 메모 시트 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get routineMemorySave;

  /// 메모 고치기 시트의 지우기 글자 버튼
  ///
  /// In ko, this message translates to:
  /// **'이 줄 지우기'**
  String get routineMemoryDeleteLine;

  /// 모두 지우기 확인 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'메모를 모두 지울까요?'**
  String get routineMemoryClearConfirmTitle;

  /// 모두 지우기 확인 팝업 설명
  ///
  /// In ko, this message translates to:
  /// **'지운 메모는 되돌릴 수 없어요.'**
  String get routineMemoryClearConfirmMessage;

  /// AI 메모 모두 지우기 확인 팝업의 위험 버튼 (행동 이름, #1171)
  ///
  /// In ko, this message translates to:
  /// **'모두 지우기'**
  String get routineMemoryClearConfirmAction;

  /// AI 메모 불러오기 실패
  ///
  /// In ko, this message translates to:
  /// **'메모를 불러오지 못했어요'**
  String get routineMemoryLoadFailed;

  /// AI 메모 저장 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'메모를 저장하지 못했어요'**
  String get routineMemorySaveFailedTitle;

  /// AI 메모 저장 실패 기본 설명
  ///
  /// In ko, this message translates to:
  /// **'잠시 뒤 다시 해 주세요.'**
  String get routineMemorySaveFailedFallback;

  /// Pro 미리 보기가 실제 기록이 아닌 견본임을 알리는 배지
  ///
  /// In ko, this message translates to:
  /// **'예시 화면'**
  String get proTeaserSampleLabel;

  /// Pro 전용 기능을 Free 가 눌렀는데 앱에서 Pro 를 살 수 없을 때 안내 팝업 (실패 아님)
  ///
  /// In ko, this message translates to:
  /// **'Pro에서 쓸 수 있는 기능이에요'**
  String get proOnlyNoticeTitle;

  /// Pro 판매가 꺼져 요금제 화면을 못 열 때 안내 팝업 둘째 줄 (기능별 대안이 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'지금 쓰던 기능은 그대로 쓸 수 있어요'**
  String get proOnlyFreeAlternative;

  /// Pro 안내 팝업 대안 (AI 그림)
  ///
  /// In ko, this message translates to:
  /// **'지금은 기본 그림이나 사진으로 카드를 만들 수 있어요'**
  String get proOnlyFreeAlternativeAiImage;

  /// Pro 안내 팝업 대안 (반복 일과)
  ///
  /// In ko, this message translates to:
  /// **'지금은 일과를 직접 보내면 돼요'**
  String get proOnlyFreeAlternativeSchedule;

  /// Pro 안내 팝업 대안 (보호자 목소리)
  ///
  /// In ko, this message translates to:
  /// **'지금은 기본 목소리로 카드를 읽어 줘요'**
  String get proOnlyFreeAlternativeVoice;

  /// Pro 안내 팝업 대안 (카드 나누기)
  ///
  /// In ko, this message translates to:
  /// **'지금은 카드를 직접 추가해서 나눌 수 있어요'**
  String get proOnlyFreeAlternativeCardSplit;

  /// Pro 안내 팝업 대안 (인쇄 디자인·모양)
  ///
  /// In ko, this message translates to:
  /// **'지금은 기본 디자인으로 인쇄할 수 있어요'**
  String get proOnlyFreeAlternativeCardExport;

  /// 주간 리포트 미리 보기 한 줄 혜택
  ///
  /// In ko, this message translates to:
  /// **'한 주 동안 해낸 일과를 한 장으로 정리해 보낼 수 있어요'**
  String get proTeaserWeeklyReportBenefit;

  /// AI 메모 미리 보기 한 줄 혜택
  ///
  /// In ko, this message translates to:
  /// **'내가 고친 방식을 기억해 다음 일과를 더 알맞게 만들어요'**
  String get proTeaserRoutineMemoryBenefit;

  /// 인쇄용으로 받기 Pro 테마 미리 보기 한 줄 혜택
  ///
  /// In ko, this message translates to:
  /// **'인쇄용 카드를 여러 디자인으로 받을 수 있어요'**
  String get proTeaserCardThemeBenefit;

  /// 반복 일과·주간 계획 미리 보기 한 줄 혜택
  ///
  /// In ko, this message translates to:
  /// **'매일 아침 일과를 새로 보내지 않아도 돼요'**
  String get proTeaserWeeklyPlanBenefit;

  /// 미리 보기 견본 일과 제목 1
  ///
  /// In ko, this message translates to:
  /// **'아침 준비하기'**
  String get proTeaserSampleRoutineMorning;

  /// 미리 보기 견본 일과 제목 2
  ///
  /// In ko, this message translates to:
  /// **'이 닦기'**
  String get proTeaserSampleRoutineBrush;

  /// 미리 보기 견본 일과 제목 3
  ///
  /// In ko, this message translates to:
  /// **'가방 챙기기'**
  String get proTeaserSampleRoutineBag;

  /// 미리 보기 견본 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'양말 신기'**
  String get proTeaserSampleStepSocks;

  /// AI 메모 미리 보기 견본 줄 1
  ///
  /// In ko, this message translates to:
  /// **'카드 문장은 짧게 한 줄로 써요'**
  String get proTeaserSampleMemoryShort;

  /// AI 메모 미리 보기 견본 줄 2
  ///
  /// In ko, this message translates to:
  /// **'옷 입기는 양말부터 시작해요'**
  String get proTeaserSampleMemoryOrder;

  /// AI 메모 미리 보기 견본 줄 3
  ///
  /// In ko, this message translates to:
  /// **'보상은 스티커로 정해요'**
  String get proTeaserSampleMemoryReward;

  /// 카드 그림 위 AI 그림 다시 그리기 칩의 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'다시 그리기'**
  String get cardRegenerateChip;

  /// 다시 그리기 확인 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'그림을 다시 그릴까요?'**
  String get cardRegenerateSheetTitle;

  /// 다시 그리기 비용: Pro 하루 무료 횟수 안
  ///
  /// In ko, this message translates to:
  /// **'크레딧 없이, 오늘 {count}번 남았어요'**
  String cardRegenerateCostProFree(int count);

  /// 다시 그리기 비용: 크레딧이 꺼져 있거나 단가 0
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 쓰지 않아요'**
  String get cardRegenerateCostFree;

  /// 다시 그리기 비용: 크레딧 단가
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{크레딧 {count}개}}'**
  String cardRegenerateCostCredits(int count);

  /// 다시 그리기 비용 (Pro, 오늘 무료 횟수를 다 씀). freeCount 는 하루 무료 한도
  ///
  /// In ko, this message translates to:
  /// **'{credits, plural, other{오늘 무료 {freeCount}번을 다 썼어요, 크레딧 {credits}개를 써요}}'**
  String cardRegenerateCostProUsedUp(int credits, int freeCount);

  /// 다시 그리기 시트 (Free) 사실 한 줄. count 는 서버 하루 무료 한도
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{Pro는 하루 {count}번 무료로 다시 그려요}}'**
  String cardRegenerateProFact(int count);

  /// 카드 추가 시트 버튼 위 비용 한 줄 (AI 그림 방식일 때)
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{AI 그림을 그리면 크레딧 {count}개를 써요}}'**
  String cardAddImageCost(int count);

  /// 카드 만들기 버튼 아래 비용 한 줄. costs 는 imageStyleCreditRoutine(·Image) 를 쉼표로 이은 글, available 은 남은 크레딧
  ///
  /// In ko, this message translates to:
  /// **'{available, plural, other{{costs}, 지금 {available}개 있어요}}'**
  String questionCreditCostLine(String costs, int available);

  /// 크레딧 비용 표시: 크레딧 그림 옆 개수 (낭독은 cardRegenerateCostCredits)
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개}}'**
  String creditCostCount(int count);

  /// 다시 그리기 비용을 불러오지 못했을 때
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 써요'**
  String get cardRegenerateCostUnknown;

  /// 다시 그리기 확인 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 그리기'**
  String get cardRegenerateConfirm;

  /// 다시 그리는 동안 그림 위에 덮이는 안내
  ///
  /// In ko, this message translates to:
  /// **'그림을 다시 그리고 있어요'**
  String get cardRegenerateInProgress;

  /// 다시 그리기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'그림을 다시 그리지 못했어요'**
  String get cardRegenerateFailedTitle;

  /// 그림 없는 카드(픽토그램) 아래 AI 그림 처음 그리기 칩의 글자와 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'AI 그림 그리기'**
  String get cardFirstDrawChip;

  /// Free 에게 다시 그리기 칩 자리에 보이는 Pro 안내 칩의 낭독 이름 (보이는 글은 cardRegenerateChip + Pro 배지, 누르면 요금제 화면)
  ///
  /// In ko, this message translates to:
  /// **'Pro로 다시 그리기'**
  String get cardRedrawProChip;

  /// Free 에게 그림 없는 카드 아래 보이는 Pro 안내 칩의 낭독 이름 (보이는 글은 cardFirstDrawChip + Pro 배지, 누르면 요금제 화면)
  ///
  /// In ko, this message translates to:
  /// **'Pro로 AI 그림 그리기'**
  String get cardFirstDrawProChip;

  /// AI 그림 처음 그리기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'AI 그림을 그릴까요?'**
  String get cardFirstDrawSheetTitle;

  /// 다시 그리기 시트 설명
  ///
  /// In ko, this message translates to:
  /// **'고치고 싶은 점을 적거나 골라 주세요. 비워 두면 그대로 다시 그려요'**
  String get cardRedrawSheetBody;

  /// AI 그림 처음 그리기 시트 설명
  ///
  /// In ko, this message translates to:
  /// **'원하는 점을 적거나 골라 주세요. 새 그림을 보고 고를 수 있어요'**
  String get cardFirstDrawSheetBody;

  /// 다시 그리기 시트 요청 글 칸 라벨
  ///
  /// In ko, this message translates to:
  /// **'고치고 싶은 점'**
  String get cardRedrawRequestLabel;

  /// 다시 그리기 시트 요청 글 칸 안내 (60자까지)
  ///
  /// In ko, this message translates to:
  /// **'예: 우산을 파란색으로'**
  String get cardRedrawRequestHint;

  /// 다시 그리기 요청 칩
  ///
  /// In ko, this message translates to:
  /// **'더 단순하게'**
  String get cardRedrawHintSimpler;

  /// 다시 그리기 요청 칩
  ///
  /// In ko, this message translates to:
  /// **'배경 빼기'**
  String get cardRedrawHintNoBackground;

  /// 다시 그리기 요청 칩
  ///
  /// In ko, this message translates to:
  /// **'사람 빼기'**
  String get cardRedrawHintNoPeople;

  /// 다시 그리기 요청 칩
  ///
  /// In ko, this message translates to:
  /// **'더 밝게'**
  String get cardRedrawHintBrighter;

  /// AI 그림 처음 그리기 시트 확인 버튼
  ///
  /// In ko, this message translates to:
  /// **'그리기'**
  String get cardFirstDrawConfirm;

  /// AI 그림 처음 그리는 동안 그림 위에 덮이는 안내
  ///
  /// In ko, this message translates to:
  /// **'그림을 그리고 있어요'**
  String get cardFirstDrawInProgress;

  /// AI 그림 처음 그리기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'AI 그림을 그리지 못했어요'**
  String get cardFirstDrawFailedTitle;

  /// 그리기·새 그림 받기 실패 팝업 기본 설명 (서버 문구가 없을 때)
  ///
  /// In ko, this message translates to:
  /// **'다시 해 볼까요? 크레딧은 쓰지 않았어요'**
  String get cardRedrawFailedFallback;

  /// 새 그림을 그린 뒤 받기·바꾸기 실패 팝업 기본 안내 (그리기는 끝나 크레딧을 이미 씀)
  ///
  /// In ko, this message translates to:
  /// **'새 그림은 이미 그려서 쓴 크레딧은 돌아오지 않아요. 잠시 뒤 다시 해 주세요'**
  String get cardCandidateFailedFallback;

  /// 새 그림 고르기 시트 제목
  ///
  /// In ko, this message translates to:
  /// **'어떤 그림으로 할까요?'**
  String get cardCandidateSheetTitle;

  /// 새 그림 고르기 시트 설명
  ///
  /// In ko, this message translates to:
  /// **'고른 그림만 이룸이에게 보여요\n어느 그림을 골라도 쓴 크레딧은 돌아오지 않아요'**
  String get cardCandidateSheetBody;

  /// 새 그림 고르기 시트: 원래 그림(또는 픽토그램) 이름
  ///
  /// In ko, this message translates to:
  /// **'지금 그림'**
  String get cardCandidateCurrentLabel;

  /// 새 그림 고르기 시트: 새로 그린 그림 이름과 낭독 이름
  ///
  /// In ko, this message translates to:
  /// **'새 그림'**
  String get cardCandidateNewLabel;

  /// 그림 고르기 시트의 버튼 하나. 고른 그림(지금 그림 또는 새 그림)으로 정함
  ///
  /// In ko, this message translates to:
  /// **'이 그림으로 하기'**
  String get cardCandidateSelectButton;

  /// 새 그림으로 바꾸기 성공 토스트
  ///
  /// In ko, this message translates to:
  /// **'새 그림으로 바꿨어요'**
  String get cardCandidateAppliedToast;

  /// 새로 그린 그림을 받지 못했을 때 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'새 그림을 불러오지 못했어요'**
  String get cardCandidateLoadFailedTitle;

  /// 새 그림으로 바꾸기 실패 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'새 그림으로 바꾸지 못했어요'**
  String get cardCandidateApplyFailedTitle;

  /// 요금제 화면 머리 제목 (#1189 시안 A · 용어표: 우리 아이 > 이룸이) #1189
  ///
  /// In ko, this message translates to:
  /// **'이룸이만을 위한 카드로 바뀌어요'**
  String get planHeroHeadline;

  /// 요금제 화면 머리 설명 #1189
  ///
  /// In ko, this message translates to:
  /// **'같은 일과도 Pro로 만들면 이렇게 달라져요'**
  String get planHeroSubline;

  /// 머리 비교: Free 카드 아래 작은 글 #1189
  ///
  /// In ko, this message translates to:
  /// **'Free 이모지'**
  String get planHeroFreeTag;

  /// 머리 비교: Pro 카드 아래 작은 글 #1189
  ///
  /// In ko, this message translates to:
  /// **'Pro 만화 그림'**
  String get planHeroProTag;

  /// 머리 비교 그림의 읽기 프로그램 문구 #1189
  ///
  /// In ko, this message translates to:
  /// **'Free는 이모지 카드, Pro는 만화 그림 카드예요'**
  String get planHeroCompareSemantics;

  /// 혜택 묶음 제목: 그림·다시 그리기·인쇄. elumiName 은 고른 이룸이 호칭 #1189
  ///
  /// In ko, this message translates to:
  /// **'{elumiName}만의 카드 그림'**
  String planBenefitGroupCards(String elumiName);

  /// 혜택 묶음 제목: 반복·AI 메모 #1189
  ///
  /// In ko, this message translates to:
  /// **'일과가 알아서 가요'**
  String get planBenefitGroupRoutines;

  /// 혜택 묶음 제목: 주간 리포트·보호자 목소리 #1189
  ///
  /// In ko, this message translates to:
  /// **'한 주를 정리해 드려요'**
  String get planBenefitGroupWeek;

  /// 혜택 묶음 제목: 크레딧·광고 #1189
  ///
  /// In ko, this message translates to:
  /// **'더 넉넉하게'**
  String get planBenefitGroupExtra;

  /// 1년 기간 카드 위 띠 (1개월 × 12 대비, 내림) #1189
  ///
  /// In ko, this message translates to:
  /// **'{percent}% 아껴요'**
  String planYearlySaving(int percent);

  /// 1년 기간 카드 설명 (한 달 꼴 값을 모를 때) #1189
  ///
  /// In ko, this message translates to:
  /// **'1년마다 자동 갱신'**
  String get planRenewsYearly;

  /// 1개월 기간 카드 설명 #1189
  ///
  /// In ko, this message translates to:
  /// **'1개월마다 자동 갱신'**
  String get planRenewsMonthly;

  /// 1년 기간 카드 설명: 한 달 꼴 값 + 갱신 주기 (1개월 카드와 맞춤) #1265
  ///
  /// In ko, this message translates to:
  /// **'한 달에 {price} 꼴 · 1년마다 자동 갱신'**
  String planMonthlyEquivalentRenewsYearly(String price);

  /// 기간 카드 가격 뒤 단위 · 버튼 아래 한 줄 #1189
  ///
  /// In ko, this message translates to:
  /// **'{period, select, yearly{/년} other{/월}}'**
  String planPriceUnit(String period);

  /// 요금제 화면 버튼 아래 한 줄 (App Store 체험, 스토어 값) #1189
  ///
  /// In ko, this message translates to:
  /// **'{trial} 뒤 {price}{unit} 자동 결제돼요. 끝나기 24시간 전까지 해지하면 청구되지 않아요'**
  String planCtaTrialNoticeAppStore(String trial, String price, String unit);

  /// 요금제 화면 버튼 아래 한 줄 (Google Play 체험, 스토어 값) #1189
  ///
  /// In ko, this message translates to:
  /// **'{trial} 뒤 {price}{unit} 자동 결제돼요. 체험 중 해지하면 청구되지 않아요'**
  String planCtaTrialNoticePlayStore(String trial, String price, String unit);

  /// 요금제 화면 버튼 아래 한 줄 (체험 없음) #1189
  ///
  /// In ko, this message translates to:
  /// **'{price}{unit} 자동 갱신돼요. 언제든 해지할 수 있어요'**
  String planCtaRenewNotice(String price, String unit);

  /// Pro 미리보기 버튼 (체험 대상일 때, ProUpsellButton 에서만) #1189
  ///
  /// In ko, this message translates to:
  /// **'{trial} 무료로 써 보기'**
  String planTryFreeTrial(String trial);

  /// Pro 미리보기 카드 아래 글자 링크 (요금제 화면) #1189
  ///
  /// In ko, this message translates to:
  /// **'Pro 혜택 모두 보기'**
  String get planSeeAllBenefits;

  /// 내 요금제 줄: PRO 배지 옆 (선물받은 Pro) #1189
  ///
  /// In ko, this message translates to:
  /// **'선물'**
  String get planTierGift;

  /// 내 정보 내 요금제 카드 제목: Pro (구독, 기간 제한 없음) #1268
  ///
  /// In ko, this message translates to:
  /// **'Pro로 쓰고 있어요'**
  String get myPlanProTitle;

  /// 내 정보 내 요금제 카드 제목: Pro 선물 #1268
  ///
  /// In ko, this message translates to:
  /// **'Pro 선물을 받았어요'**
  String get myPlanGiftTitle;

  /// 내 정보 내 요금제 카드 제목: Free #1268
  ///
  /// In ko, this message translates to:
  /// **'Free로 쓰고 있어요'**
  String get myPlanFreeTitle;

  /// 내 정보 내 요금제 카드 한 줄: Free, 주간 크레딧 #1268
  ///
  /// In ko, this message translates to:
  /// **'매주 받는 크레딧으로 일과를 만들어요'**
  String get myPlanFreeBodyWeek;

  /// 내 정보 내 요금제 카드 한 줄: Free, 월간 크레딧 #1268
  ///
  /// In ko, this message translates to:
  /// **'매달 받는 크레딧으로 일과를 만들어요'**
  String get myPlanFreeBodyMonth;

  /// Pro 미리보기 제목: 주간 계획 #1189
  ///
  /// In ko, this message translates to:
  /// **'요일과 시각만 정해 두면 그날 일과가 준비돼요'**
  String get proTeaserWeeklyPlanTitle;

  /// Pro 미리보기 제목: 주간 리포트 #1189
  ///
  /// In ko, this message translates to:
  /// **'한 주를 한 장으로 받아 봐요'**
  String get proTeaserWeeklyReportTitle;

  /// Pro 미리보기 제목: AI 메모 #1189
  ///
  /// In ko, this message translates to:
  /// **'이룸이에게 맞춘 방식을 기억해요'**
  String get proTeaserRoutineMemoryTitle;

  /// Pro 미리보기 제목: 인쇄 디자인 #1189
  ///
  /// In ko, this message translates to:
  /// **'인쇄용 카드를 더 예쁘게 받아요'**
  String get proTeaserCardThemeTitle;

  /// Pro 미리보기 제목: 인쇄 형태·배치 #1224
  ///
  /// In ko, this message translates to:
  /// **'인쇄용 카드를 원하는 대로 받아요'**
  String get proTeaserCardLayoutTitle;

  /// Pro 미리보기 한 줄: 인쇄 형태·배치 #1224
  ///
  /// In ko, this message translates to:
  /// **'한 장에 여러 장, 가로 용지, 일과 한 장으로 받을 수 있어요'**
  String get proTeaserCardLayoutBenefit;

  /// 보호자 홈 권유 카드 닫기 x 낭독 글
  ///
  /// In ko, this message translates to:
  /// **'괜찮아요'**
  String get homeSuggestionDismissLabel;

  /// 홈 권유 카드 제목: 같은 일과를 3일 이어서 보냈을 때 반복 정하기 권유
  ///
  /// In ko, this message translates to:
  /// **'매일 자동으로 보낼까요?'**
  String get homeSuggestionAutoSendTitle;

  /// 홈 권유 카드 본문: 같은 일과를 이어서 보낸 날 수. routine 은 일과 제목, batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다, days 는 이어서 보낸 날 수
  ///
  /// In ko, this message translates to:
  /// **'{routine}{batchim, select, yes{을} other{를}} {days}일째 보내셨어요'**
  String homeSuggestionAutoSendBody(String routine, String batchim, int days);

  /// 홈 권유 카드 버튼: 반복 요일·시각 정하기
  ///
  /// In ko, this message translates to:
  /// **'정하기'**
  String get homeSuggestionAutoSendAction;

  /// 홈 권유 카드 제목: 같은 일과를 5번 넘게 썼을 때 이야기 올리기 권유
  ///
  /// In ko, this message translates to:
  /// **'이야기에 올려 볼까요?'**
  String get homeSuggestionTalkShareTitle;

  /// 홈 권유 카드 본문: 이야기에 올리면 다른 보호자가 가져다 쓸 수 있다는 뜻. routine 은 일과 제목, batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다
  ///
  /// In ko, this message translates to:
  /// **'다른 보호자도 {routine}{batchim, select, yes{을} other{를}} 가져다 쓸 수 있어요'**
  String homeSuggestionTalkShareBody(String routine, String batchim);

  /// 홈 권유 카드 버튼: 그 일과로 이야기 올리기 화면 열기
  ///
  /// In ko, this message translates to:
  /// **'올리기'**
  String get homeSuggestionTalkShareAction;

  /// 홈 권유 카드 제목: 일과가 1개뿐이고 3일 넘게 썼을 때 일과 더 만들기 권유
  ///
  /// In ko, this message translates to:
  /// **'일과를 더 만들어 볼까요?'**
  String get homeSuggestionCreateMoreTitle;

  /// 홈 권유 카드 본문: 다른 시간대 일과 예시
  ///
  /// In ko, this message translates to:
  /// **'저녁이나 잠자기 전 일과는 어때요?'**
  String get homeSuggestionCreateMoreBody;

  /// 홈 권유 카드 버튼: 일과 만들기 시작
  ///
  /// In ko, this message translates to:
  /// **'만들기'**
  String get homeSuggestionCreateMoreAction;

  /// 카드 수정 시트 칩: 카드 한 장을 AI 가 2~3장으로 나눈 안 받기 (Free 는 PRO 배지)
  ///
  /// In ko, this message translates to:
  /// **'이 카드 더 쉽게'**
  String get cardSplitChip;

  /// 카드 나누기 시트: 안을 받는 중
  ///
  /// In ko, this message translates to:
  /// **'더 쉬운 단계로 나누고 있어요'**
  String get cardSplitLoading;

  /// 카드 나누기 시트 제목: 나눈 안을 보여 주며 묻는다
  ///
  /// In ko, this message translates to:
  /// **'이렇게 나눠 볼까요?'**
  String get cardSplitSheetTitle;

  /// 카드 나누기 시트 제목 아래 한 줄. title 은 원래 카드 제목, count 는 나눈 카드 수
  ///
  /// In ko, this message translates to:
  /// **'{title} 카드를 작은 단계 {count}개로 나눠 봤어요'**
  String cardSplitSheetDescription(String title, int count);

  /// 나눌 것이 없는 카드일 때 제목 아래 한 줄
  ///
  /// In ko, this message translates to:
  /// **'행동이 하나라서 더 나누지 않았어요'**
  String get cardSplitAlreadyShortDescription;

  /// 카드 나누기 시트 안내: 새 카드 그림은 기본 그림
  ///
  /// In ko, this message translates to:
  /// **'그림은 기본 그림으로 들어가요. 나중에 바꿀 수 있어요'**
  String get cardSplitDefaultPictureNote;

  /// 카드 나누기 시트 버튼(보조): 나누지 않고 닫기
  ///
  /// In ko, this message translates to:
  /// **'그대로 두기'**
  String get cardSplitKeepButton;

  /// 카드 나누기 시트 버튼(주): 나눈 안 적용
  ///
  /// In ko, this message translates to:
  /// **'이렇게 나누기'**
  String get cardSplitApplyButton;

  /// 카드 나누기 시트: 더 나눌 필요가 없는 카드
  ///
  /// In ko, this message translates to:
  /// **'이미 충분히 짧아요'**
  String get cardSplitAlreadyShort;

  /// 카드 나누기 실패 문구 (서버가 문구를 주지 않을 때)
  ///
  /// In ko, this message translates to:
  /// **'카드를 나누지 못했어요. 잠시 뒤 다시 해 주세요'**
  String get cardSplitFailedFallback;

  /// 카드 나누기 실패 화면 버튼: 같은 일 다시 하기
  ///
  /// In ko, this message translates to:
  /// **'다시 하기'**
  String get cardSplitRetry;

  /// 카드를 나눈 뒤 토스트. count 는 나뉜 카드 수
  ///
  /// In ko, this message translates to:
  /// **'카드를 {count}장으로 나눴어요'**
  String cardSplitDoneToast(int count);

  /// 혜택 줄: 카드 나누기
  ///
  /// In ko, this message translates to:
  /// **'카드 한 장을 더 작게 나눠 줘요'**
  String get planBenefitCardSplit;

  /// 크레딧 더 받기 시트 제목 (주 단위 크레딧을 다 썼을 때)
  ///
  /// In ko, this message translates to:
  /// **'🎟️ 이번 주 크레딧을 다 썼어요'**
  String get creditTopUpTitleExhausted;

  /// creditTopUpTitleExhausted 의 월 단위 문구
  ///
  /// In ko, this message translates to:
  /// **'🎟️ 이번 달 크레딧을 다 썼어요'**
  String get creditTopUpTitleExhaustedMonth;

  /// 크레딧 더 받기 시트 제목 (남았지만 이번 일에 모자랄 때 · 잔액을 모를 때)
  ///
  /// In ko, this message translates to:
  /// **'🎟️ 크레딧이 조금 모자라요'**
  String get creditTopUpTitleShort;

  /// 크레딧 더 받기 시트 한 줄 설명. reset 은 다시 채워지는 시각(예: 9월 28일(월) 0시)
  ///
  /// In ko, this message translates to:
  /// **'{reset}에 다시 채워져요'**
  String creditTopUpRefillAt(String reset);

  /// 시트 광고 칸 제목. count 는 광고 한 번에 받는 크레딧 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{광고 보고 크레딧 {count}개 받기}}'**
  String creditTopUpAdTitle(int count);

  /// 시트 광고 칸 제목 (받는 수를 모를 때)
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 크레딧 받기'**
  String get creditTopUpAdTitleNoCount;

  /// 광고 칸 설명. remaining 은 오늘 더 볼 수 있는 횟수
  ///
  /// In ko, this message translates to:
  /// **'{remaining, plural, other{30초쯤 걸려요, 오늘 {remaining}번 더 받을 수 있어요}}'**
  String creditTopUpAdDetail(int remaining);

  /// 광고 칸 버튼
  ///
  /// In ko, this message translates to:
  /// **'광고 보기'**
  String get creditTopUpAdWatch;

  /// 광고 보상이 꺼져 있어 버튼을 끈 이유
  ///
  /// In ko, this message translates to:
  /// **'지금은 광고로 받을 수 없어요'**
  String get creditTopUpAdOff;

  /// 오늘 광고 횟수를 다 써서 버튼을 끈 이유
  ///
  /// In ko, this message translates to:
  /// **'오늘은 다 받았어요. 내일 다시 볼 수 있어요'**
  String get creditTopUpAdDailyLimit;

  /// 광고 제안 조회가 실패해 버튼을 끈 이유
  ///
  /// In ko, this message translates to:
  /// **'광고 정보를 불러오지 못했어요. 잠시 후 다시 열어 주세요'**
  String get creditTopUpAdCheckFailed;

  /// 시트의 꾸러미 화면 글자 버튼
  ///
  /// In ko, this message translates to:
  /// **'크레딧 꾸러미 보기'**
  String get creditTopUpPackLink;

  /// 광고로 크레딧을 받은 뒤 일과 만들기를 다시 시도하는 버튼
  ///
  /// In ko, this message translates to:
  /// **'이어서 만들기'**
  String get creditTopUpRoutineContinue;

  /// 광고로 크레딧을 받은 뒤 카드 그림 그리기를 다시 시도하는 버튼
  ///
  /// In ko, this message translates to:
  /// **'이어서 그리기'**
  String get creditTopUpRedrawContinue;

  /// 광고 보상 받은 순간 창 제목. count 는 받은 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{🎟️ 크레딧 {count}개를 받았어요}}'**
  String creditRewardTitle(int count);

  /// 광고 보상 받은 순간 창 제목 (받은 수를 모를 때)
  ///
  /// In ko, this message translates to:
  /// **'🎟️ 크레딧을 받았어요'**
  String get creditRewardTitleNoCount;

  /// 받는 순간 창의 받은 수 (큰 숫자, 0 에서 세며 올라감)
  ///
  /// In ko, this message translates to:
  /// **'+{count}'**
  String creditRewardPlus(int count);

  /// 받은 순간 창 한 줄 설명
  ///
  /// In ko, this message translates to:
  /// **'광고를 끝까지 봐서 받았어요'**
  String get creditRewardReason;

  /// 받은 순간 창 잔액 줄 항목
  ///
  /// In ko, this message translates to:
  /// **'지금 크레딧'**
  String get creditRewardBalanceLabel;

  /// 홈 안내 카드 제목 (일과 하나 만들 만큼 안 남았을 때)
  ///
  /// In ko, this message translates to:
  /// **'크레딧이 조금 남았어요'**
  String get lowCreditNoticeTitle;

  /// 홈 안내 카드 제목 (0 일 때)
  ///
  /// In ko, this message translates to:
  /// **'크레딧을 다 썼어요'**
  String get lowCreditNoticeTitleEmpty;

  /// 홈 크레딧 안내 카드 한 문장
  ///
  /// In ko, this message translates to:
  /// **'광고를 보면 바로 더 받을 수 있어요'**
  String get lowCreditNoticeBody;

  /// 홈 크레딧 안내 카드 버튼 (광고를 바로 띄움)
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 받기'**
  String get lowCreditNoticeAction;

  /// 크레딧 안내 창 제목
  ///
  /// In ko, this message translates to:
  /// **'🎟️ 크레딧은 이렇게 써요'**
  String get creditGuideTitle;

  /// 크레딧 안내 창 한 줄 설명 (요금제 칩과 함께)
  ///
  /// In ko, this message translates to:
  /// **'내 요금제 기준이에요'**
  String get creditGuideBasis;

  /// 크레딧 안내 표 항목
  ///
  /// In ko, this message translates to:
  /// **'일과 글 만들기'**
  String get creditGuideRoutineText;

  /// 크레딧 안내 표 항목
  ///
  /// In ko, this message translates to:
  /// **'카드 그림 1장'**
  String get creditGuideCardImage;

  /// 크레딧 안내 표 항목
  ///
  /// In ko, this message translates to:
  /// **'그림 다시 그리기'**
  String get creditGuideRegenerate;

  /// 크레딧 안내 표 항목 (주 단위 지급량)
  ///
  /// In ko, this message translates to:
  /// **'매주 받는 크레딧'**
  String get creditGuideWeeklyGrant;

  /// 크레딧 안내 표 항목 (월 단위 지급량)
  ///
  /// In ko, this message translates to:
  /// **'매달 받는 크레딧'**
  String get creditGuideMonthlyGrant;

  /// 크레딧 안내 표 값: 크레딧 수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개}}'**
  String creditGuideCount(int count);

  /// 크레딧 안내 표 값: 크레딧을 쓰지 않고 횟수 제한도 없음
  ///
  /// In ko, this message translates to:
  /// **'제한 없음'**
  String get creditGuideUnlimited;

  /// Pro 다시 그리기 값: 오늘 남은 무료 횟수
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{오늘 {count}번 더 무료}}'**
  String creditGuideRegenerateFreeToday(int count);

  /// 크레딧 안내 설명 줄
  ///
  /// In ko, this message translates to:
  /// **'시작한 일과는 크레딧이 모자라도 끝까지 만들어져요'**
  String get creditGuideKeepGoing;

  /// 크레딧 안내 설명 줄 (주 단위)
  ///
  /// In ko, this message translates to:
  /// **'매주 월요일 0시에 다시 채워져요'**
  String get creditGuideRefillWeek;

  /// 크레딧 안내 설명 줄 (월 단위)
  ///
  /// In ko, this message translates to:
  /// **'매달 1일 0시에 다시 채워져요'**
  String get creditGuideRefillMonth;

  /// Free 에게 보이는 Pro 사실 한 줄 (비교 문구 금지). count 는 서버 하루 무료 다시 그리기 한도
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{Pro는 일과 글이 제한 없고, 다시 그리기는 하루 {count}번 무료예요}}'**
  String creditGuideProFactBoth(int count);

  /// Free 에게 보이는 Pro 사실 한 줄 (글만)
  ///
  /// In ko, this message translates to:
  /// **'Pro는 일과 글이 제한 없어요'**
  String get creditGuideProFactText;

  /// Free 에게 보이는 Pro 사실 한 줄 (다시 그리기만). count 는 서버 하루 무료 한도
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{Pro는 다시 그리기가 하루 {count}번 무료예요}}'**
  String creditGuideProFactRegenerate(int count);

  /// Pro 다시 그리기 값: 서버 하루 무료 한도
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{하루 {count}번 무료}}'**
  String creditGuideRegenerateFreeDaily(int count);

  /// 크레딧 안내 창 버튼
  ///
  /// In ko, this message translates to:
  /// **'알겠어요'**
  String get creditGuideConfirm;

  /// 내 크레딧 막대 위 한 줄 (주 단위). used 는 이번 주 쓴 수, available 은 남은 수
  ///
  /// In ko, this message translates to:
  /// **'이번 주에 {used}개 쓰고 {available}개 남았어요'**
  String myCreditUsageWeek(int used, int available);

  /// myCreditUsageWeek 의 월 단위 문구
  ///
  /// In ko, this message translates to:
  /// **'이번 달에 {used}개 쓰고 {available}개 남았어요'**
  String myCreditUsageMonth(int used, int available);

  /// Pro 무료 다시 그리기 한 줄. left 는 오늘 남은 횟수, cap 은 서버 하루 한도
  ///
  /// In ko, this message translates to:
  /// **'오늘 무료 다시 그리기 {left}번 남았어요 (하루 {cap}번)'**
  String myCreditFreeRegenerateToday(int left, int cap);

  /// 내 크레딧 최근 내역 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'최근 쓴 내역'**
  String get myCreditRecentTitle;

  /// 최근 내역 아래 글자 버튼 (사용 내역 화면)
  ///
  /// In ko, this message translates to:
  /// **'전체 내역 보기'**
  String get myCreditSeeAllHistory;

  /// 내 크레딧 맨 아래 글자 버튼 (크레딧 안내 창)
  ///
  /// In ko, this message translates to:
  /// **'크레딧은 이렇게 써요'**
  String get myCreditGuideLink;

  /// ABA 소개 화면 제목 (온보딩 역할 선택 다음, 설정 다시 보기) #1277
  ///
  /// In ko, this message translates to:
  /// **'🧩 준비는 간편하게, 일상은 스스로'**
  String get abaIntroTitle;

  /// ABA 소개 화면 제목 아래 한 줄. 치료·효과 표현 금지, 기관 이름 금지
  ///
  /// In ko, this message translates to:
  /// **'이룸은 응용행동분석(ABA)의 원리로 만들었어요'**
  String get abaIntroSubtitle;

  /// ABA 소개 줄 1 제목 (카드 아이콘)
  ///
  /// In ko, this message translates to:
  /// **'카드 한 장에 한 가지 행동'**
  String get abaIntroCardTitle;

  /// ABA 소개 줄 1 설명
  ///
  /// In ko, this message translates to:
  /// **'무엇을 할지, 어떻게 할지, 다 하면 받을 보상까지'**
  String get abaIntroCardBody;

  /// ABA 소개 줄 2 제목 (소리 아이콘)
  ///
  /// In ko, this message translates to:
  /// **'짧은 문장, 그림과 목소리'**
  String get abaIntroVoiceTitle;

  /// ABA 소개 줄 2 설명
  ///
  /// In ko, this message translates to:
  /// **'보고 들으며 하나씩 따라 해요'**
  String get abaIntroVoiceBody;

  /// ABA 소개 줄 3 제목 (별 아이콘)
  ///
  /// In ko, this message translates to:
  /// **'해내면 바로 칭찬과 별'**
  String get abaIntroStarTitle;

  /// ABA 소개 줄 3 설명
  ///
  /// In ko, this message translates to:
  /// **'보호자님이 정한 보상까지 받아요'**
  String get abaIntroStarBody;

  /// ABA 소개 아래 보호자 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'💛 가장 중요한 건 보호자님이에요'**
  String get abaIntroGuardianTitle;

  /// ABA 소개 아래 보호자 묶음 설명
  ///
  /// In ko, this message translates to:
  /// **'아이를 가장 잘 아는 보호자님이 일과와 보상을 정하고, 이룸은 아이가 스스로 이어 갈 수 있게 곁에서 도와요'**
  String get abaIntroGuardianBody;

  /// ABA 소개 화면(온보딩) 주 버튼 > 이룸이 이름 입력으로
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get abaIntroStart;

  /// 설정 > 약관 및 정보 줄, ABA 소개 화면 다시 보기 (화면 제목으로도 씀)
  ///
  /// In ko, this message translates to:
  /// **'이룸은 이렇게 만들었어요'**
  String get guardianSettingsAboutElum;

  /// 알림 켜기 안내 화면 제목 (온보딩 끝, 이미 가입한 보호자는 업데이트 뒤 한 번) #1275
  ///
  /// In ko, this message translates to:
  /// **'🔔 알림을 꼭 켜 주세요'**
  String get notificationIntroTitle;

  /// 알림 켜기 안내 화면 제목 아래 한 줄 (왜 켜야 하는지)
  ///
  /// In ko, this message translates to:
  /// **'켜 두면 이룸이 소식을 놓치지 않고 바로 알려 드려요'**
  String get notificationIntroBody;

  /// 알림 켜기 안내: 받는 알림 1
  ///
  /// In ko, this message translates to:
  /// **'이룸이가 일과를 마쳤을 때'**
  String get notificationIntroRoutineDone;

  /// 알림 켜기 안내: 받는 알림 2 (공동 보호자가 보낸 일과)
  ///
  /// In ko, this message translates to:
  /// **'함께 돌보는 분이 일과를 보냈을 때'**
  String get notificationIntroCaregiverRoutine;

  /// 알림 켜기 안내: 받는 알림 3
  ///
  /// In ko, this message translates to:
  /// **'주간 리포트가 나왔을 때'**
  String get notificationIntroWeeklyReport;

  /// 알림 켜기 안내: 받는 알림 3 (주간 리포트 권한 없음, 주 단위 크레딧)
  ///
  /// In ko, this message translates to:
  /// **'이번 주 크레딧이 다시 채워졌을 때'**
  String get notificationIntroCreditRefilledWeek;

  /// 알림 켜기 안내: 받는 알림 3 (주간 리포트 권한 없음, 월 단위 크레딧)
  ///
  /// In ko, this message translates to:
  /// **'이번 달 크레딧이 다시 채워졌을 때'**
  String get notificationIntroCreditRefilledMonth;
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
