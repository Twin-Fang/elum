import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';
import 'guardian_lock_store.dart';
import 'local_storage.dart';

/// SharedPreferences 기반 실제 구현.
class SharedPrefsStorage implements LocalStorage {
  SharedPrefsStorage(this._prefs, {GuardianLockStore? lock}) : _lock = lock;

  GuardianLockStore? _lock;
  GuardianLockStore get _guardianLock => _lock ?? (throw StateError('E-PIN: installation not configured'));

  /// 설치 판정 뒤에만 평문 레거시 값을 이전한다. 재설치 잔존 암호는 폐기한다.
  Future<void> configureLock(String installationId, {required bool reset}) async {
    _lock = GuardianLockStore(installationId: installationId);
    if (reset) {
      await _guardianLock.clear();
    } else {
      final legacy = _prefs.getString(_kPin);
      if (legacy != null && legacy.isNotEmpty && !await _guardianLock.hasPin()) {
        await _guardianLock.setPin(legacy);
      }
    }
    if (!await _prefs.remove(_kPin)) throw StateError('E-PIN: legacy cleanup failed');
  }

  final SharedPreferences _prefs;

  static const _kAccountMemberId = 'accountMemberId';
  static const _kNickname = 'childNickname';
  static const _kLastProvider = 'lastLoginProvider';
  static const _kGoals = 'supportGoals';
  // 온보딩 예시 분류 대기값·실패 횟수 (#803)
  static const _kPendingExampleCategories = 'pendingExampleCategories';
  static const _kExampleSeedAttempts = 'exampleSeedAttempts';
  static const _kPendingExampleProfileId = 'pendingExampleProfileId';
  static const _kCharacter = 'cardCharacter';
  static const _kImageStyle = 'imageStyle';
  static const _kCompleted = 'onboardingCompleted';
  static const _kSelectedProfile = 'selectedProfileId';
  static const _kPin = 'guardianPin';
  static const _kElumiDevice = 'isElumiDevice';
  static const _kElumiLinkLost = 'isElumiLinkLost';
  static const _kSelectedRole = 'selectedRole';
  static const _kResumeElumiScreen = 'resumeOnElumiScreen';
  static const _kAccessToken = 'accessToken';
  static const _kProgressPrefix = 'progress.';
  static const _kPendingSync = 'progress.pending';
  static const _kCachedToday = 'cache.todayRoutines';
  // 오늘 일과 캐시를 받은 회원 id (다른 회원이면 캐시를 읽지 않음)
  static const _kCachedTodayOwner = 'cache.todayRoutinesOwner';
  static const _kCachedConsent = 'cache.consentDocuments';
  static const _kCachedTuning = 'cache.clientTuning';
  // 서버 Pro 판매 여부 마지막 값 (#1132)
  static const _kCachedStoreSellingOpen = 'cache.storeSellingOpen';
  static const _kNoticeHiddenPrefix = 'notice.hidden.';
  static const _kHasAskedPushPermission = 'push.hasAskedPermission';
  // 알림 켜기 안내 마지막 표시 시각 (ISO-8601)
  static const _kPushPermissionNudgedAt = 'push.permissionNudgedAt';
  // 알림 켜기 안내 화면(온보딩 끝·업데이트 뒤 한 번)을 이 기기에서 봤는가
  static const _kPushPermissionIntroSeen = 'push.permissionIntroSeen';
  // 보호자 홈 알림 꺼짐 띠를 닫은 시각 (ISO-8601, 7일 숨김)
  static const _kHomeNotificationNoticeDismissedAt = 'push.homeNoticeDismissedAt';
  // 업데이트 권유 마지막 표시: 최신 버전|yyyy-MM-dd
  static const _kUpdateSuggestionShown = 'updateSuggestionShown';
  static const _kHomeCoachSeen = 'coach.homeSeen';
  static const _kManageCoachSeen = 'coach.manageSeen';
  static const _kGroupCoachSeen = 'coach.groupSeen';
  static const _kCardReviewCoachSeen = 'coach.cardReviewSeen';
  static const _kChildHapticOn = 'haptic.childOn';
  static const _kChildPraiseSoundOn = 'sound.childPraiseOn';
  static const _kChildScreenAwakeOn = 'screen.childAwakeOn';
  // 일과 알림: {routineId: {hour, minute, isDaily, title}} JSON
  static const _kRoutineReminders = 'reminder.routines';
  // 이야기에서 가져온 일과 중 상세를 연 일과 id 목록
  static const _kTalkImportedSeenRoutineIds = 'talkImportedSeenRoutineIds';
  static const _kTalkShareHintDismissedRoutineIds =
      'talkShareHintDismissedRoutineIds';
  // 보호자 홈 권유: 종류별 마지막 표시 시각 {종류 이름: ISO-8601} JSON
  static const _kHomeSuggestionShownAtByKind = 'homeSuggestion.shownAtByKind';
  // 보호자 홈 권유: 닫은 권유 `{종류 이름}:{일과 id}` 목록
  static const _kHomeSuggestionDismissedKeys = 'homeSuggestion.dismissedKeys';
  // 보호자 홈 크레딧 부족 카드를 닫은 주기: 그 주기의 다음 초기화 시각 (ISO-8601)
  static const _kLowCreditNoticeDismissedPeriod = 'credit.lowNoticeDismissedPeriod';
  // 보호자 홈 자동 보내기 권유 카드: 처음 보인 날 (yyyy-MM-dd) · 닫음 여부
  static const _kHomeAutoSendUpsellFirstShownDay = 'homeNotice.autoSendUpsellFirstShownDay';
  static const _kHomeAutoSendUpsellClosed = 'homeNotice.autoSendUpsellClosed';
  // 보호자 홈 권유 카드 하루 1개: {yyyy-MM-dd}|{종류 이름}
  static const _kHomeUpsellShownRecord = 'homeNotice.upsellShownRecord';
  // 이야기 상세 보기: true 한 눈에 보기, false 크게 보기
  static const _kTalkGridView = 'talk.isGridView';

