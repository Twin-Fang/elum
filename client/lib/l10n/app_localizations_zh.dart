// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

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
}
