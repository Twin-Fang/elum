import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';
import 'guardian_lock_store.dart';

/// 로컬 저장소.
///
/// 인터페이스로 두는 이유: 테스트에서 SharedPreferences(플랫폼 채널)를 타지 않고
/// 메모리 구현으로 바꿔 끼우기 위함이다.
///
/// 보호자가 입력한 일과 원문은 어디에도 저장하지 않는다 (docs 원칙 5번).
/// 저장되는 것은 온보딩 결과 4개(호칭·목표·캐릭터·PIN)뿐이다.
abstract interface class LocalStorage {
  /// 로컬 프로필·진행 큐의 소유자다. 권한 판정은 서버 인증이 담당한다.
  String? get accountMemberId;
  Future<void> setAccountMemberId(String id);

  String? get nickname;
  Future<void> setNickname(String v);

  /// 마지막으로 성공한 로그인 수단(kakao·naver·google·apple).
  ///
  /// 소셜 로그인이 넷이면 사용자는 자기가 뭘 썼는지 잊는다. 다른 것으로 들어오면
  /// **별개 계정이 생겨** "내 아이 정보가 사라졌다"가 된다. 지난 수단을 표시해
  /// 그 사고를 막는다. 민감한 값이 아니라 일반 저장소에 둔다.
  String? get lastLoginProvider;
  Future<void> setLastLoginProvider(String v);

  List<String> get goals;
  Future<void> setGoals(List<String> v);

  String? get character;
  Future<void> setCharacter(String v);

  /// 카드 그림 방식 (#458 · `ImageStyle.apiValue`). 고른 적이 없으면 null —
  /// 기존 설치 앱을 올렸을 때가 그렇고, 읽는 쪽이 만화로 처리한다.
  ///
  /// `character`와 같은 이유로 enum 이 아니라 문자열이다 (core 가 feature 를 모른다).
  String? get imageStyle;
  Future<void> setImageStyle(String v);

  bool get isOnboardingCompleted;
  Future<void> setOnboardingCompleted(bool v);

  /// 보호자가 지금 보고 있는 이룸이 id (다중 보호자 #362).
  ///
  /// 모든 요청에 `X-Profile-Id` 로 실린다. 비어 있으면 서버가 "가장 먼저 합류한 이룸이"를
  /// 쓴다. **이 로그인 세션에만 속한다** — 다른 계정으로 들어왔을 때 남아 있으면 서버가
  /// 403 을 주므로 로그아웃·새 계정 정리가 함께 지운다.
  String? get selectedProfileId;
  Future<void> setSelectedProfileId(String v);
  Future<void> clearSelectedProfileId();

  /// 이 휴대폰이 이룸이(당사자) 것인가 (이슈 #206).
  ///
  /// 연결 암호로 붙은 휴대폰에는 로그인할 계정이 없다. 세션이 끊겼을 때
  /// 보호자 로그인 화면으로 보내면 누를 것이 하나도 없는 막다른 길이 된다.
  bool get isElumiDevice;

  Future<void> setElumiDevice(bool v);

  /// 이 이룸이 휴대폰의 연결이 **밖에서 끊겼다** — 보호자가 끊었거나 세션이 끝났다 (#363).
  ///
  /// 연결 암호 넣기 화면이 `연결이 끊어졌어요`를 말하는 근거다. 앱이 꺼져 있는 사이에 끊겨도
  /// 다음에 열 때 알 수 있어야 해서 저장한다. 스스로 끊은 것(로그아웃)에는 세우지 않고,
  /// 새로 연결에 성공하면 내린다.
  bool get isElumiLinkLost;

  Future<void> setElumiLinkLost(bool v);

  /// 약관 동의 뒤에 고른 역할 (이슈 #212 · `AppRole.storageValue`).
  ///
  /// enum이 아니라 문자열로 주고받는다 — core가 feature의 `AppRole`을 알면
  /// 의존 방향이 뒤집힌다 (`character`도 같은 이유로 문자열이다).
  ///
  /// ⚠️ [isElumiDevice]와 다르다. 역할은 **고른 순간** 정해지고, 이룸이 휴대폰
  /// 여부는 **연결에 성공한 순간** 정해진다. 둘을 같이 세우면 역할만 고르고
  /// 연결 전인 사람이 라우터 가드에 붙잡혀 뒤로 갈 수 없게 된다.
  String? get selectedRole;

  Future<void> setSelectedRole(String v);

  Future<void> clearSelectedRole();

