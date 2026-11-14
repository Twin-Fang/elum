// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get notificationOffNoticeTitle => '通知をオンにしますか？';

  @override
  String get notificationOffNoticeBody => 'ルーティンが終わったらお知らせします';

  @override
  String get notificationOffValue => 'オフ';

  @override
  String get appTitle => 'elum';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonNext => '次へ';

  @override
  String get commonRetry => 'もう一度試す';

  @override
  String dateYearMonthDay(int year, int month, int day) {
    return '$year年$month月$day日';
  }

  @override
  String dateMonthDaySince(int month, int day) {
    return '$month月$day日から';
  }

  @override
  String weekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'mon': '月',
      'tue': '火',
      'wed': '水',
      'thu': '木',
      'fri': '金',
      'sat': '土',
      'sun': '日',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String creditResetAt(int month, int day, String weekday, int hour) {
    return '$month月$day日($weekday) $hour時';
  }

  @override
  String creditResetAtMinute(
    int month,
    int day,
    String weekday,
    int hour,
    int minute,
  ) {
    return '$month月$day日($weekday) $hour時$minute分';
  }

  @override
  String get creditResetFallback => '来週月曜日の0時';

  @override
  String get creditResetFallbackMonth => '来月1日の0時';

  @override
  String get creditBlockedBusy => 'すでに日課を作っています。\n作り終わったら新しい日課を作れます';

  @override
  String creditReceivedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'クレジットを$count個もらいました',
    );
    return '$_temp0';
  }

  @override
  String get adRewardPreparing => '広告を準備しています';

  @override
  String get adRewardConfirming => 'クレジットを確認しています';

  @override
  String get adRewardLoadFailed => '今は広告を読み込めません。\nしばらくしてからもう一度お試しください';

  @override
  String get adRewardNotWatched => '広告を最後まで見るとクレジットをもらえます。\n最初からもう一度お試しください';

  @override
  String get adRewardSlow =>
      'クレジットの確認に時間がかかっています。\n広告をもう一度見る必要はありません。マイ情報 → マイクレジットで確認してください';

  @override
  String get adRewardDailyLimit => '今日、広告でもらえるクレジットはすべてもらいました。\n明日もう一度お試しください';

  @override
  String get adRewardCheckAccount => '今は広告でクレジットをもらえません。\nアカウントの状態を確認してください';

  @override
  String get adRewardUnavailable => '今は広告でクレジットをもらえません。';

  @override
  String get adRewardUnavailableRetry =>
      '今は広告でクレジットをもらえません。\nしばらくしてからもう一度お試しください';

  @override
  String get adRewardFailed => 'クレジットをもらえませんでした。\nしばらくしてからもう一度お試しください';

  @override
  String get commonPopupClose => 'ポップアップを閉じる';

  @override
  String get commonBack => '戻る';

  @override
  String get commonScreenNotFound => '画面が見つかりません';

  @override
  String get commonRetryLater => 'しばらくしてからもう一度お試しください';

  @override
  String get sentenceStop => '。';

  @override
  String get failureHintOffline => 'インターネット接続を確認してください';

  @override
  String get failureHintTimeout => '接続が遅いです。しばらくしてからもう一度お試しください';

  @override
  String get failureHintBadCertificate => '安全ではない接続です。別のネットワークでお試しください';

  @override
  String coachStepLabel(int index, int total, String message) {
    return 'ガイド $index/$total。$message';
  }

  @override
  String get commonAd => '広告';

  @override
  String get commonAppInfo => 'アプリ情報';

  @override
  String get coachCloseHint => 'ガイドを閉じる';

  @override
  String get coachNextHint => '次のガイド';

  @override
  String get coachTapToClose => '画面をタップすると閉じます';

  @override
  String get coachTapToNext => '画面をタップすると次へ進みます';

  @override
  String get loginSceneEyebrow => '今日の一日を、';

  @override
  String get loginSceneTitle => '一歩ずつ一緒に';

  @override
  String get appStatusStoreOpenFailedTitle => 'ストアを開けませんでした';

  @override
  String get appStatusStoreOpenFailedFallback => 'ストアでelumを探してアップデートしてください';

  @override
  String get appStatusMaintenanceTitle => 'ただいまメンテナンス中です';

  @override
  String get appStatusMaintenanceBody => 'メンテナンスが終わるとまた使えます。\n少し後で確認してください';

  @override
  String get appStatusRecheck => 'もう一度確認する';

  @override
  String get appStatusUpdateTitle => '今すぐアップデートして\n新しくなったelumを使ってみましょう！';

  @override
  String get appStatusUpdated => 'アップデートしました';

  @override
  String get appStatusGoUpdate => 'アップデートする';

  @override
  String routineForeignCreator(String name, String batchim) {
    return '$nameさんが作った日課です';
  }

  @override
  String get routineForeignCreatorUnknown => 'ほかの保護者が作った日課です';

  @override
  String get routineDefaultTitle => '今日の日課';

  @override
  String get rewardPresetSnack => '好きなおやつ';

  @override
  String get rewardPresetVideo => 'YouTube 10分';

  @override
  String get rewardPresetPlay => '好きな遊び';

  @override
  String get rewardPresetWalk => '散歩';

  @override
  String get rewardPresetCustom => '自分で入力';

  @override
  String get roleGuardianWord => '保護者';

  @override
  String get roleElumiWord => 'Elumi';

  @override
  String get roleLabelSuffix => 'が使います';

  @override
  String get roleGuardianDescription => '日課を作って管理します';

  @override
  String get roleElumiDescription => '日課を実践します';

  @override
  String get roleSelectTitle => 'この端末は誰が\n使いますか？';

  @override
  String get roleSelectDescription => '保護者モードとElumiモードに分かれています';

  @override
  String get loginKakaoButton => 'Kakaoでログイン';

  @override
  String get loginNaverButton => 'NAVERでログイン';

  @override
  String get loginAppleButton => 'Appleでログイン';

  @override
  String get loginConnecting => '接続しています';

  @override
  String get loginLastUsed => '前回のログイン';

  @override
  String get loginDuplicateTitle => 'すでに登録済みのアカウントです';

  @override
  String get loginDuplicateFallback => '最初に使った方法でログインしてください';

  @override
  String get loginOfflineTitle => 'インターネット接続を確認してください';

  @override
  String get loginOfflineFallback => '接続してからもう一度お試しください';

  @override
  String get loginFailedTitle => 'ログインできませんでした';

  @override
  String get loginFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get consentTitle => '規約に同意してください';

  @override
  String get consentLoading => '規約を読み込んでいます';

  @override
  String get consentSaving => '保存しています';

  @override
  String get consentSaveFailed => '同意を保存できませんでした。もう一度お試しください';

  @override
  String get consentDescriptionReady => '項目をタップすると詳しい内容を見られます';

  @override
  String get consentDescriptionNeeded => 'サービスを使うには規約への同意が必要です';

  @override
  String get consentAllAgree => 'サービス利用規約にすべて同意';

  @override
  String get consentRequiredTag => '必須';

  @override
  String get consentOptionalTag => '任意';

  @override
  String consentDocumentMeta(String label, String version) {
    return '$label · バージョン $version';
  }

  @override
  String get consentListTitle => '利用規約とプライバシーポリシー';

  @override
  String get consentGroupRequired => '必須項目';

  @override
  String get consentGroupOptional => '任意項目';

  @override
  String get commonElumiName => 'Elumi';

  @override
  String get characterCatLabel => 'ネコ';

  @override
  String get characterCatName => 'ルル';

  @override
  String get characterFoxLabel => 'キツネ';

  @override
  String get characterFoxName => 'ポポ';

  @override
  String get imageStyleEmojiLabel => '絵文字の絵';

  @override
  String get imageStyleEmojiDescription => 'かわいい絵文字で物を見せます';

  @override
  String get imageStyleSymbolLabel => '絵記号';

  @override
  String get imageStyleSymbolDescription => 'する動作を線画で見せます';

  @override
  String get imageStyleCharacterLabel => 'マンガの絵';

  @override
  String get imageStyleCharacterDescription => 'マンガの人物が実際にやって見せます';

  @override
  String get imageStyleRealisticLabel => '写真のような絵';

  @override
  String get imageStyleRealisticDescription => '本物の物のように見えます';

  @override
  String get imageStyleCreditLabel => 'クレジット';

  @override
  String imageStyleCreditRoutine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '日課1つにつき$count個',
    );
    return '$_temp0';
  }

  @override
  String get imageStyleCreditRoutineFree => '日課の文章はクレジットなしで作れます';

  @override
  String imageStyleCreditImage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '絵1枚につき$count個',
    );
    return '$_temp0';
  }

  @override
  String get goalStepByStep => 'やることを順番に理解します';

  @override
  String get goalPrepareItems => '必要な持ち物を自分でそろえます';

  @override
  String get goalPrepareNew => '新しい場面に前もって備えます';

  @override
  String get goalIndependent => '一人で最後までやり遂げる経験を作ります';

  @override
  String onboardingCharacterTitle(String name, String batchim) {
    return '$nameの一日を一緒に過ごす\n友だちを選んでください';
  }

  @override
  String get onboardingCharacterDescription => '選んだ友だちがホームとごほうび画面で一緒にいます';

  @override
  String get onboardingImageStyleTitle => 'カードの絵はどんな方法で\n作りますか？';

  @override
  String get onboardingImageStyleDescription => 'あとで設定で変えられます';

  @override
  String onboardingImageStyleCreditIntroWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'クレジットは毎週$count個もらえます。日課と絵を作るときに使います',
    );
    return '$_temp0';
  }

  @override
  String onboardingImageStyleCreditIntroMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'クレジットは毎月$count個もらえます。日課と絵を作るときに使います',
    );
    return '$_temp0';
  }

  @override
  String get onboardingImageStyleCreditIntro => 'クレジットは日課と絵を作るときに使います';

  @override
  String get onboardingNameTitle => 'Elumiを何と\nお呼びしますか？';

  @override
  String get onboardingNameDescription => 'elumでは使う人をElumiと呼びます\n本名でなくても大丈夫です';

  @override
  String get onboardingNameHint => '名前を入力してください';

  @override
  String get onboardingNameInviteLink => '招待コードがあります';

  @override
  String get onboardingSplashLogoLabel => 'elum';

  @override
  String get pinCreateTitle => '保護者だけが知っている\nパスコードを作ってください';

  @override
  String get pinConfirmTitle => 'パスコードをもう一度\n入力してください';

  @override
  String get pinDescription => '保護者モードに切り替えるときに使うパスコードです';

  @override
  String get pinMismatch => 'パスコードが違います。もう一度入力してください';

  @override
  String get pinInputSemanticLabel => 'パスコードを入力';

  @override
  String get pinStartButton => 'はじめる';

  @override
  String get pinProfileCreateFailedTitle => 'Elumiを登録できませんでした';

  @override
  String get pinProfileCreateFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get pinSaveFailedTitle => '設定を保存できませんでした';

  @override
  String get pinSaveFailedFallback => 'しばらくしてから「はじめる」をもう一度タップしてください';

  @override
  String get elumiSettingsTitle => '設定';

  @override
  String get elumiSettingsHapticLabel => 'カードチェック時の振動';

  @override
  String get elumiSettingsPraiseSoundLabel => 'カードチェック時のほめる音';

  @override
  String get elumiSettingsScreenAwakeLabel => 'カードを見るとき画面をつけたままにする';

  @override
  String get elumiSettingsTermsLabel => '利用規約とプライバシーポリシー';

  @override
  String get elumiSettingsLogoutLabel => 'ログアウト';

  @override
  String get elumiSettingsWithdrawLabel => '退会';

  @override
  String get elumiSettingsLogoutTitle => 'ログアウトしますか？';

  @override
  String get elumiSettingsLogoutMessage =>
      'この端末の接続が切れます\nまた使うには保護者から\n接続コードをもらってください';

  @override
  String get elumiSettingsLogoutFailTitle => 'ログアウトできませんでした';

  @override
  String get elumiSettingsWithdrawTitle => '退会しますか？';

  @override
  String get elumiSettingsWithdrawMessage =>
      'この端末の接続だけが切れます\n日課と星は保護者の端末に残ります\nまた使うには保護者から\n接続コードをもらってください';

  @override
  String get elumiSettingsWithdrawAction => '退会する';

  @override
  String get inviteRejectedOnElumiDevice => 'この端末では招待を受けられません\n保護者の端末で開いてください';

  @override
  String get elumiSettingsWithdrawFailTitle => '退会できませんでした';

  @override
  String get elumiSettingsExitFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get linkStatusTitle => 'Elumiの端末';

  @override
  String get linkStatusRevokeConfirmTitle => '接続を切りますか？';

  @override
  String get linkStatusRevokeConfirmMessage =>
      'Elumiの端末で日課を見られなくなります\nまた接続するには新しいコードを作ってください';

  @override
  String get linkStatusRevokeConfirmAction => '接続を切る';

  @override
  String get linkStatusRevokeFailTitle => '接続を切れませんでした';

  @override
  String get linkStatusRevokeFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get linkStatusRevoked => '接続を切りました';

  @override
  String get linkStatusAlreadyRevoked => 'すでに切れています';

  @override
  String get linkStatusLoadFailedFallback => '接続状態を読み込めませんでした';

  @override
  String linkDeviceNumbered(int number) {
    return 'Elumiの端末 $number';
  }

  @override
  String get linkStatusConnected => '接続済み';

  @override
  String get linkStatusRevokeButton => '接続を切る';

  @override
  String get linkStatusRevokeHint => '切るとElumiの端末で\n日課を見られなくなります';

  @override
  String get linkStatusEmpty => '接続された端末がありません';

  @override
  String linkStatusConnectedBy(String name, String batchim) {
    return '$nameさんが接続';
  }

  @override
  String get linkStatusConnectedByMe => '自分が接続';

  @override
  String linkStatusConnectedByAndSince(String by, String since) {
    return '$by · $since';
  }

  @override
  String get linkStatusAddAction => '+ ほかの端末を接続する';

  @override
  String get linkStatusConnectAction => 'Elumiの端末を接続する';

  @override
  String get linkCodeSettingsTitle => 'Elumiの端末を接続';

  @override
  String linkCodeAskTitle(String name, String batchim) {
    return '$nameの端末を\n接続しますか？';
  }

  @override
  String linkCodeEnterHint(String name, String batchim) {
    return '$nameの端末で下のコードを入力してください';
  }

  @override
  String get linkCodeIssueFailedFallback => 'コードを作れませんでした。もう一度お試しください';

  @override
  String get linkCodeSuccessTitle => '端末の接続に成功しました！';

  @override
  String get linkCodeStartButton => 'はじめる';

  @override
  String get linkCodeLater => 'あとで';

  @override
  String get linkCodeChangesAfter => '後にコードが変わります';

  @override
  String get linkRetryChipLabel => 'コードを作り直す';

  @override
  String get linkEnterTitle => '保護者からもらったコードを\n入力してください';

  @override
  String get linkEnterGuide => 'コードは保護者の端末のここにあります\nマイ情報 → 歯車 → Elumiの端末を接続する';

  @override
  String get linkEnterGuidePath => 'マイ情報 → 歯車 → Elumiの端末を接続する';

  @override
  String get linkEnterLinkLost => '接続が切れました\n保護者から新しい接続コードをもらって入力してください';

  @override
  String get linkEnterStartButton => 'はじめる';

  @override
  String get linkEnterInputLabel => '接続コードを入力';

  @override
  String get linkEnterWrongCode => 'コードが正しくありません';

  @override
  String get linkEnterExpired => 'コードの有効期限が切れました。新しいコードをもらってください';

  @override
  String get linkEnterOffline => '接続できませんでした。インターネットを確認してください';

  @override
  String get linkEnterFailed => '接続できませんでした。もう一度お試しください';

  @override
  String get commonGuardianName => '保護者';

  @override
  String get guardianKindGuardian => '保護者';

  @override
  String get guardianKindCaregiver => '先生';

  @override
  String inviteShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes分',
    );
    return 'Elumiを一緒に見守りましょう。下のリンクをタップするとelumアプリに招待コードが入ります。\n招待コードは$_temp0間だけ使えます。\n\n$url\n\nリンクが開かない場合は、アプリで直接入力してください。\n招待コード $code';
  }

  @override
  String get guardiansEditTitle => '自分の名前を変更する';

  @override
  String get guardiansEditDescription =>
      'Elumiを一緒に見守る人に表示される名前です。\n本名でなくても大丈夫です';

  @override
  String get guardiansEditNameHint => 'ママ、パパ、先生';

  @override
  String get guardiansEditSave => '保存する';

  @override
  String get guardiansLeaveConfirmTitle => '一緒に見守るのをやめますか？';

  @override
  String get guardiansLeaveConfirmMessageLast =>
      'ほかの保護者がいません\n抜けるとElumiと作った日課、集めた星がすべて消えます\n元に戻せません';

  @override
  String get guardiansLeaveConfirmMessageOthers =>
      '自分が接続したElumiの端末があれば接続が切れます\n残った保護者が新しい接続コードを作るとまた使えます\n自分が作った日課は消えます\nElumiとほかの保護者の日課・星はそのまま残ります';

  @override
  String get guardiansLeaveConfirmAction => 'やめる';

  @override
  String get guardiansLeaveTypeTitle => 'もう一度確認します';

  @override
  String guardiansLeaveTypeMessage(String phrase) {
    return 'Elumiと日課、星がすべて消えます\n下の欄に「$phrase」と\n同じように入力してください';
  }

  @override
  String get guardiansLeaveTypePhrase => 'やめる';

  @override
  String get guardiansLeaveTypeAction => 'やめる';

  @override
  String get guardiansLeaveFailTitle => '抜けられませんでした';

  @override
  String get guardiansLeaveFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String guardiansLeft(String name) {
    return '$nameから抜けました';
  }

  @override
  String get guardiansNameEditFailTitle => '名前を変更できませんでした';

  @override
  String get guardiansNameEditFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get guardiansTitle => '一緒に見守る人';

  @override
  String get guardiansNoProfileMessage => '一緒に見守る人を表示するElumiがいません';

  @override
  String get guardiansNoProfileDescription => '先にElumiを登録してください';

  @override
  String get guardiansIntro => '日課を一緒に作る家族や先生です';

  @override
  String get guardiansLoadFailedFallback => '一緒に見守る人を読み込めませんでした';

  @override
  String get guardiansEmptyMessage => '一緒に見守る人が見つかりませんでした';

  @override
  String get guardiansAloneHint => '今は一人で見守っています。家族や先生を招待してみましょう';

  @override
  String get guardiansNameScopeHint =>
      'ここの名前は一緒に見守る人にだけ表示されます。トークではマイ情報のニックネームが表示されます';

  @override
  String get guardiansInviteAction => 'ほかの保護者を招待する';

  @override
  String get guardiansEnterCodeAction => 'もらった招待コードを入力する';

  @override
  String get guardiansLeaveAction => '一緒に見守るのをやめる';

  @override
  String get guardiansLeaveHintAlone => '一人で見守っているので、やめるとElumiと日課、星がすべて消えます';

  @override
  String get guardiansLeaveHintWithOthers => '自分が作った日課だけが消えます';

  @override
  String inviteCodeGuestJoinedTitle(String name) {
    return '$nameさんが仲間になりました';
  }

  @override
  String get guardiansMeBadge => '自分';

  @override
  String guardiansPeopleHeader(int count) {
    return '一緒に見守る人 $count人';
  }

  @override
  String get guardiansInviteHeader => '招待';

  @override
  String get guardiansRenameAction => '名前を変更';

  @override
  String get inviteCodeShareFailTitle => 'リンクを送れませんでした';

  @override
  String get inviteCodeShareFailFallback => 'コードを直接伝えてください';

  @override
  String get inviteCodeTitle => '招待コード';

  @override
  String get inviteCodeShareButton => 'リンクで送る';

  @override
  String get inviteCodeHeaderTitle => '一緒に見守る保護者に\nコードを伝えてください';

  @override
  String inviteCodeAsk(String name, String batchim) {
    return 'コードを受け取った人が$nameを一緒に見守ります';
  }

  @override
  String get inviteCodeNoProfileMessage => '一緒に見守るElumiがいません';

  @override
  String get inviteCodeNoProfileDescription => '先にElumiを登録してください';

  @override
  String get inviteCodeIssueFailedFallback => '招待コードを作れませんでした';

  @override
  String get inviteEnterLinkInvalid =>
      '招待リンクが正しくありません。送った人にもう一度もらってください (E-INV-LINK)';

  @override
  String get inviteEnterFormInvalid => '招待コードが正しくありません (E-INV-FORM)';

  @override
  String inviteJoined(String name, String batchim) {
    return '$nameを一緒に見守ることになりました';
  }

  @override
  String get inviteEnterNotFound => '招待コードが正しくありません';

  @override
  String get inviteEnterExpired => '招待コードの有効期限が切れました。新しいコードをもらってください';

  @override
  String get inviteEnterTooManyAttempts => '少し待ってからもう一度お試しください';

  @override
  String get inviteEnterAlreadyGuardian => 'すでに一緒に見守っているElumiです';

  @override
  String get inviteEnterForbiddenForElumi => 'Elumiの端末ではできません';

  @override
  String get inviteEnterInvalidInput => '招待コードが正しくありません';

  @override
  String get inviteEnterOffline => '接続できませんでした。インターネットを確認してください';

  @override
  String get inviteEnterOther => '接続できませんでした。もう一度お試しください';

  @override
  String get inviteEnterConsentFailTitle => '招待コードを入力できませんでした';

  @override
  String get inviteEnterConsentFallback => '先に規約に同意してください';

  @override
  String get inviteEnterStartButton => 'はじめる';

  @override
  String get inviteEnterManualLink => '別のコードを入力';

  @override
  String get inviteEnterTitle => '招待コードを\n入力してください';

  @override
  String get inviteEnterDescriptionFromLink =>
      'リンクで受け取った招待コードです。正しければ「はじめる」をタップしてください';

  @override
  String get inviteEnterDescriptionManual =>
      'コードは一緒に見守る保護者の端末の\nマイ情報 → 一緒に見守る人にあります';

  @override
  String get inviteEnterDescriptionPath => 'マイ情報 → 一緒に見守る人';

  @override
  String get inviteEnterSemanticsFromLink => 'リンクで受け取った招待コード';

  @override
  String get inviteEnterSemanticsInput => '招待コードを入力';

  @override
  String get profileSwitchChanged => 'Elumiを切り替えました';

  @override
  String get profileSwitchTitle => 'Elumiを切り替える';

  @override
  String get profileSwitchLoadFailedFallback => 'Elumiの一覧を読み込めませんでした';

  @override
  String get profileSwitchLoadFailedMessage => 'Elumiの一覧を読み込めませんでした';

  @override
  String profileSwitchSelected(String name) {
    return '$name、今見ているElumi';
  }

  @override
  String get noticeHideWeek => '1週間表示しない';

  @override
  String noticeHideDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days日間表示しない',
    );
    return '$_temp0';
  }

  @override
  String noticeLinkOpenFailed(String code) {
    return 'リンクを開けませんでした ($code)';
  }

  @override
  String get noticeCloseBarrier => 'お知らせを閉じる';

  @override
  String get cardPhotoTooLarge => '写真が大きすぎます。別の写真を選んでください';

  @override
  String get cardPhotoWrongType => 'JPGかPNGの写真だけアップロードできます';

  @override
  String get cardPhotoUnreadable => '写真を読み込めませんでした。別の写真を選んでください';

  @override
  String get cardPhotoPickFailed => '写真を取り込めませんでした。もう一度お試しください';

  @override
  String get routineLoadingPrepareTitle => 'ルミが内容を\n整理しています';

  @override
  String get routineLoadingGenerateTitle => 'ルミが行動カードを\n作っています';

  @override
  String get routineStageReviewSituation => '書いてくれた状況を確認しています';

  @override
  String get routineStageTidyEssentials => '必要な内容だけを整理します';

  @override
  String get routineStageThinkQuestions => '追加の質問を考えています';

  @override
  String get routineStageReadRoutine => '今日の日課を読んでいます';

  @override
  String get routineStageFindItems => '大事な持ち物を探しています';

  @override
  String get routineStageOrderSteps => '順番を整理しています';

  @override
  String get suggestionRainyText => '雨の日の登校';

  @override
  String get suggestionRainyPrompt => '雨の日に傘を持って学校へ行くしたくをしたいです';

  @override
  String get suggestionHospitalText => '病院へ行く準備';

  @override
  String get suggestionHospitalPrompt => 'Elumiと一緒に病院へ行くので、怖がらないように準備したいです';

  @override
  String get suggestionTripText => '校外学習の準備';

  @override
  String get suggestionTripPrompt => '校外学習の日の朝に持っていく物を順番に伝えたいです';

  @override
  String get suggestionNewPlaceText => '初めての場所へ行く';

  @override
  String get suggestionNewPlacePrompt => '初めての場所へ行く前に、Elumiが心の準備をできるよう手伝いたいです';

  @override
  String get suggestionAfterSchoolText => '夏休みの放課後教室の準備';

  @override
  String get suggestionAfterSchoolPrompt => '休み中の放課後教室へ行く準備を順番に伝えたいです';

  @override
  String get guardianHomeTodayRoutine => '今日の日課';

  @override
  String get guardianHomePastRoutine => '過去の日課';

  @override
  String get guardianHomeGoChildScreen => 'Elumi画面へ';

  @override
  String get notificationBellLabel => '通知';

  @override
  String get notificationBellUnreadLabel => '未読の通知があります';

  @override
  String get notificationTabNotifications => '通知';

  @override
  String get notificationTabNotices => 'お知らせ';

  @override
  String get notificationDayToday => '今日';

  @override
  String get notificationDayYesterday => '昨日';

  @override
  String get notificationDayEarlier => 'それ以前';

  @override
  String get notificationMarkAllRead => 'すべて既読';

  @override
  String get notificationEmpty => 'まだ通知はありません';

  @override
  String get notificationNoticeEmpty => 'まだお知らせはありません';

  @override
  String get notificationNoticeFailed => 'お知らせを読み込めませんでした';

  @override
  String get notificationSettingsTitle => '通知設定';

  @override
  String get notificationSettingAll => 'すべての通知を受け取る';

  @override
  String get notificationSettingRoutineCompleted => 'Elumiが日課を終えたとき';

  @override
  String get notificationSettingRoutineSent => 'ほかの保護者が日課を送ったとき';

  @override
  String get notificationSettingCoGuardianJoined => '新しい保護者が加わったとき';

  @override
  String get notificationSettingCreditRefilled => '今週のクレジットが補充されたとき';

  @override
  String get notificationSettingFeedbackResolved => 'ご意見に対応したとき';

  @override
  String get notificationSettingTalkCommented => 'トーク:自分の投稿にコメントがついたとき';

  @override
  String get notificationSettingTalkImported => 'トーク:自分の投稿が持っていかれたとき';

  @override
  String get notificationPermissionOff => '端末の通知がオフになっています';

  @override
  String get notificationTurnOnDeviceNotification => 'オンにする';

  @override
  String get notificationSettingSaveFailed => '設定を保存できませんでした';

  @override
  String get notificationSettingLoadFailed => '設定を読み込めませんでした';

  @override
  String get notificationListFailed => '通知を読み込めませんでした';

  @override
  String get notificationProfileUnavailable => 'このElumiの通知はもう見られません';

  @override
  String notificationRoutineCompletedOne(String title) {
    return '「$title」の日課を終えました';
  }

  @override
  String notificationRoutineCompletedMany(int count) {
    return '日課を$count個終えました';
  }

  @override
  String get notificationRoutineCompletedNoTitle => '日課を終えました';

  @override
  String notificationRoutineSent(String title) {
    return '一緒に見守る保護者が「$title」の日課を送りました';
  }

  @override
  String get notificationRoutineSentNoTitle => '一緒に見守る保護者が新しい日課を送りました';

  @override
  String get notificationCoGuardianJoined => '新しい保護者が加わりました';

  @override
  String get notificationCreditRefilled => '今週のクレジットが補充されました';

  @override
  String get notificationFeedbackResolved => 'お送りいただいたご意見を確認し、対応しました';

  @override
  String notificationTalkPostCommented(int count) {
    return '自分の投稿にコメントが$count件つきました';
  }

  @override
  String notificationTalkPostImported(int count) {
    return '保護者$count人が自分の投稿を持っていきました';
  }

  @override
  String get notificationWeeklyReportReady => '先週のレポートが届きました';

  @override
  String get notificationAdminMessageFallback => 'elumからのお知らせです';

  @override
  String guardianHomeGreeting(String name) {
    return 'こんにちは、\n$nameの保護者さん 👋🏻';
  }

  @override
  String get guardianHomeSubtitle => '今日はどんな日課を準備しますか？';

  @override
  String get pinChangeMismatchCreate => 'パスコードが違います。もう一度入力してください';

  @override
  String get pinChangeMismatch => 'パスコードが違います。もう一度入力してください';

  @override
  String get pinChangeCreateFailedTitle => 'パスコードを作れませんでした';

  @override
  String get pinChangeFailedTitle => 'パスコードを変更できませんでした';

  @override
  String get pinChangeFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get pinChangeCreatedSnack => 'パスコードを作りました';

  @override
  String get pinChangeChangedSnack => 'パスコードを変更しました';

  @override
  String get pinChangeVerifyTitle => '今のパスコードを\n入力してください';

  @override
  String get pinChangeCreateTitle => 'この端末で使う\nパスコードを決めてください';

  @override
  String get pinChangeCreateDescription => 'パスコードは端末ごとに決めます\n前の端末と同じでもかまいません';

  @override
  String get pinModeHint => '保護者モードに切り替えるときに使うパスコードです';

  @override
  String get pinChangeEnterTitle => '新しいパスコードを\n入力してください';

  @override
  String get pinChangeCreateConfirmTitle => 'パスコードをもう一度\n入力してください';

  @override
  String get pinChangeConfirmTitle => 'パスコードをもう一度\n入力してください';

  @override
  String get pinChangeConfirmHint => 'もうすぐパスコードの変更が終わります';

  @override
  String get pinChangeHeaderTitle => 'パスコードを変更する';

  @override
  String get pinChangeSave => '保存する';

  @override
  String get pinChangeInputLabel => 'パスコードを入力';

  @override
  String get rewardSaveFailedTitle => 'ごほうびを保存できませんでした';

  @override
  String get rewardSaveFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get rewardWhyTitle => 'ごほうびはなぜ必要ですか？';

  @override
  String get rewardWhyMessage =>
      '日課のあとに楽しみがあると、Elumiは最後までやりとげる力がわきます。\n1か月後のプレゼントより、今日すぐあげられる小さなものがよく効きます。\n決めなくても日課は作れます。';

  @override
  String get rewardHeadlineTitle => '日課が終わったら\nどんなごほうびをあげますか？';

  @override
  String get rewardHeadlineBody => '日課をやりとげる大きなやる気になります';

  @override
  String get rewardLater => 'あとで決めます';

  @override
  String get imageStyleChangedSnack => '絵のスタイルを変更しました';

  @override
  String get imageStyleSaveFailedTitle => '絵のスタイルを保存できませんでした';

  @override
  String get imageStyleSaveFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get imageStyleTitle => '絵のスタイル';

  @override
  String get routineLoadingBlockedTitle => '今は作れません';

  @override
  String get routineLoadingPrepareFailed => '質問を準備できませんでした';

  @override
  String get routineLoadingGenerateFailed => 'カードを作れませんでした';

  @override
  String get routineLoadingInputNeededTitle => 'どんな日課か教えてください';

  @override
  String get routineLoadingEditInput => '書き直す';

  @override
  String routineLoadingPercent(int percent) {
    return '$percent% 進みました';
  }

  @override
  String get routineLoadingRetry => 'もう一度';

  @override
  String get routineLoadingHome => 'ホームへ';

  @override
  String get draftRoutinesTitle => '下書き';

  @override
  String get draftRoutinesLoadFailedFallback => '下書きを読み込めませんでした';

  @override
  String get draftRoutinesDeleteLabel => '下書きを消す';

  @override
  String get draftRoutinesDeleteConfirmTitle => '下書きを消しますか？';

  @override
  String get draftRoutinesDeleteAction => '消す';

  @override
  String get draftRoutinesDeleteFailedTitle => '下書きを消せませんでした';

  @override
  String get draftRoutinesDeleteFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get draftRoutinesRewardUnset => 'ごほうびはまだ決めていません';

  @override
  String get draftRoutinesRewardLabel => '完了したら';

  @override
  String get draftRoutinesResume => '続ける';

  @override
  String get draftRoutinesEmptyTitle => '作りかけの日課はありません';

  @override
  String get draftRoutinesEmptyBody => '日課を作る途中でやめると、ここに残ります';

  @override
  String get cardReviewDeleteConfirmTitle => 'カードを消しますか？';

  @override
  String get cardReviewDeleteAction => '消す';

  @override
  String get cardReviewSoundFailedTitle => '音を再生できませんでした';

  @override
  String get cardReviewSoundFailedFallback => '端末の音をオンにして、もう一度タップしてください';

  @override
  String get cardReviewSaveFailedTitle => '日課を保存できませんでした';

  @override
  String get cardReviewSaveFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get cardReviewEditFailedTitle => '直した内容を保存できませんでした';

  @override
  String get cardReviewEditFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get cardReviewAddFailedTitle => 'カードを追加できませんでした';

  @override
  String get cardReviewAddFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get cardImageGeneratingLabel => '絵を作っています';

  @override
  String get cardImageNoCreditToast => 'クレジットが足りないので、基本の絵を入れました';

  @override
  String get cardImageUnavailableToast => '絵を作れなかったので、基本の絵を入れました';

  @override
  String get cardImageMissingAfterCreateToast =>
      '絵を作れなかったカードには基本の絵を入れました。「このカードを編集」でAIの絵を描けます';

  @override
  String get cardReviewReorderDone => '完了';

  @override
  String get cardReviewSave => 'カードを保存する';

  @override
  String get routineInputTitle => '今日はどんな準備が\n必要ですか？';

  @override
  String get routineInputSubtitle => 'AIアシスタントのルミが小さな行動のステップに分けます';

  @override
  String get routineInputHint => 'ふだん話すように入力してください';

  @override
  String get routineInputPrivacyNotice => '名前・学校・病院・診断名などの個人情報は書かないでください';

  @override
  String get guardianSettingsLogoutConfirmTitle => 'ログアウトしますか？';

  @override
  String get guardianSettingsWithdrawConfirmTitle => '退会しますか？';

  @override
  String get guardianSettingsWithdrawConfirmMessage =>
      '作った日課と集めた星がすべて消えます\nもう一度ログインしても元に戻せません';

  @override
  String get guardianSettingsWithdrawConfirmAction => '退会する';

  @override
  String get guardianSettingsWithdrawFailedTitle => '退会できませんでした';

  @override
  String get guardianSettingsWithdrawFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get guardianSettingsWithdrawAppStoreSubscriptionNotice =>
      'Proの購読は退会しても続きます\nApp Storeで\nご自身で解約してください';

  @override
  String get guardianSettingsWithdrawGooglePlaySubscriptionNotice =>
      '退会すると、Google PlayのPro購読の\n次回の支払いを止めます';

  @override
  String get guardianSettingsWithdrawProNotice => 'Proも一緒になくなります';

  @override
  String guardianSettingsWithdrawProGiftNotice(String date) {
    return '$dateまで使える\nProのプレゼントもなくなります';
  }

  @override
  String get guardianSettingsWithdrawProTrialNotice => 'Proのお試しも一緒になくなります';

  @override
  String guardianSettingsWithdrawCreditsNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個',
    );
    return '残りのクレジット$_temp0もなくなります';
  }

  @override
  String guardianSettingsWithdrawCreditsWithPurchasedNotice(
    int count,
    int purchased,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個',
    );
    String _temp1 = intl.Intl.pluralLogic(
      purchased,
      locale: localeName,
      other: '$purchased個',
    );
    return '残りのクレジット$_temp0もなくなります\n購入したクレジット$_temp1も含まれます';
  }

  @override
  String get guardianSettingsWithdrawCreditsUnknownNotice =>
      '残りのクレジットもすべてなくなります';

  @override
  String get guardianSettingsWithdrawAppStoreStepTitle =>
      '先にApp Storeの購読を解約してください';

  @override
  String get guardianSettingsWithdrawAppStoreStepMessage =>
      '退会だけでは支払いが続きます\n解約しなくても退会はできます';

  @override
  String get guardianSettingsWithdrawAppStoreStepContinue => '続ける';

  @override
  String get guardianSettingsWithdrawDone =>
      '退会しました。これまでelumを使っていただき、ありがとうございました';

  @override
  String get guardianSettingsWithdrawTypeTitle => 'もう一度確認します';

  @override
  String guardianSettingsWithdrawTypeMessage(String phrase) {
    return '下の欄に「$phrase」と\n同じように入力してください';
  }

  @override
  String get guardianSettingsWithdrawTypePhrase => '退会する';

  @override
  String get guardianSettingsWithdrawTypeAction => '退会する';

  @override
  String get guardianSettingsTitle => '設定';

  @override
  String get guardianSettingsPeople => '一緒に見守る人';

  @override
  String get guardianSettingsDrafts => '下書き';

  @override
  String get guardianSettingsPinChange => 'パスコードを変更する';

  @override
  String get guardianSettingsTerms => '利用規約とプライバシーポリシー';

  @override
  String get guardianSettingsFeedback => 'ご意見を送る';

  @override
  String get feedbackTitle => 'ご意見を送る';

  @override
  String get feedbackHint => '使いにくかったことを気軽に書いてください';

  @override
  String get feedbackIncludeLog => 'アプリの状態記録と端末情報を送る';

  @override
  String get feedbackSend => '送る';

  @override
  String get feedbackSent => 'ご意見を送りました';

  @override
  String get feedbackFailedTitle => 'ご意見を送れませんでした';

  @override
  String get feedbackFailedFallback => '書いた内容はそのまま残っています。しばらくしてからもう一度送ってください';

  @override
  String get guardianSettingsLogout => 'ログアウト';

  @override
  String get guardianSettingsWithdraw => '退会';

  @override
  String get guardianSettingsLinkConnected => 'Elumiの端末';

  @override
  String get guardianSettingsLinkConnect => 'Elumiの端末をつなげる';

  @override
  String get guardianSettingsLinkStatus => '接続済み';

  @override
  String get guardianSettingsProfileSwitch => 'Elumiを切り替える';

  @override
  String get guardianSettingsImageStyle => '絵のスタイル';

  @override
  String get guardianSettingsHaptic => 'カードチェック時の振動';

  @override
  String get guardianSettingsPraiseSound => 'カードチェック時のほめる音';

  @override
  String get guardianSettingsScreenAwake => 'カードを見るとき画面をつけておく';

  @override
  String get questionMakeCards => 'カードを作る';

  @override
  String get questionCustomAdd => '+ 自分で入力する';

  @override
  String get questionCustomHint => 'ここに書いてください';

  @override
  String get questionCustomClose => '自分で入力を閉じる';

  @override
  String questionClearLabel(String label) {
    return '$labelを消す';
  }

  @override
  String cardReviewMade(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'カードを$count枚作りました',
    );
    return '$_temp0';
  }

  @override
  String get cardReviewRewardLead => '完了したら ';

  @override
  String get cardReviewRewardSet => 'ごほうびを決める';

  @override
  String get cardReviewReorderHint => 'カードを長押しすると順番を変えられます';

  @override
  String get cardReviewToolReorder => 'カードの順番を変更';

  @override
  String get cardReviewToolEdit => 'このカードを編集';

  @override
  String get cardReviewToolAdd => 'カードを追加';

  @override
  String get cardReviewReorderTitle => 'カードの順番を変更';

  @override
  String get cardReviewReorderCancel => '順番の変更をやめる';

  @override
  String get cardReviewEmptyTitle => '作られたカードはありません';

  @override
  String get cardReviewEmptyBody => '日課を最初から作り直してください';

  @override
  String get cardReviewEmptyAction => '作り直す';

  @override
  String get cardMoveForward => '前に移す';

  @override
  String get cardMoveBackward => '後ろに移す';

  @override
  String get cardSpeakStop => '読み上げを止める';

  @override
  String get cardSpeak => '音で聞く';

  @override
  String get cardDeleteLabel => 'このカードを消す';

  @override
  String get cardAddPhoto => '写真を追加';

  @override
  String get cardViewerBarrierLabel => 'カードを閉じる';

  @override
  String get cardViewerSoundFailedTitle => '音を再生できませんでした';

  @override
  String get cardViewerSoundFailedFallback => '端末の音をオンにして、もう一度タップしてください';

  @override
  String get cardViewerClose => 'カードを閉じる';

  @override
  String get cardEditAddTitle => '新しいカードを追加';

  @override
  String get cardEditTitle => 'カードを編集';

  @override
  String get cardEditFieldTitle => 'タイトル';

  @override
  String get cardEditTitleHint => 'カードのタイトルを書いてください';

  @override
  String get cardEditFieldDescription => '説明';

  @override
  String get cardEditDescriptionHint => 'カードの説明を書いてください';

  @override
  String get cardEditAddAction => '追加する';

  @override
  String get cardEditDoneAction => '完了';

  @override
  String get cardPhotoPermissionTake => '写真を撮る';

  @override
  String get cardPhotoPermissionGallery => 'ギャラリーから選ぶ';

  @override
  String get cardPhotoPermissionOpenSettings => '設定を開く';

  @override
  String get cardPhotoPermissionCameraTitle => 'カメラを使えません';

  @override
  String get cardPhotoPermissionGalleryTitle => '写真を見られません';

  @override
  String get cardPhotoPermissionCameraBody => '端末の設定でカメラをオンにすると写真を撮れます';

  @override
  String get cardPhotoPermissionGalleryBody => '端末の設定で写真へのアクセスをオンにすると選べます';

  @override
  String get cardPhotoSettingsFailedTitle => '設定を開けませんでした';

  @override
  String get cardPhotoSettingsFailedFallback => '端末の設定から直接オンにしてください';

  @override
  String get cardPhotoSourceTake => '写真を撮る';

  @override
  String get cardPhotoSourceGallery => 'ギャラリーから選ぶ';

  @override
  String cardPhotoUploadFailedDialog(String message) {
    return '写真をアップロードできませんでした。\n$message';
  }

  @override
  String get cardPhotoChange => '写真を変える';

  @override
  String get cardPhotoUploading => '写真をアップロードしています';

  @override
  String get cardPhotoUploadFailed => '写真をアップロードできませんでした';

  @override
  String get cardPhotoRetry => 'もう一度';

  @override
  String get creditCardTitle => '今週のAI作成';

  @override
  String get creditCardTitleMonth => '今月のAI作成';

  @override
  String get creditCardLoading => '今週のAI作成の使用量を読み込んでいます';

  @override
  String get creditCardLoadingMonth => '今月のAI作成の使用量を読み込んでいます';

  @override
  String get creditCardLoadFailed => '使用量を読み込めませんでした';

  @override
  String get creditCardRetry => 'もう一度';

  @override
  String get creditGenerating => '日課を作っています';

  @override
  String get creditExhausted => '今週のクレジットをすべて使いました';

  @override
  String get creditExhaustedMonth => '今月のクレジットをすべて使いました';

  @override
  String get creditExhaustedStillOk => '作った日課を見ることと、自分で直すことは続けてできます';

  @override
  String get creditInfoLabel => 'AIクレジットのご案内';

  @override
  String creditAmountLeft(int available, int weekly) {
    return '残り $available / $weekly クレジット';
  }

  @override
  String creditAmountRest(int weekly) {
    return ' / $weekly クレジット残り';
  }

  @override
  String aiCreditResetLine(String reset) {
    return '$resetにまた補充されます';
  }

  @override
  String get routineCreateButton => '新しい日課を作る';

  @override
  String get routineSwipeDelete => '日課を消す';

  @override
  String get routineSwipeEdit => '日課を編集';

  @override
  String get routineFlowHomeLabel => 'ホームへ行く';

  @override
  String get routineFlowDraftLabel => '下書き';

  @override
  String get routineFlowLeaveStay => '作り続ける';

  @override
  String get routineFlowLeaveConfirm => '出る';

  @override
  String get routineLeaveDiscardTitle => '日課作りをやめますか？';

  @override
  String get routineLeaveDiscardMessage => '今出ると、書いた内容は残りません';

  @override
  String get routineLeaveDraftWhenReadyTitle => '下書きに残して出ますか？';

  @override
  String get routineLeaveDraftWhenReadyMessage =>
      'カードができあがると下書きに残ります\nマイ情報から続きを作れます';

  @override
  String get routineLeaveDraftTitle => '下書きに残して出ますか？';

  @override
  String get routineLeaveDraftMessage => 'マイ情報の下書きから\n続きを作れます';

  @override
  String get routineLeaveEditTitle => '保存せずに出ますか？';

  @override
  String get routineLeaveEditMessage => '外したカードは「保存する」を押すと外れます';

  @override
  String get routineTileRewardLabel => '完了したら';

  @override
  String get routineTileRerun => '日課をもう一度';

  @override
  String get routineDetailReorderFailedTitle => '順番を保存できませんでした';

  @override
  String get routineDetailReorderFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get routineDetailRerun => '日課をもう一度';

  @override
  String get routineDetailEdit => '編集する';

  @override
  String routineDetailTodayProgress(int done, int total) {
    return '今日 $done/$total できました';
  }

  @override
  String routineDetailPastProgress(int done, int total) {
    return '$done/$total できました';
  }

  @override
  String get routineDetailExportLabel => '印刷用';

  @override
  String get routineDetailFinishedToday => 'すべて終わった日課です';

  @override
  String get routineDetailOpenHint => 'タップしてカードを大きく見る';

  @override
  String get routineDetailNoReward => '日課のあとのごほうびはありません';

  @override
  String get rewardInputHint => '例）動画を10分見る';

  @override
  String get todayRoutineReorderFailedTitle => '順番を保存できませんでした';

  @override
  String get todayRoutineReorderFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get todayRoutineDeleteConfirmTitle => '日課を消しますか？';

  @override
  String get todayRoutineStartedTitle => 'Elumiが始めた日課です';

  @override
  String get todayRoutineStartedMessage => 'やったことが記録に残るように、消すことはできません';

  @override
  String get todayRoutineDeleteAction => '消す';

  @override
  String get todayRoutineDeleteFailedTitle => '日課を消せませんでした';

  @override
  String get todayRoutineDeleteFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get todayRoutineLoadFailedFallback => '日課を読み込めませんでした';

  @override
  String get todayRoutineRerunFailedTitle => '日課を作り直せませんでした';

  @override
  String get todayRoutineRerunFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String todayRoutineCopied(String title, String batchim) {
    return '$titleを今日の日課に入れました';
  }

  @override
  String get todayRoutinePastLoadFailedFallback => '過去の日課を読み込めませんでした';

  @override
  String get todayRoutinePastEmpty => '過去の日課はありません';

  @override
  String get homeCoachCreate => 'Elumiがする*新しい\n日課を作れます*';

  @override
  String get homeCoachSwipe => '日課を*左にスライドすると*\n*編集したり消したり*できます';

  @override
  String get homeCoachSwitch => 'キャラクターのアイコンを押すと\n*Elumiモードに切り替えられます*';

  @override
  String childHomeGreeting(String name, String batchim) {
    return '今日の$nameの\nやることです。がんばりましょう！';
  }

  @override
  String childHomeEmptyTitle(String name, String batchim) {
    return '$nameの日課は\nまだありません';
  }

  @override
  String get childHomeEmptyHint => '保護者モードで日課を作れます';

  @override
  String get childHomeEmptyHintDevice => '保護者の端末で日課を作れます';

  @override
  String get childHomeToGuardianLabel => '保護者モードへ行く';

  @override
  String get childHomeSettingsLabel => '設定を開く';

  @override
  String get childHomeRewardPrefix => 'できたら';

  @override
  String childStarsEarned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '星を$count個もらいました\nやることをやりとげて、もっと星を見つけましょう！',
    );
    return '$_temp0';
  }

  @override
  String childStarsSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '星を$count個集めました',
    );
    return '$_temp0';
  }

  @override
  String childCardPagerLabel(int total, int index) {
    return 'カード$total枚のうち$index枚目';
  }

  @override
  String get childDetailSoundFailedTitle => '音を再生できませんでした';

  @override
  String get childDetailSoundFailedFallback => '端末の音をオンにして、もう一度タップしてください';

  @override
  String get childDetailCheckLabel => 'できました';

  @override
  String get rewardBannerPrefix => 'できたら ';

  @override
  String get rewardLumiTitle => 'おめでとう！';

  @override
  String rewardLumiMessage(String name) {
    return 'やることができたので、ルミが\n$nameに星を持ってきました';
  }

  @override
  String get rewardLumiButton => 'やったー！';

  @override
  String get rewardPopoTitle => 'よくできました！';

  @override
  String rewardPopoMessage(String name) {
    return 'ポポが$nameに\nお祝いのプレゼントとして大きな星を持ってきました';
  }

  @override
  String get rewardPopoButton => 'うれしい！';

  @override
  String get rewardRuruTitle => 'すごいです！';

  @override
  String rewardRuruMessage(String name, String batchim) {
    return '$nameがやることをやりとげたので\nルルがプレゼントを持ってきました';
  }

  @override
  String get rewardRuruButton => 'わーい！';

  @override
  String get routineDoneTitle => '日課が終わりました！';

  @override
  String routineDoneMessage(String name) {
    return 'やることをすべてやりとげた\n$nameのために用意しました';
  }

  @override
  String get routineDoneButton => 'できました！';

  @override
  String get routineDoneRewardCaption => '今日のごほうび';

  @override
  String get modeSwitchToChild => 'パスコードを入力するとElumiモードに切り替わります';

  @override
  String get modeSwitchToGuardian => 'パスコードを入力すると保護者モードに切り替わります';

  @override
  String get modeSwitchTitle => 'パスコードを入力してください';

  @override
  String get modeSwitchMismatch => 'パスコードが違います。もう一度入力してください';

  @override
  String get modeSwitchPinLabel => 'パスコードを入力';

  @override
  String get pinForgotLink => 'パスコードを忘れました';

  @override
  String get pinForgotTitle => 'パスコードを思い出せませんか？';

  @override
  String get pinForgotMessage => '保護者アカウントでもう一度ログインすると\n新しいパスコードを決められます';

  @override
  String get pinForgotRelogin => 'もう一度ログイン';

  @override
  String get modeSwitchReadFailedTitle => 'パスコードを確認できませんでした';

  @override
  String get modeSwitchReadFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get modeSwitchBlockedTitle => '保護者の端末で\n開いてください';

  @override
  String get modeSwitchBlockedDescription => 'この端末では保護者モードを開けません';

  @override
  String get modeSwitchBlockedBack => '戻る';

  @override
  String get installationRetryTitle => '少し問題が起きました';

  @override
  String get installationRetryMessage => 'ログイン情報を確認できませんでした。もう一度お試しください。';

  @override
  String get installationRetryButton => '再試行';

  @override
  String get issuedCodeCopyButton => 'コードをコピーする';

  @override
  String get issuedCodeCopied => 'コードをコピーしました';

  @override
  String get issuedCodeCopyFailedTitle => 'コピーできませんでした';

  @override
  String get issuedCodeCopyFailedFallback => '画面に表示されているコードを直接お伝えください';

  @override
  String linkShareMessage(int minutes, String url, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes分',
    );
    return 'Elumiが使う端末をつなげます。その端末で下のリンクをタップすると、elumアプリに接続コードが入ります。\n接続コードは$_temp0間だけ使えます。\n\n$url\n\nリンクが開かないときは、アプリで直接入力してください。\n接続コード $code';
  }

  @override
  String get linkRejectedAlreadyLinked => 'すでにつながっている端末です';

  @override
  String get linkRejectedOnGuardianPhone => 'Elumiの端末で開いてください';

  @override
  String get myCreditTitle => 'マイクレジット';

  @override
  String get planFreeBadge => 'FREE';

  @override
  String get myCreditKindPeriodicWeek => '週間';

  @override
  String get myCreditKindPeriodicMonth => '月間';

  @override
  String get myCreditKindBonus => 'ボーナス';

  @override
  String get myCreditKindPurchased => '購入したクレジット';

  @override
  String get myCreditSubscribeLabel => '購読すると';

  @override
  String get myCreditSubscribeBody => 'AIの絵も描けて、日課も自動で送ります';

  @override
  String get myCreditPackLabelFree => 'クレジットだけ買う';

  @override
  String get myCreditPackLabelPro => 'クレジットをもっと買う';

  @override
  String get creditGetMore => 'クレジットをもっともらう';

  @override
  String myCreditPackDiscount(int percent) {
    return '-$percent%';
  }

  @override
  String get myCreditPackPopular => '人気！';

  @override
  String myCreditPackBuy(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個買う',
    );
    return '$_temp0（$price）';
  }

  @override
  String get myCreditPackNoExpiryNote => '購入したクレジットに期限はありません';

  @override
  String get myCreditPackPriceFailed => 'クレジットの価格を読み込めませんでした';

  @override
  String myCreditPackTileLabel(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'クレジット$count個',
    );
    return '$_temp0、$price';
  }

  @override
  String get myCreditPurchaseRecheckTitle => 'クレジットがまだ届いていません';

  @override
  String get myCreditPurchaseRecheckBody =>
      'お支払いは終わっています。もう一度払わずに、確認するだけで大丈夫です';

  @override
  String get creditHistoryTitle => 'クレジットの利用履歴';

  @override
  String get creditMineLink => 'マイクレジットを見る';

  @override
  String creditHistoryDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String creditHistoryDetail(String kind, String time) {
    return '$kind・$time';
  }

  @override
  String get creditHistoryKindRoutineText => '日課の文を作る';

  @override
  String creditHistoryKindCardImages(int count) {
    return 'カードの絵 $count枚';
  }

  @override
  String get creditHistoryKindCardImage => 'カードの絵を作る';

  @override
  String get creditHistoryKindImageRegenerate => 'カードの絵を作り直す';

  @override
  String get creditHistoryFree => 'クレジットなし';

  @override
  String get creditHistoryKindWeeklyGrant => '今週のクレジットを補充しました';

  @override
  String get creditHistoryKindAdReward => '広告を見てもらいました';

  @override
  String get creditHistoryKindAdminBonus => '運営からボーナスをお贈りしました';

  @override
  String get creditHistoryKindOtherGrant => 'クレジットをもらいました';

  @override
  String get creditHistoryExpiredWeekTitle => '先週のクレジットの整理';

  @override
  String get creditHistoryExpiredMonthTitle => '先月のクレジットの整理';

  @override
  String get creditHistoryExpiredWeekReason => '使わなかった週間クレジットは繰り越されません';

  @override
  String get creditHistoryExpiredMonthReason => '使わなかった月間クレジットは繰り越されません';

  @override
  String get creditHistoryAdjustedTitle => 'クレジットの調整';

  @override
  String get creditHistoryAdjustedReason => '返金または運営による調整です';

  @override
  String get creditHistoryKindUnknownSpend => 'クレジットを使いました';

  @override
  String get creditHistoryEmptyTitle => 'まだ使ったクレジットはありません';

  @override
  String get creditHistoryEmptyBody => '日課を作るとここに記録されます';

  @override
  String get creditHistoryLoadFailed => '利用履歴を読み込めませんでした';

  @override
  String get creditHistoryMoreFailed => 'これ以上読み込めませんでした';

  @override
  String get reminderRowLabel => '日課のお知らせ';

  @override
  String get reminderRowOff => 'お知らせなし';

  @override
  String reminderRowDaily(String time) {
    return '毎日$timeにお知らせします';
  }

  @override
  String reminderRowOnce(String time) {
    return '$timeに1回お知らせします';
  }

  @override
  String get reminderSheetTitle => 'いつお知らせしますか？';

  @override
  String get reminderSheetBody => '決めた時刻にこの端末に通知が届きます';

  @override
  String get reminderRepeatDaily => '毎日同じ時刻にお知らせする';

  @override
  String get reminderTurnOn => 'お知らせをオンにする';

  @override
  String get reminderUpdate => 'お知らせの時刻を変える';

  @override
  String get reminderTurnOff => 'お知らせをオフにする';

  @override
  String get reminderSavedToast => 'お知らせを設定しました';

  @override
  String get reminderClearedToast => 'お知らせをオフにしました';

  @override
  String get reminderPermissionDeniedTitle => '通知がオフになっています';

  @override
  String get reminderPermissionDeniedBody =>
      '端末の設定でelumの通知を許可すると、日課の時間をお知らせします';

  @override
  String get reminderFailedTitle => 'お知らせを設定できませんでした';

  @override
  String get reminderFailedBody => 'しばらくしてからもう一度お試しください';

  @override
  String get reminderChannelName => '日課のお知らせ';

  @override
  String get reminderNotificationTitle => 'elum';

  @override
  String reminderNotificationBody(String routineTitle) {
    return '$routineTitleの時間です';
  }

  @override
  String get routineTemplateOpen => '例の日課を見てみる';

  @override
  String get routineImageStylePillLabel => 'カードの絵';

  @override
  String routineImageStylePillSemantics(String style) {
    return 'カードの絵のスタイル $style、タップして変更';
  }

  @override
  String get routineTemplateSheetTitle => '例の日課';

  @override
  String get routineTemplateSheetBody => '選ぶと入力欄に入れます。Elumiに合わせて直してから送ってください';

  @override
  String get routineTemplateBeginnerBadge => 'はじめての方におすすめ';

  @override
  String get routineTemplateCategorySelfCare => '生活習慣';

  @override
  String get routineTemplateCategorySelfCareHint => '歯みがき・洗顔・着替え';

  @override
  String get routineTemplateCategoryDailyFlow => '一日の流れ';

  @override
  String get routineTemplateCategoryDailyFlowHint =>
      '朝のしたく・下校後・寝る前（いくつかのことを順番に）';

  @override
  String get routineTemplateCategoryHousehold => '家事';

  @override
  String get routineTemplateCategoryHouseholdHint => '部屋の片づけ・食器の片づけ・洗濯物たたみ';

  @override
  String get routineTemplateCategoryCommunity => '外での活動';

  @override
  String get routineTemplateCategoryCommunityHint => 'バスに乗る・買い物・病院に行く';

  @override
  String get routineTemplateCategoryLearning => '勉強';

  @override
  String get routineTemplateCategoryLearningHint => '宿題を始める・名前を書く・本を読む';

  @override
  String get routineTemplateCategoryFeelings => '気持ち・人との関わり';

  @override
  String get routineTemplateCategoryFeelingsHint => '気持ちカード・あいさつ・順番を待つ';

  @override
  String get routineTemplateBrushTeethText => '歯みがき';

  @override
  String get routineTemplateBrushTeethPrompt =>
      'Elumiがひとりで歯みがきできるようにしたいです。歯ブラシと歯みがき粉を出す、コップに水を入れる、歯をみがく、口をゆすぐ、片づけるまで順番に教えてください';

  @override
  String get routineTemplateWashFaceText => '顔を洗う';

  @override
  String get routineTemplateWashFacePrompt =>
      'Elumiが朝ひとりで顔を洗えるようにしたいです。水を出す、顔をぬらす、せっけんを泡立てる、すすぐ、タオルでふく、ローションをぬるまで教えてください';

  @override
  String get routineTemplateGetDressedText => 'ひとりで着替える';

  @override
  String get routineTemplateGetDressedPrompt =>
      'Elumiがひとりで服を着られるようにしたいです。肌着、Tシャツ、ズボン、くつ下の順にひとつずつ着るのを教えてください';

  @override
  String get routineTemplateEatMealText => 'ごはんを食べる';

  @override
  String get routineTemplateEatMealPrompt =>
      'Elumiが食事の時間に自分でできるようにしたいです。水を飲む、自分のはしとお皿を持っていく、座って食べる、食べ終わったお皿を戻すまで教えてください';

  @override
  String get routineTemplateBathTimeText => 'お風呂に入る';

  @override
  String get routineTemplateBathTimePrompt =>
      'Elumiが順番にお風呂に入れるようにしたいです。服を脱ぐ、体をぬらす、髪を洗う、体を洗う、すすぐ、タオルでふいて服を着るまで教えてください';

  @override
  String get routineTemplateMorningRoutineText => '朝の登校じたく';

  @override
  String get routineTemplateMorningRoutinePrompt =>
      'Elumiが朝起きてから学校に行くまでのことを順番にできるようにしたいです。起きる、トイレに行く、ごはんを食べる、顔を洗って歯をみがく、服を着る、かばんを背負ってくつをはくまで教えてください';

  @override
  String get routineTemplateAfterSchoolText => '学校から帰ったら';

  @override
  String get routineTemplateAfterSchoolPrompt =>
      'Elumiが学校から帰ったら自分でやることをできるようにしたいです。くつをそろえる、手を洗う、かばんを決まった場所に置く、おやつを食べる、休む時間をとるまで教えてください';

  @override
  String get routineTemplateBedtimeText => '寝る前のしたく';

  @override
  String get routineTemplateBedtimePrompt =>
      'Elumiが寝る前にやることを順番にできるようにしたいです。歯みがき、パジャマに着替える、明日のかばんを用意する、電気を消して横になるまで教えてください';

  @override
  String get routineTemplateGoingOutText => 'お出かけのしたく';

  @override
  String get routineTemplateGoingOutPrompt =>
      'Elumiが外に出る前に自分でしたくできるようにしたいです。トイレに行く、上着を着る、水筒と携帯電話を持つ、くつをはく、ドアの前で待つまで教えてください';

  @override
  String get routineTemplateTidyRoomText => '部屋を片づける';

  @override
  String get routineTemplateTidyRoomPrompt =>
      'Elumiが遊んだあと自分で部屋を片づけられるようにしたいです。おもちゃを集める、箱に入れる、本を本棚に戻す、服をかけるまで教えてください';

  @override
  String get routineTemplateClearDishesText => '食べたお皿を片づける';

  @override
  String get routineTemplateClearDishesPrompt =>
      'Elumiが食べ終わったら自分でお皿を片づけられるようにしたいです。残った食べ物を集める、お皿を運ぶ、流しに入れる、テーブルをふくまで教えてください';

  @override
  String get routineTemplateFoldLaundryText => '洗濯物をたたむ';

  @override
  String get routineTemplateFoldLaundryPrompt =>
      'Elumiが乾いた洗濯物をたたんで片づけられるようにしたいです。洗濯物を持ってくる、くつ下のペアを合わせる、タオルをたたむ、服をたたむ、引き出しにしまうまで教えてください';

  @override
  String get routineTemplateTakeOutTrashText => 'ごみを捨てる';

  @override
  String get routineTemplateTakeOutTrashPrompt =>
      'Elumiがごみを分けて捨てられるようにしたいです。ごみを集める、紙とプラスチックを分ける、袋をしばる、決まった場所に捨てるまで教えてください';

  @override
  String get routineTemplateRideBusText => 'バスに乗る';

  @override
  String get routineTemplateRideBusPrompt =>
      'Elumiがひとりでバスに乗る練習をしたいです。バス停で番号を確かめる、列に並ぶ、交通系ICカードをタッチする、席に座る、降りる場所でボタンを押すまで教えてください';

  @override
  String get routineTemplateBuyItemText => 'コンビニで買い物をする';

  @override
  String get routineTemplateBuyItemPrompt =>
      'Elumiがコンビニでひとりで買い物できるようにしたいです。買う物を探す、レジに並ぶ、品物を置く、カードかお金で払う、レシートを受け取ってあいさつするまで教えてください';

  @override
  String get routineTemplateUseElevatorText => 'エレベーターで階へ行く';

  @override
  String get routineTemplateUseElevatorPrompt =>
      'Elumiがエレベーターに乗って決めた階へひとりで行けるようにしたいです。ボタンを押す、ドアが開いたら乗る、数字のボタンを押す、階の数字を見る、降りるまで教えてください';

  @override
  String get routineTemplateHospitalVisitText => '病院に行く';

  @override
  String get routineTemplateHospitalVisitPrompt =>
      'Elumiが病院で順番に診察を受けられるようにしたいです。受付をする、待合室で待つ、名前を呼ばれたら入る、診察を受ける、薬を受け取ってあいさつするまで教えてください';

  @override
  String get routineTemplateStartHomeworkText => '宿題を始める';

  @override
  String get routineTemplateStartHomeworkPrompt =>
      'Elumiが自分で宿題を始めて終えられるようにしたいです。机に座る、ノートとえんぴつを出す、宿題をする、終わったら見せる、かばんに入れるまで教えてください';

  @override
  String get routineTemplateWriteNameText => '名前を書く練習';

  @override
  String get routineTemplateWriteNamePrompt =>
      'Elumiがえんぴつを正しく持って自分の名前を書けるようにしたいです。えんぴつを持つ、紙を置く、名前をなぞる、ひとりで書く、片づけるまで教えてください';

  @override
  String get routineTemplateCountObjectsText => '数をかぞえる遊び';

  @override
  String get routineTemplateCountObjectsPrompt =>
      'Elumiが物をひとつずつ指さして数をかぞえる練習をしたいです。物を並べる、ひとつずつ指でさす、声に出してかぞえる、全部でいくつか言うまで教えてください';

  @override
  String get routineTemplateReadBookText => '本を読む時間';

  @override
  String get routineTemplateReadBookPrompt =>
      'Elumiが自分で本を読む時間をもてるようにしたいです。本を選ぶ、席に座る、1ページずつめくって見る、読み終わったら本棚に戻すまで教えてください';

  @override
  String get routineTemplateEmotionCardText => '怒ったときに気持ちカードを出す';

  @override
  String get routineTemplateEmotionCardPrompt =>
      'Elumiが友だちのことで怒ったとき、大声を出したり押したりせずに気持ちカードを出して見せられるようにしたいです。止まる、ポケットから気持ちカードを出す、今の気持ちのカードを選ぶ、先生に見せるまで教えてください';

  @override
  String get routineTemplatePlayNicelyText => '友だちと仲よく遊ぶ';

  @override
  String get routineTemplatePlayNicelyPrompt =>
      'Elumiが友だちと仲よく遊ぶ練習をしたいです。いっしょに遊ぼうと言う、おもちゃを貸し合う、順番を守る、終わったらありがとうと言うまで教えてください';

  @override
  String get routineTemplateGreetingText => 'あいさつする';

  @override
  String get routineTemplateGreetingPrompt =>
      'Elumiが人に会ったら先にあいさつできるようにしたいです。相手の顔を見る、手をふる、こんにちはと言う、笑顔を見せるまで教えてください';

  @override
  String get routineTemplateWaitTurnText => '順番を待つ';

  @override
  String get routineTemplateWaitTurnPrompt =>
      'Elumiが列に並んで自分の順番を待つ練習をしたいです。列の最後に並ぶ、前の人のうしろで待つ、自分の番か確かめる、順番が来たらするまで教えてください';

  @override
  String get routineTemplateAskHelpText => '手伝ってと言う';

  @override
  String get routineTemplateAskHelpPrompt =>
      'Elumiがひとりでは難しいときに助けを求められるようにしたいです。止まる、近くの大人を探す、手伝ってくださいと言う、助けてもらったらありがとうございますと言うまで教えてください';

  @override
  String get guardianTabHome => 'ホーム';

  @override
  String get guardianTabManage => '日課管理';

  @override
  String get guardianTabTalk => 'トーク';

  @override
  String get guardianTabMe => 'マイ情報';

  @override
  String get guardianMyInfoProfileName => '保護者';

  @override
  String get guardianMyInfoEmailPrivate => 'メール非公開';

  @override
  String guardianMyInfoJoinedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'y. MM. dd',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$dateString に登録';
  }

  @override
  String get guardianMyInfoActiveBadge => '表示中';

  @override
  String get guardianNicknameEditLabel => 'ニックネームを変える';

  @override
  String get guardianNicknameSheetTitle => '自分の名前を変更する';

  @override
  String get guardianNicknameSheetDescription =>
      'トークに書くときに表示される名前です。\n名前は7日に1回変えられます';

  @override
  String get guardianNicknameSheetHint => '名前を入力してください';

  @override
  String get guardianNicknameSheetSave => '保存する';

  @override
  String get guardianNicknameInvalidFormat => 'ハングル・英字・数字・ハイフンで2〜16文字まで使えます';

  @override
  String guardianNicknameChangeableFrom(String since) {
    return '$since変えられます';
  }

  @override
  String get guardianNicknameChanged => 'ニックネームを変えました';

  @override
  String get guardianNicknameSaveFailed => 'ニックネームを変えられませんでした';

  @override
  String get guardianSideNavCaption => '保護者モード';

  @override
  String get guardianSideNavChildScreen => 'Elumiモード';

  @override
  String get routineLibraryEmptyTitle => 'まだ作った日課がありません';

  @override
  String get routineLibraryEmptyBody => '下の「+ 日課を作る」から最初の日課を作ってみましょう';

  @override
  String get routineLibraryLoadFailedFallback => '日課を読み込めませんでした';

  @override
  String get routineLibraryCreate => '新しく作る';

  @override
  String get routineLibrarySendToday => '今日送る';

  @override
  String get routineLibraryEditCards => 'カードを直す';

  @override
  String get routineLibraryAlreadySent => '今日はもう送った日課です';

  @override
  String get routineLibrarySendFailedTitle => '送れませんでした';

  @override
  String get routineLibraryActionFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get routineLibraryCopied => 'コピーを作りました';

  @override
  String get routineLibraryCopyFailedTitle => 'コピーできませんでした';

  @override
  String get routineLibraryMenuRename => '名前を変える';

  @override
  String get routineLibraryMenuCopy => 'コピーする';

  @override
  String get routineLibraryMenuRemove => '削除する';

  @override
  String get routineLibraryRenameHint => '日課の名前';

  @override
  String get routineLibraryRenameSave => '保存する';

  @override
  String get routineLibraryRenamed => '名前を変えました';

  @override
  String get routineLibraryRenameFailedTitle => '名前を変えられませんでした';

  @override
  String get routineLibraryRemoveConfirmTitle => 'この日課を削除しますか？';

  @override
  String get routineLibraryRemoveConfirmMessage =>
      '日課管理から外れます。Elumiの記録はそのまま残ります';

  @override
  String get routineLibraryRemoved => '日課を削除しました';

  @override
  String get routineLibraryRemoveFailedTitle => '削除できませんでした';

  @override
  String get routineLibrarySentBadge => '今日送りました';

  @override
  String get routineLibraryTileHint => '長押しするとメニューが開きます';

  @override
  String get routineLibraryFromTalk => 'トークから';

  @override
  String get routineLibraryNewBadge => '新しい日課';

  @override
  String get routineDetailTalkOriginBand => 'トークから持ってきました';

  @override
  String get routineDetailTalkOriginOpenPost => '元の投稿';

  @override
  String get routineDetailTalkOriginPostGone => '削除された投稿';

  @override
  String get routineDetailTalkOriginBandOpenLabel => 'トークから持ってきました、元の投稿を見る';

  @override
  String routineLibrarySent(String title, String batchim) {
    return '$titleを今日の日課として送りました';
  }

  @override
  String onboardingExampleTitle(String name, String batchim) {
    return '$nameの、どんなことを\n手伝いたいですか?';
  }

  @override
  String get onboardingExampleDescription =>
      '選んだ分類の例の日課を入れておきます。\n複数選んでもかまいません。';

  @override
  String get onboardingExampleSkip => 'スキップ';

  @override
  String get exampleCategoryMorningEvening => '朝・夜のしたく';

  @override
  String get exampleCategoryMorningEveningHint => '洗面、着替え、寝る準備';

  @override
  String get exampleCategorySchoolStudy => '学校・勉強';

  @override
  String get exampleCategorySchoolStudyHint => '登校のしたく、宿題';

  @override
  String get exampleCategoryHouseSelf => '家事・自分でする';

  @override
  String get exampleCategoryHouseSelfHint => '片づけ、食卓の準備';

  @override
  String get exampleCategoryOutside => '外でやってみる';

  @override
  String get exampleCategoryOutsideHint => 'バスに乗る、買い物';

  @override
  String get exampleRoutinesFailed => '例の日課を入れられませんでした';

  @override
  String get routineGroupMenuAddToGroup => 'グループに入れる';

  @override
  String get routineGroupMenuReorder => '順番を変える';

  @override
  String get routineGroupMenuUngroup => 'グループを解除';

  @override
  String routineGroupTileLabel(String name, int count) {
    return '$name グループ、日課 $count件';
  }

  @override
  String get routineGroupDefaultName => '新しいグループ';

  @override
  String get routineGroupNameLabel => 'グループの名前';

  @override
  String get routineGroupNameHint => '例：登校前のしたく';

  @override
  String get routineGroupNewTitle => '新しいグループを作る';

  @override
  String routineGroupAddTitle(String name) {
    return '$nameに入れる';
  }

  @override
  String get routineGroupPickHintNew => '入れる日課を、表示したい順番にタップしてください';

  @override
  String get routineGroupPickHint => '入れる日課を順番にタップしてください';

  @override
  String get routineGroupPickEmpty => '入れられる日課がありません';

  @override
  String routineGroupPickConfirmNew(int count) {
    return '$count件でグループにする';
  }

  @override
  String routineGroupPickConfirmAdd(int count) {
    return '$count件入れる';
  }

  @override
  String get routineGroupCreateMenuTitle => '何を作りますか？';

  @override
  String get routineGroupCreateRoutine => '新しい日課を作る';

  @override
  String get routineGroupCreateGroup => '新しいグループを作る';

  @override
  String get routineGroupCreateGroupDescription =>
      'いくつかの日課をひとつのフォルダにまとめます（例：朝の登校）';

  @override
  String get routineGroupChooseTitle => 'どのグループに入れますか？';

  @override
  String routineGroupSheetCount(int count) {
    return '日課 $count件';
  }

  @override
  String get routineGroupSheetAdd => '日課を入れる';

  @override
  String routineGroupSheetRemove(String title) {
    return '$titleをグループから外す';
  }

  @override
  String get routineGroupCreated => 'グループを作りました';

  @override
  String get routineGroupAdded => 'グループに入れました';

  @override
  String get routineGroupUngrouped => 'グループを解除しました';

  @override
  String get routineGroupUngroupedEmpty => '日課をすべて外したので、グループを解除しました';

  @override
  String routineGroupSent(String name) {
    return '$name グループを今日の日課として送りました';
  }

  @override
  String get routineGroupAllSentAlready => 'グループ内の日課は今日すべて送りました';

  @override
  String get routineGroupActionFailedTitle => 'グループを変更できませんでした';

  @override
  String get routineGroupUngroupConfirmTitle => 'グループを解除しますか？';

  @override
  String get routineGroupUngroupConfirmMessage => '中の日課は日課管理にそのまま残ります';

  @override
  String routineGroupRemoveConfirmTitle(String title) {
    return '$titleをグループから外しますか?';
  }

  @override
  String get routineGroupRemoveConfirmMessage => '日課は日課管理にそのまま残ります';

  @override
  String get routineGroupRemoveConfirmAction => '外す';

  @override
  String childHomeGroupProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String get childHomeGroupAllDone => 'できました！';

  @override
  String get routineTitleEdit => '日課の名前を変える';

  @override
  String get routineDetailMore => 'もっと見る';

  @override
  String get libraryArrangeDone => '完了';

  @override
  String get libraryArrangeRemove => '削除またはグループ解除';

  @override
  String get routineGroupEditOrder => '編集';

  @override
  String get routineLibrarySendOnlyThis => 'この日課だけ今日送る';

  @override
  String routineGroupRowCardCount(int count) {
    return 'カード$count枚';
  }

  @override
  String get routineManageCoachTapMessage => '日課を*押す*とカードが見られます';

  @override
  String get routineManageCoachLongPressMessage => '長押ししてから*離す*とメニューが開きます';

  @override
  String get routineManageCoachDragMessage =>
      '長押ししたまま*動かす*と整理モードになります\nほかの日課の上に置くと*グループ*になり\n間に置くと場所を移します';

  @override
  String get cardReviewCoachEditMessage =>
      '表示中のカードの*文と絵*を直します\n絵は*自分の写真*に変えることもできます';

  @override
  String get cardReviewCoachReorderMessage =>
      'ここをタップしてからカードを*長押しして動かす*と\n順番が変わります';

  @override
  String get cardReviewCoachSaveMessage =>
      '直し終わったら必ず*カードを保存*をタップしてください\nタップすると日課ができあがります';

  @override
  String get coachHelpLabel => '使い方を見る';

  @override
  String get pushPermissionSheetTitle => 'Elumiが日課を終えたらお知らせしますか？';

  @override
  String get pushPermissionSheetBody => 'ほかの保護者からのお知らせやクレジットの案内も届きます';

  @override
  String get pushPermissionAllow => '通知を受け取る';

  @override
  String get pushPermissionLater => 'あとで';

  @override
  String get pushPermissionDenied => '通知設定でいつでもオンにできます';

  @override
  String get pushChannelGuardianUpdates => '保護者向け通知';

  @override
  String get pushPermissionNudgeTitle => '通知がオフになっています';

  @override
  String get pushPermissionNudgeBody => 'オンにすると、Elumiが日課を終えたときすぐにお知らせします';

  @override
  String get pushPermissionElumiTitle => '新しい日課が届いたらお知らせしますか？';

  @override
  String get pushPermissionElumiBody => '保護者が日課を送ると、この端末に通知が届きます';

  @override
  String get pushPermissionTurnOn => '通知をオンにする';

  @override
  String get pushChannelElumiRoutines => '新しい日課の通知';

  @override
  String get signInProviderKakao => 'Kakao';

  @override
  String get signInProviderNaver => 'NAVER';

  @override
  String get signInProviderGoogle => 'Google';

  @override
  String get signInProviderApple => 'Apple';

  @override
  String get routineManageCoachSampleMorning => '朝のしたく';

  @override
  String get routineManageCoachSampleBrush => '歯みがき';

  @override
  String get routineManageCoachSampleBag => 'かばんの準備';

  @override
  String get updateSuggestionTitle => '新しいバージョンがあります';

  @override
  String get updateSuggestionBody => 'アップデートすると最新の修正と機能を使えます';

  @override
  String get updateSuggestionLater => 'あとで';

  @override
  String elumiInfoTitle(String name) {
    return '$nameの情報';
  }

  @override
  String elumiInfoEditLabel(String name) {
    return '$nameの情報を直す';
  }

  @override
  String get elumiInfoName => '名前';

  @override
  String get elumiInfoCharacter => 'キャラクター';

  @override
  String get elumiInfoCharacterSheetTitle => 'キャラクターを変える';

  @override
  String get elumiInfoImageStyleSheetTitle => '絵のスタイルを変える';

  @override
  String get elumiInfoSave => '保存する';

  @override
  String get elumiInfoSaved => '保存しました';

  @override
  String get elumiInfoSaveFailedTitle => '保存できませんでした';

  @override
  String get elumiInfoSaveFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get elumiInfoNotFound => 'Elumiの情報を読み込めませんでした';

  @override
  String get talkTitle => 'トーク';

  @override
  String get talkWriteButton => '投稿する';

  @override
  String get talkCategoryAll => 'すべて';

  @override
  String get talkPopularTitle => '今週たくさん持っていかれた日課です';

  @override
  String talkPopularImportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人が持っていきました',
    );
    return '$_temp0';
  }

  @override
  String get talkLatestTitle => '新しく投稿されました';

  @override
  String get talkEmptyTitle => 'まだシェアされた日課がありません';

  @override
  String get talkEmptyCategoryTitle => 'この分類にはまだシェアされた日課がありません';

  @override
  String get talkEmptyCategoryAction => 'すべて見る';

  @override
  String get talkFeedFailed => 'トークを読み込めませんでした';

  @override
  String get talkAuthorFallback => '保護者';

  @override
  String get talkShareTitleLabel => '日課のタイトル';

  @override
  String get talkShareTitleHint => '日課のタイトルを書いてください';

  @override
  String get talkNoteLabel => '内容';

  @override
  String talkHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '役に立った $count',
    );
    return '$_temp0';
  }

  @override
  String talkCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コメント $count',
    );
    return '$_temp0';
  }

  @override
  String get talkLoadMoreRetry => '続きを読み込めませんでした。押してもう一度試してください';

  @override
  String talkDetailStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'カード$count枚',
    );
    return '$_temp0';
  }

  @override
  String get talkDetailLoadFailed => '投稿を読み込めませんでした';

  @override
  String get talkPostGoneTitle => 'もう見られない投稿です';

  @override
  String get talkPostGoneBack => 'トークに戻る';

  @override
  String talkDetailCardCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count枚',
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
  String get talkViewGrid => 'ひと目で見る';

  @override
  String get talkViewLarge => '大きく見る';

  @override
  String get talkHelpfulFailed => '「役に立った」を変えられませんでした。少したってからもう一度試してください';

  @override
  String get talkImportButton => '日課に持ってくる';

  @override
  String get talkImportedButton => '✓ 日課管理に入れました';

  @override
  String get talkShareLinkButton => 'シェアする';

  @override
  String talkShareLinkMessage(String title, String url) {
    return '$title\nelumのトークで一緒に見ましょう\n\n$url';
  }

  @override
  String get talkShareLinkFailed => 'シェアできませんでした。少したってからもう一度試してください';

  @override
  String get talkPostLinkRejectedOnElumiDevice => 'トークの投稿は保護者の端末で見られます';

  @override
  String get talkImportSheetTitle => '日課に持ってくる';

  @override
  String get talkImportSheetHint => '日課に追加したあと、Elumiに合わせて直せます';

  @override
  String get talkImportElumiLabel => 'Elumi';

  @override
  String get talkImportConfirm => '完了';

  @override
  String get talkImportNoElumiTitle => '先にElumiをつなげてください';

  @override
  String get talkImportNoElumiAction => 'Elumiをつなげる';

  @override
  String talkImportDone(String routineTitle, String batchim) {
    return '$routineTitleを取り込みました';
  }

  @override
  String get talkImportGoToLibrary => '見に行く';

  @override
  String get talkImportFailedTitle => '日課管理に入れられませんでした';

  @override
  String get talkCommentsTitle => 'コメント';

  @override
  String get talkCommentsEmpty => 'まだコメントがありません';

  @override
  String talkCommentAuthorMine(String name) {
    return '$name(自分)';
  }

  @override
  String talkCommentAuthorPostWriter(String name) {
    return '$name(投稿者)';
  }

  @override
  String get talkCommentHiddenNotice => '運営ポリシーにより非表示にしました';

  @override
  String get talkCommentsFailed => 'コメントを読み込めませんでした';

  @override
  String get talkCommentHint => 'コメントを書いてみましょう';

  @override
  String get talkCommentSend => '送る';

  @override
  String get talkCommentSendFailedTitle => 'コメントを送れませんでした';

  @override
  String get talkFailedFallback => '少したってからもう一度試してください';

  @override
  String get talkCommentDeleteTitle => 'コメントを消しますか?';

  @override
  String get talkCommentDeleteAction => '消す';

  @override
  String get talkCommentDeleteFailedTitle => 'コメントを消せませんでした';

  @override
  String get talkMenuReport => '通報する';

  @override
  String get talkMenuBlock => 'この保護者の投稿を非表示にする';

  @override
  String get talkMenuEdit => '直す';

  @override
  String get talkMenuTakeDown => '取り下げる';

  @override
  String get talkMoreLabel => 'その他';

  @override
  String get talkTakeDownTitle => 'この投稿を取り下げますか?';

  @override
  String get talkTakeDownMessage => '取り下げた投稿は、ほかの保護者にはもう見えません。';

  @override
  String get talkTakeDownDone => '投稿を取り下げました';

  @override
  String get talkTakeDownFailedTitle => '投稿を取り下げられませんでした';

  @override
  String get talkEditTitle => '投稿を直す';

  @override
  String get talkEditSave => '保存する';

  @override
  String get talkEditSaved => '直しました';

  @override
  String get talkEditFailedTitle => '投稿を直せませんでした';

  @override
  String get talkNoteGuide => 'ほかの人の名前や連絡先などの個人情報は書かないでください';

  @override
  String get talkCategoryTitle => '分類';

  @override
  String get talkReportTitle => '通報する';

  @override
  String get talkReportSubmit => '通報する';

  @override
  String get talkReportDone => '通報しました';

  @override
  String get talkReportFailedTitle => '通報できませんでした';

  @override
  String get talkReportReasonPersonalInfo => 'Elumiや家族の情報が見えます';

  @override
  String get talkReportReasonOffensive => '嫌な言葉があります';

  @override
  String get talkReportReasonAdvertising => '広告や宣伝です';

  @override
  String get talkReportReasonOther => 'そのほかの理由';

  @override
  String talkBlockTitle(String nickname) {
    return '$nicknameさんの投稿を非表示にしますか?';
  }

  @override
  String get talkBlockMessage =>
      'この保護者の投稿とコメントが見えなくなります。相手には分かりません。マイ情報 › 非表示の保護者でまた見られます。';

  @override
  String get talkBlockAction => '非表示にする';

  @override
  String get talkBlockDone => '非表示にしました';

  @override
  String get talkBlockFailedTitle => '非表示にできませんでした';

  @override
  String get talkBlockedGuardiansTitle => '非表示の保護者';

  @override
  String get talkBlockedGuardiansEmpty => '非表示の保護者はいません';

  @override
  String get talkBlockedGuardiansFailed => '非表示の保護者を読み込めませんでした';

  @override
  String get talkUnblockAction => 'また見る';

  @override
  String get talkUnblockDone => 'また見られます';

  @override
  String get talkUnblockFailedTitle => '非表示を解除できませんでした';

  @override
  String get talkRulesTitle => 'トークの利用ルール';

  @override
  String get talkRulesIntro => '保護者どうし安全にシェアするため、この3つを守ってください。';

  @override
  String get talkRulesPrivacy => '顔・名前・学校・家の住所が見えないようにしてください';

  @override
  String get talkRulesRespect => 'ほかの保護者を大切にしてください。非難・広告・宣伝はできません';

  @override
  String get talkRulesNoDiagnosis => '診断名・病院の情報は書かないでください';

  @override
  String get talkRulesAgreeCheck => '上のルールを読み、守ります';

  @override
  String get talkRulesAgreeButton => '同意して続ける';

  @override
  String get talkRulesFailedTitle => '同意を保存できませんでした';

  @override
  String get talkShareTitle => 'トークに投稿する';

  @override
  String get talkSharePickTitle => 'どの日課をシェアしますか?';

  @override
  String get talkSharePickEmpty => '投稿できる日課がありません';

  @override
  String get talkSharePickEmptyHint =>
      '日課管理にある自分の日課だけ投稿できます。もう投稿した日課や、トークから持ってきた日課は入りません。例の日課は、タイトルやカードを直すと投稿できます。';

  @override
  String get talkSharePickFailed => '日課を読み込めませんでした';

  @override
  String get talkSharePreviewFailed => '投稿する内容を読み込めませんでした';

  @override
  String get talkSharePhotoTitle => '写真はどう投稿しますか?';

  @override
  String get talkSharePhotoGuide =>
      '顔・名前・家の住所が見えたら、ぼかしてください。\nAIで作った絵はそのまま投稿されます';

  @override
  String get talkSharePhotoBlur => 'ぼかす';

  @override
  String get talkSharePhotoKeep => 'そのまま';

  @override
  String get talkSharePhotoNext => '次へ';

  @override
  String get talkSharePreviewTitle => 'このように見えます';

  @override
  String get talkShareSubmit => '投稿する';

  @override
  String get talkShareDone => 'トークに投稿しました';

  @override
  String get talkShareFailedTitle => '投稿できませんでした';

  @override
  String get talkShareHint => '📖 トークでシェアしてみる ›';

  @override
  String get talkMenuShare => 'トークでシェアする';

  @override
  String get talkMyPostsTitle => '自分の投稿';

  @override
  String get talkMyPostsEmpty => 'まだ投稿がありません';

  @override
  String get talkMyPostsEmptyAction => 'トークで日課をシェアする';

  @override
  String get talkMyPostsFailed => '自分の投稿を読み込めませんでした';

  @override
  String get talkMenuViewMyPost => '自分の投稿を見る';

  @override
  String get talkLinkSend => 'リンクで送る';

  @override
  String get talkLinkTurnOff => 'リンクをオフにする';

  @override
  String get talkLinkConfirmTitle => 'このルーティンをリンクで送りますか?';

  @override
  String get talkLinkConfirmGuide =>
      'リンクを受け取った人だけが見られます。トークには投稿されません。\n送ったあともルーティン管理でリンクをオフにできます';

  @override
  String get talkLinkResendGuide =>
      'すでに送ったリンクがあります。最初に送った内容のまま同じリンクをもう一度送ります。\n変更を送るには、リンクをオフにしてから送り直してください';

  @override
  String get talkLinkPhotoTitle => '写真をどう送りますか?';

  @override
  String get talkLinkPhotoGuide =>
      '顔、名前、住所が写っていたらぼかしてください。\nAIで作った絵はそのまま表示されます';

  @override
  String get talkLinkCreateButton => 'リンクを作る';

  @override
  String get talkLinkPreviewFailed => '送る内容を読み込めませんでした';

  @override
  String get talkLinkCreateFailedTitle => 'リンクを作れませんでした';

  @override
  String get talkLinkCreated => 'リンクを作りました';

  @override
  String talkLinkShareMessage(String title, String url) {
    return '$title\nelumでこのルーティンを取り込んでみてください\n\n$url';
  }

  @override
  String get talkLinkTurnOffTitle => 'リンクをオフにしますか?';

  @override
  String get talkLinkTurnOffMessage =>
      'リンクを受け取った人はもう見られません。すでに取り込んだルーティンはそのまま残ります';

  @override
  String get talkLinkTurnOffDone => 'リンクをオフにしました';

  @override
  String get talkLinkTurnOffFailedTitle => 'リンクをオフにできませんでした';

  @override
  String get talkLinkReceivedTitle => '受け取ったルーティン';

  @override
  String get timeAgoJustNow => 'たった今';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count分前',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count時間前',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日前',
    );
    return '$_temp0';
  }

  @override
  String routineProgressRingPercentLabel(int percent) {
    return '$percent% できました';
  }

  @override
  String get routineProgressRingDoneLabel => 'ぜんぶできました';

  @override
  String get guardianSettingsLicenses => 'オープンソースライセンス';

  @override
  String get licenseScreenTitle => 'オープンソースライセンス';

  @override
  String get licenseScreenGuide =>
      'elumは下記の絵、フォント、プログラムを使って作りました。項目をタップするとライセンス全文を見られます。';

  @override
  String get licenseGroupArtwork => '絵';

  @override
  String get licenseGroupFonts => 'フォント';

  @override
  String get licenseGroupSoftware => 'プログラム';

  @override
  String get licenseSoftwareListRow => 'プログラム一覧を見る';

  @override
  String get licenseFontTmoneyName => 'Tmoney RoundWind';

  @override
  String get licenseLoadFailedMessage => '一覧を読み込めませんでした';

  @override
  String get cardExportOpen => '印刷用に保存';

  @override
  String get cardExportFormatSection => 'どの形で保存しますか？';

  @override
  String get cardExportFormatRoutineSheet => '日課を1枚に';

  @override
  String get cardExportFormatRoutineSheetCaption => 'A4 1枚に順番どおり';

  @override
  String get cardExportFormatCutCards => '切って使うカード';

  @override
  String get cardExportFormatCutCardsCaption => 'A4に切り取り線つき';

  @override
  String get cardExportFormatCardImages => 'カードを1枚ずつ';

  @override
  String get cardExportFormatCardImagesCaption => 'カードごとに画像1枚';

  @override
  String get cardExportPerPageSection => '1ページに何枚入れますか？';

  @override
  String get cardExportIncludeText => 'カードの文を入れる';

  @override
  String get cardExportThemeSection => 'カードのデザイン';

  @override
  String get cardExportThemeBasic => '基本';

  @override
  String get cardExportThemeSimple => 'シンプル';

  @override
  String get cardExportThemeInkSaver => 'インク節約';

  @override
  String get cardExportThemeMonochrome => '白黒';

  @override
  String get cardExportThemeLargeText => '大きい文字';

  @override
  String get planProBadge => 'PRO';

  @override
  String get cardExportProThemeLocked => 'Proで使えるデザインです';

  @override
  String get cardExportWatermarkNotice => 'Freeでは下にelumのロゴ帯が入ります';

  @override
  String get cardExportPreviewSection => 'プレビュー';

  @override
  String get cardExportMissingPicture => 'まだ絵がないカードはタイトルだけが入ります';

  @override
  String cardExportSomePicturesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '絵を読み込めなかったカード$count枚は、別の絵かタイトルで入ります',
    );
    return '$_temp0';
  }

  @override
  String get cardExportActualSizeHint => 'ほかのアプリで印刷するときは「実際のサイズ」を選んでください';

  @override
  String get cardExportPrint => '印刷する';

  @override
  String get cardExportShare => '送る';

  @override
  String get cardExportPreparing => 'カードを準備しています';

  @override
  String get cardExportImageFailed => 'カードの絵を読み込めませんでした';

  @override
  String get cardExportRenderFailed => '印刷用ファイルを作れませんでした';

  @override
  String get cardExportPrintFailed => 'この端末では印刷できません。「送る」で保存してください';

  @override
  String get cardExportNoCards => 'カードがない日課です';

  @override
  String get cardExportNoneSelected => '送るカードを1枚以上選んでください';

  @override
  String get printBrandTagline => '毎日をいっしょに | elum 行動カード';

  @override
  String get cardExportPictogramCredit => '絵：Mulberry Symbols (CC BY-SA 4.0)';

  @override
  String get cardExportEmojiCredit => '絵：Twemoji (CC BY 4.0)';

  @override
  String cardExportPerPage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count枚',
    );
    return '$_temp0';
  }

  @override
  String get cardExportFormatRow => '形式';

  @override
  String get cardExportLayoutSection => '配置';

  @override
  String get cardExportStyleSection => 'デザイン';

  @override
  String get cardExportOrientationRow => '用紙の向き';

  @override
  String get cardExportOrientationSheetTitle => '用紙をどの向きにしますか？';

  @override
  String get cardExportOrientationPortrait => '縦';

  @override
  String get cardExportOrientationLandscape => '横';

  @override
  String get cardExportPerPageRow => '1枚に';

  @override
  String get cardExportCardSizeRow => 'カードの大きさ';

  @override
  String get cardExportCardSizeSheetTitle => 'カードをどのくらいの大きさにしますか？';

  @override
  String get cardExportCardSizeFit => 'いっぱいに';

  @override
  String get cardExportCardSizeMedium => 'ふつう';

  @override
  String get cardExportCardSizeSmall => '小さく';

  @override
  String get cardExportProLayoutLocked => 'Proで使える形式です';

  @override
  String get cardExportUpsellTitle => 'Proなら好きな形で保存できます';

  @override
  String get cardExportUpsellBody => '日課を1枚に、切って使うカード、1枚に複数、横向きの用紙、デザインまで選べます';

  @override
  String get modeSwitchToPurchase => 'お支払いは保護者だけができます';

  @override
  String get planBenefitAiImageStyles => 'カードごとにAIが絵をかきます';

  @override
  String get planBenefitAdsRemoved => '広告なしで使えます';

  @override
  String get planBenefitWeeklyReport => '週間レポートが届きます';

  @override
  String get planBenefitRoutineSchedule => '曜日と時刻を決めて毎日送ります';

  @override
  String get planBenefitRoutineMemory => '自分が直したやり方を覚えます';

  @override
  String get planBenefitGuardianVoice => '保護者の声でカードを読み上げます';

  @override
  String get planBenefitFreeRoutineText => '日課の文はクレジットなしで作れます';

  @override
  String get planBenefitFreeImageRegenerate => '1日の決まった回数まで、クレジットなしで絵をかき直せます';

  @override
  String planBenefitFreeImageRegenerateDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '1日$count回まで、クレジットなしでかき直せます',
    );
    return '$_temp0';
  }

  @override
  String get planBenefitMoreWeeklyCredits => '毎週もっと多くのクレジットがもらえます';

  @override
  String get planBenefitMoreMonthlyCredits => '毎月もっと多くのクレジットがもらえます';

  @override
  String get planBenefitCardExportWithoutWatermark => '印刷物の下に帯が入らずすっきりします';

  @override
  String get planBenefitCardExportAllThemes => 'すべての印刷デザインから選べます';

  @override
  String get planBenefitCardExportAllLayouts => '日課を1枚に、切って使うカードで印刷できます';

  @override
  String get planKeepContentNotice => 'Proが終わっても、作った日課と絵はそのまま残ります';

  @override
  String get planPeriodMonthly => '1か月';

  @override
  String get planPeriodYearly => '1年';

  @override
  String get planSubscribe => 'サブスクリプションを始める';

  @override
  String get planPriceLoading => '価格を読み込んでいます';

  @override
  String get planPriceFailed => '価格を読み込めませんでした';

  @override
  String get planRestore => '購入を復元';

  @override
  String get planTermsOfUse => '利用規約';

  @override
  String get planPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get planManageSubscription => 'サブスクリプションの管理';

  @override
  String get planLegalBillingAppStore =>
      'お支払いは購入の確認時にApple IDアカウントに請求されます。期間終了の24時間以上前に解約しない限り、同じ期間・価格で自動更新され、期間終了前の24時間以内に次回分が請求されます。';

  @override
  String get planLegalCancelAppStore =>
      'サブスクリプションの管理と解約は、端末の設定 > Apple ID > サブスクリプションでできます。解約しても残りの期間まではProを使えます。';

  @override
  String get planLegalBillingPlayStore =>
      'お支払いは購入の確認時にGoogle Playアカウントに請求されます。解約するまで同じ期間・価格で自動更新されます。';

  @override
  String get planLegalCancelPlayStore =>
      'サブスクリプションの管理と解約は、Google Playストアのお支払いと定期購入 > 定期購入でできます。解約しても残りの期間まではProを使えます。';

  @override
  String planTrialDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日間',
    );
    return '$_temp0';
  }

  @override
  String planTrialMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countか月',
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
    return '$trial無料で始める';
  }

  @override
  String get planLegalTrialAppStore => '無料体験が終わる24時間以上前に解約すれば、料金は請求されません。';

  @override
  String get planLegalTrialPlayStore => '無料体験中に解約すれば、料金は請求されません。';

  @override
  String get planVerifying => 'お支払いを確認しています';

  @override
  String get planStorePendingTitle => 'お支払いの承認をリクエストしました';

  @override
  String get planStorePendingBody => '承認されるとProがオンになります。この画面は閉じてもかまいません。';

  @override
  String get planVerificationPendingTitle => 'お支払いを確認しています';

  @override
  String get planVerificationPendingBody =>
      'もう一度支払う必要はありません。アプリを開き直すと、もう一度確認します';

  @override
  String get planVerificationRetry => 'もう一度確認する';

  @override
  String get planActivatedStart => '始める';

  @override
  String get planActivatedTitle => 'Proを始めました';

  @override
  String get planNotActivatedTitle => 'Proがオンになりませんでした';

  @override
  String get planNotActivatedBodyApple =>
      'App Storeアプリ → 右上の自分の写真 → サブスクリプションで、elumのサブスクリプションを確認してください';

  @override
  String get planNotActivatedBodyGoogle =>
      'Playストアアプリ → 右上のプロフィール → お支払いと定期購入 → 定期購入で、elumの定期購入を確認してください';

  @override
  String get planOpenAppStore => 'App Storeで確認する';

  @override
  String get planOpenPlayStore => 'Playストアで確認する';

  @override
  String get planAlreadyProTitle => 'Proを利用中です';

  @override
  String get planPurchaseFailedTitle => 'お支払いできませんでした';

  @override
  String get planVerifyFailedTitle => 'お支払いをこのアカウントにつなげられませんでした';

  @override
  String get planAccountFailedTitle => 'アカウント情報を確認できませんでした';

  @override
  String get planFailedFallback => 'しばらくしてからもう一度お試しください';

  @override
  String get planRestoreDone => 'Proを復元しました';

  @override
  String get planRestoreNothing => '復元できるサブスクリプションがありません';

  @override
  String get planRestoreNothingHintApple =>
      '購入したときのApple IDでこの端末にログインしているか確認してください。elumにも購入したときと同じ方法でログインする必要があります';

  @override
  String get planRestoreNothingHintGoogle =>
      '購入したときのGoogleアカウントでPlayストアにログインしているか確認してください。elumにも購入したときと同じ方法でログインする必要があります';

  @override
  String get planRestoreFailedTitle => '購入を復元できませんでした';

  @override
  String get planRestoring => '購入履歴を確認しています';

  @override
  String get planManageFailed => 'サブスクリプションの管理画面を開けませんでした';

  @override
  String get planLinkFailed => 'リンクを開けませんでした';

  @override
  String get planSettingsLabel => 'マイプラン';

  @override
  String get planStatusFree => 'Free';

  @override
  String get planStatusPro => 'Pro';

  @override
  String planStatusRenewing(String date) {
    return 'Pro、$dateに更新されます';
  }

  @override
  String planStatusUntil(String date) {
    return 'Pro、$dateまで';
  }

  @override
  String planStatusCancelScheduled(String date) {
    return 'Pro、$dateに終了します';
  }

  @override
  String get planStatusGracePeriod => 'Pro、お支払いの確認が必要です';

  @override
  String planStatusTrial(int days) {
    return 'Pro体験中、残り$days日です';
  }

  @override
  String get planStatusTrialLastDay => 'Pro体験中、今日までです';

  @override
  String get planStatusGift => 'Proプレゼント';

  @override
  String planStatusGiftUntil(String date) {
    return 'Proプレゼント、$dateまで';
  }

  @override
  String planStatusRenewingFooter(String date) {
    return '$dateに更新されます';
  }

  @override
  String planStatusUntilFooter(String date) {
    return '$dateまで使えます';
  }

  @override
  String planStatusCancelScheduledFooter(String date) {
    return '$dateに終了します';
  }

  @override
  String get planStatusGracePeriodFooter => 'お支払い方法を確認してください';

  @override
  String get planSheetNextPaymentLabel => '次回のお支払い日';

  @override
  String get planSheetEndDateLabel => '終了日';

  @override
  String get planSheetStoreLabel => 'お支払い先';

  @override
  String get planSheetStoreAppStore => 'App Store';

  @override
  String get planSheetStoreGooglePlay => 'Google Play';

  @override
  String planSheetRenewingNote(String date) {
    return '解約しない限り、$dateに自動でお支払いされます。解約はサブスクリプションの管理からできます';
  }

  @override
  String get planSheetEndsToFreeNote => '終了するとFreeに切り替わります。自動でお支払いされることはありません';

  @override
  String get planSheetUnlimitedNote => '期限なしでProを使えます';

  @override
  String get planLearnPro => 'Proについて見る';

  @override
  String get weeklyReportTitle => '週間レポート';

  @override
  String weeklyReportWeekRange(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日～$endMonth月$endDay日';
  }

  @override
  String weeklyReportThisWeekRange(String range) {
    return '今週 · $range';
  }

  @override
  String get weeklyReportPreviousWeek => '先週を見る';

  @override
  String get weeklyReportNextWeek => '次の週を見る';

  @override
  String get weeklyReportCompletionLabel => '日課の達成率';

  @override
  String weeklyReportPercent(int percent) {
    return '$percent%';
  }

  @override
  String weeklyReportCompletionSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '送った日課$sent件のうち$completed件を終えました',
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
  String get weeklyReportStars => 'もらった星';

  @override
  String get weeklyReportRewards => 'ごほうびをもらった日課';

  @override
  String get weeklyReportStreak => '連続で終えた日';

  @override
  String weeklyReportCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRoutinesSection => '日課ごとの記録';

  @override
  String weeklyReportRoutineValue(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent回中$completed回終えました',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportRemainingSection => 'よく残ったカード';

  @override
  String weeklyReportRemainingLabel(String routine, String step) {
    return '$routine · $step';
  }

  @override
  String weeklyReportTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count回',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportEmptyTitle => 'この週は送った日課がありません';

  @override
  String get weeklyReportEmptyBody => '日課を送ると、Elumiが終えた記録がここに集まります';

  @override
  String get weeklyReportNoCompletionThisWeekTitle => '今週はまだ記録がありません';

  @override
  String get weeklyReportNoCompletionPastWeekTitle => 'この週は終えた日課がありません';

  @override
  String get weeklyReportNoCompletionBody => '今日の日課を送ってみましょうか？';

  @override
  String get weeklyReportGoToManage => '日課管理へ';

  @override
  String get weeklyReportLoadFailed => '週間レポートを読み込めませんでした';

  @override
  String get weeklyReportNotIncluded => '週間レポートはProで見られます';

  @override
  String get weeklyReportShareImage => '画像';

  @override
  String get weeklyReportSharePdf => 'PDF';

  @override
  String get weeklyReportShareFailed => '送るページを作れませんでした';

  @override
  String weeklyReportShareTitle(String name, String batchim) {
    return '$nameの1週間';
  }

  @override
  String get weeklyReportShareNote => 'elumアプリに残った完了記録を数えた内容です';

  @override
  String get weeklyReportRecordSection => '1週間の記録';

  @override
  String get weeklyReportDonutLabel => '達成率';

  @override
  String weeklyReportDonutSummary(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: 'ルーティン$sent件中$completed件を終えました',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDonutSemantics(int percent, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '達成率$percentパーセント、ルーティン$sent件中$completed件を終えました',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportDaysSection => '曜日ごとの記録';

  @override
  String weeklyReportDayBarSemantics(String weekday, int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$weekday曜日 ルーティン$sent件中$completed件を終えました',
    );
    return '$_temp0';
  }

  @override
  String weeklyReportDayBarEmptySemantics(String weekday) {
    return '$weekday曜日 送ったルーティンなし';
  }

  @override
  String get weeklyReportTrendSection => '過去の週との比較';

  @override
  String weeklyReportTrendWeekLabel(int month, int day) {
    return '$month/$day';
  }

  @override
  String weeklyReportTrendPointSemantics(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$month月$day日の週 ルーティン$count件を終えました',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportInsightHighlightTitle => 'よくできたこと';

  @override
  String weeklyReportInsightHighlightFirst(String routine, String batchim) {
    return '今週はじめて$routineを最後までできました';
  }

  @override
  String weeklyReportInsightHighlightEvery(
    String routine,
    String batchim,
    int count,
  ) {
    return '$routineを$count回すべて最後までできました';
  }

  @override
  String weeklyReportInsightHighlightStreak(int days) {
    return '$days日続けて日課を終えました';
  }

  @override
  String weeklyReportInsightHighlightHint(String name) {
    return '今日、$nameに伝えてあげてください';
  }

  @override
  String get weeklyReportInsightStuckTitle => 'よく止まったところ';

  @override
  String weeklyReportInsightStuckLine(
    String routine,
    String step,
    int sent,
    int remained,
  ) {
    return '$routineの$stepで$sent回中$remained回止まりました';
  }

  @override
  String get weeklyReportInsightStuckShorten => 'カードの文をもっと短くするか、2つに分けてみましょう';

  @override
  String get weeklyReportInsightStuckAddMedia => '声や写真をつけてみましょう';

  @override
  String weeklyReportInsightStuckFix(String step) {
    return '$stepのカードを直す';
  }

  @override
  String get weeklyReportInsightStuckFixFailed => '直す日課を開けませんでした';

  @override
  String get weeklyReportInsightTrendTitle => '先週と変わったこと';

  @override
  String weeklyReportInsightTrendUp(int before, int after) {
    return '終えた日課が$before個から$after個に増えました';
  }

  @override
  String weeklyReportInsightTrendDown(int before, int after) {
    return '終えた日課が$before個から$after個になりました';
  }

  @override
  String weeklyReportInsightTrendSame(int after) {
    return '先週と同じく$after個終えました';
  }

  @override
  String weeklyReportInsightTrendBarPrevious(int count) {
    return '先週 $count';
  }

  @override
  String weeklyReportInsightTrendBarCurrent(int count) {
    return '今週 $count';
  }

  @override
  String get weeklyReportInsightDurationTitle => 'かかった時間';

  @override
  String weeklyReportInsightDurationLine(
    String routine,
    int before,
    int after,
  ) {
    return '$routineにかかった時間が$before分から$after分になりました';
  }

  @override
  String get weeklyReportInsightSlowestTitle => 'いちばん長くとどまったカード';

  @override
  String weeklyReportInsightSlowestLine(
    String routine,
    String step,
    int minutes,
  ) {
    return '$routineの$stepで平均$minutes分とどまりました';
  }

  @override
  String get weeklyReportStatCompleted => '終えた日課';

  @override
  String get weeklyReportStatRemaining => 'まだのカード';

  @override
  String weeklyReportRoutineRatio(int sent, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      sent,
      locale: localeName,
      other: '$sent回中$completed回',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportSave => 'レポートを保存';

  @override
  String get weeklyReportSaveSheetTitle => 'レポートをどう保存しますか？';

  @override
  String get weeklyReportPastReports => '過去のレポートを見る';

  @override
  String get weeklyReportPastSheetTitle => '過去のレポート';

  @override
  String weeklyReportPastWeekValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '日課を$count個終えました',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportPastEmpty => 'まだ過去のレポートはありません';

  @override
  String get weeklyReportPastLoadFailed => '過去のレポートを読み込めませんでした';

  @override
  String get weeklyReportFreePreviewNote => '最初のレポートはProなしで見られます';

  @override
  String get weeklyReportNextWeekUpsell => '来週のレポートも受け取る';

  @override
  String get routineScheduleRowOff => '曜日・時刻を決める';

  @override
  String get routineScheduleRowLabel => 'くり返す曜日と時刻';

  @override
  String routineScheduleSummary(String days, String time) {
    return '$days $time';
  }

  @override
  String get routineScheduleEveryDay => '毎日';

  @override
  String get routineScheduleWeekdaysOnly => '平日';

  @override
  String get routineScheduleWeekendOnly => '週末';

  @override
  String get routineScheduleDaySeparator => '·';

  @override
  String get routineSchedulePaused => 'Proが終わり、止まりました';

  @override
  String get routineSchedulePausedNote =>
      'Proが終わったため、くり返しを止めました。決めた曜日と時刻はそのまま残っています';

  @override
  String get routineScheduleSheetTitle => 'いつしますか？';

  @override
  String get routineScheduleSheetBody => '選んだ曜日ごとに、この日課が今日の日課になります';

  @override
  String get routineScheduleDaysLabel => '曜日';

  @override
  String get routineScheduleTimeLabel => '時刻';

  @override
  String get routineScheduleNotifyElumi => 'その時刻にElumiの端末へ知らせる';

  @override
  String get routineScheduleElumiNotificationOff => 'Elumiの端末の通知がオフになっています';

  @override
  String get routineScheduleElumiNotificationOffHint =>
      'Elumiの端末の設定で、elumの通知をオンにしてください';

  @override
  String get routineScheduleElumiNoDevice => 'Elumiの端末をつなぐと、その時刻に通知が届きます';

  @override
  String get routineScheduleSave => '保存';

  @override
  String get routineScheduleTurnOff => 'くり返しをオフにする';

  @override
  String get routineScheduleSavedToast => '曜日と時刻を保存しました';

  @override
  String get routineScheduleTurnedOffToast => 'くり返しをオフにしました';

  @override
  String get routineScheduleSaveFailedTitle => '保存できませんでした';

  @override
  String get routineScheduleSaveFailedFallback => '少し待ってから、もう一度お試しください';

  @override
  String get routineSchedulePickDayHint => '曜日を1つ以上選んでください';

  @override
  String get routineScheduleProNote => 'くり返しの日課はProで保存できます';

  @override
  String get weeklyPlanEntry => '週間計画';

  @override
  String get weeklyPlanTitle => '週間計画';

  @override
  String weeklyPlanDayTitle(String weekday) {
    return '$weekday曜日';
  }

  @override
  String get weeklyPlanToday => '今日';

  @override
  String get weeklyPlanEmptyDay => '決まった日課はありません';

  @override
  String get weeklyPlanEmptyTitle => 'まだ曜日を決めた日課はありません';

  @override
  String get weeklyPlanEmptyBody => '日課管理で日課をタップして、曜日・時刻を決めてみましょう';

  @override
  String get weeklyPlanLoadFailed => '週間計画を読み込めませんでした';

  @override
  String get weeklyPlanNotifyOff => '通知なし';

  @override
  String get weeklyPlanMetaSeparator => '  ·  ';

  @override
  String get guardianVoiceRecordAction => '自分の声で録音する';

  @override
  String get guardianVoiceRecordHint => 'カードをタップすると、この声が流れます';

  @override
  String guardianVoiceRecording(int seconds) {
    return '録音中 $seconds秒';
  }

  @override
  String guardianVoiceRecordingLimit(int seconds) {
    return '$seconds秒まで録音できます';
  }

  @override
  String get guardianVoiceStop => '止める';

  @override
  String get guardianVoiceSaving => '録音を保存しています';

  @override
  String get guardianVoiceSaved => '録音しました';

  @override
  String get guardianVoicePlay => '聞く';

  @override
  String get guardianVoiceRerecord => '録音し直す';

  @override
  String get guardianVoiceDelete => '消す';

  @override
  String get guardianVoiceDeleteConfirmTitle => '録音を消しますか？';

  @override
  String get guardianVoiceDeleteConfirmMessage => '消すと、標準の声で読み上げます';

  @override
  String get guardianVoicePlanEnded => '標準の声で読み上げます';

  @override
  String get guardianVoiceMicDeniedTitle => 'マイクがオフになっています';

  @override
  String get guardianVoiceMicDeniedBody => 'オンにするまでは、標準の声で読み上げます';

  @override
  String get guardianVoiceOpenSettings => '設定を開く';

  @override
  String get guardianVoiceFailedTitle => '録音を保存できませんでした';

  @override
  String get guardianVoiceRetry => 'もう一度';

  @override
  String get guardianVoiceTooShort => '短すぎます。話してから「止める」をタップしてください';

  @override
  String get guardianVoiceRecordFailed => '録音できませんでした。もう一度お試しください';

  @override
  String get guardianVoiceTooLarge => '録音ファイルが大きすぎます。少し短く録音し直してください';

  @override
  String get guardianVoicePlayFailed => '録音を再生できませんでした';

  @override
  String get guardianVoiceDeleteFailed => '録音を消せませんでした';

  @override
  String get guardianVoiceRecordChip => '録音';

  @override
  String get guardianVoicePlanEndedHint => 'Proが終わっても録音は残してあります';

  @override
  String get guardianSettingsRoutineMemory => 'AIメモリー';

  @override
  String memoryHeroTitle(String name) {
    return '$nameのAIメモリー';
  }

  @override
  String get memoryHeroBody => 'あなたの直し方を覚えて、次の日課をそのように作ります。見られるのはあなただけです';

  @override
  String get memoryStatApplied => '適用中';

  @override
  String get memoryStatWatching => '観察中';

  @override
  String get memoryStatEdits => '修正記録';

  @override
  String get memoryListAppliedHeader => '適用中のルール';

  @override
  String get memoryListAppliedHint => '新しい日課に使われます';

  @override
  String get memoryListWatchingHeader => '観察中のルール';

  @override
  String get memoryListWatchingHint => '点がすべて埋まると適用されます';

  @override
  String get memoryListEditsHeader => '直して送った記録';

  @override
  String memoryRuleByAi(int count) {
    return 'AIが発見、日課$count個';
  }

  @override
  String get memoryRuleByMe => '自分で書いたもの';

  @override
  String memoryEditCards(int before, int after) {
    return '$before枚 → $after枚';
  }

  @override
  String memoryEditTexts(int count) {
    return '文$countか所';
  }

  @override
  String get memoryAddRule => '+ ルールを自分で書く';

  @override
  String get memoryAutoFind => '直した内容から自動で見つける';

  @override
  String memoryAutoFindNote(int count) {
    return '同じ修正が日課$count個でくり返されると適用されます';
  }

  @override
  String get memoryEmptyTitle => '日課を直して送ると、ここにたまります';

  @override
  String get memoryEmptyEdits => 'まだ直して送った日課はありません';

  @override
  String get memoryTypeWord => '言葉を変える';

  @override
  String get memoryTypeSplit => 'カードを分ける';

  @override
  String get memoryTypeMerge => 'カードをまとめる';

  @override
  String get memoryTypeAdd => 'カードを足す';

  @override
  String get memoryTypeRemove => 'カードを外す';

  @override
  String get memoryTypeManual => '自分で書いたルール';

  @override
  String get memoryApplyNow => '今すぐ適用';

  @override
  String get memoryRuleDelete => '削除';

  @override
  String get memoryRuleEdit => '編集';

  @override
  String memoryEvidenceLine(String routine, int month, int day) {
    return '$routine、$month月$day日';
  }

  @override
  String get memoryMenuLabel => 'メニュー';

  @override
  String get memoryMenuExport => 'ファイルに書き出す';

  @override
  String get memoryMenuClear => 'メモリーをすべて消す';

  @override
  String get memoryExportFailed => 'メモリーを書き出せませんでした';

  @override
  String get memoryObsTitle => 'AIメモリー';

  @override
  String get memoryObsWord => '言葉をこのように変えました';

  @override
  String get memoryObsSplit => 'カードを分けました';

  @override
  String get memoryObsMerge => 'カードをまとめました';

  @override
  String get memoryObsAdd => 'カードを足しました';

  @override
  String get memoryObsRemove => 'カードを外しました';

  @override
  String get memoryObsManual => 'このように直しました';

  @override
  String memoryObsAsk(String phrase) {
    return '$phrase。次の日課でもこうしますか？';
  }

  @override
  String get memoryObsAlways => 'いつもこうする';

  @override
  String get memoryObsOnce => '今回だけ';

  @override
  String get memoryObsDone => '次の日課からこのように作ります';

  @override
  String memoryObsMore(int count) {
    return 'AIメモリーでさらに$count個見る';
  }

  @override
  String memoryAppliedPill(int count) {
    return 'AIメモリーのルールを$count個適用しました';
  }

  @override
  String get routineMemoryAddSheetTitle => 'メモを足す';

  @override
  String get routineMemoryEditSheetTitle => 'メモを直す';

  @override
  String get routineMemoryLineHint => '例：「洗う」ではなく「手をふく」と書きます';

  @override
  String get routineMemorySave => '保存';

  @override
  String get routineMemoryDeleteLine => 'この行を消す';

  @override
  String get routineMemoryClearConfirmTitle => 'メモをすべて消しますか？';

  @override
  String get routineMemoryClearConfirmMessage => '消したメモは元に戻せません。';

  @override
  String get routineMemoryClearConfirmAction => 'すべて消す';

  @override
  String get routineMemoryLoadFailed => 'メモを読み込めませんでした';

  @override
  String get routineMemorySaveFailedTitle => 'メモを保存できませんでした';

  @override
  String get routineMemorySaveFailedFallback => '少し待ってから、もう一度お試しください。';

  @override
  String get proTeaserSampleLabel => 'サンプル画面';

  @override
  String get proOnlyNoticeTitle => 'Proで使える機能です';

  @override
  String get proOnlyFreeAlternative => '今使っている機能はそのまま使えます';

  @override
  String get proOnlyFreeAlternativeAiImage => '今は基本の絵や写真でカードを作れます';

  @override
  String get proOnlyFreeAlternativeSchedule => '今は日課を自分で送れば大丈夫です';

  @override
  String get proOnlyFreeAlternativeVoice => '今は標準の声でカードを読み上げます';

  @override
  String get proOnlyFreeAlternativeCardSplit => '今はカードを自分で足して分けられます';

  @override
  String get proOnlyFreeAlternativeCardExport => '今は基本のデザインで印刷できます';

  @override
  String get proTeaserWeeklyReportBenefit => '1週間でできた日課を1枚にまとめて送れます';

  @override
  String get proTeaserRoutineMemoryBenefit => 'あなたの直し方を覚えて、次の日課をもっとぴったりに作ります';

  @override
  String get proTeaserCardThemeBenefit => '印刷用カードをいろいろなデザインで受け取れます';

  @override
  String get proTeaserWeeklyPlanBenefit => '毎朝、日課を送り直さなくて大丈夫です';

  @override
  String get proTeaserSampleRoutineMorning => '朝のしたく';

  @override
  String get proTeaserSampleRoutineBrush => '歯みがき';

  @override
  String get proTeaserSampleRoutineBag => 'かばんの準備';

  @override
  String get proTeaserSampleStepSocks => 'くつしたをはく';

  @override
  String get proTeaserSampleMemoryShort => 'カードの文は短く1行で書きます';

  @override
  String get proTeaserSampleMemoryOrder => '着替えはくつしたから始めます';

  @override
  String get proTeaserSampleMemoryReward => 'ごほうびはシールにします';

  @override
  String get cardRegenerateChip => '描き直す';

  @override
  String get cardRegenerateSheetTitle => '絵を描き直しますか？';

  @override
  String cardRegenerateCostProFree(int count) {
    return 'クレジットなし、今日はあと$count回です';
  }

  @override
  String get cardRegenerateCostFree => 'クレジットを使いません';

  @override
  String cardRegenerateCostCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'クレジット$count個',
    );
    return '$_temp0';
  }

  @override
  String cardRegenerateCostProUsedUp(int credits, int freeCount) {
    String _temp0 = intl.Intl.pluralLogic(
      credits,
      locale: localeName,
      other: '今日の無料$freeCount回を使い切りました。クレジットを$credits個使います',
    );
    return '$_temp0';
  }

  @override
  String cardRegenerateProFact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Proは1日$count回まで無料で描き直せます',
    );
    return '$_temp0';
  }

  @override
  String cardAddImageCost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'AIの絵を描くとクレジットを$count個使います',
    );
    return '$_temp0';
  }

  @override
  String questionCreditCostLine(String costs, int available) {
    String _temp0 = intl.Intl.pluralLogic(
      available,
      locale: localeName,
      other: '$costs、今$available個あります',
    );
    return '$_temp0';
  }

  @override
  String creditCostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個',
    );
    return '$_temp0';
  }

  @override
  String get cardRegenerateCostUnknown => 'クレジットを使います';

  @override
  String get cardRegenerateConfirm => '描き直す';

  @override
  String get cardRegenerateInProgress => '絵を描き直しています';

  @override
  String get cardRegenerateFailedTitle => '絵を描き直せませんでした';

  @override
  String get cardFirstDrawChip => 'AIの絵を描く';

  @override
  String get cardRedrawProChip => 'Proで描き直す';

  @override
  String get cardFirstDrawProChip => 'ProでAIの絵を描く';

  @override
  String get cardFirstDrawSheetTitle => 'AIの絵を描きますか？';

  @override
  String get cardRedrawSheetBody => '直したいところを書くか選んでください。空のままなら、そのまま描き直します';

  @override
  String get cardFirstDrawSheetBody => '希望を書くか選んでください。新しい絵を見てから選べます';

  @override
  String get cardRedrawRequestLabel => '直したいところ';

  @override
  String get cardRedrawRequestHint => '例：かさを青に';

  @override
  String get cardRedrawHintSimpler => 'もっとシンプルに';

  @override
  String get cardRedrawHintNoBackground => '背景なし';

  @override
  String get cardRedrawHintNoPeople => '人なし';

  @override
  String get cardRedrawHintBrighter => 'もっと明るく';

  @override
  String get cardFirstDrawConfirm => '描く';

  @override
  String get cardFirstDrawInProgress => '絵を描いています';

  @override
  String get cardFirstDrawFailedTitle => 'AIの絵を描けませんでした';

  @override
  String get cardRedrawFailedFallback => 'もう一度やってみましょうか？クレジットは使っていません';

  @override
  String get cardCandidateFailedFallback =>
      '新しい絵はすでに描いたので、使ったクレジットは戻りません。少し待ってから、もう一度お試しください';

  @override
  String get cardCandidateSheetTitle => 'どの絵にしますか？';

  @override
  String get cardCandidateSheetBody =>
      '選んだ絵だけがElumiに見えます\nどの絵を選んでも、使ったクレジットは戻りません';

  @override
  String get cardCandidateCurrentLabel => '今の絵';

  @override
  String get cardCandidateNewLabel => '新しい絵';

  @override
  String get cardCandidateSelectButton => 'この絵にする';

  @override
  String get cardCandidateAppliedToast => '新しい絵に変えました';

  @override
  String get cardCandidateLoadFailedTitle => '新しい絵を読み込めませんでした';

  @override
  String get cardCandidateApplyFailedTitle => '新しい絵に変えられませんでした';

  @override
  String get planHeroHeadline => 'Elumiだけのカードに変わります';

  @override
  String get planHeroSubline => '同じ日課もProで作るとこんなに変わります';

  @override
  String get planHeroFreeTag => 'Free 絵文字';

  @override
  String get planHeroProTag => 'Pro マンガの絵';

  @override
  String get planHeroCompareSemantics => 'Freeは絵文字のカード、Proはマンガの絵のカードです';

  @override
  String planBenefitGroupCards(String elumiName) {
    return '$elumiNameだけのカードの絵';
  }

  @override
  String get planBenefitGroupRoutines => '日課が自動で届きます';

  @override
  String get planBenefitGroupWeek => '1週間をまとめてお届けします';

  @override
  String get planBenefitGroupExtra => 'もっとたっぷり';

  @override
  String planYearlySaving(int percent) {
    return '$percent%おトク';
  }

  @override
  String get planRenewsYearly => '1年ごとに自動更新';

  @override
  String get planRenewsMonthly => '1か月ごとに自動更新';

  @override
  String planMonthlyEquivalentRenewsYearly(String price) {
    return '1か月あたり約$price · 1年ごとに自動更新';
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
    return '$trialの後、$price$unitが自動で支払われます。終了の24時間前までに解約すれば請求されません';
  }

  @override
  String planCtaTrialNoticePlayStore(String trial, String price, String unit) {
    return '$trialの後、$price$unitが自動で支払われます。体験中に解約すれば請求されません';
  }

  @override
  String planCtaRenewNotice(String price, String unit) {
    return '$price$unitで自動更新されます。いつでも解約できます';
  }

  @override
  String planTryFreeTrial(String trial) {
    return '$trial無料で試す';
  }

  @override
  String get planSeeAllBenefits => 'Proの特典をすべて見る';

  @override
  String get planTierGift => 'ギフト';

  @override
  String get myPlanProTitle => 'Proを使っています';

  @override
  String get myPlanGiftTitle => 'Proのギフトを受け取りました';

  @override
  String get myPlanFreeTitle => 'Freeを使っています';

  @override
  String get myPlanFreeBodyWeek => '毎週もらえるクレジットで日課を作ります';

  @override
  String get myPlanFreeBodyMonth => '毎月もらえるクレジットで日課を作ります';

  @override
  String get proTeaserWeeklyPlanTitle => '曜日と時刻を決めておけば、その日の日課が用意されます';

  @override
  String get proTeaserWeeklyReportTitle => '1週間を1枚で受け取れます';

  @override
  String get proTeaserRoutineMemoryTitle => 'Elumiに合ったやり方を覚えます';

  @override
  String get proTeaserCardThemeTitle => '印刷用カードをもっとかわいく受け取れます';

  @override
  String get proTeaserCardLayoutTitle => '印刷用カードを好きな形で受け取れます';

  @override
  String get proTeaserCardLayoutBenefit =>
      '1枚に複数のカード、横向きの用紙、日課を1枚にまとめた形で受け取れます';

  @override
  String get homeSuggestionDismissLabel => '大丈夫です';

  @override
  String get homeSuggestionAutoSendTitle => '毎日自動で送りますか？';

  @override
  String homeSuggestionAutoSendBody(String routine, String batchim, int days) {
    return '$routineを$days日続けて送っています';
  }

  @override
  String get homeSuggestionAutoSendAction => '設定する';

  @override
  String get homeSuggestionTalkShareTitle => 'ストーリーに載せてみますか？';

  @override
  String homeSuggestionTalkShareBody(String routine, String batchim) {
    return 'ほかの保護者も$routineを使えます';
  }

  @override
  String get homeSuggestionTalkShareAction => '載せる';

  @override
  String get homeSuggestionCreateMoreTitle => '日課をもう一つ作りますか？';

  @override
  String get homeSuggestionCreateMoreBody => '夜や寝る前の日課はどうですか？';

  @override
  String get homeSuggestionCreateMoreAction => '作る';

  @override
  String get cardSplitChip => 'このカードをもっとやさしく';

  @override
  String get cardSplitLoading => 'やさしいステップに分けています';

  @override
  String get cardSplitSheetTitle => 'こう分けてみますか？';

  @override
  String cardSplitSheetDescription(String title, int count) {
    return '「$title」を小さなステップ$countつに分けてみました';
  }

  @override
  String get cardSplitAlreadyShortDescription => '行動が一つなので、これ以上分けませんでした';

  @override
  String get cardSplitDefaultPictureNote => '絵は基本の絵が入ります。あとで変えられます';

  @override
  String get cardSplitKeepButton => 'そのままにする';

  @override
  String get cardSplitApplyButton => 'この分け方にする';

  @override
  String get cardSplitAlreadyShort => 'もう十分短いです';

  @override
  String get cardSplitFailedFallback => 'カードを分けられませんでした。しばらくしてからもう一度お試しください';

  @override
  String get cardSplitRetry => 'もう一度';

  @override
  String cardSplitDoneToast(int count) {
    return 'カードを$count枚に分けました';
  }

  @override
  String get planBenefitCardSplit => 'カード1枚をより小さく分けます';

  @override
  String get creditTopUpTitleExhausted => '🎟️ 今週のクレジットを使い切りました';

  @override
  String get creditTopUpTitleExhaustedMonth => '🎟️ 今月のクレジットを使い切りました';

  @override
  String get creditTopUpTitleShort => '🎟️ クレジットが少し足りません';

  @override
  String creditTopUpRefillAt(String reset) {
    return '$resetにまた補充されます';
  }

  @override
  String get creditTopUpAdTitleNoCount => '広告を見てクレジットをもらう';

  @override
  String get creditTopUpAdWatch => '広告を見る';

  @override
  String get creditTopUpAdOff => '今は広告でもらえません';

  @override
  String get creditTopUpAdDailyLimit => '今日の分はすべてもらいました。明日また見られます';

  @override
  String creditTopUpAdDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '15〜30秒、最後まで見るとクレジット$count個',
    );
    return '$_temp0';
  }

  @override
  String creditTopUpAdRemaining(int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '今日はあと$remaining回もらえます',
    );
    return '$_temp0';
  }

  @override
  String get creditTopUpAdNoFill => '今見られる広告がありません';

  @override
  String get proFeatureMarkLabel => 'くわしく見る';

  @override
  String get proExplainAiImageStylesReason => 'カードの内容に合った絵なので、Elumiがわかりやすくなります';

  @override
  String get proExplainCardSplitReason => '難しい行動を小さなステップに分けて、一歩ずつまねできます';

  @override
  String get proExplainFreeImageRegenerateReason => '気に入るまでクレジットを気にせず絵を直せます';

  @override
  String get creditTopUpAdCheckFailed => '広告の情報を読み込めませんでした。少し待ってから、もう一度開いてください';

  @override
  String get creditTopUpPackLink => 'クレジットパックを見る';

  @override
  String get creditTopUpRoutineContinue => '続けて作る';

  @override
  String get creditTopUpRedrawContinue => '続けて描く';

  @override
  String creditRewardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🎟️ クレジットを$count個もらいました',
    );
    return '$_temp0';
  }

  @override
  String get creditRewardTitleNoCount => '🎟️ クレジットをもらいました';

  @override
  String get creditRewardReason => '広告を最後まで見たのでもらえました';

  @override
  String get lowCreditNoticeTitle => 'クレジットが残り少なくなりました';

  @override
  String get lowCreditNoticeTitleEmpty => 'クレジットを使い切りました';

  @override
  String get lowCreditNoticeBody => '広告を見ると、すぐにもっともらえます';

  @override
  String get lowCreditNoticeAction => '広告を見てもらう';

  @override
  String get creditGuideTitle => '🎟️ クレジットの使い方';

  @override
  String get creditGuideBasis => 'あなたのプランの基準です';

  @override
  String get creditGuideRoutineText => '日課の文を作る';

  @override
  String get creditGuideCardImage => 'カードの絵 1枚';

  @override
  String get creditGuideRegenerate => '絵を描き直す';

  @override
  String get creditGuideWeeklyGrant => '毎週もらえるクレジット';

  @override
  String get creditGuideMonthlyGrant => '毎月もらえるクレジット';

  @override
  String creditGuideCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideUnlimited => '制限なし';

  @override
  String creditGuideRegenerateFreeToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今日はあと$count回無料',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideKeepGoing => '始めた日課は、クレジットが足りなくても最後まで作られます';

  @override
  String get creditGuideRefillWeek => '毎週月曜日0時にまた補充されます';

  @override
  String get creditGuideRefillMonth => '毎月1日0時にまた補充されます';

  @override
  String creditGuideProFactBoth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Proは日課の文が制限なしで、描き直しは1日$count回無料です',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideProFactText => 'Proは日課の文が制限なしです';

  @override
  String creditGuideProFactRegenerate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Proは描き直しが1日$count回無料です',
    );
    return '$_temp0';
  }

  @override
  String creditGuideRegenerateFreeDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '1日$count回無料',
    );
    return '$_temp0';
  }

  @override
  String get creditGuideConfirm => 'わかりました';

  @override
  String myCreditFreeRegenerateToday(int left, int cap) {
    return '描き直し 今日$left/$cap回無料';
  }

  @override
  String get myCreditRecentTitle => '最近使った履歴';

  @override
  String get myCreditSeeAllHistory => 'すべて見る';

  @override
  String get myCreditGuideLink => 'クレジットの使い方';

  @override
  String get abaIntroTitle => '準備はかんたんに、\n毎日は自分の力で';

  @override
  String get abaIntroSubtitle => '応用行動分析（ABA）の考え方で作りました';

  @override
  String get abaIntroStepsTitle => '小さく分けます';

  @override
  String get abaIntroStepsBody => '日課を段階カードに';

  @override
  String get abaIntroShowTitle => '前もって見せます';

  @override
  String get abaIntroShowBody => '絵と音声で';

  @override
  String get abaIntroHelpTitle => '手助けを減らす';

  @override
  String get abaIntroHelpBody => '自分で進めるように';

  @override
  String get abaIntroRewardTitle => 'すぐにほめます';

  @override
  String get abaIntroRewardBody => '星と決めたごほうび';

  @override
  String get abaIntroGuardianTitle => 'いちばん大切なのは保護者です';

  @override
  String get abaIntroGuardianBody => '日課とごほうびは保護者が決め、elumが手伝います';

  @override
  String get abaIntroStart => 'はじめる';

  @override
  String get guardianSettingsAboutElum => 'elumはこうして作りました';

  @override
  String get notificationIntroTitle => '🔔 通知をぜひオンにしてください';

  @override
  String get notificationIntroBody => 'オンにしておくと、Elumiの知らせを逃さずすぐにお知らせします';

  @override
  String get notificationIntroRoutineDone => 'Elumiが日課を終えたとき';

  @override
  String get notificationIntroCaregiverRoutine => '一緒に見守る人が日課を送ったとき';

  @override
  String get notificationIntroWeeklyReport => '週間レポートができたとき';

  @override
  String get notificationIntroCreditRefilledWeek => '今週のクレジットが補充されたとき';

  @override
  String get notificationIntroCreditRefilledMonth => '今月のクレジットが補充されたとき';

  @override
  String get notificationOffNoticeHighlightRoutineDone => '日課を終えたとき';

  @override
  String get notificationOffNoticeHighlightCaregiver => '一緒に見守る人からの知らせ';

  @override
  String get notificationOffNoticeAction => '通知をオンにする';

  @override
  String get homeAutoSendUpsellTitle => '⏰ 毎日同じ時刻に自動で送ってみませんか？';

  @override
  String get homeAutoSendUpsellBody => '曜日と時刻を決めておくと、その時にElumiの端末へ送ります';

  @override
  String get homeAutoSendUpsellAction => 'くわしく見る';

  @override
  String get notificationSettingRoutineNudge => '今日の日課をまだ送っていないとき';

  @override
  String get notificationSettingSuggestion => '新しい日課のおすすめ';

  @override
  String get notificationSettingPlanReminder => 'Proのギフトが終わる前';

  @override
  String get myCreditRemainingSuffix => '個残っています';

  @override
  String get commonGoHome => 'ホームへ';

  @override
  String get onboardingLinkStepTitle => 'Elumiの端末をつなぎますか？';

  @override
  String get linkDeviceBenefitLine => '送った日課がElumiの端末にすぐ表示されます';

  @override
  String get onboardingLinkStepConnectNow => '今つなぐ';

  @override
  String get onboardingLinkStepEnterCode => 'Elumiの端末で接続コードを入れるだけです';

  @override
  String get onboardingLinkStepManyDevices => '複数の端末をつなげます';

  @override
  String get onboardingLinkStepLaterInSettings => 'あとで設定からもつなげます';

  @override
  String get homeNextStepMakeTitle => '最初の日課を作ってみましょう';

  @override
  String get homeNextStepMakeBody => 'やることを書くと行動カードにします';

  @override
  String get homeNextStepMakeAction => '日課を作る';

  @override
  String get homeNextStepSendTitle => '作りかけの日課があります';

  @override
  String get homeNextStepSendBody => 'カードを確認して保存するとElumiの端末に届きます';

  @override
  String get homeNextStepSendAction => '続けて作る';

  @override
  String get homeNextStepLinkTitle => 'Elumiの端末をつなぎましょう';

  @override
  String get homeNextStepWaitTitle => '次はElumiの番です';

  @override
  String get elumiFinishNotifyLine => 'Elumiが終えたらお知らせします';

  @override
  String get routineSentTitle => 'Elumiの端末に送りました';

  @override
  String get routineSentReasonNotLinked => '端末をつなぐとElumiの端末にすぐ表示されます';

  @override
  String get routineSentLinkDevice => '端末をつなぐ';

  @override
  String get routineSentPreviewElumi => 'Elumi画面を見てみる';

  @override
  String guardianRoutineDoneTitle(String name, String batchim) {
    return '$nameが日課を終えました';
  }

  @override
  String get routineDonePraiseHint => '終えたことをすぐにほめてあげましょう';

  @override
  String routineDoneStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '星$count個',
    );
    return '$_temp0';
  }

  @override
  String routineDoneMoreRoutines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ほか$count件',
    );
    return '$_temp0';
  }

  @override
  String get routineDoneNotFound => '日課が見つかりません';

  @override
  String get routineDoneNotFoundHint => '削除されたか、別のElumiの日課です';

  @override
  String get routineDoneLoadFailed => '終えた日課を読み込めませんでした';

  @override
  String get todayRoutineEmptyNotSent => 'まだ送った日課はありません';

  @override
  String get todayRoutineEmptyTodayTitle => '今日送った日課はありません';

  @override
  String get todayRoutineEmptyTodayBody => '作っておいた日課を日課管理からすぐ送れます';

  @override
  String get notificationEmptyBody => 'Elumiが日課を終えるとここでお知らせします';

  @override
  String get notificationEmptyOpenSettings => '通知設定';

  @override
  String streakChipDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日連続',
    );
    return '$_temp0';
  }

  @override
  String streakAtRiskLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今日も続ければ$count日です',
    );
    return '$_temp0';
  }

  @override
  String streakMilestoneTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日連続でできました',
    );
    return '$_temp0';
  }

  @override
  String streakMilestoneReason(String name, String batchim) {
    return '$nameは毎日こつこつ日課を終えています';
  }

  @override
  String childStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日続けてできました',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportNotificationTitle => '1週間の記録が届きました';

  @override
  String weeklyReportNotificationCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'この週は日課を$count個終えました',
    );
    return '$_temp0';
  }

  @override
  String get weeklyReportNotificationNoCount => '今週もElumiと一緒にやってみましょう';

  @override
  String get weeklyReportNotificationProDetail => 'Proで詳しく見る';
}
