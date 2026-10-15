
import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
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

    test('앱이 모르는 코드여도 문구는 쓴다 — 서버가 먼저 배포되면 반드시 생긴다', () {
      final f = AppFailure.of(_res({
        'errorCode': 'SOME_BRAND_NEW_CODE',
        'errorMessage': '새로 생긴 이유예요',
      }, status: 409));

      expect(f.messageOr('기본 문구'), '새로 생긴 이유예요');
      // 코드를 몰라도 **어느 화면에서 무엇이 왔는지**는 남는다.
      expect(f.badgeOr('E-AUTH'), 'E-AUTH/409');
    });

    test('빈 문구는 없는 것으로 본다 — 빈 팝업이 뜨면 안 된다', () {
      final f = AppFailure.of(_res({'errorMessage': '   '}));
      expect(f.messageOr('기본 문구'), '기본 문구');
    });
  });


  group('네트워크 실패도 같은 통로로 묶는다 (#341)', () {
    test('연결 실패는 오프라인', () {
      final f = AppFailure.of(_typed(DioExceptionType.connectionError));
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

    test('원인을 못 밝힌 실패도 응답이 없으면 연결 실패다 (실기기 회귀)', () {
      // 요청이 나가는 도중에 비행기 모드를 켜면 dio 가 `error` 를 비운 채
      // `DioException [unknown]: null` 을 준다. 타입만 보고 가르던 시절에는
      // 이것이 `앱 오류` 로 떨어져 오프라인인데 "다시 해주세요" 로 안내했다 (#352).
      final f = AppFailure.of(_typed(DioExceptionType.unknown));
      expect(f.badgeOr('E-X'), 'E-NET-OFFLINE');
    });

    test('앱이 끊은 요청은 알리지 않는다 — 사용자가 한 적 없는 실패다', () {
      final f = AppFailure.of(_typed(DioExceptionType.cancel));
      expect(f.isSilent, isTrue);
    });
  });

  group('네트워크 사정은 우리가 안내한다 (#352)', () {

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

}

