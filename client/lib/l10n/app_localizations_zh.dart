// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get notificationOffNoticeTitle => '要开启通知吗？';

  @override
  String get notificationOffNoticeBody => '完成日程后会通知你';

  @override
  String get notificationOffValue => '已关闭';

  @override
  String get appTitle => 'elum';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonNext => '下一步';

  @override
  String get commonRetry => '重试';

  @override
  String dateYearMonthDay(int year, int month, int day) {
    return '$year年$month月$day日';
  }

  @override
  String dateMonthDaySince(int month, int day) {
    return '$month月$day日起';
  }

  @override
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'mon': '周一',
      'tue': '周二',
      'wed': '周三',
      'thu': '周四',
      'fri': '周五',
      'sat': '周六',
      'sun': '周日',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String creditResetAt(int month, int day, String weekday, int hour) {
    return '$month月$day日($weekday) $hour点';
  }

  @override
  String creditResetAtMinute(
    int month,
    int day,
    String weekday,
    int hour,
    int minute,
  ) {
    return '$month月$day日($weekday) $hour点$minute分';
  }

  @override
  String get creditResetFallback => '下周一0点';

  @override
  String get creditResetFallbackMonth => '下个月1日0点';

  @override
  String get creditBlockedBusy => '已经在制作日常了。\n做完后就能制作新的日常';

  @override
  String creditReceivedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '获得了$count个积分',
    );
    return '$_temp0';
  }

  @override
  String get adRewardPreparing => '正在准备广告';

  @override
  String get adRewardConfirming => '正在确认积分';

  @override
  String get adRewardLoadFailed => '现在无法加载广告。\n请稍后再试';

  @override
  String get adRewardNotWatched => '看完广告才能获得积分。\n请从头再来一次';

  @override
  String get adRewardSlow => '积分确认比较慢。\n不用再看一次广告。请在 我的信息 → 我的积分 中查看';

  @override
  String get adRewardDailyLimit => '今天通过广告能获得的积分已经全部领取了。\n请明天再来';

  @override
  String get adRewardCheckAccount => '现在无法通过广告获得积分。\n请检查账号状态';

  @override
  String get adRewardUnavailable => '现在无法通过广告获得积分。';

  @override
  String get adRewardUnavailableRetry => '现在无法通过广告获得积分。\n请稍后再试';

  @override
  String get adRewardFailed => '没能获得积分。\n请稍后再试';

  @override
  String get commonPopupClose => '关闭弹窗';

  @override
  String get commonBack => '返回';

  @override
  String get commonScreenNotFound => '找不到这个页面';

  @override
  String get commonRetryLater => '请稍后再试';

  @override
  String get sentenceStop => '。';

  @override
  String get failureHintOffline => '请检查网络连接';

  @override
  String get failureHintTimeout => '连接有点慢。请稍后再试';

  @override
  String get failureHintBadCertificate => '这个连接不安全。请换一个网络试试';

  @override
  String coachStepLabel(int index, int total, String message) {
    return '提示 $index/$total。$message';
  }

  @override
  String get commonAd => '广告';

  @override
  String get commonAppInfo => '应用信息';

  @override
  String get coachCloseHint => '关闭提示';

  @override
  String get coachNextHint => '下一条提示';

  @override
  String get coachTapToClose => '点一下屏幕就会关闭';

  @override
  String get coachTapToNext => '点一下屏幕进入下一步';

  @override
  String get loginSceneEyebrow => '今天的一天，';

  @override
  String get loginSceneTitle => '一步一步一起来';

  @override
  String get appStatusStoreOpenFailedTitle => '没能打开应用商店';

  @override
  String get appStatusStoreOpenFailedFallback => '请在应用商店找到elum并更新';

  @override
  String get appStatusMaintenanceTitle => '正在维护中';

  @override
  String get appStatusMaintenanceBody => '维护结束后就能继续使用。\n请稍后再来看看';

  @override
  String get appStatusRecheck => '再次确认';

  @override
  String get appStatusUpdateTitle => '现在更新，\n体验全新的elum吧！';

  @override
  String get appStatusUpdated => '已经更新了';

  @override
  String get appStatusGoUpdate => '去更新';

  @override
  String routineForeignCreator(String name, String batchim) {
    return '$name制作的日常';
  }

  @override
  String get routineForeignCreatorUnknown => '其他监护人制作的日常';

  @override
  String get routineDefaultTitle => '今天的日常';

  @override
  String get rewardPresetSnack => '喜欢的零食';

  @override
  String get rewardPresetVideo => '看10分钟视频';

  @override
  String get rewardPresetPlay => '喜欢的游戏';

  @override
  String get rewardPresetWalk => '散步';

  @override
  String get rewardPresetCustom => '自己填写';

  @override
  String get roleGuardianWord => '监护人';

  @override
  String get roleElumiWord => 'Elumi';

  @override
  String get roleLabelSuffix => '使用';

  @override
  String get roleGuardianDescription => '制作并管理日常';

  @override
  String get roleElumiDescription => '完成日常';

  @override
  String get roleSelectTitle => '这台设备\n由谁使用？';

  @override
  String get roleSelectDescription => '分为监护人模式和Elumi模式';

  @override
  String get loginKakaoButton => '用Kakao登录';

  @override
  String get loginNaverButton => '用Naver登录';

  @override
  String get loginAppleButton => '用Apple登录';

  @override
  String get loginConnecting => '正在连接';

  @override
  String get loginLastUsed => '最近登录';

  @override
  String get loginDuplicateTitle => '这个账号已经注册过了';

  @override
  String get loginDuplicateFallback => '请用第一次使用的方式登录';

  @override
  String get loginOfflineTitle => '请检查网络连接';

  @override
  String get loginOfflineFallback => '连上网络后请再试一次';

  @override
  String get loginFailedTitle => '没能登录';

  @override
  String get loginFailedFallback => '请稍后再试';

  @override
  String get consentTitle => '请同意条款';

  @override
  String get consentLoading => '正在加载条款';

  @override
  String get consentSaving => '正在保存';

  @override
  String get consentSaveFailed => '没能保存同意内容。请再试一次';

  @override
  String get consentDescriptionReady => '点一下项目就能查看详细内容';

  @override
  String get consentDescriptionNeeded => '使用服务需要同意条款';

  @override
  String get consentAllAgree => '同意全部服务条款';

  @override
  String get consentRequiredTag => '必选';

  @override
  String get consentOptionalTag => '可选';

  @override
  String consentDocumentMeta(String label, String version) {
    return '$label · 版本 $version';
  }

  @override
  String get consentListTitle => '条款及隐私政策';

  @override
  String get consentGroupRequired => '必选项目';

  @override
  String get consentGroupOptional => '可选项目';

  @override
  String get commonElumiName => 'Elumi';

  @override
  String get characterCatLabel => '猫咪';

  @override
  String get characterCatName => 'Ruru';

  @override
  String get characterFoxLabel => '狐狸';

  @override
  String get characterFoxName => 'Popo';

  @override
  String get imageStyleEmojiLabel => '表情符号图';

  @override
  String get imageStyleEmojiDescription => '用可爱的表情符号展示物品';

  @override
  String get imageStyleSymbolLabel => '图形符号';

  @override
  String get imageStyleSymbolDescription => '用线条画展示动作';

  @override
  String get imageStyleCharacterLabel => '漫画图';

  @override
  String get imageStyleCharacterDescription => '漫画人物亲自做给你看';

  @override
  String get imageStyleRealisticLabel => '写实图';

  @override
  String get imageStyleRealisticDescription => '看起来像真实的物品';

  @override
  String get imageStyleCreditLabel => '积分';

  @override
  String imageStyleCreditRoutine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每个日常$count个',
    );
    return '$_temp0';
  }

  @override
  String get imageStyleCreditRoutineFree => '日常文字不用积分';

  @override
  String imageStyleCreditImage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每张图片$count个',
    );
    return '$_temp0';
  }

  @override
  String get goalStepByStep => '按顺序理解要做的事';

  @override
  String get goalPrepareItems => '自己准备需要的东西';

  @override
  String get goalPrepareNew => '提前为新情况做准备';

  @override
  String get goalIndependent => '积累自己坚持做完的经验';

  @override
  String onboardingCharacterTitle(String name, String batchim) {
    return '请选择陪伴$name\n度过一天的朋友';
  }

  @override
  String get onboardingCharacterDescription => '选好的朋友会在首页和奖励页面陪着你';

  @override
  String get onboardingImageStyleTitle => '卡片图片要用\n哪种方式制作？';

  @override
  String get onboardingImageStyleDescription => '以后可以在设置中修改';

  @override
  String onboardingImageStyleCreditIntroWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每周获得$count个积分。制作日常和图片时使用',
    );
    return '$_temp0';
  }

  @override
  String onboardingImageStyleCreditIntroMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每月获得$count个积分。制作日常和图片时使用',
    );
    return '$_temp0';
  }

  @override
  String get onboardingImageStyleCreditIntro => '积分在制作日常和图片时使用';

  @override
  String get onboardingNameTitle => '要怎么称呼\nElumi呢？';

  @override
  String get onboardingNameDescription => '在elum里，我们把使用的人叫作Elumi\n不用真实姓名也可以';

  @override
  String get onboardingNameHint => '请输入名字';

  @override
  String get onboardingNameInviteLink => '我有邀请码';

  @override
  String get onboardingCompletionTitle => '内容已经\n全部整理好了';

  @override
  String get onboardingCompletionProgress => '100% 完成！';

  @override
  String get onboardingSplashLogoLabel => 'elum';

  @override
  String get pinCreateTitle => '请设置一个\n只有你知道的密码';

  @override
  String get pinConfirmTitle => '请再输入\n一次密码';

  @override
  String get pinDescription => '切换到监护人模式时使用这个密码';

  @override
  String get pinMismatch => '密码不一致。请重新输入';

  @override
  String get pinInputSemanticLabel => '输入密码';

  @override
  String get pinStartButton => '开始';

  @override
  String get pinProfileCreateFailedTitle => '没能创建Elumi';

  @override
  String get pinProfileCreateFailedFallback => '请稍后再试';

  @override
  String get pinSaveFailedTitle => '没能保存设置';

  @override
  String get pinSaveFailedFallback => '请稍后再点一次开始';

  @override
  String get elumiSettingsTitle => '设置';

  @override
  String get elumiSettingsHapticLabel => '勾选卡片时振动';

  @override
  String get elumiSettingsPraiseSoundLabel => '勾选卡片时的表扬声音';

  @override
  String get elumiSettingsScreenAwakeLabel => '看卡片时保持屏幕常亮';

  @override
  String get elumiSettingsTermsLabel => '条款及隐私政策';

  @override
  String get elumiSettingsLogoutLabel => '退出登录';

  @override
  String get elumiSettingsWithdrawLabel => '注销账号';

  @override
  String get elumiSettingsLogoutTitle => '要退出登录吗？';

  @override
  String get elumiSettingsLogoutMessage => '这台设备会断开连接\n想再次使用，需要\n向监护人领取连接码';

  @override
  String get elumiSettingsLogoutFailTitle => '没能退出登录';

  @override
  String get elumiSettingsWithdrawTitle => '要注销账号吗？';

  @override
  String get elumiSettingsWithdrawMessage =>
      '只会断开这台设备的连接\n日常和星星会保留在监护人的设备上\n想再次使用，需要\n向监护人领取连接码';

  @override
  String get elumiSettingsWithdrawAction => '注销';

  @override
  String get inviteRejectedOnElumiDevice => '这台设备不能接受邀请\n请在监护人的设备上打开';

  @override
  String get elumiSettingsWithdrawFailTitle => '没能注销';

  @override
  String get elumiSettingsExitFailedFallback => '请稍后再试';

  @override
  String get linkStatusTitle => 'Elumi的设备';

  @override
  String get linkStatusRevokeConfirmTitle => '要断开连接吗？';

  @override
  String get linkStatusRevokeConfirmMessage =>
      'Elumi的设备将看不到日常\n想重新连接，制作新的连接码就可以';

  @override
  String get linkStatusRevokeConfirmAction => '断开连接';

  @override
  String get linkStatusRevokeFailTitle => '没能断开连接';

  @override
  String get linkStatusRevokeFailedFallback => '请稍后再试';

  @override
  String get linkStatusRevoked => '已断开连接';

  @override
  String get linkStatusAlreadyRevoked => '已经断开了';

  @override
  String get linkStatusLoadFailedFallback => '没能加载连接状态';

  @override
  String linkDeviceNumbered(int number) {
    return 'Elumi的设备 $number';
  }

  @override
  String get linkStatusConnected => '已连接';

  @override
  String get linkStatusRevokeButton => '断开连接';

  @override
  String get linkStatusRevokeHint => '断开后，Elumi的设备\n将看不到日常';

  @override
  String get linkStatusEmpty => '没有已连接的设备';

  @override
  String linkStatusConnectedBy(String name, String batchim) {
    return '$name连接';
  }

  @override
  String get linkStatusConnectedByMe => '我连接的';

  @override
  String linkStatusConnectedByAndSince(String by, String since) {
    return '$by · $since';
  }

  @override
  String get linkStatusAddAction => '+ 连接其他设备';

  @override
  String get linkStatusConnectAction => '连接Elumi的设备';

  @override
  String get linkCodeSettingsTitle => '连接Elumi的设备';

  @override
  String linkCodeAskTitle(String name, String batchim) {
    return '要连接$name的\n设备吗？';
  }

  @override
  String linkCodeEnterHint(String name, String batchim) {
    return '请在$name的设备上输入下面的连接码';
  }

  @override
  String get linkCodeIssueFailedFallback => '没能生成连接码。请再试一次';

  @override
  String get linkCodeSuccessTitle => '设备连接成功！';

  @override
  String get linkCodeStartButton => '开始';

  @override
  String get linkCodeLater => '以后再说';

  @override
  String get linkCodeChangesAfter => '后连接码会更换';

  @override
  String get linkRetryChipLabel => '重新生成连接码';

  @override
  String get linkEnterTitle => '请输入从监护人\n那里拿到的连接码';

  @override
  String get linkEnterGuide => '连接码在监护人设备的这个位置\n我的信息 → 齿轮 → 连接Elumi的设备';

  @override
  String get linkEnterGuidePath => '我的信息 → 齿轮 → 连接Elumi的设备';

  @override
  String get linkEnterLinkLost => '连接已断开\n请向监护人领取新的连接码并输入';

  @override
  String get linkEnterStartButton => '开始';

  @override
  String get linkEnterInputLabel => '输入连接码';

  @override
  String get linkEnterWrongCode => '连接码不对';

  @override
  String get linkEnterExpired => '连接码已过期。请领取新的连接码';

  @override
  String get linkEnterOffline => '没能连接。请检查网络';

  @override
  String get linkEnterFailed => '没能连接。请再试一次';

  @override
  String get commonGuardianName => '监护人';

  @override
  String get guardianKindGuardian => '监护人';

  @override
  String get guardianKindCaregiver => '老师';

  @override
  String inviteShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes分钟',
    );
    return '一起照顾Elumi吧。点击下面的链接，elum应用里会自动填好邀请码。\n邀请码只能在$_temp0内使用。\n\n$url\n\n如果链接打不开，请在应用里直接输入。\n邀请码 $code';
  }

  @override
  String get guardiansEditTitle => '修改我的名字';

  @override
  String get guardiansEditDescription => '这是一起照顾Elumi的人看到的名字。\n不用真实姓名也可以';

  @override
  String get guardiansEditNameHint => '妈妈、爸爸、老师';

  @override
  String get guardiansEditSave => '保存';

  @override
  String get guardiansLeaveConfirmTitle => '要停止一起照顾吗？';

  @override
  String get guardiansLeaveConfirmMessageLast =>
      '没有一起照顾的监护人\n离开后，和Elumi一起做的日常、攒的星星都会消失\n无法恢复';

  @override
  String get guardiansLeaveConfirmMessageOthers =>
      '如果有我连接的Elumi设备，连接会断开\n需要其他监护人制作新的连接码才能再次使用\n我做的日常会消失\nElumi和其他监护人的日常、星星都会保留';

  @override
  String get guardiansLeaveConfirmAction => '停止';

  @override
  String get guardiansLeaveTypeTitle => '再确认一次';

  @override
  String guardiansLeaveTypeMessage(String phrase) {
    return 'Elumi、日常和星星都会消失\n请在下面的框里\n准确输入“$phrase”';
  }

  @override
  String get guardiansLeaveTypePhrase => '停止';

  @override
  String get guardiansLeaveTypeAction => '停止';

  @override
  String get guardiansLeaveFailTitle => '没能离开';

  @override
  String get guardiansLeaveFailedFallback => '请稍后再试';

  @override
  String guardiansLeft(String name) {
    return '已离开$name';
  }

  @override
  String get guardiansNameEditFailTitle => '没能修改名字';

  @override
  String get guardiansNameEditFailedFallback => '请稍后再试';

  @override
  String get guardiansTitle => '一起照顾的人';

  @override
  String get guardiansNoProfileMessage => '没有可以查看一起照顾的人的Elumi';

  @override
  String get guardiansNoProfileDescription => '请先添加Elumi';

  @override
  String get guardiansIntro => '一起制作日常的家人或老师';

  @override
  String get guardiansLoadFailedFallback => '没能加载一起照顾的人';

  @override
  String get guardiansEmptyMessage => '没有找到一起照顾的人';

  @override
  String get guardiansAloneHint => '目前是你一个人在照顾。试着邀请家人或老师吧';

  @override
  String get guardiansNameScopeHint => '这里的名字只有一起照顾的人能看到。故事区显示的是我的信息里的昵称';

  @override
  String get guardiansInviteAction => '邀请其他监护人';

  @override
  String get guardiansEnterCodeAction => '输入收到的邀请码';

  @override
  String get guardiansLeaveAction => '停止一起照顾';

  @override
  String get guardiansLeaveHintAlone => '只有你一个人在照顾，停止后Elumi、日常和星星都会消失';

  @override
  String get guardiansLeaveHintWithOthers => '只有我做的日常会消失';

  @override
  String inviteCodeGuestJoinedTitle(String name) {
    return '$name加入了';
  }

  @override
  String get guardiansMeBadge => '我';

  @override
  String guardiansPeopleHeader(int count) {
    return '一起照顾的人 $count位';
  }

  @override
  String get guardiansInviteHeader => '邀请';

  @override
  String get guardiansRenameAction => '修改名字';

  @override
  String get inviteCodeShareFailTitle => '没能发送链接';

  @override
  String get inviteCodeShareFailFallback => '请直接告诉对方邀请码';

  @override
  String get inviteCodeTitle => '邀请码';

  @override
  String get inviteCodeShareButton => '用链接发送';

  @override
  String get inviteCodeHeaderTitle => '请把邀请码告诉\n要一起照顾的监护人';

  @override
  String inviteCodeAsk(String name, String batchim) {
    return '收到邀请码的人会一起照顾$name';
  }

  @override
  String get inviteCodeNoProfileMessage => '没有可以一起照顾的Elumi';

  @override
  String get inviteCodeNoProfileDescription => '请先添加Elumi';

  @override
  String get inviteCodeIssueFailedFallback => '没能生成邀请码';

  @override
  String get inviteEnterLinkInvalid => '邀请链接不对。请让发送的人重新发一次 (E-INV-LINK)';

  @override
  String get inviteEnterFormInvalid => '邀请码不对 (E-INV-FORM)';

  @override
  String inviteJoined(String name, String batchim) {
    return '现在一起照顾$name了';
  }

  @override
  String get inviteEnterNotFound => '邀请码不对';

  @override
  String get inviteEnterExpired => '邀请码已过期。请领取新的邀请码';

  @override
  String get inviteEnterTooManyAttempts => '请稍后再试';

  @override
  String get inviteEnterAlreadyGuardian => '你已经在照顾这位Elumi了';

  @override
  String get inviteEnterForbiddenForElumi => '在Elumi的设备上无法进行';

  @override
  String get inviteEnterInvalidInput => '邀请码不对';

  @override
  String get inviteEnterOffline => '没能连接。请检查网络';

  @override
  String get inviteEnterOther => '没能连接。请再试一次';

  @override
  String get inviteEnterConsentFailTitle => '没能输入邀请码';

  @override
  String get inviteEnterConsentFallback => '请先同意条款';

  @override
  String get inviteEnterStartButton => '开始';

  @override
  String get inviteEnterManualLink => '输入其他邀请码';

  @override
  String get inviteEnterTitle => '请输入\n邀请码';

  @override
  String get inviteEnterDescriptionFromLink => '这是通过链接收到的邀请码。没问题的话请点开始';

  @override
  String get inviteEnterDescriptionManual => '邀请码在一起照顾的监护人设备的\n我的信息 → 一起照顾的人 里';

  @override
  String get inviteEnterDescriptionPath => '我的信息 → 一起照顾的人';

  @override
  String get inviteEnterSemanticsFromLink => '通过链接收到的邀请码';

  @override
  String get inviteEnterSemanticsInput => '输入邀请码';

  @override
  String get profileSwitchChanged => '已切换Elumi';

  @override
  String get profileSwitchTitle => '切换Elumi';

  @override
  String get profileSwitchLoadFailedFallback => '没能加载Elumi列表';

  @override
  String get profileSwitchLoadFailedMessage => '没能加载Elumi列表';

  @override
  String profileSwitchSelected(String name) {
    return '$name，正在查看的Elumi';
  }

  @override
  String get noticeHideWeek => '一周内不再显示';

  @override
  String noticeHideDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days天内不再显示',
    );
    return '$_temp0';
  }

  @override
  String noticeLinkOpenFailed(String code) {
    return '没能打开链接 ($code)';
  }

  @override
  String get noticeCloseBarrier => '关闭公告';

  @override
  String get cardPhotoTooLarge => '照片太大了。请选择其他照片';

  @override
  String get cardPhotoWrongType => '只能上传JPG或PNG照片';

  @override
  String get cardPhotoUnreadable => '没能读取照片。请选择其他照片';

  @override
  String get cardPhotoPickFailed => '没能获取照片。请再试一次';

  @override
  String get routineLoadingPrepareTitle => 'Lumi正在\n整理内容';

  @override
  String get routineLoadingGenerateTitle => 'Lumi正在\n制作行为卡片';

  @override
  String get routineStageReviewSituation => '正在查看你写的情况';

  @override
  String get routineStageTidyEssentials => '只整理必要的内容';

  @override
  String get routineStageThinkQuestions => '正在想补充问题';

  @override
  String get routineStageReadRoutine => '正在阅读今天的日常';

  @override
  String get routineStageFindItems => '正在找重要的准备物品';

  @override
  String get routineStageOrderSteps => '正在整理顺序';

  @override
  String get suggestionRainyText => '下雨天上学';

  @override
  String get suggestionRainyPrompt => '想做好下雨天带伞去上学的准备';

  @override
  String get suggestionHospitalText => '去医院的准备';

  @override
  String get suggestionHospitalPrompt => '要和Elumi一起去医院，想提前准备好让Elumi不害怕';

  @override
  String get suggestionTripText => '校外实践的准备';

  @override
  String get suggestionTripPrompt => '想按顺序告诉Elumi校外实践当天早上要带的东西';

  @override
  String get suggestionNewPlaceText => '去新的地方';

  @override
  String get suggestionNewPlacePrompt => '想在去第一次去的地方之前，帮Elumi做好心理准备';

  @override
  String get suggestionAfterSchoolText => '暑假课后班的准备';

  @override
  String get suggestionAfterSchoolPrompt => '想按顺序告诉Elumi假期去课后班要做的准备';

  @override
  String get guardianHomeTodayRoutine => '今天的日常';

  @override
  String get guardianHomePastRoutine => '过去的日常';

  @override
  String get guardianHomeGoChildScreen => '去Elumi模式';

  @override
  String get notificationBellLabel => '通知';

  @override
  String get notificationBellUnreadLabel => '有未读通知';

  @override
  String get notificationTabNotifications => '通知';

  @override
  String get notificationTabNotices => '公告';

  @override
  String get notificationDayToday => '今天';

  @override
  String get notificationDayYesterday => '昨天';

  @override
  String get notificationDayEarlier => '更早';

  @override
  String get notificationMarkAllRead => '全部已读';

  @override
  String get notificationEmpty => '还没有收到通知';

  @override
  String get notificationNoticeEmpty => '还没有公告';

  @override
  String get notificationNoticeFailed => '没能加载公告';

  @override
  String get notificationSettingsTitle => '通知设置';

  @override
  String get notificationSettingAll => '接收所有通知';

  @override
  String get notificationSettingRoutineCompleted => 'Elumi完成日常时';

  @override
  String get notificationSettingRoutineSent => '其他监护人发来日常时';

  @override
  String get notificationSettingCoGuardianJoined => '有新监护人加入时';

  @override
  String get notificationSettingCreditRefilled => '本周积分补满时';

  @override
  String get notificationSettingFeedbackResolved => '意见处理完成时';

  @override
  String get notificationSettingTalkCommented => '故事区:我的帖子有新评论时';

  @override
  String get notificationSettingTalkImported => '故事区:有人拿走我的帖子时';

  @override
  String get notificationPermissionOff => '设备通知已关闭';

  @override
  String get notificationTurnOnDeviceNotification => '开启';

  @override
  String get notificationSettingSaveFailed => '没能保存设置';

  @override
  String get notificationSettingLoadFailed => '没能加载设置';

  @override
  String get notificationListFailed => '没能加载通知';

  @override
  String get notificationProfileUnavailable => '无法再查看这位Elumi的通知';

  @override
  String notificationRoutineCompletedOne(String title) {
    return '完成了“$title”日常';
  }

  @override
  String notificationRoutineCompletedMany(int count) {
    return '完成了$count个日常';
  }

  @override
  String get notificationRoutineCompletedNoTitle => '完成了日常';

  @override
  String notificationRoutineSent(String title) {
    return '一起照顾的监护人发来了“$title”日常';
  }

  @override
  String get notificationRoutineSentNoTitle => '一起照顾的监护人发来了新日常';

  @override
  String get notificationCoGuardianJoined => '有新监护人开始一起照顾了';

  @override
  String get notificationCreditRefilled => '本周积分已补满';

  @override
  String get notificationFeedbackResolved => '已确认并处理了你发来的意见';

  @override
  String notificationTalkPostCommented(int count) {
    return '我的帖子收到了$count条评论';
  }

  @override
  String notificationTalkPostImported(int count) {
    return '有$count位监护人拿走了我的帖子';
  }

  @override
  String get notificationWeeklyReportReady => '上周的报告来了';

  @override
  String get notificationAdminMessageFallback => '来自elum的消息';

  @override
  String guardianHomeGreeting(String name) {
    return '你好，\n$name的监护人 👋🏻';
  }

  @override
  String get guardianHomeSubtitle => '今天要准备什么日常呢？';

  @override
  String get pinChangeMismatchCreate => '密码不一致。请重新输入';

  @override
  String get pinChangeMismatch => '密码不一致。请重新输入';

  @override
  String get pinChangeCreateFailedTitle => '没能设置密码';

  @override
  String get pinChangeFailedTitle => '没能修改密码';

  @override
  String get pinChangeFailedFallback => '请稍后再试';

  @override
  String get pinChangeCreatedSnack => '已设置密码';

  @override
  String get pinChangeChangedSnack => '已修改密码';

  @override
  String get pinChangeVerifyTitle => '请输入\n现在的密码';

  @override
  String get pinChangeCreateTitle => '请设置这台设备\n要用的密码';

  @override
  String get pinChangeCreateDescription => '每台设备单独设置密码\n和以前的设备一样也可以';

  @override
  String get pinModeHint => '切换到监护人模式时使用这个密码';

  @override
  String get pinChangeEnterTitle => '请输入\n新密码';

  @override
  String get pinChangeCreateConfirmTitle => '请再输入\n一次密码';

  @override
  String get pinChangeConfirmTitle => '请再输入\n一次密码';

  @override
  String get pinChangeConfirmHint => '马上就改好密码了';

  @override
  String get pinChangeHeaderTitle => '修改密码';

  @override
  String get pinChangeSave => '保存';

  @override
  String get pinChangeInputLabel => '输入密码';

  @override
  String get rewardSaveFailedTitle => '没能保存奖励';

  @override
  String get rewardSaveFailedFallback => '请稍后再试';

  @override
  String get rewardWhyTitle => '为什么需要奖励？';

  @override
  String get rewardWhyMessage =>
      '完成日常后有期待的东西，Elumi就会有坚持到底的力量。\n比起一个月后的礼物，今天就能给的小东西更有效。\n不设置奖励也可以制作日常。';

  @override
  String get rewardHeadlineTitle => '日常完成后\n要给什么奖励？';

  @override
  String get rewardHeadlineBody => '会成为完成日常的很大动力';

  @override
  String get rewardLater => '以后再说';

  @override
  String get imageStyleChangedSnack => '已更换图片方式';

  @override
  String get imageStyleSaveFailedTitle => '没能保存图片方式';

  @override
  String get imageStyleSaveFailedFallback => '请稍后再试';

  @override
  String get imageStyleTitle => '图片方式';

  @override
  String get routineLoadingBlockedTitle => '现在无法制作';

  @override
  String get routineLoadingPrepareFailed => '没能准备好问题';

  @override
  String get routineLoadingGenerateFailed => '没能制作卡片';

  @override
  String get routineLoadingInputNeededTitle => '请告诉我们是什么日常';

  @override
  String get routineLoadingEditInput => '重新填写';

  @override
  String routineLoadingPercent(int percent) {
    return '已完成$percent%';
  }

  @override
  String get routineLoadingRetry => '再试一次';

  @override
  String get routineLoadingHome => '回到首页';

  @override
  String get draftRoutinesTitle => '草稿';

  @override
  String get draftRoutinesLoadFailedFallback => '没能加载草稿';

  @override
  String get draftRoutinesDeleteLabel => '删除草稿';

  @override
  String get draftRoutinesDeleteConfirmTitle => '要删除草稿吗？';

  @override
  String get draftRoutinesDeleteAction => '删除';

  @override
  String get draftRoutinesDeleteFailedTitle => '没能删除草稿';

  @override
  String get draftRoutinesDeleteFailedFallback => '请稍后再试';

  @override
  String get draftRoutinesRewardUnset => '还没定奖励';

  @override
  String get draftRoutinesRewardLabel => '完成时';

  @override
  String get draftRoutinesResume => '继续';

  @override
  String get draftRoutinesEmptyTitle => '没有做到一半的日常';

  @override
  String get draftRoutinesEmptyBody => '制作日常中途停下，会保留在这里';

  @override
  String get cardReviewDeleteConfirmTitle => '要删除卡片吗？';

  @override
  String get cardReviewDeleteAction => '删除';

  @override
  String get cardReviewSoundFailedTitle => '没能播放声音';

  @override
  String get cardReviewSoundFailedFallback => '请打开设备声音后再点一次';

  @override
  String get cardReviewSaveFailedTitle => '没能保存日常';

  @override
  String get cardReviewSaveFailedFallback => '请稍后再试';

  @override
  String get cardReviewEditFailedTitle => '没能保存修改的内容';

  @override
  String get cardReviewEditFailedFallback => '请稍后再试';

  @override
  String get cardReviewAddFailedTitle => '没能添加卡片';

  @override
  String get cardReviewAddFailedFallback => '请稍后再试';

  @override
  String get cardImageGeneratingLabel => '正在制作图片';

  @override
  String get cardImageNoCreditToast => '积分不够，已放入默认图片';

  @override
  String get cardImageUnavailableToast => '图片没能做好，已放入默认图片';

  @override
  String get cardImageMissingAfterCreateToast =>
      '没能生成图片的卡片已放入默认图片。可以在“修改这张卡片”里画AI图片';

  @override
  String get cardReviewReorderDone => '完成';

  @override
  String get cardReviewSave => '保存卡片';

  @override
  String get routineInputTitle => '今天需要\n做什么准备？';

  @override
  String get routineInputSubtitle => 'AI助手Lumi会帮你分成小的行动步骤';

  @override
  String get routineInputHint => '像平时说话一样输入就好';

  @override
  String get routineInputPrivacyNotice => '请不要填写姓名、学校、医院、诊断名称等个人信息';

  @override
  String get guardianSettingsLogoutConfirmTitle => '要退出登录吗？';

  @override
  String get guardianSettingsWithdrawConfirmTitle => '要注销账号吗？';

  @override
  String get guardianSettingsWithdrawConfirmMessage =>
      '做好的日常和攒的星星都会消失\n重新登录也无法恢复';

  @override
  String get guardianSettingsWithdrawConfirmAction => '注销';

  @override
  String get guardianSettingsWithdrawFailedTitle => '没能注销';

  @override
  String get guardianSettingsWithdrawFailedFallback => '请稍后再试';

  @override
  String get guardianSettingsWithdrawAppStoreSubscriptionNotice =>
      '注销后Pro订阅仍会继续\n请在App Store中\n自行取消';

  @override
  String get guardianSettingsWithdrawGooglePlaySubscriptionNotice =>
      '注销后会停止Google Play Pro订阅的\n下一次付款';

  @override
  String get guardianSettingsWithdrawProNotice => 'Pro也会一起消失';

  @override
  String guardianSettingsWithdrawProGiftNotice(String date) {
    return '可以用到$date的\nPro礼物也会消失';
  }

  @override
  String get guardianSettingsWithdrawProTrialNotice => 'Pro体验也会一起消失';

  @override
  String guardianSettingsWithdrawCreditsNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个',
    );
    return '剩下的$_temp0积分也会消失';
  }

  @override
  String guardianSettingsWithdrawCreditsWithPurchasedNotice(
    int count,
    int purchased,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个',
    );
    String _temp1 = intl.Intl.pluralLogic(
      purchased,
      locale: localeName,
      other: '$purchased个',
    );
    return '剩下的$_temp0积分也会消失\n其中包括购买的$_temp1积分';
  }

  @override
  String get guardianSettingsWithdrawCreditsUnknownNotice => '剩下的积分也会全部消失';

  @override
  String get guardianSettingsWithdrawAppStoreStepTitle => '请先取消App Store订阅';

  @override
  String get guardianSettingsWithdrawAppStoreStepMessage =>
      '只注销的话付款还会继续\n不取消也可以注销';

  @override
  String get guardianSettingsWithdrawAppStoreStepContinue => '继续';

  @override
  String get guardianSettingsWithdrawDone => '已注销。感谢你一直以来使用elum';

  @override
  String get guardianSettingsWithdrawTypeTitle => '再确认一次';

  @override
  String guardianSettingsWithdrawTypeMessage(String phrase) {
    return '请在下面的框里\n准确输入“$phrase”';
  }

  @override
  String get guardianSettingsWithdrawTypePhrase => '注销账号';

  @override
  String get guardianSettingsWithdrawTypeAction => '注销';

  @override
  String get guardianSettingsTitle => '设置';

  @override
  String get guardianSettingsPeople => '一起照顾的人';

  @override
  String get guardianSettingsDrafts => '草稿';

  @override
  String get guardianSettingsPinChange => '修改密码';

  @override
  String get guardianSettingsTerms => '条款及隐私政策';

  @override
  String get guardianSettingsFeedback => '发送意见';

  @override
  String get feedbackTitle => '发送意见';

  @override
  String get feedbackHint => '把不方便的地方随意写下来吧';

  @override
  String get feedbackIncludeLog => '发送应用状态记录和设备信息';

  @override
  String get feedbackSend => '发送';

  @override
  String get feedbackSent => '已发送意见';

  @override
  String get feedbackFailedTitle => '没能发送意见';

  @override
  String get feedbackFailedFallback => '写好的内容还在。请稍后再发送';

  @override
  String get guardianSettingsLogout => '退出登录';

  @override
  String get guardianSettingsWithdraw => '注销账号';

  @override
  String get guardianSettingsLinkConnected => 'Elumi的设备';

  @override
  String get guardianSettingsLinkConnect => '连接Elumi的设备';

  @override
  String get guardianSettingsLinkStatus => '已连接';

  @override
  String get guardianSettingsProfileSwitch => '切换Elumi';

  @override
  String get guardianSettingsImageStyle => '图片方式';

  @override
  String get guardianSettingsHaptic => '勾选卡片时振动';

  @override
  String get guardianSettingsPraiseSound => '勾选卡片时的表扬声音';

  @override
  String get guardianSettingsScreenAwake => '看卡片时保持屏幕常亮';

  @override
  String get questionMakeCards => '制作卡片';

  @override
  String get questionCustomAdd => '+ 自己填写';

  @override
  String get questionCustomHint => '请自己填写';

  @override
  String get questionCustomClose => '关闭自己填写';

  @override
  String questionClearLabel(String label) {
    return '清除$label';
  }

  @override
  String cardReviewMade(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '做好了$count张卡片',
    );
    return '$_temp0';
  }

  @override
  String get cardReviewRewardLead => '完成时 ';

  @override
  String get cardReviewRewardSet => '设置奖励';

  @override
  String get cardReviewReorderHint => '长按卡片可以调整顺序';

  @override
  String get cardReviewToolReorder => '调整卡片顺序';

  @override
  String get cardReviewToolEdit => '修改这张卡片';

  @override
  String get cardReviewToolAdd => '添加卡片';

  @override
  String get cardReviewReorderTitle => '调整卡片顺序';

  @override
  String get cardReviewReorderCancel => '取消调整顺序';

  @override
  String get cardReviewEmptyTitle => '没有做好的卡片';

  @override
  String get cardReviewEmptyBody => '请从头重新制作日常';

  @override
  String get cardReviewEmptyAction => '重新制作';

  @override
  String get cardMoveForward => '往前移';

  @override
  String get cardMoveBackward => '往后移';

  @override
  String get cardSpeakStop => '停止朗读';

  @override
  String get cardSpeak => '听声音';

  @override
  String get cardDeleteLabel => '删除这张卡片';

  @override
  String get cardAddPhoto => '添加照片';

  @override
  String get cardViewerBarrierLabel => '关闭卡片';

  @override
  String get cardViewerSoundFailedTitle => '没能播放声音';

  @override
  String get cardViewerSoundFailedFallback => '请打开设备声音后再点一次';

  @override
  String get cardViewerClose => '关闭卡片';

  @override
  String get cardEditAddTitle => '添加新卡片';

  @override
  String get cardEditTitle => '修改卡片';

  @override
  String get cardEditFieldTitle => '标题';

  @override
  String get cardEditTitleHint => '请填写卡片标题';

  @override
  String get cardEditFieldDescription => '说明';

  @override
  String get cardEditDescriptionHint => '请填写卡片说明';

  @override
  String get cardEditAddAction => '添加';

  @override
  String get cardEditDoneAction => '完成';

  @override
  String get cardPhotoPermissionTake => '拍照';

  @override
  String get cardPhotoPermissionGallery => '从相册选择';

  @override
  String get cardPhotoPermissionOpenSettings => '打开设置';

  @override
  String get cardPhotoPermissionCameraTitle => '无法使用相机';

  @override
  String get cardPhotoPermissionGalleryTitle => '无法查看照片';

  @override
  String get cardPhotoPermissionCameraBody => '在设备设置中开启相机后就能拍照';

  @override
  String get cardPhotoPermissionGalleryBody => '在设备设置中开启照片访问后就能选择';

  @override
  String get cardPhotoSettingsFailedTitle => '没能打开设置';

  @override
  String get cardPhotoSettingsFailedFallback => '请在设备设置中手动开启';

  @override
  String get cardPhotoSourceTake => '拍照';

  @override
  String get cardPhotoSourceGallery => '从相册选择';

  @override
  String cardPhotoUploadFailedDialog(String message) {
    return '没能上传照片。\n$message';
  }

  @override
  String get cardPhotoChange => '更换照片';

  @override
  String get cardPhotoUploading => '正在上传照片';

  @override
  String get cardPhotoUploadFailed => '没能上传照片';

  @override
  String get cardPhotoRetry => '再试一次';

  @override
  String get creditCardTitle => '本周AI生成';

  @override
  String get creditCardTitleMonth => '本月AI生成';

  @override
  String get creditCardLoading => '正在加载本周AI生成用量';

  @override
  String get creditCardLoadingMonth => '正在加载本月AI生成用量';

  @override
  String get creditCardLoadFailed => '没能加载用量';

  @override
  String get creditCardRetry => '再试一次';

  @override
  String get creditGenerating => '正在制作日常';

  @override
  String get creditExhausted => '本周积分已全部用完';

  @override
  String get creditExhaustedMonth => '本月积分已全部用完';

  @override
  String get creditExhaustedStillOk => '仍然可以查看做好的日常并自己修改';

  @override
  String get creditInfoLabel => 'AI积分说明';

  @override
  String creditAmountLeft(int available, int weekly) {
    return '剩余 $available / $weekly 积分';
  }

  @override
  String creditAmountRest(int weekly) {
    return ' / $weekly 积分剩余';
  }

  @override
  String aiCreditResetLine(String reset) {
    return '$reset重新补满';
  }

  @override
  String get routineCreateButton => '制作新日常';

  @override
  String get routineSwipeDelete => '删除日常';

  @override
  String get routineSwipeEdit => '修改日常';

  @override
  String get routineFlowHomeLabel => '回到首页';

  @override
  String get routineFlowDraftLabel => '草稿';

  @override
  String get routineFlowLeaveStay => '继续制作';

  @override
  String get routineFlowLeaveConfirm => '离开';

  @override
  String get routineLeaveDiscardTitle => '要停止制作日常吗？';

  @override
  String get routineLeaveDiscardMessage => '现在离开的话，写的内容不会保留';

  @override
  String get routineLeaveDraftWhenReadyTitle => '要存为草稿再离开吗？';

  @override
  String get routineLeaveDraftWhenReadyMessage => '卡片做好后会保留在草稿里\n可以在我的信息中继续制作';

  @override
  String get routineLeaveDraftTitle => '要存为草稿再离开吗？';

  @override
  String get routineLeaveDraftMessage => '可以在我的信息的草稿中\n继续制作';

  @override
  String get routineLeaveEditTitle => '不保存就离开吗？';

  @override
  String get routineLeaveEditMessage => '删掉的卡片要点保存才会移除';

  @override
  String get routineTileRewardLabel => '完成时';

  @override
  String get routineTileRerun => '再做一次日常';

  @override
  String get routineDetailReorderFailedTitle => '没能保存顺序';

  @override
  String get routineDetailReorderFailedFallback => '请稍后再试';

  @override
  String get routineDetailRerun => '再做一次日常';

  @override
  String get routineDetailEdit => '编辑';

  @override
  String routineDetailTodayProgress(int done, int total) {
    return '今天完成了 $done/$total';
  }

  @override
  String routineDetailPastProgress(int done, int total) {
    return '完成了 $done/$total';
  }

  @override
  String get routineDetailExportLabel => '打印用';

  @override
  String get routineDetailFinishedToday => '已经全部完成的日常';

  @override
  String get routineDetailOpenHint => '点一下放大看卡片';

  @override
  String get routineDetailNoReward => '这个日常完成后没有奖励';

  @override
  String get rewardInputHint => '例) 看10分钟视频';

  @override
  String get todayRoutineReorderFailedTitle => '没能保存顺序';

  @override
  String get todayRoutineReorderFailedFallback => '请稍后再试';

  @override
  String get todayRoutineDeleteConfirmTitle => '要删除日常吗？';

  @override
  String get todayRoutineStartedTitle => '这是Elumi已经开始的日常';

  @override
  String get todayRoutineStartedMessage => '为了保留做过的记录，无法删除';

  @override
  String get todayRoutineDeleteAction => '删除';

  @override
  String get todayRoutineDeleteFailedTitle => '没能删除日常';

  @override
  String get todayRoutineDeleteFailedFallback => '请稍后再试';

  @override
  String get todayRoutineLoadFailedFallback => '没能加载日常';

  @override
  String get todayRoutineRerunFailedTitle => '没能重新制作日常';

  @override
  String get todayRoutineRerunFailedFallback => '请稍后再试';

  @override
  String todayRoutineCopied(String title, String batchim) {
    return '已把$title放入今天的日常';
  }

  @override
  String get todayRoutinePastLoadFailedFallback => '没能加载过去的日常';

  @override
  String get todayRoutineEmptyTitle => '还没有做好的日常';

  @override
  String get todayRoutineEmptyHint => '来做今天的第一张行为卡片吧';

  @override
  String get todayRoutinePastEmpty => '没有过去的日常';

  @override
  String get homeCoachCreate => '可以*制作Elumi要做的\n新日常*';

  @override
  String get homeCoachSwipe => '把日常*往左滑*\n就能*修改或删除*';

  @override
  String get homeCoachSwitch => '点角色图标\n就能*切换到Elumi模式*';

  @override
  String childHomeGreeting(String name, String batchim) {
    return '这是$name今天\n要做的事。加油！';
  }

  @override
  String childHomeEmptyTitle(String name, String batchim) {
    return '$name还\n没有日常';
  }

  @override
  String get childHomeEmptyHint => '可以在监护人模式中制作日常';

  @override
  String get childHomeEmptyHintDevice => '可以在监护人的设备上制作日常';

  @override
  String get childHomeToGuardianLabel => '去监护人模式';

  @override
  String get childHomeSettingsLabel => '打开设置';

  @override
  String get childHomeRewardPrefix => '做完后';

  @override
  String childStarsEarned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '得到了$count颗星星\n完成要做的事，找到更多星星吧！',
    );
    return '$_temp0';
  }

  @override
  String childStarsSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '攒了$count颗星星',
    );
    return '$_temp0';
  }

  @override
  String childCardPagerLabel(int total, int index) {
    return '共$total张卡片中的第$index张';
  }

  @override
  String get childDetailSoundFailedTitle => '没能播放声音';

  @override
  String get childDetailSoundFailedFallback => '请打开设备声音后再点一次';

  @override
  String get childDetailCheckLabel => '做完了';

  @override
  String get rewardBannerPrefix => '做完后 ';

  @override
  String get rewardLumiTitle => '恭喜！';

  @override
  String rewardLumiMessage(String name) {
    return '完成了要做的事，Lumi\n给$name带来了星星';
  }

  @override
  String get rewardLumiButton => '耶！';

  @override
  String get rewardPopoTitle => '做得好！';

  @override
  String rewardPopoMessage(String name) {
    return 'Popo给$name\n带来了一颗大星星作为祝贺礼物';
  }

  @override
  String get rewardPopoButton => '太好了！';

  @override
  String get rewardRuruTitle => '真棒！';

  @override
  String rewardRuruMessage(String name, String batchim) {
    return '$name完成了要做的事，\nRuru说带来了礼物';
  }

  @override
  String get rewardRuruButton => '好开心！';

  @override
  String get routineDoneTitle => '完成日常了！';

  @override
  String routineDoneMessage(String name) {
    return '为完成了所有事情的\n$name准备的';
  }

  @override
  String get routineDoneButton => '做到了！';

  @override
  String get routineDoneRewardCaption => '今天的奖励';

  @override
  String get modeSwitchToChild => '输入密码就会切换到Elumi模式';

  @override
  String get modeSwitchToGuardian => '输入密码就会切换到监护人模式';

  @override
  String get modeSwitchTitle => '请输入密码';

  @override
  String get modeSwitchMismatch => '密码不对。请重新输入';

  @override
  String get modeSwitchPinLabel => '输入密码';

  @override
  String get pinForgotLink => '忘记密码了';

  @override
  String get pinForgotTitle => '想不起密码了吗？';

  @override
  String get pinForgotMessage => '用监护人账号重新登录\n就能设置新密码';

  @override
  String get pinForgotRelogin => '重新登录';

  @override
  String get modeSwitchReadFailedTitle => '没能确认密码';

  @override
  String get modeSwitchReadFailedFallback => '请稍后再试';

  @override
  String get modeSwitchBlockedTitle => '请在监护人的\n设备上打开';

  @override
  String get modeSwitchBlockedDescription => '这台设备无法打开监护人模式';

  @override
  String get modeSwitchBlockedBack => '返回';

  @override
  String get installationRetryTitle => '出了点小问题';

  @override
  String get installationRetryMessage => '无法检查登录信息。请重试。';

  @override
  String get installationRetryButton => '重试';

  @override
  String get issuedCodeCopyButton => '复制连接码';

  @override
  String get issuedCodeCopied => '已复制连接码';

  @override
  String get issuedCodeCopyFailedTitle => '复制失败了';

  @override
  String get issuedCodeCopyFailedFallback => '请直接告知屏幕上显示的代码';

  @override
  String linkShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes分钟',
    );
    return '来连接Elumi要用的设备吧。在那台设备上点击下面的链接，elum应用里会自动填好连接码。\n连接码只能在$_temp0内使用。\n\n$url\n\n如果链接打不开，请在应用里直接输入。\n连接码 $code';
  }

  @override
  String get linkRejectedAlreadyLinked => '这台设备已经连接了';

  @override
  String get linkRejectedOnGuardianPhone => '请在Elumi的设备上打开';

  @override
  String get myCreditTitle => '我的积分';

  @override
  String get planFreeBadge => 'FREE';

  @override
  String get myCreditKindPeriodicWeek => '每周';

  @override
  String get myCreditKindPeriodicMonth => '每月';

  @override
  String get myCreditKindBonus => '额外积分';

  @override
  String get myCreditKindPurchased => '购买的积分';

  @override
  String get myCreditSubscribeLabel => '订阅后';

  @override
  String get myCreditSubscribeBody => '可以画AI图片，日常也会自动发送';

  @override
  String get myCreditPackLabelFree => '单独购买积分';

  @override
  String get myCreditPackLabelPro => '再买一些积分';

  @override
  String get creditGetMore => '获取更多积分';

  @override
  String myCreditPackDiscount(int percent) {
    return '-$percent%';
  }

  @override
  String get myCreditPackPopular => '热门！';

  @override
  String myCreditPackBuy(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '购买$count个',
    );
    return '$_temp0 ($price)';
  }

  @override
  String get myCreditPackNoExpiryNote => '购买的积分没有期限';

  @override
  String get myCreditPackPriceFailed => '没能加载积分价格';

  @override
  String myCreditPackTileLabel(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个积分',
    );
    return '$_temp0, $price';
  }

  @override
  String get myCreditPurchaseRecheckTitle => '还没收到积分';

  @override
  String get myCreditPurchaseRecheckBody => '已经付款成功。不用再付款，只要再确认一次就好';

  @override
  String get creditHistoryTitle => '积分使用记录';

  @override
  String get creditMineLink => '查看我的积分';

  @override
  String creditHistoryDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String creditHistoryDetail(String kind, String time) {
    return '$kind・$time';
  }

  @override
  String get creditHistoryKindRoutineText => '制作日常文字';

  @override
  String creditHistoryKindCardImages(int count) {
    return '卡片图片$count张';
  }

  @override
  String get creditHistoryKindCardImage => '制作卡片图片';

  @override
  String get creditHistoryKindImageRegenerate => '重新制作卡片图片';

  @override
  String get creditHistoryFree => '不用积分';

  @override
  String get creditHistoryKindWeeklyGrant => '本周积分已补满';

  @override
  String get creditHistoryKindAdReward => '看广告获得';

  @override
  String get creditHistoryKindAdminBonus => 'elum团队送的奖励积分';

  @override
  String get creditHistoryKindOtherGrant => '获得了积分';

  @override
  String get creditHistoryExpiredWeekTitle => '上周积分清零';

  @override
  String get creditHistoryExpiredMonthTitle => '上月积分清零';

  @override
  String get creditHistoryExpiredWeekReason => '没用完的每周积分不会累积到下周';

  @override
  String get creditHistoryExpiredMonthReason => '没用完的每月积分不会累积到下月';

  @override
  String get creditHistoryAdjustedTitle => '积分调整';

  @override
  String get creditHistoryAdjustedReason => '来自退款或运营调整';

  @override
  String get creditHistoryKindUnknownSpend => '使用了积分';

  @override
  String get creditHistoryEmptyTitle => '还没有使用过积分';

  @override
  String get creditHistoryEmptyBody => '制作日常后会记录在这里';

  @override
  String get creditHistoryLoadFailed => '没能加载使用记录';

  @override
  String get creditHistoryMoreFailed => '没能加载更多';

  @override
  String get reminderRowLabel => '日常提醒';

  @override
  String get reminderRowOff => '无提醒';

  @override
  String reminderRowDaily(String time) {
    return '每天$time提醒';
  }

  @override
  String reminderRowOnce(String time) {
    return '$time提醒一次';
  }

  @override
  String get reminderSheetTitle => '什么时候提醒你？';

  @override
  String get reminderSheetBody => '到设定时间，这台设备会收到通知';

  @override
  String get reminderRepeatDaily => '每天同一时间提醒';

  @override
  String get reminderTurnOn => '开启提醒';

  @override
  String get reminderUpdate => '修改提醒时间';

  @override
  String get reminderTurnOff => '关闭提醒';

  @override
  String get reminderSavedToast => '已设置提醒';

  @override
  String get reminderClearedToast => '已关闭提醒';

  @override
  String get reminderPermissionDeniedTitle => '通知已关闭';

  @override
  String get reminderPermissionDeniedBody => '在设备设置中允许elum通知，就能提醒你日常时间';

  @override
  String get reminderFailedTitle => '没能设置提醒';

  @override
  String get reminderFailedBody => '请稍后再试';

  @override
  String get reminderChannelName => '日常提醒';

  @override
  String get reminderNotificationTitle => 'elum';

  @override
  String reminderNotificationBody(String routineTitle) {
    return '该做$routineTitle了';
  }

  @override
  String get routineTemplateOpen => '看看示例日常';

  @override
  String get routineImageStylePillLabel => '卡片图片';

  @override
  String routineImageStylePillSemantics(String style) {
    return '卡片图片方式 $style，点一下更换';
  }

  @override
  String get routineTemplateSheetTitle => '示例日常';

  @override
  String get routineTemplateSheetBody => '选好后会填进输入框。按Elumi的情况修改后再发送';

  @override
  String get routineTemplateBeginnerBadge => '第一次推荐';

  @override
  String get routineTemplateCategorySelfCare => '生活习惯';

  @override
  String get routineTemplateCategorySelfCareHint => '刷牙 · 洗脸 · 穿衣';

  @override
  String get routineTemplateCategoryDailyFlow => '一天的顺序';

  @override
  String get routineTemplateCategoryDailyFlowHint =>
      '早上准备 · 放学后 · 睡前 (按顺序做几件事)';

  @override
  String get routineTemplateCategoryHousehold => '家务';

  @override
  String get routineTemplateCategoryHouseholdHint => '整理房间 · 收碗 · 叠衣服';

  @override
  String get routineTemplateCategoryCommunity => '外出活动';

  @override
  String get routineTemplateCategoryCommunityHint => '坐公交 · 买东西 · 去医院';

  @override
  String get routineTemplateCategoryLearning => '学习';

  @override
  String get routineTemplateCategoryLearningHint => '开始写作业 · 写名字 · 读书';

  @override
  String get routineTemplateCategoryFeelings => '情绪·关系';

  @override
  String get routineTemplateCategoryFeelingsHint => '情绪卡片 · 打招呼 · 等待轮到自己';

  @override
  String get routineTemplateBrushTeethText => '刷牙';

  @override
  String get routineTemplateBrushTeethPrompt =>
      '想让Elumi自己试着刷牙。请按顺序告诉我:拿出牙刷和牙膏、在漱口杯里接水、刷牙、漱口、收拾好';

  @override
  String get routineTemplateWashFaceText => '洗脸';

  @override
  String get routineTemplateWashFacePrompt =>
      '想让Elumi早上自己试着洗脸。请告诉我:打开水龙头、打湿脸、搓出肥皂泡、冲洗、用毛巾擦干、涂润肤露';

  @override
  String get routineTemplateGetDressedText => '自己穿衣服';

  @override
  String get routineTemplateGetDressedPrompt =>
      '想让Elumi自己试着穿衣服。请告诉我按背心、T恤、裤子、袜子的顺序一件一件穿';

  @override
  String get routineTemplateEatMealText => '吃饭';

  @override
  String get routineTemplateEatMealPrompt =>
      '想让Elumi吃饭时自己动手。请告诉我:喝水、拿自己的餐具和碗、坐下吃饭、把吃完的碗送回去';

  @override
  String get routineTemplateBathTimeText => '洗澡';

  @override
  String get routineTemplateBathTimePrompt =>
      '想让Elumi按顺序试着洗澡。请告诉我:脱衣服、把身体打湿、洗头、洗身体、冲洗、用毛巾擦干后穿衣服';

  @override
  String get routineTemplateMorningRoutineText => '早上上学准备';

  @override
  String get routineTemplateMorningRoutinePrompt =>
      '想让Elumi从早上起床到去上学，按顺序做好要做的事。请告诉我:起床、上厕所、吃饭、洗脸刷牙、穿衣服、背书包穿鞋';

  @override
  String get routineTemplateAfterSchoolText => '放学回家后';

  @override
  String get routineTemplateAfterSchoolPrompt =>
      '想让Elumi放学回家后自己做该做的事。请告诉我:摆好鞋子、洗手、把书包放回原位、吃零食、休息一下';

  @override
  String get routineTemplateBedtimeText => '睡前准备';

  @override
  String get routineTemplateBedtimePrompt =>
      '想让Elumi睡前按顺序做好要做的事。请告诉我:刷牙、换睡衣、收拾明天的书包、关灯躺下';

  @override
  String get routineTemplateGoingOutText => '出门准备';

  @override
  String get routineTemplateGoingOutPrompt =>
      '想让Elumi出门前自己做好准备。请告诉我:上厕所、穿外套、带上水杯和手机、穿鞋、在门口等';

  @override
  String get routineTemplateTidyRoomText => '整理房间';

  @override
  String get routineTemplateTidyRoomPrompt =>
      '想让Elumi玩完后自己整理房间。请告诉我:把玩具收在一起、放进箱子、把书插回书架、把衣服挂好';

  @override
  String get routineTemplateClearDishesText => '收拾吃过的碗';

  @override
  String get routineTemplateClearDishesPrompt =>
      '想让Elumi吃完饭后自己收拾碗。请告诉我:把剩菜归到一起、端起碗、放进水槽、擦桌子';

  @override
  String get routineTemplateFoldLaundryText => '叠衣服';

  @override
  String get routineTemplateFoldLaundryPrompt =>
      '想让Elumi试着把晾干的衣服叠好收起来。请告诉我:把衣服拿过来、给袜子配对、叠毛巾、叠衣服、放进抽屉';

  @override
  String get routineTemplateTakeOutTrashText => '倒垃圾';

  @override
  String get routineTemplateTakeOutTrashPrompt =>
      '想让Elumi试着分类倒垃圾。请告诉我:把垃圾收在一起、分开纸和塑料、系好袋子、扔到指定的地方';

  @override
  String get routineTemplateRideBusText => '坐公交';

  @override
  String get routineTemplateRideBusPrompt =>
      '想让Elumi练习自己坐公交。请告诉我:在车站确认车号、排队、刷交通卡、坐到座位上、到站前按铃';

  @override
  String get routineTemplateBuyItemText => '在便利店买东西';

  @override
  String get routineTemplateBuyItemPrompt =>
      '想让Elumi自己在便利店买东西。请告诉我:找到要买的东西、在收银台排队、把东西放上去、用卡或钱付款、拿小票并道谢';

  @override
  String get routineTemplateUseElevatorText => '坐电梯去指定楼层';

  @override
  String get routineTemplateUseElevatorPrompt =>
      '想让Elumi自己坐电梯去指定的楼层。请告诉我:按按钮、门开了就进去、按楼层数字、看楼层显示、出电梯';

  @override
  String get routineTemplateHospitalVisitText => '去医院看病';

  @override
  String get routineTemplateHospitalVisitPrompt =>
      '想让Elumi去医院按顺序看病。请告诉我:挂号、在候诊室等待、叫到名字就进去、看医生、拿药并道别';

  @override
  String get routineTemplateStartHomeworkText => '开始写作业';

  @override
  String get routineTemplateStartHomeworkPrompt =>
      '想让Elumi自己开始并写完作业。请告诉我:坐到书桌前、拿出本子和铅笔、写作业、写完给大人看、放进书包';

  @override
  String get routineTemplateWriteNameText => '练习写名字';

  @override
  String get routineTemplateWriteNamePrompt =>
      '想让Elumi正确握笔，写自己的名字。请告诉我:握铅笔、放好纸、照着描名字、自己写一遍、收拾好';

  @override
  String get routineTemplateCountObjectsText => '数数游戏';

  @override
  String get routineTemplateCountObjectsPrompt =>
      '想让Elumi练习一个一个指着东西数数。请告诉我:把东西摆开、用手指一个一个指、出声数、说出数到的总数';

  @override
  String get routineTemplateReadBookText => '读书时间';

  @override
  String get routineTemplateReadBookPrompt =>
      '想让Elumi自己安排读书时间。请告诉我:选书、坐好、一页一页翻着看、读完插回书架';

  @override
  String get routineTemplateEmotionCardText => '生气时拿出情绪卡片';

  @override
  String get routineTemplateEmotionCardPrompt =>
      '想让Elumi因为朋友生气时，不大喊也不推人，而是拿出情绪卡片给人看。请告诉我:停下来、从口袋里拿出情绪卡片、选出现在心情的卡片、给老师看';

  @override
  String get routineTemplatePlayNicelyText => '和朋友好好玩';

  @override
  String get routineTemplatePlayNicelyPrompt =>
      '想让Elumi练习和朋友好好玩。请告诉我:说一起玩吧、分享玩具、遵守顺序、结束时说谢谢';

  @override
  String get routineTemplateGreetingText => '打招呼';

  @override
  String get routineTemplateGreetingPrompt =>
      '想让Elumi见到人时先打招呼。请告诉我:看着对方的脸、挥手、说你好、微笑';

  @override
  String get routineTemplateWaitTurnText => '等待轮到自己';

  @override
  String get routineTemplateWaitTurnPrompt =>
      '想让Elumi练习排队等轮到自己。请告诉我:站到队伍最后、在前面的人后面等、确认是不是轮到自己、轮到了就去做';

  @override
  String get routineTemplateAskHelpText => '说请帮帮我';

  @override
  String get routineTemplateAskHelpPrompt =>
      '想让Elumi在自己做不来时请求帮助。请告诉我:停下来、找到附近的大人、说请帮帮我、得到帮助后说谢谢';

  @override
  String get guardianTabHome => '首页';

  @override
  String get guardianTabManage => '日常管理';

  @override
  String get guardianTabTalk => '故事区';

  @override
  String get guardianTabMe => '我的信息';

  @override
  String get guardianMyInfoProfileName => '监护人';

  @override
  String get guardianMyInfoEmailPrivate => '邮箱不公开';

  @override
  String guardianMyInfoJoinedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'y. MM. dd',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString 加入';
  }

  @override
  String get guardianMyInfoActiveBadge => '正在查看';

  @override
  String get guardianNicknameEditLabel => '修改昵称';

  @override
  String get guardianNicknameSheetTitle => '修改我的名字';

  @override
  String get guardianNicknameSheetDescription => '这是在故事区发帖时显示的名字。\n名字每7天可以修改一次';

  @override
  String get guardianNicknameSheetHint => '请输入名字';

  @override
  String get guardianNicknameSheetSave => '保存';

  @override
  String get guardianNicknameInvalidFormat => '可以使用韩文、英文、数字、连字符，2~16个字';

  @override
  String guardianNicknameChangeableFrom(String since) {
    return '$since可以修改';
  }

  @override
  String get guardianNicknameChanged => '昵称已修改';

  @override
  String get guardianNicknameSaveFailed => '没能修改昵称';

  @override
  String get guardianSideNavCaption => '监护人模式';

  @override
  String get guardianSideNavChildScreen => 'Elumi模式';

  @override
  String get routineLibraryEmptyTitle => '还没有做好的日常';

  @override
  String get routineLibraryEmptyBody => '点下面的 + 制作日常，做第一个日常吧';

  @override
  String get routineLibraryLoadFailedFallback => '没能加载日常';

  @override
  String get routineLibraryCreate => '新建';

  @override
  String get routineLibrarySendToday => '今天发送';

  @override
  String get routineLibraryEditCards => '修改卡片';

  @override
  String get routineLibraryAlreadySent => '今天已经发送过的日常';

  @override
  String get routineLibrarySendFailedTitle => '没能发送';

  @override
  String get routineLibraryActionFailedFallback => '请稍后再试';

  @override
  String get routineLibraryCopied => '已制作副本';

  @override
  String get routineLibraryCopyFailedTitle => '没能复制';

  @override
  String get routineLibraryMenuRename => '修改名称';

  @override
  String get routineLibraryMenuCopy => '复制';

  @override
  String get routineLibraryMenuRemove => '删除';

  @override
  String get routineLibraryRenameHint => '日常名称';

  @override
  String get routineLibraryRenameSave => '保存';

  @override
  String get routineLibraryRenamed => '已修改名称';

  @override
  String get routineLibraryRenameFailedTitle => '没能修改名称';

  @override
  String get routineLibraryRemoveConfirmTitle => '要删除这个日常吗？';

  @override
  String get routineLibraryRemoveConfirmMessage => '会从日常管理中移除。Elumi做过的记录会保留';

  @override
  String get routineLibraryRemoved => '已删除日常';

  @override
  String get routineLibraryRemoveFailedTitle => '没能删除';

  @override
  String get routineLibrarySentBadge => '今天已发送';

  @override
  String get routineLibraryTileHint => '长按会打开菜单';

  @override
  String get routineLibraryFromTalk => '来自故事区';

  @override
  String get routineLibraryNewBadge => '新日常';

  @override
  String get routineDetailTalkOriginBand => '来自故事区';

  @override
  String get routineDetailTalkOriginOpenPost => '原帖';

  @override
  String get routineDetailTalkOriginPostGone => '已下架的帖子';

  @override
  String get routineDetailTalkOriginBandOpenLabel => '来自故事区，查看原帖';

  @override
  String routineLibrarySent(String title, String batchim) {
    return '已把$title作为今天的日常发送';
  }

  @override
  String onboardingExampleTitle(String name, String batchim) {
    return '想在哪些方面\n帮助$name?';
  }

  @override
  String get onboardingExampleDescription => '我们会为所选分类加入示例日常。\n可以选择多个。';

  @override
  String get onboardingExampleSkip => '跳过';

  @override
  String get exampleCategoryMorningEvening => '早晚准备';

  @override
  String get exampleCategoryMorningEveningHint => '洗漱、穿衣、睡前';

  @override
  String get exampleCategorySchoolStudy => '上学·学习';

  @override
  String get exampleCategorySchoolStudyHint => '上学准备、作业';

  @override
  String get exampleCategoryHouseSelf => '家务·自己动手';

  @override
  String get exampleCategoryHouseSelfHint => '整理、摆餐桌';

  @override
  String get exampleCategoryOutside => '外出试试';

  @override
  String get exampleCategoryOutsideHint => '坐公交、买东西';

  @override
  String get exampleRoutinesFailed => '未能加入示例日常';

  @override
  String get routineGroupMenuAddToGroup => '放入分组';

  @override
  String get routineGroupMenuReorder => '调整顺序';

  @override
  String get routineGroupMenuUngroup => '解散分组';

  @override
  String routineGroupTileLabel(String name, int count) {
    return '$name分组，$count个日常';
  }

  @override
  String get routineGroupDefaultName => '新分组';

  @override
  String get routineGroupNameLabel => '分组名称';

  @override
  String get routineGroupNameHint => '例如:上学前准备';

  @override
  String get routineGroupNewTitle => '新建分组';

  @override
  String routineGroupAddTitle(String name) {
    return '放入$name';
  }

  @override
  String get routineGroupPickHintNew => '请按要显示的顺序点选要放入的日常';

  @override
  String get routineGroupPickHint => '请按顺序点选要放入的日常';

  @override
  String get routineGroupPickEmpty => '没有可以放入的日常';

  @override
  String routineGroupPickConfirmNew(int count) {
    return '把$count个组成分组';
  }

  @override
  String routineGroupPickConfirmAdd(int count) {
    return '放入$count个';
  }

  @override
  String get routineGroupCreateMenuTitle => '要制作什么？';

  @override
  String get routineGroupCreateRoutine => '制作新日常';

  @override
  String get routineGroupCreateGroup => '新建分组';

  @override
  String get routineGroupCreateGroupDescription => '把几个日常放进一个文件夹 (例如:早上上学)';

  @override
  String get routineGroupChooseTitle => '要放入哪个分组？';

  @override
  String routineGroupSheetCount(int count) {
    return '$count个日常';
  }

  @override
  String get routineGroupSheetAdd => '放入日常';

  @override
  String routineGroupSheetRemove(String title) {
    return '把$title移出分组';
  }

  @override
  String get routineGroupCreated => '已新建分组';

  @override
  String get routineGroupAdded => '已放入分组';

  @override
  String get routineGroupUngrouped => '已解散分组';

  @override
  String get routineGroupUngroupedEmpty => '日常都已移出，分组已解散';

  @override
  String routineGroupSent(String name) {
    return '已把$name分组作为今天的日常发送';
  }

  @override
  String get routineGroupAllSentAlready => '分组里的日常今天都已发送';

  @override
  String get routineGroupActionFailedTitle => '没能修改分组';

  @override
  String get routineGroupUngroupConfirmTitle => '要解散分组吗？';

  @override
  String get routineGroupUngroupConfirmMessage => '里面的日常会保留在日常管理里';

  @override
  String routineGroupRemoveConfirmTitle(String title) {
    return '要把$title移出分组吗？';
  }

  @override
  String get routineGroupRemoveConfirmMessage => '日常会保留在日常管理里';

  @override
  String get routineGroupRemoveConfirmAction => '移出';

  @override
  String childHomeGroupProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String get childHomeGroupAllDone => '都做完了！';

  @override
  String get routineTitleEdit => '修改日常名称';

  @override
  String get routineDetailMore => '更多';

  @override
  String get libraryArrangeDone => '完成';

  @override
  String get libraryArrangeRemove => '删除或解散分组';

  @override
  String get routineGroupEditOrder => '编辑';

  @override
  String get routineLibrarySendOnlyThis => '今天只发送这个日常';

  @override
  String routineGroupRowCardCount(int count) {
    return '$count张卡片';
  }

  @override
  String get routineManageCoachTapMessage => '*点一下*日常就能看卡片';

  @override
  String get routineManageCoachLongPressMessage => '长按后*松开*，就会打开菜单';

  @override
  String get routineManageCoachDragMessage =>
      '长按并*移动*，就会进入整理状态\n放到其他日常上会变成*分组*\n放到中间会换位置';

  @override
  String get cardReviewCoachEditMessage => '修改正在看的卡片的*文字和图片*\n图片也可以换成*自己的照片*';

  @override
  String get cardReviewCoachReorderMessage => '点这里后*长按并拖动*卡片\n就能调整顺序';

  @override
  String get cardReviewCoachSaveMessage => '改好后一定要点*保存卡片*\n点了才算完成日常';

  @override
  String get coachHelpLabel => '查看使用方法';

  @override
  String get pushPermissionSheetTitle => 'Elumi完成日常时要通知你吗？';

  @override
  String get pushPermissionSheetBody => '也会通知其他监护人的消息和积分提醒';

  @override
  String get pushPermissionAllow => '接收通知';

  @override
  String get pushPermissionLater => '以后再说';

  @override
  String get pushPermissionDenied => '随时可以在通知设置中开启';

  @override
  String get pushChannelGuardianUpdates => '监护人通知';

  @override
  String get pushPermissionNudgeTitle => '通知已关闭';

  @override
  String get pushPermissionNudgeBody => '开启后，Elumi完成日常时会马上通知你';

  @override
  String get pushPermissionElumiTitle => '有新日常时要通知你吗？';

  @override
  String get pushPermissionElumiBody => '监护人发来日常时，这台设备会收到通知';

  @override
  String get pushPermissionTurnOn => '开启通知';

  @override
  String get pushChannelElumiRoutines => '新日常通知';

  @override
  String get signInProviderKakao => 'Kakao';

  @override
  String get signInProviderNaver => 'Naver';

  @override
  String get signInProviderGoogle => 'Google';

  @override
  String get signInProviderApple => 'Apple';

  @override
  String get routineManageCoachSampleMorning => '早上准备';

  @override
  String get routineManageCoachSampleBrush => '刷牙';

  @override
  String get routineManageCoachSampleBag => '收拾书包';

  @override
  String get updateSuggestionTitle => '有新版本了';

  @override
  String get updateSuggestionBody => '更新后即可使用最新的修复和功能';

  @override
  String get updateSuggestionLater => '以后再说';

  @override
  String elumiInfoTitle(String name) {
    return '$name的信息';
  }

  @override
  String elumiInfoEditLabel(String name) {
    return '修改$name的信息';
  }

  @override
  String get elumiInfoName => '名字';

  @override
  String get elumiInfoCharacter => '角色';

  @override
  String get elumiInfoCharacterSheetTitle => '更换角色';

  @override
  String get elumiInfoImageStyleSheetTitle => '更换图片方式';

  @override
  String get elumiInfoSave => '保存';

  @override
  String get elumiInfoSaved => '已保存';

  @override
  String get elumiInfoSaveFailedTitle => '没能保存';

  @override
  String get elumiInfoSaveFailedFallback => '请稍后再试';

  @override
  String get elumiInfoNotFound => '没能加载Elumi的信息';

  @override
  String get talkTitle => '故事区';

  @override
  String get talkWriteButton => '发帖';

  @override
  String get talkCategoryAll => '全部';

  @override
  String get talkPopularTitle => '本周被拿走最多的日常';

  @override
  String talkPopularImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人拿走了',
    );
    return '$_temp0';
  }

  @override
  String get talkLatestTitle => '最新发布';

  @override
  String get talkEmptyTitle => '还没有人分享日常';

  @override
  String get talkEmptyCategoryTitle => '这个分类还没有人分享日常';

  @override
  String get talkEmptyCategoryAction => '查看全部';

  @override
  String get talkFeedFailed => '没能加载故事区';

  @override
  String get talkAuthorFallback => '监护人';

  @override
  String get talkShareTitleLabel => '日常标题';

  @override
  String get talkShareTitleHint => '请填写日常标题';

  @override
  String get talkNoteLabel => '内容';

  @override
  String talkHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有帮助 $count',
    );
    return '$_temp0';
  }

  @override
  String talkCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '评论 $count',
    );
    return '$_temp0';
  }

  @override
  String get talkLoadMoreRetry => '没能加载更多。点一下再试试';

  @override
  String talkDetailStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count张卡片',
    );
    return '$_temp0';
  }

  @override
  String get talkDetailLoadFailed => '没能加载帖子';

  @override
  String get talkPostGoneTitle => '这个帖子已无法查看';

  @override
  String get talkPostGoneBack => '返回故事区';

  @override
  String talkDetailCardCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count张',
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
  String get talkViewGrid => '一览';

  @override
  String get talkViewLarge => '放大看';

  @override
  String get talkHelpfulFailed => '没能修改“有帮助”。请稍后再试';

  @override
  String get talkImportButton => '拿来当日常';

  @override
  String get talkImportedButton => '✓ 已放入日常管理';

  @override
  String get talkShareLinkButton => '分享';

  @override
  String talkShareLinkMessage(String title, String url) {
    return '$title\n一起在elum故事区看看吧\n\n$url';
  }

  @override
  String get talkShareLinkFailed => '没能分享。请稍后再试';

  @override
  String get talkPostLinkRejectedOnElumiDevice => '故事区的帖子可以在监护人的设备上查看';

  @override
  String get talkImportSheetTitle => '拿来当日常';

  @override
  String get talkImportSheetHint => '加入日常后，可以按Elumi的情况修改';

  @override
  String get talkImportElumiLabel => 'Elumi';

  @override
  String get talkImportConfirm => '完成';

  @override
  String get talkImportNoElumiTitle => '请先连接Elumi';

  @override
  String get talkImportNoElumiAction => '连接Elumi';

  @override
  String talkImportDone(String routineTitle, String batchim) {
    return '已导入$routineTitle';
  }

  @override
  String get talkImportGoToLibrary => '去看看';

  @override
  String get talkImportFailedTitle => '没能放入日常管理';

  @override
  String get talkCommentsTitle => '评论';

  @override
  String get talkCommentsEmpty => '还没有评论';

  @override
  String talkCommentAuthorMine(String name) {
    return '$name(我)';
  }

  @override
  String talkCommentAuthorPostWriter(String name) {
    return '$name(发帖人)';
  }

  @override
  String get talkCommentHiddenNotice => '根据运营政策已隐藏';

  @override
  String get talkCommentsFailed => '没能加载评论';

  @override
  String get talkCommentHint => '留个评论吧';

  @override
  String get talkCommentSend => '发送';

  @override
  String get talkCommentSendFailedTitle => '没能发送评论';

  @override
  String get talkFailedFallback => '请稍后再试';

  @override
  String get talkCommentDeleteTitle => '要删除评论吗？';

  @override
  String get talkCommentDeleteAction => '删除';

  @override
  String get talkCommentDeleteFailedTitle => '没能删除评论';

  @override
  String get talkMenuReport => '举报';

  @override
  String get talkMenuBlock => '隐藏这位监护人的帖子';

  @override
  String get talkMenuEdit => '修改';

  @override
  String get talkMenuTakeDown => '下架';

  @override
  String get talkMoreLabel => '更多';

  @override
  String get talkTakeDownTitle => '要下架这个帖子吗？';

  @override
  String get talkTakeDownMessage => '下架的帖子其他监护人就看不到了。';

  @override
  String get talkTakeDownDone => '帖子已下架';

  @override
  String get talkTakeDownFailedTitle => '没能下架帖子';

  @override
  String get talkEditTitle => '修改帖子';

  @override
  String get talkEditSave => '保存';

  @override
  String get talkEditSaved => '已修改';

  @override
  String get talkEditFailedTitle => '没能修改帖子';

  @override
  String get talkNoteGuide => '请不要写别人的名字、联系方式等个人信息';

  @override
  String get talkCategoryTitle => '分类';

  @override
  String get talkReportTitle => '举报';

  @override
  String get talkReportSubmit => '举报';

  @override
  String get talkReportDone => '已举报';

  @override
  String get talkReportFailedTitle => '没能举报';

  @override
  String get talkReportReasonPersonalInfo => '能看到Elumi或家人的信息';

  @override
  String get talkReportReasonOffensive => '有让人不舒服的话';

  @override
  String get talkReportReasonAdvertising => '是广告或宣传';

  @override
  String get talkReportReasonOther => '其他原因';

  @override
  String talkBlockTitle(String nickname) {
    return '要隐藏$nickname的帖子吗？';
  }

  @override
  String get talkBlockMessage =>
      '你将看不到这位监护人的帖子和评论。对方不会知道。可以在“我的信息 › 已隐藏的监护人”中重新查看。';

  @override
  String get talkBlockAction => '隐藏';

  @override
  String get talkBlockDone => '已隐藏';

  @override
  String get talkBlockFailedTitle => '没能隐藏';

  @override
  String get talkBlockedGuardiansTitle => '已隐藏的监护人';

  @override
  String get talkBlockedGuardiansEmpty => '没有已隐藏的监护人';

  @override
  String get talkBlockedGuardiansFailed => '没能加载已隐藏的监护人';

  @override
  String get talkUnblockAction => '重新查看';

  @override
  String get talkUnblockDone => '可以重新查看了';

  @override
  String get talkUnblockFailedTitle => '没能取消隐藏';

  @override
  String get talkRulesTitle => '故事区使用规则';

  @override
  String get talkRulesIntro => '为了让监护人之间安全地分享，请遵守这三条。';

  @override
  String get talkRulesPrivacy => '请不要露出脸、名字、学校、家庭住址';

  @override
  String get talkRulesRespect => '请尊重其他监护人。不能指责、打广告或做宣传';

  @override
  String get talkRulesNoDiagnosis => '请不要写诊断名称或医院信息';

  @override
  String get talkRulesAgreeCheck => '我已阅读以上规则，会遵守';

  @override
  String get talkRulesAgreeButton => '同意并继续';

  @override
  String get talkRulesFailedTitle => '没能保存同意';

  @override
  String get talkShareTitle => '发到故事区';

  @override
  String get talkSharePickTitle => '要分享哪个日常？';

  @override
  String get talkSharePickEmpty => '没有可以发布的日常';

  @override
  String get talkSharePickEmptyHint =>
      '只能发布日常管理里自己的日常。已经发布过的、从故事区拿来的日常不包括在内。示例日常修改标题或卡片后就可以发布。';

  @override
  String get talkSharePickFailed => '没能加载日常';

  @override
  String get talkSharePreviewFailed => '没能加载要发布的内容';

  @override
  String get talkSharePhotoTitle => '照片要怎么发布？';

  @override
  String get talkSharePhotoGuide => '如果能看到脸、名字、家庭住址，请模糊处理。\nAI做的图片会原样发布';

  @override
  String get talkSharePhotoBlur => '模糊';

  @override
  String get talkSharePhotoKeep => '原样';

  @override
  String get talkSharePhotoNext => '下一步';

  @override
  String get talkSharePreviewTitle => '会显示成这样';

  @override
  String get talkShareSubmit => '发布';

  @override
  String get talkShareDone => '已发到故事区';

  @override
  String get talkShareFailedTitle => '没能发布';

  @override
  String get talkShareHint => '📖 分享到故事区 ›';

  @override
  String get talkMenuShare => '分享到故事区';

  @override
  String get talkMyPostsTitle => '我的帖子';

  @override
  String get talkMyPostsEmpty => '还没有帖子';

  @override
  String get talkMyPostsEmptyAction => '在故事区分享日常';

  @override
  String get talkMyPostsFailed => '没能加载我的帖子';

  @override
  String get talkMenuViewMyPost => '查看我的帖子';

  @override
  String get talkLinkSend => '用链接发送';

  @override
  String get talkLinkTurnOff => '关闭链接';

  @override
  String get talkLinkConfirmTitle => '要用链接发送这个日程吗？';

  @override
  String get talkLinkConfirmGuide => '只有收到链接的人才能看到，不会发到故事区。\n发送后也可以在日程管理里关闭链接';

  @override
  String get talkLinkResendGuide =>
      '已经发送过链接。会按第一次发送时的样子再次发送同一个链接。\n要发送修改后的内容，请先关闭链接再重新发送';

  @override
  String get talkLinkPhotoTitle => '照片要怎么发送？';

  @override
  String get talkLinkPhotoGuide => '如果能看到脸、名字或住址，请模糊处理。\nAI生成的图片会原样显示';

  @override
  String get talkLinkCreateButton => '生成链接';

  @override
  String get talkLinkPreviewFailed => '无法加载要发送的内容';

  @override
  String get talkLinkCreateFailedTitle => '无法生成链接';

  @override
  String get talkLinkCreated => '已生成链接';

  @override
  String talkLinkShareMessage(String title, String url) {
    return '$title\n在elum里把这个日程拿去用吧\n\n$url';
  }

  @override
  String get talkLinkTurnOffTitle => '要关闭链接吗？';

  @override
  String get talkLinkTurnOffMessage => '收到链接的人将无法再查看。已经拿去的日程会保留';

  @override
  String get talkLinkTurnOffDone => '已关闭链接';

  @override
  String get talkLinkTurnOffFailedTitle => '无法关闭链接';

  @override
  String get talkLinkReceivedTitle => '收到的日程';

  @override
  String get timeAgoJustNow => '刚刚';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count分钟前',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count小时前',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count天前',
    );
    return '$_temp0';
  }

  @override
  String routineProgressRingPercentLabel(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get routineProgressRingDoneLabel => '全部完成';

  @override
  String get guardianSettingsLicenses => '开源许可';

  @override
  String get licenseScreenTitle => '开源许可';

  @override
  String get licenseScreenGuide => 'elum使用了下面的图片、字体和程序。点一下项目可以查看许可全文。';

  @override
  String get licenseGroupArtwork => '图片';

  @override
  String get licenseGroupFonts => '字体';

  @override
  String get licenseGroupSoftware => '程序';

  @override
  String get licenseSoftwareListRow => '查看程序列表';

  @override
  String get licenseFontTmoneyName => 'Tmoney RoundWind';

  @override
  String get licenseLoadFailedMessage => '没能加载列表';

  @override
  String get cardExportOpen => '下载打印版';

  @override
  String get cardExportFormatSection => '要怎么下载？';

  @override
  String get cardExportFormatRoutineSheet => '一页日常';

  @override
  String get cardExportFormatRoutineSheetCaption => '按顺序放在一张A4纸上';

  @override
  String get cardExportFormatCutCards => '剪下来用的卡片';

  @override
  String get cardExportFormatCutCardsCaption => 'A4纸上带裁剪线';

  @override
  String get cardExportFormatCardImages => '每张卡片单独一张';

  @override
  String get cardExportFormatCardImagesCaption => '每张卡片一张图片';

  @override
  String get cardExportPerPageSection => '每页放几张？';

  @override
  String get cardExportIncludeText => '加入卡片文字';

  @override
  String get cardExportThemeSection => '卡片设计';

  @override
  String get cardExportThemeBasic => '基本';

  @override
  String get cardExportThemeSimple => '简洁';

  @override
  String get cardExportThemeInkSaver => '省墨';

  @override
  String get cardExportThemeMonochrome => '黑白';

  @override
  String get cardExportThemeLargeText => '大字';

  @override
  String get planProBadge => 'PRO';

  @override
  String get cardExportProThemeLocked => '这是Pro可以使用的设计';

  @override
  String get cardExportWatermarkNotice => 'Free版底部会加上elum标志条';

  @override
  String get cardExportPreviewSection => '预览';

  @override
  String get cardExportMissingPicture => '还没有图片的卡片只放标题';

  @override
  String cardExportSomePicturesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有$count张卡片没能加载图片，会用其他图片或标题代替',
    );
    return '$_temp0';
  }

  @override
  String get cardExportActualSizeHint => '在其他应用中打印时，请选择实际大小';

  @override
  String get cardExportPrint => '打印';

  @override
  String get cardExportShare => '发送';

  @override
  String get cardExportPreparing => '正在准备卡片';

  @override
  String get cardExportImageFailed => '没能加载卡片图片';

  @override
  String get cardExportRenderFailed => '没能生成打印文件';

  @override
  String get cardExportPrintFailed => '这台设备无法打印。请用发送来下载';

  @override
  String get cardExportNoCards => '这个日常没有卡片';

  @override
  String get cardExportNoneSelected => '请至少选择一张要发送的卡片';

  @override
  String get printBrandTagline => '一起过好每一天 | elum 行为卡片';

  @override
  String get cardExportPictogramCredit => '图片: Mulberry Symbols (CC BY-SA 4.0)';

  @override
  String get cardExportEmojiCredit => '图片: Twemoji (CC BY 4.0)';

  @override
  String cardExportPerPage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count张',
    );
    return '$_temp0';
  }

  @override
  String get cardExportFormatRow => '形式';

  @override
  String get cardExportLayoutSection => '排版';

  @override
  String get cardExportStyleSection => '装饰';

  @override
  String get cardExportOrientationRow => '纸张方向';

  @override
  String get cardExportOrientationSheetTitle => '纸张要怎么放？';

  @override
  String get cardExportOrientationPortrait => '纵向';

  @override
  String get cardExportOrientationLandscape => '横向';

  @override
  String get cardExportPerPageRow => '每页';

  @override
  String get cardExportCardSizeRow => '卡片大小';

  @override
  String get cardExportCardSizeSheetTitle => '卡片要放多大？';

  @override
  String get cardExportCardSizeFit => '铺满';

  @override
  String get cardExportCardSizeMedium => '中等';

  @override
  String get cardExportCardSizeSmall => '小';

  @override
  String get cardExportProLayoutLocked => '这是Pro可以使用的形式';

  @override
  String get cardExportUpsellTitle => '有Pro就能按想要的方式下载';

  @override
  String get cardExportUpsellBody => '一页日常、剪下来用的卡片、一页多张、横向纸张，连设计都能选';

  @override
  String get modeSwitchToPurchase => '只有监护人可以付款';

  @override
  String get planBenefitAiImageStyles => 'AI为每张卡片画图';

  @override
  String get planBenefitAdsRemoved => '无广告使用';

  @override
  String get planBenefitWeeklyReport => '接收每周报告';

  @override
  String get planBenefitRoutineSchedule => '定好星期和时间，每天发送';

  @override
  String get planBenefitRoutineMemory => '记住我修改的方式';

  @override
  String get planBenefitGuardianVoice => '用监护人的声音朗读卡片';

  @override
  String get planBenefitFreeRoutineText => '日常文字不用积分';

  @override
  String get planBenefitFreeImageRegenerate => '每天在规定次数内不用积分重新画图';

  @override
  String planBenefitFreeImageRegenerateDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每天最多$count次不用积分重新画图',
    );
    return '$_temp0';
  }

  @override
  String get planBenefitMoreWeeklyCredits => '每周获得更多积分';

  @override
  String get planBenefitMoreMonthlyCredits => '每月获得更多积分';

  @override
  String get planBenefitCardExportWithoutWatermark => '打印件底部没有标志条，干净整洁';

  @override
  String get planBenefitCardExportAllThemes => '可以选择所有打印设计';

  @override
  String get planBenefitCardExportAllLayouts => '可以打印一页日常、剪下来用的卡片';

  @override
  String get planKeepContentNotice => 'Pro结束后，做好的日常和图片也会保留';

  @override
  String get planPeriodMonthly => '1个月';

  @override
  String get planPeriodYearly => '1年';

  @override
  String get planSubscribe => '开始订阅';

  @override
  String get planPriceLoading => '正在加载价格';

  @override
  String get planPriceFailed => '没能加载价格';

  @override
  String get planRestore => '恢复购买';

  @override
  String get planTermsOfUse => '使用条款';

  @override
  String get planPrivacyPolicy => '隐私政策';

  @override
  String get planManageSubscription => '管理订阅';

  @override
  String get planLegalBillingAppStore =>
      '确认购买时将从Apple ID账户扣款。如果在当前周期结束前至少24小时未取消，订阅将按相同周期和价格自动续订，并在周期结束前24小时内收取下一期费用。';

  @override
  String get planLegalCancelAppStore =>
      '可以在设备设置的Apple ID > 订阅中管理和取消订阅。取消后，剩余期间内仍可使用Pro。';

  @override
  String get planLegalBillingPlayStore =>
      '确认购买时将从Google Play账户扣款。在取消之前，订阅将按相同周期和价格自动续订。';

  @override
  String get planLegalCancelPlayStore =>
      '可以在Google Play商店的付款和订阅 > 订阅中管理和取消订阅。取消后，剩余期间内仍可使用Pro。';

  @override
  String planTrialDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count天',
    );
    return '$_temp0';
  }

  @override
  String planTrialMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个月',
    );
    return '$_temp0';
  }

  @override
  String planTrialYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count年',
    );
    return '$_temp0';
  }

  @override
  String planStartFreeTrial(String trial) {
    return '免费开始$trial';
  }

  @override
  String get planLegalTrialAppStore => '如果在免费体验结束前至少24小时取消，就不会收费。';

  @override
  String get planLegalTrialPlayStore => '在免费体验期间取消，就不会收费。';

  @override
  String get planVerifying => '正在确认付款';

  @override
  String get planStorePendingTitle => '已请求付款许可';

  @override
  String get planStorePendingBody => '获得许可后Pro就会开启。可以关闭这个页面。';

  @override
  String get planVerificationPendingTitle => '正在确认付款';

  @override
  String get planVerificationPendingBody => '不用再付款。重新打开应用时会再确认一次';

  @override
  String get planVerificationRetry => '再次确认';

  @override
  String get planActivatedStart => '开始';

  @override
  String get planActivatedTitle => '已开始使用Pro';

  @override
  String get planNotActivatedTitle => 'Pro还没有开启';

  @override
  String get planNotActivatedBodyApple =>
      '请在App Store应用 → 右上角我的头像 → 订阅中确认elum订阅';

  @override
  String get planNotActivatedBodyGoogle =>
      '请在Play商店应用 → 右上角个人资料 → 付款和订阅 → 订阅中确认elum订阅';

  @override
  String get planOpenAppStore => '在App Store中确认';

  @override
  String get planOpenPlayStore => '在Play商店中确认';

  @override
  String get planAlreadyProTitle => '正在使用Pro';

  @override
  String get planPurchaseFailedTitle => '没能付款';

  @override
  String get planVerifyFailedTitle => '没能把付款关联到这个账号';

  @override
  String get planAccountFailedTitle => '没能确认账号信息';

  @override
  String get planFailedFallback => '请稍后再试';

  @override
  String get planRestoreDone => '已找回Pro';

  @override
  String get planRestoreNothing => '没有可以恢复的订阅';

  @override
  String get planRestoreNothingHintApple =>
      '请确认这台设备登录的是订阅时用的Apple ID。elum也要用订阅时的同一种方式登录';

  @override
  String get planRestoreNothingHintGoogle =>
      '请确认Play商店登录的是订阅时用的Google账号。elum也要用订阅时的同一种方式登录';

  @override
  String get planRestoreFailedTitle => '没能恢复购买';

  @override
  String get planRestoring => '正在确认购买记录';

  @override
  String get planManageFailed => '没能打开订阅管理页面';

  @override
  String get planLinkFailed => '没能打开链接';

  @override
  String get planSettingsLabel => '我的套餐';

  @override
  String get planStatusFree => 'Free';

  @override
  String get planStatusPro => 'Pro';

  @override
  String planStatusRenewing(String date) {
    return 'Pro,$date续订';
  }

  @override
  String planStatusUntil(String date) {
    return 'Pro，到$date';
  }

  @override
  String planStatusCancelScheduled(String date) {
    return 'Pro,$date结束';
  }

  @override
  String get planStatusGracePeriod => 'Pro，需要确认付款';

  @override
  String planStatusTrial(int days) {
    return 'Pro体验中，还剩$days天';
  }

  @override
  String get planStatusTrialLastDay => 'Pro体验中，今天截止';

  @override
  String get planStatusGift => 'Pro礼物';

  @override
  String planStatusGiftUntil(String date) {
    return 'Pro礼物，到$date';
  }

  @override
  String planStatusRenewingFooter(String date) {
    return '$date续订';
  }

  @override
  String planStatusUntilFooter(String date) {
    return '可以用到$date';
  }

  @override
  String planStatusCancelScheduledFooter(String date) {
    return '$date结束';
  }

  @override
  String get planStatusGracePeriodFooter => '请确认付款方式';

  @override
  String get planSheetNextPaymentLabel => '下次付款日';

  @override
  String get planSheetEndDateLabel => '结束日期';

  @override
  String get planSheetStoreLabel => '付款渠道';

  @override
  String get planSheetStoreAppStore => 'App Store';

  @override
  String get planSheetStoreGooglePlay => 'Google Play';

  @override
  String planSheetRenewingNote(String date) {
    return '如果不取消，将在$date自动付款。可以在管理订阅中取消';
  }

  @override
  String get planSheetEndsToFreeNote => '结束后会变为Free。不会自动付款';

  @override
  String get planSheetUnlimitedNote => '可以不限期使用Pro';

  @override
  String get planLearnPro => '了解Pro';

  @override
  String get weeklyReportTitle => '每周报告';

  @override
  String weeklyReportWeekRange(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 ~ $endMonth月$endDay日';
  }

  @override
  String weeklyReportThisWeekRange(String range) {
    return '本周 · $range';
  }

  @override
  String get weeklyReportPreviousWeek => '查看上周';

  @override
  String get weeklyReportNextWeek => '查看下周';

  @override
  String get weeklyReportCompletionLabel => '日常完成率';

  @override
  String weeklyReportPercent(int percent) {
    return '$percent%';
  }

  @override
  String weeklyReportCompletionSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '发送的$sent个日常中完成了$completed个',
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
  String get weeklyReportStars => '获得的星星';

  @override
  String get weeklyReportRewards => '获得奖励的日常';

  @override
  String get weeklyReportStreak => '连续完成的天数';

  @override
  String weeklyReportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count天',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRoutinesSection => '各日常记录';

  @override
  String weeklyReportRoutineValue(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent次中完成$completed次',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRemainingSection => '常常没做完的卡片';

  @override
  String weeklyReportRemainingLabel(String routine, String step) {
    return '$routine · $step';
  }

  @override
  String weeklyReportTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count次',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportEmptyTitle => '这一周没有发送日常';

  @override
  String get weeklyReportEmptyBody => '发送日常后，Elumi完成的记录会汇集在这里';

  @override
  String get weeklyReportNoCompletionThisWeekTitle => '本周还没有记录';

  @override
  String get weeklyReportNoCompletionPastWeekTitle => '这一周没有完成的日常';

  @override
  String get weeklyReportNoCompletionBody => '要发送今天的日常吗？';

  @override
  String get weeklyReportGoToManage => '去日常管理';

  @override
  String get weeklyReportLoadFailed => '没能加载每周报告';

  @override
  String get weeklyReportNotIncluded => '每周报告可以在Pro中查看';

  @override
  String get weeklyReportShareImage => '图片';

  @override
  String get weeklyReportSharePdf => 'PDF';

  @override
  String get weeklyReportShareFailed => '没能生成要发送的页面';

  @override
  String weeklyReportShareTitle(String name, String batchim) {
    return '$name的一周';
  }

  @override
  String get weeklyReportShareNote => '根据elum应用中的完成记录统计';

  @override
  String get weeklyReportRecordSection => '一周记录';

  @override
  String get weeklyReportDonutLabel => '完成率';

  @override
  String weeklyReportDonutSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent个日程中完成了$completed个',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDonutSemantics(int percent, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '完成率百分之$percent，$sent个日程中完成了$completed个',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportDaysSection => '按星期记录';

  @override
  String weeklyReportDayBarSemantics(String weekday, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$weekday：$sent个日程中完成了$completed个',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDayBarEmptySemantics(String weekday) {
    return '$weekday：没有发送日程';
  }

  @override
  String get weeklyReportTrendSection => '与过去几周对比';

  @override
  String weeklyReportTrendWeekLabel(int month, int day) {
    return '$month/$day';
  }

  @override
  String weeklyReportTrendPointSemantics(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$month月$day日这一周完成了$count个日程',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportInsightHighlightTitle => '做得好的地方';

  @override
  String weeklyReportInsightHighlightFirst(String routine, String batchim) {
    return '本周第一次把$routine做完了';
  }

  @override
  String weeklyReportInsightHighlightEvery(
    String routine,
    String batchim,
    int count,
  ) {
    return '$routine$count次全都做完了';
  }

  @override
  String weeklyReportInsightHighlightStreak(int days) {
    return '连续$days天完成了日常';
  }

  @override
  String weeklyReportInsightHighlightHint(String name) {
    return '今天告诉$name吧';
  }

  @override
  String get weeklyReportInsightStuckTitle => '常常停下的地方';

  @override
  String weeklyReportInsightStuckLine(
    String routine,
    String step,
    int sent,
    int remained,
  ) {
    return '$routine的$step,$sent次中停下了$remained次';
  }

  @override
  String get weeklyReportInsightStuckShorten => '可以把卡片文字改短一些，或者分成两张';

  @override
  String get weeklyReportInsightStuckAddMedia => '可以加上声音或照片试试';

  @override
  String weeklyReportInsightStuckFix(String step) {
    return '修改$step卡片';
  }

  @override
  String get weeklyReportInsightStuckFixFailed => '没能打开要修改的日常';

  @override
  String get weeklyReportInsightTrendTitle => '和上周比的变化';

  @override
  String weeklyReportInsightTrendUp(int before, int after) {
    return '完成的日常从$before个增加到$after个';
  }

  @override
  String weeklyReportInsightTrendDown(int before, int after) {
    return '完成的日常从$before个变为$after个';
  }

  @override
  String weeklyReportInsightTrendSame(int after) {
    return '和上周一样完成了$after个';
  }

  @override
  String weeklyReportInsightTrendBarPrevious(int count) {
    return '上周 $count';
  }

  @override
  String weeklyReportInsightTrendBarCurrent(int count) {
    return '本周 $count';
  }

  @override
  String get weeklyReportInsightDurationTitle => '花费的时间';

  @override
  String weeklyReportInsightDurationLine(
    String routine,
    int before,
    int after,
  ) {
    return '$routine花费的时间从$before分钟变为$after分钟';
  }

  @override
  String get weeklyReportInsightSlowestTitle => '停留最久的卡片';

  @override
  String weeklyReportInsightSlowestLine(
    String routine,
    String step,
    int minutes,
  ) {
    return '在$routine的$step平均停留了$minutes分钟';
  }

  @override
  String get weeklyReportStatCompleted => '完成的日常';

  @override
  String get weeklyReportStatRemaining => '还没做的卡片';

  @override
  String weeklyReportRoutineRatio(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent次中$completed次',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportSave => '保存报告';

  @override
  String get weeklyReportSaveSheetTitle => '要怎么保存报告？';

  @override
  String get weeklyReportPastReports => '查看过去的报告';

  @override
  String get weeklyReportPastSheetTitle => '过去的报告';

  @override
  String weeklyReportPastWeekValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '完成了$count个日常',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportPastEmpty => '还没有过去的报告';

  @override
  String get weeklyReportPastLoadFailed => '没能加载过去的报告';

  @override
  String get weeklyReportFreePreviewNote => '第一份报告不用Pro也能预览';

  @override
  String get weeklyReportNextWeekUpsell => '下周的报告也来看看';

  @override
  String get routineScheduleRowOff => '设置星期和时间';

  @override
  String get routineScheduleRowLabel => '重复的星期和时间';

  @override
  String routineScheduleSummary(String days, String time) {
    return '$days $time';
  }

  @override
  String get routineScheduleEveryDay => '每天';

  @override
  String get routineScheduleWeekdaysOnly => '工作日';

  @override
  String get routineScheduleWeekendOnly => '周末';

  @override
  String get routineScheduleDaySeparator => '·';

  @override
  String get routineSchedulePaused => 'Pro已结束，已暂停';

  @override
  String get routineSchedulePausedNote => 'Pro已结束，重复已暂停。设置好的星期和时间仍然保留';

  @override
  String get routineScheduleSheetTitle => '什么时候做？';

  @override
  String get routineScheduleSheetBody => '在选好的每个星期几，这个日常会成为今天的日常';

  @override
  String get routineScheduleDaysLabel => '星期';

  @override
  String get routineScheduleTimeLabel => '时间';

  @override
  String get routineScheduleNotifyElumi => '到时间通知Elumi的设备';

  @override
  String get routineScheduleElumiNotificationOff => 'Elumi设备的通知已关闭';

  @override
  String get routineScheduleElumiNotificationOffHint => '请在Elumi设备的设置中开启elum通知';

  @override
  String get routineScheduleElumiNoDevice => '连接Elumi的设备后，到时间会收到通知';

  @override
  String get routineScheduleSave => '保存';

  @override
  String get routineScheduleTurnOff => '关闭重复';

  @override
  String get routineScheduleSavedToast => '已保存星期和时间';

  @override
  String get routineScheduleTurnedOffToast => '已关闭重复';

  @override
  String get routineScheduleSaveFailedTitle => '没能保存';

  @override
  String get routineScheduleSaveFailedFallback => '请稍后再试';

  @override
  String get routineSchedulePickDayHint => '请至少选择一天';

  @override
  String get routineScheduleProNote => '重复日常可以在Pro中保存';

  @override
  String get weeklyPlanEntry => '每周计划';

  @override
  String get weeklyPlanTitle => '每周计划';

  @override
  String weeklyPlanDayTitle(String weekday) {
    return '$weekday';
  }

  @override
  String get weeklyPlanToday => '今天';

  @override
  String get weeklyPlanEmptyDay => '没有安排的日常';

  @override
  String get weeklyPlanEmptyTitle => '还没有设置星期的日常';

  @override
  String get weeklyPlanEmptyBody => '在日常管理中点一个日常，设置星期和时间吧';

  @override
  String get weeklyPlanLoadFailed => '没能加载每周计划';

  @override
  String get weeklyPlanNotifyOff => '无通知';

  @override
  String get weeklyPlanMetaSeparator => ' · ';

  @override
  String get guardianVoiceRecordAction => '用我的声音录音';

  @override
  String get guardianVoiceRecordHint => '点卡片时会播放这个声音';

  @override
  String guardianVoiceRecording(int seconds) {
    return '正在录音 $seconds秒';
  }

  @override
  String guardianVoiceRecordingLimit(int seconds) {
    return '最多可录$seconds秒';
  }

  @override
  String get guardianVoiceStop => '停止';

  @override
  String get guardianVoiceSaving => '正在保存录音';

  @override
  String get guardianVoiceSaved => '已录音';

  @override
  String get guardianVoicePlay => '播放';

  @override
  String get guardianVoiceRerecord => '重新录音';

  @override
  String get guardianVoiceDelete => '删除';

  @override
  String get guardianVoiceDeleteConfirmTitle => '要删除录音吗？';

  @override
  String get guardianVoiceDeleteConfirmMessage => '删除后会用默认声音朗读';

  @override
  String get guardianVoicePlanEnded => '用默认声音朗读';

  @override
  String get guardianVoiceMicDeniedTitle => '麦克风已关闭';

  @override
  String get guardianVoiceMicDeniedBody => '开启之前会用默认声音朗读';

  @override
  String get guardianVoiceOpenSettings => '打开设置';

  @override
  String get guardianVoiceFailedTitle => '没能保存录音';

  @override
  String get guardianVoiceRetry => '再试一次';

  @override
  String get guardianVoiceTooShort => '太短了。说完后再点停止';

  @override
  String get guardianVoiceRecordFailed => '没能录音。请再试一次';

  @override
  String get guardianVoiceTooLarge => '录音文件太大了。请录短一点再试';

  @override
  String get guardianVoicePlayFailed => '没能播放录音';

  @override
  String get guardianVoiceDeleteFailed => '没能删除录音';

  @override
  String get guardianVoiceRecordChip => '录音';

  @override
  String get guardianVoicePlanEndedHint => 'Pro结束后录音也会保留';

  @override
  String get guardianSettingsRoutineMemory => 'AI记忆';

  @override
  String memoryHeroTitle(String name) {
    return '$name的AI记忆';
  }

  @override
  String get memoryHeroBody => '记住你修改的方式，下次就按这个方式制作日常。只有你能看到';

  @override
  String get memoryStatApplied => '使用中';

  @override
  String get memoryStatWatching => '观察中';

  @override
  String get memoryStatEdits => '修改记录';

  @override
  String get memoryListAppliedHeader => '使用中的规则';

  @override
  String get memoryListAppliedHint => '会用于新日常';

  @override
  String get memoryListWatchingHeader => '观察中的规则';

  @override
  String get memoryListWatchingHint => '圆点填满后就会使用';

  @override
  String get memoryListEditsHeader => '修改后发送的记录';

  @override
  String memoryRuleByAi(int count) {
    return 'AI发现，$count个日常';
  }

  @override
  String get memoryRuleByMe => '我写的';

  @override
  String memoryEditCards(int before, int after) {
    return '$before张 → $after张';
  }

  @override
  String memoryEditTexts(int count) {
    return '文字$count处';
  }

  @override
  String get memoryAddRule => '+ 自己写规则';

  @override
  String get memoryAutoFind => '从修改内容中自动发现';

  @override
  String memoryAutoFindNote(int count) {
    return '同样的修改在$count个日常中重复后就会使用';
  }

  @override
  String get memoryEmptyTitle => '修改日常后发送，就会积累在这里';

  @override
  String get memoryEmptyEdits => '还没有修改后发送的日常';

  @override
  String get memoryTypeWord => '替换词语';

  @override
  String get memoryTypeSplit => '拆分卡片';

  @override
  String get memoryTypeMerge => '合并卡片';

  @override
  String get memoryTypeAdd => '添加卡片';

  @override
  String get memoryTypeRemove => '去掉卡片';

  @override
  String get memoryTypeManual => '自己写的规则';

  @override
  String get memoryApplyNow => '立即使用';

  @override
  String get memoryRuleDelete => '删除';

  @override
  String get memoryRuleEdit => '修改';

  @override
  String memoryEvidenceLine(String routine, int month, int day) {
    return '$routine,$month月$day日';
  }

  @override
  String get memoryMenuLabel => '菜单';

  @override
  String get memoryMenuExport => '导出为文件';

  @override
  String get memoryMenuClear => '清除全部记忆';

  @override
  String get memoryExportFailed => '没能导出记忆';

  @override
  String get memoryObsTitle => 'AI记忆';

  @override
  String get memoryObsWord => '你这样替换了词语';

  @override
  String get memoryObsSplit => '你拆分了卡片';

  @override
  String get memoryObsMerge => '你合并了卡片';

  @override
  String get memoryObsAdd => '你添加了卡片';

  @override
  String get memoryObsRemove => '你去掉了卡片';

  @override
  String get memoryObsManual => '你这样修改了';

  @override
  String memoryObsAsk(String phrase) {
    return '$phrase。下一个日常也这样做吗？';
  }

  @override
  String get memoryObsAlways => '一直这样';

  @override
  String get memoryObsOnce => '只这一次';

  @override
  String get memoryObsDone => '从下一个日常开始就这样制作';

  @override
  String memoryObsMore(int count) {
    return '在AI记忆中再看$count个';
  }

  @override
  String memoryAppliedPill(int count) {
    return '已使用$count条AI记忆规则';
  }

  @override
  String get routineMemoryAddSheetTitle => '添加备注';

  @override
  String get routineMemoryEditSheetTitle => '修改备注';

  @override
  String get routineMemoryLineHint => '例:用“擦手”代替“洗漱”';

  @override
  String get routineMemorySave => '保存';

  @override
  String get routineMemoryDeleteLine => '删除这一行';

  @override
  String get routineMemoryClearConfirmTitle => '要删除全部备注吗？';

  @override
  String get routineMemoryClearConfirmMessage => '删除的备注无法恢复。';

  @override
  String get routineMemoryClearConfirmAction => '全部删除';

  @override
  String get routineMemoryLoadFailed => '没能加载备注';

  @override
  String get routineMemorySaveFailedTitle => '没能保存备注';

  @override
  String get routineMemorySaveFailedFallback => '请稍后再试。';

  @override
  String get proTeaserSampleLabel => '示例画面';

  @override
  String get proOnlyNoticeTitle => '这是Pro可以使用的功能';

  @override
  String get proOnlyFreeAlternative => '现在在用的功能可以照常使用';

  @override
  String get proOnlyFreeAlternativeAiImage => '现在可以用默认图片或照片制作卡片';

  @override
  String get proOnlyFreeAlternativeSchedule => '现在可以自己发送日常';

  @override
  String get proOnlyFreeAlternativeVoice => '现在会用默认声音朗读卡片';

  @override
  String get proOnlyFreeAlternativeCardSplit => '现在可以自己添加卡片来拆分';

  @override
  String get proOnlyFreeAlternativeCardExport => '现在可以用基本设计打印';

  @override
  String get proTeaserWeeklyReportBenefit => '可以把一周完成的日常整理成一页发送';

  @override
  String get proTeaserRoutineMemoryBenefit => '记住你修改的方式，让下一个日常更合适';

  @override
  String get proTeaserCardThemeBenefit => '可以下载多种设计的打印卡片';

  @override
  String get proTeaserWeeklyPlanBenefit => '不用每天早上重新发送日常';

  @override
  String get proTeaserSampleRoutineMorning => '早上准备';

  @override
  String get proTeaserSampleRoutineBrush => '刷牙';

  @override
  String get proTeaserSampleRoutineBag => '收拾书包';

  @override
  String get proTeaserSampleStepSocks => '穿袜子';

  @override
  String get proTeaserSampleMemoryShort => '卡片文字写成简短的一行';

  @override
  String get proTeaserSampleMemoryOrder => '穿衣服从袜子开始';

  @override
  String get proTeaserSampleMemoryReward => '奖励定为贴纸';

  @override
  String get cardRegenerateChip => '重新画';

  @override
  String get cardRegenerateSheetTitle => '要重新画图片吗？';

  @override
  String cardRegenerateCostProFree(int count) {
    return '不用积分，今天还剩$count次';
  }

  @override
  String get cardRegenerateCostFree => '不使用积分';

  @override
  String cardRegenerateCostCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个积分',
    );
    return '$_temp0';
  }

  @override
  String cardRegenerateCostProUsedUp(int credits, int freeCount) {
    String _temp0 = intl.Intl.pluralLogic(
      credits,
      locale: localeName,
      other: '今天的$freeCount次免费已用完，将使用$credits个积分',
    );
    return '$_temp0';
  }

  @override
  String cardRegenerateProFact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pro每天可免费重新画$count次',
    );
    return '$_temp0';
  }

  @override
  String cardAddImageCost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '画AI图片会使用$count个积分',
    );
    return '$_temp0';
  }

  @override
  String questionCreditCostLine(String costs, int available) {
    String _temp0 = intl.Intl.pluralLogic(
      available,
      locale: localeName,
      other: '$costs，现在有$available个',
    );
    return '$_temp0';
  }

  @override
  String creditCostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个',
    );
    return '$_temp0';
  }

  @override
  String get cardRegenerateCostUnknown => '会使用积分';

  @override
  String get cardRegenerateConfirm => '重新画';

  @override
  String get cardRegenerateInProgress => '正在重新画图片';

  @override
  String get cardRegenerateFailedTitle => '没能重新画图片';

  @override
  String get cardFirstDrawChip => '画AI图片';

  @override
  String get cardRedrawProChip => '用Pro重新画';

  @override
  String get cardFirstDrawProChip => '用Pro画AI图片';

  @override
  String get cardFirstDrawSheetTitle => '要画AI图片吗？';

  @override
  String get cardRedrawSheetBody => '请写下或选择想修改的地方。留空就按原样重新画';

  @override
  String get cardFirstDrawSheetBody => '请写下或选择想要的效果。看到新图片后可以再选';

  @override
  String get cardRedrawRequestLabel => '想修改的地方';

  @override
  String get cardRedrawRequestHint => '例:把雨伞改成蓝色';

  @override
  String get cardRedrawHintSimpler => '更简单';

  @override
  String get cardRedrawHintNoBackground => '去掉背景';

  @override
  String get cardRedrawHintNoPeople => '去掉人物';

  @override
  String get cardRedrawHintBrighter => '更明亮';

  @override
  String get cardFirstDrawConfirm => '画图';

  @override
  String get cardFirstDrawInProgress => '正在画图片';

  @override
  String get cardFirstDrawFailedTitle => '没能画AI图片';

  @override
  String get cardRedrawFailedFallback => '要再试一次吗？积分没有被使用';

  @override
  String get cardCandidateFailedFallback => '新图片已经画好，用掉的积分不会退还。请稍后再试';

  @override
  String get cardCandidateSheetTitle => '要用哪张图片？';

  @override
  String get cardCandidateSheetBody => '只有选中的图片会给Elumi看\n不管选哪张，用掉的积分都不会退还';

  @override
  String get cardCandidateCurrentLabel => '现在的图片';

  @override
  String get cardCandidateNewLabel => '新图片';

  @override
  String get cardCandidateSelectButton => '用这张图片';

  @override
  String get cardCandidateAppliedToast => '已换成新图片';

  @override
  String get cardCandidateLoadFailedTitle => '没能加载新图片';

  @override
  String get cardCandidateApplyFailedTitle => '没能换成新图片';

  @override
  String get planHeroHeadline => '变成专为Elumi制作的卡片';

  @override
  String get planHeroSubline => '同样的日常，用Pro制作会变成这样';

  @override
  String get planHeroFreeTag => 'Free 表情符号';

  @override
  String get planHeroProTag => 'Pro 漫画图';

  @override
  String get planHeroCompareSemantics => 'Free是表情符号卡片，Pro是漫画图卡片';

  @override
  String planBenefitGroupCards(String elumiName) {
    return '专属$elumiName的卡片图片';
  }

  @override
  String get planBenefitGroupRoutines => '日常自动发送';

  @override
  String get planBenefitGroupWeek => '帮你整理一周';

  @override
  String get planBenefitGroupExtra => '更加充裕';

  @override
  String planYearlySaving(int percent) {
    return '省$percent%';
  }

  @override
  String get planRenewsYearly => '每年自动续订';

  @override
  String get planRenewsMonthly => '每月自动续订';

  @override
  String planMonthlyEquivalentRenewsYearly(String price) {
    return '每月约$price · 每年自动续订';
  }

  @override
  String planPriceUnit(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'yearly': '/年',
      'other': '/月',
    });
    return '$_temp0';
  }

  @override
  String planCtaTrialNoticeAppStore(String trial, String price, String unit) {
    return '$trial后将自动收取$price$unit。在结束前24小时取消就不会收费';
  }

  @override
  String planCtaTrialNoticePlayStore(String trial, String price, String unit) {
    return '$trial后将自动收取$price$unit。在体验期间取消就不会收费';
  }

  @override
  String planCtaRenewNotice(String price, String unit) {
    return '按$price$unit自动续订。随时可以取消';
  }

  @override
  String planTryFreeTrial(String trial) {
    return '免费试用$trial';
  }

  @override
  String get planSeeAllBenefits => '查看全部Pro权益';

  @override
  String get planTierGift => '礼物';

  @override
  String get myPlanProTitle => '正在使用Pro';

  @override
  String get myPlanGiftTitle => '收到了Pro礼物';

  @override
  String get myPlanFreeTitle => '正在使用Free';

  @override
  String get myPlanFreeBodyWeek => '用每周获得的积分制作日常';

  @override
  String get myPlanFreeBodyMonth => '用每月获得的积分制作日常';

  @override
  String get proTeaserWeeklyPlanTitle => '只要设好星期和时间，当天的日常就会准备好';

  @override
  String get proTeaserWeeklyReportTitle => '把一周整理成一页来看';

  @override
  String get proTeaserRoutineMemoryTitle => '记住适合Elumi的方式';

  @override
  String get proTeaserCardThemeTitle => '下载更好看的打印卡片';

  @override
  String get proTeaserCardLayoutTitle => '按想要的方式下载打印卡片';

  @override
  String get proTeaserCardLayoutBenefit => '可以选择一页多张、横向纸张或一页日常';

  @override
  String get homeSuggestionDismissLabel => '不用了';

  @override
  String get homeSuggestionAutoSendTitle => '要每天自动发送吗？';

  @override
  String homeSuggestionAutoSendBody(String routine, String batchim, int days) {
    return '$routine已经连续发送$days天了';
  }

  @override
  String get homeSuggestionAutoSendAction => '去设置';

  @override
  String get homeSuggestionTalkShareTitle => '要发到故事里吗？';

  @override
  String homeSuggestionTalkShareBody(String routine, String batchim) {
    return '其他监护人也可以使用$routine';
  }

  @override
  String get homeSuggestionTalkShareAction => '发布';

  @override
  String get homeSuggestionCreateMoreTitle => '再做一个日常吗？';

  @override
  String get homeSuggestionCreateMoreBody => '晚上或睡前的日常怎么样？';

  @override
  String get homeSuggestionCreateMoreAction => '创建';

  @override
  String get cardSplitChip => '把这张卡片拆简单些';

  @override
  String get cardSplitLoading => '正在拆成更简单的步骤';

  @override
  String get cardSplitSheetTitle => '要这样拆分吗？';

  @override
  String cardSplitSheetDescription(String title, int count) {
    return '把“$title”分成了$count个小步骤';
  }

  @override
  String get cardSplitAlreadyShortDescription => '只有一个动作，所以没有再分';

  @override
  String get cardSplitDefaultPictureNote => '图片会使用默认图片，之后可以更换';

  @override
  String get cardSplitKeepButton => '保持原样';

  @override
  String get cardSplitApplyButton => '按此拆分';

  @override
  String get cardSplitAlreadyShort => '已经足够简短了';

  @override
  String get cardSplitFailedFallback => '未能拆分卡片，请稍后再试';

  @override
  String get cardSplitRetry => '重试';

  @override
  String cardSplitDoneToast(int count) {
    return '已把卡片拆成$count张';
  }

  @override
  String get planBenefitCardSplit => '把一张卡片拆得更小';

  @override
  String get creditTopUpTitleExhausted => '🎟️ 本周积分已用完';

  @override
  String get creditTopUpTitleExhaustedMonth => '🎟️ 本月积分已用完';

  @override
  String get creditTopUpTitleShort => '🎟️ 积分有点不够';

  @override
  String creditTopUpRefillAt(String reset) {
    return '$reset重新补满';
  }

  @override
  String get creditTopUpAdTitleNoCount => '看广告获得积分';

  @override
  String get creditTopUpAdWatch => '看广告';

  @override
  String get creditTopUpAdOff => '现在无法通过广告获得';

  @override
  String get creditTopUpAdDailyLimit => '今天已经领完了。明天可以再看';

  @override
  String creditTopUpAdDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '15到30秒，看完可得$count个积分',
    );
    return '$_temp0';
  }

  @override
  String creditTopUpAdRemaining(int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '今天还能领$remaining次',
    );
    return '$_temp0';
  }

  @override
  String get creditTopUpAdNoFill => '现在没有可看的广告';

  @override
  String get proFeatureMarkLabel => '了解详情';

  @override
  String get proExplainAiImageStylesReason => '图片和卡片内容相符，Elumi更容易看懂';

  @override
  String get proExplainCardSplitReason => '把难的行动拆成小步骤，Elumi可以一步一步跟着做';

  @override
  String get proExplainFreeImageRegenerateReason => '不用担心积分，可以改到满意为止';

  @override
  String get creditTopUpAdCheckFailed => '没能加载广告信息。请稍后再打开';

  @override
  String get creditTopUpPackLink => '查看积分礼包';

  @override
  String get creditTopUpRoutineContinue => '继续制作';

  @override
  String get creditTopUpRedrawContinue => '继续画';

  @override
  String creditRewardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🎟️ 获得了$count个积分',
    );
    return '$_temp0';
  }

  @override
  String get creditRewardTitleNoCount => '🎟️ 获得了积分';

  @override
  String get creditRewardReason => '看完了广告获得';

  @override
  String get lowCreditNoticeTitle => '积分快用完了';

  @override
  String get lowCreditNoticeTitleEmpty => '积分已用完';

  @override
  String get lowCreditNoticeBody => '看广告就能马上获得更多';

  @override
  String get lowCreditNoticeAction => '看广告领取';

  @override
  String get creditGuideTitle => '🎟️ 积分这样用';

  @override
  String get creditGuideBasis => '按我的套餐计算';

  @override
  String get creditGuideRoutineText => '制作日常文字';

  @override
  String get creditGuideCardImage => '卡片图片1张';

  @override
  String get creditGuideRegenerate => '重新画图片';

  @override
  String get creditGuideWeeklyGrant => '每周获得的积分';

  @override
  String get creditGuideMonthlyGrant => '每月获得的积分';

  @override
  String creditGuideCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideUnlimited => '不限';

  @override
  String creditGuideRegenerateFreeToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天还可免费$count次',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideKeepGoing => '已经开始的日常，积分不够也会做完';

  @override
  String get creditGuideRefillWeek => '每周一0点重新补满';

  @override
  String get creditGuideRefillMonth => '每月1日0点重新补满';

  @override
  String creditGuideProFactBoth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pro的日常文字不限，重新画每天免费$count次',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideProFactText => 'Pro的日常文字不限';

  @override
  String creditGuideProFactRegenerate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pro重新画每天免费$count次',
    );
    return '$_temp0';
  }

  @override
  String creditGuideRegenerateFreeDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每天免费$count次',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideConfirm => '知道了';

  @override
  String myCreditFreeRegenerateToday(int left, int cap) {
    return '今天重新画免费 $left/$cap次';
  }

  @override
  String get myCreditRecentTitle => '最近使用记录';

  @override
  String get myCreditSeeAllHistory => '查看全部';

  @override
  String get myCreditGuideLink => '积分这样用';

  @override
  String get abaIntroTitle => '准备很轻松，\n日常自己来';

  @override
  String get abaIntroSubtitle => '根据应用行为分析（ABA）原理制作';

  @override
  String get abaIntroStepsTitle => '拆小';

  @override
  String get abaIntroStepsBody => '把日常拆成步骤卡片';

  @override
  String get abaIntroShowTitle => '提前展示';

  @override
  String get abaIntroShowBody => '用图片和声音';

  @override
  String get abaIntroHelpTitle => '先帮忙，再减少';

  @override
  String get abaIntroHelpBody => '让Elumi自己接着做';

  @override
  String get abaIntroRewardTitle => '马上表扬';

  @override
  String get abaIntroRewardBody => '星星和定好的奖励';

  @override
  String get abaIntroGuardianTitle => '最重要的是监护人';

  @override
  String get abaIntroGuardianBody => '日常和奖励由监护人来定，elum在身边帮忙';

  @override
  String get abaIntroStart => '开始';

  @override
  String get guardianSettingsAboutElum => 'elum是这样设计的';

  @override
  String get notificationIntroTitle => '🔔 请一定要开启通知';

  @override
  String get notificationIntroBody => '开启后，Elumi的消息会马上通知你，不会错过';

  @override
  String get notificationIntroRoutineDone => 'Elumi完成日常时';

  @override
  String get notificationIntroCaregiverRoutine => '一起照顾的人发来日常时';

  @override
  String get notificationIntroWeeklyReport => '每周报告出来时';

  @override
  String get notificationIntroCreditRefilledWeek => '本周积分重新补满时';

  @override
  String get notificationIntroCreditRefilledMonth => '本月积分重新补满时';

  @override
  String get notificationOffNoticeHighlightRoutineDone => '完成日常时';

  @override
  String get notificationOffNoticeHighlightCaregiver => '一起照顾的人的消息';

  @override
  String get notificationOffNoticeAction => '开启通知';

  @override
  String get homeAutoSendUpsellTitle => '⏰ 要每天在同一时间自动发送吗？';

  @override
  String get homeAutoSendUpsellBody => '设好星期和时间，到时就会发送到Elumi的设备';

  @override
  String get homeAutoSendUpsellAction => '查看详情';

  @override
  String get notificationSettingRoutineNudge => '今天的日常还没发送时';

  @override
  String get notificationSettingSuggestion => '新日常推荐';

  @override
  String get notificationSettingPlanReminder => 'Pro礼物结束前';

  @override
  String get myCreditRemainingSuffix => '个积分可用';
}
