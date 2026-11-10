// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'elum';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonNext => 'Next';

  @override
  String get commonRetry => 'Try again';

  @override
  String dateYearMonthDay(int year, int month, int day) {
    return '$month/$day/$year';
  }

  @override
  String dateMonthDaySince(int month, int day) {
    return 'Since $month/$day';
  }

  @override
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'sun': 'Sun',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String creditResetAt(int month, int day, String weekday, int hour) {
    return '$weekday, $month/$day at $hour:00';
  }

  @override
  String creditResetAtMinute(
    int month,
    int day,
    String weekday,
    int hour,
    int minute,
  ) {
    return '$weekday, $month/$day at ${hour}h ${minute}min';
  }

  @override
  String get creditResetFallback => 'next Monday at 0:00';

  @override
  String get creditBlockedBusy =>
      'A routine is already being made.\nYou can make a new one once it\'s done';

  @override
  String creditBlockedExhausted(String reset) {
    return 'You\'ve used all your credits this week.\nCredits refill on $reset';
  }

  @override
  String creditAdOffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Watch an ad to the end to get $count credits',
      one: 'Watch an ad to the end to get $count credit',
    );
    return '$_temp0';
  }

  @override
  String creditReceivedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You got $count credits',
      one: 'You got $count credit',
    );
    return '$_temp0';
  }

  @override
  String get creditReceivedTitleNoCount => 'You got credits';

  @override
  String get creditAdWatchMore => 'Watch an ad to make more';

  @override
  String get adRewardPreparing => 'Getting the ad ready';

  @override
  String get adRewardConfirming => 'Checking your credits';

  @override
  String get adRewardLoadFailed =>
      'Can\'t load an ad right now.\nTry again in a moment';

  @override
  String get adRewardNotWatched =>
      'Watch the ad to the end to get credits.\nStart again from the beginning';

  @override
  String get adRewardSlow =>
      'Checking your credits is taking a while.\nCheck My info in a moment';

  @override
  String get adRewardDailyLimit =>
      'You\'ve got all the ad credits you can today.\nTry again tomorrow';

  @override
  String get adRewardCheckAccount =>
      'Can\'t get ad credits right now.\nCheck your account status';

  @override
  String get adRewardUnavailable => 'Can\'t get ad credits right now.';

  @override
  String get adRewardUnavailableRetry =>
      'Can\'t get ad credits right now.\nTry again in a moment';

  @override
  String get adRewardFailed =>
      'Couldn\'t get the credits.\nTry again in a moment';

  @override
  String get commonPopupClose => 'Close popup';

  @override
  String get commonBack => 'Back';

  @override
  String get commonScreenNotFound => 'We can\'t find this screen';

  @override
  String get commonRetryLater => 'Try again in a moment';

  @override
  String get sentenceStop => '.';

  @override
  String get failureHintOffline => 'Check your internet connection';

  @override
  String get failureHintTimeout =>
      'The connection is slow. Try again in a moment.';

  @override
  String get failureHintBadCertificate =>
      'This connection isn\'t safe. Try another network.';

  @override
  String coachStepLabel(int index, int total, String message) {
    return 'Tip $index/$total. $message';
  }

  @override
  String get commonAd => 'Ad';

  @override
  String get commonAppInfo => 'App info';

  @override
  String get coachCloseHint => 'Close tips';

  @override
  String get coachNextHint => 'Next tip';

  @override
  String get coachTapToClose => 'Tap the screen to close';

  @override
  String get coachTapToNext => 'Tap the screen to go on';

  @override
  String get loginSceneEyebrow => 'Today,';

  @override
  String get loginSceneTitle => 'One step at a time, together';

  @override
  String get appStatusStoreOpenFailedTitle => 'Couldn\'t open the store';

  @override
  String get appStatusStoreOpenFailedFallback =>
      'Find elum in the store and update it';

  @override
  String get appStatusMaintenanceTitle => 'Under maintenance right now';

  @override
  String get appStatusMaintenanceBody =>
      'You can use elum again once it is done.\nPlease check back in a little while';

  @override
  String get appStatusRecheck => 'Check again';

  @override
  String get appStatusUpdateTitle => 'Update now and enjoy\nthe new elum!';

  @override
  String get appStatusUpdated => 'I updated it';

  @override
  String get appStatusGoUpdate => 'Go update';

  @override
  String routineForeignCreator(String name, String batchim) {
    return 'A routine made by $name';
  }

  @override
  String get routineForeignCreatorUnknown =>
      'A routine made by another guardian';

  @override
  String get routineDefaultTitle => 'Today\'s routine';

  @override
  String get rewardPresetSnack => 'A favorite snack';

  @override
  String get rewardPresetVideo => '10 minutes of videos';

  @override
  String get rewardPresetPlay => 'A favorite game';

  @override
  String get rewardPresetWalk => 'A walk';

  @override
  String get rewardPresetCustom => 'Write your own';

  @override
  String get roleGuardianWord => 'Guardian';

  @override
  String get roleElumiWord => 'Elumi';

  @override
  String get roleLabelSuffix => ' uses this';

  @override
  String get roleGuardianDescription => 'Make and manage routines';

  @override
  String get roleElumiDescription => 'Do the routines';

  @override
  String get roleSelectTitle => 'Who will use\nthis device?';

  @override
  String get roleSelectDescription => 'There are Guardian mode and Elumi mode';

  @override
  String get loginKakaoButton => 'Log in with Kakao';

  @override
  String get loginNaverButton => 'Log in with Naver';

  @override
  String get loginAppleButton => 'Log in with Apple';

  @override
  String get loginConnecting => 'Connecting';

  @override
  String get loginLastUsed => 'Last used';

  @override
  String get loginDuplicateTitle => 'This account already exists';

  @override
  String get loginDuplicateFallback => 'Log in with the method you first used';

  @override
  String get loginOfflineTitle => 'Check your internet connection';

  @override
  String get loginOfflineFallback => 'Connect, then try again';

  @override
  String get loginFailedTitle => 'Couldn\'t log in';

  @override
  String get loginFailedFallback => 'Try again in a moment';

  @override
  String get consentTitle => 'Please agree to the terms';

  @override
  String get consentLoading => 'Loading the terms';

  @override
  String get consentSaving => 'Saving';

  @override
  String get consentSaveFailed => 'Couldn\'t save your agreement. Try again.';

  @override
  String get consentDescriptionReady => 'Tap an item to read the details';

  @override
  String get consentDescriptionNeeded =>
      'You need to agree to the terms to use the service';

  @override
  String get consentAllAgree => 'Agree to all terms';

  @override
  String get consentRequiredTag => 'Required';

  @override
  String get consentOptionalTag => 'Optional';

  @override
  String consentDocumentMeta(String label, String version) {
    return '$label · Version $version';
  }

  @override
  String get consentListTitle => 'Terms and Privacy Policy';

  @override
  String get consentGroupRequired => 'Required';

  @override
  String get consentGroupOptional => 'Optional';

  @override
  String get commonElumiName => 'Elumi';

  @override
  String get characterCatLabel => 'Cat';

  @override
  String get characterCatName => 'Ruru';

  @override
  String get characterFoxLabel => 'Fox';

  @override
  String get characterFoxName => 'Popo';

  @override
  String get imageStyleEmojiLabel => 'Emoji';

  @override
  String get imageStyleEmojiDescription => 'Shows things with cute emoji';

  @override
  String get imageStyleSymbolLabel => 'Picture symbols';

  @override
  String get imageStyleSymbolDescription =>
      'Shows the action as a line drawing';

  @override
  String get imageStyleCharacterLabel => 'Character';

  @override
  String get imageStyleCharacterDescription => 'A character acts it out';

  @override
  String get imageStyleRealisticLabel => 'Realistic';

  @override
  String get imageStyleRealisticDescription => 'Looks like real things';

  @override
  String get imageStyleCreditLabel => 'Credits';

  @override
  String imageStyleCreditRoutine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Each routine $count',
    );
    return '$_temp0';
  }

  @override
  String get imageStyleCreditRoutineFree => '일과 글은 크레딧 없이';

  @override
  String imageStyleCreditImage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Each picture $count',
    );
    return '$_temp0';
  }

  @override
  String get goalStepByStep => 'Understand what to do, step by step';

  @override
  String get goalPrepareItems => 'Pack the things they need on their own';

  @override
  String get goalPrepareNew => 'Get ready for new situations ahead of time';

  @override
  String get goalIndependent =>
      'Build the experience of finishing on their own';

  @override
  String onboardingCharacterTitle(String name) {
    return 'Choose a friend to\nspend $name\'s day with';
  }

  @override
  String get onboardingCharacterDescription =>
      'The friend you pick is the star of the cards and helps along the way';

  @override
  String get onboardingImageStyleTitle =>
      'How should the card\npictures be made?';

  @override
  String get onboardingImageStyleDescription =>
      'You can change this later in settings';

  @override
  String get onboardingNameTitle => 'What should we\ncall Elumi?';

  @override
  String get onboardingNameDescription => 'It doesn\'t have to be a real name';

  @override
  String get onboardingNameHint => 'Enter a name';

  @override
  String get onboardingNameInviteLink => 'I have an invite code';

  @override
  String get onboardingCompletionTitle => 'Everything is\nready';

  @override
  String get onboardingCompletionProgress => '100% done!';

  @override
  String get onboardingSplashLogoLabel => 'elum';

  @override
  String get pinCreateTitle => 'Create a passcode\nonly you know';

  @override
  String get pinConfirmTitle => 'Enter the passcode\none more time';

  @override
  String get pinDescription =>
      'You\'ll use this passcode to switch to Guardian mode';

  @override
  String get pinMismatch => 'The passcodes don\'t match. Try again.';

  @override
  String get pinInputSemanticLabel => 'Enter passcode';

  @override
  String get pinStartButton => 'Start';

  @override
  String get pinProfileCreateFailedTitle => 'Couldn\'t create the profile';

  @override
  String get pinProfileCreateFailedFallback => 'Try again in a moment';

  @override
  String get pinSaveFailedTitle => 'Couldn\'t save your settings';

  @override
  String get pinSaveFailedFallback => 'Tap Start again in a moment';

  @override
  String get elumiSettingsTitle => 'Settings';

  @override
  String get elumiSettingsHapticLabel => 'Vibrate on card check';

  @override
  String get elumiSettingsPraiseSoundLabel => 'Praise sound on card check';

  @override
  String get elumiSettingsScreenAwakeLabel =>
      'Keep screen on while viewing cards';

  @override
  String get elumiSettingsTermsLabel => 'Terms and Privacy Policy';

  @override
  String get elumiSettingsLogoutLabel => 'Log out';

  @override
  String get elumiSettingsWithdrawLabel => 'Delete account';

  @override
  String get elumiSettingsLogoutTitle => 'Log out?';

  @override
  String get elumiSettingsLogoutMessage =>
      'This device will be disconnected\nTo use it again, get a\nlink code from a guardian';

  @override
  String get elumiSettingsLogoutFailTitle => 'Couldn\'t log out';

  @override
  String get elumiSettingsWithdrawTitle => 'Delete your account?';

  @override
  String get elumiSettingsWithdrawMessage =>
      'Only this device is disconnected\nRoutines and stars stay on the guardian\'s device\nTo use it again, get a\nlink code from a guardian';

  @override
  String get elumiSettingsWithdrawAction => '탈퇴하기';

  @override
  String get inviteRejectedOnElumiDevice =>
      'This device can\'t accept invites\nOpen it on a guardian\'s device';

  @override
  String get elumiSettingsWithdrawFailTitle => 'Couldn\'t delete the account';

  @override
  String get elumiSettingsExitFailedFallback => 'Try again in a moment';

  @override
  String get linkStatusTitle => 'Elumi\'s device';

  @override
  String get linkStatusRevokeConfirmTitle => 'Disconnect this device?';

  @override
  String get linkStatusRevokeConfirmMessage =>
      'Elumi won\'t be able to see routines on that device\nTo connect again, make a new link code';

  @override
  String get linkStatusRevokeConfirmAction => 'Disconnect';

  @override
  String get linkStatusRevokeFailTitle => 'Couldn\'t disconnect';

  @override
  String get linkStatusRevokeFailedFallback => 'Try again in a moment';

  @override
  String get linkStatusRevoked => 'Disconnected';

  @override
  String get linkStatusAlreadyRevoked => 'Already disconnected';

  @override
  String get linkStatusLoadFailedFallback =>
      'Couldn\'t load the connection status';

  @override
  String linkDeviceNumbered(int number) {
    return 'Elumi\'s device $number';
  }

  @override
  String get linkStatusConnected => 'Connected';

  @override
  String get linkStatusRevokeButton => 'Disconnect';

  @override
  String get linkStatusRevokeHint =>
      'If you disconnect, Elumi can\'t see\nroutines on that device';

  @override
  String get linkStatusEmpty => 'No device is connected';

  @override
  String linkStatusConnectedBy(String name, String batchim) {
    return 'Connected by $name';
  }

  @override
  String get linkStatusConnectedByMe => 'Connected by you';

  @override
  String linkStatusConnectedByAndSince(String by, String since) {
    return '$by · $since';
  }

  @override
  String get linkStatusAddAction => '+ Connect another device';

  @override
  String get linkStatusConnectAction => 'Connect Elumi\'s device';

  @override
  String get linkCodeSettingsTitle => 'Connect Elumi\'s device';

  @override
  String linkCodeAskTitle(String name) {
    return 'Connect $name\'s\ndevice?';
  }

  @override
  String linkCodeEnterHint(String name) {
    return 'Enter the code below on $name\'s device';
  }

  @override
  String get linkCodeIssueFailedFallback =>
      'Couldn\'t make the code. Try again.';

  @override
  String get linkCodeSuccessTitle => 'The device is connected!';

  @override
  String get linkCodeStartButton => 'Start';

  @override
  String get linkCodeLater => 'Maybe later';

  @override
  String get linkCodeChangesAfter => 'until the code changes';

  @override
  String get linkRetryChipLabel => 'Make a new code';

  @override
  String get linkEnterTitle => 'Enter the code you got\nfrom the guardian';

  @override
  String get linkEnterGuide =>
      'You can find the code on the guardian\'s device in\nSettings → Connect Elumi\'s device';

  @override
  String get linkEnterGuidePath => 'Settings → Connect Elumi\'s device';

  @override
  String get linkEnterLinkLost =>
      'The connection was lost\nGet a new link code from the guardian and enter it';

  @override
  String get linkEnterStartButton => 'Start';

  @override
  String get linkEnterInputLabel => 'Enter link code';

  @override
  String get linkEnterWrongCode => 'That code isn\'t right';

  @override
  String get linkEnterExpired => 'The code has expired. Get a new one.';

  @override
  String get linkEnterOffline => 'Couldn\'t connect. Check your internet.';

  @override
  String get linkEnterFailed => 'Couldn\'t connect. Try again.';

  @override
  String get commonGuardianName => 'Guardian';

  @override
  String get guardianKindGuardian => 'Guardian';

  @override
  String get guardianKindCaregiver => 'Center teacher';

  @override
  String inviteShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'Let\'s look after Elumi together. Tap the link below to open the elum app with the invite code filled in.\nThe invite code works for $_temp0.\n\n$url\n\nIf the link doesn\'t open, enter it in the app.\nInvite code $code';
  }

  @override
  String get guardiansEditTitle => 'Edit my name';

  @override
  String get guardiansEditDescription =>
      'This is the name co-guardians of this Elumi see. It doesn\'t have to be your real name.';

  @override
  String get guardiansEditNameHint => 'Mom, Dad, Teacher';

  @override
  String get guardiansEditSave => 'Save';

  @override
  String get guardiansLeaveConfirmTitle => 'Stop looking after together?';

  @override
  String get guardiansLeaveConfirmMessageLast =>
      'There are no other guardians\nIf you leave, the routines and stars made with Elumi will be gone\nThis can\'t be undone';

  @override
  String get guardiansLeaveConfirmMessageOthers =>
      'If you connected Elumi\'s device, it will be disconnected\nA remaining guardian needs to make a new link code to use it again\nRoutines you made will be gone\nElumi\'s and other guardians\' routines and stars stay';

  @override
  String get guardiansLeaveConfirmAction => 'Stop';

  @override
  String get guardiansLeaveTypeTitle => '한 번 더 확인할게요';

  @override
  String guardiansLeaveTypeMessage(String phrase) {
    return '이룸이와 일과, 별이 모두 사라져요\n아래 칸에 \'$phrase\'라고\n똑같이 입력해 주세요';
  }

  @override
  String get guardiansLeaveTypePhrase => '그만두기';

  @override
  String get guardiansLeaveTypeAction => '그만두기';

  @override
  String get guardiansLeaveFailTitle => 'Couldn\'t leave';

  @override
  String get guardiansLeaveFailedFallback => 'Try again in a moment';

  @override
  String guardiansLeft(String name) {
    return 'You left $name';
  }

  @override
  String get guardiansNameEditFailTitle => 'Couldn\'t change the name';

  @override
  String get guardiansNameEditFailedFallback => 'Try again in a moment';

  @override
  String get guardiansTitle => 'Co-guardians';

  @override
  String get guardiansNoProfileMessage =>
      'There\'s no Elumi to show co-guardians for';

  @override
  String get guardiansNoProfileDescription => 'Add Elumi first';

  @override
  String get guardiansIntro => 'Family or teachers who make routines together';

  @override
  String get guardiansLoadFailedFallback => 'Couldn\'t load co-guardians';

  @override
  String get guardiansEmptyMessage => 'Couldn\'t find any co-guardians';

  @override
  String get guardiansAloneHint =>
      'You\'re looking after Elumi alone for now. Try inviting family or a teacher.';

  @override
  String get guardiansInviteAction => 'Invite another guardian';

  @override
  String get guardiansEnterCodeAction => 'Enter an invite code';

  @override
  String get guardiansLeaveAction => 'Stop looking after together';

  @override
  String get guardiansLeaveHintAlone =>
      'You\'re the only guardian, so stopping removes Elumi, routines and stars';

  @override
  String get guardiansLeaveHintWithOthers =>
      'Only routines you made are removed';

  @override
  String inviteCodeGuestJoinedTitle(String name) {
    return '$name has joined you';
  }

  @override
  String get guardiansMeBadge => 'Me';

  @override
  String guardiansPeopleHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people caring together',
      one: '1 person caring together',
    );
    return '$_temp0';
  }

  @override
  String get guardiansInviteHeader => 'Invite';

  @override
  String get guardiansRenameAction => 'Rename';

  @override
  String get inviteCodeShareFailTitle => 'Couldn\'t send the link';

  @override
  String get inviteCodeShareFailFallback => 'Tell them the code yourself';

  @override
  String get inviteCodeTitle => 'Invite code';

  @override
  String get inviteCodeShareButton => 'Send as a link';

  @override
  String get inviteCodeHeaderTitle =>
      'Share the code with\nthe guardian joining you';

  @override
  String inviteCodeAsk(String name, String batchim) {
    return 'Whoever gets this will help look after $name';
  }

  @override
  String get inviteCodeNoProfileMessage =>
      'There\'s no Elumi to look after together';

  @override
  String get inviteCodeNoProfileDescription => 'Add Elumi first';

  @override
  String get inviteCodeIssueFailedFallback => 'Couldn\'t make the invite code';

  @override
  String get inviteEnterLinkInvalid =>
      'This invite link isn\'t right. Ask them to send it again. (E-INV-LINK)';

  @override
  String get inviteEnterFormInvalid =>
      'That invite code isn\'t right (E-INV-FORM)';

  @override
  String inviteJoined(String name, String batchim) {
    return 'You\'re now looking after $name together';
  }

  @override
  String get inviteEnterNotFound => 'That invite code isn\'t right';

  @override
  String get inviteEnterExpired =>
      'The invite code has expired. Get a new one.';

  @override
  String get inviteEnterTooManyAttempts => 'Try again in a moment';

  @override
  String get inviteEnterAlreadyGuardian =>
      'You\'re already looking after this Elumi';

  @override
  String get inviteEnterForbiddenForElumi =>
      'You can\'t do this on Elumi\'s device';

  @override
  String get inviteEnterInvalidInput => 'That invite code isn\'t right';

  @override
  String get inviteEnterOffline => 'Couldn\'t connect. Check your internet.';

  @override
  String get inviteEnterOther => 'Couldn\'t connect. Try again.';

  @override
  String get inviteEnterConsentFailTitle => 'Couldn\'t enter the invite code';

  @override
  String get inviteEnterConsentFallback => 'Agree to the terms first';

  @override
  String get inviteEnterStartButton => 'Start';

  @override
  String get inviteEnterManualLink => 'Enter a different code';

  @override
  String get inviteEnterTitle => 'Enter the\ninvite code';

  @override
  String get inviteEnterDescriptionFromLink =>
      'This is the invite code from the link. If it\'s right, tap Start.';

  @override
  String get inviteEnterDescriptionManual =>
      'The code is on a co-guardian\'s device,\nin My info → Co-guardians';

  @override
  String get inviteEnterDescriptionPath => 'My info → Co-guardians';

  @override
  String get inviteEnterSemanticsFromLink => 'Invite code from the link';

  @override
  String get inviteEnterSemanticsInput => 'Enter invite code';

  @override
  String get profileSwitchChanged => 'Switched Elumi';

  @override
  String get profileSwitchTitle => 'Switch Elumi';

  @override
  String get profileSwitchLoadFailedFallback =>
      'Couldn\'t load the list of Elumi';

  @override
  String get profileSwitchLoadFailedMessage =>
      'Couldn\'t load the list of Elumi';

  @override
  String profileSwitchSelected(String name) {
    return '$name, the Elumi you\'re viewing';
  }

  @override
  String get noticeHideWeek => 'Hide for a week';

  @override
  String noticeHideDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Hide for $days days',
      one: 'Hide for $days day',
    );
    return '$_temp0';
  }

  @override
  String noticeLinkOpenFailed(String code) {
    return 'Couldn\'t open the link ($code)';
  }

  @override
  String get noticeCloseBarrier => 'Close notice';

  @override
  String get cardPhotoTooLarge => 'This photo is too big. Pick another one.';

  @override
  String get cardPhotoWrongType => 'Only JPG or PNG photos can be added';

  @override
  String get cardPhotoUnreadable =>
      'Couldn\'t read this photo. Pick another one.';

  @override
  String get cardPhotoPickFailed => 'Couldn\'t get the photo. Try again.';

  @override
  String get routineLoadingPrepareTitle => 'Lumi is organizing\nwhat you wrote';

  @override
  String get routineLoadingGenerateTitle => 'Lumi is making\nthe action cards';

  @override
  String get routineStageReviewSituation => 'Reading what you wrote';

  @override
  String get routineStageTidyEssentials => 'Keeping only what matters';

  @override
  String get routineStageThinkQuestions => 'Thinking of follow-up questions';

  @override
  String get routineStageReadRoutine => 'Reading today\'s routine';

  @override
  String get routineStageFindItems => 'Finding the key items to bring';

  @override
  String get routineStageOrderSteps => 'Putting the steps in order';

  @override
  String get suggestionRainyText => 'Going to school on a rainy day';

  @override
  String get suggestionRainyPrompt =>
      'I want to get ready to go to school with an umbrella on a rainy day';

  @override
  String get suggestionHospitalText => 'Getting ready for a hospital visit';

  @override
  String get suggestionHospitalPrompt =>
      'We have to go to the hospital and I want to prepare so Elumi isn\'t scared';

  @override
  String get suggestionTripText => 'Getting ready for a field trip';

  @override
  String get suggestionTripPrompt =>
      'I want to list what to pack in order on the morning of a field trip';

  @override
  String get suggestionNewPlaceText => 'Visiting a new place';

  @override
  String get suggestionNewPlacePrompt =>
      'I want to help Elumi feel ready before going somewhere new';

  @override
  String get suggestionAfterSchoolText =>
      'Getting ready for summer after-school class';

  @override
  String get suggestionAfterSchoolPrompt =>
      'I want to list the steps to get ready for after-school class during vacation, in order';

  @override
  String get guardianHomeTodayRoutine => 'Today\'s routine';

  @override
  String get guardianHomePastRoutine => 'Past routines';

  @override
  String get guardianHomeGoChildScreen => 'Go to Elumi mode';

  @override
  String get notificationBellLabel => 'Notifications';

  @override
  String get notificationBellUnreadLabel => 'You have unread notifications';

  @override
  String get notificationTabNotifications => 'Notifications';

  @override
  String get notificationTabNotices => 'Notices';

  @override
  String get notificationDayToday => 'Today';

  @override
  String get notificationDayYesterday => 'Yesterday';

  @override
  String get notificationDayEarlier => 'Earlier';

  @override
  String get notificationMarkAllRead => 'Mark all read';

  @override
  String get notificationEmpty => 'No notifications yet';

  @override
  String get notificationNoticeEmpty => 'No notices yet';

  @override
  String get notificationNoticeFailed => 'Couldn\'t load notices';

  @override
  String get notificationSettingsTitle => 'Notification settings';

  @override
  String get notificationSettingAll => 'All notifications';

  @override
  String get notificationSettingRoutineCompleted =>
      'When an ELUM user finishes a routine';

  @override
  String get notificationSettingRoutineSent =>
      'When a co-guardian sends a routine';

  @override
  String get notificationSettingCoGuardianJoined => 'When a new guardian joins';

  @override
  String get notificationSettingCreditRefilled =>
      'When this week\'s credits are refilled';

  @override
  String get notificationSettingFeedbackResolved =>
      'When your feedback is resolved';

  @override
  String get notificationSettingTalkCommented =>
      'Community: when someone comments on my post';

  @override
  String get notificationSettingTalkImported =>
      'Community: when someone imports my post';

  @override
  String get notificationPermissionOff => 'Device notifications are off';

  @override
  String get notificationTurnOnDeviceNotification => 'Turn on';

  @override
  String get notificationSettingSaveFailed => 'Couldn\'t save your settings';

  @override
  String get notificationSettingLoadFailed => 'Couldn\'t load your settings';

  @override
  String get notificationListFailed => 'Couldn\'t load notifications';

  @override
  String get notificationProfileUnavailable =>
      'This ELUM user is no longer available';

  @override
  String notificationRoutineCompletedOne(String title) {
    return 'Finished \'$title\'';
  }

  @override
  String notificationRoutineCompletedMany(int count) {
    return 'Finished $count routines';
  }

  @override
  String get notificationRoutineCompletedNoTitle => 'Finished a routine';

  @override
  String notificationRoutineSent(String title) {
    return 'A co-guardian sent \'$title\'';
  }

  @override
  String get notificationRoutineSentNoTitle =>
      'A co-guardian sent a new routine';

  @override
  String get notificationCoGuardianJoined => 'A new guardian joined';

  @override
  String get notificationCreditRefilled => 'This week\'s credits are refilled';

  @override
  String get notificationFeedbackResolved => 'We reviewed your feedback';

  @override
  String notificationTalkPostCommented(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your post got $count comments',
      one: 'Your post got $count comment',
    );
    return '$_temp0';
  }

  @override
  String notificationTalkPostImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guardians imported your post',
      one: '$count guardian imported your post',
    );
    return '$_temp0';
  }

  @override
  String guardianHomeGreeting(String name) {
    return 'Hello,\n$name 👋🏻';
  }

  @override
  String get guardianHomeSubtitle => 'What routine should we prepare today?';

  @override
  String get pinChangeMismatchCreate =>
      'The passcodes don\'t match. Try again.';

  @override
  String get pinChangeMismatch => 'The passcodes don\'t match. Try again.';

  @override
  String get pinChangeCreateFailedTitle => 'Couldn\'t create the passcode';

  @override
  String get pinChangeFailedTitle => 'Couldn\'t change the passcode';

  @override
  String get pinChangeFailedFallback => 'Try again in a moment';

  @override
  String get pinChangeCreatedSnack => 'Passcode created';

  @override
  String get pinChangeChangedSnack => 'Passcode changed';

  @override
  String get pinChangeVerifyTitle => 'Enter your\ncurrent passcode';

  @override
  String get pinChangeCreateTitle => 'Create a passcode\nonly you know';

  @override
  String get pinModeHint =>
      'You\'ll use this passcode to switch to Guardian mode';

  @override
  String get pinChangeEnterTitle => 'Enter your\nnew passcode';

  @override
  String get pinChangeCreateConfirmTitle => 'Enter the passcode\none more time';

  @override
  String get pinChangeConfirmTitle => 'Enter the passcode\none more time';

  @override
  String get pinChangeConfirmHint =>
      'You\'re almost done changing the passcode';

  @override
  String get pinChangeHeaderTitle => 'Change passcode';

  @override
  String get pinChangeSave => 'Save';

  @override
  String get pinChangeInputLabel => 'Enter passcode';

  @override
  String get rewardSaveFailedTitle => 'Couldn\'t save the reward';

  @override
  String get rewardSaveFailedFallback => 'Try again in a moment';

  @override
  String get rewardWhyTitle => 'Why a reward?';

  @override
  String get rewardWhyMessage =>
      'When something good waits at the end of a routine, Elumi finds the strength to finish.\nA small thing you can give today works better than a gift a month away.\nYou can make a routine without setting one.';

  @override
  String get rewardHeadlineTitle => 'What reward comes\nafter the routine?';

  @override
  String get rewardHeadlineBody =>
      'It will be a big motivation to finish the routine';

  @override
  String get rewardLater => 'Maybe later';

  @override
  String get imageStyleChangedSnack => 'Picture style changed';

  @override
  String get imageStyleSaveFailedTitle => 'Couldn\'t save the picture style';

  @override
  String get imageStyleSaveFailedFallback => 'Try again in a moment';

  @override
  String get imageStyleTitle => 'Picture style';

  @override
  String get routineLoadingBlockedTitle => 'Can\'t make it right now';

  @override
  String get routineLoadingPrepareFailed => 'Couldn\'t prepare the questions';

  @override
  String get routineLoadingGenerateFailed => 'Couldn\'t make the cards';

  @override
  String get routineLoadingInputNeededTitle => '어떤 일과인지 알려 주세요';

  @override
  String get routineLoadingEditInput => '다시 적기';

  @override
  String routineLoadingPercent(int percent) {
    return '$percent% done';
  }

  @override
  String get routineLoadingRetry => 'Try again';

  @override
  String get routineLoadingHome => 'Go home';

  @override
  String get draftRoutinesTitle => 'Drafts';

  @override
  String get draftRoutinesLoadFailedFallback => 'Couldn\'t load drafts';

  @override
  String get draftRoutinesDeleteLabel => 'Delete draft';

  @override
  String get draftRoutinesDeleteConfirmTitle => 'Delete this draft?';

  @override
  String get draftRoutinesDeleteAction => 'Delete';

  @override
  String get draftRoutinesDeleteFailedTitle => 'Couldn\'t delete the draft';

  @override
  String get draftRoutinesDeleteFailedFallback => 'Try again in a moment';

  @override
  String get draftRoutinesRewardUnset => 'No reward yet';

  @override
  String get draftRoutinesRewardLabel => 'When done';

  @override
  String get draftRoutinesResume => 'Continue';

  @override
  String get draftRoutinesEmptyTitle => 'No unfinished routines';

  @override
  String get draftRoutinesEmptyBody =>
      'If you stop while making a routine, it stays here';

  @override
  String get cardReviewDeleteConfirmTitle => 'Delete this card?';

  @override
  String get cardReviewDeleteAction => 'Delete';

  @override
  String get cardReviewSoundFailedTitle => 'Couldn\'t play the sound';

  @override
  String get cardReviewSoundFailedFallback =>
      'Turn on your device\'s sound and tap again';

  @override
  String get cardReviewSaveFailedTitle => 'Couldn\'t save the routine';

  @override
  String get cardReviewSaveFailedFallback => 'Try again in a moment';

  @override
  String get cardReviewEditFailedTitle => 'Couldn\'t save your changes';

  @override
  String get cardReviewEditFailedFallback => 'Try again in a moment';

  @override
  String get cardReviewAddFailedTitle => 'Couldn\'t add the card';

  @override
  String get cardReviewAddFailedFallback => 'Try again in a moment';

  @override
  String get cardImageGeneratingLabel => 'Making the picture';

  @override
  String get cardImageNoCreditToast =>
      'Not enough credits, so we added a basic picture';

  @override
  String get cardImageUnavailableToast =>
      'Couldn\'t make the picture, so we added a basic picture';

  @override
  String get cardImageMissingAfterCreateToast =>
      '그림을 만들지 못한 카드는 기본 그림으로 넣었어요. 이 카드 수정에서 AI 그림을 그릴 수 있어요';

  @override
  String get cardReviewReorderDone => 'Done';

  @override
  String get cardReviewSave => 'Save cards';

  @override
  String get routineInputTitle => 'What does today\nneed?';

  @override
  String get routineInputSubtitle => 'AI Lumi breaks it into small steps';

  @override
  String get routineInputHint => 'Write it the way you\'d say it';

  @override
  String get routineInputSend => 'Send';

  @override
  String get guardianSettingsLogoutConfirmTitle => 'Log out?';

  @override
  String get guardianSettingsWithdrawConfirmTitle => 'Delete your account?';

  @override
  String get guardianSettingsWithdrawConfirmMessage =>
      'All routines and stars will be gone\nLogging in again won\'t bring them back';

  @override
  String get guardianSettingsWithdrawConfirmAction => '탈퇴하기';

  @override
  String get guardianSettingsWithdrawFailedTitle =>
      'Couldn\'t delete the account';

  @override
  String get guardianSettingsWithdrawFailedFallback => 'Try again in a moment';

  @override
  String get guardianSettingsWithdrawAppStoreSubscriptionNotice =>
      'Pro 구독은 탈퇴해도 이어져요\n앱스토어에서\n직접 해지해 주세요';

  @override
  String get guardianSettingsWithdrawGooglePlaySubscriptionNotice =>
      '탈퇴하면 플레이스토어 Pro 구독의\n다음 결제를 멈춰요';

  @override
  String get guardianSettingsWithdrawTypeTitle => '한 번 더 확인할게요';

  @override
  String guardianSettingsWithdrawTypeMessage(String phrase) {
    return '아래 칸에 \'$phrase\'라고\n똑같이 입력해 주세요';
  }

  @override
  String get guardianSettingsWithdrawTypePhrase => '회원탈퇴';

  @override
  String get guardianSettingsWithdrawTypeAction => '탈퇴하기';

  @override
  String get guardianSettingsTitle => 'Settings';

  @override
  String get guardianSettingsPeople => 'Co-guardians';

  @override
  String get guardianSettingsDrafts => 'Drafts';

  @override
  String get guardianSettingsPinChange => 'Change passcode';

  @override
  String get guardianSettingsTerms => 'Terms and Privacy Policy';

  @override
  String get guardianSettingsFeedback => 'Send feedback';

  @override
  String get feedbackTitle => 'Send feedback';

  @override
  String get feedbackHint => 'Tell us what was hard to use';

  @override
  String get feedbackIncludeLog => 'Send app status log and device info';

  @override
  String get feedbackSend => 'Send';

  @override
  String get feedbackSent => 'Feedback sent';

  @override
  String get feedbackFailedTitle => 'Couldn\'t send your feedback';

  @override
  String get feedbackFailedFallback =>
      'Your message is still here. Please try again in a moment';

  @override
  String get guardianSettingsLogout => 'Log out';

  @override
  String get guardianSettingsWithdraw => 'Delete account';

  @override
  String get guardianSettingsLinkConnected => 'Elumi\'s device';

  @override
  String get guardianSettingsLinkConnect => 'Connect Elumi\'s device';

  @override
  String get guardianSettingsLinkStatus => 'Connected';

  @override
  String get guardianSettingsProfileSwitch => 'Switch Elumi';

  @override
  String get guardianSettingsImageStyle => 'Picture style';

  @override
  String get guardianSettingsHaptic => 'Vibrate on card check';

  @override
  String get guardianSettingsPraiseSound => 'Praise sound on card check';

  @override
  String get guardianSettingsScreenAwake =>
      'Keep screen on while viewing cards';

  @override
  String get questionMakeCards => 'Make cards';

  @override
  String get questionCustomAdd => '+ Write your own';

  @override
  String get questionCustomHint => 'Write it here';

  @override
  String get questionCustomClose => 'Close writing';

  @override
  String questionClearLabel(String label) {
    return 'Clear $label';
  }

  @override
  String cardReviewMade(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Made $count cards',
      one: 'Made $count card',
    );
    return '$_temp0';
  }

  @override
  String get cardReviewRewardLead => 'When done: ';

  @override
  String get cardReviewRewardSet => 'Set a reward';

  @override
  String get cardReviewReorderHint =>
      'Press and hold a card to change the order';

  @override
  String get cardReviewToolReorder => 'Reorder cards';

  @override
  String get cardReviewToolEdit => 'Edit this card';

  @override
  String get cardReviewToolAdd => 'Add a card';

  @override
  String get cardReviewReorderTitle => 'Reorder cards';

  @override
  String get cardReviewReorderCancel => 'Cancel reordering';

  @override
  String get cardReviewEmptyTitle => 'No cards yet';

  @override
  String get cardReviewEmptyBody => 'Make the routine again from the start';

  @override
  String get cardReviewEmptyAction => 'Make it again';

  @override
  String get cardMoveForward => 'Move earlier';

  @override
  String get cardMoveBackward => 'Move later';

  @override
  String get cardSpeakStop => 'Stop reading';

  @override
  String get cardSpeak => 'Listen';

  @override
  String get cardDeleteLabel => 'Remove this card';

  @override
  String get cardAddPhoto => 'Add photo';

  @override
  String get cardViewerBarrierLabel => 'Close card';

  @override
  String get cardViewerSoundFailedTitle => 'Couldn\'t play the sound';

  @override
  String get cardViewerSoundFailedFallback =>
      'Turn on your device\'s sound and tap again';

  @override
  String get cardViewerClose => 'Close card';

  @override
  String get cardEditAddTitle => 'Add a new card';

  @override
  String get cardEditTitle => 'Edit card';

  @override
  String get cardEditFieldTitle => 'Title';

  @override
  String get cardEditTitleHint => 'Write the card title';

  @override
  String get cardEditFieldDescription => 'Description';

  @override
  String get cardEditDescriptionHint => 'Write the card description';

  @override
  String get cardEditAddAction => 'Add';

  @override
  String get cardEditDoneAction => 'Done';

  @override
  String get cardPhotoPermissionTake => 'Take a photo';

  @override
  String get cardPhotoPermissionGallery => 'Choose from gallery';

  @override
  String get cardPhotoPermissionOpenSettings => 'Open settings';

  @override
  String get cardPhotoPermissionCameraTitle => 'Can\'t use the camera';

  @override
  String get cardPhotoPermissionGalleryTitle => 'Can\'t see your photos';

  @override
  String get cardPhotoPermissionCameraBody =>
      'Turn on the camera in your device\'s settings to take photos';

  @override
  String get cardPhotoPermissionGalleryBody =>
      'Turn on photo access in your device\'s settings to choose photos';

  @override
  String get cardPhotoSettingsFailedTitle => 'Couldn\'t open settings';

  @override
  String get cardPhotoSettingsFailedFallback =>
      'Turn it on in your device\'s settings';

  @override
  String get cardPhotoSourceTake => 'Take a photo';

  @override
  String get cardPhotoSourceGallery => 'Choose from gallery';

  @override
  String cardPhotoUploadFailedDialog(String message) {
    return 'Couldn\'t upload the photo.\n$message';
  }

  @override
  String get cardPhotoChange => 'Change photo';

  @override
  String get cardPhotoUploading => 'Uploading the photo';

  @override
  String get cardPhotoUploadFailed => 'Couldn\'t upload the photo';

  @override
  String get cardPhotoRetry => 'Try again';

  @override
  String get creditCardTitle => 'AI this week';

  @override
  String get creditCardLoading => 'Loading this week\'s AI usage';

  @override
  String get creditCardLoadFailed => 'Couldn\'t load usage';

  @override
  String get creditCardRetry => 'Try again';

  @override
  String get creditGenerating => 'Making the routine';

  @override
  String get creditExhausted => 'You\'ve used all your credits this week';

  @override
  String get creditExhaustedStillOk =>
      'You can still view routines you made and edit them yourself';

  @override
  String get creditInfoLabel => 'About AI credits';

  @override
  String creditAmountLeft(int available, int weekly) {
    return '$available / $weekly credits left';
  }

  @override
  String creditAmountRest(int weekly) {
    return ' / $weekly credits left';
  }

  @override
  String aiCreditResetLine(String reset) {
    return 'Refills $reset';
  }

  @override
  String get creditCostTitle => 'How AI credits are used';

  @override
  String creditCostLineTextFree(int imageCost) {
    String _temp0 = intl.Intl.pluralLogic(
      imageCost,
      locale: localeName,
      other: '$imageCost개',
    );
    return '일과 글은 크레딧 없이 만들고, 그림이 완성된 카드 1장마다 $_temp0씩 써요.';
  }

  @override
  String creditCostLine(int textCost, int imageCost) {
    String _temp0 = intl.Intl.pluralLogic(
      textCost,
      locale: localeName,
      other: '$textCost credits',
      one: '$textCost credit',
    );
    String _temp1 = intl.Intl.pluralLogic(
      imageCost,
      locale: localeName,
      other: '$imageCost credits',
      one: '$imageCost credit',
    );
    return 'Making the routine text uses $_temp0, and each card with a finished picture uses $_temp1.';
  }

  @override
  String get creditCostKeepGoing =>
      'A routine you start while you have credits is finished, even with many pictures.';

  @override
  String get creditWeeklyRefill => 'Credits refill every Monday at 0:00.';

  @override
  String get routineCreateButton => 'Make a new routine';

  @override
  String get routineSwipeDelete => 'Delete routine';

  @override
  String get routineSwipeEdit => 'Edit routine';

  @override
  String get routineFlowHomeLabel => 'Go home';

  @override
  String get routineFlowDraftLabel => 'Draft';

  @override
  String get routineFlowLeaveStay => 'Keep making';

  @override
  String get routineFlowLeaveConfirm => 'Leave';

  @override
  String get routineLeaveDiscardTitle => 'Stop making this routine?';

  @override
  String get routineLeaveDiscardMessage =>
      'If you leave now, what you wrote won\'t be kept';

  @override
  String get routineLeaveDraftWhenReadyTitle => 'Leave it as a draft?';

  @override
  String get routineLeaveDraftWhenReadyMessage =>
      'Once the cards are ready, it stays in drafts\nYou can continue from My info';

  @override
  String get routineLeaveDraftTitle => 'Leave it as a draft?';

  @override
  String get routineLeaveDraftMessage =>
      'You can continue from\nDrafts in My info';

  @override
  String get routineLeaveEditTitle => 'Leave without saving?';

  @override
  String get routineLeaveEditMessage =>
      'Removed cards only go away when you tap Save';

  @override
  String get routineTileRewardLabel => 'When done';

  @override
  String get routineTileRerun => 'Do it again';

  @override
  String get routineDetailReorderFailedTitle => 'Couldn\'t save the order';

  @override
  String get routineDetailReorderFailedFallback => 'Try again in a moment';

  @override
  String get routineDetailRerun => 'Do it again';

  @override
  String get routineDetailEdit => 'Edit';

  @override
  String get routineDetailFinishedToday => 'This routine is done';

  @override
  String get routineDetailOpenHint => 'Tap to see the card bigger';

  @override
  String get routineDetailNoReward => 'No reward after this routine';

  @override
  String get rewardInputHint => 'e.g. 10 minutes of videos';

  @override
  String get todayRoutineReorderFailedTitle => 'Couldn\'t save the order';

  @override
  String get todayRoutineReorderFailedFallback => 'Try again in a moment';

  @override
  String get todayRoutineDeleteConfirmTitle => 'Delete this routine?';

  @override
  String get todayRoutineStartedTitle => 'Elumi already started this routine';

  @override
  String get todayRoutineStartedMessage =>
      'It can\'t be deleted so what was done stays on record';

  @override
  String get todayRoutineDeleteAction => 'Delete';

  @override
  String get todayRoutineDeleteFailedTitle => 'Couldn\'t delete the routine';

  @override
  String get todayRoutineDeleteFailedFallback => 'Try again in a moment';

  @override
  String get todayRoutineLoadFailedFallback => 'Couldn\'t load the routines';

  @override
  String get todayRoutineRerunFailedTitle => 'Couldn\'t make the routine again';

  @override
  String get todayRoutineRerunFailedFallback => 'Try again in a moment';

  @override
  String todayRoutineCopied(String title) {
    return 'Added $title to today\'s routines';
  }

  @override
  String get todayRoutinePastLoadFailedFallback =>
      'Couldn\'t load past routines';

  @override
  String get todayRoutineEmptyTitle => 'No routines yet';

  @override
  String get todayRoutineEmptyHint => 'Make your first action cards for today';

  @override
  String get todayRoutinePastEmpty => 'No past routines';

  @override
  String get homeCoachCreate => 'You can make a *new routine\nfor Elumi to do*';

  @override
  String get homeCoachSwipe => '*Swipe a routine left*\nto *edit or delete it*';

  @override
  String get homeCoachSwitch =>
      'Tap the character icon\nto *switch to Elumi mode*';

  @override
  String childHomeGreeting(String name, String batchim) {
    return 'Here\'s what $name\nhas to do today. You can do it!';
  }

  @override
  String childHomeEmptyTitle(String name) {
    return 'No routines\nfor $name yet';
  }

  @override
  String get childHomeEmptyHint => 'Make a routine in Guardian mode';

  @override
  String get childHomeEmptyHintDevice =>
      'Make a routine on a guardian\'s device';

  @override
  String get childHomeToGuardianLabel => 'Go to Guardian mode';

  @override
  String get childHomeSettingsLabel => 'Open settings';

  @override
  String get childHomeRewardPrefix => 'When done:';

  @override
  String childStarsEarned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You got $count stars\nKeep going and find more stars!',
      one: 'You got $count star\nKeep going and find more stars!',
    );
    return '$_temp0';
  }

  @override
  String childStarsSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars collected',
      one: '$count star collected',
    );
    return '$_temp0';
  }

  @override
  String childCardPagerLabel(int total, int index) {
    return 'Card $index of $total';
  }

  @override
  String get childDetailSoundFailedTitle => 'Couldn\'t play the sound';

  @override
  String get childDetailSoundFailedFallback =>
      'Turn on your device\'s sound and tap again';

  @override
  String get childDetailCheckLabel => 'I did it';

  @override
  String get rewardBannerPrefix => 'When done: ';

  @override
  String get rewardLumiTitle => 'Congratulations!';

  @override
  String rewardLumiMessage(String name) {
    return 'Lumi brought a star for $name\nfor getting it done';
  }

  @override
  String get rewardLumiButton => 'Yay!';

  @override
  String get rewardPopoTitle => 'Well done!';

  @override
  String rewardPopoMessage(String name) {
    return 'Popo brought $name\na big star as a gift';
  }

  @override
  String get rewardPopoButton => 'Great!';

  @override
  String get rewardRuruTitle => 'Awesome!';

  @override
  String rewardRuruMessage(String name, String batchim) {
    return 'Ruru brought a gift\nbecause $name got it done';
  }

  @override
  String get rewardRuruButton => 'Hooray!';

  @override
  String get routineDoneTitle => 'Routine done!';

  @override
  String routineDoneMessage(String name) {
    return 'Made for $name,\nwho finished everything';
  }

  @override
  String get routineDoneButton => 'I did it!';

  @override
  String get modeSwitchToChild => 'Enter the passcode to switch to Elumi mode';

  @override
  String get modeSwitchToGuardian =>
      'Enter the passcode to switch to Guardian mode';

  @override
  String get modeSwitchTitle => 'Enter your passcode';

  @override
  String get modeSwitchMismatch => 'That passcode isn\'t right. Try again.';

  @override
  String get modeSwitchPinLabel => 'Enter passcode';

  @override
  String get modeSwitchReadFailedTitle => 'Couldn\'t check the passcode';

  @override
  String get modeSwitchReadFailedFallback => 'Try again in a moment';

  @override
  String get modeSwitchBlockedTitle => 'Open this on\na guardian\'s device';

  @override
  String get modeSwitchBlockedDescription =>
      'Guardian mode can\'t be opened on this device';

  @override
  String get modeSwitchBlockedBack => 'Go back';

  @override
  String get installationRetryTitle => 'Something went wrong';

  @override
  String get installationRetryMessage =>
      'We couldn\'t check this device. Want to try again?';

  @override
  String get installationRetryButton => 'Try again';

  @override
  String get issuedCodeCopyButton => 'Copy code';

  @override
  String get issuedCodeCopied => 'Code copied';

  @override
  String get issuedCodeCopyFailedTitle => 'Couldn\'t copy';

  @override
  String get issuedCodeCopyFailedFallback =>
      'Please tell them the code on the screen yourself';

  @override
  String linkShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'Let\'s connect Elumi\'s device. Tap the link below on that device to open the elum app with the connection code filled in.\nThe connection code works for $_temp0.\n\n$url\n\nIf the link doesn\'t open, enter it in the app.\nConnection code $code';
  }

  @override
  String get linkRejectedAlreadyLinked => 'This device is already connected';

  @override
  String get linkRejectedOnGuardianPhone => 'Open this on Elumi\'s device';

  @override
  String get creditHistoryTitle => 'Credit history';

  @override
  String get creditHistoryLink => 'View credit history';

  @override
  String creditHistoryDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String creditHistoryDetail(String kind, String time) {
    return '$kind・$time';
  }

  @override
  String get creditHistoryKindRoutineText => 'Making the routine';

  @override
  String creditHistoryKindCardImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count card pictures',
      one: '$count card picture',
    );
    return '$_temp0';
  }

  @override
  String get creditHistoryKindCardImage => 'Making a card picture';

  @override
  String get creditHistoryKindImageRegenerate => 'Remaking a card picture';

  @override
  String get creditHistoryFree => '크레딧 없이';

  @override
  String get creditHistoryKindWeeklyGrant =>
      'Your credits were refilled this week';

  @override
  String get creditHistoryKindAdReward => 'Received for watching an ad';

  @override
  String get creditHistoryKindAdminBonus => 'A bonus from the Elum team';

  @override
  String get creditHistoryKindOtherGrant => 'You received credits';

  @override
  String get creditHistoryKindExpired => 'Last week\'s credits expired';

  @override
  String get creditHistoryKindAdjusted => 'Credits were adjusted';

  @override
  String get creditHistoryKindUnknownSpend => 'You used credits';

  @override
  String get creditHistoryEmptyTitle => 'No credits used yet';

  @override
  String get creditHistoryEmptyBody =>
      'Make a routine and it will show up here';

  @override
  String get creditHistoryLoadFailed => 'Couldn\'t load credit history';

  @override
  String get creditHistoryMoreFailed => 'Couldn\'t load more';

  @override
  String get reminderRowLabel => 'Routine reminder';

  @override
  String get reminderRowOff => 'No reminder';

  @override
  String reminderRowDaily(String time) {
    return 'Every day at $time';
  }

  @override
  String reminderRowOnce(String time) {
    return 'Once at $time';
  }

  @override
  String get reminderSheetTitle => 'When should we remind you?';

  @override
  String get reminderSheetBody =>
      'This device will get a notification at the time you pick';

  @override
  String get reminderRepeatDaily => 'Remind at the same time every day';

  @override
  String get reminderTurnOn => 'Turn on reminder';

  @override
  String get reminderUpdate => 'Change reminder time';

  @override
  String get reminderTurnOff => 'Turn off reminder';

  @override
  String get reminderSavedToast => 'Reminder set';

  @override
  String get reminderClearedToast => 'Reminder turned off';

  @override
  String get reminderPermissionDeniedTitle => 'Notifications are off';

  @override
  String get reminderPermissionDeniedBody =>
      'Allow ELUM notifications in your device settings to get routine reminders';

  @override
  String get reminderFailedTitle => 'Couldn\'t set the reminder';

  @override
  String get reminderFailedBody => 'Please try again in a moment';

  @override
  String get reminderChannelName => 'Routine reminders';

  @override
  String get reminderNotificationTitle => 'ELUM';

  @override
  String reminderNotificationBody(String routineTitle) {
    return 'Time for $routineTitle';
  }

  @override
  String get routineTemplateOpen => 'Browse example routines';

  @override
  String get routineTemplateSheetTitle => 'Example routines';

  @override
  String get routineTemplateSheetBody =>
      'Pick one and we\'ll fill in the text. Adjust it for your Elumi before sending';

  @override
  String get routineTemplateBeginnerBadge => 'Good for first-timers';

  @override
  String get routineTemplateCategorySelfCare => 'Self-care';

  @override
  String get routineTemplateCategorySelfCareHint =>
      'Everyday tasks like washing, dressing and eating';

  @override
  String get routineTemplateCategoryDailyFlow => 'Daily flow';

  @override
  String get routineTemplateCategoryDailyFlowHint =>
      'The big steps from morning to bedtime';

  @override
  String get routineTemplateCategoryHousehold => 'Chores';

  @override
  String get routineTemplateCategoryHouseholdHint =>
      'Tidying up your own things and space';

  @override
  String get routineTemplateCategoryCommunity => 'Out and about';

  @override
  String get routineTemplateCategoryCommunityHint =>
      'Practice doing things alone, like riding the bus or shopping';

  @override
  String get routineTemplateCategoryLearning => 'Study';

  @override
  String get routineTemplateCategoryLearningHint =>
      'Starting and finishing study time in order';

  @override
  String get routineTemplateCategoryFeelings => 'Feelings and friends';

  @override
  String get routineTemplateCategoryFeelingsHint =>
      'Showing feelings, greeting and waiting your turn';

  @override
  String get routineTemplateBrushTeethText => 'Brushing teeth';

  @override
  String get routineTemplateBrushTeethPrompt =>
      'I want my Elumi to brush their teeth alone. Walk through taking out the toothbrush and toothpaste, filling the cup with water, brushing, rinsing and putting things away';

  @override
  String get routineTemplateWashFaceText => 'Washing face';

  @override
  String get routineTemplateWashFacePrompt =>
      'I want my Elumi to wash their face alone in the morning. Walk through turning on the water, wetting the face, making soap bubbles, rinsing, drying with a towel and putting on lotion';

  @override
  String get routineTemplateGetDressedText => 'Getting dressed alone';

  @override
  String get routineTemplateGetDressedPrompt =>
      'I want my Elumi to get dressed alone. Walk through putting on an undershirt, a T-shirt, pants and socks one at a time';

  @override
  String get routineTemplateEatMealText => 'Mealtime';

  @override
  String get routineTemplateEatMealPrompt =>
      'I want my Elumi to handle mealtime on their own. Walk through drinking water, bringing their own spoon and bowl, sitting down to eat and taking the dishes back';

  @override
  String get routineTemplateBathTimeText => 'Bath time';

  @override
  String get routineTemplateBathTimePrompt =>
      'I want my Elumi to take a bath step by step. Walk through taking off clothes, wetting the body, washing hair, washing the body, rinsing, drying with a towel and getting dressed';

  @override
  String get routineTemplateMorningRoutineText => 'Getting ready for school';

  @override
  String get routineTemplateMorningRoutinePrompt =>
      'I want my Elumi to do everything from waking up to leaving for school in order. Walk through getting up, using the bathroom, eating, washing and brushing, getting dressed, and putting on the backpack and shoes';

  @override
  String get routineTemplateAfterSchoolText => 'After school';

  @override
  String get routineTemplateAfterSchoolPrompt =>
      'I want my Elumi to do things on their own after coming home from school. Walk through putting away shoes, washing hands, putting the bag in its place, having a snack and taking a break';

  @override
  String get routineTemplateBedtimeText => 'Getting ready for bed';

  @override
  String get routineTemplateBedtimePrompt =>
      'I want my Elumi to do the bedtime steps in order. Walk through brushing teeth, putting on pajamas, packing tomorrow\'s bag, and turning off the light to lie down';

  @override
  String get routineTemplateGoingOutText => 'Getting ready to go out';

  @override
  String get routineTemplateGoingOutPrompt =>
      'I want my Elumi to get ready to go out on their own. Walk through using the bathroom, putting on a jacket, taking a water bottle and phone, putting on shoes and waiting by the door';

  @override
  String get routineTemplateTidyRoomText => 'Tidying the room';

  @override
  String get routineTemplateTidyRoomPrompt =>
      'I want my Elumi to tidy their room after playing. Walk through gathering toys, putting them in the box, shelving books and hanging clothes';

  @override
  String get routineTemplateClearDishesText => 'Clearing dishes';

  @override
  String get routineTemplateClearDishesPrompt =>
      'I want my Elumi to clear their dishes after eating. Walk through gathering leftovers, carrying the dishes, putting them in the sink and wiping the table';

  @override
  String get routineTemplateFoldLaundryText => 'Folding laundry';

  @override
  String get routineTemplateFoldLaundryPrompt =>
      'I want my Elumi to fold and put away dry laundry. Walk through bringing the laundry, matching socks, folding towels, folding clothes and putting them in the drawer';

  @override
  String get routineTemplateTakeOutTrashText => 'Taking out the trash';

  @override
  String get routineTemplateTakeOutTrashPrompt =>
      'I want my Elumi to sort and take out the trash. Walk through gathering trash, separating paper and plastic, tying the bag and taking it to the right place';

  @override
  String get routineTemplateRideBusText => 'Riding the bus';

  @override
  String get routineTemplateRideBusPrompt =>
      'I want my Elumi to practice riding the bus alone. Walk through checking the bus number at the stop, lining up, tapping the transit card, sitting down and pressing the bell at their stop';

  @override
  String get routineTemplateBuyItemText => 'Buying something at a store';

  @override
  String get routineTemplateBuyItemPrompt =>
      'I want my Elumi to buy something at a convenience store alone. Walk through finding the item, lining up at the counter, putting the item down, paying by card or cash, and taking the receipt and saying thanks';

  @override
  String get routineTemplateUseElevatorText => 'Taking the elevator to a floor';

  @override
  String get routineTemplateUseElevatorPrompt =>
      'I want my Elumi to take the elevator to a set floor alone. Walk through pressing the button, getting on when the door opens, pressing the floor number, watching the floor display and getting off';

  @override
  String get routineTemplateHospitalVisitText => 'Going to the doctor';

  @override
  String get routineTemplateHospitalVisitPrompt =>
      'I want my Elumi to go through a doctor visit in order. Walk through checking in, waiting in the waiting room, going in when called, seeing the doctor, and getting medicine and saying goodbye';

  @override
  String get routineTemplateStartHomeworkText => 'Starting homework';

  @override
  String get routineTemplateStartHomeworkPrompt =>
      'I want my Elumi to start and finish homework on their own. Walk through sitting at the desk, taking out the notebook and pencil, doing the homework, showing it when done and putting it in the bag';

  @override
  String get routineTemplateWriteNameText => 'Practicing writing a name';

  @override
  String get routineTemplateWriteNamePrompt =>
      'I want my Elumi to hold a pencil properly and write their name. Walk through holding the pencil, placing the paper, tracing the name, writing it alone and cleaning up';

  @override
  String get routineTemplateCountObjectsText => 'Counting game';

  @override
  String get routineTemplateCountObjectsPrompt =>
      'I want my Elumi to practice counting objects one by one. Walk through laying out the objects, pointing to each with a finger, counting out loud and saying the total';

  @override
  String get routineTemplateReadBookText => 'Reading time';

  @override
  String get routineTemplateReadBookPrompt =>
      'I want my Elumi to have reading time on their own. Walk through choosing a book, sitting down, turning the pages one by one and putting the book back on the shelf';

  @override
  String get routineTemplateEmotionCardText =>
      'Showing a feelings card when upset';

  @override
  String get routineTemplateEmotionCardPrompt =>
      'When my Elumi gets angry at a friend, I want them to show a feelings card instead of yelling or pushing. Walk through stopping, taking the feelings card out of the pocket, choosing the card for how they feel and showing it to the teacher';

  @override
  String get routineTemplatePlayNicelyText => 'Playing nicely with friends';

  @override
  String get routineTemplatePlayNicelyPrompt =>
      'I want my Elumi to practice playing nicely with friends. Walk through asking to play together, sharing toys, taking turns and saying thank you at the end';

  @override
  String get routineTemplateGreetingText => 'Saying hello';

  @override
  String get routineTemplateGreetingPrompt =>
      'I want my Elumi to greet people first. Walk through looking at the person\'s face, waving, saying hello and smiling';

  @override
  String get routineTemplateWaitTurnText => 'Waiting your turn';

  @override
  String get routineTemplateWaitTurnPrompt =>
      'I want my Elumi to practice waiting in line for their turn. Walk through standing at the end of the line, waiting behind the person in front, checking when it\'s their turn and going when it comes';

  @override
  String get routineTemplateAskHelpText => 'Asking for help';

  @override
  String get routineTemplateAskHelpPrompt =>
      'I want my Elumi to ask for help when something is hard. Walk through stopping, finding a nearby adult, saying \'please help me\', and saying thank you after getting help';

  @override
  String get guardianTabHome => 'Home';

  @override
  String get guardianTabManage => 'Routines';

  @override
  String get guardianTabTalk => 'Community';

  @override
  String get guardianTabMe => 'My info';

  @override
  String get guardianMyInfoProfileName => 'Guardian';

  @override
  String get guardianMyInfoEmailPrivate => 'Email private';

  @override
  String guardianMyInfoJoinedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'y.MM.dd',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return 'Joined $dateString';
  }

  @override
  String get guardianMyInfoActiveBadge => 'Viewing';

  @override
  String get guardianNicknameEditLabel => 'Change nickname';

  @override
  String get guardianNicknameSheetTitle => 'Change my name';

  @override
  String get guardianNicknameSheetDescription =>
      'This name shows when you write in Community.\nYou can change it once every 7 days';

  @override
  String get guardianNicknameSheetHint => 'Enter a name';

  @override
  String get guardianNicknameSheetSave => 'Save';

  @override
  String get guardianNicknameInvalidFormat =>
      'Use 2 to 16 Korean or English letters, numbers or hyphens';

  @override
  String guardianNicknameChangeableFrom(String since) {
    return '$since, you can change it again';
  }

  @override
  String get guardianNicknameChanged => 'Nickname changed';

  @override
  String get guardianNicknameSaveFailed => 'Couldn\'t change your nickname';

  @override
  String get guardianSideNavCaption => 'Guardian mode';

  @override
  String get guardianSideNavChildScreen => 'Elumi mode';

  @override
  String get routineLibraryEmptyTitle => 'No routines yet';

  @override
  String get routineLibraryEmptyBody =>
      'Tap + New routine below to make your first one';

  @override
  String get routineLibraryLoadFailedFallback => 'Couldn\'t load your routines';

  @override
  String get routineLibraryCreate => 'New routine';

  @override
  String get routineLibrarySendToday => 'Send today';

  @override
  String get routineLibraryEditCards => 'Edit cards';

  @override
  String get routineLibraryAlreadySent => 'Already sent today';

  @override
  String get routineLibrarySendFailedTitle => 'Couldn\'t send';

  @override
  String get routineLibraryActionFailedFallback =>
      'Please try again in a moment';

  @override
  String get routineLibraryCopied => 'Copy created';

  @override
  String get routineLibraryCopyFailedTitle => 'Couldn\'t copy';

  @override
  String get routineLibraryMenuRename => 'Rename';

  @override
  String get routineLibraryMenuCopy => 'Copy';

  @override
  String get routineLibraryMenuRemove => 'Delete';

  @override
  String get routineLibraryRenameHint => 'Routine name';

  @override
  String get routineLibraryRenameSave => 'Save';

  @override
  String get routineLibraryRenamed => 'Renamed';

  @override
  String get routineLibraryRenameFailedTitle => 'Couldn\'t rename';

  @override
  String get routineLibraryRemoveConfirmTitle => 'Delete this routine?';

  @override
  String get routineLibraryRemoveConfirmMessage =>
      'It leaves your routine list. What your Elumi already did stays recorded';

  @override
  String get routineLibraryRemoved => 'Routine deleted';

  @override
  String get routineLibraryRemoveFailedTitle => 'Couldn\'t delete';

  @override
  String get routineLibrarySentBadge => 'Sent today';

  @override
  String get routineLibraryTileHint => 'Long press to open the menu';

  @override
  String get routineLibraryFromTalk => 'From Community';

  @override
  String get routineLibraryNewBadge => 'New';

  @override
  String get routineDetailTalkOriginBand => 'Imported from Community';

  @override
  String get routineDetailTalkOriginOpenPost => 'Original post';

  @override
  String get routineDetailTalkOriginPostGone => 'Post removed';

  @override
  String get routineDetailTalkOriginBandOpenLabel =>
      'Imported from Community, view original post';

  @override
  String routineLibrarySent(String title) {
    return 'Sent $title for today';
  }

  @override
  String onboardingExampleTitle(String name) {
    return 'What would you like\nto help $name with?';
  }

  @override
  String get onboardingExampleDescription =>
      'We\'ll add example routines for the ones you pick.\nYou can pick more than one.';

  @override
  String get onboardingExampleSkip => 'Skip';

  @override
  String get exampleCategoryMorningEvening => 'Morning & evening';

  @override
  String get exampleCategoryMorningEveningHint => 'Washing, dressing, bedtime';

  @override
  String get exampleCategorySchoolStudy => 'School & study';

  @override
  String get exampleCategorySchoolStudyHint =>
      'Getting ready for school, homework';

  @override
  String get exampleCategoryHouseSelf => 'Chores & doing it myself';

  @override
  String get exampleCategoryHouseSelfHint => 'Tidying up, setting the table';

  @override
  String get exampleCategoryOutside => 'Out and about';

  @override
  String get exampleCategoryOutsideHint => 'Taking the bus, shopping';

  @override
  String get exampleRoutinesFailed => 'Couldn\'t add the example routines';

  @override
  String get routineGroupMenuAddToGroup => 'Add to a bundle';

  @override
  String get routineGroupMenuReorder => 'Change order';

  @override
  String get routineGroupMenuUngroup => 'Ungroup';

  @override
  String routineGroupTileLabel(String name, int count) {
    return '$name bundle, $count routines';
  }

  @override
  String get routineGroupDefaultName => 'New bundle';

  @override
  String get routineGroupNameLabel => 'Bundle name';

  @override
  String get routineGroupNameHint => 'Bundle name (e.g. Morning)';

  @override
  String get routineGroupNewTitle => 'New bundle';

  @override
  String routineGroupAddTitle(String name) {
    return 'Add to $name';
  }

  @override
  String get routineGroupPickHintNew =>
      'Tap routines in the order to show them';

  @override
  String get routineGroupPickHint => 'Tap routines in order';

  @override
  String get routineGroupPickEmpty => 'No routines to add';

  @override
  String routineGroupPickConfirmNew(int count) {
    return 'Bundle $count';
  }

  @override
  String routineGroupPickConfirmAdd(int count) {
    return 'Add $count';
  }

  @override
  String get routineGroupCreateMenuTitle => 'What do you want to make?';

  @override
  String get routineGroupCreateRoutine => 'New routine';

  @override
  String get routineGroupCreateGroup => 'New bundle';

  @override
  String get routineGroupChooseTitle => 'Which bundle?';

  @override
  String routineGroupSheetCount(int count) {
    return '$count routines';
  }

  @override
  String get routineGroupSheetAdd => 'Add routines';

  @override
  String routineGroupSheetRemove(String title) {
    return 'Remove $title from bundle';
  }

  @override
  String get routineGroupCreated => 'Bundle created';

  @override
  String get routineGroupAdded => 'Added to bundle';

  @override
  String get routineGroupUngrouped => 'Bundle ungrouped';

  @override
  String get routineGroupUngroupedEmpty =>
      'All routines were taken out, so the bundle was ungrouped';

  @override
  String routineGroupSent(String name) {
    return 'Sent the $name bundle for today';
  }

  @override
  String get routineGroupAllSentAlready =>
      'Everything in this bundle was already sent today';

  @override
  String get routineGroupActionFailedTitle => 'Couldn\'t change the bundle';

  @override
  String get routineGroupUngroupConfirmTitle => 'Ungroup this bundle?';

  @override
  String get routineGroupUngroupConfirmMessage =>
      'The routines stay in Routines';

  @override
  String routineGroupRemoveConfirmTitle(String title) {
    return 'Take $title out of the bundle?';
  }

  @override
  String get routineGroupRemoveConfirmMessage =>
      'The routine stays in Routines';

  @override
  String get routineGroupRemoveConfirmAction => 'Take out';

  @override
  String childHomeGroupProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String get childHomeGroupAllDone => 'All done!';

  @override
  String get routineTitleEdit => 'Rename routine';

  @override
  String get routineDetailMore => 'More';

  @override
  String get libraryArrangeDone => 'Done';

  @override
  String get libraryArrangeRemove => 'Remove or ungroup';

  @override
  String get routineGroupEditOrder => 'Edit';

  @override
  String get routineLibrarySendOnlyThis => 'Send only this one today';

  @override
  String routineGroupRowCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '$count card',
    );
    return '$_temp0';
  }

  @override
  String get routineManageCoachTapMessage => '*Tap* a routine to see its cards';

  @override
  String get routineManageCoachLongPressMessage =>
      'Press and hold, then *let go* to open the menu';

  @override
  String get routineManageCoachSentMessage =>
      'Routines sent today get a *✓*\nThey go into today\'s routines on Home\nand stay here too';

  @override
  String get routineManageCoachDragMessage =>
      'Press and hold, then *move* to start arranging\nDrop on another routine to make a *bundle*\nDrop between them to move it';

  @override
  String get routineManageCoachCreateGroupMessage =>
      'If dragging is hard, use *+ New routine*\nand pick *New bundle* to group them';

  @override
  String get cardReviewCoachEditMessage =>
      'Fix the *words and picture* of this card\nYou can also use *your own photo*';

  @override
  String get cardReviewCoachReorderMessage =>
      'Tap here, then *press and drag* a card\nto change the order';

  @override
  String get cardReviewCoachSaveMessage =>
      'When you\'re done, be sure to tap *Save cards*\nThe routine is finished only after saving';

  @override
  String get coachHelpLabel => 'How to use';

  @override
  String get pushPermissionSheetTitle =>
      'Want a heads-up when your ELUM user finishes a routine?';

  @override
  String get pushPermissionSheetBody =>
      'You\'ll also get updates from other guardians and credit reminders';

  @override
  String get pushPermissionAllow => 'Turn on';

  @override
  String get pushPermissionLater => 'Not now';

  @override
  String get pushPermissionDenied =>
      'You can turn this on anytime in notification settings';

  @override
  String get pushChannelGuardianUpdates => 'Guardian updates';

  @override
  String get pushPermissionNudgeTitle => 'Notifications are off';

  @override
  String get pushPermissionNudgeBody =>
      'Turn them on to hear right away when your ELUM user finishes a routine';

  @override
  String get pushPermissionElumiTitle =>
      'Get notified when a new routine arrives?';

  @override
  String get pushPermissionElumiBody =>
      'You\'ll get a notification on this device when a guardian sends a routine';

  @override
  String get pushPermissionTurnOn => 'Turn on notifications';

  @override
  String get pushChannelElumiRoutines => 'New routines';

  @override
  String get signInProviderKakao => 'Kakao';

  @override
  String get signInProviderNaver => 'Naver';

  @override
  String get signInProviderGoogle => 'Google';

  @override
  String get signInProviderApple => 'Apple';

  @override
  String get routineManageCoachSampleMorning => 'Morning routine';

  @override
  String get routineManageCoachSampleBrush => 'Brushing teeth';

  @override
  String get routineManageCoachSampleBag => 'Packing my bag';

  @override
  String get updateSuggestionTitle => 'A new version is here';

  @override
  String get updateSuggestionBody =>
      'Update to get the latest fixes and features';

  @override
  String get updateSuggestionLater => 'Later';

  @override
  String elumiInfoTitle(String name) {
    return '$name\'s info';
  }

  @override
  String elumiInfoEditLabel(String name) {
    return 'Edit $name\'s info';
  }

  @override
  String get elumiInfoName => 'Name';

  @override
  String get elumiInfoCharacter => 'Character';

  @override
  String get elumiInfoCharacterSheetTitle => 'Change character';

  @override
  String get elumiInfoImageStyleSheetTitle => 'Change picture style';

  @override
  String get elumiInfoSave => 'Save';

  @override
  String get elumiInfoSaved => 'Saved';

  @override
  String get elumiInfoSaveFailedTitle => 'Couldn\'t save';

  @override
  String get elumiInfoSaveFailedFallback => 'Try again in a moment';

  @override
  String get elumiInfoNotFound => 'Couldn\'t load Elumi\'s info';

  @override
  String get talkTitle => 'Community';

  @override
  String get talkWriteButton => 'Post';

  @override
  String get talkCategoryAll => 'All';

  @override
  String get talkPopularTitle => 'Most imported routines this week';

  @override
  String talkPopularImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guardians imported',
      one: '$count guardian imported',
    );
    return '$_temp0';
  }

  @override
  String get talkLatestTitle => 'Just posted';

  @override
  String get talkEmptyTitle => 'No routines shared yet';

  @override
  String get talkEmptyCategoryTitle =>
      'No routines shared in this category yet';

  @override
  String get talkEmptyCategoryAction => 'See all';

  @override
  String get talkFeedFailed => 'Couldn\'t load Community';

  @override
  String get talkAuthorFallback => 'Guardian';

  @override
  String get talkShareTitleLabel => 'Routine title';

  @override
  String get talkShareTitleHint => 'Write a routine title';

  @override
  String get talkNoteLabel => 'Note';

  @override
  String talkHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Helpful $count',
    );
    return '$_temp0';
  }

  @override
  String talkCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Comments $count',
      one: 'Comment $count',
    );
    return '$_temp0';
  }

  @override
  String get talkLoadMoreRetry => 'Couldn\'t load more. Tap to try again';

  @override
  String talkDetailStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '$count card',
    );
    return '$_temp0';
  }

  @override
  String get talkDetailLoadFailed => 'Couldn\'t load the post';

  @override
  String get talkPostGoneTitle => 'This post is no longer available';

  @override
  String get talkPostGoneBack => 'Back to Community';

  @override
  String talkDetailCardCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
    );
    return '$_temp0';
  }

  @override
  String talkDetailPostedAt(DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('M/d', localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dateString $timeString';
  }

  @override
  String get talkViewGrid => 'See all at once';

  @override
  String get talkViewLarge => 'See large';

  @override
  String get talkHelpfulFailed =>
      'Couldn\'t change Helpful. Try again in a moment';

  @override
  String get talkImportButton => 'Import as a routine';

  @override
  String get talkImportedButton => '✓ Added to Routines';

  @override
  String get talkShareLinkButton => 'Share';

  @override
  String talkShareLinkMessage(String title, String url) {
    return '$title\nLet\'s look at it together in elum Community\n\n$url';
  }

  @override
  String get talkShareLinkFailed => 'Couldn\'t share. Try again in a moment';

  @override
  String get talkPostLinkRejectedOnElumiDevice =>
      'Community posts can be viewed on a guardian\'s device';

  @override
  String get talkImportSheetTitle => 'Import as a routine';

  @override
  String get talkImportSheetHint =>
      'After adding it, you can change it to fit your Elumi';

  @override
  String get talkImportElumiLabel => 'Elumi';

  @override
  String get talkImportConfirm => 'Done';

  @override
  String get talkImportNoElumiTitle => 'Connect your Elumi first';

  @override
  String get talkImportNoElumiAction => 'Connect Elumi';

  @override
  String talkImportDone(String elumiName) {
    return 'Added to $elumiName\'s routines';
  }

  @override
  String get talkImportGoToLibrary => 'Go see';

  @override
  String get talkImportFailedTitle => 'Couldn\'t add it to Routines';

  @override
  String get talkCommentsTitle => 'Comments';

  @override
  String get talkCommentsEmpty => 'No comments yet';

  @override
  String talkCommentAuthorMine(String name) {
    return '$name (me)';
  }

  @override
  String talkCommentAuthorPostWriter(String name) {
    return '$name (author)';
  }

  @override
  String get talkCommentHiddenNotice => 'Hidden under our community policy';

  @override
  String get talkCommentsFailed => 'Couldn\'t load comments';

  @override
  String get talkCommentHint => 'Leave a comment';

  @override
  String get talkCommentSend => 'Send';

  @override
  String get talkCommentSendFailedTitle => 'Couldn\'t send the comment';

  @override
  String get talkFailedFallback => 'Try again in a moment';

  @override
  String get talkCommentDeleteTitle => 'Delete this comment?';

  @override
  String get talkCommentDeleteAction => 'Delete';

  @override
  String get talkCommentDeleteFailedTitle => 'Couldn\'t delete the comment';

  @override
  String get talkMenuReport => 'Report';

  @override
  String get talkMenuBlock => 'Hide this guardian\'s posts';

  @override
  String get talkMenuEdit => 'Edit';

  @override
  String get talkMenuTakeDown => 'Take down';

  @override
  String get talkMoreLabel => 'More';

  @override
  String get talkTakeDownTitle => 'Take down this post?';

  @override
  String get talkTakeDownMessage =>
      'Other guardians won\'t see a post once you take it down.';

  @override
  String get talkTakeDownDone => 'Post taken down';

  @override
  String get talkTakeDownFailedTitle => 'Couldn\'t take down the post';

  @override
  String get talkEditTitle => 'Edit post';

  @override
  String get talkEditSave => 'Save';

  @override
  String get talkEditSaved => 'Edited';

  @override
  String get talkEditFailedTitle => 'Couldn\'t edit the post';

  @override
  String get talkNoteGuide =>
      'Don\'t write personal details like other people\'s names or contacts';

  @override
  String get talkCategoryTitle => 'Category';

  @override
  String get talkReportTitle => 'Report';

  @override
  String get talkReportSubmit => 'Report';

  @override
  String get talkReportDone => 'Reported';

  @override
  String get talkReportFailedTitle => 'Couldn\'t report';

  @override
  String get talkReportReasonPersonalInfo => 'It shows Elumi or family details';

  @override
  String get talkReportReasonOffensive => 'It has hurtful words';

  @override
  String get talkReportReasonAdvertising => 'It\'s an ad or promotion';

  @override
  String get talkReportReasonOther => 'Other reason';

  @override
  String talkBlockTitle(String nickname) {
    return 'Hide posts from $nickname?';
  }

  @override
  String get talkBlockMessage =>
      'You won\'t see this guardian\'s posts and comments. They won\'t know. You can see them again in My info › Hidden guardians.';

  @override
  String get talkBlockAction => 'Hide';

  @override
  String get talkBlockDone => 'Hidden';

  @override
  String get talkBlockFailedTitle => 'Couldn\'t hide';

  @override
  String get talkBlockedGuardiansTitle => 'Hidden guardians';

  @override
  String get talkBlockedGuardiansEmpty => 'No hidden guardians';

  @override
  String get talkBlockedGuardiansFailed => 'Couldn\'t load hidden guardians';

  @override
  String get talkUnblockAction => 'Show again';

  @override
  String get talkUnblockDone => 'You can see them again';

  @override
  String get talkUnblockFailedTitle => 'Couldn\'t unhide';

  @override
  String get talkRulesTitle => 'Community rules';

  @override
  String get talkRulesIntro =>
      'To share safely with other guardians, please follow these three rules.';

  @override
  String get talkRulesPrivacy =>
      'Don\'t show faces, names, schools or home addresses';

  @override
  String get talkRulesRespect =>
      'Respect other guardians. No blaming, ads or promotion';

  @override
  String get talkRulesNoDiagnosis =>
      'Don\'t write diagnoses or hospital details';

  @override
  String get talkRulesAgreeCheck =>
      'I read the rules above and will follow them';

  @override
  String get talkRulesAgreeButton => 'Agree and continue';

  @override
  String get talkRulesFailedTitle => 'Couldn\'t save your agreement';

  @override
  String get talkShareTitle => 'Post to Community';

  @override
  String get talkSharePickTitle => 'Which routine do you want to share?';

  @override
  String get talkSharePickEmpty => 'No routines to post';

  @override
  String get talkSharePickEmptyHint =>
      'You can post only your own routines in Routines. Routines you already posted or imported from Community are left out. You can post an example routine after you change its title or cards.';

  @override
  String get talkSharePickFailed => 'Couldn\'t load routines';

  @override
  String get talkSharePreviewFailed => 'Couldn\'t load what you\'re posting';

  @override
  String get talkSharePhotoTitle => 'How do you want to post the photos?';

  @override
  String get talkSharePhotoGuide =>
      'Blur faces, names and home addresses if they show.\nAI-made pictures are posted as they are';

  @override
  String get talkSharePhotoBlur => 'Blur';

  @override
  String get talkSharePhotoKeep => 'As is';

  @override
  String get talkSharePhotoNext => 'Next';

  @override
  String get talkSharePreviewTitle => 'This is how it looks';

  @override
  String get talkShareSubmit => 'Post';

  @override
  String get talkShareDone => 'Posted to Community';

  @override
  String get talkShareFailedTitle => 'Couldn\'t post';

  @override
  String get talkShareHint => '📖 Share it in Community ›';

  @override
  String get talkMenuShare => 'Share in Community';

  @override
  String get talkMyPostsTitle => 'My posts';

  @override
  String get talkMyPostsEmpty => 'No posts yet';

  @override
  String get talkMyPostsEmptyAction => 'Share a routine in Community';

  @override
  String get talkMyPostsFailed => 'Couldn\'t load your posts';

  @override
  String get talkMenuViewMyPost => 'See my post';

  @override
  String get talkLinkSend => 'Send as link';

  @override
  String get talkLinkTurnOff => 'Turn off link';

  @override
  String get talkLinkConfirmTitle => 'Send this routine as a link?';

  @override
  String get talkLinkConfirmGuide =>
      'Only people with the link can see it. It won\'t be posted to Community.\nYou can turn off the link in Routines anytime';

  @override
  String get talkLinkResendGuide =>
      'You already sent a link. The same link is sent again, as it was first sent.\nTo send your changes, turn off the link and send it again';

  @override
  String get talkLinkPhotoTitle => 'How should photos be sent?';

  @override
  String get talkLinkPhotoGuide =>
      'Blur photos that show faces, names, or home addresses.\nAI pictures are shown as they are';

  @override
  String get talkLinkCreateButton => 'Create link';

  @override
  String get talkLinkPreviewFailed => 'Couldn\'t load what to send';

  @override
  String get talkLinkCreateFailedTitle => 'Couldn\'t create the link';

  @override
  String get talkLinkCreated => 'Link created';

  @override
  String talkLinkShareMessage(String title, String url) {
    return '$title\nTake this routine into your elum\n\n$url';
  }

  @override
  String get talkLinkTurnOffTitle => 'Turn off the link?';

  @override
  String get talkLinkTurnOffMessage =>
      'People with the link can\'t see it anymore. Routines they already took stay';

  @override
  String get talkLinkTurnOffDone => 'Link turned off';

  @override
  String get talkLinkTurnOffFailedTitle => 'Couldn\'t turn off the link';

  @override
  String get talkLinkReceivedTitle => 'Shared routine';

  @override
  String get timeAgoJustNow => 'Just now';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '$count hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String routineProgressRingPercentLabel(int percent) {
    return '$percent% done';
  }

  @override
  String get routineProgressRingDoneLabel => 'All done';

  @override
  String get guardianSettingsLicenses => 'Open source licenses';

  @override
  String get licenseScreenTitle => 'Open source licenses';

  @override
  String get licenseScreenGuide =>
      'Elum is built with the artwork, fonts, and software below. Tap an item to read its full license.';

  @override
  String get licenseGroupArtwork => 'Artwork';

  @override
  String get licenseGroupFonts => 'Fonts';

  @override
  String get licenseGroupSoftware => 'Software';

  @override
  String get licenseSoftwareListRow => 'View software list';

  @override
  String get licenseFontTmoneyName => 'Tmoney RoundWind';

  @override
  String get licenseLoadFailedMessage => 'We couldn\'t load the list';

  @override
  String get cardExportOpen => '인쇄용으로 받기';

  @override
  String get cardExportFormatSection => '어떻게 받을까요?';

  @override
  String get cardExportFormatRoutineSheet => '일과 한 장';

  @override
  String get cardExportFormatRoutineSheetCaption => 'A4 한 장에 순서대로';

  @override
  String get cardExportFormatCutCards => '오려 쓰는 카드';

  @override
  String get cardExportFormatCutCardsCaption => 'A4에 자를 선과 함께';

  @override
  String get cardExportFormatCardImages => '카드 한 장씩';

  @override
  String get cardExportFormatCardImagesCaption => '카드마다 이미지 한 장';

  @override
  String get cardExportPerPageSection => '한 쪽에 몇 장 넣을까요?';

  @override
  String get cardExportIncludeText => '카드 문장 넣기';

  @override
  String get cardExportThemeSection => '카드 디자인';

  @override
  String get cardExportThemeBasic => '기본';

  @override
  String get cardExportThemeSimple => '단순';

  @override
  String get cardExportThemeInkSaver => '잉크 절약';

  @override
  String get cardExportThemeMonochrome => '흑백';

  @override
  String get cardExportThemeLargeText => '큰 글자';

  @override
  String get planProBadge => 'Pro';

  @override
  String get cardExportProThemeLocked => 'Pro에서 쓸 수 있는 디자인이에요';

  @override
  String get cardExportWatermarkNotice => 'Free는 이룸 로고와 워터마크가 들어가요';

  @override
  String get cardExportPreviewSection => '미리 보기';

  @override
  String get cardExportMissingPicture => '그림이 아직 없는 카드는 제목만 들어가요';

  @override
  String cardExportSomePicturesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '그림을 불러오지 못한 카드 $count장은 다른 그림이나 제목으로 들어가요',
    );
    return '$_temp0';
  }

  @override
  String get cardExportActualSizeHint => '다른 앱에서 인쇄할 때는 실제 크기를 골라 주세요';

  @override
  String get cardExportPrint => '인쇄하기';

  @override
  String get cardExportShare => '보내기';

  @override
  String get cardExportPreparing => '카드를 준비하고 있어요';

  @override
  String get cardExportImageFailed => '카드 그림을 불러오지 못했어요';

  @override
  String get cardExportRenderFailed => '인쇄용 파일을 만들지 못했어요';

  @override
  String get cardExportPrintFailed => '이 기기에서 인쇄할 수 없어요. 보내기로 받아 주세요';

  @override
  String get cardExportNoCards => '카드가 없는 일과예요';

  @override
  String get cardExportNoneSelected => '보낼 카드를 하나 이상 골라 주세요';

  @override
  String get cardExportFooterMadeWith => '이룸 앱으로 만들었어요';

  @override
  String get cardExportPictogramCredit => '그림: Mulberry Symbols (CC BY-SA 4.0)';

  @override
  String get cardExportEmojiCredit => '그림: Twemoji (CC BY 4.0)';

  @override
  String get cardExportWatermarkText => '이룸';

  @override
  String cardExportPerPage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count장',
    );
    return '$_temp0';
  }

  @override
  String get cardExportFormatRow => '형태';

  @override
  String get cardExportLayoutSection => '배치';

  @override
  String get cardExportStyleSection => '꾸밈';

  @override
  String get cardExportOrientationRow => '용지 방향';

  @override
  String get cardExportOrientationSheetTitle => '용지를 어떻게 놓을까요?';

  @override
  String get cardExportOrientationPortrait => '세로';

  @override
  String get cardExportOrientationLandscape => '가로';

  @override
  String get cardExportPerPageRow => '한 장에';

  @override
  String get cardExportCardSizeRow => '카드 크기';

  @override
  String get cardExportCardSizeSheetTitle => '카드를 얼마나 크게 넣을까요?';

  @override
  String get cardExportCardSizeFit => '꽉 차게';

  @override
  String get cardExportCardSizeMedium => '보통';

  @override
  String get cardExportCardSizeSmall => '작게';

  @override
  String get cardExportProLayoutLocked => 'Pro에서 쓸 수 있는 형태예요';

  @override
  String get cardExportUpsellTitle => 'Pro면 원하는 대로 받을 수 있어요';

  @override
  String get cardExportUpsellBody =>
      '일과 한 장, 오려 쓰는 카드, 한 장에 여러 장, 가로 용지, 디자인까지 골라요';

  @override
  String get modeSwitchToPurchase => '결제는 보호자만 할 수 있어요';

  @override
  String get planBenefitAiImageStyles => '캐릭터·사진 같은 AI 그림';

  @override
  String get planBenefitAdsRemoved => '광고 없음';

  @override
  String get planBenefitWeeklyReport => '주간 리포트';

  @override
  String get planBenefitRoutineSchedule => '요일·시각 정해 반복';

  @override
  String get planBenefitRoutineMemory => '내가 고친 방식 기억하기';

  @override
  String get planBenefitGuardianVoice => '카드마다 보호자 목소리';

  @override
  String get planBenefitFreeRoutineText => '일과 글은 크레딧 없이';

  @override
  String get planBenefitFreeImageRegenerate => '다시 그리기 하루 여러 번 크레딧 없이';

  @override
  String get planBenefitMoreWeeklyCredits => '매주 크레딧 더 많이';

  @override
  String get planBenefitCardExportWithoutWatermark => '워터마크 없이 인쇄';

  @override
  String get planBenefitCardExportAllThemes => '인쇄 디자인 전부';

  @override
  String get planBenefitCardExportAllLayouts => '일과 한 장·오려 쓰는 카드 인쇄';

  @override
  String get planKeepContentNotice => 'Pro가 끝나도 만든 일과와 그림은 그대로 남아요';

  @override
  String get planPeriodMonthly => '1개월';

  @override
  String get planPeriodYearly => '1년';

  @override
  String get planSubscribe => '구독 시작하기';

  @override
  String get planPriceLoading => '가격을 불러오고 있어요';

  @override
  String get planPriceFailed => '가격을 불러오지 못했어요';

  @override
  String get planRestore => '구매 복원';

  @override
  String get planTermsOfUse => '이용약관';

  @override
  String get planPrivacyPolicy => '개인정보처리방침';

  @override
  String get planManageSubscription => '구독 관리';

  @override
  String get planLegalBillingAppStore =>
      '결제는 구매를 확인할 때 Apple ID 계정으로 청구돼요. 기간이 끝나기 최소 24시간 전에 해지하지 않으면 같은 기간과 가격으로 자동 갱신되고, 기간이 끝나기 전 24시간 안에 다음 요금이 청구돼요.';

  @override
  String get planLegalCancelAppStore =>
      '구독 관리와 해지는 기기 설정의 Apple ID > 구독에서 할 수 있어요. 해지해도 남은 기간까지는 Pro를 쓸 수 있어요.';

  @override
  String get planLegalBillingPlayStore =>
      '결제는 구매를 확인할 때 Google Play 계정으로 청구돼요. 해지하기 전까지 같은 기간과 가격으로 자동 갱신돼요.';

  @override
  String get planLegalCancelPlayStore =>
      '구독 관리와 해지는 Google Play 스토어의 결제 및 정기 결제 > 정기 결제에서 할 수 있어요. 해지해도 남은 기간까지는 Pro를 쓸 수 있어요.';

  @override
  String planTrialDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일',
    );
    return '$_temp0';
  }

  @override
  String planTrialWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count주',
    );
    return '$_temp0';
  }

  @override
  String planTrialMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개월',
    );
    return '$_temp0';
  }

  @override
  String planTrialYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count년',
    );
    return '$_temp0';
  }

  @override
  String planStartFreeTrial(String trial) {
    return '$trial 무료로 시작하기';
  }

  @override
  String planTrialEndsNotice(String date, String price) {
    return '무료 체험은 $date에 끝나요. 해지하지 않으면 그날부터 $price씩 청구돼요.';
  }

  @override
  String get planLegalTrialAppStore =>
      '무료 체험이 끝나기 최소 24시간 전에 해지하면 요금이 청구되지 않아요.';

  @override
  String get planLegalTrialPlayStore => '무료 체험 중에 해지하면 요금이 청구되지 않아요.';

  @override
  String get planVerifying => '결제를 확인하고 있어요';

  @override
  String get planStorePendingTitle => '결제 허락을 요청했어요';

  @override
  String get planStorePendingBody => '허락을 받으면 Pro가 켜져요. 이 화면은 닫아도 돼요';

  @override
  String get planVerificationPendingTitle => '결제를 확인하고 있어요';

  @override
  String get planVerificationPendingBody =>
      '다시 결제하지 않아도 돼요. 앱을 다시 열면 한 번 더 확인해요';

  @override
  String get planVerificationRetry => '다시 확인하기';

  @override
  String get planActivatedTitle => 'Pro를 시작했어요';

  @override
  String get planNotActivatedTitle => 'Pro가 켜지지 않았어요';

  @override
  String get planNotActivatedBody => '스토어의 구독 상태를 확인해 주세요';

  @override
  String get planAlreadyProTitle => 'Pro를 쓰고 있어요';

  @override
  String get planPurchaseFailedTitle => '결제하지 못했어요';

  @override
  String get planVerifyFailedTitle => '결제를 이 계정에 연결하지 못했어요';

  @override
  String get planAccountFailedTitle => '계정 정보를 확인하지 못했어요';

  @override
  String get planFailedFallback => '잠시 후 다시 시도해주세요';

  @override
  String get planRestoreDone => 'Pro를 되찾았어요';

  @override
  String get planRestoreNothing => '되찾을 구독이 없어요';

  @override
  String get planRestoreFailedTitle => '구매를 복원하지 못했어요';

  @override
  String get planRestoring => '구매 내역을 확인하고 있어요';

  @override
  String get planManageFailed => '구독 관리 화면을 열지 못했어요';

  @override
  String get planLinkFailed => '링크를 열지 못했어요';

  @override
  String get planSettingsLabel => '내 요금제';

  @override
  String get planStatusFree => 'Free';

  @override
  String get planStatusPro => 'Pro';

  @override
  String planStatusRenewing(String date) {
    return 'Pro · $date 갱신';
  }

  @override
  String planStatusUntil(String date) {
    return 'Pro · $date까지';
  }

  @override
  String planStatusCancelScheduled(String date) {
    return 'Pro · $date에 끝나요';
  }

  @override
  String get planStatusGracePeriod => 'Pro · 결제 확인 필요';

  @override
  String get planStatusGift => 'Pro 선물';

  @override
  String planStatusGiftUntil(String date) {
    return 'Pro 선물 · $date까지';
  }

  @override
  String planStatusRenewingFooter(String date) {
    return '$date에 갱신돼요';
  }

  @override
  String planStatusUntilFooter(String date) {
    return '$date까지 쓸 수 있어요';
  }

  @override
  String planStatusCancelScheduledFooter(String date) {
    return '$date에 끝나요';
  }

  @override
  String get planStatusGracePeriodFooter => '결제 수단을 확인해 주세요';

  @override
  String get planLearnPro => 'Pro 알아보기';

  @override
  String get weeklyReportTitle => '주간 리포트';

  @override
  String weeklyReportWeekRange(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth월 $startDay일 ~ $endMonth월 $endDay일';
  }

  @override
  String weeklyReportThisWeekRange(String range) {
    return '이번 주 · $range';
  }

  @override
  String get weeklyReportPreviousWeek => '지난주 보기';

  @override
  String get weeklyReportNextWeek => '다음 주 보기';

  @override
  String get weeklyReportCompletionLabel => '일과 완료율';

  @override
  String weeklyReportPercent(int percent) {
    return '$percent%';
  }

  @override
  String weeklyReportCompletionSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '보낸 일과 $sent개 중 $completed개를 마쳤어요',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportDayNone => '-';

  @override
  String weeklyReportDayCount(int completed, int sent) {
    return '$completed/$sent';
  }

  @override
  String get weeklyReportFactsSection => '한 주 기록';

  @override
  String get weeklyReportStars => '받은 별';

  @override
  String get weeklyReportRewards => '보상까지 간 일과';

  @override
  String get weeklyReportStreak => '연속으로 마친 날';

  @override
  String weeklyReportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRoutinesSection => '일과별 기록';

  @override
  String weeklyReportRoutineValue(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent번 중 $completed번 마침',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRemainingSection => '남아 있던 카드';

  @override
  String get weeklyReportRemainingFooter =>
      '지난 날 일과에서 마치지 않고 남은 카드예요. 오늘 일과는 세지 않아요';

  @override
  String weeklyReportRemainingLabel(String routine, String step) {
    return '$routine · $step';
  }

  @override
  String weeklyReportTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count번',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportEmptyTitle => '이 주에는 보낸 일과가 없어요';

  @override
  String get weeklyReportEmptyBody => '일과를 보내면 이룸이가 마친 기록이 여기에 모여요';

  @override
  String get weeklyReportLoadFailed => '주간 리포트를 불러오지 못했어요';

  @override
  String get weeklyReportNotIncluded => '주간 리포트는 Pro에서 볼 수 있어요';

  @override
  String get weeklyReportSharePreview => '보낼 한 장';

  @override
  String get weeklyReportSharePreviewCaption => '미리 보기 그대로 이미지나 PDF로 보내요';

  @override
  String get weeklyReportShareImage => '이미지';

  @override
  String get weeklyReportSharePdf => 'PDF로 보내기';

  @override
  String get weeklyReportShareFailed => '보낼 한 장을 만들지 못했어요';

  @override
  String weeklyReportShareTitle(String name) {
    return '$name의 한 주';
  }

  @override
  String get weeklyReportShareNote => '이룸 앱에 남은 완료 기록을 센 내용이에요';

  @override
  String get routineScheduleRowOff => '요일·시각 정하기';

  @override
  String get routineScheduleRowLabel => '반복 요일과 시각';

  @override
  String routineScheduleSummary(String days, String time) {
    return '$days $time';
  }

  @override
  String get routineScheduleEveryDay => '매일';

  @override
  String get routineScheduleWeekdaysOnly => '평일';

  @override
  String get routineScheduleWeekendOnly => '주말';

  @override
  String get routineScheduleDaySeparator => '·';

  @override
  String get routineSchedulePaused => 'Pro가 끝나 멈췄어요';

  @override
  String get routineSchedulePausedNote =>
      'Pro가 끝나 반복을 멈췄어요. 정해 둔 요일과 시각은 그대로 남아 있어요';

  @override
  String get routineScheduleSheetTitle => '언제 할까요?';

  @override
  String get routineScheduleSheetBody => '고른 요일마다 이 일과가 오늘 일과로 가요';

  @override
  String get routineScheduleDaysLabel => '요일';

  @override
  String get routineScheduleTimeLabel => '시각';

  @override
  String get routineScheduleNotifyElumi => '그 시각에 이룸이 기기에 알리기';

  @override
  String get routineScheduleElumiNotificationOff => '이룸이 기기 알림이 꺼져 있어요';

  @override
  String get routineScheduleElumiNotificationOffHint =>
      '이룸이 기기의 설정에서 이룸 알림을 켜 주세요';

  @override
  String get routineScheduleElumiNoDevice => '이룸이 기기를 연결하면 그 시각에 알림이 가요';

  @override
  String get routineScheduleSave => '저장하기';

  @override
  String get routineScheduleTurnOff => '반복 끄기';

  @override
  String get routineScheduleSavedToast => '요일과 시각을 저장했어요';

  @override
  String get routineScheduleTurnedOffToast => '반복을 껐어요';

  @override
  String get routineScheduleSaveFailedTitle => '저장하지 못했어요';

  @override
  String get routineScheduleSaveFailedFallback => '잠시 뒤 다시 해 주세요';

  @override
  String get routineSchedulePickDayHint => '요일을 하나 이상 골라 주세요';

  @override
  String get routineScheduleProNote => '반복 일과는 Pro에서 저장할 수 있어요';

  @override
  String get weeklyPlanEntry => '주간 계획';

  @override
  String get weeklyPlanTitle => '주간 계획';

  @override
  String weeklyPlanDayTitle(String weekday) {
    return '$weekday요일';
  }

  @override
  String get weeklyPlanToday => '오늘';

  @override
  String get weeklyPlanEmptyDay => '정한 일과가 없어요';

  @override
  String get weeklyPlanEmptyTitle => '아직 요일을 정한 일과가 없어요';

  @override
  String get weeklyPlanEmptyBody => '일과 관리에서 일과를 누르고 요일·시각을 정해 보세요';

  @override
  String get weeklyPlanLoadFailed => '주간 계획을 불러오지 못했어요';

  @override
  String get weeklyPlanNotifyOff => '알림 없음';

  @override
  String get weeklyPlanMetaSeparator => ' · ';

  @override
  String get guardianVoiceRecordAction => '내 목소리로 녹음하기';

  @override
  String get guardianVoiceRecordHint => '카드를 누르면 이 목소리가 들려요';

  @override
  String guardianVoiceRecording(int seconds) {
    return '녹음하고 있어요 $seconds초';
  }

  @override
  String guardianVoiceRecordingLimit(int seconds) {
    return '$seconds초까지 녹음돼요';
  }

  @override
  String get guardianVoiceStop => '멈추기';

  @override
  String get guardianVoiceSaving => '녹음을 저장하고 있어요';

  @override
  String get guardianVoiceSaved => '녹음했어요';

  @override
  String get guardianVoicePlay => '듣기';

  @override
  String get guardianVoiceRerecord => '다시 녹음';

  @override
  String get guardianVoiceDelete => '지우기';

  @override
  String get guardianVoiceDeleteConfirmTitle => '녹음을 지울까요?';

  @override
  String get guardianVoiceDeleteConfirmMessage => '지우면 기본 목소리로 읽어 줘요';

  @override
  String get guardianVoicePlanEnded => '기본 목소리로 읽어요';

  @override
  String get guardianVoiceMicDeniedTitle => '마이크가 꺼져 있어요';

  @override
  String get guardianVoiceMicDeniedBody => '켜기 전까지 기본 목소리로 읽어요';

  @override
  String get guardianVoiceOpenSettings => '설정 열기';

  @override
  String get guardianVoiceFailedTitle => '녹음을 저장하지 못했어요';

  @override
  String get guardianVoiceRetry => '다시 하기';

  @override
  String get guardianVoiceTooShort => '너무 짧아요. 말한 뒤에 멈추기를 눌러 주세요';

  @override
  String get guardianVoiceRecordFailed => '녹음하지 못했어요. 다시 해 주세요';

  @override
  String get guardianVoiceTooLarge => '녹음 파일이 너무 커요. 조금 짧게 다시 녹음해 주세요';

  @override
  String get guardianVoicePlayFailed => '녹음을 틀지 못했어요';

  @override
  String get guardianVoiceDeleteFailed => '녹음을 지우지 못했어요';

  @override
  String get guardianVoiceRecordChip => '녹음';

  @override
  String get guardianVoicePlanEndedHint => 'Pro가 끝나도 녹음은 남겨 뒀어요';

  @override
  String get guardianSettingsRoutineMemory => 'AI 메모';

  @override
  String get routineMemoryTitle => 'AI 메모';

  @override
  String get routineMemoryEnabledLabel => '내가 고친 일과처럼 만들기';

  @override
  String get routineMemoryEnabledFooter =>
      '카드를 고쳐서 보내면 AI가 이룸이에게 맞는 카드 만들기 방법을 짧게 적어 둬요. 다음 일과를 만들 때 이 메모와 고친 일과를 참고해요.';

  @override
  String routineMemoryLinesHeader(int count, int max) {
    return '메모 $count/$max';
  }

  @override
  String get routineMemoryLinesFooter =>
      '줄을 누르면 고치거나 지울 수 있어요. 진단이나 장애, 정도에 관한 말은 적지 않아요.';

  @override
  String get routineMemoryDisabledFooter =>
      '꺼져 있어요. 켜기 전까지 일과를 만들 때 메모를 쓰지 않고, 고친 카드에서 새로 배우지도 않아요.';

  @override
  String routineMemoryFullFooter(int max) {
    return '메모는 $max개까지예요. 줄을 지우면 새로 더할 수 있어요.';
  }

  @override
  String get routineMemoryEmpty => '아직 메모가 없어요';

  @override
  String get routineMemoryEmptyFooter => '카드를 고쳐서 보내면 하루에 한 번 정리해요. 직접 적어도 돼요.';

  @override
  String get routineMemoryWrittenByMe => '내가 씀';

  @override
  String get routineMemoryAddLine => '메모 더하기';

  @override
  String get routineMemoryAddSheetTitle => '메모 더하기';

  @override
  String get routineMemoryEditSheetTitle => '메모 고치기';

  @override
  String get routineMemoryLineHint => '예: \'씻기\' 대신 \'손 닦기\'라고 써요';

  @override
  String get routineMemorySave => '저장하기';

  @override
  String get routineMemoryDeleteLine => '이 줄 지우기';

  @override
  String get routineMemoryClearAll => '메모 모두 지우기';

  @override
  String get routineMemoryClearFooter =>
      '지난 일과에서 배운 것도 함께 지워요. 그다음 보낸 일과부터 다시 배워요.';

  @override
  String get routineMemoryClearConfirmTitle => '메모를 모두 지울까요?';

  @override
  String get routineMemoryClearConfirmMessage => '지운 메모는 되돌릴 수 없어요.';

  @override
  String get routineMemoryClearConfirmAction => '모두 지우기';

  @override
  String get routineMemoryLoadFailed => '메모를 불러오지 못했어요';

  @override
  String get routineMemorySaveFailedTitle => '메모를 저장하지 못했어요';

  @override
  String get routineMemorySaveFailedFallback => '잠시 뒤 다시 해 주세요.';

  @override
  String get proTeaserSampleLabel => '예시 화면';

  @override
  String get proOnlyNoticeTitle => 'Pro에서 쓸 수 있는 기능이에요';

  @override
  String get proTeaserWeeklyReportBenefit => '한 주 동안 해낸 일과를 한 장으로 정리해 보낼 수 있어요';

  @override
  String get proTeaserRoutineMemoryBenefit => '내가 고친 방식을 기억해 다음 일과를 더 알맞게 만들어요';

  @override
  String get proTeaserCardThemeBenefit => '인쇄용 카드를 여러 디자인으로 받을 수 있어요';

  @override
  String get proTeaserWeeklyPlanBenefit => '매일 아침 일과를 새로 보내지 않아도 돼요';

  @override
  String get proTeaserSampleRoutineMorning => '아침 준비하기';

  @override
  String get proTeaserSampleRoutineBrush => '이 닦기';

  @override
  String get proTeaserSampleRoutineBag => '가방 챙기기';

  @override
  String get proTeaserSampleStepSocks => '양말 신기';

  @override
  String get proTeaserSampleMemoryShort => '카드 문장은 짧게 한 줄로 써요';

  @override
  String get proTeaserSampleMemoryOrder => '옷 입기는 양말부터 시작해요';

  @override
  String get proTeaserSampleMemoryReward => '보상은 스티커로 정해요';

  @override
  String get cardRegenerateChip => '다시 그리기';

  @override
  String get cardRegenerateSheetTitle => '그림을 다시 그릴까요?';

  @override
  String cardRegenerateCostProFree(int count) {
    return '크레딧 없이 · 오늘 $count번 남았어요';
  }

  @override
  String get cardRegenerateCostFree => '크레딧을 쓰지 않아요';

  @override
  String cardRegenerateCostCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '크레딧 $count개',
    );
    return '$_temp0';
  }

  @override
  String get cardRegenerateCostUnknown => '크레딧을 써요';

  @override
  String get cardRegenerateConfirm => '다시 그리기';

  @override
  String get cardRegenerateInProgress => '그림을 다시 그리고 있어요';

  @override
  String get cardRegenerateFailedTitle => '그림을 다시 그리지 못했어요';

  @override
  String get cardFirstDrawChip => 'AI 그림 그리기';

  @override
  String get cardRedrawProChip => 'Pro로 다시 그리기';

  @override
  String get cardFirstDrawProChip => 'Pro로 AI 그림 그리기';

  @override
  String get cardFirstDrawSheetTitle => 'AI 그림을 그릴까요?';

  @override
  String get cardRedrawSheetBody => '고치고 싶은 점을 적거나 골라 주세요. 비워 두면 그대로 다시 그려요';

  @override
  String get cardFirstDrawSheetBody => '원하는 점을 적거나 골라 주세요. 새 그림을 보고 고를 수 있어요';

  @override
  String get cardRedrawRequestLabel => '고치고 싶은 점';

  @override
  String get cardRedrawRequestHint => '예: 우산을 파란색으로';

  @override
  String get cardRedrawHintSimpler => '더 단순하게';

  @override
  String get cardRedrawHintNoBackground => '배경 빼기';

  @override
  String get cardRedrawHintNoPeople => '사람 빼기';

  @override
  String get cardRedrawHintBrighter => '더 밝게';

  @override
  String get cardFirstDrawConfirm => '그리기';

  @override
  String get cardFirstDrawInProgress => '그림을 그리고 있어요';

  @override
  String get cardFirstDrawFailedTitle => 'AI 그림을 그리지 못했어요';

  @override
  String get cardRedrawFailedFallback => '다시 해 볼까요? 크레딧은 쓰지 않았어요';

  @override
  String get cardCandidateSheetTitle => '어떤 그림으로 할까요?';

  @override
  String get cardCandidateSheetBody => '고른 그림만 이룸이에게 보여요';

  @override
  String get cardCandidateCurrentLabel => '지금 그림';

  @override
  String get cardCandidateNewLabel => '새 그림';

  @override
  String get cardCandidateKeepButton => '지금 그림 그대로';

  @override
  String get cardCandidateApplyButton => '새 그림으로 바꾸기';

  @override
  String get cardCandidateAppliedToast => '새 그림으로 바꿨어요';

  @override
  String get cardCandidateLoadFailedTitle => '새 그림을 불러오지 못했어요';

  @override
  String get cardCandidateApplyFailedTitle => '새 그림으로 바꾸지 못했어요';

  @override
  String get planHeroHeadline => '이룸이만을 위한 카드로 바뀌어요';

  @override
  String get planHeroSubline => '같은 일과도 Pro로 만들면 이렇게 달라져요';

  @override
  String get planHeroFreeTag => 'Free · 이모지';

  @override
  String get planHeroProTag => 'Pro · 캐릭터 그림';

  @override
  String get planHeroCompareSemantics => 'Free는 이모지 카드, Pro는 캐릭터 그림 카드예요';

  @override
  String get planBenefitGroupCards => '더 예쁜 카드';

  @override
  String get planBenefitGroupRoutines => '일과가 알아서 준비돼요';

  @override
  String get planBenefitGroupWeek => '한 주를 한눈에';

  @override
  String get planBenefitGroupExtra => '넉넉하게, 광고 없이';

  @override
  String get planBenefitSeparator => ' · ';

  @override
  String planYearlySaving(int percent) {
    return '$percent% 아껴요';
  }

  @override
  String planMonthlyEquivalent(String price) {
    return '한 달에 $price 꼴';
  }

  @override
  String get planRenewsYearly => '1년마다 자동 갱신';

  @override
  String get planRenewsMonthly => '1개월마다 자동 갱신';

  @override
  String planPriceUnit(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'yearly': '/년',
      'other': '/월',
    });
    return '$_temp0';
  }

  @override
  String planCtaTrialNoticeAppStore(String trial, String price, String unit) {
    return '$trial 뒤 $price$unit 자동 결제 · 끝나기 하루 전까지 해지하면 청구되지 않아요';
  }

  @override
  String planCtaTrialNoticePlayStore(String trial, String price, String unit) {
    return '$trial 뒤 $price$unit 자동 결제 · 체험 중 해지하면 청구되지 않아요';
  }

  @override
  String planCtaRenewNotice(String price, String unit) {
    return '$price$unit 자동 갱신 · 언제든 해지할 수 있어요';
  }

  @override
  String planTryFreeTrial(String trial) {
    return '$trial 무료로 써 보기';
  }

  @override
  String get planSeeAllBenefits => 'Pro 혜택 모두 보기';

  @override
  String get planTierGift => '선물';

  @override
  String get proTeaserWeeklyPlanTitle => '요일과 시각만 정해 두면 그날 일과가 준비돼요';

  @override
  String get proTeaserWeeklyReportTitle => '한 주를 한 장으로 받아 봐요';

  @override
  String get proTeaserRoutineMemoryTitle => '이룸이에게 맞춘 방식을 기억해요';

  @override
  String get proTeaserCardThemeTitle => '인쇄용 카드를 더 예쁘게 받아요';

  @override
  String get proTeaserCardLayoutTitle => '인쇄용 카드를 원하는 대로 받아요';

  @override
  String get proTeaserCardLayoutBenefit =>
      '한 장에 여러 장, 가로 용지, 일과 한 장으로 받을 수 있어요';
}
