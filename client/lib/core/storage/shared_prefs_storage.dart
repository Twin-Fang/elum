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
  static const _kCachedConsent = 'cache.consentDocuments';
  static const _kCachedTuning = 'cache.clientTuning';
  static const _kNoticeHiddenPrefix = 'notice.hidden.';
  static const _kHomeCoachSeen = 'coach.homeSeen';
  static const _kChildHapticOn = 'haptic.childOn';

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
  String? get cachedTodayRoutinesJson => _prefs.getString(_kCachedToday);

  @override
  Future<void> setCachedTodayRoutinesJson(String json) {
    // 호출부가 원문 계열 키를 뺀 JSON 만 넘긴다. 그래도 값은 로그에 찍지 않는다.
    AppLogger.storageWrite(_kCachedToday, '${json.length}B');
    return _prefs.setString(_kCachedToday, json);
  }

  @override
  Future<void> clearCachedTodayRoutines() {
    AppLogger.storageDelete(_kCachedToday);
    return _prefs.remove(_kCachedToday);
  }

  @override
  String? get cachedClientTuningJson => _prefs.getString(_kCachedTuning);

  @override
  Future<void> setCachedClientTuningJson(String json) {
    AppLogger.storageWrite(_kCachedTuning, json);
    return _prefs.setString(_kCachedTuning, json);
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
  bool get isHomeCoachSeen => _prefs.getBool(_kHomeCoachSeen) ?? false;

  @override
  Future<void> setHomeCoachSeen(bool v) async {
    AppLogger.storageWrite(_kHomeCoachSeen, '$v');
    await _prefs.setBool(_kHomeCoachSeen, v);
  }

  @override
  bool get isChildHapticOn => _prefs.getBool(_kChildHapticOn) ?? true;

  @override
  Future<void> setChildHapticOn(bool v) async {
    AppLogger.storageWrite(_kChildHapticOn, '$v');
    await _prefs.setBool(_kChildHapticOn, v);
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
      _kCharacter,
      _kImageStyle,
      _kCompleted,
      _kSelectedProfile,
    ]) {
      await _prefs.remove(key);
    }
    // 진행 기록·캐시도 이전 아이의 것이다
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith(_kProgressPrefix) || k == _kCachedToday,
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
    await clearChildProfile();
    // 역할도 지운다 — 이룸이 휴대폰에서의 로그아웃은 곧 연결 끊기다 (§8-5).
    // 잘못 고른 사람이 로그아웃으로 빠져나올 수 있어야 한다.
    for (final key in [
      _kAccountMemberId,
      _kAccessToken,
      _kElumiDevice,
      _kElumiLinkLost,
      _kSelectedRole,
      // 다음에 로그인한 사람이 이룸이 화면에서 시작하면 안 된다
      _kResumeElumiScreen,
    ]) {
      await _prefs.remove(key);
    }
  }
}