  // 키 범위 분류: 새 키는 아래 셋 중 하나에 반드시 넣음 (tool/check_storage_scopes.dart 가 검사)
  // 계정 범위: 로그아웃·다른 계정 로그인([clearAll]) 때 지움
  static const accountScopedKeys = [
    _kAccountMemberId,
    _kNickname,
    _kGoals,
    _kPendingExampleCategories,
    _kExampleSeedAttempts,
    _kPendingExampleProfileId,
    _kCharacter,
    _kImageStyle,
    _kCompleted,
    _kSelectedProfile,
    _kPin,
    _kElumiDevice,
    _kElumiLinkLost,
    _kSelectedRole,
    _kResumeElumiScreen,
    _kAccessToken,
    _kPendingSync,
    _kCachedToday,
    _kCachedTodayOwner,
    _kTalkImportedSeenRoutineIds,
    _kTalkShareHintDismissedRoutineIds,
    _kHomeSuggestionShownAtByKind,
    _kHomeSuggestionDismissedKeys,
    _kLowCreditNoticeDismissedPeriod,
    _kHomeAutoSendUpsellFirstShownDay,
    _kHomeAutoSendUpsellClosed,
    _kHomeUpsellShownRecord,
  ];
  static const accountScopedKeyPrefixes = [_kProgressPrefix];
  // 계정 범위지만 기기 알림 예약과 묶여 [clearAll]·[clearAccountForElumiLink] 가 남김: 다른 계정 로그인·로그아웃·탈퇴·이룸이 기기 연결 때 알림 기능이 예약 취소와 함께 비움 (`routineReminderResetProvider`)
  static const accountScopedKeysClearedByFeature = [_kRoutineReminders];
  // 기기 범위: 계정이 바뀌어도 남김 (기기 설정·서버 설정 캐시·이 기기에서 본 안내)
  static const deviceScopedKeys = [
    _kLastProvider,
    _kCachedConsent,
    _kCachedTuning,
    _kCachedStoreSellingOpen,
    _kHasAskedPushPermission,
    _kPushPermissionNudgedAt,
    _kPushPermissionIntroSeen,
    _kHomeNotificationNoticeDismissedAt,
    _kUpdateSuggestionShown,
    _kHomeCoachSeen,
    _kManageCoachSeen,
    _kGroupCoachSeen,
    _kCardReviewCoachSeen,
    _kChildHapticOn,
    _kChildPraiseSoundOn,
    _kChildScreenAwakeOn,
    _kTalkGridView,
  ];
  static const deviceScopedKeyPrefixes = [_kNoticeHiddenPrefix];
  // 계정 범위 중 이룸이 기기 연결([clearAccountForElumiLink]) 때 남김: 연결이 방금 쓴 표식·역할, 보호자 잠금
  static const keptOnElumiLinkKeys = [
    _kElumiDevice,
    _kElumiLinkLost,
    _kSelectedRole,
    _kPin,
  ];

