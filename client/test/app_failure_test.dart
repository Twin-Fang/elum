import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/failure_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 전역 실패 판정 (이슈 #352).
///
/// **여기서 지키는 약속은 둘이다.**
/// 1. 서버가 문구를 줬으면 **그 문구가 이긴다** — 앱이 지어낸 말로 덮지 않는다.
/// 2. 어떤 모양이 와도 **던지지 않는다** — 실패를 알리려다 앱이 죽으면 사용자는
///    무슨 일이 났는지조차 모른다.
DioException _res(dynamic data, {int status = 400}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

DioException _typed(DioExceptionType type, {Object? error}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  error: error,
);

void main() {
  group('서버가 준 문구가 앱 문구를 이긴다', () {
    test('문구가 있으면 그대로 쓴다', () {
      final f = AppFailure.of(_res({
        'errorCode': 'MEMBER_SUSPENDED',
        'errorMessage': '정지된 계정이에요',
      }, status: 403));

      expect(f.messageOr('잠시 후 다시 해주세요'), '정지된 계정이에요');
      expect(f.badgeOr('E-AUTH'), 'MEMBER_SUSPENDED');
    });

    test('앱이 모르는 코드여도 문구는 쓴다 — 서버가 먼저 배포되면 반드시 생긴다', () {
      final f = AppFailure.of(_res({
        'errorCode': 'SOME_BRAND_NEW_CODE',
        'errorMessage': '새로 생긴 이유예요',
      }, status: 409));

      expect(f.messageOr('기본 문구'), '새로 생긴 이유예요');
      // 코드를 몰라도 **어느 화면에서 무엇이 왔는지**는 남는다.
      expect(f.badgeOr('E-AUTH'), 'E-AUTH/409');
    });

    test('문구가 없으면 화면이 넘긴 기본 문구를 쓴다', () {
      final f = AppFailure.of(_res({'errorCode': 'MEMBER_NOT_FOUND'}));
      expect(f.messageOr('계정을 찾지 못했어요'), '계정을 찾지 못했어요');
      expect(f.badgeOr('E-AUTH'), 'MEMBER_NOT_FOUND');
    });

    test('빈 문구는 없는 것으로 본다 — 빈 팝업이 뜨면 안 된다', () {
      final f = AppFailure.of(_res({'errorMessage': '   '}));
      expect(f.messageOr('기본 문구'), '기본 문구');
    });
  });

  group('어떤 모양이 와도 죽지 않는다', () {
    test('본문이 Map이 아니어도', () {
      final f = AppFailure.of(_res('<html>502 Bad Gateway</html>', status: 502));
      expect(f.messageOr('기본 문구'), '기본 문구');
      expect(f.badgeOr('E-X'), 'E-X/502');
    });

    test('본문이 비어도', () {
      final f = AppFailure.of(_res(null, status: 500));
      expect(f.messageOr('기본 문구'), '기본 문구');
      expect(f.badgeOr('E-X'), 'E-X/500');
    });

    test('서버와 무관한 예외여도 — 이때만 화면이 준 코드를 쓴다', () {
      final f = AppFailure.of(StateError('생성된 카드가 없습니다'));
      expect(f.messageOr('카드를 만들지 못했어요'), '카드를 만들지 못했어요');
      expect(f.badgeOr('E-1001'), 'E-1001');
    });

    test('null 이어도', () {
      final f = AppFailure.of(null);
      expect(f.badgeOr('E-X'), 'E-X');
    });
  });

  group('네트워크 실패도 같은 통로로 묶는다 (#341)', () {
    test('연결 실패는 오프라인', () {
      final f = AppFailure.of(_typed(DioExceptionType.connectionError));
      expect(f.badgeOr('E-X'), 'E-NET-OFFLINE');
    });

    test('비행기 모드는 unknown 안에 SocketException 으로 온다', () {
      final f = AppFailure.of(
        _typed(DioExceptionType.unknown, error: const SocketException('no route')),
      );
      expect(f.badgeOr('E-X'), 'E-NET-OFFLINE');
    });

    test('세 가지 타임아웃이 모두 같은 코드로 모인다', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(AppFailure.of(_typed(t)).badgeOr('E-X'), 'E-NET-TIMEOUT',
            reason: '$t');
      }
    });

    test('Dio 밖에서 온 타임아웃·소켓 오류도 받는다', () {
      expect(
        AppFailure.of(TimeoutException('늦음')).badgeOr('E-X'),
        'E-NET-TIMEOUT',
      );
      expect(
        AppFailure.of(const SocketException('끊김')).badgeOr('E-X'),
        'E-NET-OFFLINE',
      );
    });

    test('원인을 못 밝힌 실패도 응답이 없으면 연결 실패다 (실기기 회귀)', () {
      // 요청이 나가는 도중에 비행기 모드를 켜면 dio 가 `error` 를 비운 채
      // `DioException [unknown]: null` 을 준다. 타입만 보고 가르던 시절에는
      // 이것이 `앱 오류` 로 떨어져 오프라인인데 "다시 해주세요" 로 안내했다 (#352).
      final f = AppFailure.of(_typed(DioExceptionType.unknown));
      expect(f.badgeOr('E-X'), 'E-NET-OFFLINE');
    });

    test('응답이 있는데 unknown 이면 앱 쪽 문제로 둔다', () {
      final err = _res({'errorMessage': '뭔가 이상해요'}, status: 200);
      final f = AppFailure.of(DioException(
        requestOptions: err.requestOptions,
        type: DioExceptionType.unknown,
        response: err.response,
      ));
      expect(f.messageOr('기본'), '뭔가 이상해요');
    });

    test('앱이 끊은 요청은 알리지 않는다 — 사용자가 한 적 없는 실패다', () {
      final f = AppFailure.of(_typed(DioExceptionType.cancel));
      expect(f.isSilent, isTrue);
    });
  });

  group('네트워크 사정은 우리가 안내한다 (#352)', () {
    test('오프라인이면 무엇을 하면 되는지 말한다', () {
      final f = AppFailure.of(_typed(DioExceptionType.connectionError));
      expect(f.hint, '인터넷 연결을 확인해주세요');
      // 무엇이 안 됐는지(화면 몫)와 무엇을 하면 되는지(여기 몫)가 둘 다 나온다.
      expect(
        f.describe('일과를 불러오지 못했어요', 'E-HOME'),
        '일과를 불러오지 못했어요 · 인터넷 연결을 확인해주세요 (E-NET-OFFLINE)',
      );
    });

    // 화면 문구가 두 문장(무엇이 안 됐는지 + 할 일)이면 안내가 붙을 때 할 일이
    // 두 개가 된다 — `연결하지 못했어요. 인터넷을 확인해주세요 · 인터넷 연결을
    // 확인해주세요` (실기기 실측, #428 · #427). 할 일은 안내 하나만 말한다.
    test('안내가 붙으면 화면 문구는 첫 문장만 쓴다 — 할 일을 두 번 말하지 않는다', () {
      const f = AppFailure(fault: NetworkFault.offline);
      expect(
        f.describe('연결하지 못했어요. 인터넷을 확인해주세요', 'E-NET'),
        '연결하지 못했어요 · 인터넷 연결을 확인해주세요 (E-NET-OFFLINE)',
      );
      expect(
        f.describe('일과를 저장하지 못했어요. 다시 해주세요', 'E-SAVE'),
        '일과를 저장하지 못했어요 · 인터넷 연결을 확인해주세요 (E-NET-OFFLINE)',
      );
    });

    test('안내가 없으면 화면 문구를 그대로 쓴다', () {
      final f = AppFailure.of(_res(null, status: 500));
      expect(
        f.describe('일과를 저장하지 못했어요. 다시 해주세요', 'E-SAVE'),
        '일과를 저장하지 못했어요. 다시 해주세요 (E-SAVE/500)',
      );
    });

    test('서버가 이유를 말했으면 덧붙이지 않는다 — 두 번 말하지 않는다', () {
      final f = AppFailure.of(_res({
        'errorCode': 'MEMBER_SUSPENDED',
        'errorMessage': '정지된 계정이에요',
      }, status: 403));
      expect(f.hint, isNull);
      expect(f.describe('기본', 'E-X'), '정지된 계정이에요 (MEMBER_SUSPENDED)');
    });

    test('서버가 응답한 실패에는 네트워크 안내를 붙이지 않는다', () {
      final f = AppFailure.of(_res(null, status: 500));
      expect(f.hint, isNull);
      expect(f.describe('저장하지 못했어요', 'E-X'), '저장하지 못했어요 (E-X/500)');
    });
  });

  test('팝업 본문은 문구와 식별자를 함께 낸다', () {
    final f = AppFailure.of(_res({
      'errorCode': 'ROUTINE_REQUEST_TOO_FREQUENT',
      'errorMessage': '조금 뒤에 다시 만들어주세요',
    }, status: 429));

    expect(
      f.describe('잠시 후 다시 해주세요', 'E-RT'),
      '조금 뒤에 다시 만들어주세요 (ROUTINE_REQUEST_TOO_FREQUENT)',
    );
  });

  group('인터셉터가 한 번만 판정한다', () {
    test('붙여 둔 판정을 그대로 쓴다 — 두 번 계산하지 않는다', () {
      const attached = AppFailure(fault: NetworkFault.offline);
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        error: attached,
      );
      expect(identical(AppFailure.of(err), attached), isTrue);
    });

    test('onError 가 지나가면 실패가 붙어 있다', () {
      final err = _res({'errorCode': 'MEMBER_SUSPENDED', 'errorMessage': '정지됐어요'});
      DioException? passed;
      const FailureInterceptor().onError(
        err,
        _CaptureHandler((e) => passed = e),
      );

      final attached = passed?.error;
      expect(attached, isA<AppFailure>());
      expect((attached! as AppFailure).messageOr('x'), '정지됐어요');
    });
  });
}

/// `handler.next`가 무엇을 넘기는지만 본다.
class _CaptureHandler implements ErrorInterceptorHandler {
  _CaptureHandler(this.onNext);

  final void Function(DioException) onNext;

  @override
  void next(DioException err) => onNext(err);

  @override
  void reject(DioException error, [bool callFollowing = false]) => onNext(error);

  @override
  void resolve(Response<dynamic> response) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
