import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/token_store.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/storage/card_image_disk_cache.dart';
import 'oauth_sdk.dart';
import '../../../core/storage/account_wipe.dart';
import '../../../app/dio_provider.dart';

/// 로그인 결과. 화면이 다음 목적지를 정하는 데 쓴다.
enum AuthOutcome {
  /// 약관 동의를 받지 않은 계정 — 동의 화면부터.
  ///
  /// 동의 없이는 서비스를 쓸 수 없으므로 아이 정보를 입력받기 전에 먼저 받는다.
  /// 온보딩을 다 하고 나서 동의를 거부하면 입력한 것이 전부 버려진다.
  consentRequired,

  /// 동의는 마쳤고 아이 정보가 없는 계정 — 온보딩을 진행한다
  onboarding,

  /// 전부 마친 계정 — 보호자 홈으로 바로 간다
  home,

  /// 사용자가 제공자 화면을 닫았다. **오류가 아니다.**
  /// 스스로 닫은 것에 에러를 띄우면 뭘 잘못한 줄 안다
  cancelled,

  /// 같은 이메일이 이미 다른 방법으로 가입돼 있다
  emailConflict,

  /// 인증 실패 — 화면에 에러 코드와 함께 재시도를 안내한다.
  ///
  /// **갈래를 나눠 둔 이유는 제보를 받았을 때 어디서 터졌는지 가리기 위해서다.**
  /// 사용자에게는 넷 다 "로그인하지 못했어요"로 같지만, 붙는 코드가 달라
  /// 스크린샷 한 장으로 원인을 좁힐 수 있다. 특히 [failedSdk]는 스토어로 받은
  /// 빌드에서만 나기 쉽다 — Play 가 앱을 다시 서명하므로 앱 서명 키의
  /// SHA-1·키해시를 제공자에 등록하지 않으면 그 빌드에서만 깨진다 (#286 4단계).
  ///
  /// 소셜 SDK 자체가 실패했다 (`E-AUTH-SDK`).
  failedSdk,

  /// 서버가 응답은 줬는데 토큰이 비어 있다 (`E-AUTH-TOKEN`).
  failedToken,

  /// 토큰 교환 API 가 오프라인도 409 도 아닌 오류를 냈다 (`E-AUTH-API`).
  failedApi,

  /// 위 어느 것도 아닌 예외 (`E-AUTH`).
  failed,

  /// 서버에 닿지 못했다 (DNS·연결 실패·타임아웃).
  ///
  /// [failed]와 나눠둔 이유는 보여줄 문구가 다르기 때문이다. 네트워크가 끊긴 건데
  /// "다시 로그인해 주세요"라고 하면 사용자는 로그인만 계속 누르게 된다
  offline,
}

/// 로그인 한 번의 결과 — 갈래와 **그 실패가 무엇이었는지**를 함께 돌려준다.
///
/// 전에는 실패를 저장소의 `lastServerError` 필드에 담아 두고 화면이 나중에
/// 꺼내 봤다. **실패는 그 호출의 결과지 저장소의 상태가 아니다** — 요청이 겹치면
/// 엉뚱한 실패를 보여줄 수 있었다 (#352).
class AuthResult {
  const AuthResult(this.outcome, {this.failure});

  final AuthOutcome outcome;

  /// 실패했을 때 서버·네트워크가 알려준 것. 성공이면 null.
  ///
  /// 화면은 이것을 [AppFailure.messageOr] 에 넘겨 **서버 문구를 그대로** 띄운다.
  final AppFailure? failure;
}

/// 서버에 닿지 못한 실패인가. 응답 자체를 못 받은 경우가 여기에 해당한다.
bool _isOffline(AppFailure f) =>
    f.fault == NetworkFault.offline ||
    f.fault == NetworkFault.timeout ||
    f.fault == NetworkFault.badCertificate;