  static Future<SharedPrefsStorage> create({GuardianLockStore? lock}) async {
    return SharedPrefsStorage(await SharedPreferences.getInstance(), lock: lock);
  }

  @override
  String? get accountMemberId => _prefs.getString(_kAccountMemberId);

  @override
  Future<void> setAccountMemberId(String id) => _prefs.setString(_kAccountMemberId, id);

  @override
  String? get nickname {
    final value = _prefs.getString(_kNickname);
    AppLogger.storageRead(_kNickname, value);
    return value;
  }

  @override
  Future<void> setNickname(String v) {
    AppLogger.storageWrite(_kNickname, v);
    return _prefs.setString(_kNickname, v);
  }

  @override
  String? get lastLoginProvider {
    final value = _prefs.getString(_kLastProvider);
    AppLogger.storageRead(_kLastProvider, value);
    return value;
  }

  @override
  Future<void> setLastLoginProvider(String v) {
    AppLogger.storageWrite(_kLastProvider, v);
    return _prefs.setString(_kLastProvider, v);
  }

  @override
  List<String> get goals {
    final value = _prefs.getStringList(_kGoals) ?? const [];
    AppLogger.storageRead(_kGoals, value);
    return value;
  }

  @override
  Future<void> setGoals(List<String> v) {
    AppLogger.storageWrite(_kGoals, v);
    return _prefs.setStringList(_kGoals, v);
  }

  @override
  List<String> get pendingExampleCategories {
    final categories =
        _prefs.getStringList(_kPendingExampleCategories) ?? const [];
    AppLogger.storageRead(_kPendingExampleCategories, categories);
    return categories;
  }

  @override
  Future<void> setPendingExampleCategories(List<String> v) {
    AppLogger.storageWrite(_kPendingExampleCategories, v);
    return _prefs.setStringList(_kPendingExampleCategories, v);
  }

  @override
  String? get pendingExampleProfileId =>
      _prefs.getString(_kPendingExampleProfileId);

  @override
  Future<void> setPendingExampleProfileId(String? v) async {
    AppLogger.storageWrite(_kPendingExampleProfileId, v ?? '');
    if (v == null) {
      await _prefs.remove(_kPendingExampleProfileId);
    } else {
      await _prefs.setString(_kPendingExampleProfileId, v);
    }
  }

  @override
  int get exampleSeedAttempts => _prefs.getInt(_kExampleSeedAttempts) ?? 0;

  @override
  Future<void> setExampleSeedAttempts(int v) {
    AppLogger.storageWrite(_kExampleSeedAttempts, '$v');
    return _prefs.setInt(_kExampleSeedAttempts, v);
  }

