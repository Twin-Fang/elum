import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/token_store.dart';
import '../../guardian/data/card_image_disk_cache.dart';
import '../../onboarding/domain/image_style.dart';
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

/// 암호 넣기 한 번의 결과 — 갈래와 **그 실패가 무엇이었는지**를 함께 돌려준다.
///
/// 갈래만으로는 서버가 알려준 문구를 화면에 전할 수 없다. 이유가 저장소 안에서
/// 사라지면 화면은 자기가 지어낸 말밖에 못 한다 (#352).
class RedeemResult {
  const RedeemResult(this.outcome, {this.failure});

  final RedeemOutcome outcome;

  /// 실패했을 때 서버·네트워크가 알려준 것. 성공이면 null.
  final AppFailure? failure;
}

/// 연결 하나를 끊은 결과 (#363).
///
/// 갈래가 셋인 이유 — `이미 끊겨 있었다`를 실패로 보이면 보호자는 끊겼는데 "못 끊었어요"를 본다.
/// 끊으려던 결과(연결이 없다)는 이미 이뤄졌으므로 성공과 같이 다루되, 말은 다르게 한다.
enum RevokeOutcome {
  /// 이번에 끊었다.
  done,

  /// 이미 끊겨 있었다 — 이룸이 휴대폰이 스스로 끊었거나 다른 보호자가 먼저 끊었다.
  alreadyGone,

  /// 끊지 못했다. 연결은 그대로다.
  failed,
}

/// [DeviceLinkRepository.revoke] 의 결과 — 갈래와 **실패 이유**를 함께 돌려준다 (#352).
class RevokeResult {
  const RevokeResult(this.outcome, {this.failure});

  final RevokeOutcome outcome;

  /// 끊지 못했을 때 서버·네트워크가 알려준 것. 성공이면 null.
  final AppFailure? failure;

  /// 연결이 이제 없다 — 이번에 끊었든 이미 끊겨 있었든.
  bool get isGone => outcome != RevokeOutcome.failed;
}

class DeviceLinkRepository {
  DeviceLinkRepository({
    required Dio dio,
    required TokenStore tokens,
    required LocalStorage storage,
    CardImageDiskCache? imageCache,
  })  : _dio = dio,
        _tokens = tokens,
        _storage = storage,
        _imageCache = imageCache;

  final Dio _dio;

  /// 받아 둔 카드 그림. 스스로 로그아웃할 때 함께 비운다 — 보호자 로그아웃과 같다.
  final CardImageDiskCache? _imageCache;
  final TokenStore _tokens;
  final LocalStorage _storage;

  /// 이 이룸이 휴대폰의 연결이 **밖에서 끊겼다**(보호자가 끊었거나 세션이 끝났다) — 연결 화면이 말한다 (#363).
  bool get linkWasLost => _storage.isElumiLinkLost;