  /// 보호자 휴대폰이 마지막에 **이룸이 화면**에 있었는가 (#532).
  ///
  /// 한 휴대폰을 보호자와 이룸이가 같이 쓰면, 보호자가 이룸이 화면으로 넘겨 준 뒤 휴대폰을
  /// 껐다 켜도 이룸이 화면이어야 한다. 이 값이 없으면 시작 화면이 매번 보호자 홈을 열어
  /// 이룸이가 암호 없이 보호자 화면을 보게 된다.
  ///
  /// ⚠️ [isElumiDevice]와 다르다. 그쪽은 연결로 붙은 **이룸이 전용 휴대폰**이고,
  /// 이 값은 보호자 휴대폰이 지금 어느 화면을 띄우고 있는지다.
  bool get resumeOnElumiScreen;

  Future<void> setResumeOnElumiScreen(bool v);

  Future<void> setPin(String v);
  Future<bool> hasPin();
  Future<bool> verifyPin(String pin);

  // --- 인증 ---
  // Figma에 로그인 화면이 없어 아이 이름을 아이디로 쓴다 (이슈 #19).
  // 자격증명은 nickname + 고정 비밀번호에서 나오므로 따로 보관하지 않는다.
  // 원문(rawInputText)은 여전히 저장하지 않는다 (docs 원칙 5번).

  /// 서버 accessToken. 만료(1시간)되면 재발급해 덮어쓴다.
  String? get accessToken;
  Future<void> setAccessToken(String v);

  /// 토큰을 지운다. 로그아웃·계정 전환에 쓴다.
  Future<void> clearAccessToken();

  // --- 아동 카드 진행 (오프라인 퍼스트, 이슈 #140) ---
  // 일과별 완료·보상 기록과 서버 반영 대기열, 오늘 일과 캐시.
  // JSON 문자열로만 주고받는다 — core가 feature 모델(RoutineProgressRecord)을
  // 알면 의존 방향이 뒤집힌다. 직렬화는 feature 쪽 ProgressStore가 한다.

  String? getRoutineProgressJson(String routineId);
  Future<void> setRoutineProgressJson(String routineId, String json);
  Future<void> removeRoutineProgress(String routineId);

  /// 서버 반영이 아직 안 끝난 일과 id 목록.
  List<String> get pendingSyncRoutineIds;
  Future<void> setPendingSyncRoutineIds(List<String> ids);

  /// 마지막으로 성공한 `/api/routines/today` 응답. 오프라인에서 목록을 띄우는 데 쓴다.
  String? get cachedTodayRoutinesJson;
  Future<void> setCachedTodayRoutinesJson(String json);

  /// 오늘 일과 캐시만 지운다. 이룸이를 바꿀 때 쓴다 (#362 · E44).
  ///
  /// 오프라인이면 이 캐시를 보여 주는데, 바꾸기 전 이룸이의 일과가 남아 있으면
  /// 다른 이룸이의 일과가 이 이룸이 것처럼 뜬다.
  Future<void> clearCachedTodayRoutines();

  /// 마지막으로 서버에서 받은 약관 전문 (이슈 #278).
  ///
  /// 약관은 서버가 원본을 들고 있지만 **서버를 못 봐도 읽을 수 있어야 한다** —
  /// 읽을 수 없는 상태에서 받은 동의는 고지로 성립하지 않는다. 그래서 받은 것을
  /// 여기 담아 두고, 이것도 없으면 앱에 박힌 기본값으로 떨어진다.
  String? get cachedConsentJson;
  Future<void> setCachedConsentJson(String json);

  /// 마지막으로 서버에서 받은 대기·연출 시간값 (`ClientTuning`).
  ///
  /// 앱이 뜰 때 서버에 닿기 전 첫 요청부터 이 값으로 돈다. 없으면 코드 기본값이다.
  String? get cachedClientTuningJson;
  Future<void> setCachedClientTuningJson(String json);

  // --- 공지 "보지 않기" 기록 (이슈 #371) ---
  // 공지마다 `{revision, until}` JSON 한 줄. 판단은 feature 쪽 NoticeHideStore 가 한다 —
  // 진행 기록과 같은 이유로 core 는 문자열만 주고받는다.
  //
  // ⚠️ [clearAll]·[clearChildProfile] 이 **지우지 않는다.** 숨김은 계정이 아니라
  // 이 휴대폰에서 이미 본 공지에 대한 것이다. 로그아웃했다 들어왔다고 방금 숨긴
  // 공지가 다시 뜨면 보지 않기를 누른 뜻이 사라진다.

  String? getNoticeHiddenJson(String noticeId);
  Future<void> setNoticeHiddenJson(String noticeId, String json);