  @override
  String? get character {
    final value = _prefs.getString(_kCharacter);
    AppLogger.storageRead(_kCharacter, value);
    return value;
  }

  @override
  Future<void> setCharacter(String v) {
    AppLogger.storageWrite(_kCharacter, v);
    return _prefs.setString(_kCharacter, v);
  }

  @override
  String? get imageStyle {
    final value = _prefs.getString(_kImageStyle);
    AppLogger.storageRead(_kImageStyle, value);
    return value;
  }

  @override
  Future<void> setImageStyle(String v) {
    AppLogger.storageWrite(_kImageStyle, v);
    return _prefs.setString(_kImageStyle, v);
  }

  @override
  bool get isOnboardingCompleted {
    final value = _prefs.getBool(_kCompleted) ?? false;
    AppLogger.storageRead(_kCompleted, value);
    return value;
  }

  @override
  Future<void> setOnboardingCompleted(bool v) {
    AppLogger.storageWrite(_kCompleted, v);
    return _prefs.setBool(_kCompleted, v);
  }

  @override
  Future<void> setPin(String v) => _guardianLock.setPin(v);

  @override
  Future<bool> hasPin() => _guardianLock.hasPin();

  @override
  Future<bool> verifyPin(String pin) => _guardianLock.verifyPin(pin);

