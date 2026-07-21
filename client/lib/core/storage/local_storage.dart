import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 저장소 래퍼.
///
/// 보호자가 입력한 일과 원문은 어디에도 저장하지 않는다 (docs 원칙 5번).
/// 저장되는 것은 온보딩 결과 4개(호칭·목표·캐릭터·PIN)뿐이다.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _kNickname = 'childNickname';
  static const _kGoals = 'supportGoals';
  static const _kCharacter = 'cardCharacter';
  static const _kCompleted = 'onboardingCompleted';
  static const _kPin = 'guardianPin';

  static Future<LocalStorage> create() async {
    return LocalStorage(await SharedPreferences.getInstance());
  }

  String? get nickname => _prefs.getString(_kNickname);
  Future<void> setNickname(String v) => _prefs.setString(_kNickname, v);

  List<String> get goals => _prefs.getStringList(_kGoals) ?? const [];
  Future<void> setGoals(List<String> v) => _prefs.setStringList(_kGoals, v);

  String? get character => _prefs.getString(_kCharacter);
  Future<void> setCharacter(String v) => _prefs.setString(_kCharacter, v);

  bool get isOnboardingCompleted => _prefs.getBool(_kCompleted) ?? false;
  Future<void> setOnboardingCompleted(bool v) => _prefs.setBool(_kCompleted, v);

  // PIN 읽기·쓰기를 메서드로 감싸둔다.
  // flutter_secure_storage로 옮길 때 호출부를 건드리지 않기 위함이다.
  //
  // ⚠️ 현재는 평문 저장이다. flutter_secure_storage는 objective_c의 build hook이
  // build_runner의 AOT 컴파일을 깨뜨려 제외했다 (Dart 3.10 이슈).
  // 보안 해커톤 특성상 발표 전 재검토 대상. 상세는 docs/architecture.md 참조.
  Future<void> setPin(String v) async {
    try {
      await _prefs.setString(_kPin, v);
    } catch (e) {
      debugPrint('[storage] PIN 저장 실패: $e');
    }
  }

  Future<String?> getPin() async => _prefs.getString(_kPin);
}