/// 소셜 로그인 기반 인증.
///
/// 제공자 SDK로 받은 토큰을 서버에 넘기면 서버가 확인 후 우리 토큰을 준다.
/// 제공자 토큰은 여기서 버린다 — 저장하지 않는다.
///
/// **절대 throw하지 않는다.** 인증 실패가 화면을 깨뜨리면 안 된다 (docs 원칙 6번).
class AuthRepository {
  AuthRepository({
    required Dio dio,
    required LocalStorage storage,
    required TokenStore tokens,
    required OAuthSdk sdk,
    CardImageDiskCache? imageCache,
  }) : _dio = dio,
       _storage = storage,
       _tokens = tokens,
       _sdk = sdk,
       _imageCache = imageCache;

  final Dio _dio;
  final LocalStorage _storage;
  final TokenStore _tokens;
  final OAuthSdk _sdk;

  /// 기기에 남은 카드 그림. 보호자가 올린 사진이 들어 있어 계정이 끝나면 함께 지운다 (#462).
  final CardImageDiskCache? _imageCache;

  /// 진행 중인 갱신 요청. **동시에 여러 번 갱신하지 않기 위한 장치다.**
  ///
  /// 홈 화면이 API 3개를 동시에 부르다 다 같이 401을 받으면 각자 갱신을 시도한다.
  /// 서버는 리프레시 토큰을 한 번 쓰면 폐기하는 회전 방식이라, 두 번째 요청은
  /// **탈취로 간주돼 계정의 모든 세션이 끊긴다.** 첫 요청만 실제로 보내고
  /// 나머지는 그 결과를 함께 기다린다.
  Future<String?>? _refreshInFlight;

  bool _restoring = false;
  bool lastSignInChangedAccount = false;
  bool get hasSession => !_restoring && _tokens.hasSession;
  bool _guardianPinSetupAllowed = false;
  bool guardianPinSetupPending = false;

  void finishGuardianPinSetup() {
    guardianPinSetupPending = false;
    _guardianPinSetupAllowed = false;
  }

  /// URL만으로 잠금을 새로 만들 수 없게 성공한 보호자 로그인에서 한 번만 허가한다.
  bool consumeGuardianPinSetupPermit() {
    final allowed =
        _guardianPinSetupAllowed && hasSession && !_storage.isElumiDevice;
    _guardianPinSetupAllowed = false;
    return allowed;
  }

  /// 제공자로 로그인한다.
  ///
  /// 실패는 **결과에 담아 돌려준다.** 저장소 필드에 남겨 화면이 꺼내 보게 하면
  /// 요청이 겹칠 때 엉뚱한 실패가 딸려 나온다 (#352).
  Future<AuthResult> signInWith(OAuthProvider provider) async {
    _guardianPinSetupAllowed = false;
    final sdkResult = await _sdk.signIn(provider);

    switch (sdkResult) {
      case OAuthSdkCancelled():
        return const AuthResult(AuthOutcome.cancelled);
      case OAuthSdkFailure(code: final code):
        AppLogger.error('소셜 로그인', code);
        return const AuthResult(AuthOutcome.failedSdk);
      case OAuthSdkSuccess(token: final providerToken):
        return _exchange(provider, providerToken);
    }
  }

  /// 제공자 토큰을 우리 토큰으로 바꾼다.
  Future<AuthResult> _exchange(
    OAuthProvider provider,
    String providerToken,
  ) async {
    _guardianPinSetupAllowed = false;
    _restoring = true;
    final previousOwner =
        _storage.accountMemberId ??
        (_tokens is SecureTokenStore ? _tokens.previousMemberId : null);
    final previousProfile = _storage.selectedProfileId;
    var exchanged = false;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/oauth/${provider.path}',
        data: {'token': providerToken},
      );

      final access = res.data?['accessToken']?.toString();
      final refresh = res.data?['refreshToken']?.toString();
      if (access == null ||
          access.isEmpty ||
          refresh == null ||
          refresh.isEmpty) {
        AppLogger.error('소셜 로그인', '서버 응답에 토큰이 없다');
        return const AuthResult(AuthOutcome.failedToken);
      }

