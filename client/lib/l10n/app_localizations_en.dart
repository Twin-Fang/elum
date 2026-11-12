// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get notificationOffNoticeTitle => 'Turn on notifications?';

  @override
  String get notificationOffNoticeBody =>
      'We\'ll tell you when a routine is done';

  @override
  String get notificationOffValue => 'Off';

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
  String get creditResetFallbackMonth => '12:00 AM on the 1st of next month';

  @override
  String get creditBlockedBusy =>
      'A routine is already being made.\nYou can make a new one once it\'s done';

  @override
  String creditBlockedExhausted(String reset) {
    return 'You\'ve used all your credits this week.\nCredits refill on $reset';
  }

  @override
  String creditBlockedExhaustedMonth(String reset) {
    return 'You\'ve used all your credits this month.\nThey refill on $reset';
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
  String get imageStyleCharacterLabel => 'Cartoon';

  @override
  String get imageStyleCharacterDescription => 'A cartoon child acts it out';

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
  String get imageStyleCreditRoutineFree => 'Routine text is free';

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
      'The friend you pick joins you on the home and reward screens';

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
  String get elumiSettingsWithdrawAction => 'Delete account';

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
  String get guardiansLeaveTypeTitle => 'One more check';

  @override
  String guardiansLeaveTypeMessage(String phrase) {
    return 'Elumi, routines, and stars will all be gone.\nPlease type \'$phrase\'\nexactly as shown below';
  }

  @override
  String get guardiansLeaveTypePhrase => 'Leave';

  @override
  String get guardiansLeaveTypeAction => 'Leave';

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
  String get notificationWeeklyReportReady => 'Last week\'s report is ready';

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
  String get routineLoadingInputNeededTitle => 'Tell us what the routine is';

  @override
  String get routineLoadingEditInput => 'Write again';

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
      'Cards without a picture got a default one. You can draw an AI picture when you edit the card';

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
  String get guardianSettingsWithdrawConfirmAction => 'Delete account';

  @override
  String get guardianSettingsWithdrawFailedTitle =>
      'Couldn\'t delete the account';

  @override
  String get guardianSettingsWithdrawFailedFallback => 'Try again in a moment';

  @override
  String get guardianSettingsWithdrawAppStoreSubscriptionNotice =>
      'Your Pro subscription continues after you delete your account.\nPlease cancel it yourself\nin the App Store';

  @override
  String get guardianSettingsWithdrawGooglePlaySubscriptionNotice =>
      'Deleting your account stops the next\npayment for your Google Play Pro subscription';

  @override
  String get guardianSettingsWithdrawTypeTitle => 'One more check';

  @override
  String guardianSettingsWithdrawTypeMessage(String phrase) {
    return 'Please type \'$phrase\'\nexactly as shown below';
  }

  @override
  String get guardianSettingsWithdrawTypePhrase => 'Delete account';

  @override
  String get guardianSettingsWithdrawTypeAction => 'Delete account';

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
  String get creditCardTitleMonth => 'AI creations this month';

  @override
  String get creditCardLoading => 'Loading this week\'s AI usage';

  @override
  String get creditCardLoadingMonth => 'Loading this month\'s AI usage';

  @override
  String get creditCardLoadFailed => 'Couldn\'t load usage';

  @override
  String get creditCardRetry => 'Try again';

  @override
  String get creditGenerating => 'Making the routine';

  @override
  String get creditExhausted => 'You\'ve used all your credits this week';

  @override
  String get creditExhaustedMonth => 'You\'ve used all your credits this month';

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
      other: '$imageCost credits',
      one: '$imageCost credit',
    );
    return 'Routine text is free. Each finished card picture uses $_temp0.';
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
  String get creditMonthlyRefill =>
      'Refills at 12:00 AM on the 1st of every month.';

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
  String get myCreditTitle => 'My credits';

  @override
  String get planFreeBadge => 'FREE';

  @override
  String get myCreditHistoryButton => 'Usage history';

  @override
  String get myCreditCountUnit => '';

  @override
  String get myCreditKindPeriodicWeek => 'Weekly';

  @override
  String get myCreditKindPeriodicMonth => 'Monthly';

  @override
  String get myCreditKindBonus => 'Bonus';

  @override
  String get myCreditKindPurchased => 'Purchased';

  @override
  String get myCreditRefillWeek => 'Refills on Monday';

  @override
  String get myCreditRefillMonth => 'Refills on the 1st of next month';

  @override
  String myCreditUntilDate(int month, int day) {
    return 'Until $month/$day';
  }

  @override
  String get myCreditNoExpiry => 'No expiry';

  @override
  String get myCreditSubscribeLabel => 'When you subscribe';

  @override
  String get myCreditSubscribeBody =>
      'Draw AI pictures and send routines automatically';

  @override
  String get myCreditPackLabelFree => 'Get more credits';

  @override
  String get myCreditPackLabelPro => 'Get more credits';

  @override
  String get creditGetMore => 'Get more credits';

  @override
  String myCreditPackDiscount(int percent) {
    return '-$percent%';
  }

  @override
  String get myCreditPackPopular => 'Popular!';

  @override
  String myCreditPackBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Get $count credits',
      one: 'Get $count credit',
    );
    return '$_temp0';
  }

  @override
  String get myCreditPackNoExpiryNote => 'Purchased credits never expire';

  @override
  String get myCreditPackPriceFailed => 'Couldn\'t load credit prices';

  @override
  String myCreditPackTileLabel(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count credits',
      one: '$count credit',
    );
    return '$_temp0, $price';
  }

  @override
  String get myCreditPurchaseRecheckTitle =>
      'Your credits haven\'t arrived yet';

  @override
  String get myCreditPurchaseRecheckBody =>
      'Your payment went through. You only need to check again, not pay again';

  @override
  String get creditHistoryTitle => 'Credit history';

  @override
  String get creditMineLink => 'View my credits';

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
  String get creditHistoryFree => 'No credits used';

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
  String talkImportDone(String routineTitle, String batchim) {
    return 'Imported $routineTitle';
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
  String get cardExportOpen => 'Save for printing';

  @override
  String get cardExportFormatSection => 'How would you like it?';

  @override
  String get cardExportFormatRoutineSheet => 'One-page routine';

  @override
  String get cardExportFormatRoutineSheetCaption => 'In order on one A4 page';

  @override
  String get cardExportFormatCutCards => 'Cut-out cards';

  @override
  String get cardExportFormatCutCardsCaption => 'On A4 with cutting lines';

  @override
  String get cardExportFormatCardImages => 'One card at a time';

  @override
  String get cardExportFormatCardImagesCaption => 'One image per card';

  @override
  String get cardExportPerPageSection => 'How many cards per page?';

  @override
  String get cardExportIncludeText => 'Include card text';

  @override
  String get cardExportThemeSection => 'Card design';

  @override
  String get cardExportThemeBasic => 'Basic';

  @override
  String get cardExportThemeSimple => 'Simple';

  @override
  String get cardExportThemeInkSaver => 'Ink saver';

  @override
  String get cardExportThemeMonochrome => 'Black & white';

  @override
  String get cardExportThemeLargeText => 'Large text';

  @override
  String get planProBadge => 'Pro';

  @override
  String get cardExportProThemeLocked => 'This design is available with Pro';

  @override
  String get cardExportWatermarkNotice =>
      'Free adds an Elumi logo strip at the bottom';

  @override
  String get cardExportPreviewSection => 'Preview';

  @override
  String get cardExportMissingPicture =>
      'Cards without a picture show only the title';

  @override
  String cardExportSomePicturesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cards whose pictures couldn\'t load will use other pictures or their titles',
      one:
          '$count card whose picture couldn\'t load will use another picture or its title',
    );
    return '$_temp0';
  }

  @override
  String get cardExportActualSizeHint =>
      'When printing from another app, choose actual size';

  @override
  String get cardExportPrint => 'Print';

  @override
  String get cardExportShare => 'Send';

  @override
  String get cardExportPreparing => 'Getting your cards ready';

  @override
  String get cardExportImageFailed => 'Couldn\'t load the card picture';

  @override
  String get cardExportRenderFailed => 'Couldn\'t create the printable file';

  @override
  String get cardExportPrintFailed =>
      'This device can\'t print. Please use Send instead';

  @override
  String get cardExportNoCards => 'This routine has no cards';

  @override
  String get cardExportNoneSelected =>
      'Please choose at least one card to send';

  @override
  String get printBrandTagline => 'Every day, together | Elumi Behavior Cards';

  @override
  String get cardExportPictogramCredit =>
      'Pictures: Mulberry Symbols (CC BY-SA 4.0)';

  @override
  String get cardExportEmojiCredit => 'Pictures: Twemoji (CC BY 4.0)';

  @override
  String cardExportPerPage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '$count card',
    );
    return '$_temp0';
  }

  @override
  String get cardExportFormatRow => 'Format';

  @override
  String get cardExportLayoutSection => 'Layout';

  @override
  String get cardExportStyleSection => 'Style';

  @override
  String get cardExportOrientationRow => 'Paper orientation';

  @override
  String get cardExportOrientationSheetTitle =>
      'How should the paper be laid out?';

  @override
  String get cardExportOrientationPortrait => 'Portrait';

  @override
  String get cardExportOrientationLandscape => 'Landscape';

  @override
  String get cardExportPerPageRow => 'Per page';

  @override
  String get cardExportCardSizeRow => 'Card size';

  @override
  String get cardExportCardSizeSheetTitle => 'How big should the cards be?';

  @override
  String get cardExportCardSizeFit => 'Fill the page';

  @override
  String get cardExportCardSizeMedium => 'Medium';

  @override
  String get cardExportCardSizeSmall => 'Small';

  @override
  String get cardExportProLayoutLocked => 'This format is available with Pro';

  @override
  String get cardExportUpsellTitle => 'With Pro, save it your way';

  @override
  String get cardExportUpsellBody =>
      'Pick a one-page routine, cut-out cards, several cards per page, landscape paper, and designs';

  @override
  String get modeSwitchToPurchase => 'Only a guardian can make purchases';

  @override
  String get planBenefitAiImageStyles => 'AI draws a picture for every card';

  @override
  String get planBenefitAdsRemoved => 'Use it without ads';

  @override
  String get planBenefitWeeklyReport => 'Get a weekly report';

  @override
  String get planBenefitRoutineSchedule =>
      'Pick days and times and send every day';

  @override
  String get planBenefitRoutineMemory => 'Remember how I edit things';

  @override
  String get planBenefitGuardianVoice => 'Read cards aloud in your own voice';

  @override
  String get planBenefitFreeRoutineText => 'Routine text is free of credits';

  @override
  String get planBenefitFreeImageRegenerate =>
      'Redraw a picture you don\'t like without credits';

  @override
  String get planBenefitMoreWeeklyCredits => 'Get more credits every week';

  @override
  String get planBenefitMoreMonthlyCredits => 'Get more credits every month';

  @override
  String get planBenefitCardExportWithoutWatermark =>
      'Clean printouts with no strip at the bottom';

  @override
  String get planBenefitCardExportAllThemes => 'Choose from every print design';

  @override
  String get planBenefitCardExportAllLayouts =>
      'Print a one-page routine or cut-out cards';

  @override
  String get planKeepContentNotice =>
      'Routines and pictures you made stay even after Pro ends';

  @override
  String get planPeriodMonthly => '1 month';

  @override
  String get planPeriodYearly => '1 year';

  @override
  String get planSubscribe => 'Start subscription';

  @override
  String get planPriceLoading => 'Loading prices';

  @override
  String get planPriceFailed => 'Couldn\'t load prices';

  @override
  String get planRestore => 'Restore purchases';

  @override
  String get planTermsOfUse => 'Terms of Use';

  @override
  String get planPrivacyPolicy => 'Privacy Policy';

  @override
  String get planManageSubscription => 'Manage subscription';

  @override
  String get planLegalBillingAppStore =>
      'Payment is charged to your Apple ID account when you confirm the purchase. The subscription renews automatically at the same length and price unless you cancel at least 24 hours before the period ends, and your account is charged for the next period within 24 hours before it ends.';

  @override
  String get planLegalCancelAppStore =>
      'You can manage and cancel your subscription in Settings > Apple ID > Subscriptions on your device. After you cancel, you can use Pro until the end of the paid period.';

  @override
  String get planLegalBillingPlayStore =>
      'Payment is charged to your Google Play account when you confirm the purchase. The subscription renews automatically at the same length and price until you cancel.';

  @override
  String get planLegalCancelPlayStore =>
      'You can manage and cancel your subscription in the Google Play Store under Payments & subscriptions > Subscriptions. After you cancel, you can use Pro until the end of the paid period.';

  @override
  String planTrialDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String planTrialWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '$count week',
    );
    return '$_temp0';
  }

  @override
  String planTrialMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String planTrialYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String planStartFreeTrial(String trial) {
    return 'Start $trial free';
  }

  @override
  String get planLegalTrialAppStore =>
      'If you cancel at least 24 hours before the free trial ends, you won\'t be charged.';

  @override
  String get planLegalTrialPlayStore =>
      'If you cancel during the free trial, you won\'t be charged.';

  @override
  String get planVerifying => 'Confirming your payment';

  @override
  String get planStorePendingTitle => 'Payment approval requested';

  @override
  String get planStorePendingBody =>
      'Pro turns on once it\'s approved. You can close this screen.';

  @override
  String get planVerificationPendingTitle => 'Confirming your payment';

  @override
  String get planVerificationPendingBody =>
      'You don\'t need to pay again. We\'ll check once more when you reopen the app';

  @override
  String get planVerificationRetry => 'Check again';

  @override
  String get planActivatedStart => 'Get started';

  @override
  String get planActivatedTitle => 'Pro has started';

  @override
  String get planNotActivatedTitle => 'Pro isn\'t on yet';

  @override
  String get planNotActivatedBody =>
      'Please check your subscription status in the store';

  @override
  String get planAlreadyProTitle => 'You\'re using Pro';

  @override
  String get planPurchaseFailedTitle => 'Couldn\'t complete the payment';

  @override
  String get planVerifyFailedTitle =>
      'Couldn\'t link the payment to this account';

  @override
  String get planAccountFailedTitle => 'Couldn\'t check your account';

  @override
  String get planFailedFallback => 'Please try again in a moment';

  @override
  String get planRestoreDone => 'Pro is back';

  @override
  String get planRestoreNothing => 'There\'s no subscription to restore';

  @override
  String get planRestoreFailedTitle => 'Couldn\'t restore your purchase';

  @override
  String get planRestoring => 'Checking your purchases';

  @override
  String get planManageFailed => 'Couldn\'t open subscription management';

  @override
  String get planLinkFailed => 'Couldn\'t open the link';

  @override
  String get planSettingsLabel => 'My plan';

  @override
  String get planStatusFree => 'Free';

  @override
  String get planStatusPro => 'Pro';

  @override
  String planStatusRenewing(String date) {
    return 'Pro, renews on $date';
  }

  @override
  String planStatusUntil(String date) {
    return 'Pro, until $date';
  }

  @override
  String planStatusCancelScheduled(String date) {
    return 'Pro, ends on $date';
  }

  @override
  String get planStatusGracePeriod => 'Pro, payment needs checking';

  @override
  String planStatusTrial(int days) {
    return 'Pro trial, $days days left';
  }

  @override
  String get planStatusTrialLastDay => 'Pro trial, ends today';

  @override
  String get planStatusGift => 'Pro gift';

  @override
  String planStatusGiftUntil(String date) {
    return 'Pro gift, until $date';
  }

  @override
  String planStatusRenewingFooter(String date) {
    return 'Renews on $date';
  }

  @override
  String planStatusUntilFooter(String date) {
    return 'You can use it until $date';
  }

  @override
  String planStatusCancelScheduledFooter(String date) {
    return 'Ends on $date';
  }

  @override
  String get planStatusGracePeriodFooter => 'Please check your payment method';

  @override
  String get planLearnPro => 'Learn about Pro';

  @override
  String get weeklyReportTitle => 'Weekly report';

  @override
  String weeklyReportWeekRange(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth/$startDay - $endMonth/$endDay';
  }

  @override
  String weeklyReportThisWeekRange(String range) {
    return 'This week · $range';
  }

  @override
  String get weeklyReportPreviousWeek => 'View last week';

  @override
  String get weeklyReportNextWeek => 'View next week';

  @override
  String get weeklyReportCompletionLabel => 'Routines completed';

  @override
  String weeklyReportPercent(int percent) {
    return '$percent%';
  }

  @override
  String weeklyReportCompletionSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: 'Finished $completed of $sent routines sent',
      one: 'Finished $completed of $sent routine sent',
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
  String get weeklyReportStars => 'Stars earned';

  @override
  String get weeklyReportRewards => 'Routines that reached a reward';

  @override
  String get weeklyReportStreak => 'Days finished in a row';

  @override
  String weeklyReportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '$count',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRoutinesSection => 'By routine';

  @override
  String weeklyReportRoutineValue(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: 'Finished $completed of $sent times',
      one: 'Finished $completed of $sent time',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRemainingSection => 'Cards often left undone';

  @override
  String weeklyReportRemainingLabel(String routine, String step) {
    return '$routine · $step';
  }

  @override
  String weeklyReportTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '$count time',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportEmptyTitle => 'No routines were sent this week';

  @override
  String get weeklyReportEmptyBody =>
      'When you send routines, Elumi\'s finished records gather here';

  @override
  String get weeklyReportLoadFailed => 'Couldn\'t load the weekly report';

  @override
  String get weeklyReportNotIncluded =>
      'The weekly report is available with Pro';

  @override
  String get weeklyReportShareImage => 'Image';

  @override
  String get weeklyReportSharePdf => 'PDF';

  @override
  String get weeklyReportShareFailed => 'Couldn\'t create the page to send';

  @override
  String weeklyReportShareTitle(String name) {
    return '$name\'s week';
  }

  @override
  String get weeklyReportShareNote =>
      'Counted from the completion records in the Elumi app';

  @override
  String get weeklyReportRecordSection => 'This week\'s record';

  @override
  String get weeklyReportDonutLabel => 'Completion rate';

  @override
  String weeklyReportDonutSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$completed of $sent routines done',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDonutSemantics(int percent, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other:
          'Completion rate $percent percent, $completed of $sent routines done',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportDaysSection => 'Daily record';

  @override
  String weeklyReportDayBarSemantics(String weekday, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$weekday: $completed of $sent routines done',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDayBarEmptySemantics(String weekday) {
    return '$weekday: no routines sent';
  }

  @override
  String get weeklyReportTrendSection => 'Compared with past weeks';

  @override
  String weeklyReportTrendWeekLabel(int month, int day) {
    return '$month/$day';
  }

  @override
  String weeklyReportTrendPointSemantics(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Week of $month/$day: $count routines done',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportInsightHighlightTitle => 'What went well';

  @override
  String weeklyReportInsightHighlightFirst(String routine, String batchim) {
    return 'Finished $routine all the way for the first time this week';
  }

  @override
  String weeklyReportInsightHighlightEvery(
    String routine,
    String batchim,
    int count,
  ) {
    return 'Finished $routine all the way every one of $count times';
  }

  @override
  String weeklyReportInsightHighlightStreak(int days) {
    return 'Finished routines $days days in a row';
  }

  @override
  String weeklyReportInsightHighlightHint(String name) {
    return 'Tell $name today';
  }

  @override
  String get weeklyReportInsightStuckTitle => 'Where they often stop';

  @override
  String weeklyReportInsightStuckLine(
    String routine,
    String step,
    int sent,
    int remained,
  ) {
    return 'Stopped at $step in $routine $remained of $sent times';
  }

  @override
  String get weeklyReportInsightStuckShorten =>
      'You could shorten the card text or split it into two';

  @override
  String get weeklyReportInsightStuckAddMedia =>
      'You could add a voice or a photo';

  @override
  String weeklyReportInsightStuckFix(String step) {
    return 'Edit the $step card';
  }

  @override
  String get weeklyReportInsightStuckFixFailed =>
      'Couldn\'t open the routine to edit';

  @override
  String get weeklyReportInsightTrendTitle => 'Changes from last week';

  @override
  String weeklyReportInsightTrendUp(int before, int after) {
    return 'Finished routines went up from $before to $after';
  }

  @override
  String weeklyReportInsightTrendDown(int before, int after) {
    return 'Finished routines went from $before to $after';
  }

  @override
  String weeklyReportInsightTrendSame(int after) {
    return 'Finished $after again, same as last week';
  }

  @override
  String weeklyReportInsightTrendBarPrevious(int count) {
    return 'Last week $count';
  }

  @override
  String weeklyReportInsightTrendBarCurrent(int count) {
    return 'This week $count';
  }

  @override
  String get weeklyReportInsightDurationTitle => 'Time taken';

  @override
  String weeklyReportInsightDurationLine(
    String routine,
    int before,
    int after,
  ) {
    return 'Time for $routine went from $before min to $after min';
  }

  @override
  String get weeklyReportInsightSlowestTitle => 'Card they stayed on longest';

  @override
  String weeklyReportInsightSlowestLine(
    String routine,
    String step,
    int minutes,
  ) {
    return 'Stayed $minutes min on average at $step in $routine';
  }

  @override
  String get weeklyReportStatCompleted => 'Routines finished';

  @override
  String get weeklyReportStatRemaining => 'Cards left';

  @override
  String weeklyReportRoutineRatio(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$completed of $sent times',
      one: '$completed of $sent time',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportSave => 'Save report';

  @override
  String get weeklyReportSaveSheetTitle =>
      'How would you like to save the report?';

  @override
  String get weeklyReportPastReports => 'View past reports';

  @override
  String get weeklyReportPastSheetTitle => 'Past reports';

  @override
  String weeklyReportPastWeekValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Finished $count routines',
      one: 'Finished $count routine',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportPastEmpty => 'No past reports yet';

  @override
  String get weeklyReportPastLoadFailed => 'Couldn\'t load past reports';

  @override
  String get weeklyReportFreePreviewNote => 'Your first report is on us';

  @override
  String get routineScheduleRowOff => 'Set days and time';

  @override
  String get routineScheduleRowLabel => 'Repeat days and time';

  @override
  String routineScheduleSummary(String days, String time) {
    return '$days $time';
  }

  @override
  String get routineScheduleEveryDay => 'Every day';

  @override
  String get routineScheduleWeekdaysOnly => 'Weekdays';

  @override
  String get routineScheduleWeekendOnly => 'Weekends';

  @override
  String get routineScheduleDaySeparator => '·';

  @override
  String get routineSchedulePaused => 'Paused because Pro ended';

  @override
  String get routineSchedulePausedNote =>
      'Repeating paused because Pro ended. Your days and time are still saved';

  @override
  String get routineScheduleSheetTitle => 'When should it happen?';

  @override
  String get routineScheduleSheetBody =>
      'On each day you pick, this routine goes to today\'s routines';

  @override
  String get routineScheduleDaysLabel => 'Days';

  @override
  String get routineScheduleTimeLabel => 'Time';

  @override
  String get routineScheduleNotifyElumi =>
      'Notify Elumi\'s device at that time';

  @override
  String get routineScheduleElumiNotificationOff =>
      'Notifications are off on Elumi\'s device';

  @override
  String get routineScheduleElumiNotificationOffHint =>
      'Turn on Elumi notifications in the settings of Elumi\'s device';

  @override
  String get routineScheduleElumiNoDevice =>
      'Once you connect Elumi\'s device, it gets a notification at that time';

  @override
  String get routineScheduleSave => 'Save';

  @override
  String get routineScheduleTurnOff => 'Turn off repeat';

  @override
  String get routineScheduleSavedToast => 'Saved the days and time';

  @override
  String get routineScheduleTurnedOffToast => 'Turned off repeat';

  @override
  String get routineScheduleSaveFailedTitle => 'Couldn\'t save';

  @override
  String get routineScheduleSaveFailedFallback =>
      'Please try again in a moment';

  @override
  String get routineSchedulePickDayHint => 'Please choose at least one day';

  @override
  String get routineScheduleProNote =>
      'Repeating routines can be saved with Pro';

  @override
  String get weeklyPlanEntry => 'Weekly plan';

  @override
  String get weeklyPlanTitle => 'Weekly plan';

  @override
  String weeklyPlanDayTitle(String weekday) {
    return '$weekday';
  }

  @override
  String get weeklyPlanToday => 'Today';

  @override
  String get weeklyPlanEmptyDay => 'No routines planned';

  @override
  String get weeklyPlanEmptyTitle => 'No routines have days set yet';

  @override
  String get weeklyPlanEmptyBody =>
      'In Manage routines, tap a routine and set its days and time';

  @override
  String get weeklyPlanLoadFailed => 'Couldn\'t load the weekly plan';

  @override
  String get weeklyPlanNotifyOff => 'No notification';

  @override
  String get weeklyPlanMetaSeparator => ' · ';

  @override
  String get guardianVoiceRecordAction => 'Record in my voice';

  @override
  String get guardianVoiceRecordHint =>
      'When a card is tapped, this voice plays';

  @override
  String guardianVoiceRecording(int seconds) {
    return 'Recording ${seconds}s';
  }

  @override
  String guardianVoiceRecordingLimit(int seconds) {
    return 'Records up to ${seconds}s';
  }

  @override
  String get guardianVoiceStop => 'Stop';

  @override
  String get guardianVoiceSaving => 'Saving your recording';

  @override
  String get guardianVoiceSaved => 'Recorded';

  @override
  String get guardianVoicePlay => 'Listen';

  @override
  String get guardianVoiceRerecord => 'Record again';

  @override
  String get guardianVoiceDelete => 'Delete';

  @override
  String get guardianVoiceDeleteConfirmTitle => 'Delete the recording?';

  @override
  String get guardianVoiceDeleteConfirmMessage =>
      'If you delete it, the default voice reads the card';

  @override
  String get guardianVoicePlanEnded => 'Reading in the default voice';

  @override
  String get guardianVoiceMicDeniedTitle => 'The microphone is off';

  @override
  String get guardianVoiceMicDeniedBody =>
      'Until you turn it on, the default voice reads the card';

  @override
  String get guardianVoiceOpenSettings => 'Open settings';

  @override
  String get guardianVoiceFailedTitle => 'Couldn\'t save the recording';

  @override
  String get guardianVoiceRetry => 'Try again';

  @override
  String get guardianVoiceTooShort => 'That\'s too short. Speak, then tap Stop';

  @override
  String get guardianVoiceRecordFailed => 'Couldn\'t record. Please try again';

  @override
  String get guardianVoiceTooLarge =>
      'The recording is too large. Please record a shorter one';

  @override
  String get guardianVoicePlayFailed => 'Couldn\'t play the recording';

  @override
  String get guardianVoiceDeleteFailed => 'Couldn\'t delete the recording';

  @override
  String get guardianVoiceRecordChip => 'Record';

  @override
  String get guardianVoicePlanEndedHint =>
      'Your recording is kept even after Pro ends';

  @override
  String get guardianSettingsRoutineMemory => 'AI memory';

  @override
  String memoryHeroTitle(String name) {
    return '$name AI memory';
  }

  @override
  String get memoryHeroBody =>
      'It remembers how you edit and makes your next routines that way. Only you can see it';

  @override
  String get memoryStatApplied => 'In use';

  @override
  String get memoryStatWatching => 'Watching';

  @override
  String get memoryStatEdits => 'Edit history';

  @override
  String get memoryListAppliedHeader => 'Rules in use';

  @override
  String get memoryListAppliedHint => 'Used for new routines';

  @override
  String get memoryListWatchingHeader => 'Rules being watched';

  @override
  String get memoryListWatchingHint => 'Applied once the dots fill up';

  @override
  String get memoryListEditsHeader => 'Edited and sent';

  @override
  String memoryRuleByAi(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count routines',
      one: '$count routine',
    );
    return 'Found by AI, $_temp0';
  }

  @override
  String get memoryRuleByMe => 'Written by me';

  @override
  String memoryEditCards(int before, int after) {
    return '$before → $after cards';
  }

  @override
  String memoryEditTexts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texts',
      one: '$count text',
    );
    return '$_temp0';
  }

  @override
  String get memoryAddRule => '+ Write a rule';

  @override
  String get memoryAutoFind => 'Find from my edits automatically';

  @override
  String memoryAutoFindNote(int count) {
    return 'Applied when the same edit repeats in $count routines';
  }

  @override
  String get memoryEmptyTitle =>
      'When you edit and send routines, they gather here';

  @override
  String get memoryEmptyEdits => 'No edited routines have been sent yet';

  @override
  String get memoryTypeWord => 'Replace a word';

  @override
  String get memoryTypeSplit => 'Split a card';

  @override
  String get memoryTypeMerge => 'Merge cards';

  @override
  String get memoryTypeAdd => 'Add a card';

  @override
  String get memoryTypeRemove => 'Remove a card';

  @override
  String get memoryTypeManual => 'Rule I wrote';

  @override
  String get memoryApplyNow => 'Apply now';

  @override
  String get memoryRuleDelete => 'Delete';

  @override
  String get memoryRuleEdit => 'Edit';

  @override
  String memoryEvidenceLine(String routine, int month, int day) {
    return '$routine, $month/$day';
  }

  @override
  String get memoryMenuLabel => 'Menu';

  @override
  String get memoryMenuExport => 'Export as a file';

  @override
  String get memoryMenuClear => 'Clear all memory';

  @override
  String get memoryExportFailed => 'Couldn\'t export your memory';

  @override
  String get memoryObsTitle => 'AI memory';

  @override
  String get memoryObsWord => 'You changed a word like this';

  @override
  String get memoryObsSplit => 'You split a card';

  @override
  String get memoryObsMerge => 'You merged cards';

  @override
  String get memoryObsAdd => 'You added a card';

  @override
  String get memoryObsRemove => 'You removed a card';

  @override
  String get memoryObsManual => 'You edited it like this';

  @override
  String memoryObsAsk(String phrase) {
    return '$phrase. Should we do this in the next routine too?';
  }

  @override
  String get memoryObsAlways => 'Always do this';

  @override
  String get memoryObsOnce => 'Just this time';

  @override
  String get memoryObsDone => 'From the next routine, we\'ll make it this way';

  @override
  String memoryObsMore(int count) {
    return 'See $count more in AI memory';
  }

  @override
  String memoryAppliedPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AI memory rules applied',
      one: '$count AI memory rule applied',
    );
    return '$_temp0';
  }

  @override
  String get routineMemoryAddSheetTitle => 'Add a note';

  @override
  String get routineMemoryEditSheetTitle => 'Edit note';

  @override
  String get routineMemoryLineHint =>
      'e.g. Write \'wipe hands\' instead of \'wash up\'';

  @override
  String get routineMemorySave => 'Save';

  @override
  String get routineMemoryDeleteLine => 'Delete this line';

  @override
  String get routineMemoryClearConfirmTitle => 'Delete all notes?';

  @override
  String get routineMemoryClearConfirmMessage =>
      'Deleted notes can\'t be brought back.';

  @override
  String get routineMemoryClearConfirmAction => 'Delete all';

  @override
  String get routineMemoryLoadFailed => 'Couldn\'t load notes';

  @override
  String get routineMemorySaveFailedTitle => 'Couldn\'t save the note';

  @override
  String get routineMemorySaveFailedFallback => 'Please try again in a moment.';

  @override
  String get proTeaserSampleLabel => 'Example screen';

  @override
  String get proOnlyNoticeTitle => 'This feature is available with Pro';

  @override
  String get proTeaserWeeklyReportBenefit =>
      'Send a one-page summary of the routines done over the week';

  @override
  String get proTeaserRoutineMemoryBenefit =>
      'Remember how you edit so the next routines fit better';

  @override
  String get proTeaserCardThemeBenefit =>
      'Get printable cards in several designs';

  @override
  String get proTeaserWeeklyPlanBenefit =>
      'No need to send the routine again every morning';

  @override
  String get proTeaserSampleRoutineMorning => 'Getting ready in the morning';

  @override
  String get proTeaserSampleRoutineBrush => 'Brush teeth';

  @override
  String get proTeaserSampleRoutineBag => 'Pack your bag';

  @override
  String get proTeaserSampleStepSocks => 'Put on socks';

  @override
  String get proTeaserSampleMemoryShort => 'Write card text short, in one line';

  @override
  String get proTeaserSampleMemoryOrder => 'Start getting dressed with socks';

  @override
  String get proTeaserSampleMemoryReward => 'Choose stickers as the reward';

  @override
  String get cardRegenerateChip => 'Redraw';

  @override
  String get cardRegenerateSheetTitle => 'Redraw the picture?';

  @override
  String cardRegenerateCostProFree(int count) {
    return 'No credits, $count left today';
  }

  @override
  String get cardRegenerateCostFree => 'Doesn\'t use credits';

  @override
  String cardRegenerateCostCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count credits',
      one: '$count credit',
    );
    return '$_temp0';
  }

  @override
  String creditCostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '$count',
    );
    return '$_temp0';
  }

  @override
  String get cardRegenerateCostUnknown => 'Uses credits';

  @override
  String get cardRegenerateConfirm => 'Redraw';

  @override
  String get cardRegenerateInProgress => 'Redrawing the picture';

  @override
  String get cardRegenerateFailedTitle => 'Couldn\'t redraw the picture';

  @override
  String get cardFirstDrawChip => 'Draw AI picture';

  @override
  String get cardRedrawProChip => 'Redraw with Pro';

  @override
  String get cardFirstDrawProChip => 'Draw AI picture with Pro';

  @override
  String get cardFirstDrawSheetTitle => 'Draw an AI picture?';

  @override
  String get cardRedrawSheetBody =>
      'Write or pick what you\'d like to change. Leave it blank to redraw as is';

  @override
  String get cardFirstDrawSheetBody =>
      'Write or pick what you\'d like. You can choose after seeing the new picture';

  @override
  String get cardRedrawRequestLabel => 'What to change';

  @override
  String get cardRedrawRequestHint => 'e.g. Make the umbrella blue';

  @override
  String get cardRedrawHintSimpler => 'Simpler';

  @override
  String get cardRedrawHintNoBackground => 'No background';

  @override
  String get cardRedrawHintNoPeople => 'No people';

  @override
  String get cardRedrawHintBrighter => 'Brighter';

  @override
  String get cardFirstDrawConfirm => 'Draw';

  @override
  String get cardFirstDrawInProgress => 'Drawing the picture';

  @override
  String get cardFirstDrawFailedTitle => 'Couldn\'t draw the AI picture';

  @override
  String get cardRedrawFailedFallback =>
      'Want to try again? No credits were used';

  @override
  String get cardCandidateSheetTitle => 'Which picture would you like?';

  @override
  String get cardCandidateSheetBody =>
      'Only the picture you choose is shown to Elumi';

  @override
  String get cardCandidateCurrentLabel => 'Current';

  @override
  String get cardCandidateNewLabel => 'New';

  @override
  String get cardCandidateSelectButton => 'Use this picture';

  @override
  String get cardCandidateAppliedToast => 'Changed to the new picture';

  @override
  String get cardCandidateLoadFailedTitle => 'Couldn\'t load the new picture';

  @override
  String get cardCandidateApplyFailedTitle =>
      'Couldn\'t change to the new picture';

  @override
  String get planHeroHeadline => 'Cards made just for Elumi';

  @override
  String get planHeroSubline =>
      'Make the same routine with Pro and it looks like this';

  @override
  String get planHeroFreeTag => 'Free emoji';

  @override
  String get planHeroProTag => 'Pro cartoon picture';

  @override
  String get planHeroCompareSemantics =>
      'Free gives emoji cards, Pro gives cartoon picture cards';

  @override
  String planBenefitGroupCards(String elumiName) {
    return 'Card pictures made just for $elumiName';
  }

  @override
  String get planBenefitGroupRoutines => 'Routines send themselves';

  @override
  String get planBenefitGroupWeek => 'We sum up the week for you';

  @override
  String get planBenefitGroupExtra => 'A little more room';

  @override
  String planYearlySaving(int percent) {
    return 'Save $percent%';
  }

  @override
  String get planRenewsYearly => 'Renews every year';

  @override
  String get planRenewsMonthly => 'Renews every month';

  @override
  String planMonthlyEquivalentRenewsYearly(String price) {
    return 'About $price a month · Renews every year';
  }

  @override
  String planPriceUnit(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'yearly': '/year',
      'other': '/month',
    });
    return '$_temp0';
  }

  @override
  String planCtaTrialNoticeAppStore(String trial, String price, String unit) {
    return 'After $trial, $price$unit is charged automatically. Cancel at least 24 hours before it ends to avoid being charged';
  }

  @override
  String planCtaTrialNoticePlayStore(String trial, String price, String unit) {
    return 'After $trial, $price$unit is charged automatically. Cancel during the trial to avoid being charged';
  }

  @override
  String planCtaRenewNotice(String price, String unit) {
    return 'Renews automatically at $price$unit. Cancel anytime';
  }

  @override
  String planTryFreeTrial(String trial) {
    return 'Try $trial free';
  }

  @override
  String get planSeeAllBenefits => 'See all Pro benefits';

  @override
  String get planTierGift => 'Gift';

  @override
  String get proTeaserWeeklyPlanTitle =>
      'Set the days and time, and that day\'s routine is ready';

  @override
  String get proTeaserWeeklyReportTitle => 'Get the whole week on one page';

  @override
  String get proTeaserRoutineMemoryTitle => 'Remember what works for Elumi';

  @override
  String get proTeaserCardThemeTitle => 'Get prettier printable cards';

  @override
  String get proTeaserCardLayoutTitle => 'Get printable cards your way';

  @override
  String get proTeaserCardLayoutBenefit =>
      'Choose several cards per page, landscape paper, or a one-page routine';

  @override
  String get homeSuggestionDismissLabel => 'No thanks';

  @override
  String get homeSuggestionAutoSendTitle => 'Send it automatically every day?';

  @override
  String homeSuggestionAutoSendBody(String routine, String batchim, int days) {
    return 'You\'ve sent $routine $days days in a row';
  }

  @override
  String get homeSuggestionAutoSendAction => 'Set up';

  @override
  String get homeSuggestionTalkShareTitle => 'Share it in Stories?';

  @override
  String homeSuggestionTalkShareBody(String routine, String batchim) {
    return 'Other guardians can use $routine too';
  }

  @override
  String get homeSuggestionTalkShareAction => 'Share';

  @override
  String get homeSuggestionCreateMoreTitle => 'Make another routine?';

  @override
  String get homeSuggestionCreateMoreBody =>
      'How about one for the evening or bedtime?';

  @override
  String get homeSuggestionCreateMoreAction => 'Create';

  @override
  String get cardSplitChip => 'Make this card easier';

  @override
  String get cardSplitLoading => 'Splitting it into easier steps';

  @override
  String get cardSplitSheetTitle => 'Split it like this?';

  @override
  String cardSplitSheetDescription(String title, int count) {
    return 'We split “$title” into $count smaller steps';
  }

  @override
  String get cardSplitAlreadyShortDescription =>
      'It is already one action, so we left it as is';

  @override
  String get cardSplitDefaultPictureNote =>
      'Cards get the default picture. You can change it later';

  @override
  String get cardSplitKeepButton => 'Keep as is';

  @override
  String get cardSplitApplyButton => 'Split like this';

  @override
  String get cardSplitAlreadyShort => 'It\'s already short enough';

  @override
  String get cardSplitFailedFallback =>
      'We couldn\'t split the card. Please try again in a moment';

  @override
  String get cardSplitRetry => 'Try again';

  @override
  String cardSplitDoneToast(int count) {
    return 'Split the card into $count';
  }

  @override
  String get planBenefitCardSplit => 'Splits one card into smaller ones';
}