  /// 새 연결 암호를 만든다.
  ///
  /// 실패하면 **이유까지 담아** 돌려준다 — 화면이 서버 문구를 그대로 띄운다 (#352).
  Future<Attempt<IssuedLinkCode>> issue() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/device-links');
      final code = res.data?['code']?.toString();
      // 서버의 절대 시각이 아니라 **남은 초**를 쓴다. 두 시계가 어긋나 있으면
      // 절대 시각을 그대로 믿을 때 남은 시간이 서버보다 길게 나온다 (이슈 #205).
      final seconds = (res.data?['expiresInSeconds'] as num?)?.toInt();
      if (code == null || code.isEmpty || seconds == null || seconds <= 0) {
        AppLogger.error('연결 암호 발급', '응답에 code/expiresInSeconds가 없습니다');
        return const Attempt.failed(AppFailure(fault: NetworkFault.app));
      }
      return Attempt.ok(
        IssuedLinkCode.fromNow(code: code, expiresInSeconds: seconds),
      );
    } catch (e) {
      AppLogger.error('연결 암호 발급', e);
      return Attempt.failed(AppFailure.of(e));
    }
  }

  /// 연결 상태 — 실패하면 **이유와 함께** 돌려준다 (#363).
  ///
  /// 상태 화면이 빈 화면·무한 로딩 대신 `다시 시도`와 에러 코드를 보여줘야 한다.
  Future<Attempt<LinkStatus>> statusResult() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/device-links');
      final data = res.data;
      return Attempt.ok(data == null ? LinkStatus.empty : LinkStatus.fromJson(data));
    } catch (e) {
      AppLogger.error('연결 상태 조회', e);
      return Attempt.failed(AppFailure.of(e));
    }
  }

  /// 연결 하나를 끊는다 — 보호자 휴대폰에서 (명세 §8-5).
  ///
  /// 404(`DEVICE_LINK_NOT_CONNECTED`)는 실패가 아니라 [RevokeOutcome.alreadyGone] 이다. 이룸이 휴대폰이
  /// 스스로 끊었거나 다른 보호자가 먼저 끊은 경우라, 보호자가 원한 상태(연결 없음)가 이미 됐다.
  /// 그 밖의 실패(403·5xx·오프라인)는 연결이 그대로이니 이유를 담아 돌려준다.
  Future<RevokeResult> revoke(String linkId) async {
    try {
      await _dio.delete<dynamic>('/api/device-links/$linkId');
      return const RevokeResult(RevokeOutcome.done);
    } catch (e) {
      final failure = AppFailure.of(e);
      if (_isAlreadyDisconnected(e, failure)) {
        return const RevokeResult(RevokeOutcome.alreadyGone);
      }
      AppLogger.error('연결 끊기', e);
      return RevokeResult(RevokeOutcome.failed, failure: failure);
    }
  }

  /// 서버가 "연결된 휴대폰이 아니다"라고 답했는가. 프록시가 바꿔 보낸 404 와 구분하려고 코드를 함께 본다.
  bool _isAlreadyDisconnected(Object e, AppFailure failure) =>
      e is DioException &&
      e.response?.statusCode == 404 &&
      failure.server?.code == ServerErrorCode.deviceLinkNotConnected;

  /// 이 휴대폰(이룸이)이 **스스로** 연결을 끊는다 — 설정의 로그아웃·회원탈퇴 (#363).
  ///
  /// 서버가 연결을 끊은 **뒤에만** 로컬을 정리한다. 서버가 안 끊겼는데 로컬만 비우면 보호자 화면에는
  /// 계속 `연결됨`이 남고 이 휴대폰은 연결 화면으로 가 버린다 — 되돌릴 수 없다고 안내한 동작은 됐는지
  /// 안 됐는지를 말해야 한다 (#187). 그래서 실패하면 아무것도 지우지 않고 이유만 돌려준다.
  ///
  /// 이미 끊겨 있으면(404 `DEVICE_LINK_NOT_CONNECTED`·401) 원하는 결과가 이미 됐으므로 정리하고 끝낸다.
  /// 401 은 토큰 갱신까지 실패했다는 뜻이라 서버가 이 연결을 더는 인정하지 않는 것이다.
  ///
  /// **로컬은 보호자 로그아웃처럼 전부 비운다** — `이룸이 휴대폰` 표식과 역할까지 (#542). 스스로 나간
  /// 사람은 로그인 화면으로 간다. 표식을 남기면 연결 화면에 갇히고, 역할(`이룸이`)을 남기면 다시
  /// 로그인해도 연결 화면으로 끌려간다. 밖에서 끊긴 경우([releaseThisPhone])와 다르다.
  ///
  /// null 이면 끊겼고 로컬도 정리했다.
  Future<AppFailure?> disconnectThisPhone() async {
    try {
      await _dio.delete<dynamic>('/api/device-links/current');
    } catch (e) {
      final failure = AppFailure.of(e);
      final gone = _isAlreadyDisconnected(e, failure) ||
          (e is DioException && e.response?.statusCode == 401);
      if (!gone) {
        AppLogger.error('이 휴대폰 연결 끊기', e);
        return failure;
      }
    }
    await _tokens.clear();
    await _storage.clearAll();
    // 파일 삭제는 기다리지 않는다 — 화면 이동이 디스크에 묶이면 안 된다. 세대 표식은 부르는 즉시 올라가
    // 진행 중인 다운로드가 뒤늦게 저장하지 못한다 (세션 만료 때 dio_client 와 같다).
    if (_imageCache != null) unawaited(_imageCache.clear());
    return null;
  }

  /// 연결이 끊긴 이룸이 휴대폰의 로컬을 비운다 (#363).
  ///
  /// 지우는 것 — 토큰, 이룸이 정보(이름·캐릭터·그림 방식), 일과 캐시, 체크 기록. **남기는 것 — `이룸이 휴대폰`
  /// 표식**이다. 이 휴대폰은 스스로 나간 것이 아니라 밖에서 끊겼으므로, 다시 켜도 연결 화면에서 `연결이
  /// 끊어졌어요`를 말하고 같은 이룸이에게 다시 붙을 수 있어야 한다(#206). 연결 화면의 뒤로가기는 로그인으로
  /// 간다(#542). 로그인하면 표식이 내려간다([AuthRepository]).
  ///
  /// 스스로 로그아웃·탈퇴한 경우는 여기가 아니다 — [disconnectThisPhone] 이 표식까지 전부 지운다.
  ///
  /// [lost] 가 true 면 `연결이 끊어졌어요`를 다음 연결 화면에서 말한다. 스스로 끊은 것은 false 다.
  Future<void> releaseThisPhone({required bool lost}) async {
    await _tokens.clear();
    await _storage.clearChildProfile();
    await _storage.setElumiLinkLost(lost);
  }

  /// 이룸이 휴대폰이 암호를 넣는다. **로그인 전이라 토큰 없이 부른다.**
  Future<RedeemResult> redeem(String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/device-links/redeem',
        data: {'code': code},
      );
      final access = res.data?['accessToken']?.toString();
      final refresh = res.data?['refreshToken']?.toString();
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
        AppLogger.error('연결', '응답에 토큰이 없습니다');
        return const RedeemResult(RedeemOutcome.failed);
      }
      await _tokens.save(accessToken: access, refreshToken: refresh);
      // 이 휴대폰이 이룸이 것임을 남긴다. 세션이 끊겼을 때 보호자 로그인 화면이 아니라
      // 연결 화면으로 되돌리려면 토큰이 사라진 뒤에도 알 수 있어야 한다 (이슈 #206).
      await _storage.setElumiDevice(true);
      // 새로 이어졌다 — 전에 끊겼다는 안내는 거둔다 (#363)
      await _storage.setElumiLinkLost(false);
      await _pullProfile();
      return const RedeemResult(RedeemOutcome.linked);
    } on DioException catch (e) {
      return RedeemResult(_classify(e), failure: AppFailure.of(e));
    } catch (e) {
      AppLogger.error('연결', e);
      return RedeemResult(RedeemOutcome.failed, failure: AppFailure.of(e));
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
      // 보호자가 정한 그림 방식 (#458). 없거나 모르는 값이면 담지 않는다 — 로컬이 비면
      // 읽는 쪽이 만화로 처리하므로 옛 서버·새 값이어도 연결은 그대로 성공한다.
      final imageStyle = res.data?['imageStyle'];
      if (imageStyle is String &&
          ImageStyle.values.any((s) => s.apiValue == imageStyle)) {
        await _storage.setImageStyle(imageStyle);
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
    imageCache: ref.watch(cardImageDiskCacheProvider),
  );
});

/// 보호자 휴대폰의 이룸이 휴대폰 연결 상태. 설정 줄과 상태 화면이 함께 본다 (#363).
///
/// 화면을 떠나면 버린다 — 연결은 다른 사람(이룸이 휴대폰·다른 보호자)이 언제든 바꾸므로 오래된 값을 두지 않는다.
final linkStatusProvider = FutureProvider.autoDispose<Attempt<LinkStatus>>((ref) {
  return ref.watch(deviceLinkRepositoryProvider).statusResult();
});