  /// 보호자 홈 코치마크를 이 휴대폰에서 이미 봤는가 (#505).
  ///
  /// 공지 숨김과 같은 이유로 **계정이 아니라 휴대폰에 속한다.** [clearAll] 이 지우지 않는다 —
  /// 로그아웃했다 들어왔다고 안내를 처음부터 다시 보여 주면 귀찮기만 하다.
  bool get isHomeCoachSeen;
  Future<void> setHomeCoachSeen(bool v);

  /// 이룸이 화면의 카드 진동을 켜 두었는가 (#515). **기본은 켜짐**이라 저장된 적이 없으면 true.
  ///
  /// 코치마크와 같은 이유로 **계정이 아니라 휴대폰에 속한다.** [clearAll] 이 지우지 않는다 —
  /// 진동에 예민한 이룸이가 쓰는 휴대폰이 로그아웃 한 번에 다시 울리면 안 된다.
  bool get isChildHapticOn;
  Future<void> setChildHapticOn(bool v);

  /// 저장된 온보딩 결과를 전부 지운다. **개발·테스트 전용.**
  ///
  /// 일부만 지우면 어중간한 상태가 남아 더 헷갈리므로 5개 값을 모두 비운다.
  /// 인터페이스에 두는 이유는 InMemoryStorage도 같은 동작을 보장해
  /// 테스트로 검증할 수 있게 하기 위함이다. (이슈 #13)
  Future<void> clearAll();

  /// 아이 정보만 지운다. 토큰은 건드리지 않는다.
  ///
  /// 새 계정으로 막 로그인한 직후에 쓴다 — 그 계정에는 아직 아이 정보가 없는데
  /// 이전 계정의 이름이 남아 있으면 입력칸에 남의 이름이 미리 채워진다 (이슈 #177).
  /// [clearAll]은 토큰까지 지워 방금 받은 세션이 날아가므로 여기서는 쓸 수 없다.
  Future<void> clearChildProfile();
}

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
    // 호출부가 원문 계열 키를 뺀 JSON 만 넘긴다(#358). 그래도 값은 로그에 찍지 않는다.
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
    // 남으면 이전 계정의 일과가 새 이름과 섞여 보인다. (이슈 #13)
    await _guardianLock.clear();
    if (!await _prefs.remove(_kPin)) throw StateError('E-PIN: legacy cleanup failed');
    await clearChildProfile();
    // 역할도 지운다 — 이룸이 휴대폰에서의 로그아웃은 곧 연결 끊기다 (§8-5).
    // 잘못 고른 사람이 로그아웃으로 빠져나올 수 있어야 한다 (이슈 #212).
    for (final key in [
      _kAccountMemberId,
      _kAccessToken,
      _kElumiDevice,
      _kElumiLinkLost,
      _kSelectedRole,
      // 다음에 로그인한 사람이 이룸이 화면에서 시작하면 안 된다 (#532)
      _kResumeElumiScreen,
    ]) {
      await _prefs.remove(key);
    }
  }
}

/// 메모리 구현. 테스트와 저장소 초기화 실패 시 대체용으로 쓴다.
class InMemoryStorage implements LocalStorage {
  InMemoryStorage({
    bool onboardingCompleted = false,
    String? pin,
    String? nickname,
    String? character,
    bool elumiDevice = false,
    // 기본은 "이미 봤다" — 홈을 띄우는 기존 테스트마다 코치마크가 화면을 덮으면 안 된다.
    // 코치마크를 검증하는 테스트만 false 를 준다. 실제 앱의 첫 실행 기본값은 false 다.
    bool homeCoachSeen = true,
    bool childHapticOn = true,
  }) : _childHapticOn = childHapticOn,
       _completed = onboardingCompleted,
       _homeCoachSeen = homeCoachSeen,
       _pin = pin,
       _nickname = nickname,
       _character = character,
       _elumi = elumiDevice;

  String? _accountMemberId;

  @override
  String? get accountMemberId => _accountMemberId;

  @override
  Future<void> setAccountMemberId(String id) async => _accountMemberId = id;

  bool _elumi;
  bool _elumiLinkLost = false;
  bool _homeCoachSeen;

  String? _nickname;
  List<String> _goals = const [];
  String? _character;
  String? _imageStyle;
  String? _pin;
  bool _completed;
  String? _selectedProfileId;
  String? _accessToken;
  final Map<String, String> _progress = {};
  List<String> _pendingSync = const [];
  String? _cachedToday;
  String? _cachedConsent;

  @override
  String? get nickname => _nickname;

  @override
  Future<void> setNickname(String v) async => _nickname = v;

  String? _lastLoginProvider;

