import 'local_storage.dart';

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
