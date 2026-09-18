import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/link_status.dart';

/// 연결 암호를 넣었을 때의 결과.
///
/// 실패를 예외로 던지지 않는다 — 화면이 종류별로 다른 문구를 보여줘야 하고,
/// 예외로 올리면 호출부마다 catch가 흩어진다 (저장소 규칙: 예외를 삼키지 않되 화면은 죽지 않는다).
enum RedeemOutcome {
  /// 연결됐다. 토큰까지 저장을 마쳤다.
  linked,

  /// 그런 암호가 없다(틀렸거나 이미 썼다).
  notFound,

  /// 10분이 지났다.
  expired,

  /// 시도가 너무 잦다.
  tooManyAttempts,

  /// 서버에 닿지 못했다.
  offline,

  /// 그 밖의 실패.
  failed,
}

class DeviceLinkRepository {
  DeviceLinkRepository({
    required Dio dio,
    required TokenStore tokens,
    required LocalStorage storage,
  })  : _dio = dio,
        _tokens = tokens,
        _storage = storage;

  final Dio _dio;
  final TokenStore _tokens;
  final LocalStorage _storage;

  /// 새 연결 암호를 만든다. 실패하면 null — 화면이 에러 코드와 함께 알린다.
  Future<IssuedLinkCode?> issue() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/device-links');
      final code = res.data?['code']?.toString();
      // 서버의 절대 시각이 아니라 **남은 초**를 쓴다. 두 시계가 어긋나 있으면
      // 절대 시각을 그대로 믿을 때 남은 시간이 서버보다 길게 나온다 (이슈 #205).
      final seconds = (res.data?['expiresInSeconds'] as num?)?.toInt();
      if (code == null || code.isEmpty || seconds == null || seconds <= 0) {
        AppLogger.error('연결 암호 발급', '응답에 code/expiresInSeconds가 없습니다');
        return null;
      }
      return IssuedLinkCode.fromNow(code: code, expiresInSeconds: seconds);
    } catch (e) {
      AppLogger.error('연결 암호 발급', e);
      return null;
    }
  }

  /// 연결 상태. 실패하면 비어 있는 상태로 돌려준다 — 설정 화면이 멈추지 않게.
  Future<LinkStatus> status() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/device-links');
      final data = res.data;
      return data == null ? LinkStatus.empty : LinkStatus.fromJson(data);
    } catch (e) {
      AppLogger.error('연결 상태 조회', e);
      return LinkStatus.empty;
    }
  }

  /// 연결 하나를 끊는다.
  Future<bool> revoke(String linkId) async {
    try {
      await _dio.delete<dynamic>('/api/device-links/$linkId');
      return true;
    } catch (e) {
      AppLogger.error('연결 끊기', e);
      return false;
    }
  }

  /// 이룸이 휴대폰이 암호를 넣는다. **로그인 전이라 토큰 없이 부른다.**
  Future<RedeemOutcome> redeem(String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/device-links/redeem',
        data: {'code': code},
      );
      final access = res.data?['accessToken']?.toString();
      final refresh = res.data?['refreshToken']?.toString();
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
        AppLogger.error('연결', '응답에 토큰이 없습니다');
        return RedeemOutcome.failed;
      }
      await _tokens.save(accessToken: access, refreshToken: refresh);
      // 이 휴대폰이 이룸이 것임을 남긴다. 세션이 끊겼을 때 보호자 로그인 화면이 아니라
      // 연결 화면으로 되돌리려면 토큰이 사라진 뒤에도 알 수 있어야 한다 (이슈 #206).
      await _storage.setElumiDevice(true);
      await _pullProfile();
      return RedeemOutcome.linked;
    } on DioException catch (e) {
      return _classify(e);
    } catch (e) {
      AppLogger.error('연결', e);
      return RedeemOutcome.failed;
    }
  }

  /// 연결 직후 이 휴대폰에도 아이 정보를 내려 둔다.
  ///
  /// 이룸이 휴대폰은 **로컬에서 온보딩을 한 적이 없다.** 이름·캐릭터가 비어 있으면
  /// 이룸이 화면이 빈 값으로 그려지고, 라우터 가드가 온보딩 미완료로 보고 이름 입력
  /// 화면으로 되돌려 버린다. 계정은 이미 온보딩을 마쳤으므로 서버 값을 가져와 채운다.
  ///
  /// 실패해도 연결 자체는 성공이다 — 다음 화면에서 다시 조회할 기회가 있다.
  Future<void> _pullProfile() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/member/me');
      final nickname = res.data?['nickname']?.toString();
      if (nickname != null && nickname.isNotEmpty) {
        await _storage.setNickname(nickname);
      }
      final character = res.data?['character']?.toString();
      if (character != null && character.isNotEmpty) {
        await _storage.setCharacter(character);
      }
      await _storage.setOnboardingCompleted(true);
    } catch (e) {
      AppLogger.error('연결 후 이룸이 정보 조회', e);
    }
  }

  /// 서버가 내려준 상태·코드를 화면이 쓸 결과로 옮긴다.
  RedeemOutcome _classify(DioException e) {
    AppLogger.error('연결', e);
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return RedeemOutcome.offline;
    }
    final status = e.response?.statusCode;
    final code = e.response?.data is Map
        ? (e.response!.data as Map)['errorCode']?.toString()
        : null;
    // 상태 코드와 errorCode 둘 다 본다 — 프록시가 상태만 바꿔 보내는 경우가 있다.
    if (status == 410 || code == 'DEVICE_LINK_EXPIRED') {
      return RedeemOutcome.expired;
    }
    if (status == 429 || code == 'DEVICE_LINK_TOO_MANY_ATTEMPTS') {
      return RedeemOutcome.tooManyAttempts;
    }
    if (status == 404 || code == 'DEVICE_LINK_NOT_FOUND') {
      return RedeemOutcome.notFound;
    }
    return RedeemOutcome.failed;
  }
}

final deviceLinkRepositoryProvider = Provider<DeviceLinkRepository>((ref) {
  return DeviceLinkRepository(
    dio: ref.watch(dioProvider),
    tokens: ref.watch(tokenStoreProvider),
    storage: ref.watch(localStorageProvider),
  );
});