  @override
  String? get lastLoginProvider => _lastLoginProvider;

  @override
  Future<void> setLastLoginProvider(String v) async => _lastLoginProvider = v;

  @override
  List<String> get goals => _goals;

  @override
  Future<void> setGoals(List<String> v) async => _goals = v;

  @override
  String? get character => _character;

  @override
  Future<void> setCharacter(String v) async => _character = v;

  @override
  String? get imageStyle => _imageStyle;

  @override
  Future<void> setImageStyle(String v) async => _imageStyle = v;

  @override
  bool get isOnboardingCompleted => _completed;

  @override
  Future<void> setOnboardingCompleted(bool v) async => _completed = v;

  @override
  String? get selectedProfileId => _selectedProfileId;

  @override
  Future<void> setSelectedProfileId(String v) async => _selectedProfileId = v;

  @override
  Future<void> clearSelectedProfileId() async => _selectedProfileId = null;

  bool _childHapticOn;

  @override
  bool get isChildHapticOn => _childHapticOn;

  @override
  Future<void> setChildHapticOn(bool v) async => _childHapticOn = v;

  @override
  bool get isElumiDevice => _elumi;

  @override
  Future<void> setElumiDevice(bool v) async => _elumi = v;

  @override
  bool get isElumiLinkLost => _elumiLinkLost;

  @override
  Future<void> setElumiLinkLost(bool v) async => _elumiLinkLost = v;

  String? _role;

  @override
  String? get selectedRole => _role;

  @override
  Future<void> setSelectedRole(String v) async => _role = v;

  @override
  Future<void> clearSelectedRole() async => _role = null;

  bool _resumeElumiScreen = false;

  @override
  bool get resumeOnElumiScreen => _resumeElumiScreen;

  @override
  Future<void> setResumeOnElumiScreen(bool v) async => _resumeElumiScreen = v;

  @override
  Future<void> setPin(String v) async => _pin = v;

  @override
  Future<bool> hasPin() async => _pin?.isNotEmpty ?? false;

  @override
  Future<bool> verifyPin(String pin) async => await hasPin() && _pin == pin;

  @override
  String? get accessToken => _accessToken;

  @override
  Future<void> setAccessToken(String v) async => _accessToken = v;

  @override
  Future<void> clearAccessToken() async => _accessToken = null;

  @override
  String? getRoutineProgressJson(String routineId) => _progress[routineId];

  @override
  Future<void> setRoutineProgressJson(String routineId, String json) async =>
      _progress[routineId] = json;

  @override
  Future<void> removeRoutineProgress(String routineId) async =>
      _progress.remove(routineId);

  @override
  List<String> get pendingSyncRoutineIds => _pendingSync;

  @override
  Future<void> setPendingSyncRoutineIds(List<String> ids) async =>
      _pendingSync = ids;

  @override
  String? get cachedTodayRoutinesJson => _cachedToday;

  @override
  Future<void> setCachedTodayRoutinesJson(String json) async =>
      _cachedToday = json;

  @override
  Future<void> clearCachedTodayRoutines() async => _cachedToday = null;

  String? _cachedTuning;

  @override
  String? get cachedClientTuningJson => _cachedTuning;

  @override
  Future<void> setCachedClientTuningJson(String json) async =>
      _cachedTuning = json;

  @override
  String? get cachedConsentJson => _cachedConsent;

  @override
  Future<void> setCachedConsentJson(String json) async => _cachedConsent = json;

  final Map<String, String> _noticeHidden = {};

  @override
  String? getNoticeHiddenJson(String noticeId) => _noticeHidden[noticeId];

  @override
  Future<void> setNoticeHiddenJson(String noticeId, String json) async =>
      _noticeHidden[noticeId] = json;

  @override
  bool get isHomeCoachSeen => _homeCoachSeen;

  @override
  Future<void> setHomeCoachSeen(bool v) async => _homeCoachSeen = v;

  @override
  Future<void> clearChildProfile() async {
    _nickname = null;
    _goals = const [];
    _character = null;
    _imageStyle = null;
    _completed = false;
    _selectedProfileId = null;
    _progress.clear();
    _cachedToday = null;
  }

  @override
  Future<void> clearAll() async {
    _accountMemberId = null;
    _nickname = null;
    _goals = const [];
    _character = null;
    _imageStyle = null;
    _pin = null;
    _completed = false;
    _selectedProfileId = null;
    _accessToken = null;
    _elumi = false;
    _elumiLinkLost = false;
    _role = null;
    _resumeElumiScreen = false;
    _progress.clear();
    _pendingSync = const [];
    _cachedToday = null;
  }
}
