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
    return 'You\'ve used all your credits this week.\nYou can make more from $reset';
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
      'Checking your credits is taking a while.\nCheck settings in a moment';

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
  String commonRetryWithCode(String code) {
    return 'Try again ($code)';
  }

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
  String consentChipRequired(String label) {
    return '[Required] $label';
  }

  @override
  String consentChipOptional(String label) {
    return '[Optional] $label';
  }

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
  String get agentChickLabel => 'Chick';

  @override
  String get imageStyleCartoonLabel => 'Cartoon';

  @override
  String get imageStyleCartoonDescription => 'Pictures with characters';

  @override
  String get imageStyleRealisticLabel => 'Realistic';

  @override
  String get imageStyleRealisticDescription =>
      'Looks like photos of real things';

  @override
  String get imageStylePhotoOnlyLabel => 'My own photos';

  @override
  String get imageStylePhotoOnlyDescription =>
      'Simple picture symbols are used';

  @override
  String get imageStyleCreditLabel => 'Credits';

  @override
  String imageStyleCreditRoutine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Routine $count',
    );
    return '$_temp0';
  }

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
  String get pinSaveFailedFallback => 'Check again in settings';

  @override
  String get elumiSettingsTitle => 'Settings';

  @override
  String get elumiSettingsHapticLabel => 'Vibrate on card check';

  @override
  String get elumiSettingsPraiseSoundLabel => 'Praise sound on card check';

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
  String get inviteCodeRetryChip => 'Make a new invite code';

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
      'The code is on a co-guardian\'s device,\nin Settings → Co-guardians';

  @override
  String get inviteEnterDescriptionPath => 'Settings → Co-guardians';

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
  String get guardianHomeSettings => 'Settings';

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
  String get draftRoutinesRewardUnset => 'Not set';

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
  String get guardianSettingsWithdrawFailedTitle =>
      'Couldn\'t delete the account';

  @override
  String get guardianSettingsWithdrawFailedFallback => 'Try again in a moment';

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
  String get cardPhotoSourcePrivacy =>
      'Don\'t show faces or personal information in the photo';

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
  String get routineSuggestLoadFailed =>
      'Couldn\'t load suggestions · Try again';

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
      'Once the cards are ready, it stays in drafts\nYou can continue from settings';

  @override
  String get routineLeaveDraftTitle => 'Leave it as a draft?';

  @override
  String get routineLeaveDraftMessage =>
      'You can continue from\nDrafts in settings';

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
  String get installationRetryMessage =>
      'Could not check sign-in information on this device. Please try again.';

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
  String get guardianSideNavCaption => 'Guardian mode';

  @override
  String get guardianSideNavChildScreen => 'Elumi mode';

  @override
  String get guardianTalkComingSoonTitle => 'Community is coming';

  @override
  String get guardianTalkComingSoonBody =>
      'A place to share tips with other guardians\nopens soon';

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
  String routineLibrarySent(String title) {
    return 'Sent $title for today';
  }

  @override
  String onboardingExampleTitle(String name, String batchim) {
    return 'Which routines would you like\nto start with $name?';
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
  String get routineTileExampleBadge => 'Example';

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
  String get routineGroupNameHint => 'Bundle name (e.g. Morning)';

  @override
  String get routineGroupNewTitle => 'New bundle';

  @override
  String routineGroupAddTitle(String name) {
    return 'Add to $name';
  }

  @override
  String get routineGroupPickHintNew =>
      'Tap routines in the order to show them (2 or more)';

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
    return '$count routines · shown in this order';
  }

  @override
  String get routineGroupSheetAdd => 'Add routines';

  @override
  String routineGroupSheetRemove(String title) {
    return 'Remove $title from bundle';
  }

  @override
  String get routineGroupSheetDragHint => 'Drag the handle to reorder';

  @override
  String get routineGroupCreated => 'Bundle created';

  @override
  String get routineGroupAdded => 'Added to bundle';

  @override
  String get routineGroupRemovedOne => 'Removed from bundle';

  @override
  String get routineGroupUngrouped => 'Bundle ungrouped';

  @override
  String get routineGroupUngroupedLastOne =>
      'Only one routine left, so the bundle was ungrouped';

  @override
  String get routineGroupReordered => 'Order changed';

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
}
