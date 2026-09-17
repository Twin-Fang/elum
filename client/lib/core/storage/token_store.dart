import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logger/app_logger.dart';

/// 서버 토큰 보관소.
///
/// **`SharedPreferences`를 쓰지 않는다.** 그쪽은 평문이라 루팅·탈옥된 기기에서
/// 그대로 읽힌다. 액세스 토큰만 있을 때는 수명이 짧아 위험이 제한적이었지만,
/// 리프레시 토큰은 180일 동안 계정을 열 수 있는 열쇠다.
///
/// 읽기가 비동기라 요청마다 기다리면 느리다. 앱 시작에서 [load]로 한 번 읽어
/// 메모리에 들고, 이후 동기 getter로 꺼내 쓴다.
abstract class TokenStore {
  String? get accessToken;

  String? get refreshToken;

  /// 리프레시 토큰이 있으면 로그인 상태다. 액세스 토큰은 만료돼도 갱신하면 되므로
  /// 세션 판단 기준으로 쓰지 않는다.
  bool get hasSession;

  /// 앱 시작 시 한 번 호출한다.
  Future<void> load();

  Future<void> save({required String accessToken, required String refreshToken});

  Future<void> clear();
}

/// 기기 보안 저장소(iOS Keychain · Android Keystore)에 담는 구현.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      // 11.x 기본값이 이미 AES-GCM + RSA 키 래핑(Android) / Keychain(iOS)이다.
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = 'elum.accessToken';
  static const _kRefresh = 'elum.refreshToken';

  final FlutterSecureStorage _storage;

  String? _accessToken;
  String? _refreshToken;

  @override
  String? get accessToken => _accessToken;

  @override
  String? get refreshToken => _refreshToken;

  @override
  bool get hasSession => _refreshToken != null && _refreshToken!.isNotEmpty;

  /// 실패해도 앱은 떠야 하므로 예외를 삼키고 로그아웃 상태로 시작한다 —
  /// 기기 보안 저장소 접근이 막힌 환경도 있다.
  @override
  Future<void> load() async {
    try {
      _accessToken = await _storage.read(key: _kAccess);
      _refreshToken = await _storage.read(key: _kRefresh);
      AppLogger.storageRead(_kRefresh, _refreshToken != null ? '***' : null);
    } catch (e) {
      AppLogger.error('토큰 읽기', e);
      _accessToken = null;
      _refreshToken = null;
    }
  }

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    AppLogger.storageWrite(_kRefresh, '***');
    try {
      await _storage.write(key: _kAccess, value: accessToken);
      await _storage.write(key: _kRefresh, value: refreshToken);
    } catch (e) {
      // 메모리에는 남아 있으므로 이번 실행 동안은 동작한다.
      // 다음 실행에서 다시 로그인하게 될 뿐 지금 흐름을 끊지 않는다.
      AppLogger.error('토큰 저장', e);
    }
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    AppLogger.storageDelete(_kRefresh);
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (e) {
      AppLogger.error('토큰 삭제', e);
    }
  }
}

/// 테스트·미리보기용. 기기 저장소를 건드리지 않는다.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore({String? accessToken, String? refreshToken})
      : _accessToken = accessToken,
        _refreshToken = refreshToken;

  String? _accessToken;
  String? _refreshToken;

  @override
  String? get accessToken => _accessToken;

  @override
  String? get refreshToken => _refreshToken;

  @override
  bool get hasSession => _refreshToken != null && _refreshToken!.isNotEmpty;

  @override
  Future<void> load() async {}

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