  @override
  String? get selectedProfileId {
    final value = _prefs.getString(_kSelectedProfile);
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<void> setSelectedProfileId(String v) {
    AppLogger.storageWrite(_kSelectedProfile, v);
    return _prefs.setString(_kSelectedProfile, v);
  }

  @override
  Future<void> clearSelectedProfileId() {
    AppLogger.storageDelete(_kSelectedProfile);
    return _prefs.remove(_kSelectedProfile);
  }

  @override
  String? get accessToken {
    final value = _prefs.getString(_kAccessToken);
    AppLogger.storageRead(_kAccessToken, value != null ? '***' : null);
    return value;
  }

  @override
  Future<void> setAccessToken(String v) {
    AppLogger.storageWrite(_kAccessToken, '***');
    return _prefs.setString(_kAccessToken, v);
  }

  @override
  Future<void> clearAccessToken() {
    AppLogger.storageDelete(_kAccessToken);
    return _prefs.remove(_kAccessToken);
  }

  @override
  String? getRoutineProgressJson(String routineId) =>
      _prefs.getString('$_kProgressPrefix$routineId');

  @override
  Future<void> setRoutineProgressJson(String routineId, String json) {
    // 카드 id 집합뿐이라 로그에 남겨도 원문은 없다
    AppLogger.storageWrite('$_kProgressPrefix$routineId', json);
    return _prefs.setString('$_kProgressPrefix$routineId', json);
  }

  @override
  Future<void> removeRoutineProgress(String routineId) {
    AppLogger.storageDelete('$_kProgressPrefix$routineId');
    return _prefs.remove('$_kProgressPrefix$routineId');
  }

  @override
  List<String> get pendingSyncRoutineIds =>
      _prefs.getStringList(_kPendingSync) ?? const [];

  @override
  Future<void> setPendingSyncRoutineIds(List<String> ids) {
    AppLogger.storageWrite(_kPendingSync, ids);
    return _prefs.setStringList(_kPendingSync, ids);
  }

  @override
  String? get cachedTodayRoutinesJson {
    // 받은 회원 <-> 지금 회원 (다르면 캐시 없음으로 읽음)
    if (_prefs.getString(_kCachedTodayOwner) != accountMemberId) return null;
    return _prefs.getString(_kCachedToday);
  }

  @override
  Future<void> setCachedTodayRoutinesJson(
    String json, {
    required String? ownerMemberId,
  }) async {
    // 받은 회원과 지금 회원이 다르면 쓰지 않음 (계정 전환 중 늦게 온 응답)
    if (ownerMemberId != accountMemberId) {
      AppLogger.storageWrite(_kCachedToday, 'skipped: owner changed');
      return;
    }
    // 호출부가 원문 계열 키를 뺀 JSON 만 넘긴다. 그래도 값은 로그에 찍지 않는다.
    AppLogger.storageWrite(_kCachedToday, '${json.length}B');
    if (ownerMemberId == null) {
      await _prefs.remove(_kCachedTodayOwner);
    } else {
      await _prefs.setString(_kCachedTodayOwner, ownerMemberId);
    }
    await _prefs.setString(_kCachedToday, json);
  }

  @override
  Future<void> clearCachedTodayRoutines() async {
    AppLogger.storageDelete(_kCachedToday);
    await _prefs.remove(_kCachedToday);
    await _prefs.remove(_kCachedTodayOwner);
  }

  @override
  String? get cachedClientTuningJson => _prefs.getString(_kCachedTuning);

  @override
  Future<void> setCachedClientTuningJson(String json) {
    AppLogger.storageWrite(_kCachedTuning, json);
    return _prefs.setString(_kCachedTuning, json);
  }

  @override
  bool? get isCachedStoreSellingOpen => _prefs.getBool(_kCachedStoreSellingOpen);

  @override
  Future<void> setCachedStoreSellingOpen(bool isOpen) {
    AppLogger.storageWrite(_kCachedStoreSellingOpen, isOpen);
    return _prefs.setBool(_kCachedStoreSellingOpen, isOpen);
  }

  @override
  String? get cachedConsentJson => _prefs.getString(_kCachedConsent);

  @override
  Future<void> setCachedConsentJson(String json) {
    // 약관 전문은 길다. 크기만 남긴다.
    AppLogger.storageWrite(_kCachedConsent, '${json.length}B');
    return _prefs.setString(_kCachedConsent, json);
  }

  @override
  String? getNoticeHiddenJson(String noticeId) =>
      _prefs.getString('$_kNoticeHiddenPrefix$noticeId');

  @override
  Future<void> setNoticeHiddenJson(String noticeId, String json) {
    // 판과 기한 숫자뿐이라 값을 남겨도 된다
    AppLogger.storageWrite('$_kNoticeHiddenPrefix$noticeId', json);
    return _prefs.setString('$_kNoticeHiddenPrefix$noticeId', json);
  }

  @override
  Future<void> clearNoticeHidden() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_kNoticeHiddenPrefix)).toList()) {
      await _prefs.remove(key);
    }
  }

  @override
  bool get hasAskedPushPermission =>
      _prefs.getBool(_kHasAskedPushPermission) ?? false;

  @override
  Future<void> setHasAskedPushPermission(bool v) async {
    AppLogger.storageWrite(_kHasAskedPushPermission, '$v');
    await _prefs.setBool(_kHasAskedPushPermission, v);
  }

  @override
  DateTime? get pushPermissionNudgedAt {
    final raw = _prefs.getString(_kPushPermissionNudgedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> setPushPermissionNudgedAt(DateTime at) async {
    final raw = at.toIso8601String();
    AppLogger.storageWrite(_kPushPermissionNudgedAt, raw);
    await _prefs.setString(_kPushPermissionNudgedAt, raw);
  }

  @override
  bool get isPushPermissionIntroSeen =>
      _prefs.getBool(_kPushPermissionIntroSeen) ?? false;

  @override
  Future<void> setPushPermissionIntroSeen(bool isSeen) async {
    AppLogger.storageWrite(_kPushPermissionIntroSeen, '$isSeen');
    await _prefs.setBool(_kPushPermissionIntroSeen, isSeen);
  }

  @override
  DateTime? get homeNotificationNoticeDismissedAt {
    final raw = _prefs.getString(_kHomeNotificationNoticeDismissedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> setHomeNotificationNoticeDismissedAt(DateTime at) async {
    final raw = at.toIso8601String();
    AppLogger.storageWrite(_kHomeNotificationNoticeDismissedAt, raw);
    await _prefs.setString(_kHomeNotificationNoticeDismissedAt, raw);
  }

  @override
  String? get updateSuggestionShownRecord =>
      _prefs.getString(_kUpdateSuggestionShown);

  @override
  Future<void> setUpdateSuggestionShownRecord(String record) async {
    AppLogger.storageWrite(_kUpdateSuggestionShown, record);
    await _prefs.setString(_kUpdateSuggestionShown, record);
  }

  @override
  bool get isHomeCoachSeen => _prefs.getBool(_kHomeCoachSeen) ?? false;

  @override
  Future<void> setHomeCoachSeen(bool v) async {
    AppLogger.storageWrite(_kHomeCoachSeen, '$v');
    await _prefs.setBool(_kHomeCoachSeen, v);
  }

  @override
  bool get isManageCoachSeen => _prefs.getBool(_kManageCoachSeen) ?? false;

  @override
  Future<void> setManageCoachSeen(bool isSeen) async {
    AppLogger.storageWrite(_kManageCoachSeen, '$isSeen');
    await _prefs.setBool(_kManageCoachSeen, isSeen);
  }

  @override
  List<String> get talkImportedSeenRoutineIds =>
      _prefs.getStringList(_kTalkImportedSeenRoutineIds) ?? const [];

  @override
  Future<void> setTalkImportedSeenRoutineIds(List<String> routineIds) {
    AppLogger.storageWrite(_kTalkImportedSeenRoutineIds, routineIds);
    return _prefs.setStringList(_kTalkImportedSeenRoutineIds, routineIds);
  }

  @override
  List<String> get talkShareHintDismissedRoutineIds =>
      _prefs.getStringList(_kTalkShareHintDismissedRoutineIds) ?? const [];

  @override
  Future<void> setTalkShareHintDismissedRoutineIds(List<String> routineIds) {
    AppLogger.storageWrite(_kTalkShareHintDismissedRoutineIds, routineIds);
    return _prefs.setStringList(
      _kTalkShareHintDismissedRoutineIds,
      routineIds,
    );
  }

  @override
  Map<String, DateTime> get homeSuggestionShownAtByKind {
    final raw = _prefs.getString(_kHomeSuggestionShownAtByKind);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const {};
      return {
        for (final entry in decoded.entries) entry.key: ?DateTime.tryParse('${entry.value}'),
      };
    } on FormatException catch (e) {
      // 깨진 값은 기록 없음으로 봄 (권유가 다시 나올 수 있을 뿐)
      AppLogger.error('storage', e, null, {'key': _kHomeSuggestionShownAtByKind});
      return const {};
    }
  }

  @override
  Future<void> setHomeSuggestionShownAtByKind(Map<String, DateTime> shownAtByKind) async {
    final raw = jsonEncode({
      for (final entry in shownAtByKind.entries) entry.key: entry.value.toIso8601String(),
    });
    AppLogger.storageWrite(_kHomeSuggestionShownAtByKind, raw);
    await _prefs.setString(_kHomeSuggestionShownAtByKind, raw);
  }

  @override
  Set<String> get homeSuggestionDismissedKeys =>
      (_prefs.getStringList(_kHomeSuggestionDismissedKeys) ?? const <String>[]).toSet();

  @override
  Future<void> setHomeSuggestionDismissedKeys(Set<String> dismissedKeys) async {
    AppLogger.storageWrite(_kHomeSuggestionDismissedKeys, dismissedKeys.toList());
    await _prefs.setStringList(_kHomeSuggestionDismissedKeys, dismissedKeys.toList());
  }

  @override
  String? get lowCreditNoticeDismissedPeriod => _prefs.getString(_kLowCreditNoticeDismissedPeriod);

  @override
  Future<void> setLowCreditNoticeDismissedPeriod(String period) async {
    AppLogger.storageWrite(_kLowCreditNoticeDismissedPeriod, period);
    await _prefs.setString(_kLowCreditNoticeDismissedPeriod, period);
  }

  @override
  String? get homeAutoSendUpsellFirstShownDay => _prefs.getString(_kHomeAutoSendUpsellFirstShownDay);

  @override
  Future<void> setHomeAutoSendUpsellFirstShownDay(String day) async {
    AppLogger.storageWrite(_kHomeAutoSendUpsellFirstShownDay, day);
    await _prefs.setString(_kHomeAutoSendUpsellFirstShownDay, day);
  }

  @override
  bool get isHomeAutoSendUpsellClosed => _prefs.getBool(_kHomeAutoSendUpsellClosed) ?? false;

  @override
  Future<void> setHomeAutoSendUpsellClosed(bool isClosed) async {
    AppLogger.storageWrite(_kHomeAutoSendUpsellClosed, '$isClosed');
    await _prefs.setBool(_kHomeAutoSendUpsellClosed, isClosed);
  }

  @override
  String? get homeUpsellShownRecord => _prefs.getString(_kHomeUpsellShownRecord);

  @override
  Future<void> setHomeUpsellShownRecord(String record) async {
    AppLogger.storageWrite(_kHomeUpsellShownRecord, record);
    await _prefs.setString(_kHomeUpsellShownRecord, record);
  }

  @override
  bool get isTalkGridView => _prefs.getBool(_kTalkGridView) ?? true;

  @override
  Future<void> setTalkGridView(bool isGridView) async {
    AppLogger.storageWrite(_kTalkGridView, '$isGridView');
    await _prefs.setBool(_kTalkGridView, isGridView);
  }

  @override
  bool get isGroupCoachSeen => _prefs.getBool(_kGroupCoachSeen) ?? false;

  @override
  Future<void> setGroupCoachSeen(bool isSeen) async {
    AppLogger.storageWrite(_kGroupCoachSeen, '$isSeen');
    await _prefs.setBool(_kGroupCoachSeen, isSeen);
  }

  @override
  bool get isCardReviewCoachSeen =>
      _prefs.getBool(_kCardReviewCoachSeen) ?? false;

  @override
  Future<void> setCardReviewCoachSeen(bool isSeen) async {
    AppLogger.storageWrite(_kCardReviewCoachSeen, '$isSeen');
    await _prefs.setBool(_kCardReviewCoachSeen, isSeen);
  }

  @override
  Future<void> resetCoachMarks() async {
    for (final key in [
      _kHomeCoachSeen,
      _kManageCoachSeen,
      _kGroupCoachSeen,
      _kCardReviewCoachSeen,
    ]) {
      AppLogger.storageWrite(key, 'reset');
      await _prefs.remove(key);
    }
  }

  @override
  bool get isChildHapticOn => _prefs.getBool(_kChildHapticOn) ?? true;

  @override
  Future<void> setChildHapticOn(bool v) async {
    AppLogger.storageWrite(_kChildHapticOn, '$v');
    await _prefs.setBool(_kChildHapticOn, v);
  }

  @override
  bool get isChildPraiseSoundOn => _prefs.getBool(_kChildPraiseSoundOn) ?? true;

  @override
  Future<void> setChildPraiseSoundOn(bool v) async {
    AppLogger.storageWrite(_kChildPraiseSoundOn, '$v');
    await _prefs.setBool(_kChildPraiseSoundOn, v);
  }

  @override
  bool get isChildScreenAwakeOn =>
      _prefs.getBool(_kChildScreenAwakeOn) ?? true;

  @override
  Future<void> setChildScreenAwakeOn(bool v) async {
    AppLogger.storageWrite(_kChildScreenAwakeOn, '$v');
    await _prefs.setBool(_kChildScreenAwakeOn, v);
  }

  @override
  String? get routineRemindersJson => _prefs.getString(_kRoutineReminders);

  @override
  Future<void> setRoutineRemindersJson(String json) async {
    AppLogger.storageWrite(_kRoutineReminders, 'len=${json.length}');
    await _prefs.setString(_kRoutineReminders, json);
  }

  @override
  bool get isElumiDevice => _prefs.getBool(_kElumiDevice) ?? false;

  @override
  Future<void> setElumiDevice(bool v) async {
    AppLogger.storageWrite(_kElumiDevice, '$v');
    await _prefs.setBool(_kElumiDevice, v);
  }

  @override
  bool get isElumiLinkLost => _prefs.getBool(_kElumiLinkLost) ?? false;

  @override
  Future<void> setElumiLinkLost(bool v) async {
    AppLogger.storageWrite(_kElumiLinkLost, '$v');
    await _prefs.setBool(_kElumiLinkLost, v);
  }

  @override
  String? get selectedRole => _prefs.getString(_kSelectedRole);

  @override
  Future<void> setSelectedRole(String v) async =>
      _prefs.setString(_kSelectedRole, v);

  @override
  Future<void> clearSelectedRole() async => _prefs.remove(_kSelectedRole);

  @override
  bool get resumeOnElumiScreen => _prefs.getBool(_kResumeElumiScreen) ?? false;

  @override
  Future<void> setResumeOnElumiScreen(bool v) async {
    // 화면을 옮길 때마다 불린다. 같은 값이면 쓰지 않는다 — 로그만 쌓인다.
    if (resumeOnElumiScreen == v) return;
    AppLogger.storageWrite(_kResumeElumiScreen, '$v');
    await _prefs.setBool(_kResumeElumiScreen, v);
  }

  @override
  Future<void> clearChildProfile() async {
    for (final key in [
      _kNickname,
      _kGoals,
      // 지운 이룸이의 예시를 다음 이룸이에 만들지 않게
      _kPendingExampleCategories,
      _kExampleSeedAttempts,
      _kPendingExampleProfileId,
      _kCharacter,
      _kImageStyle,
      _kCompleted,
      _kSelectedProfile,
    ]) {
      await _prefs.remove(key);
    }
    // 진행 기록·캐시도 이전 아이의 것이다
    for (final key in _prefs.getKeys().where(
      (k) =>
          k.startsWith(_kProgressPrefix) ||
          k == _kCachedToday ||
          k == _kCachedTodayOwner,
    )) {
      await _prefs.remove(key);
    }
  }

  @override
  Future<void> clearAll() async {
    // 앱이 쓰는 키만 지운다. _prefs.clear()는 다른 패키지가 저장한 값까지
    // 날려 원인 모를 오작동을 만든다.
    //
    // 토큰도 함께 지운다 — 이것이 곧 로그아웃이다. 온보딩 값만 지우고 토큰이
    // 남으면 이전 계정의 일과가 새 이름과 섞여 보인다.
    await _guardianLock.clear();
    if (!await _prefs.remove(_kPin)) throw StateError('E-PIN: legacy cleanup failed');
    // 계정 범위 키 전부 (분류표 한 곳 · 역할·이룸이 표식 포함: 이룸이 기기의 로그아웃은 곧 연결 끊기)
    await _removeAccountScopedKeys();
  }

  @override
  Future<void> clearAccountForElumiLink() =>
      _removeAccountScopedKeys(keptKeys: keptOnElumiLinkKeys);

  /// 계정 범위 키·접두사 키 지우기 ([keptKeys] 제외, 로그아웃·연결 공통)
  Future<void> _removeAccountScopedKeys({
    List<String> keptKeys = const [],
  }) async {
    for (final key in accountScopedKeys) {
      if (keptKeys.contains(key)) continue;
      await _prefs.remove(key);
    }
    for (final key in _prefs.getKeys().where(
      (k) => accountScopedKeyPrefixes.any(k.startsWith),
    )) {
      await _prefs.remove(key);
    }
  }
}
