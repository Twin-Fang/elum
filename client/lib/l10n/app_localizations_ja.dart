// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '이룸';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonCancel => '취소';

  @override
  String get commonClose => '닫기';

  @override
  String get commonNext => '다음';

  @override
  String get commonRetry => '다시 시도';

  @override
  String dateYearMonthDay(int year, int month, int day) {
    return '$year년 $month월 $day일';
  }

  @override
  String dateMonthDaySince(int month, int day) {
    return '$month월 $day일부터';
  }

  @override
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'mon': '월',
      'tue': '화',
      'wed': '수',
      'thu': '목',
      'fri': '금',
      'sat': '토',
      'sun': '일',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String creditResetAt(int month, int day, String weekday, int hour) {
    return '$month월 $day일($weekday) $hour시';
  }

  @override
  String creditResetAtMinute(
    int month,
    int day,
    String weekday,
    int hour,
    int minute,
  ) {
    return '$month월 $day일($weekday) $hour시 $minute분';
  }

  @override
  String get creditResetFallback => '다음 주 월요일 0시';

  @override
  String get commonPopupClose => '팝업 닫기';

  @override
  String get commonBack => '뒤로 가기';

  @override
  String get commonScreenNotFound => '화면을 찾을 수 없어요';

  @override
  String get commonRetryLater => '잠시 후 다시 해주세요';

  @override
  String commonRetryWithCode(String code) {
    return '다시 시도 ($code)';
  }

  @override
  String get sentenceStop => '.';

  @override
  String get failureHintOffline => '인터넷 연결을 확인해주세요';

  @override
  String get failureHintTimeout => '연결이 느려요. 잠시 후 다시 해주세요';

  @override
  String get failureHintBadCertificate => '안전하지 않은 연결이에요. 다른 망에서 해주세요';

  @override
  String coachStepLabel(int index, int total, String message) {
    return '안내 $index/$total. $message';
  }

  @override
  String get commonAd => '광고';

  @override
  String get commonAppInfo => '앱 정보';

  @override
  String get coachCloseHint => '안내 닫기';

  @override
  String get coachNextHint => '다음 안내';

  @override
  String get coachTapToClose => '화면을 누르면 닫혀요';

  @override
  String get coachTapToNext => '화면을 누르면 다음으로 넘어가요';

  @override
  String get loginSceneEyebrow => '오늘의 하루,';

  @override
  String get loginSceneTitle => '차근차근 함께해요';

  @override
  String get appStatusStoreOpenFailedTitle => '스토어를 열지 못했어요';

  @override
  String get appStatusStoreOpenFailedFallback => '스토어에서 이룸을 찾아 업데이트해주세요';

  @override
  String get appStatusMaintenanceTitle => '잠시 쉬고 있어요';

  @override
  String get appStatusMaintenanceBody => '조금 뒤에 다시 열어주세요';

  @override
  String get appStatusRecheck => '다시 확인하기';

  @override
  String get appStatusUpdateTitle => '새 이룸이 나왔어요';

  @override
  String get appStatusUpdateBody =>
      '앱을 새로 받아야 이어서 쓸 수 있어요.\n스토어에서 이룸을 업데이트해주세요';

  @override
  String get appStatusUpdated => '업데이트했어요';

  @override
  String get appStatusGoUpdate => '업데이트하러 가기';

  @override
  String routineForeignCreator(String name, String batchim) {
    String _temp0 = intl.Intl.selectLogic(batchim, {'yes': '이', 'other': '가'});
    return '$name$_temp0 만든 일과예요';
  }

  @override
  String get routineForeignCreatorUnknown => '다른 보호자가 만든 일과예요';

  @override
  String get routineDefaultTitle => '오늘의 일과';

  @override
  String get rewardPresetSnack => '좋아하는 간식';

  @override
  String get rewardPresetVideo => '유튜브 10분';

  @override
  String get rewardPresetPlay => '좋아하는 놀이';

  @override
  String get rewardPresetWalk => '산책';

  @override
  String get rewardPresetCustom => '직접 입력';

  @override
  String get roleGuardianWord => '보호자';

  @override
  String get roleElumiWord => '이룸이';

  @override
  String get roleLabelSuffix => '가 사용해요';

  @override
  String get roleGuardianDescription => '일과를 만들고 관리해요';

  @override
  String get roleElumiDescription => '일과를 실천해요';

  @override
  String get roleSelectTitle => '이 휴대폰은 누가\n사용하나요?';

  @override
  String get roleSelectDescription => '보호자모드와 이룸이모드가 나눠져 있어요';

  @override
  String get loginKakaoButton => '카카오로 로그인';

  @override
  String get loginNaverButton => '네이버로 로그인';

  @override
  String get loginAppleButton => 'Apple로 로그인';

  @override
  String get loginConnecting => '연결하고 있어요';

  @override
  String get loginLastUsed => '최근 로그인';

  @override
  String get loginDuplicateTitle => '이미 가입된 계정이에요';

  @override
  String get loginDuplicateFallback => '처음 쓰신 방법으로 로그인해주세요';

  @override
  String get loginOfflineTitle => '인터넷 연결을 확인해주세요';

  @override
  String get loginOfflineFallback => '연결한 뒤 다시 해주세요';

  @override
  String get loginFailedTitle => '로그인하지 못했어요';

  @override
  String get loginFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get consentTitle => '약관에 동의해주세요';

  @override
  String get consentLoading => '약관을 불러오고 있어요';

  @override
  String get consentSaving => '저장하고 있어요';

  @override
  String get consentSaveFailed => '동의를 저장하지 못했어요. 다시 해주세요';

  @override
  String get consentDescriptionReady => '항목을 눌러 상세 내용을 볼 수 있어요';

  @override
  String get consentDescriptionNeeded => '서비스 사용을 위해 약관 동의가 필요해요';

  @override
  String get consentAllAgree => '서비스 이용약관 전체 동의';

  @override
  String get consentRequiredTag => '필수';

  @override
  String get consentOptionalTag => '선택';

  @override
  String consentChipRequired(String label) {
    return '[필수] $label';
  }

  @override
  String consentChipOptional(String label) {
    return '[선택] $label';
  }

  @override
  String consentDocumentMeta(String label, String version) {
    return '$label · 버전 $version';
  }

  @override
  String get consentListTitle => '약관 및 개인정보처리방침';

  @override
  String get consentGroupRequired => '필수항목';

  @override
  String get consentGroupOptional => '선택항목';

  @override
  String get commonElumiName => '이룸이';

  @override
  String get characterCatLabel => '고양이';

  @override
  String get characterCatName => '루루';

  @override
  String get characterFoxLabel => '여우';

  @override
  String get characterFoxName => '포포';

  @override
  String get agentChickLabel => '병아리';

  @override
  String get imageStyleCartoonLabel => '만화';

  @override
  String get imageStyleCartoonDescription => '캐릭터가 나오는 그림이에요';

  @override
  String get imageStyleRealisticLabel => '실사';

  @override
  String get imageStyleRealisticDescription => '실제 물건 사진처럼 보여요';

  @override
  String get imageStylePhotoOnlyLabel => '직접 찍은 사진';

  @override
  String get imageStylePhotoOnlyDescription =>
      '그림은 직접 찍은 사진으로 넣어요. 글은 계속 만들어 드려요';

  @override
  String get goalStepByStep => '해야 할 일을 순서대로 이해해요';

  @override
  String get goalPrepareItems => '필요한 준비물을 스스로 챙겨요';

  @override
  String get goalPrepareNew => '새로운 상황을 미리 준비해요';

  @override
  String get goalIndependent => '혼자 끝까지 해내는 경험을 만들어요';

  @override
  String onboardingCharacterTitle(String name) {
    return '$name의 하루를 함께할\n친구를 골라주세요';
  }

  @override
  String get onboardingCharacterDescription => '선택한 친구가 카드 속 주인공이 되어 도와줘요';

  @override
  String onboardingGoalsTitle(String name) {
    return '$name의 어떤 순간을\n도와주고 싶으신가요?';
  }

  @override
  String get onboardingGoalsDescription => '여러 개를 선택할 수 있어요';

  @override
  String get onboardingImageStyleTitle => '카드 그림은 어떤 방식으로\n만들까요?';

  @override
  String get onboardingImageStyleDescription => '나중에 설정에서 바꿀 수 있어요';

  @override
  String get onboardingImageStyleSkip => '건너뛰기';

  @override
  String get onboardingNameTitle => '이룸이를 어떻게\n불러드릴까요?';

  @override
  String get onboardingNameDescription => '정확한 실명이 아니어도 괜찮아요';

  @override
  String get onboardingNameHint => '이름을 입력해주세요';

  @override
  String get onboardingNameInviteLink => '초대 코드가 있어요';

  @override
  String get onboardingCompletionTitle => '내용 정리가 모두\n완료됐어요';

  @override
  String get onboardingCompletionProgress => '100% 완료!';

  @override
  String get onboardingSplashLogoLabel => '이룸';

  @override
  String get pinCreateTitle => '보호자님만 아는\n비밀암호를 만들어주세요';

  @override
  String get pinConfirmTitle => '암호를 한번 더\n입력해주세요';

  @override
  String get pinDescription => '보호자모드로 변경할 때 사용하는 암호예요';

  @override
  String get pinMismatch => '암호가 달라요. 다시 넣어주세요';

  @override
  String get pinInputSemanticLabel => '암호 넣기';

  @override
  String get pinStartButton => '시작하기';

  @override
  String get pinProfileCreateFailedTitle => '이룸이를 만들지 못했어요';

  @override
  String get pinProfileCreateFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get pinSaveFailedTitle => '설정을 저장하지 못했어요';

  @override
  String get pinSaveFailedFallback => '설정 화면에서 다시 확인해주세요';
}
