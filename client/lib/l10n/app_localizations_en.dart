// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get creditBlockedBusy => '이미 일과를 만들고 있어요.\n다 만든 뒤에 새 일과를 만들 수 있어요';

  @override
  String creditBlockedExhausted(String reset) {
    return '이번 주 크레딧을 모두 사용했어요.\n$reset부터 다시 만들 수 있어요';
  }

  @override
  String creditAdOffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '광고를 끝까지 보면 크레딧 $count개를 받아요',
    );
    return '$_temp0';
  }

  @override
  String creditReceivedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '크레딧 $count개를 받았어요',
    );
    return '$_temp0';
  }

  @override
  String get creditReceivedTitleNoCount => '크레딧을 받았어요';

  @override
  String get creditAdWatchMore => '광고 보고 더 만들기';

  @override
  String get adRewardPreparing => '광고를 준비하고 있어요';

  @override
  String get adRewardConfirming => '크레딧을 확인하고 있어요';

  @override
  String get adRewardLoadFailed => '지금은 광고를 불러올 수 없어요.\n잠시 후 다시 해주세요';

  @override
  String get adRewardNotWatched => '광고를 끝까지 봐야 크레딧을 받을 수 있어요.\n처음부터 다시 해주세요';

  @override
  String get adRewardSlow => '크레딧 확인이 늦어지고 있어요.\n잠시 후 설정에서 확인해주세요';

  @override
  String get adRewardDailyLimit => '오늘은 광고로 받을 수 있는 크레딧을 모두 받았어요.\n내일 다시 해주세요';

  @override
  String get adRewardCheckAccount => '지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요';

  @override
  String get adRewardUnavailable => '지금은 광고로 크레딧을 받을 수 없어요.';

  @override
  String get adRewardUnavailableRetry => '지금은 광고로 크레딧을 받을 수 없어요.\n잠시 후 다시 해주세요';

  @override
  String get adRewardFailed => '크레딧을 받지 못했어요.\n잠시 후 다시 해주세요';

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

  @override
  String get elumiSettingsTitle => '설정';

  @override
  String get elumiSettingsHapticLabel => '카드 체크 진동';

  @override
  String get elumiSettingsTermsLabel => '약관 및 개인정보처리방침';

  @override
  String get elumiSettingsLogoutLabel => '로그아웃';

  @override
  String get elumiSettingsWithdrawLabel => '회원탈퇴';

  @override
  String get elumiSettingsLogoutTitle => '로그아웃 하실건가요?';

  @override
  String get elumiSettingsLogoutMessage =>
      '이 휴대폰의 연결이 끊어져요\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요';

  @override
  String get elumiSettingsLogoutFailTitle => '로그아웃하지 못했어요';

  @override
  String get elumiSettingsWithdrawTitle => '회원탈퇴 하실건가요?';

  @override
  String get elumiSettingsWithdrawMessage =>
      '이 휴대폰의 연결만 끊어져요\n일과와 별은 보호자 휴대폰에 남고\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요';

  @override
  String get inviteRejectedOnElumiDevice =>
      '이 휴대폰에서는 초대를 받을 수 없어요\n보호자 휴대폰에서 열어주세요';

  @override
  String get elumiSettingsWithdrawFailTitle => '탈퇴하지 못했어요';

  @override
  String get elumiSettingsExitFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get linkStatusTitle => '이룸이 휴대폰';

  @override
  String get linkStatusRevokeConfirmTitle => '연결을 끊을까요?';

  @override
  String get linkStatusRevokeConfirmMessage =>
      '이룸이 휴대폰에서 일과를 볼 수 없어요\n다시 연결하려면 새 암호를 만들면 돼요';

  @override
  String get linkStatusRevokeConfirmAction => '연결 끊기';

  @override
  String get linkStatusRevokeFailTitle => '연결을 끊지 못했어요';

  @override
  String get linkStatusRevokeFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get linkStatusRevoked => '연결을 끊었어요';

  @override
  String get linkStatusAlreadyRevoked => '이미 끊겨 있어요';

  @override
  String get linkStatusLoadFailedFallback => '연결 상태를 불러오지 못했어요';

  @override
  String linkDeviceNumbered(int number) {
    return '이룸이 휴대폰 $number';
  }

  @override
  String get linkStatusConnected => '연결됨';

  @override
  String get linkStatusRevokeButton => '연결 끊기';

  @override
  String get linkStatusRevokeHint => '끊으면 이룸이 휴대폰에서\n일과를 볼 수 없어요';

  @override
  String get linkStatusEmpty => '연결된 휴대폰이 없어요';

  @override
  String get linkStatusConnectAction => '이룸이 휴대폰 연결하기';

  @override
  String get linkCodeSettingsTitle => '이룸이 휴대폰 연결';

  @override
  String linkCodeAskTitle(String name) {
    return '$name의 휴대폰을\n연결할까요?';
  }

  @override
  String linkCodeEnterHint(String name) {
    return '$name의 휴대폰에서 아래 코드를 입력하세요';
  }

  @override
  String get linkCodeIssueFailedFallback => '암호를 만들지 못했어요. 다시 해주세요';

  @override
  String get linkCodeExpired => '암호가 만료됐어요';

  @override
  String get linkCodeSuccessTitle => '휴대폰 연결에 성공했어요!';

  @override
  String get linkCodeStartButton => '시작하기';

  @override
  String get linkCodeLater => '나중에 할게요';

  @override
  String get linkRetryChipLabel => '코드 다시 만들기';

  @override
  String get linkEnterTitle => '보호자에게서 받은 코드를\n입력해주세요';

  @override
  String get linkEnterGuide => '코드는 보호자 휴대폰의\n설정 → 이룸이 휴대폰 연결하기에 있어요';

  @override
  String get linkEnterGuidePath => '설정 → 이룸이 휴대폰 연결하기';

  @override
  String get linkEnterLinkLost => '연결이 끊어졌어요\n보호자에게 새 연결 암호를 받아 입력해주세요';

  @override
  String get linkEnterStartButton => '시작하기';

  @override
  String get linkEnterInputLabel => '연결 암호 넣기';

  @override
  String get linkEnterWrongCode => '암호가 맞지 않아요';

  @override
  String get linkEnterExpired => '암호가 만료됐어요. 새 암호를 받아주세요';

  @override
  String get linkEnterOffline => '연결하지 못했어요. 인터넷을 확인해주세요';

  @override
  String get linkEnterFailed => '연결하지 못했어요. 다시 해주세요';

  @override
  String get commonGuardianName => '보호자';

  @override
  String get guardianKindGuardian => '보호자';

  @override
  String get guardianKindCaregiver => '센터 선생님';

  @override
  String inviteShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes분',
    );
    return '이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n초대 코드는 $_temp0 동안만 쓸 수 있어요.\n\n$url\n\n링크가 열리지 않으면 앱에서 직접 넣어주세요.\n초대 코드 $code';
  }

  @override
  String get guardiansEditTitle => '내 이름 고치기';

  @override
  String get guardiansEditDescription =>
      '이 이룸이를 함께 돌보는 사람에게 보이는 이름이에요. 실명이 아니어도 괜찮아요';

  @override
  String get guardiansEditNameHint => '엄마, 아빠, 센터 선생님';

  @override
  String get guardiansEditSave => '저장';

  @override
  String get guardiansLeaveConfirmTitle => '함께 돌보기를 그만둘까요?';

  @override
  String get guardiansLeaveConfirmMessageLast =>
      '함께하는 보호자가 없어요\n나가면 이룸이와 만든 일과, 모은 별이 모두 사라져요\n되돌릴 수 없어요';

  @override
  String get guardiansLeaveConfirmMessageOthers =>
      '내가 연결한 이룸이 휴대폰이 있다면 연결이 끊어져요\n남은 보호자가 새 연결 암호를 만들어야 다시 쓸 수 있어요\n내가 만든 일과는 사라져요\n이룸이와 다른 보호자의 일과·별은 그대로예요';

  @override
  String get guardiansLeaveConfirmAction => '그만두기';

  @override
  String get guardiansLeaveFailTitle => '나가지 못했어요';

  @override
  String get guardiansLeaveFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String guardiansLeft(String name) {
    return '$name에서 나왔어요';
  }

  @override
  String get guardiansNameEditFailTitle => '이름을 고치지 못했어요';

  @override
  String get guardiansNameEditFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get guardiansTitle => '함께하는 사람';

  @override
  String get guardiansNoProfileMessage => '함께하는 사람을 볼 이룸이가 없어요';

  @override
  String get guardiansNoProfileDescription => '이룸이를 먼저 등록해주세요';

  @override
  String guardiansCaption(String name) {
    return '$name를 함께 돌보는 사람이에요';
  }

  @override
  String get guardiansIntro =>
      '일과를 같이 만드는 가족이나 선생님이에요. 이룸이가 쓰는 휴대폰은 설정의 이룸이 휴대폰에서 연결해요';

  @override
  String get guardiansLoadFailedFallback => '함께하는 사람을 불러오지 못했어요';

  @override
  String get guardiansEmptyMessage => '함께하는 사람을 찾지 못했어요';

  @override
  String get guardiansAloneHint => '아직 혼자 돌보고 있어요. 가족이나 선생님을 초대해보세요';

  @override
  String get guardiansInviteAction => '다른 보호자 초대하기';

  @override
  String get guardiansEnterCodeAction => '받은 초대 코드 넣기';

  @override
  String get guardiansLeaveAction => '함께 돌보기 그만두기';

  @override
  String get guardiansLeaveHintAlone => '혼자 돌보고 있어서 그만두면 이룸이와 일과, 별이 모두 사라져요';

  @override
  String get guardiansLeaveHintWithOthers =>
      '내가 만든 일과만 사라지고, 다른 보호자의 일과는 그대로예요';

  @override
  String get guardiansMeBadge => '나';

  @override
  String get inviteCodeShareFailTitle => '링크를 보내지 못했어요';

  @override
  String get inviteCodeShareFailFallback => '초대 코드를 직접 알려주세요';

  @override
  String get inviteCodeExpired => '초대 코드가 만료됐어요';

  @override
  String get inviteCodeTitle => '초대 코드';

  @override
  String get inviteCodeShareButton => '링크로 보내기';

  @override
  String get inviteCodeHeaderTitle => '함께할 보호자에게\n코드를 알려주세요';

  @override
  String inviteCodeAsk(String name, String batchim) {
    String _temp0 = intl.Intl.selectLogic(batchim, {'yes': '을', 'other': '를'});
    return '받은 분이 $name$_temp0 함께 돌봐요';
  }

  @override
  String get inviteCodeNoProfileMessage => '함께 돌볼 이룸이가 없어요';

  @override
  String get inviteCodeNoProfileDescription => '이룸이를 먼저 등록해주세요';

  @override
  String get inviteCodeIssueFailedFallback => '초대 코드를 만들지 못했어요';

  @override
  String get inviteCodeRetryChip => '초대 코드 다시 만들기';

  @override
  String get inviteCodeRetryNote => '다시 만들면 이전 코드는 쓸 수 없어요';

  @override
  String get inviteCodeElumiPhoneNote =>
      '이룸이가 쓰는 휴대폰은 여기서 붙이지 않아요\n설정의 이룸이 휴대폰에서 연결해요';

  @override
  String get inviteEnterLinkInvalid =>
      '초대 링크가 맞지 않아요. 보낸 분께 다시 받아주세요 (E-INV-LINK)';

  @override
  String get inviteEnterFormInvalid => '초대 코드가 맞지 않아요 (E-INV-FORM)';

  @override
  String inviteJoined(String name, String batchim) {
    String _temp0 = intl.Intl.selectLogic(batchim, {'yes': '을', 'other': '를'});
    return '$name$_temp0 함께 돌보게 됐어요';
  }

  @override
  String get inviteEnterNotFound => '초대 코드가 맞지 않아요';

  @override
  String get inviteEnterExpired => '초대 코드가 만료됐어요. 새 코드를 받아주세요';

  @override
  String get inviteEnterTooManyAttempts => '잠시 뒤에 다시 해주세요';

  @override
  String get inviteEnterAlreadyGuardian => '이미 함께하고 있는 이룸이예요';

  @override
  String get inviteEnterForbiddenForElumi => '이룸이 휴대폰에서는 할 수 없어요';

  @override
  String get inviteEnterInvalidInput => '초대 코드가 맞지 않아요';

  @override
  String get inviteEnterOffline => '연결하지 못했어요. 인터넷을 확인해주세요';

  @override
  String get inviteEnterOther => '연결하지 못했어요. 다시 해주세요';

  @override
  String get inviteEnterConsentFailTitle => '초대 코드를 넣지 못했어요';

  @override
  String get inviteEnterConsentFallback => '약관에 먼저 동의해주세요';

  @override
  String get inviteEnterJoinButton => '함께하기';

  @override
  String get inviteEnterManualLink => '다른 코드 넣기';

  @override
  String get inviteEnterTitle => '초대 코드를\n넣어주세요';

  @override
  String get inviteEnterDescriptionFromLink =>
      '링크로 받은 초대 코드예요. 맞으면 함께하기를 눌러주세요';

  @override
  String get inviteEnterDescriptionManual => '함께하는 보호자에게 받은 여섯 글자예요';

  @override
  String get inviteEnterWhereFrom => '함께하는 보호자 휴대폰에서';

  @override
  String get inviteEnterWherePath => '설정 → 함께하는 사람';

  @override
  String get inviteEnterWhereHow => '초대 코드를 만들면 여섯 글자가 나와요';

  @override
  String get inviteEnterSemanticsFromLink => '링크로 받은 초대 코드';

  @override
  String get inviteEnterSemanticsInput => '초대 코드 넣기';

  @override
  String get profileSwitchChanged => '이룸이를 바꿨어요';

  @override
  String get profileSwitchTitle => '이룸이 바꾸기';

  @override
  String get profileSwitchLoadFailedFallback => '이룸이 목록을 불러오지 못했어요';

  @override
  String get profileSwitchLoadFailedMessage => '이룸이 목록을 불러오지 못했어요';

  @override
  String profileSwitchSelected(String name) {
    return '$name, 지금 보는 이룸이';
  }

  @override
  String get noticeHideWeek => '일주일간 보지 않기';

  @override
  String noticeHideDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일간 보지 않기',
    );
    return '$_temp0';
  }

  @override
  String noticeLinkOpenFailed(String code) {
    return '링크를 열지 못했어요 ($code)';
  }

  @override
  String get noticeCloseBarrier => '공지 닫기';

  @override
  String get cardPhotoTooLarge => '사진이 너무 커요. 다른 사진을 골라 주세요';

  @override
  String get cardPhotoWrongType => 'JPG나 PNG 사진만 올릴 수 있어요';

  @override
  String get cardPhotoUnreadable => '사진을 읽지 못했어요. 다른 사진을 골라 주세요';

  @override
  String get cardPhotoPickFailed => '사진을 가져오지 못했어요. 다시 해주세요';

  @override
  String get routineLoadingPrepareTitle => '루미가 내용을\n정리하고 있어요';

  @override
  String get routineLoadingGenerateTitle => '루미가 행동카드를\n만들고 있어요';

  @override
  String get routineStageReviewSituation => '적어 주신 상황을 살펴보고 있어요';

  @override
  String get routineStageTidyEssentials => '꼭 필요한 내용만 정리해요';

  @override
  String get routineStageThinkQuestions => '추가 질문을 생각하고 있어요';

  @override
  String get routineStageReadRoutine => '오늘의 일과를 읽고 있어요';

  @override
  String get routineStageFindItems => '중요한 준비물을 찾고 있어요';

  @override
  String get routineStageOrderSteps => '순서를 정리하고 있어요';

  @override
  String get suggestionRainyText => '비 오는 날 등교';

  @override
  String get suggestionRainyPrompt => '비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요';

  @override
  String get suggestionHospitalText => '병원 방문 준비';

  @override
  String get suggestionHospitalPrompt => '이룸이와 함께 병원에 가야 하는데 무서워하지 않게 준비하고 싶어요';

  @override
  String get suggestionTripText => '체험학습 준비';

  @override
  String get suggestionTripPrompt => '체험학습 가는 날 아침에 챙길 것들을 순서대로 알려주고 싶어요';

  @override
  String get suggestionNewPlaceText => '새로운 장소 방문';

  @override
  String get suggestionNewPlacePrompt =>
      '처음 가보는 장소에 가기 전에 이룸이가 마음의 준비를 하게 돕고 싶어요';

  @override
  String get suggestionAfterSchoolText => '여름방학 방과후 수업 준비';

  @override
  String get suggestionAfterSchoolPrompt => '방학 중 방과후 수업에 갈 준비를 순서대로 알려주고 싶어요';

  @override
  String get guardianHomeTodayRoutine => '오늘 일과';

  @override
  String get guardianHomePastRoutine => '지난 일과';

  @override
  String get guardianHomeGoChildScreen => '이룸이 화면으로 가기';

  @override
  String get guardianHomeSettings => '설정';

  @override
  String guardianHomeGreeting(String name) {
    return '안녕하세요,\n$name 보호자님 👋🏻';
  }

  @override
  String get guardianHomeSubtitle => '오늘은 어떤 일과를 준비할까요?';

  @override
  String get pinChangeMismatchCreate => '암호가 달라요. 다시 넣어주세요';

  @override
  String get pinChangeMismatch => '암호가 달라요. 다시 입력해주세요';

  @override
  String get pinChangeCreateFailedTitle => '비밀암호를 만들지 못했어요';

  @override
  String get pinChangeFailedTitle => '비밀암호를 바꾸지 못했어요';

  @override
  String get pinChangeFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get pinChangeCreatedSnack => '비밀암호를 만들었어요';

  @override
  String get pinChangeChangedSnack => '비밀암호를 바꿨어요';

  @override
  String get pinChangeVerifyTitle => '지금 비밀암호를\n입력해주세요';

  @override
  String get pinChangeCreateTitle => '보호자님만 아는\n비밀암호를 만들어주세요';

  @override
  String get pinModeHint => '보호자모드로 변경할 때 사용하는 암호예요';

  @override
  String get pinChangeEnterTitle => '새 비밀암호를\n입력해주세요';

  @override
  String get pinChangeCreateConfirmTitle => '암호를 한번 더\n입력해주세요';

  @override
  String get pinChangeConfirmTitle => '비밀암호를 한번 더\n입력해주세요';

  @override
  String get pinChangeConfirmHint => '이제 곧 비밀암호 변경이 끝나요';

  @override
  String get pinChangeHeaderTitle => '비밀암호 변경하기';

  @override
  String get pinChangeSave => '저장하기';

  @override
  String get pinChangeInputLabel => '암호 넣기';

  @override
  String get rewardSaveFailedTitle => '보상을 저장하지 못했어요';

  @override
  String get rewardSaveFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get rewardWhyTitle => '보상이 왜 필요한가요?';

  @override
  String get rewardWhyMessage =>
      '일과를 마친 뒤 기다리는 것이 있으면 이룸이가 끝까지 해낼 힘이 생겨요.\n한 달 뒤 선물보다 오늘 바로 줄 수 있는 작은 것이 더 잘 통해요.\n정하지 않아도 일과는 만들 수 있어요.';

  @override
  String get rewardHeadlineTitle => '일과가 끝나면\n어떤 보상을 줄까요?';

  @override
  String get rewardHeadlineBody => '일과를 완료하는 데 큰 동기가 될 거예요';

  @override
  String get rewardLater => '나중에 할게요';

  @override
  String get imageStyleChangedSnack => '그림 방식을 바꿨어요';

  @override
  String get imageStyleSaveFailedTitle => '그림 방식을 저장하지 못했어요';

  @override
  String get imageStyleSaveFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get imageStyleTitle => '그림 방식';

  @override
  String get routineLoadingBlockedTitle => '지금은 만들 수 없어요';

  @override
  String get routineLoadingPrepareFailed => '질문을 준비하지 못했어요';

  @override
  String get routineLoadingGenerateFailed => '카드를 만들지 못했어요';

  @override
  String routineLoadingPercent(int percent) {
    return '$percent% 진행됐어요';
  }

  @override
  String get routineLoadingRetry => '다시 하기';

  @override
  String get routineLoadingHome => '홈으로';

  @override
  String get draftRoutinesTitle => '임시저장';

  @override
  String get draftRoutinesLoadFailedFallback => '임시저장을 불러오지 못했어요';

  @override
  String get draftRoutinesDeleteLabel => '임시저장 삭제';

  @override
  String get draftRoutinesDeleteConfirmTitle => '임시저장을 삭제하실건가요?';

  @override
  String get draftRoutinesDeleteAction => '삭제';

  @override
  String get draftRoutinesDeleteFailedTitle => '임시저장을 삭제하지 못했어요';

  @override
  String get draftRoutinesDeleteFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get draftRoutinesRewardUnset => '미설정';

  @override
  String get draftRoutinesRewardLabel => '완료 시';

  @override
  String get draftRoutinesResume => '이어서';

  @override
  String get draftRoutinesEmptyTitle => '만들다 만 일과가 없어요';

  @override
  String get draftRoutinesEmptyBody => '일과를 만들다 그만두면 여기에 남아요';

  @override
  String get cardReviewDeleteConfirmTitle => '카드를 삭제하실건가요?';

  @override
  String get cardReviewDeleteAction => '삭제';

  @override
  String get cardReviewSoundFailedTitle => '소리를 재생하지 못했어요';

  @override
  String get cardReviewSoundFailedFallback => '휴대폰 소리를 켜고 다시 눌러주세요';

  @override
  String get cardReviewSaveFailedTitle => '일과를 저장하지 못했어요';

  @override
  String get cardReviewSaveFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get cardReviewEditFailedTitle => '고친 내용을 저장하지 못했어요';

  @override
  String get cardReviewEditFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get cardReviewAddFailedTitle => '카드를 추가하지 못했어요';

  @override
  String get cardReviewAddFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get cardReviewReorderDone => '완료';

  @override
  String get cardReviewSave => '카드 저장하기';

  @override
  String get routineInputTitle => '오늘은 어떤 준비가\n필요한가요?';

  @override
  String get routineInputSubtitle => 'AI 루미가 작은 행동 단계로 나눠드려요';

  @override
  String get routineInputHint => '평소 이야기하듯 입력해주세요';

  @override
  String get routineInputSend => '보내기';

  @override
  String get guardianSettingsLogoutConfirmTitle => '로그아웃 하실건가요?';

  @override
  String get guardianSettingsWithdrawConfirmTitle => '회원탈퇴 하실건가요?';

  @override
  String get guardianSettingsWithdrawConfirmMessage =>
      '만든 일과와 모은 별이 모두 사라져요\n다시 로그인해도 되돌릴 수 없어요';

  @override
  String get guardianSettingsWithdrawFailedTitle => '탈퇴하지 못했어요';

  @override
  String get guardianSettingsWithdrawFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get guardianSettingsTitle => '설정';

  @override
  String get guardianSettingsPeople => '함께하는 사람';

  @override
  String get guardianSettingsDrafts => '임시저장';

  @override
  String get guardianSettingsPinChange => '비밀암호 변경하기';

  @override
  String get guardianSettingsTerms => '약관 및 개인정보처리방침';

  @override
  String get guardianSettingsLogout => '로그아웃';

  @override
  String get guardianSettingsWithdraw => '회원탈퇴';

  @override
  String get guardianSettingsLinkConnected => '이룸이 휴대폰';

  @override
  String get guardianSettingsLinkConnect => '이룸이 휴대폰 연결하기';

  @override
  String get guardianSettingsLinkStatus => '연결됨';

  @override
  String get guardianSettingsProfileSwitch => '이룸이 바꾸기';

  @override
  String get guardianSettingsImageStyle => '그림 방식';

  @override
  String get guardianSettingsHaptic => '카드 체크 진동';

  @override
  String get questionMakeCards => '카드 만들기';

  @override
  String get questionCustomAdd => '+ 직접 입력하기';

  @override
  String get questionCustomHint => '직접 적어주세요';

  @override
  String get questionCustomClose => '직접 입력 닫기';

  @override
  String questionClearLabel(String label) {
    return '$label 지우기';
  }

  @override
  String cardReviewMade(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '카드 $count개를 만들었어요',
    );
    return '$_temp0';
  }

  @override
  String get cardReviewRewardLead => '완료 시 ';

  @override
  String get cardReviewRewardSet => '보상 정하기';

  @override
  String get cardReviewReorderHint => '카드를 길게 눌러 순서를 변경하세요';

  @override
  String get cardReviewToolReorder => '카드 순서 변경';

  @override
  String get cardReviewToolEdit => '이 카드 수정';

  @override
  String get cardReviewToolAdd => '카드 추가';

  @override
  String get cardReviewReorderTitle => '카드 순서 변경';

  @override
  String get cardReviewReorderCancel => '순서 변경 취소';

  @override
  String get cardReviewEmptyTitle => '만들어진 카드가 없어요';

  @override
  String get cardReviewEmptyBody => '다시 만들어 주세요 (E-CARD)';

  @override
  String get cardMoveForward => '앞으로 옮기기';

  @override
  String get cardMoveBackward => '뒤로 옮기기';

  @override
  String get cardSpeakStop => '읽기 멈추기';

  @override
  String get cardSpeak => '소리로 듣기';

  @override
  String get cardDeleteLabel => '이 카드 지우기';

  @override
  String get cardAddPhoto => '사진 추가';

  @override
  String get cardViewerBarrierLabel => '카드 닫기';

  @override
  String get cardViewerSoundFailedTitle => '소리를 재생하지 못했어요';

  @override
  String get cardViewerSoundFailedFallback => '휴대폰 소리를 켜고 다시 눌러주세요';

  @override
  String get cardViewerClose => '카드 닫기';

  @override
  String get cardEditAddTitle => '새로운 카드 추가';

  @override
  String get cardEditTitle => '카드 수정';

  @override
  String get cardEditFieldTitle => '제목';

  @override
  String get cardEditTitleHint => '카드 제목을 적어주세요';

  @override
  String get cardEditFieldDescription => '설명';

  @override
  String get cardEditDescriptionHint => '카드 설명을 적어주세요';

  @override
  String get cardEditAddAction => '추가하기';

  @override
  String get cardEditDoneAction => '완료';

  @override
  String get cardPhotoPermissionTake => '사진 찍기';

  @override
  String get cardPhotoPermissionGallery => '갤러리에서 고르기';

  @override
  String get cardPhotoPermissionOpenSettings => '설정 열기';

  @override
  String get cardPhotoPermissionCameraTitle => '카메라를 쓸 수 없어요';

  @override
  String get cardPhotoPermissionGalleryTitle => '사진을 볼 수 없어요';

  @override
  String get cardPhotoPermissionCameraBody => '휴대폰 설정에서 카메라를 켜면 사진을 찍을 수 있어요';

  @override
  String get cardPhotoPermissionGalleryBody => '휴대폰 설정에서 사진 접근을 켜면 고를 수 있어요';

  @override
  String get cardPhotoSettingsFailedTitle => '설정을 열지 못했어요';

  @override
  String get cardPhotoSettingsFailedFallback => '휴대폰 설정에서 직접 켜 주세요';

  @override
  String get cardPhotoSourceTake => '사진 찍기';

  @override
  String get cardPhotoSourceGallery => '갤러리에서 고르기';

  @override
  String get cardPhotoSourcePrivacy => '얼굴이나 개인정보가 나오지 않게 찍어 주세요';

  @override
  String cardPhotoUploadFailedDialog(String message) {
    return '사진을 올리지 못했어요.\n$message';
  }

  @override
  String get cardPhotoChange => '사진 바꾸기';

  @override
  String get cardPhotoUploading => '사진을 올리고 있어요';

  @override
  String get cardPhotoUploadFailed => '사진을 올리지 못했어요';

  @override
  String get cardPhotoRetry => '다시 하기';

  @override
  String get creditCardTitle => '이번 주 AI 생성';

  @override
  String get creditCardLoading => '이번 주 AI 생성 사용량을 불러오고 있어요';

  @override
  String get creditCardLoadFailed => '사용량을 불러오지 못했어요';

  @override
  String get creditCardRetry => '다시 하기';

  @override
  String get creditGenerating => '일과를 만들고 있어요';

  @override
  String get creditExhausted => '이번 주 크레딧을 모두 사용했어요';

  @override
  String get creditExhaustedStillOk => '만든 일과 보기와 직접 고치기는 계속 할 수 있어요';

  @override
  String get creditInfoLabel => 'AI 크레딧 안내';

  @override
  String creditAmountLeft(int available, int weekly) {
    return '$available / $weekly 크레딧 남음';
  }

  @override
  String creditAmountRest(int weekly) {
    return ' / $weekly 크레딧 남음';
  }

  @override
  String aiCreditResetLine(String reset) {
    return '$reset에 다시 채워져요';
  }

  @override
  String get creditCostTitle => 'AI 크레딧은 이렇게 줄어요';

  @override
  String creditCostLine(int textCost, int imageCost) {
    String _temp0 = intl.Intl.pluralLogic(
      textCost,
      locale: localeName,
      other: '$textCost개',
    );
    String _temp1 = intl.Intl.pluralLogic(
      imageCost,
      locale: localeName,
      other: '$imageCost개',
    );
    return '일과 글을 만들 때 $_temp0, 그림이 완성된 카드 1장마다 $_temp1씩 써요.';
  }

  @override
  String get creditCostKeepGoing => '크레딧이 남아 있을 때 시작한 일과는 그림이 많아도 끝까지 만들어져요.';

  @override
  String get creditWeeklyRefill => '매주 월요일 0시에 다시 채워져요.';

  @override
  String get routineCreateButton => '새로운 일과 만들기';

  @override
  String get routineSwipeDelete => '일과 삭제';

  @override
  String get routineSwipeEdit => '일과 수정';

  @override
  String get routineSuggestLoadFailed => '추천을 불러오지 못했어요 · 다시 시도';

  @override
  String get routineFlowHomeLabel => '홈으로 가기';

  @override
  String get routineFlowDraftLabel => '임시저장';

  @override
  String get routineFlowLeaveStay => '계속 만들기';

  @override
  String get routineFlowLeaveConfirm => '나가기';

  @override
  String get routineLeaveDiscardTitle => '일과 만들기를 그만둘까요?';

  @override
  String get routineLeaveDiscardMessage => '지금 나가면 적은 내용은 남지 않아요';

  @override
  String get routineLeaveDraftWhenReadyTitle => '임시저장에 두고 나갈까요?';

  @override
  String get routineLeaveDraftWhenReadyMessage =>
      '카드가 다 만들어지면 임시저장에 남아요\n설정에서 이어서 만들 수 있어요';

  @override
  String get routineLeaveDraftTitle => '임시저장에 두고 나갈까요?';

  @override
  String get routineLeaveDraftMessage => '설정의 임시저장에서\n이어서 만들 수 있어요';

  @override
  String get routineLeaveEditTitle => '저장하지 않고 나갈까요?';

  @override
  String get routineLeaveEditMessage => '뺀 카드는 저장하기를 눌러야 빠져요';

  @override
  String get routineTileRewardLabel => '완료 시';

  @override
  String get routineTileRerun => '일과 다시하기';

  @override
  String get routineDetailReorderFailedTitle => '순서를 저장하지 못했어요';

  @override
  String get routineDetailReorderFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get routineDetailRerun => '일과 다시하기';

  @override
  String get routineDetailEdit => '편집하기';

  @override
  String get routineDetailFinishedToday => '다 끝낸 일과예요';

  @override
  String get routineDetailOpenHint => '눌러서 카드 크게 보기';

  @override
  String get routineDetailNoReward => '일과 완료 후 보상이 없어요';

  @override
  String get rewardInputHint => '예) 유튜브 10분 보기';

  @override
  String get todayRoutineReorderFailedTitle => '순서를 저장하지 못했어요';

  @override
  String get todayRoutineReorderFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get todayRoutineDeleteConfirmTitle => '일과를 삭제하실건가요?';

  @override
  String get todayRoutineStartedTitle => '이룸이가 시작한 일과예요';

  @override
  String get todayRoutineStartedMessage => '한 일이 기록으로 남도록 지울 수 없어요';

  @override
  String get todayRoutineDeleteAction => '삭제';

  @override
  String get todayRoutineDeleteFailedTitle => '일과를 삭제하지 못했어요';

  @override
  String get todayRoutineDeleteFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get todayRoutineLoadFailedFallback => '일과를 불러오지 못했어요';

  @override
  String get todayRoutineRerunFailedTitle => '일과를 다시 만들지 못했어요';

  @override
  String get todayRoutineRerunFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String todayRoutineCopied(String title) {
    return '$title을(를) 오늘 일과에 담았어요';
  }

  @override
  String get todayRoutinePastLoadFailedFallback => '지난 일과를 불러오지 못했어요';

  @override
  String get todayRoutineEmptyTitle => '아직 만든 일과가 없어요';

  @override
  String get todayRoutineEmptyHint => '오늘의 첫 행동카드를 만들어보세요';

  @override
  String get todayRoutinePastEmpty => '지난 일과가 없어요';

  @override
  String get homeCoachCreate => '이룸이가 수행할 *새로운\n일과를 만들 수 있어요*';

  @override
  String get homeCoachSwipe => '일과를 *왼쪽으로 스와이프*하면\n*수정하거나 삭제*할 수 있어요';

  @override
  String get homeCoachSwitch => '캐릭터 아이콘을 누르면\n*이룸이모드로 바꿀 수 있어요*';

  @override
  String childHomeGreeting(String name, String batchim) {
    String _temp0 = intl.Intl.selectLogic(batchim, {'yes': '이', 'other': '가'});
    return '오늘 $name$_temp0\n할 일들이에요. 힘내봐요!';
  }

  @override
  String childHomeEmptyTitle(String name) {
    return '아직 $name의\n일과가 없어요';
  }

  @override
  String get childHomeEmptyHint => '보호자 화면에서 일과를 만들 수 있어요';

  @override
  String get childHomeEmptyHintDevice => '보호자 휴대폰에서 일과를 만들 수 있어요';

  @override
  String get childHomeToGuardianLabel => '보호자 화면으로 가기';

  @override
  String get childHomeSettingsLabel => '설정 열기';

  @override
  String get childHomeRewardPrefix => '다하면';

  @override
  String childStarsEarned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!',
    );
    return '$_temp0';
  }

  @override
  String childStarsSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '별 $count개 모았어요',
    );
    return '$_temp0';
  }

  @override
  String childCardPagerLabel(int total, int index) {
    return '카드 $total장 중 $index번째';
  }

  @override
  String get childDetailSoundFailedTitle => '소리를 재생하지 못했어요';

  @override
  String get childDetailSoundFailedFallback => '휴대폰 소리를 켜고 다시 눌러주세요';

  @override
  String get childDetailCheckLabel => '다 했어요';

  @override
  String get rewardBannerPrefix => '다하면 ';

  @override
  String get rewardLumiTitle => '축하해요!';

  @override
  String rewardLumiMessage(String name) {
    return '할 일을 해내서 루미가\n$name에게 별을 가져왔어요';
  }

  @override
  String get rewardLumiButton => '오예!';

  @override
  String get rewardPopoTitle => '잘했어요!';

  @override
  String rewardPopoMessage(String name) {
    return '포포가 $name에게\n축하의 선물로 큰 별을 가져왔어요';
  }

  @override
  String get rewardPopoButton => '좋아요!';

  @override
  String get rewardRuruTitle => '멋져요!';

  @override
  String rewardRuruMessage(String name, String batchim) {
    String _temp0 = intl.Intl.selectLogic(batchim, {'yes': '이', 'other': '가'});
    return '$name$_temp0 할 일을 해내서\n루루가 선물을 가져왔다고 해요';
  }

  @override
  String get rewardRuruButton => '신난다!';

  @override
  String get routineDoneTitle => '일과를 끝냈어요!';

  @override
  String get routineDoneButton => '오예!';

  @override
  String get modeSwitchToChild => '암호를 입력하면 이룸이 화면으로 바뀌어요';

  @override
  String get modeSwitchToGuardian => '암호를 입력하면 보호자 화면으로 바뀌어요';

  @override
  String get modeSwitchTitle => '비밀암호를 입력하세요';

  @override
  String get modeSwitchMismatch => '암호가 달라요. 다시 넣어주세요';

  @override
  String get modeSwitchPinLabel => '암호 넣기';

  @override
  String get modeSwitchReadFailedTitle => '암호를 확인하지 못했어요';

  @override
  String get modeSwitchReadFailedFallback => '잠시 후 다시 해주세요';

  @override
  String get modeSwitchBlockedTitle => '보호자 휴대폰에서\n열어 주세요';

  @override
  String get modeSwitchBlockedDescription => '이 휴대폰에서는 보호자 화면을 열 수 없어요';

  @override
  String get modeSwitchBlockedBack => '돌아가기';
}