      // 회원 복원이 끝나기 전 토큰을 영속화하면 재실행 시 새 토큰에 옛 프로필이 붙는다.
      exchanged = true;
      await _tokens.clear();
      final outcome = await _resolveDestination(
        previousOwner,
        previousProfile,
        access,
      );
      await _storage.setLastLoginProvider(provider.name);
      await _tokens.save(accessToken: access, refreshToken: refresh);
      return AuthResult(outcome);
    } on DioException catch (e) {
      if (exchanged) await _discardIncompleteSession();
      // 판정은 전역 인터셉터가 이미 해 뒀다. 여기서 본문을 다시 파싱하지 않는다.
      final failure = AppFailure.of(e);
      if (_isOffline(failure)) {
        return AuthResult(AuthOutcome.offline, failure: failure);
      }

      // **서버가 무엇이 잘못됐는지 이미 알려줬다.** 상태 코드만 보고 뭉개면
      // 정지된 계정에게 "잠시 후 다시 해주세요"라고 안내하게 된다 — 사용자는
      // 될 때까지 다시 누른다 (#347).
      // 같은 이메일이 다른 제공자로 이미 가입된 경우. 서버가 이메일로 계정을
      // 합치지 않기 때문에 사용자에게 안내해야 한다.
      if (failure.server?.code == ServerErrorCode.oauthEmailConflict ||
          e.response?.statusCode == 409) {
        return AuthResult(AuthOutcome.emailConflict, failure: failure);
      }
      AppLogger.error('소셜 로그인 교환', e);
      return AuthResult(AuthOutcome.failedApi, failure: failure);
    } catch (e) {
      AppLogger.error('소셜 로그인 교환', e);
      if (exchanged) await _discardIncompleteSession();
      return AuthResult(AuthOutcome.failed, failure: AppFailure.of(e));
    } finally {
      _restoring = false;
    }
  }

  Future<void> _discardIncompleteSession() async {
    _guardianPinSetupAllowed = false;
    try {
      await _tokens.clear();
    } catch (error) {
      AppLogger.error('불완전 세션 삭제', error);
    }
  }

  /// 다음에 보여줄 화면을 정한다. 요청 한 번으로 끝내기 위해 회원 정보에
  /// 동의 완료 여부를 함께 담아 받는다.
  ///
  /// 순서는 **동의 → 아이 정보 → 홈**이다. 동의를 마지막에 받으면 아이 정보를
  /// 다 입력한 뒤 거부했을 때 그 입력이 전부 버려진다.
  Future<AuthOutcome> _resolveDestination(
    String? previousOwner,
    String? previousProfile,
    String access,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/member/me',
      options: Options(
        headers: {'Authorization': 'Bearer $access'},
        extra: {ProfileHeaderInterceptor.skipKey: true},
      ),
    );
    var body = res.data;
    final memberId = body?['id'];
    if (body == null ||
        memberId is! String ||
        memberId.isEmpty ||
        body['requiredConsentsCompleted'] is! bool) {
      throw const FormatException('invalid member snapshot');
    }
    final sameAccount = previousOwner == memberId;
    final profiles = body['profiles'];
    if (profiles != null && profiles is! List) {
      throw const FormatException('invalid profile list');
    }
    String? selectedId;
    if (profiles is List && profiles.isNotEmpty) {
      if (profiles.any(
        (p) => p is! Map || p['id'] is! String || (p['id'] as String).isEmpty,
      )) {
        throw const FormatException('invalid profile');
      }
      selectedId =
          sameAccount &&
              profiles.any((p) => (p as Map)['id'] == previousProfile)
          ? previousProfile
          : (profiles.first as Map)['id'] as String;
      // 최초 응답은 첫 프로필의 정보다. 이전 선택이 살아있으면 그 프로필로 다시 읽는다.
      if (selectedId != (profiles.first as Map)['id']) {
        final selected = await _dio.get<Map<String, dynamic>>(
          '/api/member/me',
          options: Options(
            headers: {
              'Authorization': 'Bearer $access',
              ProfileHeaderInterceptor.headerName: selectedId,
            },
            extra: {ProfileHeaderInterceptor.skipKey: true},
          ),
        );
        body = selected.data;
        if (body == null ||
            body['id'] != memberId ||
            body['requiredConsentsCompleted'] != true) {
          throw const FormatException('invalid selected member snapshot');
        }
      }
    }
    final nickname = body['nickname'];
    if (nickname != null && nickname is! String) {
      throw const FormatException('invalid nickname');
    }
    final goals = body['supportGoals'];
    if (goals != null && (goals is! List || goals.any((g) => g is! String))) {
      throw const FormatException('invalid support goals');
    }
    final character = body['character'];
    final imageStyle = body['imageStyle'];
    if ((character != null && character is! String) ||
        (imageStyle != null && imageStyle is! String)) {
      throw const FormatException('invalid profile settings');
    }
    // 응답을 검증한 뒤에만 계정 범위 로컬 상태를 교체한다. 조회 실패는 기존 큐를 보존한다.
    lastSignInChangedAccount = !sameAccount;
    if (!sameAccount) await _storage.clearAll();
    if (sameAccount &&
        previousProfile != null &&
        selectedId != previousProfile) {
      await _storage.clearChildProfile();
    }
    await _storage.setAccountMemberId(memberId);
    await _storage.setElumiDevice(false);
    await _storage.setElumiLinkLost(false);
    await _storage.setResumeOnElumiScreen(false);
    await _storage.setSelectedRole('guardian');
    if (body['requiredConsentsCompleted'] != true) {
      await _storage.clearChildProfile();
      return AuthOutcome.consentRequired;
    }
    if ((profiles is List && profiles.isEmpty) ||
        nickname == null ||
        nickname.trim().isEmpty) {
      await _storage.clearChildProfile();
      return AuthOutcome.onboarding;
    }
    if (selectedId != null) await _storage.setSelectedProfileId(selectedId);
    await _storage.setNickname(nickname);
    await _storage.setGoals(goals is List ? goals.cast<String>() : const []);
    await _storage.setCharacter(character is String ? character : '');
    await _storage.setImageStyle(imageStyle is String ? imageStyle : 'CARTOON');
    await _storage.setOnboardingCompleted(true);
    guardianPinSetupPending = !await _storage.hasPin();
    _guardianPinSetupAllowed = guardianPinSetupPending;
    return AuthOutcome.home;
  }

  /// 리프레시 토큰으로 액세스 토큰을 다시 받는다. [AuthInterceptor]가 401에서 부른다.
  Future<String?> refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  Future<String?> _performRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refresh},
      );

      final access = res.data?['accessToken']?.toString();
      final nextRefresh = res.data?['refreshToken']?.toString();
      if (access == null ||
          access.isEmpty ||
          nextRefresh == null ||
          nextRefresh.isEmpty) {
        return null;
      }

      // 기다리는 동안 다른 계정이 로그인하면 늦은 응답으로 새 세션을 덮어쓰지 않는다.
      if (_tokens.refreshToken != refresh) return null;
      // 회전 방식이라 리프레시 토큰도 매번 새 값으로 바뀐다. 반드시 덮어쓴다.
      await _tokens.save(accessToken: access, refreshToken: nextRefresh);
      return access;
    } on DioException catch (e) {
      if (_isOffline(AppFailure.of(e))) {
        // 네트워크 문제는 세션 문제가 아니다. 토큰을 지우면 안 된다.
        AppLogger.error('토큰 갱신', '서버에 닿지 못했다');
        return null;
      }
      // 401이면 토큰이 만료·폐기됐거나 재사용으로 감지된 것이다.
      // 어느 쪽이든 이 세션은 끝났으므로 지우고 다시 로그인시킨다.
      if (e.response?.statusCode == 401 && _tokens.refreshToken == refresh) {
        AppLogger.error('토큰 갱신', '세션이 만료되었다');
        await _tokens.clear();
      }
      return null;
    } catch (e) {
      AppLogger.error('토큰 갱신', e);
      return null;
    }
  }

  /// 로그아웃. 서버 세션을 끊고 로컬 토큰을 지운다.
  ///
  /// **서버 요청이 실패해도 로컬은 반드시 지운다.** 로컬에 남으면 사용자는
  /// 로그아웃했다고 생각하는데 앱은 로그인 상태로 동작한다.
  Future<void> logout() async {
    finishGuardianPinSetup();
    final refresh = _tokens.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _dio.post<dynamic>(
          '/api/auth/logout',
          data: {'refreshToken': refresh},
        );
      } catch (e) {
        AppLogger.error('로그아웃', e);
      }
    }
    await wipeLocalAccount(
      tokens: _tokens,
      storage: _storage,
      imageCache: _imageCache,
    );
  }

  /// 회원삭제 — 서버 계정과 로컬 저장값을 모두 지운다. 지워졌으면 true.
  ///
  /// 로그아웃과 다르다. 로그아웃 후 같은 계정으로 다시 들어오면 데이터가 그대로지만,
  /// 회원삭제 후에는 같은 소셜 계정으로 로그인해도 **신규 가입**이 된다.
  ///
  /// **서버가 실패하면 로컬도 건드리지 않고 false를 돌려준다** (이슈 #187).
  /// 계정이 서버에 그대로 있는데 로컬만 비우면, 사용자는 지워진 줄 알고 떠나고
  /// 실제로는 아무것도 지워지지 않는다. 되돌릴 수 없다고 안내한 동작은 됐는지
  /// 안 됐는지를 말해야 한다.
  ///
  /// 삭제는 됐는데 응답만 유실된 경우가 남지만, 그때는 다음 요청이 401을 맞고
  /// 갱신까지 실패해 세션 종료 경로로 빠진다 (이슈 #175). 그쪽에 맡긴다.
  /// null 이면 지워졌다. 실패하면 **서버가 알려준 이유**가 담겨 온다 (#352).
  Future<AppFailure?> deleteAccount() async {
    finishGuardianPinSetup();
    try {
      await _dio.delete<dynamic>('/api/member/me');
    } catch (e) {
      AppLogger.error('회원삭제', e);
      return AppFailure.of(e);
    }
    await wipeLocalAccount(
      tokens: _tokens,
      storage: _storage,
      imageCache: _imageCache,
    );
    return null;
  }
}

/// 앱 전체에서 하나만 쓴다. 갱신 동시성 제어가 인스턴스 안에 있어서
/// 매번 새로 만들면 묶는 의미가 없다.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final oAuthSdkProvider = Provider<OAuthSdk>((ref) => OAuthSdk());

/// 토큰 갱신 전용 인스턴스.
///
/// **인터셉터가 붙지 않은 Dio**를 쓴다. 갱신 요청이 401을 받았을 때 인터셉터가
/// 또 갱신을 부르면 재귀가 된다. 그리고 앱 전체에서 이 인스턴스 하나만 쓰므로
/// 동시 갱신을 묶는 장치가 실제로 동작한다.
final tokenRefresherProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: DioClient.create(),
    storage: ref.watch(localStorageProvider),
    tokens: ref.watch(tokenStoreProvider),
    sdk: ref.watch(oAuthSdkProvider),
    imageCache: ref.watch(cardImageDiskCacheProvider),
  );
});

/// 인증 저장소. 인터셉터가 붙은 [dioProvider]를 쓴다.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
    tokens: ref.watch(tokenStoreProvider),
    sdk: ref.watch(oAuthSdkProvider),
    imageCache: ref.watch(cardImageDiskCacheProvider),
  );
});
