import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<LocalStorage> create() async {
    return SharedPrefsStorage(await SharedPreferences.getInstance());
  }

  @override
  String? get nickname => _prefs.getString(_kNickname);

  @override
  Future<void> setNickname(String v) => _prefs.setString(_kNickname, v);

  @override
  List<String> get goals => _prefs.getStringList(_kGoals) ?? const [];

  @override
  Future<void> setGoals(List<String> v) => _prefs.setStringList(_kGoals, v);

  @override
  String? get character => _prefs.getString(_kCharacter);

  @override
  Future<void> setCharacter(String v) => _prefs.setString(_kCharacter, v);

  @override
  bool get isOnboardingCompleted => _prefs.getBool(_kCompleted) ?? false;

  @override
  Future<void> setOnboardingCompleted(bool v) => _prefs.setBool(_kCompleted, v);

  // PIN 읽기·쓰기를 메서드로 감싸둔다.
  // flutter_secure_storage로 옮길 때 호출부를 건드리지 않기 위함이다.
  //
  // ⚠️ 현재는 평문 저장이다. flutter_secure_storage는 objective_c의 build hook이
  // build_runner의 AOT 컴파일을 깨뜨려 제외했다 (Dart 3.10 이슈).
  @override
  Future<void> setPin(String v) async {
    try {
      await _prefs.setString(_kPin, v);
    } catch (e) {
      debugPrint('[storage] PIN 저장 실패: $e');
    }
  }

  @override
  Future<String?> getPin() async => _prefs.getString(_kPin);
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
}
