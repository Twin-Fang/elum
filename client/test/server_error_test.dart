import 'package:dio/dio.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(dynamic data, {int status = 400}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
  ),
);

void main() {
  group('서버 에러 코드는 서버 enum과 이름이 맞는다 (이슈 #347)', () {
    test('아는 코드는 그대로 매핑된다', () {
      expect(
        ServerErrorCode.from('OAUTH_EMAIL_CONFLICT'),
        ServerErrorCode.oauthEmailConflict,
      );
      expect(
        ServerErrorCode.from('MEMBER_SUSPENDED'),
        ServerErrorCode.memberSuspended,
      );
      expect(
        ServerErrorCode.from('MAINTENANCE_MODE'),
        ServerErrorCode.maintenanceMode,
      );
    });

    test('모르는 코드·빈 값은 unknown이다 — 던지지 않는다', () {
      expect(ServerErrorCode.from('NOPE_NOT_A_CODE'), ServerErrorCode.unknown);
      expect(ServerErrorCode.from(''), ServerErrorCode.unknown);
      expect(ServerErrorCode.from(null), ServerErrorCode.unknown);
    });
  });

  group('응답에서 에러를 꺼낸다 (이슈 #347)', () {
    test('코드와 문구를 함께 읽는다', () {
      final e = _err({
        'errorCode': 'MEMBER_SUSPENDED',
        'errorMessage': '정지된 계정입니다. 관리자에게 문의해주세요.',
      }, status: 403).serverError;

      expect(e.code, ServerErrorCode.memberSuspended);
      expect(e.message, '정지된 계정입니다. 관리자에게 문의해주세요.');
      expect(e.statusCode, 403);
      expect(e.badge, 'MEMBER_SUSPENDED');
    });

    test('서버 문구가 있으면 그것을 쓴다', () {
      final e = _err({
        'errorCode': 'OAUTH_PROVIDER_UNSUPPORTED',
        'errorMessage': '지원하지 않는 로그인 방식입니다.',
      }).serverError;

      expect(e.messageOr('잠시 후 다시 해주세요'), '지원하지 않는 로그인 방식입니다.');
    });

    test('서버 문구가 비면 앱 문구로 물러선다', () {
      final e = _err({'errorCode': 'INTERNAL_SERVER_ERROR', 'errorMessage': '  '})
          .serverError;

      expect(e.messageOr('잠시 후 다시 해주세요'), '잠시 후 다시 해주세요');
    });

    // 서버가 새 코드를 먼저 배포하는 일은 반드시 생긴다. 코드를 몰라도
    // 문구는 맞으므로 그대로 보여줄 수 있어야 한다.
    test('모르는 코드여도 문구는 살린다', () {
      final e = _err({
        'errorCode': 'BRAND_NEW_CODE',
        'errorMessage': '새로 생긴 안내 문구입니다.',
      }, status: 418).serverError;

      expect(e.isUnknownCode, isTrue);
      expect(e.messageOr('기본'), '새로 생긴 안내 문구입니다.');
      // 코드를 모르면 상태 코드라도 남긴다 — 제보 추적 수단이 사라지면 안 된다.
      expect(e.badge, 'E-HTTP-418');
    });

    group('본문이 어떤 모양이어도 죽지 않는다', () {
      test('본문이 문자열', () {
        final e = _err('<html>502 Bad Gateway</html>', status: 502).serverError;
        expect(e.code, ServerErrorCode.unknown);
        expect(e.messageOr('기본'), '기본');
        expect(e.badge, 'E-HTTP-502');
      });

      test('본문이 null', () {
        expect(_err(null, status: 500).serverError.code, ServerErrorCode.unknown);
      });

      test('필드가 아예 없다', () {
        final e = _err(<String, dynamic>{}).serverError;
        expect(e.code, ServerErrorCode.unknown);
        expect(e.message, isNull);
      });

      test('응답 자체가 없다 (연결 실패)', () {
        final e = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ).serverError;
        expect(e.code, ServerErrorCode.unknown);
        expect(e.badge, 'E-HTTP-0');
      });
    });
  });
}
