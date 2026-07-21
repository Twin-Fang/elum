import 'package:shared_preferences/shared_preferences.dart';

import '../logger/app_logger.dart';

/// 로컬 저장소.
///
/// 인터페이스로 두는 이유: 테스트에서 SharedPreferences(플랫폼 채널)를 타지 않고
/// 메모리 구현으로 바꿔 끼우기 위함이다.
///
/// 보호자가 입력한 일과 원문은 어디에도 저장하지 않는다 (docs 원칙 5번).
/// 저장되는 것은 온보딩 결과 4개(호칭·목표·캐릭터·PIN)뿐이다.
abstract interface class LocalStorage {
  String? get nickname;
  Future<void> setNickname(String v);

  List<String> get goals;
  Future<void> setGoals(List<String> v);

  String? get character;
  Future<void> setCharacter(String v);

  bool get isOnboardingCompleted;
  Future<void> setOnboardingCompleted(bool v);

  Future<void> setPin(String v);
  Future<String?> getPin();

  // --- 인증 ---
  // Figma에 로그인 화면이 없어 아이 이름을 아이디로 쓴다 (이슈 #19).
  // 자격증명은 nickname + 고정 비밀번호에서 나오므로 따로 보관하지 않는다.
  // 원문(rawInputText)은 여전히 저장하지 않는다 (docs 원칙 5번).

  /// 서버 accessToken. 만료(1시간)되면 재발급해 덮어쓴다.
  String? get accessToken;
  Future<void> setAccessToken(String v);

  /// 토큰을 지운다. 로그아웃·계정 전환에 쓴다.
  Future<void> clearAccessToken();

  /// 저장된 온보딩 결과를 전부 지운다. **개발·테스트 전용.**
  ///
  /// 일부만 지우면 어중간한 상태가 남아 더 헷갈리므로 5개 값을 모두 비운다.
  /// 인터페이스에 두는 이유는 InMemoryStorage도 같은 동작을 보장해
  /// 테스트로 검증할 수 있게 하기 위함이다. (이슈 #13)
  Future<void> clearAll();
}

/// SharedPreferences 기반 실제 구현.
class SharedPrefsStorage implements LocalStorage {
  SharedPrefsStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _kNickname = 'childNickname';
  static const _kGoals = 'supportGoals';
  static const _kCharacter = 'cardCharacter';
  static const _kCompleted = 'onboardingCompleted';
  static const _kPin = 'guardianPin';
  static const _kAccessToken = 'accessToken';

  static Future<LocalStorage> create() async {
    return SharedPrefsStorage(await SharedPreferences.getInstance());
  }

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

  // PIN 읽기·쓰기를 메서드로 감싸둔다.
  // flutter_secure_storage로 옮길 때 호출부를 건드리지 않기 위함이다.
  //
  // ⚠️ 현재는 평문 저장이다. flutter_secure_storage는 objective_c의 build hook이
  // build_runner의 AOT 컴파일을 깨뜨려 제외했다 (Dart 3.10 이슈).
  @override
  Future<void> setPin(String v) async {
    try {
      AppLogger.storageWrite(_kPin, '***');
      await _prefs.setString(_kPin, v);
    } catch (e) {
      AppLogger.error('storage', e);
    }
  }

  @override
  Future<String?> getPin() async {
    final value = _prefs.getString(_kPin);
    AppLogger.storageRead(_kPin, value != null ? '***' : null);
    return value;
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
  Future<void> clearAll() async {
    // 앱이 쓰는 키만 지운다. _prefs.clear()는 다른 패키지가 저장한 값까지
    // 날려 원인 모를 오작동을 만든다.
    //
    // 토큰도 함께 지운다 — 이것이 곧 로그아웃이다. 온보딩 값만 지우고 토큰이
    // 남으면 이전 계정의 일과가 새 이름과 섞여 보인다. (이슈 #13)
    for (final key in [
      _kNickname,
      _kGoals,
      _kCharacter,
      _kCompleted,
      _kPin,
      _kAccessToken,
    ]) {
      await _prefs.remove(key);
    }
  }
}

/// 메모리 구현. 테스트와 저장소 초기화 실패 시 대체용으로 쓴다.
class InMemoryStorage implements LocalStorage {
  InMemoryStorage({bool onboardingCompleted = false})
      : _completed = onboardingCompleted;

  String? _nickname;
  List<String> _goals = const [];
  String? _character;
  String? _pin;
  bool _completed;
  String? _accessToken;

  @override
  String? get nickname => _nickname;

  @override
  Future<void> setNickname(String v) async => _nickname = v;

  @override
  List<String> get goals => _goals;

  @override
  Future<void> setGoals(List<String> v) async => _goals = v;

  @override
  String? get character => _character;

  @override
  Future<void> setCharacter(String v) async => _character = v;

  @override
  bool get isOnboardingCompleted => _completed;

  @override
  Future<void> setOnboardingCompleted(bool v) async => _completed = v;

  @override
  Future<void> setPin(String v) async => _pin = v;

  @override
  Future<String?> getPin() async => _pin;

  @override
  String? get accessToken => _accessToken;

  @override
  Future<void> setAccessToken(String v) async => _accessToken = v;

  @override
  Future<void> clearAccessToken() async => _accessToken = null;

  @override
  Future<void> clearAll() async {
    _nickname = null;
    _goals = const [];
    _character = null;
    _pin = null;
    _completed = false;
    _accessToken = null;
  }
}
