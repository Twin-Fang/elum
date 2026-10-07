import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logger/app_logger.dart';
import 'installation_store.dart';

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

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clear();
}

/// 기기 보안 저장소(iOS Keychain · Android Keystore)에 담는 구현.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({
    FlutterSecureStorage? storage,
    this.installationId,
    this.allowLegacyMigration = false,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = 'elum.accessToken';
  static const _kRefresh = 'elum.refreshToken';
  static const _kInstallation = 'elum.tokenInstallation';
  static const _kPreviousMember = 'elum.previousMemberId';
  final FlutterSecureStorage _storage;
  final String? installationId;
  final bool allowLegacyMigration;
  String? _accessToken;
  String? _refreshToken;
  bool installationChanged = false;

  /// 서명 검증 없는 캐시 소유자 힌트이며 권한 판단에는 사용하지 않는다.
  String? previousMemberId;

  @override
  String? get accessToken => _accessToken;
  @override
  String? get refreshToken => _refreshToken;
  @override
  bool get hasSession => _refreshToken?.isNotEmpty ?? false;

  @override
  Future<void> load() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      if (installationId == null || installationId!.isEmpty) {
        throw StateError('installation id required');
      }
      final boundId = await _storage.read(key: _kInstallation);
      final access = await _storage.read(key: _kAccess);
      final refresh = await _storage.read(key: _kRefresh);
      previousMemberId = await _storage.read(key: _kPreviousMember);
      if (boundId == null &&
          allowLegacyMigration &&
          refresh?.isNotEmpty == true) {
        // 기존 로컬 설치 상태가 남아있는 업데이트만 일회 결합한다.
        await _storage.write(key: _kInstallation, value: installationId);
        installationChanged = false;
        _accessToken = access;
        _refreshToken = refresh;
        return;
      }
      installationChanged = boundId != installationId;
      if (installationChanged) {
        // 이전 큐는 로그인한 회원과 대조할 때까지 보존하므로 소유자 힌트만 남긴다.
        previousMemberId ??= memberIdHint(access);
        if (previousMemberId != null) {
          await _storage.write(key: _kPreviousMember, value: previousMemberId);
        }
        await _storage.delete(key: _kAccess);
        await _storage.delete(key: _kRefresh);
        return;
      }
      _accessToken = access;
      _refreshToken = refresh;
    } catch (error) {
      _accessToken = null;
      _refreshToken = null;
      throw InstallationException(error);
    }
  }

  static String? memberIdHint(String? token) {
    try {
      final parts = token?.split('.');
      if (parts == null || parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final sub = payload is Map ? payload['sub'] : null;
      return sub is String && sub.trim().isNotEmpty
          ? sub
          : sub is int
          ? sub.toString()
          : null;
    } catch (_) {
      // 손상된 JWT는 소유자도 알 수 없으므로 캐시 보존 근거로 삼지 않는다.
      return null;
    }
  }

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = null;
    _refreshToken = null;
    try {
      if (installationId == null || installationId!.isEmpty) {
        throw StateError('installation id required');
      }
      // 설치 결합을 마지막에 커밋해야 중간 쓰기 실패가 다음 실행 세션으로 살아나지 않는다.
      await _storage.write(key: _kInstallation, value: 'invalidated');
      await _storage.write(key: _kAccess, value: accessToken);
      await _storage.write(key: _kRefresh, value: refreshToken);
      final owner = memberIdHint(accessToken);
      if (owner == null) {
        await _storage.delete(key: _kPreviousMember);
      } else {
        await _storage.write(key: _kPreviousMember, value: owner);
      }
      await _storage.write(key: _kInstallation, value: installationId);
      previousMemberId = owner;
      _accessToken = accessToken;
      _refreshToken = refreshToken;
    } catch (error) {
      AppLogger.error('토큰 저장', error);
      throw InstallationException(error);
    }
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      // 삭제 실패가 재실행에서 토큰을 복원하지 못하도록 결합부터 끊는다.
      await _storage.write(key: _kInstallation, value: 'invalidated');
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (error) {
      throw InstallationException(error);
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
