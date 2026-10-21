// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

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
  String get adRewardSlow => '크레딧 확인이 늦어지고 있어요.\n잠시 후 내정보에서 확인해주세요';

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
  String get appStatusMaintenanceTitle => '지금 점검 중이에요';

  @override
  String get appStatusMaintenanceBody => '점검이 끝나면 다시 쓸 수 있어요.\n조금 뒤에 확인해주세요';

  @override
  String get appStatusRecheck => '다시 확인하기';

  @override
  String get appStatusUpdateTitle => '지금 업데이트하고\n새로워진 이룸을 이용해보세요!';

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
  String get roleSelectTitle => '이 기기는 누가\n사용하나요?';

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
  String get imageStylePhotoOnlyLabel => '기본 그림';

  @override
  String get imageStylePhotoOnlyDescription => '간단한 그림 기호가 들어가요';

  @override
  String get imageStyleCreditLabel => '크레딧';

  @override
  String imageStyleCreditRoutine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '일과 $count개',
    );
    return '$_temp0';
  }

  @override
  String imageStyleCreditImage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '그림 한 장 $count개',
    );
    return '$_temp0';
  }

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
  String get onboardingImageStyleTitle => '카드 그림은 어떤 방식으로\n만들까요?';

  @override
  String get onboardingImageStyleDescription => '나중에 설정에서 바꿀 수 있어요';

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
  String get elumiSettingsPraiseSoundLabel => '카드 체크 칭찬 소리';

  @override
  String get elumiSettingsTermsLabel => '약관 및 개인정보처리방침';

  @override
  String get elumiSettingsLogoutLabel => '로그아웃';

  @override
  String get elumiSettingsWithdrawLabel => '회원탈퇴';

  @override
  String get elumiSettingsLogoutTitle => '로그아웃할까요?';

  @override
  String get elumiSettingsLogoutMessage =>
      '이 기기의 연결이 끊어져요\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요';

  @override
  String get elumiSettingsLogoutFailTitle => '로그아웃하지 못했어요';

  @override
  String get elumiSettingsWithdrawTitle => '회원탈퇴할까요?';

  @override
  String get elumiSettingsWithdrawMessage =>
      '이 기기의 연결만 끊어져요\n일과와 별은 보호자 기기에 남고\n다시 쓰려면 보호자에게\n연결 암호를 받아야 해요';

  @override
  String get inviteRejectedOnElumiDevice =>
      '이 기기에서는 초대를 받을 수 없어요\n보호자 기기에서 열어주세요';

  @override
  String get elumiSettingsWithdrawFailTitle => '탈퇴하지 못했어요';

  @override
  String get elumiSettingsExitFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get linkStatusTitle => '이룸이 기기';

  @override
  String get linkStatusRevokeConfirmTitle => '연결을 끊을까요?';

  @override
  String get linkStatusRevokeConfirmMessage =>
      '이룸이 기기에서 일과를 볼 수 없어요\n다시 연결하려면 새 암호를 만들면 돼요';

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
    return '이룸이 기기 $number';
  }

  @override
  String get linkStatusConnected => '연결됨';

  @override
  String get linkStatusRevokeButton => '연결 끊기';

  @override
  String get linkStatusRevokeHint => '끊으면 이룸이 기기에서\n일과를 볼 수 없어요';

  @override
  String get linkStatusEmpty => '연결된 기기가 없어요';

  @override
  String linkStatusConnectedBy(String name, String batchim) {
    String _temp0 = intl.Intl.selectLogic(batchim, {'yes': '이', 'other': '가'});
    return '$name$_temp0 연결';
  }

  @override
  String get linkStatusConnectedByMe => '내가 연결';

  @override
  String linkStatusConnectedByAndSince(String by, String since) {
    return '$by · $since';
  }

  @override
  String get linkStatusAddAction => '+ 다른 기기 연결하기';

  @override
  String get linkStatusConnectAction => '이룸이 기기 연결하기';

  @override
  String get linkCodeSettingsTitle => '이룸이 기기 연결';

  @override
  String linkCodeAskTitle(String name) {
    return '$name의 기기를\n연결할까요?';
  }

  @override
  String linkCodeEnterHint(String name) {
    return '$name의 기기에서 아래 코드를 입력하세요';
  }

  @override
  String get linkCodeIssueFailedFallback => '암호를 만들지 못했어요. 다시 해주세요';

  @override
  String get linkCodeSuccessTitle => '기기 연결에 성공했어요!';

  @override
  String get linkCodeStartButton => '시작하기';

  @override
  String get linkCodeLater => '나중에 할게요';

  @override
  String get linkCodeChangesAfter => '뒤에 코드가 바껴요';

  @override
  String get linkRetryChipLabel => '코드 다시 만들기';

  @override
  String get linkEnterTitle => '보호자에게서 받은 코드를\n입력해주세요';

  @override
  String get linkEnterGuide => '코드는 보호자 기기의\n설정 → 이룸이 기기 연결하기에 있어요';

  @override
  String get linkEnterGuidePath => '설정 → 이룸이 기기 연결하기';

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
  String get guardianKindCaregiver => '선생님';

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
  String get guardiansEditTitle => '내 이름 변경하기';

  @override
  String get guardiansEditDescription =>
      '이룸이를 함께 돌보는 사람에게 보이는 이름이에요.\n실명이 아니어도 괜찮아요';

  @override
  String get guardiansEditNameHint => '엄마, 아빠, 선생님';

  @override
  String get guardiansEditSave => '저장하기';

  @override
  String get guardiansLeaveConfirmTitle => '함께 돌보기를 그만둘까요?';

  @override
  String get guardiansLeaveConfirmMessageLast =>
      '함께하는 보호자가 없어요\n나가면 이룸이와 만든 일과, 모은 별이 모두 사라져요\n되돌릴 수 없어요';

  @override
  String get guardiansLeaveConfirmMessageOthers =>
      '내가 연결한 이룸이 기기가 있다면 연결이 끊어져요\n남은 보호자가 새 연결 암호를 만들어야 다시 쓸 수 있어요\n내가 만든 일과는 사라져요\n이룸이와 다른 보호자의 일과·별은 그대로예요';

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
  String get guardiansIntro => '일과를 같이 만드는 가족이나 선생님이에요';

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
  String get guardiansLeaveHintWithOthers => '내가 만든 일과만 사라져요';

  @override
  String inviteCodeGuestJoinedTitle(String name) {
    return '$name님이 함께하게 됐어요';
  }

  @override
  String get guardiansMeBadge => '나';

  @override
  String guardiansPeopleHeader(int count) {
    return '함께 돌보는 사람 $count명';
  }

  @override
  String get guardiansInviteHeader => '초대';

  @override
  String get guardiansRenameAction => '이름 변경';

  @override
  String get inviteCodeShareFailTitle => '링크를 보내지 못했어요';

  @override
  String get inviteCodeShareFailFallback => '코드를 직접 알려주세요';

  @override
  String get inviteCodeTitle => '초대 코드';

  @override
  String get inviteCodeShareButton => '링크로 보내기';

  @override
  String get inviteCodeHeaderTitle => '함께할 보호자에게\n코드를 알려주세요';

  @override
  String inviteCodeAsk(String name, String batchim) {
    String _temp0 = intl.Intl.selectLogic(batchim, {'yes': '을', 'other': '를'});
    return '코드를 받은 분이 $name$_temp0 함께 돌봐요';
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
  String get inviteEnterForbiddenForElumi => '이룸이 기기에서는 할 수 없어요';

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
  String get inviteEnterStartButton => '시작하기';

  @override
  String get inviteEnterManualLink => '다른 코드 넣기';

  @override
  String get inviteEnterTitle => '초대 코드를\n입력해주세요';

  @override
  String get inviteEnterDescriptionFromLink =>
      '링크로 받은 초대 코드예요. 맞으면 시작하기를 눌러주세요';

  @override
  String get inviteEnterDescriptionManual =>
      '코드는 함께하는 보호자 기기의\n내정보 → 함께하는 사람에 있어요';

  @override
  String get inviteEnterDescriptionPath => '내정보 → 함께하는 사람';

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
  String get notificationBellLabel => '알림';

  @override
  String get notificationBellUnreadLabel => '읽지 않은 알림이 있어요';

  @override
  String get notificationTabNotifications => '알림';

  @override
  String get notificationTabNotices => '공지사항';

  @override
  String get notificationDayToday => '오늘';

  @override
  String get notificationDayYesterday => '어제';

  @override
  String get notificationDayEarlier => '이전';

  @override
  String get notificationMarkAllRead => '모두 읽음';

  @override
  String get notificationEmpty => '아직 받은 알림이 없어요';

  @override
  String get notificationNoticeEmpty => '아직 올라온 공지가 없어요';

  @override
  String get notificationNoticeFailed => '공지를 불러오지 못했어요';

  @override
  String get notificationSettingsTitle => '알림 설정';

  @override
  String get notificationSettingAll => '모든 알림 받기';

  @override
  String get notificationSettingRoutineCompleted => '이룸이가 일과를 끝냈을 때';

  @override
  String get notificationSettingRoutineSent => '다른 보호자가 일과를 보냈을 때';

  @override
  String get notificationSettingCoGuardianJoined => '새 보호자가 함께할 때';

  @override
  String get notificationSettingCreditRefilled => '이번 주 크레딧이 채워졌을 때';

  @override
  String get notificationSettingFeedbackResolved => '의견을 처리했을 때';

  @override
  String get notificationSettingTalkCommented => '이야기: 내 글에 댓글이 달렸을 때';

  @override
  String get notificationSettingTalkImported => '이야기: 내 글을 가져갔을 때';

  @override
  String get notificationPermissionOff => '기기 알림이 꺼져 있어요';

  @override
  String get notificationTurnOnDeviceNotification => '켜기';

  @override
  String get notificationSettingSaveFailed => '설정을 저장하지 못했어요';

  @override
  String get notificationSettingLoadFailed => '설정을 불러오지 못했어요';

  @override
  String get notificationListFailed => '알림을 불러오지 못했어요';

  @override
  String get notificationProfileUnavailable => '이 이룸이의 알림은 더 볼 수 없어요';

  @override
  String notificationRoutineCompletedOne(String title) {
    return '\'$title\' 일과를 끝냈어요';
  }

  @override
  String notificationRoutineCompletedMany(int count) {
    return '일과 $count개를 끝냈어요';
  }

  @override
  String get notificationRoutineCompletedNoTitle => '일과를 끝냈어요';

  @override
  String notificationRoutineSent(String title) {
    return '함께하는 보호자가 \'$title\' 일과를 보냈어요';
  }

  @override
  String get notificationRoutineSentNoTitle => '함께하는 보호자가 새 일과를 보냈어요';

  @override
  String get notificationCoGuardianJoined => '새 보호자가 함께하기 시작했어요';

  @override
  String get notificationCreditRefilled => '이번 주 크레딧이 채워졌어요';

  @override
  String get notificationFeedbackResolved => '보내 주신 의견을 확인하고 처리했어요';

  @override
  String notificationTalkPostCommented(int count) {
    return '내 글에 댓글이 $count개 달렸어요';
  }

  @override
  String notificationTalkPostImported(int count) {
    return '보호자 $count명이 내 글을 가져갔어요';
  }

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
  String get draftRoutinesDeleteConfirmTitle => '임시저장을 삭제할까요?';

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
  String get cardReviewDeleteConfirmTitle => '카드를 삭제할까요?';

  @override
  String get cardReviewDeleteAction => '삭제';

  @override
  String get cardReviewSoundFailedTitle => '소리를 재생하지 못했어요';

  @override
  String get cardReviewSoundFailedFallback => '기기 소리를 켜고 다시 눌러주세요';

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
  String get cardImageGeneratingLabel => '그림을 만들고 있어요';

  @override
  String get cardImageNoCreditToast => '크레딧이 모자라 기본 그림을 넣었어요';

  @override
  String get cardImageUnavailableToast => '그림을 만들지 못해 기본 그림을 넣었어요';

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
  String get guardianSettingsLogoutConfirmTitle => '로그아웃할까요?';

  @override
  String get guardianSettingsWithdrawConfirmTitle => '회원탈퇴할까요?';

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
  String get guardianSettingsFeedback => '의견 보내기';

  @override
  String get feedbackTitle => '의견 보내기';

  @override
  String get feedbackHint => '불편했던 점을 편하게 적어 주세요';

  @override
  String get feedbackIncludeLog => '앱 상태 기록과 기기 정보 보내기';

  @override
  String get feedbackSend => '보내기';

  @override
  String get feedbackSent => '의견을 보냈어요';

  @override
  String get feedbackFailedTitle => '의견을 보내지 못했어요';

  @override
  String get feedbackFailedFallback => '적은 글은 그대로 있어요. 잠시 후 다시 보내 주세요';

  @override
  String get guardianSettingsLogout => '로그아웃';

  @override
  String get guardianSettingsWithdraw => '회원탈퇴';

  @override
  String get guardianSettingsLinkConnected => '이룸이 기기';

  @override
  String get guardianSettingsLinkConnect => '이룸이 기기 연결하기';

  @override
  String get guardianSettingsLinkStatus => '연결됨';

  @override
  String get guardianSettingsProfileSwitch => '이룸이 바꾸기';

  @override
  String get guardianSettingsImageStyle => '그림 방식';

  @override
  String get guardianSettingsHaptic => '카드 체크 진동';

  @override
  String get guardianSettingsPraiseSound => '카드 체크 칭찬 소리';

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
  String get cardReviewEmptyBody => '일과를 처음부터 다시 만들어 주세요';

  @override
  String get cardReviewEmptyAction => '다시 만들기';

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
  String get cardViewerSoundFailedFallback => '기기 소리를 켜고 다시 눌러주세요';

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
  String get cardPhotoPermissionCameraBody => '기기 설정에서 카메라를 켜면 사진을 찍을 수 있어요';

  @override
  String get cardPhotoPermissionGalleryBody => '기기 설정에서 사진 접근을 켜면 고를 수 있어요';

  @override
  String get cardPhotoSettingsFailedTitle => '설정을 열지 못했어요';

  @override
  String get cardPhotoSettingsFailedFallback => '기기 설정에서 직접 켜 주세요';

  @override
  String get cardPhotoSourceTake => '사진 찍기';

  @override
  String get cardPhotoSourceGallery => '갤러리에서 고르기';

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
      '카드가 다 만들어지면 임시저장에 남아요\n내정보에서 이어서 만들 수 있어요';

  @override
  String get routineLeaveDraftTitle => '임시저장에 두고 나갈까요?';

  @override
  String get routineLeaveDraftMessage => '내정보의 임시저장에서\n이어서 만들 수 있어요';

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
  String get todayRoutineDeleteConfirmTitle => '일과를 삭제할까요?';

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
  String get childHomeEmptyHintDevice => '보호자 기기에서 일과를 만들 수 있어요';

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
  String get childDetailSoundFailedFallback => '기기 소리를 켜고 다시 눌러주세요';

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
  String routineDoneMessage(String name) {
    return '할 일을 모두 해낸\n$name를 위해 준비했어요';
  }

  @override
  String get routineDoneButton => '해냈어요!';

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
  String get modeSwitchBlockedTitle => '보호자 기기에서\n열어 주세요';

  @override
  String get modeSwitchBlockedDescription => '이 기기에서는 보호자 화면을 열 수 없어요';

  @override
  String get modeSwitchBlockedBack => '돌아가기';

  @override
  String get installationRetryTitle => '잠깐 문제가 생겼어요';

  @override
  String get installationRetryMessage =>
      'No se pudo comprobar el inicio de sesión. Inténtalo de nuevo.';

  @override
  String get installationRetryButton => 'Reintentar';

  @override
  String get issuedCodeCopyButton => '코드 복사하기';

  @override
  String get issuedCodeCopied => '코드를 복사했어요';

  @override
  String get issuedCodeCopyFailedTitle => 'No se pudo copiar';

  @override
  String get issuedCodeCopyFailedFallback =>
      'Indica tú mismo el código que aparece en la pantalla';

  @override
  String linkShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes분',
    );
    return '이룸이가 쓸 기기를 연결해요. 그 기기에서 아래 링크를 누르면 이룸 앱에 연결 코드가 채워져요.\n연결 코드는 $_temp0 동안만 쓸 수 있어요.\n\n$url\n\n링크가 열리지 않으면 앱에서 직접 넣어주세요.\n연결 코드 $code';
  }

  @override
  String get linkRejectedAlreadyLinked => '이미 연결된 기기예요';

  @override
  String get linkRejectedOnGuardianPhone => '이룸이 기기에서 열어주세요';

  @override
  String get creditHistoryTitle => '크레딧 사용 내역';

  @override
  String get creditHistoryLink => '크레딧 사용 내역 보기';

  @override
  String creditHistoryDay(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String creditHistoryDetail(String kind, String time) {
    return '$kind・$time';
  }

  @override
  String get creditHistoryKindRoutineText => '일과 글 만들기';

  @override
  String creditHistoryKindCardImages(int count) {
    return '카드 그림 $count장';
  }

  @override
  String get creditHistoryKindCardImage => '카드 그림 만들기';

  @override
  String get creditHistoryKindImageRegenerate => '카드 그림 다시 만들기';

  @override
  String get creditHistoryKindWeeklyGrant => '이번 주 크레딧을 채워드렸어요';

  @override
  String get creditHistoryKindAdReward => '광고를 보고 받았어요';

  @override
  String get creditHistoryKindAdminBonus => '운영에서 보너스를 드렸어요';

  @override
  String get creditHistoryKindOtherGrant => '크레딧을 받았어요';

  @override
  String get creditHistoryKindExpired => '지난주 크레딧이 사라졌어요';

  @override
  String get creditHistoryKindAdjusted => '크레딧이 조정됐어요';

  @override
  String get creditHistoryKindUnknownSpend => '크레딧을 썼어요';

  @override
  String get creditHistoryEmptyTitle => '아직 사용한 크레딧이 없어요';

  @override
  String get creditHistoryEmptyBody => '일과를 만들면 여기에 기록돼요';

  @override
  String get creditHistoryLoadFailed => '사용 내역을 불러오지 못했어요';

  @override
  String get creditHistoryMoreFailed => '더 불러오지 못했어요';

  @override
  String get reminderRowLabel => '일과 알림';

  @override
  String get reminderRowOff => '알림 없음';

  @override
  String reminderRowDaily(String time) {
    return '매일 $time에 알려요';
  }

  @override
  String reminderRowOnce(String time) {
    return '$time에 한 번 알려요';
  }

  @override
  String get reminderSheetTitle => '언제 알려 드릴까요?';

  @override
  String get reminderSheetBody => '정한 시각에 이 기기로 알림이 와요';

  @override
  String get reminderRepeatDaily => '매일 같은 시각에 알리기';

  @override
  String get reminderTurnOn => '알림 켜기';

  @override
  String get reminderUpdate => '알림 시각 바꾸기';

  @override
  String get reminderTurnOff => '알림 끄기';

  @override
  String get reminderSavedToast => '알림을 맞췄어요';

  @override
  String get reminderClearedToast => '알림을 껐어요';

  @override
  String get reminderPermissionDeniedTitle => '알림이 꺼져 있어요';

  @override
  String get reminderPermissionDeniedBody =>
      '기기 설정에서 이룸 알림을 허용하면 일과 시간을 알려 드려요';

  @override
  String get reminderFailedTitle => '알림을 맞추지 못했어요';

  @override
  String get reminderFailedBody => '잠시 후 다시 해 주세요';

  @override
  String get reminderChannelName => '일과 알림';

  @override
  String get reminderNotificationTitle => '이룸';

  @override
  String reminderNotificationBody(String routineTitle) {
    return '$routineTitle 할 시간이에요';
  }

  @override
  String get routineTemplateOpen => '예시 일과 둘러보기';

  @override
  String get routineTemplateSheetTitle => '예시 일과';

  @override
  String get routineTemplateSheetBody => '고르면 입력칸에 채워 드려요. 이룸이에게 맞게 고쳐서 보내세요';

  @override
  String get routineTemplateBeginnerBadge => '처음이라면 추천';

  @override
  String get routineTemplateCategorySelfCare => '생활 습관';

  @override
  String get routineTemplateCategorySelfCareHint => '양치 · 세수 · 옷 입기';

  @override
  String get routineTemplateCategoryDailyFlow => '하루 순서';

  @override
  String get routineTemplateCategoryDailyFlowHint =>
      '아침 준비 · 하교 후 · 잠자리 (여러 일을 차례로)';

  @override
  String get routineTemplateCategoryHousehold => '집안일';

  @override
  String get routineTemplateCategoryHouseholdHint => '방 정리 · 그릇 치우기 · 빨래 개기';

  @override
  String get routineTemplateCategoryCommunity => '바깥 활동';

  @override
  String get routineTemplateCategoryCommunityHint => '버스 타기 · 물건 사기 · 병원 가기';

  @override
  String get routineTemplateCategoryLearning => '공부';

  @override
  String get routineTemplateCategoryLearningHint => '숙제 시작 · 이름 쓰기 · 책 읽기';

  @override
  String get routineTemplateCategoryFeelings => '감정·관계';

  @override
  String get routineTemplateCategoryFeelingsHint => '감정 카드 · 인사 · 차례 기다리기';

  @override
  String get routineTemplateBrushTeethText => '양치하기';

  @override
  String get routineTemplateBrushTeethPrompt =>
      '이룸이가 혼자 양치를 해 보게 하고 싶어. 칫솔과 치약 꺼내기, 양치컵에 물 받기, 이 닦기, 헹구기, 정리하기까지 순서대로 알려 줘';

  @override
  String get routineTemplateWashFaceText => '세수하기';

  @override
  String get routineTemplateWashFacePrompt =>
      '이룸이가 아침에 혼자 세수를 해 보게 하고 싶어. 물 틀기, 얼굴 적시기, 비누 거품 내기, 헹구기, 수건으로 닦기, 로션 바르기까지 알려 줘';

  @override
  String get routineTemplateGetDressedText => '혼자 옷 입기';

  @override
  String get routineTemplateGetDressedPrompt =>
      '이룸이가 혼자 옷을 입어 보게 하고 싶어. 러닝셔츠, 티셔츠, 바지, 양말 순서로 하나씩 입는 걸 알려 줘';

  @override
  String get routineTemplateEatMealText => '밥 먹기';

  @override
  String get routineTemplateEatMealPrompt =>
      '이룸이가 식사 시간에 스스로 해 보게 하고 싶어. 물 마시기, 자기 수저와 그릇 가져가기, 앉아서 먹기, 다 먹은 그릇 갖다 놓기까지 알려 줘';

  @override
  String get routineTemplateBathTimeText => '목욕하기';

  @override
  String get routineTemplateBathTimePrompt =>
      '이룸이가 목욕을 순서대로 해 보게 하고 싶어. 옷 벗기, 몸에 물 적시기, 머리 감기, 몸 씻기, 헹구기, 수건으로 닦고 옷 입기까지 알려 줘';

  @override
  String get routineTemplateMorningRoutineText => '아침 등교 준비';

  @override
  String get routineTemplateMorningRoutinePrompt =>
      '이룸이가 아침에 일어나서 학교 갈 때까지 할 일을 순서대로 하게 하고 싶어. 일어나기, 화장실 가기, 밥 먹기, 세수와 양치, 옷 입기, 가방 메고 신발 신기까지 알려 줘';

  @override
  String get routineTemplateAfterSchoolText => '학교 다녀와서';

  @override
  String get routineTemplateAfterSchoolPrompt =>
      '이룸이가 학교에서 돌아오면 스스로 할 일을 하게 하고 싶어. 신발 정리하기, 손 씻기, 가방 제자리에 두기, 간식 먹기, 쉬는 시간 갖기까지 알려 줘';

  @override
  String get routineTemplateBedtimeText => '자기 전 준비';

  @override
  String get routineTemplateBedtimePrompt =>
      '이룸이가 잠들기 전에 할 일을 순서대로 하게 하고 싶어. 양치하기, 잠옷 입기, 내일 가방 챙기기, 불 끄고 눕기까지 알려 줘';

  @override
  String get routineTemplateGoingOutText => '외출 준비';

  @override
  String get routineTemplateGoingOutPrompt =>
      '이룸이가 밖에 나가기 전에 스스로 준비하게 하고 싶어. 화장실 다녀오기, 겉옷 입기, 물통과 휴대폰 챙기기, 신발 신기, 문 앞에서 기다리기까지 알려 줘';

  @override
  String get routineTemplateTidyRoomText => '방 정리하기';

  @override
  String get routineTemplateTidyRoomPrompt =>
      '이룸이가 놀고 난 뒤 방을 스스로 정리하게 하고 싶어. 장난감 모으기, 상자에 넣기, 책 꽂기, 옷 걸기까지 알려 줘';

  @override
  String get routineTemplateClearDishesText => '먹은 그릇 정리하기';

  @override
  String get routineTemplateClearDishesPrompt =>
      '이룸이가 밥을 다 먹고 그릇을 스스로 치우게 하고 싶어. 남은 음식 모으기, 그릇 들고 가기, 싱크대에 넣기, 식탁 닦기까지 알려 줘';

  @override
  String get routineTemplateFoldLaundryText => '빨래 개기';

  @override
  String get routineTemplateFoldLaundryPrompt =>
      '이룸이가 마른 빨래를 개서 정리해 보게 하고 싶어. 빨래 가져오기, 양말 짝 맞추기, 수건 접기, 옷 개기, 서랍에 넣기까지 알려 줘';

  @override
  String get routineTemplateTakeOutTrashText => '쓰레기 버리기';

  @override
  String get routineTemplateTakeOutTrashPrompt =>
      '이룸이가 쓰레기를 나눠서 버리는 걸 해 보게 하고 싶어. 쓰레기 모으기, 종이와 플라스틱 나누기, 봉투 묶기, 정해진 곳에 버리기까지 알려 줘';

  @override
  String get routineTemplateRideBusText => '버스 타기';

  @override
  String get routineTemplateRideBusPrompt =>
      '이룸이가 혼자 버스를 타 보는 연습을 하고 싶어. 정류장에서 번호 확인하기, 줄 서기, 교통카드 찍기, 자리에 앉기, 내릴 곳에서 벨 누르기까지 알려 줘';

  @override
  String get routineTemplateBuyItemText => '편의점에서 물건 사기';

  @override
  String get routineTemplateBuyItemPrompt =>
      '이룸이가 편의점에서 혼자 물건을 사 보게 하고 싶어. 살 물건 찾기, 계산대에 줄 서기, 물건 올려놓기, 카드나 돈 내기, 영수증 받고 인사하기까지 알려 줘';

  @override
  String get routineTemplateUseElevatorText => '엘리베이터로 층 찾아가기';

  @override
  String get routineTemplateUseElevatorPrompt =>
      '이룸이가 엘리베이터를 타고 정한 층에 혼자 가 보게 하고 싶어. 버튼 누르기, 문 열리면 타기, 숫자 버튼 누르기, 층 숫자 보기, 내리기까지 알려 줘';

  @override
  String get routineTemplateHospitalVisitText => '병원 다녀오기';

  @override
  String get routineTemplateHospitalVisitPrompt =>
      '이룸이가 병원에 가서 순서대로 진료를 받게 하고 싶어. 접수하기, 대기실에서 기다리기, 이름 부르면 들어가기, 진료 받기, 약 받고 인사하기까지 알려 줘';

  @override
  String get routineTemplateStartHomeworkText => '숙제 시작하기';

  @override
  String get routineTemplateStartHomeworkPrompt =>
      '이룸이가 숙제를 스스로 시작해서 끝내 보게 하고 싶어. 책상에 앉기, 공책과 연필 꺼내기, 숙제 하기, 다 하면 보여 주기, 가방에 넣기까지 알려 줘';

  @override
  String get routineTemplateWriteNameText => '이름 쓰기 연습';

  @override
  String get routineTemplateWriteNamePrompt =>
      '이룸이가 연필을 바르게 잡고 자기 이름을 써 보게 하고 싶어. 연필 잡기, 종이 놓기, 이름 따라 쓰기, 혼자 써 보기, 정리하기까지 알려 줘';

  @override
  String get routineTemplateCountObjectsText => '수 세기 놀이';

  @override
  String get routineTemplateCountObjectsPrompt =>
      '이룸이가 물건을 하나씩 짚으며 수를 세는 연습을 하고 싶어. 물건 늘어놓기, 하나씩 손가락으로 짚기, 소리 내어 세기, 다 센 수 말하기까지 알려 줘';

  @override
  String get routineTemplateReadBookText => '책 읽는 시간';

  @override
  String get routineTemplateReadBookPrompt =>
      '이룸이가 책 읽는 시간을 스스로 가져 보게 하고 싶어. 책 고르기, 자리에 앉기, 한 쪽씩 넘기며 보기, 다 읽으면 책꽂이에 꽂기까지 알려 줘';

  @override
  String get routineTemplateEmotionCardText => '화가 날 때 감정 카드 꺼내기';

  @override
  String get routineTemplateEmotionCardPrompt =>
      '이룸이가 친구 때문에 화가 날 때 소리 지르거나 밀지 않고 감정 카드를 꺼내 보여 주게 하고 싶어. 멈추기, 주머니에서 감정 카드 꺼내기, 지금 기분 카드 고르기, 선생님께 보여 주기까지 알려 줘';

  @override
  String get routineTemplatePlayNicelyText => '친구와 사이좋게 놀기';

  @override
  String get routineTemplatePlayNicelyPrompt =>
      '이룸이가 친구와 사이좋게 노는 연습을 하고 싶어. 같이 놀자고 말하기, 장난감 나눠 쓰기, 차례 지키기, 끝나면 고마워 말하기까지 알려 줘';

  @override
  String get routineTemplateGreetingText => '인사하기';

  @override
  String get routineTemplateGreetingPrompt =>
      '이룸이가 사람을 만나면 먼저 인사하게 하고 싶어. 상대 얼굴 보기, 손 흔들기, 안녕하세요 말하기, 웃어 주기까지 알려 줘';

  @override
  String get routineTemplateWaitTurnText => '차례 기다리기';

  @override
  String get routineTemplateWaitTurnPrompt =>
      '이룸이가 줄을 서서 자기 차례를 기다리는 연습을 하고 싶어. 줄 끝에 서기, 앞사람 뒤에서 기다리기, 내 차례 확인하기, 차례가 오면 하기까지 알려 줘';

  @override
  String get routineTemplateAskHelpText => '도와 달라고 말하기';

  @override
  String get routineTemplateAskHelpPrompt =>
      '이룸이가 혼자 하기 어려울 때 도움을 요청하게 하고 싶어. 멈추기, 가까운 어른 찾기, 도와주세요 말하기, 도움 받고 고맙습니다 말하기까지 알려 줘';

  @override
  String get guardianTabHome => '홈';

  @override
  String get guardianTabManage => '일과 관리';

  @override
  String get guardianTabTalk => '이야기';

  @override
  String get guardianTabMe => '내 정보';

  @override
  String get guardianMyInfoProfileName => '보호자';

  @override
  String get guardianMyInfoEmailPrivate => '이메일 비공개';

  @override
  String guardianMyInfoJoinedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'y.MM.dd',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString 가입';
  }

  @override
  String get guardianMyInfoChildrenHeader => '이룸이';

  @override
  String get guardianMyInfoActiveBadge => '보는 중';

  @override
  String get guardianSideNavCaption => '보호자 화면';

  @override
  String get guardianSideNavChildScreen => '이룸이 화면';

  @override
  String get routineLibraryEmptyTitle => '아직 만든 일과가 없어요';

  @override
  String get routineLibraryEmptyBody => '아래 + 일과 만들기로 첫 일과를 만들어 보세요';

  @override
  String get routineLibraryLoadFailedFallback => '일과를 불러오지 못했어요';

  @override
  String get routineLibraryCreate => '새로 만들기';

  @override
  String get routineLibrarySendToday => '오늘 보내기';

  @override
  String get routineLibraryEditCards => '카드 고치기';

  @override
  String get routineLibraryAlreadySent => '오늘 이미 보낸 일과예요';

  @override
  String get routineLibrarySendFailedTitle => '보내지 못했어요';

  @override
  String get routineLibraryActionFailedFallback => '잠시 뒤 다시 해 주세요';

  @override
  String get routineLibraryCopied => '복사본을 만들었어요';

  @override
  String get routineLibraryCopyFailedTitle => '복사하지 못했어요';

  @override
  String get routineLibraryMenuRename => '이름 바꾸기';

  @override
  String get routineLibraryMenuCopy => '복사하기';

  @override
  String get routineLibraryMenuRemove => '지우기';

  @override
  String get routineLibraryRenameHint => '일과 이름';

  @override
  String get routineLibraryRenameSave => '저장하기';

  @override
  String get routineLibraryRenamed => '이름을 바꿨어요';

  @override
  String get routineLibraryRenameFailedTitle => '이름을 바꾸지 못했어요';

  @override
  String get routineLibraryRemoveConfirmTitle => '이 일과를 지울까요?';

  @override
  String get routineLibraryRemoveConfirmMessage =>
      '일과 관리에서 빠져요. 이룸이가 한 기록은 그대로 남아요';

  @override
  String get routineLibraryRemoved => '일과를 지웠어요';

  @override
  String get routineLibraryRemoveFailedTitle => '지우지 못했어요';

  @override
  String get routineLibrarySentBadge => '오늘 보냈어요';

  @override
  String get routineLibraryTileHint => '길게 누르면 메뉴가 열려요';

  @override
  String get routineLibraryFromTalk => '이야기에서';

  @override
  String get routineLibraryNewBadge => '새로';

  @override
  String get routineDetailTalkOriginBand => 'Traído de Historias';

  @override
  String get routineDetailTalkOriginOpenPost => 'Publicación original';

  @override
  String get routineDetailTalkOriginPostGone => 'Publicación retirada';

  @override
  String get routineDetailTalkOriginBandOpenLabel =>
      'Traído de Historias, ver la publicación original';

  @override
  String routineLibrarySent(String title) {
    return '$title을(를) 오늘 일과로 보냈어요';
  }

  @override
  String onboardingExampleTitle(String name) {
    return '¿En qué te gustaría\nayudar a $name?';
  }

  @override
  String get onboardingExampleDescription =>
      'Añadiremos rutinas de ejemplo de lo que elijas.\nPuedes elegir más de una.';

  @override
  String get onboardingExampleSkip => 'Omitir';

  @override
  String get exampleCategoryMorningEvening => 'Mañana y noche';

  @override
  String get exampleCategoryMorningEveningHint =>
      'Asearse, vestirse, ir a dormir';

  @override
  String get exampleCategorySchoolStudy => 'Escuela y estudio';

  @override
  String get exampleCategorySchoolStudyHint =>
      'Prepararse para la escuela, deberes';

  @override
  String get exampleCategoryHouseSelf => 'Tareas y hacerlo solo';

  @override
  String get exampleCategoryHouseSelfHint => 'Ordenar, poner la mesa';

  @override
  String get exampleCategoryOutside => 'Salir y probar';

  @override
  String get exampleCategoryOutsideHint => 'Tomar el autobús, hacer compras';

  @override
  String get exampleRoutinesFailed =>
      'No se pudieron añadir las rutinas de ejemplo';

  @override
  String get routineGroupMenuAddToGroup => '묶음에 넣기';

  @override
  String get routineGroupMenuReorder => '순서 바꾸기';

  @override
  String get routineGroupMenuUngroup => '묶음 풀기';

  @override
  String routineGroupTileLabel(String name, int count) {
    return '$name 묶음, 일과 $count개';
  }

  @override
  String get routineGroupDefaultName => '새 묶음';

  @override
  String get routineGroupNameHint => '묶음 이름 (예: 아침 준비)';

  @override
  String get routineGroupNewTitle => '새 묶음 만들기';

  @override
  String routineGroupAddTitle(String name) {
    return '$name에 넣기';
  }

  @override
  String get routineGroupPickHintNew => '넣을 일과를 보여 줄 순서대로 눌러 주세요 (2개 이상)';

  @override
  String get routineGroupPickHint => '넣을 일과를 순서대로 눌러 주세요';

  @override
  String get routineGroupPickEmpty => '넣을 수 있는 일과가 없어요';

  @override
  String routineGroupPickConfirmNew(int count) {
    return '$count개로 묶기';
  }

  @override
  String routineGroupPickConfirmAdd(int count) {
    return '$count개 넣기';
  }

  @override
  String get routineGroupCreateMenuTitle => '무엇을 만들까요?';

  @override
  String get routineGroupCreateRoutine => '새 일과 만들기';

  @override
  String get routineGroupCreateGroup => '새 묶음 만들기';

  @override
  String get routineGroupChooseTitle => '어느 묶음에 넣을까요?';

  @override
  String routineGroupSheetCount(int count) {
    return '일과 $count개';
  }

  @override
  String get routineGroupSheetAdd => '일과 넣기';

  @override
  String routineGroupSheetRemove(String title) {
    return '$title 묶음에서 빼기';
  }

  @override
  String get routineGroupCreated => '묶음을 만들었어요';

  @override
  String get routineGroupAdded => '묶음에 넣었어요';

  @override
  String get routineGroupRemovedOne => '묶음에서 뺐어요';

  @override
  String get routineGroupUngrouped => '묶음을 풀었어요';

  @override
  String get routineGroupUngroupedLastOne => '일과가 하나만 남아 묶음을 풀었어요';

  @override
  String get routineGroupReordered => '순서를 바꿨어요';

  @override
  String routineGroupSent(String name) {
    return '$name 묶음을 오늘 일과로 보냈어요';
  }

  @override
  String get routineGroupAllSentAlready => '묶음 안 일과를 오늘 모두 보냈어요';

  @override
  String get routineGroupActionFailedTitle => '묶음을 바꾸지 못했어요';

  @override
  String get routineGroupUngroupConfirmTitle => '묶음을 풀까요?';

  @override
  String get routineGroupUngroupConfirmMessage => '안에 있던 일과는 일과 관리에 그대로 남아요';

  @override
  String routineGroupRemoveConfirmTitle(String title) {
    return '$title 일과를 묶음에서 뺄까요?';
  }

  @override
  String get routineGroupRemoveConfirmMessage => '일과는 일과 관리에 그대로 남아요';

  @override
  String get routineGroupRemoveConfirmAction => '빼기';

  @override
  String childHomeGroupProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String get childHomeGroupAllDone => '다 했어요!';

  @override
  String get routineDetailMore => '더 보기';

  @override
  String get libraryArrangeDone => '완료';

  @override
  String get libraryArrangeRemove => '지우기 또는 묶음 풀기';

  @override
  String get routineGroupEditOrder => '편집';

  @override
  String get routineLibrarySendOnlyThis => '이 일과만 오늘 보내기';

  @override
  String routineGroupRowCardCount(int count) {
    return '카드 $count장';
  }

  @override
  String get routineManageCoachTapMessage => '일과를 *누르면* 카드를 볼 수 있어요';

  @override
  String get routineManageCoachLongPressMessage => '길게 눌렀다 *떼면* 메뉴가 열려요';

  @override
  String get routineManageCoachSentMessage =>
      '오늘 보낸 일과에는 *✓*가 붙어요\n홈의 오늘 일과에 들어가고\n여기 일과는 그대로 남아요';

  @override
  String get routineManageCoachDragMessage =>
      '길게 누른 채 *움직이면* 정리 상태가 돼요\n다른 일과 위에 놓으면 *묶음*이 되고\n사이에 놓으면 자리를 옮겨요';

  @override
  String get routineManageCoachCreateGroupMessage =>
      '끌기가 어려우면 *+ 일과 만들기*에서\n*새 묶음 만들기*로도 묶을 수 있어요';

  @override
  String get cardReviewCoachEditMessage =>
      '보고 있는 카드의 *글과 그림*을 고쳐요\n그림은 *내 사진*으로 바꿀 수도 있어요';

  @override
  String get cardReviewCoachReorderMessage =>
      '여기를 누른 뒤 카드를 *길게 눌러 끌면*\n순서가 바뀌어요';

  @override
  String get cardReviewCoachSaveMessage =>
      '다 고쳤으면 꼭 *카드 저장하기*를 눌러요\n눌러야 일과가 완성돼요';

  @override
  String get coachHelpLabel => '사용법 보기';

  @override
  String get guardianSettingsRoutineManageGuide => '일과관리 사용법 다시 보기';

  @override
  String get pushPermissionSheetTitle => '이룸이가 일과를 끝내면 알려 드릴까요?';

  @override
  String get pushPermissionSheetBody => '다른 보호자의 소식과 크레딧 안내도 함께 알려 드려요';

  @override
  String get pushPermissionAllow => '알림 받기';

  @override
  String get pushPermissionLater => '나중에';

  @override
  String get pushPermissionDenied => '알림 설정에서 언제든 켤 수 있어요';

  @override
  String get pushChannelGuardianUpdates => '보호자 알림';

  @override
  String get signInProviderKakao => 'Kakao';

  @override
  String get signInProviderNaver => 'Naver';

  @override
  String get signInProviderGoogle => 'Google';

  @override
  String get signInProviderApple => 'Apple';

  @override
  String get routineManageCoachSampleMorning => '아침 준비';

  @override
  String get routineManageCoachSampleBrush => '양치하기';

  @override
  String get routineManageCoachSampleBag => '가방 챙기기';

  @override
  String get updateSuggestionTitle => 'Hay una nueva versión';

  @override
  String get updateSuggestionBody =>
      'Actualiza para usar las últimas mejoras y funciones';

  @override
  String get updateSuggestionLater => 'Más tarde';

  @override
  String elumiInfoTitle(String name) {
    return '$name 정보';
  }

  @override
  String elumiInfoEditLabel(String name) {
    return '$name 정보 고치기';
  }

  @override
  String get elumiInfoName => '이름';

  @override
  String get elumiInfoCharacter => '캐릭터';

  @override
  String get elumiInfoCharacterSheetTitle => '캐릭터 바꾸기';

  @override
  String get elumiInfoImageStyleSheetTitle => '그림 방식 바꾸기';

  @override
  String get elumiInfoSave => '저장하기';

  @override
  String get elumiInfoSaved => '저장했어요';

  @override
  String get elumiInfoSaveFailedTitle => '저장하지 못했어요';

  @override
  String get elumiInfoSaveFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get elumiInfoNotFound => '이룸이 정보를 불러오지 못했어요';

  @override
  String get talkTitle => '이야기';

  @override
  String get talkWriteButton => '+ 올리기';

  @override
  String get talkCategoryAll => '전체';

  @override
  String get talkPopularTitle => '많이 가져갔어요';

  @override
  String get talkPopularPeriod => '이번 주';

  @override
  String talkPopularImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명 가져감',
    );
    return '$_temp0';
  }

  @override
  String get talkLatestTitle => '새로 올라왔어요';

  @override
  String get talkEmptyTitle => '아직 나눈 일과가 없어요';

  @override
  String get talkEmptyAction => '첫 일과를 나눠 보세요';

  @override
  String get talkFeedFailed => '이야기를 불러오지 못했어요';

  @override
  String get talkAuthorFallback => '보호자';

  @override
  String get talkNoteLabel => '내용';

  @override
  String get talkImportButtonShort => '내 일과로';

  @override
  String talkHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '도움돼요 $count',
    );
    return '$_temp0';
  }

  @override
  String talkCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '댓글 $count',
    );
    return '$_temp0';
  }

  @override
  String get talkLoadMoreRetry => '더 불러오지 못했어요. 눌러서 다시 해 보세요';

  @override
  String talkDetailStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '카드 $count장',
    );
    return '$_temp0';
  }

  @override
  String get talkDetailLoadFailed => '글을 불러오지 못했어요';

  @override
  String get talkPostGoneTitle => '내려간 글이에요';

  @override
  String get talkPostGoneBack => '이야기로 돌아가기';

  @override
  String get talkStepsTitle => '이렇게 해요';

  @override
  String get talkHelpfulFailed => '도움돼요를 바꾸지 못했어요. 잠시 뒤에 다시 해 주세요';

  @override
  String get talkImportButton => '내 일과로 가져오기';

  @override
  String get talkImportedButton => '✓ 일과관리에 넣었어요';

  @override
  String get talkImportSheetTitle => '어느 일과관리에 넣을까요?';

  @override
  String get talkImportSheetHint => '넣은 뒤 우리 집에 맞게 고치고, 준비되면 보내기를 눌러 주세요.';

  @override
  String get talkImportElumiLabel => '이룸이';

  @override
  String get talkImportGroupLabel => '묶음';

  @override
  String get talkImportGroupNone => '묶음 없이';

  @override
  String get talkImportConfirm => '일과관리에 넣기';

  @override
  String get talkImportNoElumiTitle => '이룸이를 먼저 연결해 주세요';

  @override
  String get talkImportNoElumiAction => '이룸이 연결하기';

  @override
  String talkImportDone(String elumiName) {
    return '$elumiName 일과관리에 넣었어요';
  }

  @override
  String get talkImportGoToLibrary => '보러 가기';

  @override
  String get talkImportFailedTitle => '일과관리에 넣지 못했어요';

  @override
  String get talkCommentsTitle => '댓글';

  @override
  String get talkCommentsEmpty => '아직 댓글이 없어요';

  @override
  String get talkCommentsFailed => '댓글을 불러오지 못했어요';

  @override
  String get talkCommentHint => '댓글을 남겨 보세요';

  @override
  String get talkCommentSend => '보내기';

  @override
  String get talkCommentSendFailedTitle => '댓글을 보내지 못했어요';

  @override
  String get talkFailedFallback => '잠시 뒤에 다시 해 주세요';

  @override
  String get talkCommentDeleteTitle => '댓글을 지울까요?';

  @override
  String get talkCommentDeleteAction => '지우기';

  @override
  String get talkCommentDeleteFailedTitle => '댓글을 지우지 못했어요';

  @override
  String get talkMenuReport => '신고하기';

  @override
  String get talkMenuBlock => '이 보호자 글 숨기기';

  @override
  String get talkMenuEdit => '고치기';

  @override
  String get talkMenuTakeDown => '내리기';

  @override
  String get talkMoreLabel => '더보기';

  @override
  String get talkTakeDownTitle => '이 글을 내릴까요?';

  @override
  String get talkTakeDownMessage => '내린 글은 다른 보호자에게 더 이상 보이지 않아요.';

  @override
  String get talkTakeDownDone => '글을 내렸어요';

  @override
  String get talkTakeDownFailedTitle => '글을 내리지 못했어요';

  @override
  String get talkEditTitle => '글 고치기';

  @override
  String get talkEditSave => '저장하기';

  @override
  String get talkEditSaved => '고쳤어요';

  @override
  String get talkEditFailedTitle => '글을 고치지 못했어요';

  @override
  String get talkNoteGuide => '다른 사람 이름·연락처는 적지 말아 주세요';

  @override
  String get talkCategoryTitle => '분류';

  @override
  String get talkReportTitle => '신고하기';

  @override
  String get talkReportSubmit => '신고하기';

  @override
  String get talkReportDone => '신고했어요';

  @override
  String get talkReportFailedTitle => '신고하지 못했어요';

  @override
  String get talkReportReasonPersonalInfo => '이룸이나 가족 정보가 보여요';

  @override
  String get talkReportReasonOffensive => '기분 나쁜 말이 있어요';

  @override
  String get talkReportReasonAdvertising => '광고나 홍보예요';

  @override
  String get talkReportReasonOther => '그 밖의 이유';

  @override
  String talkBlockTitle(String nickname) {
    return '$nickname님 글을 숨길까요?';
  }

  @override
  String get talkBlockMessage =>
      '이 보호자의 글과 댓글이 나에게 안 보여요. 상대방은 알 수 없어요. 내 정보 › 숨긴 보호자에서 다시 볼 수 있어요.';

  @override
  String get talkBlockAction => '숨기기';

  @override
  String get talkBlockDone => '숨겼어요';

  @override
  String get talkBlockFailedTitle => '숨기지 못했어요';

  @override
  String get talkBlockedGuardiansTitle => '숨긴 보호자';

  @override
  String get talkBlockedGuardiansEmpty => '숨긴 보호자가 없어요';

  @override
  String get talkBlockedGuardiansFailed => '숨긴 보호자를 불러오지 못했어요';

  @override
  String get talkUnblockAction => '다시 보기';

  @override
  String get talkUnblockDone => '다시 볼 수 있어요';

  @override
  String get talkUnblockFailedTitle => '숨김을 풀지 못했어요';

  @override
  String get talkRulesTitle => '이야기 이용 규칙';

  @override
  String get talkRulesIntro => '보호자끼리 안전하게 나누려고 이 세 가지를 지켜 주세요.';

  @override
  String get talkRulesPrivacy => '얼굴·이름·학교·집 주소가 보이지 않게 해 주세요';

  @override
  String get talkRulesRespect => '다른 보호자를 존중해 주세요. 비난·광고·홍보는 안 돼요';

  @override
  String get talkRulesNoDiagnosis => '진단명·병원 정보는 적지 말아 주세요';

  @override
  String get talkRulesAgreeCheck => '위 규칙을 읽었고 지킬게요';

  @override
  String get talkRulesAgreeButton => '동의하고 계속하기';

  @override
  String get talkRulesFailedTitle => '동의를 저장하지 못했어요';

  @override
  String get talkShareTitle => '이야기에 올리기';

  @override
  String get talkSharePickTitle => '어떤 일과를 나눌까요?';

  @override
  String get talkSharePickEmpty => '올릴 수 있는 일과가 없어요';

  @override
  String get talkSharePickEmptyHint =>
      '일과관리에 있는 내 일과만 올릴 수 있어요. 이미 올렸거나 예시, 이야기에서 가져온 일과는 빠져요.';

  @override
  String get talkSharePickFailed => '일과를 불러오지 못했어요';

  @override
  String get talkSharePreviewFailed => '올릴 내용을 불러오지 못했어요';

  @override
  String get talkSharePhotoTitle => '사진을 어떻게 올릴까요?';

  @override
  String get talkSharePhotoGuide =>
      '얼굴, 이름표, 집 주소가 보이면 흐리게 해 주세요. AI로 만든 그림은 그대로 올라가요.';

  @override
  String get talkSharePhotoBlur => '흐리게';

  @override
  String get talkSharePhotoKeep => '그대로';

  @override
  String get talkSharePhotoNext => '다음';

  @override
  String get talkSharePreviewTitle => '이렇게 올라가요';

  @override
  String get talkSharePreviewHint => '이름은 모두 \'이룸이\'로 바뀌어 올라가요';

  @override
  String get talkShareSubmit => '올리기';

  @override
  String get talkShareDone => '이야기에 올렸어요';

  @override
  String get talkShareFailedTitle => '올리지 못했어요';

  @override
  String get talkShareHint => '📖 이야기에 공유해 보기 ›';

  @override
  String get talkMenuShare => '이야기에 공유하기';

  @override
  String get talkMenuViewMyPost => '내 글 보기';

  @override
  String get timeAgoJustNow => '방금 전';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분 전',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간 전',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일 전',
    );
    return '$_temp0';
  }
}
